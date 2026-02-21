# Credential-CRUD: name/username and secret encrypted in DB; decrypted only when vault is unsealed
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crypto import get_container
from app.db.models import Credential
from app.models.schemas import CredentialCreate, CredentialUpdate, CredentialResponse


def _ensure_unsealed():
    if get_container().is_sealed:
        raise HTTPException(status_code=503, detail="Vault is sealed. Unseal first.")


def _encrypt_field(container, value: str) -> str:
    """Encrypt string for storage; empty string stays empty."""
    if not value or not value.strip():
        return ""
    return container.encrypt(value.strip())


def _decrypt_field(container, value: str) -> tuple[str, bool]:
    """
    Decrypt name/username from DB. Returns (plaintext, was_legacy).
    If decryption fails (legacy plaintext), returns (value as-is, True).
    """
    if not value or not value.strip():
        return "", False
    try:
        return container.decrypt(value), False
    except Exception:
        return value, True


def _credential_to_response(container, cred: Credential) -> CredentialResponse:
    """Build CredentialResponse with decrypted name and username."""
    dec_name, name_legacy = _decrypt_field(container, cred.name)
    dec_username, username_legacy = _decrypt_field(container, cred.username or "")
    return CredentialResponse(
        id=cred.id,
        type=cred.type,
        name=dec_name,
        username=dec_username,
        category=cred.category,
        description=cred.description,
        created_at=cred.created_at,
        updated_at=cred.updated_at,
    )


async def create_credential(db: AsyncSession, data: CredentialCreate) -> CredentialResponse:
    _ensure_unsealed()
    container = get_container()
    cred = Credential(
        type=data.type,
        name=_encrypt_field(container, data.name),
        username=_encrypt_field(container, data.username or ""),
        category=data.category or "",
        description=data.description or "",
        ciphertext=container.encrypt(data.secret),
    )
    db.add(cred)
    await db.commit()
    await db.refresh(cred)
    return _credential_to_response(container, cred)


async def list_credentials(
    db: AsyncSession,
    type_filter: str | None = None,
    category: str | None = None,
) -> list[CredentialResponse]:
    _ensure_unsealed()
    container = get_container()
    q = select(Credential)
    if type_filter:
        q = q.where(Credential.type == type_filter)
    if category:
        q = q.where(Credential.category == category)
    r = await db.execute(q)
    rows = list(r.scalars().all())
    result = []
    to_migrate = []
    for cred in rows:
        dec_name, name_legacy = _decrypt_field(container, cred.name)
        dec_username, username_legacy = _decrypt_field(container, cred.username or "")
        if name_legacy or username_legacy:
            to_migrate.append((cred, dec_name, dec_username))
        result.append(
            CredentialResponse(
                id=cred.id,
                type=cred.type,
                name=dec_name,
                username=dec_username,
                category=cred.category,
                description=cred.description,
                created_at=cred.created_at,
                updated_at=cred.updated_at,
            )
        )
    result.sort(key=lambda c: c.name.lower())
    for cred, dec_name, dec_username in to_migrate:
        cred.name = _encrypt_field(container, dec_name) if dec_name else ""
        cred.username = _encrypt_field(container, dec_username) if dec_username else ""
        db.add(cred)
    if to_migrate:
        await db.commit()
    return result


async def get_credential(db: AsyncSession, credential_id: int) -> Credential | None:
    r = await db.execute(select(Credential).where(Credential.id == credential_id))
    return r.scalar_one_or_none()


async def get_credential_response(
    db: AsyncSession, credential_id: int
) -> CredentialResponse | None:
    cred = await get_credential(db, credential_id)
    if not cred:
        return None
    _ensure_unsealed()
    container = get_container()
    dec_name, name_legacy = _decrypt_field(container, cred.name)
    dec_username, username_legacy = _decrypt_field(container, cred.username or "")
    if name_legacy or username_legacy:
        cred.name = _encrypt_field(container, dec_name) if dec_name else ""
        cred.username = _encrypt_field(container, dec_username) if dec_username else ""
        db.add(cred)
        await db.commit()
    return CredentialResponse(
        id=cred.id,
        type=cred.type,
        name=dec_name,
        username=dec_username,
        category=cred.category,
        description=cred.description,
        created_at=cred.created_at,
        updated_at=cred.updated_at,
    )


async def get_credential_decrypted(
    db: AsyncSession, credential_id: int
) -> tuple[CredentialResponse, str] | None:
    cred = await get_credential(db, credential_id)
    if not cred:
        return None
    _ensure_unsealed()
    container = get_container()
    dec_name, name_legacy = _decrypt_field(container, cred.name)
    dec_username, username_legacy = _decrypt_field(container, cred.username or "")
    if name_legacy or username_legacy:
        cred.name = _encrypt_field(container, dec_name) if dec_name else ""
        cred.username = _encrypt_field(container, dec_username) if dec_username else ""
        db.add(cred)
        await db.commit()
    secret = container.decrypt(cred.ciphertext)
    resp = CredentialResponse(
        id=cred.id,
        type=cred.type,
        name=dec_name,
        username=dec_username,
        category=cred.category,
        description=cred.description,
        created_at=cred.created_at,
        updated_at=cred.updated_at,
    )
    return resp, secret


async def update_credential(
    db: AsyncSession, credential_id: int, data: CredentialUpdate
) -> CredentialResponse | None:
    cred = await get_credential(db, credential_id)
    if not cred:
        return None
    _ensure_unsealed()
    container = get_container()
    if data.name is not None:
        cred.name = _encrypt_field(container, data.name)
    if data.username is not None:
        cred.username = _encrypt_field(container, data.username)
    if data.category is not None:
        cred.category = data.category
    if data.description is not None:
        cred.description = data.description
    if data.secret is not None:
        cred.ciphertext = container.encrypt(data.secret)
    await db.commit()
    await db.refresh(cred)
    return _credential_to_response(container, cred)


async def delete_credential(db: AsyncSession, credential_id: int) -> bool:
    cred = await get_credential(db, credential_id)
    if not cred:
        return False
    await db.delete(cred)
    await db.commit()
    return True
