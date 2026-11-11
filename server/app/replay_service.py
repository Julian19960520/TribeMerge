"""Read confirmed state, replay outside the transaction, then compare-and-swap."""

import secrets
from datetime import timezone

from sqlalchemy import update

from . import clock, replay_engine
from .config import get_settings
from .errors import ApiError
from .models import AuthSession, Save
from .security import lock_account
from .services import audit, idem_gc, idem_get, idem_put, request_fingerprint, stamp, store_state
from .snapshots import b64, backup, pack, unpack_blob

ENDPOINT = "replay.sync"


def _write_start(db) -> None:
    # SQLite has no SELECT FOR UPDATE. Acquire its short write transaction before
    # reading the commit point, avoiding a deferred read-to-write upgrade race.
    if db.get_bind().dialect.name == "sqlite":
        db.connection().exec_driver_sql("BEGIN IMMEDIATE")


def _account(db, account_id: str, token_hash: str):
    account = lock_account(db, account_id)
    session = db.get(AuthSession, token_hash, populate_existing=True)
    if session is None or session.account_id != account_id:
        raise ApiError(401, "unauthorized", "登录凭证无效")
    if session.revoked_at is not None:
        reason = "session_replaced" if session.revoke_reason == "replaced" else "session_revoked"
        raise ApiError(401, reason, "登录会话已失效")
    expires = session.expires_at
    if (expires if expires.tzinfo else expires.replace(tzinfo=timezone.utc)) <= clock.utcnow():
        raise ApiError(401, "token_expired", "登录已过期")
    if account.disabled:
        raise ApiError(403, "account_disabled", "账号不可用")
    return account


def response(save, state: dict, *, reset=False, reason="", include_data=True) -> dict:
    replay = state["replay"]
    out = {"ok": True, "version": save.version, "hash": replay["hash"], "rules": replay["rules"],
           "seq": replay["seq"], "reset": reset, "reason": reason}
    if include_data:
        out["data"] = b64(save.data)
    return stamp(out)


def commit_result(account, save, result) -> None:
    snapshot = result["data"]
    state = {key: snapshot[key] for key in ("amber", "shells", "level", "xp", "builds", "cards")}
    state["replay"] = {"hash": result["hash"], "rules": result["rules"], "seq": result["seq"],
                       "at": snapshot["replay_meta"]["at"]}
    save.data = pack(snapshot)
    save.hash = result["hash"]
    save.saved_at = int(clock.now())
    save.version += 1
    account.last_sync_at = clock.utcnow()
    store_state(account, state)


def session(auth, db) -> dict:
    account_id, token_hash = auth.id, auth.session.token_hash
    save = db.get(Save, account_id)
    saved_version = save.version if save else None
    db.rollback()
    current_rules = replay_engine.current_rules()
    result = None
    if saved_version is None:
        result = replay_engine.run_worker({"mode": "new", "at": int(clock.now()), "player": account_id,
                                           "seed": secrets.token_hex(32), "allow_gm": not get_settings().is_prod})
        if not result.get("ok") or result.get("rules") != current_rules:
            raise ApiError(503, "replay_failed", "无法准备服务器存档")
    _write_start(db)
    account = _account(db, account_id, token_hash)
    save = db.get(Save, account_id, populate_existing=True)
    if save is None:
        if result is None:
            raise ApiError(409, "session_required", "存档状态已变化，请重新登录")
        save = Save(account_id=account_id, version=0, hash="", data=None, saved_at=0)
        db.add(save)
        commit_result(account, save, result)
    if (account.state or {}).get("replay", {}).get("rules") != current_rules:
        raise ApiError(409, "rules_update_required", "游戏规则已更新，需要使用当前版本")
    out = response(save, account.state)
    db.commit()
    return out


def sync(request, auth, db) -> dict:
    account_id, token_hash = auth.id, auth.session.token_hash
    fingerprint = request_fingerprint(request.model_dump())
    hit = idem_get(db, account_id, request.batch, ENDPOINT, fingerprint)
    if hit is not None:
        return hit.response
    save = db.get(Save, account_id)
    if save is None:
        raise ApiError(409, "session_required", "需要先取得服务器存档")
    expected_version, snapshot = save.version, bytes(save.data)
    saved_rules = auth.account.state.get("replay", {}).get("rules")
    # All CPU work, process startup and queue waiting happen after releasing DB
    # resources. Authentication is checked again at the actual commit point.
    db.rollback()
    current_rules = replay_engine.current_rules()
    if request.rules != current_rules or saved_rules != current_rules:
        raise ApiError(409, "rules_update_required", "游戏规则版本不一致，请更新客户端")
    reason, result = "", None
    if request.base != expected_version:
        reason = "云端存档版本已更新"
    elif any(operation.at > int(clock.now()) + 5 for operation in request.ops):
        reason = "操作时间超出服务器时间"
    else:
        result = replay_engine.run_worker({"mode": "replay", "data": unpack_blob(snapshot),
                                           "ops": [operation.model_dump() for operation in request.ops]})
        if not result.get("ok"):
            reason = "操作未通过规则校验"
        elif result.get("rules") != current_rules:
            raise ApiError(409, "rules_update_required", "服务器规则已更新，请重试")
        elif not secrets.compare_digest(result["hash"], request.hash):
            reason = "本地存档与操作重放结果不一致"
    _write_start(db)
    account = _account(db, account_id, token_hash)
    hit = idem_get(db, account_id, request.batch, ENDPOINT, fingerprint)
    if hit is not None:
        db.rollback()
        return hit.response
    save = db.get(Save, account_id, populate_existing=True)
    if save is None:
        raise ApiError(409, "session_required", "需要先取得服务器存档")
    if save.version != expected_version or request.base != save.version:
        reason = "云端存档版本已更新"
    if not reason:
        changed = db.execute(update(Save).where(Save.account_id == account_id, Save.version == request.base)
                             .values(version=Save.version + 1).execution_options(synchronize_session=False))
        if changed.rowcount != 1:
            db.rollback()
            raise ApiError(409, "save_conflict", "存档已更新，请重新同步")
        backup(db, account_id, save, account.state)
        commit_result(account, save, result)
    else:
        audit(db, account_id, "replay_reset", reason)
    out = response(save, account.state, reset=bool(reason), reason=reason, include_data=bool(reason))
    idem_gc(db)
    idem_put(db, account_id, request.batch, ENDPOINT, fingerprint, out)
    db.commit()
    return out
