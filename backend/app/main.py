# KeyPilot Backend – FastAPI
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import Settings
from app.db.database import engine, Base, get_db
from app.db import models  # noqa: F401 – Tabellen bei Base registrieren
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
    if Settings().database_url.startswith("sqlite"):
        os.makedirs("data", exist_ok=True)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        if Settings().database_url.startswith("sqlite"):
            await conn.run_sync(_add_username_column_if_missing)
    yield
    # Shutdown
    await engine.dispose()


app = FastAPI(
    title="KeyPilot",
    description="KI-gestütztes Credential-Management – Passwort, SSH-Key, API-Key",
    version="0.1.0",
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


@app.get("/health")
def health():
    return {"status": "ok", "app": "KeyPilot"}
