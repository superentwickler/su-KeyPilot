#!/usr/bin/env bash
# KeyPilot Restore: DB-Datei aus Backup zurücklegen
# Nutzung: ./scripts/restore.sh <backup.db>
# Beispiel: ./scripts/restore.sh ./backups/keypilot_20260221.db
# Wichtig: Backend/Docker vorher stoppen.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP="${1:?Usage: $0 <path-to-backup.db>}"

if [ ! -f "$BACKUP" ]; then
  echo "File not found: $BACKUP"
  exit 1
fi

mkdir -p "$ROOT/backend/data"
cp "$BACKUP" "$ROOT/backend/data/keypilot.db"
echo "Restore done: $ROOT/backend/data/keypilot.db"
echo "Restart backend/Docker and open the vault with the same master key."
