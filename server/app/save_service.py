"""Whole-snapshot cloud saves. The client runs the game; the server stores, backs up and audits.

Conflict rule: one account has one active session at a time, so a save written by
another device since the client's base version means the player moved devices —
the client adopts the cloud copy. A save written by this same device is always
older than what the device holds now (e.g. a lost response), so it is overwritten.
"""

import base64
import binascii
import hashlib
import json
import zlib
from datetime import timezone

from . import clock, plausibility
from .config import get_settings
from .errors import ApiError
from .models import AuthSession, Save
from .security import lock_account
from .services import audit, stamp, store_state
from .snapshots import b64, backup

SUMMARY_FIELDS = ("amber", "shells", "level", "xp", "builds", "cards")


def writer_of(session: AuthSession) -> str:
    return session.device_id or ("session:" + session.token_hash[:56])


def _write_start(db) -> None:
    # SQLite has no SELECT FOR UPDATE; take the write lock before reading the version.
    if db.get_bind().dialect.name == "sqlite":
        db.connection().exec_driver_sql("BEGIN IMMEDIATE")


def _account(db, account_id: str, token_hash: str):
    account = lock_account(db, account_id)
    session = db.get(AuthSession, token_hash, populate_existing=True)
    if session is None or session.account_id != account_id:
        raise ApiError(401, "unauthorized", "登录凭证无效")
    if session.revoked_at is not None:
        raise ApiError(401, "session_replaced" if session.revoke_reason == "replaced" else "session_revoked", "登录会话已失效")
    expires = session.expires_at
    if (expires if expires.tzinfo else expires.replace(tzinfo=timezone.utc)) <= clock.utcnow():
        raise ApiError(401, "token_expired", "登录已过期")
    if account.disabled:
        raise ApiError(403, "account_disabled", "账号不可用")
    return account, session


def _inflate(blob: bytes, limit: int) -> bytes:
    try:
        inflater = zlib.decompressobj(16 + zlib.MAX_WBITS)
        raw = inflater.decompress(blob, limit + 1)
    except zlib.error as e:
        raise ApiError(422, "invalid_save", "存档数据损坏") from e
    if len(raw) > limit or inflater.unconsumed_tail:
        raise ApiError(413, "save_too_big", "存档太大")
    if not inflater.eof:
        raise ApiError(422, "invalid_save", "存档数据不完整")
    return raw


def _parse(raw: bytes) -> dict:
    try:
        snapshot = json.loads(raw)
    except (UnicodeDecodeError, ValueError) as e:
        raise ApiError(422, "invalid_save", "存档格式错误") from e
    if not isinstance(snapshot, dict) or snapshot.get("schema") != 1:
        raise ApiError(422, "invalid_save", "存档版本不支持")
    for key in ("level", "xp", "amber", "shells"):
        if not isinstance(snapshot.get(key), (int, float)) or isinstance(snapshot.get(key), bool):
            raise ApiError(422, "invalid_save", "存档缺少字段")
    for key in ("builds", "cards"):
        if not isinstance(snapshot.get(key), dict):
            raise ApiError(422, "invalid_save", "存档缺少字段")
    return snapshot


def session(auth, db) -> dict:
    save = db.get(Save, auth.id)
    has = bool(save and save.data)
    return stamp({"ok": True, "version": save.version if save else 0, "hash": save.hash if has else "",
                  "data": b64(save.data) if has else "", "mine": has and save.writer == writer_of(auth.session)})


def upload(request, auth, db) -> dict:
    try:
        blob = base64.b64decode(request.data, validate=True)
    except (binascii.Error, ValueError) as e:
        raise ApiError(422, "invalid_save", "存档编码错误") from e
    raw = _inflate(blob, get_settings().save_max_raw_bytes)
    if hashlib.sha256(raw).hexdigest() != request.hash:
        raise ApiError(422, "save_hash_mismatch", "存档校验失败")
    snapshot = _parse(raw)
    db.rollback()
    _write_start(db)
    account, session_row = _account(db, auth.id, auth.session.token_hash)
    writer = writer_of(session_row)
    save = db.get(Save, account.id, populate_existing=True)
    if save is None:
        save = Save(account_id=account.id, version=0, hash="", data=None, saved_at=0, writer="")
        db.add(save)
    if save.data and save.version != request.base and save.writer != writer:
        out = stamp({"ok": True, "conflict": True, "version": save.version, "hash": save.hash, "data": b64(save.data)})
        db.rollback()
        return out
    if save.data and save.hash == request.hash:
        out = stamp({"ok": True, "conflict": False, "version": save.version, "hash": save.hash})
        db.rollback()
        return out
    previous = dict(account.state or {})
    now = clock.now()
    since = previous.get("saved_at") or account.created_at.replace(tzinfo=timezone.utc).timestamp()
    reasons = plausibility.check(previous, snapshot, now - float(since))
    backup(db, account.id, save, previous)
    save.data = blob
    save.hash = request.hash
    save.version += 1
    save.writer = writer
    save.saved_at = int(now)
    account.last_sync_at = clock.utcnow()
    state = {key: snapshot[key] for key in SUMMARY_FIELDS}
    state["saved_at"] = save.saved_at
    store_state(account, state)
    if reasons:
        account.flagged = True
        account.flag_reason = "; ".join(reasons)[:200]
        audit(db, account.id, "save_flagged", f"v{save.version}: " + "; ".join(reasons))
    out = stamp({"ok": True, "conflict": False, "version": save.version, "hash": save.hash})
    db.commit()
    return out
