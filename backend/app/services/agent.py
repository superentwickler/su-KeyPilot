# AI agent: natural language -> intent -> credential API (Ollama local)
import json
import re
import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.services import credentials as cred_svc

settings = Settings()

# Simplified intent: send user message to Ollama with a system prompt that requires
# format "INTENT: <name> | PARAMS: <json>"; then we execute the action.
SYSTEM_PROMPT = """You are the KeyPilot assistant. The user manages passwords, SSH keys, and API keys.
Reply with ONLY one line in this format (no other text):
INTENT: <intent> | PARAMS: <json>

Allowed intents and PARAMS (JSON):
- credential_create: {"type": "password|ssh_key|api_key", "name": "...", "category": "...", "description": "..."}  (secret generated separately if not given)
- credential_list: {"type": null or "password|ssh_key|api_key", "category": null or "..."}
- credential_show: {"id": number} or {"name": "..."}
- credential_rotate: {"id": number} or {"name": "..."}
- credential_delete: {"id": number} or {"name": "..."}

If the user only asks a question or you are unsure, use:
INTENT: chat | PARAMS: {}

Examples:
User: "Save a password for server prod-01 under the name SAP HANA Prod"
-> INTENT: credential_create | PARAMS: {"type": "password", "name": "SAP HANA Prod", "category": "Production", "description": "Server prod-01"}

User: "Show all API keys for BTP"
-> INTENT: credential_list | PARAMS: {"type": "api_key", "category": "BTP"}

User: "Rotate the password for RFC User DEV"
-> INTENT: credential_rotate | PARAMS: {"name": "RFC User DEV"}
"""


def _ollama_model_name() -> str:
    """Use model name as-is; if no tag (e.g. llama3.2), append :latest for Ollama."""
    name = (settings.ollama_model or "").strip()
    if not name:
        return "llama3.2:latest"
    if ":" not in name:
        return f"{name}:latest"
    return name


async def _call_ollama(prompt: str, user_message: str) -> str:
    url = f"{settings.ollama_base_url.rstrip('/')}/api/generate"
    model = _ollama_model_name()
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            r = await client.post(
                url,
                json={
                    "model": model,
                    "prompt": f"{prompt}\n\nUser: {user_message}\n\nAssistant:",
                    "stream": False,
                },
            )
            r.raise_for_status()
            data = r.json()
            return (data.get("response") or "").strip()
    except httpx.ConnectError as e:
        raise RuntimeError(
            f"Cannot reach Ollama at {settings.ollama_base_url}. "
            "Is Ollama running? If the backend runs in Docker, set OLLAMA_BASE_URL=http://host.docker.internal:11434"
        ) from e
    except httpx.HTTPStatusError as e:
        body = e.response.text
        if e.response.status_code == 404:
            raise RuntimeError(
                f"Ollama model '{model}' not found. Run: ollama pull {settings.ollama_model or 'llama3.2'}. "
                "Or check available models with: ollama list — then set OLLAMA_MODEL in backend/.env to the exact name."
            ) from e
        raise RuntimeError(f"Ollama error ({e.response.status_code}): {body[:200]}") from e


def _parse_response(response: str) -> tuple[str, dict]:
    intent = "chat"
    params: dict = {}
    m = re.search(r"INTENT:\s*(\w+)\s*\|\s*PARAMS:\s*(\{.*?\})", response, re.DOTALL)
    if m:
        intent = m.group(1).strip()
        try:
            params = json.loads(m.group(2))
        except json.JSONDecodeError:
            pass
    return intent, params


async def execute(
    db: AsyncSession,
    user_message: str,
) -> tuple[str, str | None]:
    """
    Send message to Ollama, parse intent+params, execute action.
    Returns: (response text for user, optional action_performed).
    """
    raw = await _call_ollama(SYSTEM_PROMPT, user_message)
    intent, params = _parse_response(raw)

    if intent == "chat":
        return raw or "Understood. Can you be more specific about what you want to do with the credentials?", None

    if intent == "credential_create":
        from secrets import token_urlsafe
        secret = params.pop("secret", None) or token_urlsafe(24)
        from app.models.schemas import CredentialCreate
        data = CredentialCreate(secret=secret, type=params.get("type", "password"), name=params.get("name", "Unnamed"), username=params.get("username", ""), category=params.get("category", ""), description=params.get("description", ""))
        cred = await cred_svc.create_credential(db, data)
        return f"Credential created: \"{cred.name}\" (type: {cred.type}, ID: {cred.id}). Secret stored securely.", "credential_created"

    if intent == "credential_list":
        items = await cred_svc.list_credentials(db, type_filter=params.get("type"), category=params.get("category"))
        if not items:
            return "No matching credentials found.", "credential_list"
        lines = [f"- [{c.id}] {c.name} ({c.type})" + (f" – Group: {c.category}" if c.category else "") for c in items]
        return "Credentials found:\n" + "\n".join(lines), "credential_list"

    if intent == "credential_show":
        name = params.get("name")
        cid = params.get("id")
        if name:
            all_ = await cred_svc.list_credentials(db)
            cred = next((c for c in all_ if c.name == name), None)
        elif cid is not None:
            cred = await cred_svc.get_credential(db, int(cid))
        else:
            return "Please specify name or ID.", None
        if not cred:
            return "Credential not found.", None
        _, secret = await cred_svc.get_credential_decrypted(db, cred.id)
        return f"**{cred.name}** ({cred.type})\nSecret: {secret}", "credential_show"

    if intent == "credential_rotate":
        name = params.get("name")
        cid = params.get("id")
        if name:
            all_ = await cred_svc.list_credentials(db)
            cred = next((c for c in all_ if c.name == name), None)
        elif cid is not None:
            cred = await cred_svc.get_credential(db, int(cid))
        else:
            return "Please specify name or ID.", None
        if not cred:
            return "Credential not found.", None
        from secrets import token_urlsafe
        from app.models.schemas import CredentialUpdate
        await cred_svc.update_credential(db, cred.id, CredentialUpdate(secret=token_urlsafe(24)))
        return f"Password/secret for \"{cred.name}\" rotated and saved.", "credential_rotated"

    if intent == "credential_delete":
        name = params.get("name")
        cid = params.get("id")
        if name:
            all_ = await cred_svc.list_credentials(db)
            cred = next((c for c in all_ if c.name == name), None)
        elif cid is not None:
            cred = await cred_svc.get_credential(db, int(cid))
        else:
            return "Please specify name or ID.", None
        if not cred:
            return "Credential not found.", None
        await cred_svc.delete_credential(db, cred.id)
        return f"Credential \"{cred.name}\" deleted.", "credential_deleted"

    return raw or "Action could not be performed.", None
