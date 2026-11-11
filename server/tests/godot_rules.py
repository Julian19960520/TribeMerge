"""Run the shared Godot gameplay rules (scripts/replay/worker.gd) from tests.

The server no longer executes game rules; these tests exercise the client reducer
directly so gameplay invariants keep Python-side coverage.
"""
import atexit
import json
import os
import subprocess
import tempfile

import pytest

from app.config import REPO_DIR

GODOT = os.environ.get('TRIBE_GODOT') or os.environ.get('TRIBE_REPLAY_GODOT')
PREFIX = 'TRIBE_REPLAY_RESPONSE '
requires_godot = pytest.mark.skipif(not GODOT, reason='set TRIBE_GODOT to Godot 4.6.3')
_process = None
_directory = None


def _start():
    global _process, _directory
    _directory = tempfile.TemporaryDirectory(prefix='tribe-rules-')
    _process = subprocess.Popen(
        [GODOT, '--headless', '--path', str(REPO_DIR), '--script', 'res://scripts/replay/worker.gd', '--',
         '--replay-worker', '--replay-service', '--cloud-off',
         f'--save={_directory.name}/unused.json', f'--cloud-state={_directory.name}/cloud.json'],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', bufsize=1,
        env={**os.environ, 'GODOT_SILENCE_ROOT_WARNING': '1'})


def _close():
    global _process, _directory
    if _process is not None:
        _process.kill()
        _process.wait()
        _process = None
    if _directory is not None:
        _directory.cleanup()
        _directory = None


atexit.register(_close)


def run_worker(payload):
    if _process is None or _process.poll() is not None:
        _start()
    _process.stdin.write(json.dumps(payload, ensure_ascii=False, separators=(',', ':')) + '\n')
    _process.stdin.flush()
    diagnostics = []
    while True:
        line = _process.stdout.readline()
        if not line:
            _close()
            raise RuntimeError('rules worker exited: ' + ''.join(diagnostics[-20:]))
        if 'SCRIPT ERROR:' in line or line.startswith('ERROR:'):
            _close()
            raise RuntimeError('rules worker script error: ' + line + ''.join(diagnostics[-20:]))
        if line.startswith(PREFIX):
            return json.loads(line[len(PREFIX):])
        diagnostics.append(line)


def worker(payload):
    result = run_worker(payload)
    assert result['ok'], result
    return result


def op(seq, at, name, **args):
    return dict(seq=seq, at=at, name=name, args=args)


def new_game(at=1794240000, player='TRBTEST', seed='ab' * 32, allow_gm=True):
    return worker(dict(mode='new', at=at, player=player, seed=seed, allow_gm=allow_gm))['data']
