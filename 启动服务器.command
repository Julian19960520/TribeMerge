#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT_DIR/tools/mac_launcher_common.sh"

ensure_server_venv || { pause_on_error; exit 1; }

HOST="${TRIBE_HOST:-127.0.0.1}"
PORT="${TRIBE_PORT:-8765}"
echo "Server: http://${HOST}:${PORT}"
"$SERVER_PY" "$ROOT_DIR/server/run.py" --host "$HOST" --port "$PORT" "$@" || true

echo ""
echo "Server stopped."
pause_on_error
