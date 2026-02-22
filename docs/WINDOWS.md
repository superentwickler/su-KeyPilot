# KeyPilot unter Windows

Die Scripts in `scripts/` sind für **Linux/macOS** (Bash). Unter Windows kannst du wie folgt vorgehen.

---

## Option A: Docker (empfohlen)

Mit **Docker Desktop für Windows** laufen die gleichen Container wie auf Mac/Linux. Statt der Shell-Scripts führst du die Befehle in **PowerShell** oder **CMD** aus.

**Projektroot** = Ordner, in dem `docker-compose.yml` liegt.

### Starten

```powershell
cd C:\Pfad\zu\KeyPilot
docker compose up -d --build
```

Dann http://localhost im Browser öffnen.

### Stoppen

```powershell
docker compose down
```

### Logs

```powershell
docker compose logs -f
```

### Dev-Modus (Backend-Code gemountet, Reload)

```powershell
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

**.env** für Docker liegt im Projektroot (siehe README). DB-Standort z. B.:

```powershell
# Beispiel: eigenes Verzeichnis
$env:KEYPILOT_DATA_DIR = "C:\Users\DeinName\Data\KeyPilot"
docker compose up -d --build
```

Oder `.env` im Projektroot anlegen mit `KEYPILOT_DATA_DIR=C:\Users\...\KeyPilot`.

---

## Option B: Lokal ohne Docker

Backend (Python) und Frontend (Node) manuell starten – **zwei Terminals** (PowerShell oder CMD).

### Voraussetzungen

- **Python 3.11+** (z. B. von python.org), „Add to PATH“ aktiviert
- **Node.js 18+** (z. B. von nodejs.org)
- Optional: **Ollama** für den Chat (ollama.ai)

### Terminal 1 – Backend

```powershell
cd C:\Pfad\zu\KeyPilot\backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

*(Falls ExecutionPolicy Fehler: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`)*

### Terminal 2 – Frontend

```powershell
cd C:\Pfad\zu\KeyPilot\frontend
npm install
npm run dev
```

Dann http://localhost:5173 im Browser öffnen.

---

## Backup (Windows)

**Lokal (ohne Docker):** DB liegt standardmäßig in `backend\data\keypilot.db`.

```powershell
cd C:\Pfad\zu\KeyPilot
$date = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Force -Path backups
Copy-Item backend\data\keypilot.db backups\keypilot_$date.db
Write-Host "Backup: backups\keypilot_$date.db"
```

**Mit Docker:** Backup aus laufendem Container:

```powershell
docker cp keypilot-backend:/app/data/keypilot.db backups\keypilot_$(Get-Date -Format "yyyyMMdd_HHmmss").db
```

---

## Restore (Windows)

**Backend/Docker vorher stoppen.**

```powershell
cd C:\Pfad\zu\KeyPilot
Copy-Item C:\Pfad\zu\deinem\keypilot_backup.db backend\data\keypilot.db
Write-Host "Restore done. Restart backend/Docker and open vault with same master key."
```

---

## Option C: WSL oder Git Bash

Wenn du **WSL** (Windows Subsystem for Linux) oder **Git für Windows** (Git Bash) nutzt, kannst du die vorhandenen `.sh`-Scripts wie auf Linux/Mac verwenden – aus WSL/Git-Bash heraus im Projektordner:

```bash
./scripts/start-docker.sh
./scripts/backup.sh
# usw.
```

---

## Kurzüberblick

| Aktion        | PowerShell (Projektroot) |
|---------------|---------------------------|
| Docker start  | `docker compose up -d --build` |
| Docker stop   | `docker compose down` |
| Backup (lokal)| `Copy-Item backend\data\keypilot.db backups\keypilot_<datum>.db` |
| Backup (Docker)| `docker cp keypilot-backend:/app/data/keypilot.db backups\keypilot_<datum>.db` |
| Restore      | Backend stoppen, dann `Copy-Item <backup.db> backend\data\keypilot.db` |

Weitere Details (Umgebungsvariablen, Ports, Ollama) stehen in der [README](../README.md).
