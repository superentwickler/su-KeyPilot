# KeyPilot

Credential management (passwords, SSH keys, API keys) with a **built-in crypto container** (master key, seal/unseal) and **local LLM** (Ollama) for AI-assisted chat.

**License:** [MIT](LICENSE) – free to use, modify, and distribute. For personal and non-commercial use no further permission is needed. For commercial use please get in touch (e.g. via the repository or the maintainer listed in the license).

---

## Installation options

| Option | Effort | When to use |
|--------|--------|-------------|
| **Docker Compose** | Single command, ready environment | When Docker is installed |
| **Manual** (no Docker) | Two terminals, Python + Node | Development, or when not using Docker |

**Without Docker:** Open two terminals → `./scripts/start-local.sh backend` and `./scripts/start-local.sh frontend` → http://localhost:5173 (see [Option 2: Manual](#option-2-manual-no-docker)).

**Which .env for what?** All options are documented in the respective `.env.example` files.

| File | When used | Not used for |
|------|------------|--------------|
| **Project root `.env`** (next to `docker-compose.yml`) | Only with **Docker** (`docker compose`). Controls e.g. `KEYPILOT_DATA_DIR`, `FRONTEND_PORT`, `BACKEND_PORT`, `OLLAMA_*`. See `.env.example` in project root. | Local run (backend/frontend do not read this file.) |
| **`backend/.env`** | Only with **local** backend starts. DB in `backend/data` by default; optional **KEYPILOT_DATA_DIR** only with paths inside the project. See `backend/.env.example`. | Docker (container uses project root .env for volume.) |
| **`frontend/.env`** | Only with **local** frontend starts (`npm run dev`, `./scripts/start-local.sh frontend`). Controls e.g. `FRONTEND_PORT`. See `frontend/.env.example`. | Docker (port via project root .env.) |

---

### Option 1: Docker Compose

**Prerequisite:** Docker and Docker Compose installed.

**How to start the whole app in Docker:**

1. **Always from the project root** (folder containing `docker-compose.yml`, e.g. `KeyPilot`):
   ```bash
   cd /path/to/KeyPilot
   ./scripts/start-docker.sh
   ```
   Or manually: `docker compose up -d --build`

2. **Backend/Frontend running locally** (e.g. `./scripts/start-local.sh backend/frontend`): Stop them first so port 80 is free – otherwise Docker may report "port already in use". Backend (port 8000) is only used internally by Docker, so it won't conflict with local Uvicorn.

3. **In Docker Desktop:** Under **Containers** you'll see **keypilot-backend** and **keypilot-frontend**. The project name is the folder name (e.g. `KeyPilot`). Both must be "Running".

4. **If "backend not found" or errors:** Check status with `docker compose ps`, backend logs with `docker compose logs backend`. If the backend container is missing or stopped, run `docker compose up -d --build` again from the project root.

- **Frontend:** http://localhost (default port 80; configurable: `FRONTEND_PORT=3000` in project root `.env` or environment, then http://localhost:3000)
- **Backend** runs in the container and is reachable at http://localhost:8000 (configurable: `BACKEND_PORT=…`). You don't start `uvicorn` on the host – only `docker compose up` is needed.
- **Data** (DB) is stored in project folder `backend/data/` – survives rebuilds and updates; no backup before `docker compose up --build` required.
- **Ollama** (local LLM): Usually runs on the host. In the container, `OLLAMA_BASE_URL=http://host.docker.internal:11434` is set (Mac/Windows). On Linux, set the host IP if needed, e.g. `OLLAMA_BASE_URL=http://172.17.0.1:11434`.

Stop: `./scripts/stop-docker.sh` or `docker compose down`.

**After code changes:** Rebuild with `docker compose up -d --build`.

**Development without constant rebuilds:** Use the dev override so backend code is mounted from the host and Uvicorn runs with `--reload`: `./scripts/start-docker-dev.sh` or:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

Frontend changes still require rebuilding the frontend container (or run the frontend locally with `npm run dev` and use the running backend container).

**Which DB does Docker use?** By default **`backend/data/keypilot.db`**. Rebuilds and updates don't change the DB. **Do not** use `docker compose down -v`.

**Choose DB location yourself (e.g. iCloud, OneDrive):** In a `.env` in the project root or as an environment variable:

```bash
# Example: custom folder
KEYPILOT_DATA_DIR=/Users/yourname/Data/KeyPilot

# Example: iCloud (macOS) – adjust path
KEYPILOT_DATA_DIR=/Users/yourname/Library/Mobile Documents/com~apple~CloudDocs/KeyPilot

# Example: OneDrive (Windows) – adjust path
# KEYPILOT_DATA_DIR=C:\Users\yourname\OneDrive\KeyPilot
```

Then `docker compose up -d` – the DB is stored in that folder. **Note on iCloud/OneDrive:** While the app is running, sync may write to the open SQLite file and cause corruption. Better: keep the DB in a normal folder and only copy **backups** to the cloud folder (e.g. `./scripts/backup.sh ~/Library/Mobile\ Documents/.../KeyPilot`). If you still put the DB in the cloud, stop the app during sync if possible.

**In the app:** On first start (Unseal page) a notice with the current database path appears; it can be dismissed. Under **Open vault (Unseal)** the database path is shown. You set the location via **KEYPILOT_DATA_DIR** (one parameter for both Docker and local), not in the app.

Backup: `./scripts/backup.sh [directory]` (default target: `./backups`). Details: [docs/BACKUP.md](docs/BACKUP.md).

---

### Option 2: Manual (no Docker)

**Only if you're not using Docker:** You start backend and frontend yourself (e.g. `uvicorn` and `npm run dev`). With Docker (Option 1) you don't need these commands.

KeyPilot runs fully **without Docker**: backend (Python/FastAPI) and frontend (React/Vite) are started locally; the DB is SQLite (`keypilot.db` in **KEYPILOT_DATA_DIR**, default `backend/data`).

**Prerequisites**

- **Python 3.11+** (backend)
- **Node 18+** (frontend)
- **Ollama** with a model (e.g. `ollama run llama3.2`)

**Database:** Unset = `backend/data`. Optional **KEYPILOT_DATA_DIR** in `backend/.env`: for local runs use only paths **inside the project** (e.g. `backend/data` or `backend/mydata`); paths outside are not allowed.

**Backend**

```bash
cd backend
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Environment variables (optional, `.env` in `backend`):

```
# DB directory: unset = backend/data. Local: only paths inside project (e.g. backend/data).
# KEYPILOT_DATA_DIR=backend/data

OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2
```

**Two terminals:** Backend first, then frontend. Easiest with the scripts (venv and dependencies are created if needed):

- **Terminal 1:** `./scripts/start-local.sh backend`
- **Terminal 2:** `./scripts/start-local.sh frontend`
- **Browser:** http://localhost:5173 (port configurable in `frontend/.env` with `FRONTEND_PORT=…`, see `frontend/.env.example`)

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

Open http://localhost:5173 (or the port set in `frontend/.env`, see `frontend/.env.example`).

**First run – Master key:** There is no default key. On first “Open vault (Unseal)” you choose a secure password – that becomes your master key. Remember it; without it, stored secrets cannot be decrypted after a restart. Then: manage credentials or use the Chat (AI).


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

1. **Backend in Docker:** Inside the container, `localhost` is the container itself. Set in **project root `.env`** (not `backend/.env`): Mac/Windows: `OLLAMA_BASE_URL=http://host.docker.internal:11434`; Linux: `OLLAMA_BASE_URL=http://172.17.0.1:11434` (or host IP).
2. **Model:** Default is `OLLAMA_MODEL=llama3.2`. Pull model: `ollama pull llama3.2` or `ollama list`. Different model: **Docker** → project root `.env`; **local** → `backend/.env`.
3. **Check:** In the Chat tab, send a message; if Ollama is unreachable or the model is missing, the error text will show the cause (e.g. “Cannot reach Ollama at …” or “model not found”).

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
