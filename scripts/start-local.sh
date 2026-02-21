#!/usr/bin/env bash
# KeyPilot lokal starten (Backend + Frontend in je einem Terminal)
# Nutzung: ./scripts/start-local.sh
# Oder: Terminal 1: ./scripts/start-local.sh backend
#       Terminal 2: ./scripts/start-local.sh frontend
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

run_backend() {
  echo "Starting backend (port 8000)…"
  cd "$ROOT/backend"
  if [ ! -d .venv ]; then
    echo "No venv. Creating: python -m venv .venv && .venv/bin/pip install -r requirements.txt"
    python3 -m venv .venv
    .venv/bin/pip install -r requirements.txt
  fi
  .venv/bin/uvicorn app.main:app --reload --port 8000
}

run_frontend() {
  FRONTEND_PORT="${FRONTEND_PORT:-5173}"
  if [ -f "$ROOT/frontend/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    . "$ROOT/frontend/.env"
    set +a
    FRONTEND_PORT="${FRONTEND_PORT:-5173}"
  fi
  echo "Starting frontend (port $FRONTEND_PORT)…"
  cd "$ROOT/frontend"
  if [ ! -d node_modules ]; then
    echo "No node_modules. Running npm install…"
    npm install
  fi
  npm run dev
}

case "${1:-}" in
  backend)  run_backend ;;
  frontend) run_frontend ;;
  *)
    echo "KeyPilot local start – two terminals required."
    echo ""
    echo "Terminal 1: $0 backend"
    echo "Terminal 2: $0 frontend"
    echo ""
    p="${FRONTEND_PORT:-5173}"
    [ -f "$ROOT/frontend/.env" ] && set -a && . "$ROOT/frontend/.env" && set +a && p="${FRONTEND_PORT:-5173}"
    echo "Then open: http://localhost:$p"
    exit 0
    ;;
esac
