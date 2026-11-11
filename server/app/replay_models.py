"""Current command schema and bounded compressed transport boundary."""

from typing import Literal

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from pydantic import Field, ValidationError

from . import replay_wire
from .errors import ApiError
from .schemas import Req

COMMANDS = Literal["tick", "drop", "tap", "stash", "store", "inventory", "discard", "discard_finish", "undo",
                   "order", "craft", "rush", "boost", "energy", "expand", "build", "book", "level", "pack", "shop", "shop_view",
                   "hot_refresh", "shell_refresh", "bubble_buy", "bubble_reward", "pass", "daily", "seven", "choice",
                   "activity", "duel", "tiger", "fossil", "race_join", "race_claim", "offer", "ufo", "ufo_refresh", "gift", "gm", "reset", "tutorial_finish", "album_claim"]


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
    content_type = request.headers.get("content-type", "").split(";", 1)[0].strip().lower()
    if content_type != replay_wire.MIME or request.headers.get("content-encoding", "").lower().strip() != "gzip":
        raise ApiError(415, "unsupported_encoding", "操作日志需要当前 TRP1 协议及 gzip 编码")
    chunks = []
    size = 0
    async for chunk in request.stream():
        size += len(chunk)
        if size > replay_wire.MAX_COMPRESSED:
            raise ApiError(413, "too_big", "操作日志请求体太大")
        chunks.append(chunk)
    try:
        payload = replay_wire.decode(replay_wire.inflate(b"".join(chunks)))
    except replay_wire.WireError as e:
        raise ApiError(400, "invalid_replay_wire", "操作日志压缩包损坏或超出限制") from e
    try:
        return SyncReq.model_validate(payload)
    except ValidationError as e:
        raise RequestValidationError(e.errors()) from e
