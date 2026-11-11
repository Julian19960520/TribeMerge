"""表结构。改动后用 `alembic revision --autogenerate` 生成迁移。"""

from datetime import datetime

from sqlalchemy import (JSON, BigInteger, Boolean, DateTime, ForeignKey, Index, Integer, LargeBinary, String, Text)
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class Account(Base):
    """Account identity and a summary of the last uploaded snapshot."""

    __tablename__ = "accounts"
    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    state: Mapped[dict] = mapped_column(JSON, default=dict)
    # 账号转移码（只存哈希），以及输错计数 / 锁定
    transfer_hash: Mapped[str | None] = mapped_column(String(128), nullable=True)
    transfer_fails: Mapped[int] = mapped_column(Integer, default=0)
    transfer_locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # 排行榜：服务器自己从 state.builds 算的进度
    nick: Mapped[str] = mapped_column(String(32), default="")
    rank_progress: Mapped[int] = mapped_column(Integer, default=0)
    rank_reached_at: Mapped[float] = mapped_column(BigInteger, default=0)
    last_sync_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    disabled: Mapped[bool] = mapped_column(Boolean, default=False)
    # 上传存档的合理性检查没通过：不封号，只移出排行榜并留审计记录
    flagged: Mapped[bool] = mapped_column(Boolean, default=False)
    flag_reason: Mapped[str] = mapped_column(String(200), default="")

    __table_args__ = (Index("ix_accounts_rank", "rank_progress", "rank_reached_at", "id"),)


class AuthSession(Base):
    """登录会话。token 只存哈希；同一账号同一时间只有一个有效会话（新设备登录会顶掉旧的）。"""

    __tablename__ = "sessions"
    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    device_id: Mapped[str] = mapped_column(String(64), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoke_reason: Mapped[str] = mapped_column(String(32), default="")


class Identity(Base):
    """第三方登录渠道绑定：(provider, subject) → 账号。"""

    __tablename__ = "identities"
    provider: Mapped[str] = mapped_column(String(32), primary_key=True)
    subject: Mapped[str] = mapped_column(String(128), primary_key=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Save(Base):
    """每个账号的最新存档快照（gzip 后的 JSON）。"""

    __tablename__ = "saves"
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), primary_key=True)
    version: Mapped[int] = mapped_column(Integer, default=0)
    hash: Mapped[str] = mapped_column(String(64), default="")
    data: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    # 上传时的服务器时间
    saved_at: Mapped[float] = mapped_column(BigInteger, default=0)
    # 最后写入的设备（换设备判断存档冲突用）
    writer: Mapped[str] = mapped_column(String(64), default="")


class SaveBackup(Base):
    """备份：kind=recent 留最近 N 份，kind=daily 每天一份。"""

    __tablename__ = "save_backups"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(8))
    day: Mapped[str] = mapped_column(String(10), default="")
    version: Mapped[int] = mapped_column(Integer)
    data: Mapped[bytes] = mapped_column(LargeBinary)
    state: Mapped[dict] = mapped_column(JSON, default=dict)
    saved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class IdempotencyKey(Base):
    """幂等键：同一个键重复请求，直接返回第一次的结果，不会重复扣款 / 发奖。"""

    __tablename__ = "idempotency_keys"
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), primary_key=True)
    key: Mapped[str] = mapped_column(String(80), primary_key=True)
    endpoint: Mapped[str] = mapped_column(String(64))
    request_hash: Mapped[str] = mapped_column(String(64))
    status: Mapped[int] = mapped_column(Integer)
    response: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class AuditLog(Base):
    """Save plausibility flags and other account audit events."""

    __tablename__ = "audit_log"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    account_id: Mapped[str] = mapped_column(String(32), index=True)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    kind: Mapped[str] = mapped_column(String(32))
    detail: Mapped[str] = mapped_column(Text)
