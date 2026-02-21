# Credential-API: CRUD für Passwort, SSH-Key, API-Key
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.models.schemas import (
    CredentialCreate,
    CredentialUpdate,
    CredentialResponse,
    CredentialWithSecret,
)
from app.services import credentials as svc

router = APIRouter(prefix="/credentials", tags=["credentials"])


@router.post("", response_model=CredentialResponse)
async def create(data: CredentialCreate, db: AsyncSession = Depends(get_db)):
    return await svc.create_credential(db, data)


@router.get("", response_model=list[CredentialResponse])
async def list_(
    type: str | None = None,
    category: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    return await svc.list_credentials(db, type_filter=type, category=category)


@router.get("/{credential_id}", response_model=CredentialResponse)
async def get(credential_id: int, db: AsyncSession = Depends(get_db)):
    resp = await svc.get_credential_response(db, credential_id)
    if not resp:
        raise HTTPException(status_code=404, detail="Credential not found")
    return resp


@router.get("/{credential_id}/secret", response_model=CredentialWithSecret)
async def get_with_secret(credential_id: int, db: AsyncSession = Depends(get_db)):
    result = await svc.get_credential_decrypted(db, credential_id)
    if not result:
        raise HTTPException(status_code=404, detail="Credential not found")
    resp, secret = result
    return CredentialWithSecret(secret=secret, **resp.model_dump())


@router.patch("/{credential_id}", response_model=CredentialResponse)
async def update(credential_id: int, data: CredentialUpdate, db: AsyncSession = Depends(get_db)):
    resp = await svc.update_credential(db, credential_id, data)
    if not resp:
        raise HTTPException(status_code=404, detail="Credential not found")
    return resp


@router.delete("/{credential_id}", status_code=204)
async def delete(credential_id: int, db: AsyncSession = Depends(get_db)):
    ok = await svc.delete_credential(db, credential_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Credential not found")
