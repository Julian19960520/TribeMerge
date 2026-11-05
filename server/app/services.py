"""接口共用的东西：经济规则实例、读写 state、幂等键、快照打包。"""

import base64
import copy
import json
import logging
import zlib
from datetime import timedelta
from functools import lru_cache

from fastapi import Request
from sqlalchemy import delete
from sqlalchemy.orm import Session

from . import clock
from .config import get_settings
from .economy import Economy
from .errors import ApiError
from .gamedata import GameData
from .logs import log
from .models import Account, AuditLog, IdempotencyKey

logger = logging.getLogger("tribe")


@lru_cache
def gamedata() -> GameData:
    return GameData(get_settings().data_dir)


@lru_cache
def economy_cfg() -> dict:
    with open(get_settings().economy_config, encoding="utf-8") as f:
        return json.load(f)


def economy() -> Economy:
    gd = gamedata()
    gd.reload()
    return Economy(gd, economy_cfg(), today)


def today() -> str:
    return clock.day(None, get_settings().day_utc_offset_hours)


def stamp(out: dict) -> dict:
    out["now"] = clock.now()
    out["day"] = today()
    return out


def load_state(acc: Account) -> dict:
    """拿一份可以改的 state（JSON 列要整份赋值回去才会写库）。"""
    st = copy.deepcopy(acc.state or {})
    if not st:
        st = economy().new_state()
    st.setdefault("done", {})
    st.setdefault("credits", {"chest": 0, "pack": 0})
    st.setdefault("budget", {})
    return st


def store_state(acc: Account, st: dict) -> None:
    acc.state = st
    progress = gamedata().rank_progress(st.get("builds") or {})
    if progress > (acc.rank_progress or 0):
        acc.rank_progress = progress
        acc.rank_reached_at = int(clock.now())


def audit(db: Session, account_id: str, kind: str, detail: str) -> None:
    db.add(AuditLog(account_id=account_id, at=clock.utcnow(), kind=kind, detail=detail[:2000]))
    log(logger, logging.WARNING, "audit", kind=kind, detail=detail[:300], account_id=account_id)


# ---------------------------------------------------------------- 幂等

IDEM_TTL = timedelta(days=2)


def idem_key(request: Request) -> str:
    k = request.headers.get("idempotency-key", "").strip()
    if not k or len(k) > 80:
        raise ApiError(400, "idempotency_key_required", "这个操作需要 Idempotency-Key 请求头")
    return k


def idem_get(db: Session, account_id: str, key: str, endpoint: str):
    row = db.get(IdempotencyKey, (account_id, key))
    if row is None:
        return None
    if row.endpoint != endpoint:
        raise ApiError(409, "idempotency_key_reused", "这个 Idempotency-Key 已经用在别的操作上")
    return row


def idem_put(db: Session, account_id: str, key: str, endpoint: str, status: int, resp: dict) -> None:
    db.add(IdempotencyKey(account_id=account_id, key=key, endpoint=endpoint, status=status, response=resp,
                          created_at=clock.utcnow()))


def idem_gc(db: Session) -> None:
    db.execute(delete(IdempotencyKey).where(IdempotencyKey.created_at < clock.utcnow() - IDEM_TTL))


# ---------------------------------------------------------------- 快照

def unpack(b64: str) -> tuple[bytes, dict]:
    try:
        raw = base64.b64decode(b64, validate=True)
    except (ValueError, TypeError):
        raise ApiError(400, "bad_data", "快照不是 base64")
    if len(raw) > 64 * 1024:
        raise ApiError(413, "too_big", "快照太大")
    try:
        d = zlib.decompressobj(47)
        txt = d.decompress(raw, 256 * 1024)
        if d.unconsumed_tail:
            raise ApiError(413, "too_big", "快照解压后太大")
        snap = json.loads(txt.decode("utf-8"))
    except (zlib.error, ValueError, UnicodeDecodeError):
        raise ApiError(400, "bad_data", "快照解不开")
    if not isinstance(snap, dict) or not isinstance(snap.get("board"), list):
        raise ApiError(400, "bad_data", "快照格式不对")
    return raw, snap


def pack(snap: dict) -> bytes:
    import gzip
    return gzip.compress(json.dumps(snap, ensure_ascii=False, separators=(",", ":")).encode("utf-8"), 6)


def unpack_blob(blob: bytes | None) -> dict | None:
    if not blob:
        return None
    return json.loads(zlib.decompress(blob, 47).decode("utf-8"))


def b64(blob: bytes | None) -> str:
    return base64.b64encode(blob).decode("ascii") if blob else ""


def summary(acc: Account, snap: dict | None) -> dict:
    st = acc.state or {}
    return {"level": st.get("level", 1), "parts": acc.rank_progress, "amber": st.get("amber", 0),
            "has_save": snap is not None, "last_sync_at": acc.last_sync_at.timestamp() if acc.last_sync_at else None}
