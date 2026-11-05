"""服务器时间。所有「今天」「冷却」「体力回复」都以这里为准，不信任客户端的时间。测试可以拨 offset。"""

import time
from datetime import datetime, timezone

offset = 0.0


def now() -> float:
    return time.time() + offset


def utcnow() -> datetime:
    return datetime.fromtimestamp(now(), tz=timezone.utc)


def day(t: float | None = None, utc_offset_hours: int = 8) -> str:
    if t is None:
        t = now()
    return time.strftime("%Y-%m-%d", time.gmtime(t + utc_offset_hours * 3600))


def secs_to_midnight(utc_offset_hours: int = 8) -> int:
    return 86400 - int(now() + utc_offset_hours * 3600) % 86400
