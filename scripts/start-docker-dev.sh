#!/usr/bin/env bash
# KeyPilot mit Docker starten (Entwicklung: Backend-Code gemountet, --reload)
set -e
cd "$(dirname "$0")/.."
if ! docker info &>/dev/null; then
  echo "Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi
echo "Starting KeyPilot Docker (dev)…"
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
echo "Done. Open http://localhost"
echo "Backend changes apply without rebuild."
