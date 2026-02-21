# Vault: Unseal / Seal / Status / Reset
import base64
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.crypto import get_container
from app.db.database import get_db
from app.db.models import VaultMeta, Credential
from app.models.schemas import UnsealRequest, UnsealResponse, VaultStatusResponse

router = APIRouter(prefix="/vault", tags=["vault"])


async def _get_meta(db_session: AsyncSession, key: str) -> str | None:
    r = await db_session.execute(select(VaultMeta).where(VaultMeta.key == key))
    row = r.scalar_one_or_none()
    return row.value if row else None


@router.get("/status", response_model=VaultStatusResponse)
def vault_status():
    container = get_container()
    return VaultStatusResponse(sealed=container.is_sealed)


@router.post("/unseal", response_model=UnsealResponse)
async def unseal(req: UnsealRequest, db: AsyncSession = Depends(get_db)):
    container = get_container()
    if not container.is_sealed:
        return UnsealResponse()

    salt_b64 = await _get_meta(db, "kdf_salt")
    key_check_b64 = await _get_meta(db, "key_check")
    salt = base64.b64decode(salt_b64) if salt_b64 else None

    try:
        new_salt = container.unseal(req.master_key, salt, key_check_b64)
    except ValueError as e:
        raise HTTPException(status_code=403, detail=str(e))

    if salt is None:
        meta_salt = VaultMeta(key="kdf_salt", value=base64.b64encode(new_salt).decode("ascii"))
        db.add(meta_salt)
        check_cipher = container.encrypt(container.KEY_CHECK_PLAINTEXT)
        meta_check = VaultMeta(key="key_check", value=check_cipher)
        db.add(meta_check)
        await db.commit()
    elif not key_check_b64:
        check_cipher = container.encrypt(container.KEY_CHECK_PLAINTEXT)
        meta_check = VaultMeta(key="key_check", value=check_cipher)
        db.add(meta_check)
        await db.commit()

    return UnsealResponse()


@router.post("/seal", response_model=VaultStatusResponse)
def seal():
    container = get_container()
    container.seal()
    return VaultStatusResponse(sealed=True)


@router.post("/reset")
async def reset(db: AsyncSession = Depends(get_db)):
    """
    Vault komplett zurücksetzen: Container versiegeln, alle Credentials und den Salt löschen.
    Danach beim nächsten Unseal einen neuen Master-Key wählen (wie beim ersten Start).
    """
    container = get_container()
    container.seal()
    await db.execute(delete(Credential))
    await db.execute(delete(VaultMeta))
    await db.commit()
    return {"status": "reset", "message": "Vault zurückgesetzt. Beim nächsten Öffnen neuen Master-Key wählen."}
