"""Account projections, request idempotency and operational metadata."""

import hashlib
import json
import logging
from datetime import timedelta
from functools import lru_cache
from pathlib import Path

from sqlalchemy import delete

from . import clock
from .config import get_settings
from .errors import ApiError
from .logs import log
from .models import AuditLog, IdempotencyKey

logger = logging.getLogger("tribe")
IDEM_TTL = timedelta(days=2)


def today() -> str:
    return clock.day(None, get_settings().day_utc_offset_hours)


def stamp(out: dict) -> dict:
    return {**out, "now": clock.now(), "day": today()}


@lru_cache
def build_limits(data_dir: str) -> dict[str, int]:
    rows = json.loads((Path(data_dir) / "builds.json").read_text(encoding="utf-8"))
    return {row["id"]: len(row["parts"]) for row in rows}


def store_state(account, state: dict) -> None:
    account.state = state
    builds = state.get("builds", {})
    progress = sum(max(0, min(int(builds.get(key, 0)), maximum))
                   for key, maximum in build_limits(get_settings().data_dir).items())
    if progress > (account.rank_progress or 0):
        account.rank_progress = progress
        account.rank_reached_at = int(clock.now())


def summary(account, has_save: bool) -> dict:
    state = account.state or {}
    return {"level": state.get("level", 1), "parts": account.rank_progress, "amber": state.get("amber", 0),
            "has_save": has_save,
            "last_sync_at": account.last_sync_at.timestamp() if account.last_sync_at else None}


def audit(db, account_id: str, kind: str, detail: str) -> None:
    db.add(AuditLog(account_id=account_id, at=clock.utcnow(), kind=kind, detail=detail[:2000]))
    log(logger, logging.WARNING, "audit", kind=kind, detail=detail[:300], account_id=account_id)


def request_fingerprint(payload: dict) -> str:
    return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def idem_get(db, account_id: str, key: str, endpoint: str, fingerprint: str):
    row = db.get(IdempotencyKey, (account_id, key), populate_existing=True)
    if row is not None and (row.endpoint != endpoint or row.request_hash != fingerprint):
        raise ApiError(409, "idempotency_key_reused", "批次编号已用于其他操作")
    return row


def idem_put(db, account_id: str, key: str, endpoint: str, fingerprint: str, response: dict) -> None:
    db.add(IdempotencyKey(account_id=account_id, key=key, endpoint=endpoint, request_hash=fingerprint,
                          status=200, response=response, created_at=clock.utcnow()))


def idem_gc(db) -> None:
    db.execute(delete(IdempotencyKey).where(IdempotencyKey.created_at < clock.utcnow() - IDEM_TTL))
