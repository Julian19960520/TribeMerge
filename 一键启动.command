#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT_DIR/tools/mac_launcher_common.sh"

HOST="${TRIBE_HOST:-127.0.0.1}"
PORT="${TRIBE_PORT:-8765}"
HEALTH_URL="http://${HOST}:${PORT}/v1/health"
LOG_FILE="$ROOT_DIR/server/server.log"

STARTED_SERVER=0
SERVER_PID=""

cleanup() {
    if [[ "$STARTED_SERVER" -eq 1 && -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo ""
        echo "正在停止服务器 (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
        echo "服务器已停止。"
    fi
}
trap cleanup EXIT INT TERM

if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
    echo "检测到服务器已在运行: http://${HOST}:${PORT}"
else
    ensure_server_venv || { pause_on_error; exit 1; }
    echo "正在启动服务器: http://${HOST}:${PORT}"
    echo "服务器日志: $LOG_FILE"
    "$SERVER_PY" "$ROOT_DIR/server/run.py" --host "$HOST" --port "$PORT" >"$LOG_FILE" 2>&1 &
    SERVER_PID=$!
    STARTED_SERVER=1

    ready=0
    for _ in $(seq 1 60); do
        if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
            ready=1
            break
        fi
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            echo "服务器启动失败，最近日志如下："
            tail -n 30 "$LOG_FILE" || true
            pause_on_error
            exit 1
        fi
        sleep 0.5
    done

    if [[ "$ready" -ne 1 ]]; then
        echo "等待服务器就绪超时，最近日志如下："
        tail -n 30 "$LOG_FILE" || true
        pause_on_error
        exit 1
    fi
    echo "服务器已就绪。"
fi

run_godot_client || { pause_on_error; exit 1; }
