"""请求 / 响应模型。请求严格校验（多余字段报错）；响应声明主要字段。"""

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

ID = Field(pattern=r"^[A-Za-z0-9_\-]{1,32}$")
DEVICE = Field(default="", max_length=64)


class Req(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Resp(BaseModel):
    model_config = ConfigDict(extra="allow")
    ok: bool = True
    now: float = 0.0
    day: str = ""


# ---------------------------------------------------------------- 账号

class GuestReq(Req):
    # 老客户端已经有 player_id 时带上，没被占用就沿用；否则服务器生成
    player_id: str | None = Field(default=None, pattern=r"^[A-Za-z0-9_\-]{1,32}$")
    device_id: str = DEVICE


class TransferLoginReq(Req):
    account_id: str = ID
    code: str = Field(min_length=6, max_length=32)
    device_id: str = DEVICE


class ProviderReq(Req):
    provider: str = Field(pattern=r"^[a-z0-9_]{1,32}$")
    credential: str = Field(min_length=1, max_length=2048)
    device_id: str = DEVICE


class SessionResp(Resp):
    account_id: str
    token: str
    expires_at: float
    renew_after: float
    created: bool = False
    # 登录到已有账号时，云端进度摘要（客户端据此让玩家选用哪边）
    cloud: dict[str, Any] | None = None


class AccountResp(Resp):
    account_id: str
    bindings: list[str]
    has_transfer_code: bool
    last_sync_at: float | None
    created_at: float
    session_expires_at: float


class TransferCodeResp(Resp):
    account_id: str
    code: str


# ---------------------------------------------------------------- 存档

class Event(Req):
    id: str = Field(min_length=1, max_length=64)
    type: Literal["order", "bubble", "collect", "refund"]
    order: dict[str, Any] | None = None
    cell: int | None = None
    item: str | None = Field(default=None, max_length=32)


class SaveReq(Req):
    base: int = Field(ge=0)
    hash: str = Field(pattern=r"^[0-9a-f]{8,64}$")
    data: str = Field(max_length=90_000)
    events: list[Event] = Field(default_factory=list, max_length=200)


class SaveResp(Resp):
    version: int
    hash: str = ""
    data: str = ""
    state: dict[str, Any]
    events: list[dict[str, Any]] = Field(default_factory=list)
    same: bool = False


class EventsReq(Req):
    events: list[Event] = Field(max_length=200)


# ---------------------------------------------------------------- 经济操作

class ActionResp(Resp):
    state: dict[str, Any]
    give: dict[str, Any] = Field(default_factory=dict)


class ShopBuyReq(Req):
    key: str = Field(pattern=r"^(deal|hot)_\d{1,2}$")
    item: str = Field(default="", max_length=32)


class PassBuyReq(Req):
    tier: Literal["vip", "super"]


class PassClaimReq(Req):
    track: Literal["free", "prem", "endless"]
    level: int = Field(default=0, ge=0, le=1000)


class BuildReq(Req):
    area: str = Field(pattern=r"^[a-z0-9_]{1,32}$")


class BookReq(Req):
    item: str = Field(pattern=r"^[a-z0-9]{1,16}_\d{1,2}$")


class LevelReq(Req):
    level: int = Field(ge=2, le=10000)


class NameReq(Req):
    name: str = Field(min_length=1, max_length=16)


class PayOrderReq(Req):
    pack: int = Field(ge=0, le=50)
    provider: str = Field(default="mock", pattern=r"^[a-z0-9_]{1,16}$")


class PayOrderResp(Resp):
    order_id: str
    status: str
    amber: int
    price: str
    provider: str
    pay_params: dict[str, Any] = Field(default_factory=dict)
    state: dict[str, Any] | None = None
