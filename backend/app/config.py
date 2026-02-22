# KeyPilot Backend – Configuration
from pathlib import Path

from pydantic import model_validator
from pydantic_settings import BaseSettings


def _backend_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    app_name: str = "KeyPilot"
    debug: bool = False

    # Database: KEYPILOT_DATA_DIR only (directory for keypilot.db). Unset = backend/data.
    # Local: only paths inside project (under backend/) are allowed; others fall back to backend/data.
    keypilot_data_dir: str | None = None

    # Computed from keypilot_data_dir only (see env_ignore)
    database_url: str = ""

    # Ollama (local LLM)
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.2"  # or mistral, codellama, etc.

    @model_validator(mode="after")
    def set_database_url_default(self):
        backend_root = _backend_root()
        default_url = "sqlite+aiosqlite:///./data/keypilot.db"
        if not self.keypilot_data_dir or not self.keypilot_data_dir.strip():
            self.database_url = default_url
            return self
        raw = self.keypilot_data_dir.strip()
        # Docker: container uses /app/data (mounted). Four slashes so path is absolute (/app/data/...).
        if raw == "/app/data":
            self.database_url = "sqlite+aiosqlite:////app/data/keypilot.db"
            return self
        # Local: only allow paths under backend/ (project structure)
        resolved = Path(raw).resolve() if Path(raw).is_absolute() else (backend_root / raw).resolve()
        try:
            resolved.relative_to(backend_root)
        except ValueError:
            # Path outside project → use default
            self.database_url = default_url
            return self
        self.database_url = f"sqlite+aiosqlite:///{resolved.as_posix()}/keypilot.db"
        return self

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        env_ignore = {"database_url"}  # computed from keypilot_data_dir only
