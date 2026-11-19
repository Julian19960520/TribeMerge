#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT_DIR/tools/mac_launcher_common.sh"

run_godot_client || { pause_on_error; exit 1; }
