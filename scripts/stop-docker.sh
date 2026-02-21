#!/usr/bin/env bash
# KeyPilot Docker stoppen (Daten im Volume bleiben erhalten)
set -e
cd "$(dirname "$0")/.."
if ! docker info &>/dev/null; then
  echo "Docker is not running. Please start Docker Desktop."
  exit 1
fi
echo "Stopping KeyPilot Docker…"
docker compose down
echo "Done. Data remains in backend/data/."
