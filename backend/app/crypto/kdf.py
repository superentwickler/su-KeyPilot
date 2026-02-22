# Key derivation from master key (master key never on disk, only in memory)
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
import secrets


def derive_key(master_key: bytes, salt: bytes, length: int = 32) -> bytes:
    """Derive an AES-256 key from master key and salt (PBKDF2)."""
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
