# DB: SQLite only – async Session
import logging
from pathlib import Path

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import StaticPool

from app.config import Settings

logger = logging.getLogger(__name__)
settings = Settings()


def _sqlite_url_with_absolute_path(url: str) -> str:
    """Resolve SQLite path to absolute and ensure directory exists."""
    rest = url.split("///", 1)[-1].split("?")[0]
    path_candidate = Path(rest)
    if path_candidate.is_absolute():
        path = path_candidate
    else:
        backend_root = Path(__file__).resolve().parent.parent.parent
        path = (backend_root / rest).resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    return f"sqlite+aiosqlite:///{path.as_posix()}"


def _build_engine_for_url(url: str):
    """Create engine for SQLite URL."""
    url = _sqlite_url_with_absolute_path(url)
    return create_async_engine(
        url,
        echo=settings.debug,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )


# Config validator already set database_url (from KEYPILOT_DATA_DIR or default)
engine = _build_engine_for_url(settings.database_url)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


def switch_to_fallback_sqlite() -> None:
    """Use backend/data when configured path gets 'authorization denied' (e.g. iCloud/Documents)."""
    global engine, AsyncSessionLocal
    backend_root = Path(__file__).resolve().parent.parent.parent
    fallback_path = backend_root / "data" / "keypilot.db"
    fallback_path.parent.mkdir(parents=True, exist_ok=True)
    fallback_url = f"sqlite+aiosqlite:///{fallback_path.as_posix()}"
    try:
        engine.sync_engine.dispose()
    except Exception:
        pass
    logger.warning(
        "SQLite 'authorization denied' for configured path – using fallback: %s. "
        "Set KEYPILOT_DATA_DIR to a path outside iCloud/restricted folders (e.g. here or ~/KeyPilotData).",
        fallback_path,
    )
    engine = _build_engine_for_url(fallback_url)
    AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session
