# KeyPilot Backend – FastAPI
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import Settings

logger = logging.getLogger(__name__)
from app.db import database
from app.db.database import Base, get_db, switch_to_fallback_sqlite
from app.db import models  # noqa: F401 – register tables with Base
from app.api import vault_router, credentials_router, chat_router
from app.api.utils import router as utils_router


def _add_username_column_if_missing(sync_conn):
    """Add username column to credentials for existing DBs (SQLite)."""
    from sqlalchemy import text
    try:
        r = sync_conn.execute(text("PRAGMA table_info(credentials)"))
        rows = r.fetchall()
        if not any(row[1] == "username" for row in rows):
            sync_conn.execute(text(
                "ALTER TABLE credentials ADD COLUMN username VARCHAR(255) DEFAULT ''"
            ))
    except Exception:
        pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        async with database.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
            if Settings().database_url.startswith("sqlite"):
                await conn.run_sync(_add_username_column_if_missing)
    except Exception as e:
        if "authorization denied" in str(e).lower():
            switch_to_fallback_sqlite()
            async with database.engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
                await conn.run_sync(_add_username_column_if_missing)
        else:
            raise
    yield
    await database.engine.dispose()


app = FastAPI(
    title="KeyPilot",
    description="AI-assisted credential management – passwords, SSH keys, API keys",
    version="0.2.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(vault_router)
app.include_router(credentials_router)
app.include_router(chat_router)
app.include_router(utils_router)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    """Log full traceback and return 500 with message so frontend can show it."""
    if isinstance(exc, HTTPException):
        raise exc
    logger.exception("Unhandled exception for %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc)},
    )


@app.get("/health")
def health():
    return {"status": "ok", "app": "KeyPilot"}
