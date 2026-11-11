"""请求 / 响应模型。请求严格校验（多余字段报错）；响应声明主要字段。"""

from typing import Any

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
    # 登录到已有账号时展示的确认进度摘要
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


class NameReq(Req):
    name: str = Field(min_length=1, max_length=16)
