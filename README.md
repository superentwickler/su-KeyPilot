# KeyPilot

AI-assisted credential management (passwords, SSH keys, API keys) with a **built-in crypto container** (master key, seal/unseal) and **local LLM** (Ollama).

**License:** [MIT](LICENSE) – free to use, modify, and distribute.

---

## Installation options

| Option | Effort | When to use |
|--------|--------|-------------|
| **Docker Compose** | Single command, ready environment | When Docker is installed |
| **Manual** (no Docker) | Two terminals, Python + Node | Development, or when not using Docker |

**Without Docker:** Open two terminals → `./scripts/start-local.sh backend` and `./scripts/start-local.sh frontend` → http://localhost:5173 (see [Option 2: Manual](#option-2-manual-no-docker)).

---

### Option 1: Docker Compose

**Prerequisite:** Docker and Docker Compose installed.

```bash
# From project root – or use the script:
./scripts/start-docker.sh
# Or manually:
docker compose up -d --build
```

- **Frontend:** http://localhost (port 80)
- **Data** (DB) is stored in a Docker volume and persists across restarts.
- **Ollama** (local LLM): Usually runs on the host. In the container, `OLLAMA_BASE_URL=http://host.docker.internal:11434` is set (Mac/Windows). On Linux, set the host IP if needed, e.g. `OLLAMA_BASE_URL=http://172.17.0.1:11434`.

Stop: `./scripts/stop-docker.sh` or `docker compose down`.

**After code changes:** Rebuild with `docker compose up -d --build`.

**Development without constant rebuilds:** Use the dev override so backend code is mounted from the host and Uvicorn runs with `--reload`: `./scripts/start-docker-dev.sh` or:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

Frontend changes still require rebuilding the frontend container (or run the frontend locally with `npm run dev` and use the running backend container).

**Which DB does Docker use?** By default its **own** DB in volume `keypilot-data` – **not** the file `backend/data/keypilot.db` on your machine. To use the same DB as local runs, see [Docker: same DB as local](#docker-same-db-as-local).

Backup: `./scripts/backup.sh [directory]` (copies the DB; from Docker, copies from the container; default target: `./backups`). Details and encryption: [docs/BACKUP.md](docs/BACKUP.md).

### Docker: same DB as local

To have the backend container use the **same** SQLite file as when running locally (`backend/data/keypilot.db`), override the volume (only when Docker is stopped and the file is not in use by a local process):

```bash
# Once: create directory
mkdir -p backend/data

# In docker-compose.yml, for the backend service under volumes replace:
#   - keypilot-data:/app/data
# with:
#   - ./backend/data:/app/data
```

Then the DB lives in the project folder and is the **same** for local and Docker.

---

### Option 2: Manual (no Docker)

KeyPilot runs fully **without Docker**: backend (Python/FastAPI) and frontend (React/Vite) are started locally; the DB is a local SQLite file (`backend/data/keypilot.db`).

**Prerequisites**

- **Python 3.11+** (backend)
- **Node 18+** (frontend)
- **Ollama** with a model (e.g. `ollama run llama3.2`)

**Database:** By default **SQLite** is used (file `backend/data/keypilot.db`) – no Docker required. For PostgreSQL, set `DATABASE_URL` in `backend/.env`.

**Backend**

```bash
cd backend
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Environment variables (optional, `.env` in `backend`):

```
# Default = SQLite (no Docker)
# DATABASE_URL=sqlite+aiosqlite:///./data/keypilot.db

# Optional: PostgreSQL
# DATABASE_URL=postgresql+asyncpg://keypilot:keypilot@localhost:5432/keypilot

OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2
```

**Two terminals:** Backend first, then frontend. Easiest with the scripts (venv and dependencies are created if needed):

- **Terminal 1:** `./scripts/start-local.sh backend`
- **Terminal 2:** `./scripts/start-local.sh frontend`
- **Browser:** http://localhost:5173

**Terminal 1 – Backend** (from `backend`):

```bash
cd backend
pip install -r requirements.txt
./run.sh
```

Or with Uvicorn and reload:

```bash
cd backend
uvicorn app.main:app --reload --port 8000 --reload-dir app --reload-exclude '**/__pycache__/**' --reload-exclude '**/data/**'
```

Without reload:

```bash
cd backend && uvicorn app.main:app --port 8000
```

*(If you see "No module named 'greenlet'", run `pip install greenlet`.)*

Wait until you see `Uvicorn running on http://127.0.0.1:8000`.

**Terminal 2 – Frontend:**

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:5173.

**First run – Master key:** There is no default key. On first “Open vault (Unseal)” you choose a secure password – that becomes your master key. Remember it; without it, stored secrets cannot be decrypted after a restart. Then: manage credentials or use the Chat (AI).

**Reset vault:** If you forgot the master key or want to start over: on the Unseal page, scroll to “Reset vault”. Type **RESET** and confirm – all credentials and the salt are removed; on next open you choose a new master key.

**Backup:** `./scripts/backup.sh` backs up the local DB; restore with `./scripts/restore.sh <file.db>`. See [docs/BACKUP.md](docs/BACKUP.md) for encryption and the two-key model.

**Note:** If you see “Connection refused” or proxy errors, start the backend in Terminal 1 first.

## Ollama (local LLM)

Install: https://ollama.ai  
Start a model:

```bash
ollama run llama3.2
```

Without Ollama running, the Chat will not work (API returns an error).

**Chat still not working?**

1. **Backend in Docker:** Inside the container, `localhost` is the container itself. Set in `backend/.env` or docker-compose:
   - Mac/Windows: `OLLAMA_BASE_URL=http://host.docker.internal:11434`
   - Linux: `OLLAMA_BASE_URL=http://172.17.0.1:11434` (or your host IP)
2. **Model:** The backend uses `OLLAMA_MODEL=llama3.2` by default. Ensure the model is pulled: `ollama pull llama3.2` and/or `ollama list`. If you use another model, set `OLLAMA_MODEL=your-model` in `backend/.env`.
3. **Check:** In the Chat tab, send a message; if Ollama is unreachable or the model is missing, the error text will now show the cause (e.g. “Cannot reach Ollama at …” or “model not found”).

## Scripts (`scripts/`)

| Script | Use |
|--------|-----|
| **start-docker.sh** | Start Docker (production), then http://localhost |
| **start-docker-dev.sh** | Docker with dev override (backend code mounted, reload) |
| **stop-docker.sh** | Stop Docker; data remains in volume |
| **start-local.sh** | No arg: usage. With `backend` / `frontend`: start backend or frontend locally |
| **backup.sh** [dir] | Backup DB (local or from running container); default: `./backups` |
| **restore.sh** \<file.db\> | Restore from backup file (stop backend first) |

Run all scripts from the project root, e.g. `./scripts/start-docker.sh`. See [scripts/README.md](scripts/README.md).

## Overview

- **Unseal:** Enter master key → vault is usable.
- **Credentials:** Add, view (click “Show secret”), and delete passwords, SSH keys, API keys.
- **Chat:** Natural language, e.g. “Save a password for Server XY under the name …”, “Show all API keys for BTP”.
