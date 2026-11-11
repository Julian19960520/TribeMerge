"""Confirmed snapshot packing and bounded recovery history."""

import base64
import gzip
import json

from sqlalchemy import delete, select

from . import clock
from .config import get_settings
from .models import SaveBackup


def pack(snapshot: dict) -> bytes:
    return gzip.compress(json.dumps(snapshot, ensure_ascii=False, separators=(",", ":")).encode("utf-8"), 6)


def unpack_blob(blob: bytes | None) -> dict | None:
    return json.loads(gzip.decompress(blob)) if blob else None


def b64(blob: bytes | None) -> str:
    return base64.b64encode(blob).decode("ascii") if blob else ""


def backup(db, account_id: str, save, state: dict) -> None:
    settings = get_settings()
    if not save.data:
        return
    now = clock.utcnow()
    day = clock.day(None, settings.day_utc_offset_hours)
    if settings.backups_recent:
        db.add(SaveBackup(account_id=account_id, kind="recent", day=day, version=save.version,
                          data=save.data, state=state, saved_at=now))
        db.flush()
        keep = select(SaveBackup.id).where(SaveBackup.account_id == account_id, SaveBackup.kind == "recent").order_by(
            SaveBackup.version.desc()).limit(settings.backups_recent)
        db.execute(delete(SaveBackup).where(SaveBackup.account_id == account_id, SaveBackup.kind == "recent",
                                           SaveBackup.id.not_in(keep.scalar_subquery())))
    if settings.backups_daily_days:
        has_day = db.scalar(select(SaveBackup.id).where(SaveBackup.account_id == account_id,
                                                       SaveBackup.kind == "daily", SaveBackup.day == day).limit(1))
        if has_day is None:
            db.add(SaveBackup(account_id=account_id, kind="daily", day=day, version=save.version,
                              data=save.data, state=state, saved_at=now))
        cutoff = clock.day(clock.now() - settings.backups_daily_days * 86400, settings.day_utc_offset_hours)
        db.execute(delete(SaveBackup).where(SaveBackup.account_id == account_id, SaveBackup.kind == "daily",
                                           SaveBackup.day < cutoff))
