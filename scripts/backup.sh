#!/usr/bin/env bash
# KeyPilot Backup: DB-Datei kopieren, optional verschlüsseln
# Nutzung: ./scripts/backup.sh [Zielordner]
# Beispiel: ./scripts/backup.sh ./backups
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="${1:-$ROOT/backups}"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/keypilot_$DATE.db"

if [ -f "$ROOT/backend/data/keypilot.db" ]; then
  cp "$ROOT/backend/data/keypilot.db" "$BACKUP_FILE"
  echo "Backup created: $BACKUP_FILE"
elif docker ps -q -f name=keypilot-backend 2>/dev/null | head -1 | grep -q .; then
  docker cp keypilot-backend:/app/data/keypilot.db "$BACKUP_FILE"
  echo "Backup from Docker container: $BACKUP_FILE"
else
  echo "Neither backend/data/keypilot.db nor running container keypilot-backend found."
  exit 1
fi

echo "Optional: encrypt with openssl enc -aes-256-cbc -salt -pbkdf2 -in $BACKUP_FILE -out $BACKUP_FILE.enc"
