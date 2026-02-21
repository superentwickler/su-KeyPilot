# KeyPilot

Credential management (passwords, SSH keys, API keys) with a **built-in crypto container** (master key, seal/unseal) and **local LLM** (Ollama) an AI-assisted 

**License:** [MIT](LICENSE) – free to use, modify, and distribute.

---

## Installation options

| Option | Effort | When to use |
|--------|--------|-------------|
| **Docker Compose** | Single command, ready environment | When Docker is installed |
| **Manual** (no Docker) | Two terminals, Python + Node | Development, or when not using Docker |

**Without Docker:** Open two terminals → `./scripts/start-local.sh backend` and `./scripts/start-local.sh frontend` → http://localhost:5173 (see [Option 2: Manual](#option-2-manual-no-docker)).

**Welche .env für was?**

| Datei | Wann genutzt | Nicht genutzt bei |
|-------|--------------|--------------------|
| **Projektroot `.env`** (neben `docker-compose.yml`) | Nur bei **Docker** (`docker compose`). Steuert z. B. `KEYPILOT_DATA_DIR`, `FRONTEND_PORT`, `BACKEND_PORT`, `OLLAMA_*`. Siehe `.env.example` im Projektroot. | Lokaler Aufruf (Backend/Frontend lesen diese Datei nicht.) |
| **`backend/.env`** | Nur bei **lokalen** Backend-Starts (`uvicorn`, `./scripts/start-local.sh backend`). Steuert z. B. `DATABASE_URL`, `OLLAMA_*`. Siehe `backend/.env.example`. | Docker (Container nutzt feste Werte bzw. Projektroot-.env.) |
| **`frontend/.env`** | Nur bei **lokalen** Frontend-Starts (`npm run dev`, `./scripts/start-local.sh frontend`). Steuert z. B. `FRONTEND_PORT`. Siehe `frontend/.env.example`. | Docker (Port über Projektroot-.env.) |

---

### Option 1: Docker Compose

**Prerequisite:** Docker and Docker Compose installed.

**So startest du die ganze App in Docker:**

1. **Immer aus dem Projektroot** (Ordner, in dem `docker-compose.yml` liegt, z. B. `paiss`):
   ```bash
   cd /pfad/zu/paiss
   ./scripts/start-docker.sh
   ```
   Oder manuell: `docker compose up -d --build`

2. **Lokal laufendes Backend/Frontend** (z. B. `./scripts/start-local.sh backend/frontend`): Vorher stoppen, damit Port 80 frei ist – sonst meldet Docker ggf. „port already in use“. Backend (Port 8000) wird von Docker nur intern genutzt, kollidiert also nicht mit lokalem Uvicorn.

3. **In Docker Desktop:** Unter **Containers** siehst du die Container **keypilot-backend** und **keypilot-frontend**. Der Projektname ist der Ordnername (z. B. `paiss`). Beide müssen „Running“ sein.

4. **Wenn „backend nicht vorhanden“ oder Fehler:** Status prüfen mit `docker compose ps`, Backend-Logs mit `docker compose logs backend`. Wenn der Backend-Container fehlt oder beendet ist: `docker compose up -d --build` erneut aus dem Projektroot ausführen.

- **Frontend:** http://localhost (Standard Port 80; Port konfigurierbar: `FRONTEND_PORT=3000` in Projektroot-`.env` oder Umgebung, dann http://localhost:3000)
- **Backend** läuft im Container und ist unter http://localhost:8000 erreichbar (Port konfigurierbar: `BACKEND_PORT=…`). Du startest **kein** `uvicorn` auf dem Host – nur `docker compose up` reicht.
- **Data** (DB) liegt im Projektordner `backend/data/` – überlebt Rebuilds und Updates; kein Backup vor `docker compose up --build` nötig.
- **Ollama** (local LLM): Usually runs on the host. In the container, `OLLAMA_BASE_URL=http://host.docker.internal:11434` is set (Mac/Windows). On Linux, set the host IP if needed, e.g. `OLLAMA_BASE_URL=http://172.17.0.1:11434`.

Stop: `./scripts/stop-docker.sh` or `docker compose down`.

**After code changes:** Rebuild with `docker compose up -d --build`.

**Development without constant rebuilds:** Use the dev override so backend code is mounted from the host and Uvicorn runs with `--reload`: `./scripts/start-docker-dev.sh` or:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

Frontend changes still require rebuilding the frontend container (or run the frontend locally with `npm run dev` and use the running backend container).

**Which DB does Docker use?** Standardmäßig **`backend/data/keypilot.db`**. Rebuilds und Updates ändern die DB nicht. **Nicht** `docker compose down -v` verwenden.

**DB-Speicherort selbst wählen (z. B. iCloud, OneDrive):** In einer `.env` im Projektroot oder als Umgebungsvariable:

```bash
# Beispiel: eigener Ordner
KEYPILOT_DATA_DIR=/Users/deinname/Daten/KeyPilot

# Beispiel: iCloud (macOS) – Pfad anpassen
KEYPILOT_DATA_DIR=/Users/deinname/Library/Mobile Documents/com~apple~CloudDocs/KeyPilot

# Beispiel: OneDrive (Windows) – Pfad anpassen
# KEYPILOT_DATA_DIR=C:\Users\deinname\OneDrive\KeyPilot
```

Dann `docker compose up -d` – die DB liegt in dem Ordner. **Hinweis iCloud/OneDrive:** Während die App läuft, kann Sync die geöffnete SQLite-Datei beschreiben und zu Korruption führen. Besser: DB im normalen Ordner lassen und nur **Backups** in den Cloud-Ordner kopieren (z. B. mit `./scripts/backup.sh ~/Library/Mobile\ Documents/.../KeyPilot`). Wenn du die DB trotzdem in der Cloud ablegst: App beim Sync möglichst stoppen.

**In der App:** Beim ersten Start (Unseal-Seite) erscheint ein Hinweis mit dem aktuellen Speicherort; er ist mit „Ausblenden“ abschaltbar. Unter **Vault → Open vault (Unseal)** findest du dauerhaft die Karte **Daten-Speicherort** mit dem angezeigten Pfad und wie du ihn änderst (Docker: `KEYPILOT_DATA_DIR`; lokal: Ordner `backend/data`). Den Speicherort wählst du über die Konfiguration (nicht in der App), siehe oben.

Backup: `./scripts/backup.sh [directory]` (Standard-Ziel: `./backups`). Details: [docs/BACKUP.md](docs/BACKUP.md).

---

### Option 2: Manual (no Docker)

**Nur wenn du ohne Docker arbeitest:** Backend und Frontend startest du selbst (z. B. `uvicorn` und `npm run dev`). Bei Docker (Option 1) brauchst du diese Befehle nicht.

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
- **Browser:** http://localhost:5173 (Port konfigurierbar: `frontend/.env` mit `FRONTEND_PORT=…`, siehe `frontend/.env.example`)

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

Open http://localhost:5173 (oder den in `frontend/.env` gesetzten Port, siehe `frontend/.env.example`).

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

1. **Backend in Docker:** Inside the container, `localhost` is the container itself. Set in **Projektroot `.env`** (nicht `backend/.env`): Mac/Windows: `OLLAMA_BASE_URL=http://host.docker.internal:11434`; Linux: `OLLAMA_BASE_URL=http://172.17.0.1:11434` (oder Host-IP).
2. **Model:** Default ist `OLLAMA_MODEL=llama3.2`. Modell ziehen: `ollama pull llama3.2` bzw. `ollama list`. Anderes Modell: **Docker** → Projektroot `.env`; **lokal** → `backend/.env`.
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
