"""Authoritative command replay. No client snapshot is accepted by these endpoints."""
import json
import os
import secrets
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, Depends, Request
from pydantic import Field, ValidationError
from fastapi.exceptions import RequestValidationError
from sqlalchemy import update
from sqlalchemy.orm import Session

from . import clock, replay_wire
from .config import get_settings, REPO_DIR
from .db import get_db
from .errors import ApiError
from .models import Save
from .schemas import Req
from .security import Auth, current, lock_account
from .services import b64, pack, unpack_blob, stamp, store_state, audit, idem_get, idem_put

router = APIRouter(prefix="/v2", tags=["操作重放"])
COMMANDS = Literal["tick", "drop", "tap", "stash", "store", "inventory", "discard", "discard_finish", "undo",
                   "order", "craft", "rush", "boost", "energy", "expand", "build", "book", "level", "pack", "shop", "shop_view",
                   "hot_refresh", "shell_refresh", "bubble_buy", "bubble_reward", "pass", "daily", "seven", "choice",
                   "activity", "duel", "tiger", "race_join", "race_claim", "offer", "ufo", "ufo_refresh", "gift", "gm", "reset", "tutorial_finish"]


class Operation(Req):
    seq: int = Field(ge=1)
    at: int = Field(ge=0)
    name: COMMANDS
    args: dict = Field(default_factory=dict, max_length=8)


class SyncReq(Req):
    base: int = Field(ge=0)
    rules: str = Field(pattern=r"^[0-9a-f]{64}$")
    hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    batch: str = Field(pattern=r"^[0-9a-f]{32}$")
    ops: list[Operation] = Field(min_length=1, max_length=256)


async def parse_sync(request: Request) -> SyncReq:
    chunks = []
    size = 0
    async for chunk in request.stream():
        size += len(chunk)
        if size > replay_wire.MAX_COMPRESSED:
            raise ApiError(413, "too_big", "操作日志请求体太大")
        chunks.append(chunk)
    raw = b"".join(chunks)
    content_type = request.headers.get("content-type", "").split(";", 1)[0].strip().lower()
    encoding = request.headers.get("content-encoding", "").strip().lower()
    if content_type == replay_wire.MIME:
        if encoding != "gzip":
            raise ApiError(415, "unsupported_encoding", "操作日志需要 gzip 编码")
        try:
            payload = replay_wire.decode(replay_wire.inflate(raw))
        except replay_wire.WireError:
            raise ApiError(400, "invalid_replay_wire", "操作日志压缩包损坏或超出限制")
    elif content_type in ("application/json", "") and encoding in ("", "identity"):
        # Keep persisted in-flight requests and older clients compatible.
        try:
            payload = json.loads(raw)
        except (ValueError, UnicodeDecodeError):
            raise RequestValidationError([{"loc": ("body",), "msg": "Invalid JSON", "type": "json_invalid"}])
    else:
        raise ApiError(415, "unsupported_encoding", "不支持的操作日志编码")
    try:
        return SyncReq.model_validate(payload)
    except ValidationError as e:
        raise RequestValidationError(e.errors()) from e


def run_worker(payload: dict) -> dict:
    executable = get_settings().replay_godot or shutil.which("godot") or shutil.which("godot4")
    if not executable:
        raise ApiError(503, "replay_unavailable", "服务端未安装存档校验引擎")
    with tempfile.TemporaryDirectory(prefix="tribe-replay-") as tmp:
        root = Path(tmp)
        src, dst = root / "input.json", root / "output.json"
        src.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        try:
            completed = subprocess.run([
                executable, "--headless", "--path", str(REPO_DIR), "--script", "res://scripts/replay/worker.gd", "--",
                "--replay-worker", "--cloud-off", f"--save={root / 'unused.json'}", f"--input={src}", f"--output={dst}",
            ], capture_output=True, timeout=get_settings().replay_timeout_sec, check=False,
               env={**os.environ, "HOME": str(root), "GODOT_SILENCE_ROOT_WARNING": "1"})
        except (OSError, subprocess.TimeoutExpired):
            raise ApiError(503, "replay_unavailable", "存档校验暂时不可用")
        if completed.returncode or not dst.exists():
            raise ApiError(503, "replay_failed", "存档校验引擎执行失败")
        result = json.loads(dst.read_text(encoding="utf-8"))
        if result.get("ok") and not result.get("engine", "").startswith("4.6.3"):
            raise ApiError(503, "replay_engine_version", "存档校验引擎版本不匹配")
        return result


def response(sv: Save, st: dict, *, reset=False, reason="", include_data=True) -> dict:
    r = st["replay"]
    out = {"ok": True, "version": sv.version, "hash": r["hash"], "rules": r["rules"],
           "seq": r["seq"], "reset": reset, "reason": reason}
    if include_data:
        out["data"] = b64(sv.data)
    return stamp(out)


def commit_result(acc, sv, result, st):
    snap = result["data"]
    st.update({k: snap[k] for k in ("amber", "shells", "level", "xp", "builds", "cards") if k in snap})
    st["replay"] = {"hash": result["hash"], "rules": result["rules"], "seq": result["seq"], "at": snap["replay_meta"]["at"]}
    sv.data = pack(snap); sv.hash = result["hash"]; sv.saved_at = int(clock.now()); sv.version += 1
    acc.last_sync_at = clock.utcnow()
    store_state(acc, st)


@router.post("/session")
def session(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    acc = lock_account(db, auth.id)
    st = dict(acc.state or {})
    sv = db.get(Save, auth.id)
    if sv is None:
        sv = Save(account_id=auth.id, version=0, hash="", data=None, saved_at=0, energy=0, rush=0)
        db.add(sv)
    if "replay" not in st:
        snap = unpack_blob(sv.data)
        if snap:
            # Only a previously accepted SERVER snapshot can be migrated.
            snap["replay_rng"] = {"seed": secrets.token_hex(32), "streams": {}}
            snap["replay_meta"] = {"seq": 0, "at": int(clock.now()), "allow_gm": not get_settings().is_prod}
            result = run_worker({"mode": "load", "data": snap})
        else:
            result = run_worker({"mode": "new", "at": int(clock.now()), "player": auth.id, "seed": secrets.token_hex(32), "allow_gm": not get_settings().is_prod})
        if not result.get("ok"):
            raise ApiError(503, "replay_failed", "无法准备服务器存档")
        commit_result(acc, sv, result, st)
    db.commit()
    return response(sv, st)


@router.post("/sync")
def sync(req: SyncReq = Depends(parse_sync), auth: Auth = Depends(current), db: Session = Depends(get_db)):
    acc = lock_account(db, auth.id)
    st = dict(acc.state or {})
    sv = db.get(Save, auth.id)
    if not sv or "replay" not in st:
        raise ApiError(409, "session_required", "需要先取得服务器存档")
    endpoint = "replay.sync"
    hit = idem_get(db, auth.id, req.batch, endpoint)
    if hit is not None:
        return hit.response
    r = st["replay"]
    reason = ""
    if req.base != sv.version:
        reason = "云端存档版本已更新"
    elif req.rules != r["rules"]:
        reason = "游戏规则版本不一致"
    elif any(op.at > int(clock.now()) + 5 for op in req.ops):
        reason = "操作时间超出服务器时间"
    else:
        result = run_worker({"mode": "replay", "data": unpack_blob(sv.data), "ops": [op.model_dump() for op in req.ops]})
        if not result.get("ok"):
            reason = "操作未通过规则校验"
        elif result["rules"] != req.rules:
            raise ApiError(409, "rules_update_required", "服务器规则已更新，需要更新客户端")
        elif not secrets.compare_digest(result["hash"], req.hash):
            reason = "本地存档与操作重放结果不一致"
        else:
            # Compare-and-swap also protects SQLite/multiple server processes;
            # only one request may advance a particular confirmed version.
            changed = db.execute(update(Save).where(Save.account_id == acc.id, Save.version == req.base)
                                 .values(version=req.base + 1).execution_options(synchronize_session=False))
            if changed.rowcount != 1:
                db.rollback()
                current_save = db.get(Save, auth.id)
                current_account = lock_account(db, auth.id)
                return response(current_save, current_account.state, reset=True, reason="云端存档版本已更新")
            from .api_game import _backup
            s = get_settings()
            _backup(db, acc.id, sv, st, s.backups_recent, s.backups_daily_days)
            commit_result(acc, sv, result, st)
    if reason:
        audit(db, auth.id, "replay_reset", reason)
    out = response(sv, st, reset=bool(reason), reason=reason, include_data=bool(reason))
    idem_put(db, auth.id, req.batch, endpoint, 200, out)
    db.commit()
    return out
