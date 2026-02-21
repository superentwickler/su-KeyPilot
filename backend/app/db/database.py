# DB: SQLite (Standard) oder PostgreSQL – async Session
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import StaticPool
from app.config import Settings

settings = Settings()
# SQLite braucht connect_args für async; PostgreSQL nicht
connect_args = {}
if settings.database_url.startswith("sqlite"):
    connect_args["check_same_thread"] = False
engine = create_async_engine(
    settings.database_url,
    echo=settings.debug,
    connect_args=connect_args if connect_args else {},
    poolclass=StaticPool if settings.database_url.startswith("sqlite") else None,
)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session
