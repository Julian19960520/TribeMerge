"""鉴权：随机 token（Bearer），库里只存哈希；有效期 + 续期；同一账号同时只有一个有效会话。"""

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Depends, Request
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from . import clock
from .config import get_settings
from .db import get_db
from .errors import ApiError
from .logs import account_var
from .models import Account, AuthSession
from .ratelimit import limiter


def hash_token(token: str) -> str:
    pepper = get_settings().token_pepper.encode("utf-8")
    return hmac.new(pepper, token.encode("utf-8"), hashlib.sha256).hexdigest()


def hash_secret(secret: str, salt: str) -> str:
    """转移码之类的短密码：PBKDF2，带账号做盐，慢一点防离线爆破。"""
    pepper = get_settings().token_pepper.encode("utf-8")
    return hashlib.pbkdf2_hmac("sha256", secret.encode("utf-8"), pepper + salt.encode("utf-8"), 120_000).hex()


def new_session(db: Session, account_id: str, device_id: str, *, exclusive: bool = True) -> dict:
    """发一个新 token。exclusive=True 时顶掉这个账号的其他会话（换设备登录）。"""
    # Session changes and replay commits share the account lock: a new device
    # cannot revoke a token between its final validation and snapshot commit.
    lock_account(db, account_id)
    s = get_settings()
    now = clock.utcnow()
    if exclusive:
        db.execute(
            update(AuthSession)
            .where(AuthSession.account_id == account_id, AuthSession.revoked_at.is_(None))
            .values(revoked_at=now, revoke_reason="replaced")
        )
    token = secrets.token_urlsafe(32)
    exp = now + timedelta(days=s.token_ttl_days)
    db.add(AuthSession(token_hash=hash_token(token), account_id=account_id, device_id=device_id[:64],
                       created_at=now, expires_at=exp))
    return {"token": token, "expires_at": exp.timestamp(), "renew_after": (exp - timedelta(days=s.token_renew_days)).timestamp()}


def _bearer(request: Request) -> str:
    h = request.headers.get("authorization", "")
    if not h.lower().startswith("bearer "):
        raise ApiError(401, "unauthorized", "缺少登录凭证")
    return h[7:].strip()


class Auth:
    def __init__(self, account: Account, session: AuthSession, token: str):
        self.account = account
        self.session = session
        self.token = token

    @property
    def id(self) -> str:
        return self.account.id


def current(request: Request, db: Session = Depends(get_db)) -> Auth:
    token = _bearer(request)
    sess = db.get(AuthSession, hash_token(token))
    if sess is None:
        raise ApiError(401, "unauthorized", "登录凭证无效")
    if sess.revoked_at is not None:
        if sess.revoke_reason == "replaced":
            raise ApiError(401, "session_replaced", "账号已在其他设备登录")
        raise ApiError(401, "session_revoked", "已退出登录")
    exp = sess.expires_at if sess.expires_at.tzinfo else sess.expires_at.replace(tzinfo=timezone.utc)
    if exp <= clock.utcnow():
        raise ApiError(401, "token_expired", "登录已过期")
    wait = limiter.hit("acc:" + sess.account_id, get_settings().rate_player_per_min)
    if wait > 0:
        raise ApiError(429, "rate_limited", "操作太频繁，请稍后再试", retry_after=wait)
    acc = db.get(Account, sess.account_id)
    if acc is None or acc.disabled:
        raise ApiError(403, "account_disabled", "账号不可用")
    account_var.set(acc.id)
    return Auth(acc, sess, token)


def lock_account(db: Session, account_id: str) -> Account:
    """读账号并加行锁（PostgreSQL 上是 SELECT ... FOR UPDATE；SQLite 整库串行写，不需要）。"""
    acc = db.execute(select(Account).where(Account.id == account_id).with_for_update().execution_options(populate_existing=True)).scalar_one_or_none()
    if acc is None:
        raise ApiError(404, "unknown_account", "账号不存在")
    return acc


def same_secret(a: str, b: str) -> bool:
    return hmac.compare_digest(a, b)
