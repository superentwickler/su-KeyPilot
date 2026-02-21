# KeyPilot Backend – Konfiguration
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "KeyPilot"
    debug: bool = False

    # Database: Standard = SQLite (ohne Docker). Für PostgreSQL: DATABASE_URL setzen.
    database_url: str = "sqlite+aiosqlite:///./data/keypilot.db"

    # Ollama (lokales LLM)
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.2"  # oder mistral, codellama etc.

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
