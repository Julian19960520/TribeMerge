"""Bounded pool of isolated, persistent Godot rule interpreters."""

import atexit
import json
import logging
import os
import queue
import shutil
import subprocess
import tempfile
import threading
from collections import deque
from pathlib import Path

from .config import REPO_DIR, get_settings
from .errors import ApiError

PREFIX = "TRIBE_REPLAY_RESPONSE "
MAX_RESPONSE = 2 * 1024 * 1024
logger = logging.getLogger("tribe.replay")


class ReplayProcess:
    """One leased process handles one request at a time; a failed lease is discarded."""

    def __init__(self, executable: str):
        self.executable = executable
        self.process = None
        self.directory = None
        self.responses = queue.Queue(maxsize=2)
        self.diagnostics = deque(maxlen=20)
        self.starts = 0

    def command(self, directory: str) -> list[str]:
        return [self.executable, "--headless", "--path", str(REPO_DIR), "--script",
                "res://scripts/replay/worker.gd", "--", "--replay-worker", "--replay-service", "--cloud-off",
                f"--save={directory}/unused.json", f"--cloud-state={directory}/cloud.json"]

    def _start(self) -> None:
        self.close()
        self.directory = tempfile.TemporaryDirectory(prefix="tribe-replay-")
        self.responses = queue.Queue(maxsize=2)
        self.diagnostics.clear()
        try:
            self.process = subprocess.Popen(self.command(self.directory.name), stdin=subprocess.PIPE,
                                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                            text=True, encoding="utf-8", bufsize=1,
                                            env={**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1"})
        except OSError as e:
            self.close()
            raise ApiError(503, "replay_unavailable", "无法启动存档校验进程") from e
        self.starts += 1
        threading.Thread(target=self._read, args=(self.process, self.responses), daemon=True,
                         name="tribe-replay-output").start()

    def _read(self, process, responses) -> None:
        try:
            while True:
                line = process.stdout.readline(MAX_RESPONSE + 1)
                if not line:
                    break
                if len(line) > MAX_RESPONSE:
                    raise ValueError("worker response too large")
                if "SCRIPT ERROR:" in line or line.startswith("ERROR:"):
                    self.diagnostics.append(line.rstrip()[:500])
                    raise ValueError("worker script failed")
                if line.startswith(PREFIX):
                    value = json.loads(line[len(PREFIX):])
                    if not isinstance(value, dict):
                        raise ValueError("worker response is not an object")
                    responses.put_nowait(value)
                else:
                    self.diagnostics.append(line.rstrip()[:500])
        except (OSError, ValueError, queue.Full) as e:
            failure = e
        else:
            failure = RuntimeError("worker exited")
        try:
            responses.put_nowait(failure)
        except queue.Full:
            pass

    def call(self, payload: dict, timeout: float) -> dict:
        if self.process is None or self.process.poll() is not None:
            self._start()
        try:
            self.process.stdin.write(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n")
            self.process.stdin.flush()
            result = self.responses.get(timeout=timeout)
            if isinstance(result, Exception):
                raise result
            if result.get("ok") and str(result.get("engine", "")).split("-", 1)[0] != "4.6.3":
                raise ApiError(503, "replay_engine_version", "存档校验引擎版本不匹配")
            return result
        except queue.Empty as e:
            self.close()
            raise ApiError(503, "replay_timeout", "存档校验超时，请稍后重试") from e
        except ApiError:
            self.close()
            raise
        except (OSError, ValueError, RuntimeError) as e:
            logger.error("Validation worker failed: %s; diagnostics=%s", e, list(self.diagnostics))
            self.close()
            raise ApiError(503, "replay_failed", "存档校验进程执行失败") from e

    def close(self) -> None:
        process, self.process = self.process, None
        if process is not None:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=1)
            for stream in (process.stdin, process.stdout):
                if stream:
                    stream.close()
        directory, self.directory = self.directory, None
        if directory is not None:
            directory.cleanup()


class ReplayPool:
    def __init__(self, executable: str, workers: int, waiting: int, queue_timeout: float, timeout: float):
        self.available = queue.Queue(maxsize=workers)
        self.processes = [ReplayProcess(executable) for _ in range(workers)]
        for process in self.processes:
            self.available.put_nowait(process)
        self.capacity = threading.BoundedSemaphore(workers + waiting)
        self.queue_timeout = queue_timeout
        self.timeout = timeout
        self._rules = ""
        self._rules_lock = threading.Lock()
        self.closed = False

    def run(self, payload: dict) -> dict:
        if self.closed or not self.capacity.acquire(blocking=False):
            raise ApiError(503, "replay_busy", "存档校验繁忙，请稍后重试", retry_after=1)
        process = None
        try:
            try:
                process = self.available.get(timeout=self.queue_timeout)
            except queue.Empty as e:
                raise ApiError(503, "replay_busy", "等待存档校验超时，请稍后重试", retry_after=1) from e
            if self.closed:
                raise ApiError(503, "replay_unavailable", "存档校验服务正在关闭")
            return process.call(payload, self.timeout)
        finally:
            if process is not None:
                self.available.put_nowait(process)
            self.capacity.release()

    def rules(self) -> str:
        if not self._rules:
            if not self._rules_lock.acquire(timeout=self.queue_timeout):
                raise ApiError(503, "replay_busy", "等待游戏规则初始化超时，请稍后重试", retry_after=1)
            try:
                if not self._rules:
                    result = self.run({"mode": "rules"})
                    if not result.get("ok") or not result.get("rules"):
                        raise ApiError(503, "replay_failed", "无法取得游戏规则版本")
                    self._rules = result["rules"]
            finally:
                self._rules_lock.release()
        return self._rules

    def close(self) -> None:
        self.closed = True
        for process in self.processes:
            process.close()


_pools: dict[tuple, ReplayPool] = {}
_pools_lock = threading.Lock()


def pool() -> ReplayPool:
    settings = get_settings()
    executable = settings.replay_godot or shutil.which("godot") or shutil.which("godot4")
    if not executable:
        raise ApiError(503, "replay_unavailable", "服务端未安装存档校验引擎")
    executable = shutil.which(executable) or executable
    key = (str(Path(executable).resolve()), settings.replay_workers, settings.replay_queue_limit,
           settings.replay_queue_timeout_sec, settings.replay_timeout_sec)
    with _pools_lock:
        if key not in _pools:
            _pools[key] = ReplayPool(*key)
        return _pools[key]


def run_worker(payload: dict) -> dict:
    return pool().run(payload)


def current_rules() -> str:
    return pool().rules()


def close_pools() -> None:
    with _pools_lock:
        pools = list(_pools.values())
        _pools.clear()
    for instance in pools:
        instance.close()


atexit.register(close_pools)
