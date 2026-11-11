"""账号与登录：游客注册、续期、退出、账号转移码、第三方渠道绑定 / 登录。"""

import logging
import secrets
from datetime import timedelta, timezone

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import clock, providers
from .config import get_settings
from .db import get_db
from .errors import ApiError
from .logs import log
from .models import Account, AuthSession, Identity, Save
from .ratelimit import limiter
from .schemas import AccountResp, GuestReq, ProviderReq, Resp, SessionResp, TransferCodeResp, TransferLoginReq
from .security import Auth, current, hash_secret, lock_account, new_session, same_secret
from .services import stamp, summary

router = APIRouter(prefix="/v1", tags=["账号"])
logger = logging.getLogger("tribe.auth")

# 转移码字母表：去掉容易看错的 0/O/1/I/L
CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"


def _ip(request: Request) -> str:
    if get_settings().trust_forwarded:
        fwd = request.headers.get("x-forwarded-for", "")
        if fwd:
            return fwd.split(",")[0].strip()
    return request.client.host if request.client else "?"


def _guard(request: Request, what: str, per_min: int) -> None:
    wait = limiter.hit("%s:%s" % (what, _ip(request)), per_min)
    if wait > 0:
        raise ApiError(429, "rate_limited", "操作太频繁，请稍后再试", retry_after=wait)


def _new_id(db: Session) -> str:
    for _ in range(20):
        pid = "TRB%08d" % secrets.randbelow(10 ** 8)
        if db.get(Account, pid) is None:
            return pid
    raise ApiError(503, "id_exhausted", "暂时无法创建账号")


def _cloud(db: Session, acc: Account) -> dict:
    sv = db.get(Save, acc.id)
    return summary(acc, bool(sv and sv.data))


@router.post("/auth/guest", response_model=SessionResp)
def guest(req: GuestReq, request: Request, db: Session = Depends(get_db)):
    """Create a server-issued identity; gameplay starts through /v2/session."""
    _guard(request, "guest", 20)
    pid = _new_id(db)
    st = {}
    acc = Account(id=pid, created_at=clock.utcnow(), state=st, nick="")
    db.add(acc)
    db.flush()
    sess = new_session(db, pid, req.device_id)
    db.commit()
    log(logger, logging.INFO, "guest created", account_id=pid)
    return stamp({"ok": True, "account_id": pid, "created": True, **sess})


@router.post("/auth/refresh", response_model=SessionResp)
def refresh(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """续期：发新 token，作废当前这个。不影响其他设备（本来也只有这一台在线）。"""
    lock_account(db, auth.id)
    sess = db.get(AuthSession, auth.session.token_hash)
    sess.revoked_at = clock.utcnow()
    sess.revoke_reason = "refreshed"
    out = new_session(db, auth.id, sess.device_id, exclusive=False)
    db.commit()
    return stamp({"ok": True, "account_id": auth.id, **out})


@router.post("/auth/logout", response_model=Resp)
def logout(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    lock_account(db, auth.id)
    sess = db.get(AuthSession, auth.session.token_hash)
    sess.revoked_at = clock.utcnow()
    sess.revoke_reason = "logout"
    db.commit()
    return stamp({"ok": True})


@router.post("/auth/transfer", response_model=SessionResp)
def transfer_login(req: TransferLoginReq, request: Request, db: Session = Depends(get_db)):
    """用「账号 ID + 转移码」在新设备登录。输错 transfer_max_fails 次锁定一段时间；同 IP 也限流。"""
    s = get_settings()
    _guard(request, "transfer", 10)
    acc = db.execute(select(Account).where(Account.id == req.account_id).with_for_update()).scalar_one_or_none()
    if acc is None or not acc.transfer_hash:
        raise ApiError(401, "bad_transfer_code", "账号或转移码不对")
    now = clock.utcnow()
    lu = acc.transfer_locked_until
    if lu is not None and (lu if lu.tzinfo else lu.replace(tzinfo=timezone.utc)) > now:
        raise ApiError(429, "transfer_locked", "输错次数太多，请稍后再试",
                       retry_after=((lu if lu.tzinfo else lu.replace(tzinfo=timezone.utc)) - now).total_seconds())
    code = req.code.strip().upper().replace("-", "")
    if not same_secret(hash_secret(code, acc.id), acc.transfer_hash):
        acc.transfer_fails = (acc.transfer_fails or 0) + 1
        if acc.transfer_fails >= s.transfer_max_fails:
            acc.transfer_fails = 0
            acc.transfer_locked_until = now + timedelta(minutes=s.transfer_lock_minutes)
        db.commit()
        log(logger, logging.WARNING, "transfer code mismatch", account_id=acc.id)
        raise ApiError(401, "bad_transfer_code", "账号或转移码不对")
    acc.transfer_fails = 0
    acc.transfer_locked_until = None
    sess = new_session(db, acc.id, req.device_id)
    db.commit()
    log(logger, logging.INFO, "transfer login", account_id=acc.id)
    return stamp({"ok": True, "account_id": acc.id, "cloud": _cloud(db, acc), **sess})


@router.post("/auth/provider", response_model=SessionResp)
def provider_login(req: ProviderReq, request: Request, db: Session = Depends(get_db)):
    """用已绑定的第三方渠道登录。没绑定过返回 404 not_bound（客户端照常用游客号，再去设置里绑定）。"""
    _guard(request, "provider", 20)
    subject = providers.get(req.provider).verify(req.credential)
    ident = db.get(Identity, (req.provider, subject))
    if ident is None:
        raise ApiError(404, "not_bound", "这个账号还没有绑定游戏进度")
    acc = db.get(Account, ident.account_id)
    sess = new_session(db, acc.id, req.device_id)
    db.commit()
    log(logger, logging.INFO, "provider login", account_id=acc.id, provider=req.provider)
    return stamp({"ok": True, "account_id": acc.id, "cloud": _cloud(db, acc), **sess})


@router.get("/account", response_model=AccountResp)
def account(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    binds = db.execute(select(Identity.provider).where(Identity.account_id == auth.id)).scalars().all()
    acc = auth.account
    exp = auth.session.expires_at
    return stamp({"ok": True, "account_id": acc.id, "bindings": sorted(binds), "has_transfer_code": bool(acc.transfer_hash),
                  "last_sync_at": acc.last_sync_at.timestamp() if acc.last_sync_at else None,
                  "created_at": acc.created_at.timestamp(),
                  "session_expires_at": (exp if exp.tzinfo else exp.replace(tzinfo=timezone.utc)).timestamp()})


@router.post("/account/transfer-code", response_model=TransferCodeResp)
def make_transfer_code(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """生成（或重新生成）转移码。只在这次返回明文，服务器只存哈希；旧码立即失效。"""
    code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(10))
    acc = db.get(Account, auth.id)
    acc.transfer_hash = hash_secret(code, acc.id)
    acc.transfer_fails = 0
    acc.transfer_locked_until = None
    db.commit()
    return stamp({"ok": True, "account_id": acc.id, "code": code[:5] + "-" + code[5:]})


@router.post("/account/bind", response_model=Resp)
def bind(req: ProviderReq, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    subject = providers.get(req.provider).verify(req.credential)
    ident = db.get(Identity, (req.provider, subject))
    if ident is not None and ident.account_id != auth.id:
        raise ApiError(409, "bound_elsewhere", "这个账号已经绑定了别的游戏进度")
    if ident is None:
        db.add(Identity(provider=req.provider, subject=subject, account_id=auth.id, created_at=clock.utcnow()))
        db.commit()
    return stamp({"ok": True, "provider": req.provider})
