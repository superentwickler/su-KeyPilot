# Crypto container: AES-256-GCM, seal/unseal with master key.
# Master key is never stored on disk, only in memory after unseal.
import secrets
import base64
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.backends import default_backend

from .kdf import derive_key, generate_salt


class CryptoContainer:
    """
    Encrypted container for secrets.
    - Unseal: enter master key -> data key is derived and kept in memory.
    - Seal: discard data key; container unusable until next unseal.
    """

    def __init__(self) -> None:
        self._aes: Optional[AESGCM] = None  # set only when unsealed
        self._sealed: bool = True

    @property
    def is_sealed(self) -> bool:
        return self._sealed

    KEY_CHECK_PLAINTEXT = "keypilot-vault-ok"

    def unseal(
        self,
        master_key: str,
        salt: Optional[bytes] = None,
        key_check_b64: Optional[str] = None,
    ) -> bytes:
        """
        Master key (e.g. from user) -> container is usable.
        salt: persistent (e.g. from DB). None on first use -> new salt.
        key_check_b64: if set, verify key decrypts stored check; otherwise vault stays sealed.
        Returns: salt (new or passed in).
        """
        if salt is None:
            salt = generate_salt()
        key_material = master_key.encode("utf-8") if isinstance(master_key, str) else master_key
        key = derive_key(key_material, salt, length=32)
        self._aes = AESGCM(key)
        self._sealed = False
        if key_check_b64:
            try:
                dec = self.decrypt(key_check_b64)
                if dec != self.KEY_CHECK_PLAINTEXT:
                    self.seal()
                    raise ValueError("Wrong master key")
            except Exception:
                self.seal()
                raise ValueError("Wrong master key")
        return salt

    def seal(self) -> None:
        """Discard key; no read/write possible afterwards."""
        self._aes = None
        self._sealed = True

    def encrypt(self, plaintext: str) -> str:
        """Encrypt a string; returns base64(nonce + ciphertext)."""
        if self._sealed or self._aes is None:
            raise RuntimeError("Vault is sealed. Unseal with master key first.")
        nonce = secrets.token_bytes(12)
        ct = self._aes.encrypt(nonce, plaintext.encode("utf-8"), None)
        return base64.b64encode(nonce + ct).decode("ascii")

    def decrypt(self, ciphertext_b64: str) -> str:
        """Decrypt a string produced by encrypt()."""
        if self._sealed or self._aes is None:
            raise RuntimeError("Vault is sealed. Unseal with master key first.")
        raw = base64.b64decode(ciphertext_b64.encode("ascii"))
        nonce, ct = raw[:12], raw[12:]
        pt = self._aes.decrypt(nonce, ct, None)
        return pt.decode("utf-8")


# Singleton for the app
_container: Optional[CryptoContainer] = None


def get_container() -> CryptoContainer:
    global _container
    if _container is None:
        _container = CryptoContainer()
    return _container
