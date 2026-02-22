# KeyPilot – Scripts

Run all scripts from the project root, e.g. `./scripts/start-docker.sh`.

## Without Docker (manual start)

| Script | Description |
|--------|--------------|
| **start-local.sh backend** | Start backend locally (port 8000); creates venv if needed |
| **start-local.sh frontend** | Start frontend locally (port 5173); runs npm install if needed |

Use two terminals: first `./scripts/start-local.sh backend`, then `./scripts/start-local.sh frontend`. App: http://localhost:5173.

## With Docker

| Script | Description |
|--------|--------------|
| **start-docker.sh** | Start Docker (production), then http://localhost |
| **start-docker-dev.sh** | Docker with dev override (backend code mounted, reload) |
| **stop-docker.sh** | Stop Docker; data stays in volume |

## Backup / Restore

| Script | Description |
|--------|--------------|
| **backup.sh** [dir] | Copy DB to directory (default: `./backups`); from Docker, copy from container |
| **restore.sh** \<file.db\> | Restore DB from backup file (stop backend first) |

First run: make scripts executable with `chmod +x scripts/*.sh` if needed (Linux/macOS).

**Windows:** The `.sh` scripts do not run in CMD/PowerShell. Use the equivalent commands in [docs/WINDOWS.md](../docs/WINDOWS.md) (Docker, backup, restore, local start).
