#!/bin/sh
# Ensure data dir is writable by app user (fixes "readonly database" when host volume has wrong owner)
chown -R appuser:appuser /app/data 2>/dev/null || true
exec gosu appuser "$@"
