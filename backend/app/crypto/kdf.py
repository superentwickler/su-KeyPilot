# Key derivation from master key – Master-Key nie auf Disk, nur im Speicher
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
import secrets


def derive_key(master_key: bytes, salt: bytes, length: int = 32) -> bytes:
    """Leitet einen AES-256-Key aus dem Master-Key und Salt ab (PBKDF2)."""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=length,
        salt=salt,
        iterations=600_000,
        backend=default_backend(),
    )
    return kdf.derive(master_key)


def generate_salt() -> bytes:
    return secrets.token_bytes(16)
