"""限流：滑动窗口，按玩家和按 IP 各一套。

单进程内存实现。多实例部署时换成 Redis（同样的接口：hit(key, limit, window) -> 剩余秒数或 0）。
"""

import threading
import time
from collections import deque


class SlidingWindow:
    def __init__(self) -> None:
        self._hits: dict[str, deque] = {}
        self._lock = threading.Lock()
        self._last_gc = time.monotonic()

    def hit(self, key: str, limit: int, window: float = 60.0) -> float:
        """记一次。超限返回需要等待的秒数（> 0），没超限返回 0。"""
        if limit <= 0:
            return 0.0
        now = time.monotonic()
        with self._lock:
            q = self._hits.setdefault(key, deque())
            while q and q[0] <= now - window:
                q.popleft()
            if len(q) >= limit:
                return max(0.1, q[0] + window - now)
            q.append(now)
            if now - self._last_gc > 300:
                self._gc(now, window)
            return 0.0

    def _gc(self, now: float, window: float) -> None:
        self._last_gc = now
        for k in [k for k, q in self._hits.items() if not q or q[-1] <= now - window]:
            del self._hits[k]

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()


limiter = SlidingWindow()
