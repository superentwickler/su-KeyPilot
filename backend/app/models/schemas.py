# Pydantic-Schemas für API
from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class UnsealRequest(BaseModel):
    master_key: str


class UnsealResponse(BaseModel):
    status: str = "unsealed"


class VaultStatusResponse(BaseModel):
    sealed: bool


class CredentialBase(BaseModel):
    type: str  # password | ssh_key | api_key | other
    name: str
    username: str = ""
    category: str = ""
    description: str = ""


class CredentialCreate(CredentialBase):
    secret: str  # wird verschlüsselt gespeichert, nie in Antworten


class CredentialUpdate(BaseModel):
    name: Optional[str] = None
    username: Optional[str] = None
    category: Optional[str] = None
    description: Optional[str] = None
    secret: Optional[str] = None  # wenn gesetzt: rotieren/aktualisieren


class CredentialResponse(BaseModel):
    id: int
    type: str
    name: str
    username: str = ""
    category: str
    description: str
    created_at: datetime
    updated_at: datetime
    # secret/ciphertext nie in Response

    class Config:
        from_attributes = True


class CredentialWithSecret(CredentialResponse):
    secret: str  # nur bei expliziter Abfrage (z. B. "Passwort anzeigen")


class ChatMessage(BaseModel):
    role: str  # user | assistant
    content: str


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str
    action_performed: Optional[str] = None  # z. B. "credential_created"


class GeneratePasswordResponse(BaseModel):
    password: str
