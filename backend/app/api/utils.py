# Hilfs-Endpoints: Passwort-Generator, Backup, Restore
import os
import secrets
import tempfile
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, HTTPException, UploadFile
from fastapi.responses import FileResponse

from app.config import Settings
from app.models.schemas import GeneratePasswordResponse

router = APIRouter(prefix="/utils", tags=["utils"])


@router.get("/generate-password", response_model=GeneratePasswordResponse)
def generate_password(length: int = 24):
    """Generiert ein sicheres Passwort (URL-safe base64)."""
    return GeneratePasswordResponse(password=secrets.token_urlsafe(length))


def _sqlite_db_path() -> Path | None:
    """Pfad zur SQLite-Datei aus DATABASE_URL, oder None wenn nicht SQLite."""
    url = Settings().database_url
    if not url.startswith("sqlite"):
        return None
    if "///" in url:
        path_str = url.split("///", 1)[-1].split("?")[0]
        return Path(path_str)
    return None


@router.get("/info")
def app_info():
    """Aktueller Speicherort der DB (für Anzeige in der App). Bei Docker: Host-Pfad aus KEYPILOT_DATA_DIR."""
    path = _sqlite_db_path()
    if path:
        resolved = path.resolve()
        data_dir = resolved.parent
        db_path = str(resolved)
        host_data_dir = os.environ.get("KEYPILOT_DATA_DIR", "").strip()
        if host_data_dir:
            db_path = os.path.normpath(os.path.join(host_data_dir, "keypilot.db"))
        return {
            "data_dir": str(data_dir),
            "db_path": db_path,
            "database": "sqlite",
        }
    return {"data_dir": None, "db_path": None, "database": "other"}


@router.get("/backup")
def download_backup():
    """DB als Datei herunterladen (nur bei SQLite)."""
    path = _sqlite_db_path()
    if not path or not path.exists():
        raise HTTPException(status_code=404, detail="Backup only available with local SQLite DB.")
    date_str = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    return FileResponse(
        path,
        media_type="application/octet-stream",
        filename=f"keypilot_backup_{date_str}.db",
    )


@router.post("/restore")
async def restore_backup(file: UploadFile):
    """
    Hochgeladene Backup-Datei (.db) als aktuelle DB übernehmen.
    Nur bei SQLite. Nach dem Restore Backend neu starten, damit die neue DB aktiv wird.
    """
    path = _sqlite_db_path()
    if not path:
        raise HTTPException(status_code=404, detail="Restore only available with local SQLite DB.")
    if not file.filename or not file.filename.lower().endswith(".db"):
        raise HTTPException(status_code=400, detail="Please select a .db file.")
    try:
        content = await file.read()
        if len(content) < 100:
            raise HTTPException(status_code=400, detail="File seems too small for a KeyPilot DB.")
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(delete=False, dir=path.parent, suffix=".db") as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        os.replace(tmp_path, path)
    except OSError as e:
        raise HTTPException(
            status_code=500,
            detail="Could not write file. Try stopping the backend and retrying.",
        ) from e
    return {
        "message": "Backup restored. Please restart the backend for the new DB to take effect.",
    }
