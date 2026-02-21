# Crypto-Container: AES-256-GCM, Seal/Unseal mit Master-Key
# Master-Key wird nie auf Disk gespeichert, nur im Speicher nach Unseal.
import secrets
import base64
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.backends import default_backend

from .kdf import derive_key, generate_salt


class CryptoContainer:
    """
    Verschüsselter Container für Secrets.
    - Unseal: Master-Key eingeben -> Daten-Key wird abgeleitet und im Speicher gehalten.
    - Seal: Daten-Key verwerfen, Container unbrauchbar bis erneutes Unseal.
    """

    def __init__(self) -> None:
        self._aes: Optional[AESGCM] = None  # nur gesetzt wenn unsealed
        self._sealed: bool = True

    @property
    def is_sealed(self) -> bool:
        return self._sealed

    def unseal(self, master_key: str, salt: Optional[bytes] = None) -> bytes:
        """
        Master-Key (z. B. vom User eingegeben) -> Container ist nutzbar.
        salt: persistent gespeicherter Salt (z. B. aus DB). Beim ersten Mal None -> neuer Salt wird erzeugt.
        Returns: Salt (neu erzeugt oder gleich dem übergebenen); beim ersten Unseal in DB speichern.
        """
        if salt is None:
            salt = generate_salt()
        key_material = master_key.encode("utf-8") if isinstance(master_key, str) else master_key
        key = derive_key(key_material, salt, length=32)
        self._aes = AESGCM(key)
        self._sealed = False
        return salt

    def seal(self) -> None:
        """Schlüssel verwerfen; danach kein Lesen/Schreiben mehr möglich."""
        self._aes = None
        self._sealed = True

    def encrypt(self, plaintext: str) -> str:
        """Verschlüsselt einen String; liefert base64(Nonce + Ciphertext)."""
        if self._sealed or self._aes is None:
            raise RuntimeError("Vault is sealed. Unseal with master key first.")
        nonce = secrets.token_bytes(12)
        ct = self._aes.encrypt(nonce, plaintext.encode("utf-8"), None)
        return base64.b64encode(nonce + ct).decode("ascii")

    def decrypt(self, ciphertext_b64: str) -> str:
        """Entschlüsselt einen mit encrypt() erzeugten String."""
        if self._sealed or self._aes is None:
            raise RuntimeError("Vault is sealed. Unseal with master key first.")
        raw = base64.b64decode(ciphertext_b64.encode("ascii"))
        nonce, ct = raw[:12], raw[12:]
        pt = self._aes.decrypt(nonce, ct, None)
        return pt.decode("utf-8")


# Singleton für die App
_container: Optional[CryptoContainer] = None


def get_container() -> CryptoContainer:
    global _container
    if _container is None:
        _container = CryptoContainer()
    return _container
