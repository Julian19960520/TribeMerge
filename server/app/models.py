"""表结构。改动后用 `alembic revision --autogenerate` 生成迁移。"""

from datetime import datetime

from sqlalchemy import (JSON, BigInteger, Boolean, DateTime, Float, ForeignKey, Index, Integer, LargeBinary, String, Text,
                        UniqueConstraint)
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class Account(Base):
    """一个玩家账号。id 就是游戏里的 player_id。state 是服务器说了算的那部分存档（货币、建造、通行证……）。"""

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
    # 上一份快照的服务器时间（体力回复校验用）
    saved_at: Mapped[float] = mapped_column(BigInteger, default=0)
    energy: Mapped[int] = mapped_column(Integer, default=0)
    rush: Mapped[int] = mapped_column(Integer, default=0)


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


class HotDeal(Base):
    __tablename__ = "hot_deals"
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), primary_key=True)
    day: Mapped[str] = mapped_column(String(10), primary_key=True)
    picks: Mapped[list] = mapped_column(JSON)
    rolled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class IdempotencyKey(Base):
    """幂等键：同一个键重复请求，直接返回第一次的结果，不会重复扣款 / 发奖。"""

    __tablename__ = "idempotency_keys"
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), primary_key=True)
    key: Mapped[str] = mapped_column(String(80), primary_key=True)
    endpoint: Mapped[str] = mapped_column(String(64))
    status: Mapped[int] = mapped_column(Integer)
    response: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class PayOrder(Base):
    """充值订单。到账只由支付回调（现在是 mock）写入。"""

    __tablename__ = "pay_orders"
    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    pack: Mapped[int] = mapped_column(Integer)
    amber: Mapped[int] = mapped_column(Integer)
    price: Mapped[str] = mapped_column(String(16))
    provider: Mapped[str] = mapped_column(String(16))
    status: Mapped[str] = mapped_column(String(12))  # created / paid / failed
    provider_ref: Mapped[str] = mapped_column(String(80), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # 订单种类：amber（琥珀礼包，pack = 礼包下标）/ gift（礼包链付费步，pack = 步数，ref = "期号:步数"）
    kind: Mapped[str] = mapped_column(String(16), default="amber", server_default="amber")
    ref: Mapped[str] = mapped_column(String(40), default="", server_default="")
    # 到账时发的东西（礼包链：给客户端播动画 / 补发用）
    give: Mapped[dict | None] = mapped_column(JSON, nullable=True)


class AuditLog(Base):
    """拒收快照、拒收事件、可疑操作。"""

    __tablename__ = "audit_log"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    account_id: Mapped[str] = mapped_column(String(32), index=True)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    kind: Mapped[str] = mapped_column(String(32))
    detail: Mapped[str] = mapped_column(Text)


class RaceGroup(Base):
    """异步联机活动的一组（篝火竞速：5 人一组）。kind 给以后的活动留口子：race / weekly（部落周赛）/ daily（每日同题）/ coop。
    session 是场次 id（"r<开赛 Unix 时间>"），tier 是等级段。meta 放各活动自己的东西（周赛的段位档、同题的种子……）。"""

    __tablename__ = "race_groups"
    id: Mapped[str] = mapped_column(String(24), primary_key=True)
    kind: Mapped[str] = mapped_column(String(16), default="race")
    session: Mapped[str] = mapped_column(String(32))
    tier: Mapped[int] = mapped_column(Integer, default=0)
    start: Mapped[int] = mapped_column(BigInteger)
    end: Mapped[int] = mapped_column(BigInteger)
    target: Mapped[int] = mapped_column(Integer, default=300)
    created_at: Mapped[int] = mapped_column(BigInteger)
    # 真人凑满或者等满 fill_sec 后封组，空位补影子
    sealed: Mapped[bool] = mapped_column(Boolean, default=False)
    # 结束时间（前 3 名都到线，或者时间到）；结束后排名次
    ended_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    settled: Mapped[bool] = mapped_column(Boolean, default=False)
    meta: Mapped[dict] = mapped_column(JSON, default=dict)

    __table_args__ = (Index("ix_race_groups_session", "kind", "session", "tier", "sealed"),)


class RaceEntry(Base):
    """组里的一个位置：真人或影子。真人的 points 是服务器收到交付事件时记的「(距开赛秒数, 累计分)」曲线，
    同时就是以后给别人当影子回放的历史曲线；影子的 points 是封组时拷来（或生成）的整条曲线，按开赛后的时间回放。"""

    __tablename__ = "race_entries"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    group_id: Mapped[str] = mapped_column(ForeignKey("race_groups.id", ondelete="CASCADE"), index=True)
    slot: Mapped[int] = mapped_column(Integer)
    session: Mapped[str] = mapped_column(String(32))
    account_id: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    shadow: Mapped[bool] = mapped_column(Boolean, default=False)
    # 影子的来源：entry:<id>（真人历史曲线）/ gen（按等级生成）
    source: Mapped[str] = mapped_column(String(40), default="")
    name: Mapped[str] = mapped_column(String(32), default="")
    avatar: Mapped[int] = mapped_column(Integer, default=0)
    level: Mapped[int] = mapped_column(Integer, default=1)
    joined_at: Mapped[int] = mapped_column(BigInteger)
    score: Mapped[float] = mapped_column(Float, default=0.0)
    points: Mapped[list] = mapped_column(JSON, default=list)
    finished_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    last_at: Mapped[int] = mapped_column(BigInteger, default=0)
    # 报名时当天已买体力次数（算分数上限用）
    buys0: Mapped[int] = mapped_column(Integer, default=0)
    buys_day: Mapped[str] = mapped_column(String(10), default="")
    # 超出上限、没计入的分数
    capped: Mapped[float] = mapped_column(Float, default=0.0)
    place: Mapped[int | None] = mapped_column(Integer, nullable=True)
    reward: Mapped[list | None] = mapped_column(JSON, nullable=True)
    claimed: Mapped[bool] = mapped_column(Boolean, default=False)

    __table_args__ = (UniqueConstraint("group_id", "slot", name="uq_race_entries_slot"),
                      UniqueConstraint("session", "account_id", name="uq_race_entries_session_account"))
