#!/usr/bin/env bash
# KeyPilot mit Docker starten (Produktion)
set -e
cd "$(dirname "$0")/.."
if ! docker info &>/dev/null; then
  echo "Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi
echo "Starting KeyPilot Docker…"
docker compose up -d --build
echo "Done. Open http://localhost"
echo "Logs: docker compose logs -f"
