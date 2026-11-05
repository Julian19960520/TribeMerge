"""石器部落 · 合成 服务器入口（FastAPI）。

本地：python server/run.py（自动跑迁移再起 Uvicorn），或 docker compose up。
接口文档：启动后打开 /docs（dev 环境）。
"""

import logging
import time
import uuid

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import api_auth, api_game, errors, logs
from .config import get_settings
from .db import init_engine
from .errors import body
from .ratelimit import limiter

logger = logging.getLogger("tribe.http")


def create_app() -> FastAPI:
    s = get_settings()
    logs.setup(s.log_level, s.log_json)
    init_engine(s.database_url)
    app = FastAPI(title="石器部落 · 合成", version="1.0.0",
                  docs_url=None if s.is_prod else "/docs", redoc_url=None, openapi_url=None if s.is_prod else "/openapi.json")
    errors.install(app)
    if s.cors_origins:
        app.add_middleware(CORSMiddleware, allow_origins=s.cors_origins, allow_methods=["*"], allow_headers=["*"])

    @app.middleware("http")
    async def guard(request: Request, call_next):
        rid = request.headers.get("x-request-id") or uuid.uuid4().hex[:16]
        logs.request_id_var.set(rid)
        logs.account_var.set("")
        t0 = time.perf_counter()
        ip = request.client.host if request.client else "?"
        if s.trust_forwarded and request.headers.get("x-forwarded-for"):
            ip = request.headers["x-forwarded-for"].split(",")[0].strip()
        # 请求体大小：先看 Content-Length，没有就拒绝带 body 的请求以外的分块上传
        cl = request.headers.get("content-length")
        if cl is not None and (not cl.isdigit() or int(cl) > s.max_body_bytes):
            return _reply(413, body("too_big", "请求体太大"), rid)
        if cl is None and request.method in ("POST", "PUT", "PATCH") and request.headers.get("transfer-encoding"):
            return _reply(411, body("length_required", "需要 Content-Length"), rid)
        if request.url.path != "/v1/health":
            wait = limiter.hit("ip:" + ip, s.rate_ip_per_min)
            if wait > 0:
                resp = _reply(429, body("rate_limited", "请求太频繁", retry_after=wait), rid)
                resp.headers["Retry-After"] = str(int(wait) + 1)
                return resp
        try:
            resp = await call_next(request)
        except Exception:
            logger.exception("unhandled")
            resp = _reply(500, body("internal", "服务器出错了"), rid)
        resp.headers["X-Request-Id"] = rid
        logs.log(logger, logging.INFO, "request", method=request.method, path=request.url.path, status=resp.status_code,
                 ms=round((time.perf_counter() - t0) * 1000, 1), ip=ip)
        return resp

    app.include_router(api_auth.router)
    app.include_router(api_game.router)
    return app


def _reply(status: int, payload: dict, rid: str) -> JSONResponse:
    r = JSONResponse(payload, status_code=status)
    r.headers["X-Request-Id"] = rid
    return r


app = create_app()
