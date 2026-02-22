# Helper endpoints: password generator, backup, restore
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
    """Generate a secure password (URL-safe base64)."""
    return GeneratePasswordResponse(password=secrets.token_urlsafe(length))


def _sqlite_db_path() -> Path | None:
    """Path to SQLite file (from KEYPILOT_DATA_DIR / config), or None if not SQLite."""
    url = Settings().database_url
    if not url.startswith("sqlite"):
        return None
    if "///" in url:
        path_str = url.split("///", 1)[-1].split("?")[0]
        return Path(path_str)
    return None


@router.get("/info")
def app_info():
    """Current DB location (for display in app). Docker: host path via KEYPILOT_DATA_DIR_DISPLAY."""
    path = _sqlite_db_path()
    if path:
        resolved = path.resolve()
        data_dir = resolved.parent
        db_path = str(resolved)
        # Display path: Docker host path, or configured KEYPILOT_DATA_DIR, or actual path
        display_dir = os.environ.get("KEYPILOT_DATA_DIR_DISPLAY", "").strip() or (Settings().keypilot_data_dir or "").strip()
        if display_dir:
            db_path = os.path.normpath(os.path.join(display_dir, "keypilot.db"))
        return {
            "data_dir": str(data_dir),
            "db_path": db_path,
            "database": "sqlite",
        }
    return {"data_dir": None, "db_path": None, "database": "other"}


@router.get("/backup")
def download_backup():
    """Download DB as file (SQLite only)."""
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
    Replace current DB with uploaded backup (.db). SQLite only.
    Restart the backend after restore for the new DB to take effect.
    """
    path = _sqlite_db_path()
    if not path:
        raise HTTPException(status_code=404, detail="Restore only available with local SQLite DB.")
    # Always use absolute path so we write to the correct location (CWD-independent)
    path = path.resolve()
    if not file.filename or not file.filename.lower().endswith(".db"):
        raise HTTPException(status_code=400, detail="Please select a .db file.")
    try:
        content = await file.read()
        if len(content) < 100:
            raise HTTPException(status_code=400, detail="File seems too small for a KeyPilot DB.")
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(delete=False, dir=str(path.parent), suffix=".db") as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        os.replace(tmp_path, str(path))
    except OSError as e:
        errmsg = str(e) if e.strerror else repr(e)
        raise HTTPException(
            status_code=500,
            detail=f"Could not write to {path}. {errmsg} Stop the backend, then use: ./scripts/restore.sh <yourfile.db>",
        ) from e
    return {
        "message": f"Backup restored to {path}. Restart the backend (e.g. docker compose restart backend) so the new DB is used.",
    }
