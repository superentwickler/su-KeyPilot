# Tables: credential metadata + encrypted secrets, vault salt
from sqlalchemy import String, Text, DateTime, Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime
import enum

from .database import Base


class CredentialType(str, enum.Enum):
    password = "password"
    ssh_key = "ssh_key"
    api_key = "api_key"
    other = "other"


class Credential(Base):
    __tablename__ = "credentials"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    type: Mapped[str] = mapped_column(String(20))  # password, ssh_key, api_key, other
    # name and username stored encrypted (base64 ciphertext); decrypted only in memory when vault is unsealed
    name: Mapped[str] = mapped_column(Text, nullable=False)  # ciphertext
    username: Mapped[str] = mapped_column(Text, default="")  # ciphertext, empty string if not set
    category: Mapped[str] = mapped_column(String(255), default="", index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    # Secret stored encrypted only (ciphertext from crypto container)
    ciphertext: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(), default=datetime.utcnow, onupdate=datetime.utcnow)


class VaultMeta(Base):
    """One row: salt for key derivation (persistent). Never store master key."""
    __tablename__ = "vault_meta"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    key: Mapped[str] = mapped_column(String(64), unique=True)  # z. B. "kdf_salt"
    value: Mapped[str] = mapped_column(Text)  # Salt als base64-String
