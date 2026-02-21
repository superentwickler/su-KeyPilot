#!/usr/bin/env bash
# Backend starten – Reload nur bei Code-Änderungen (nicht bei data/, __pycache__)
cd "$(dirname "$0")"
exec uvicorn app.main:app --reload --port 8000 \
  --reload-dir app \
  --reload-exclude '**/__pycache__/**' \
  --reload-exclude '**/data/**'
