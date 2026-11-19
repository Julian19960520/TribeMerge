#!/usr/bin/env bash
# Shared helpers for macOS .command launchers.

pause_on_error() {
    echo ""
    read -r -p "按回车键退出..." _
}

find_python() {
    local candidate
    for candidate in "${PYTHON_BIN:-}" "$(command -v python3 2>/dev/null || true)" /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    echo "未找到 python3，请先安装 Python 3（例如: brew install python）。" >&2
    return 1
}

ensure_server_venv() {
    local server_dir="$ROOT_DIR/server"
    local venv_dir="$server_dir/.venv"
    local venv_py="$venv_dir/bin/python"

    if [[ ! -x "$venv_py" ]]; then
        local sys_py
        sys_py="$(find_python)" || return 1
        echo "正在创建服务器虚拟环境: $venv_dir"
        "$sys_py" -m venv "$venv_dir" || return 1
    fi

    if ! "$venv_py" -c "import fastapi, sqlalchemy, alembic, uvicorn, pydantic_settings" >/dev/null 2>&1; then
        echo "正在安装服务器依赖 (server/requirements.txt)..."
        if ! "$venv_py" -m pip install -r "$server_dir/requirements.txt"; then
            echo "检测到部分固定版本包与当前 Python 不兼容，尝试以兼容版本安装..."
            local tmp_req
            tmp_req="$(mktemp)"
            grep -v '^psycopg' "$server_dir/requirements.txt" > "$tmp_req"
            "$venv_py" -m pip install -r "$tmp_req" || { rm -f "$tmp_req"; return 1; }
            rm -f "$tmp_req"
            "$venv_py" -m pip install "psycopg[binary]>=3.2.10" || true
        fi
        "$venv_py" -c "import fastapi, sqlalchemy, alembic, uvicorn, pydantic_settings" >/dev/null 2>&1 || return 1
    fi

    SERVER_PY="$venv_py"
}

find_godot() {
    local candidate
    for candidate in \
        "${GODOT_BIN:-}" \
        "/Applications/Godot.app/Contents/MacOS/Godot" \
        "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
        "$(command -v godot 2>/dev/null || true)" \
        "$(command -v godot4 2>/dev/null || true)"; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            GODOT_BIN="$candidate"
            return 0
        fi
    done
    echo "未找到 Godot 4 可执行文件。" >&2
    echo "请将 Godot.app 放到 /Applications/Godot.app，或设置环境变量 GODOT_BIN。" >&2
    return 1
}

run_godot_client() {
    find_godot || return 1
    if [[ ! -f "$ROOT_DIR/.godot/global_script_class_cache.cfg" ]]; then
        echo "首次运行，正在重建 Godot 资源缓存..."
        "$GODOT_BIN" --headless --path "$ROOT_DIR" --import
    fi
    echo "正在启动客户端: $GODOT_BIN"
    "$GODOT_BIN" --path "$ROOT_DIR"
}
