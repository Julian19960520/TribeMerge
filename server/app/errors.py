"""统一错误格式：{"ok": false, "error": "机器可读的代码", "message": "给人看的说明", ...额外字段}。"""

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class ApiError(Exception):
    def __init__(self, status: int, error: str, message: str = "", **extra):
        super().__init__(error)
        self.status = status
        self.error = error
        self.message = message or error
        self.extra = extra


def body(error: str, message: str, **extra) -> dict:
    out = {"ok": False, "error": error, "message": message}
    out.update(extra)
    return out


def install(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _api(_req: Request, e: ApiError):
        headers = {}
        if "retry_after" in e.extra:
            headers["Retry-After"] = str(int(e.extra["retry_after"]))
        return JSONResponse(body(e.error, e.message, **e.extra), status_code=e.status, headers=headers)

    @app.exception_handler(RequestValidationError)
    async def _val(_req: Request, e: RequestValidationError):
        detail = [{"loc": list(x.get("loc", [])), "msg": x.get("msg", "")} for x in e.errors()]
        return JSONResponse(body("invalid_request", "请求参数不合法", detail=detail), status_code=422)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_req: Request, e: StarletteHTTPException):
        code = {404: "not_found", 405: "method_not_allowed"}.get(e.status_code, "http_error")
        return JSONResponse(body(code, str(e.detail)), status_code=e.status_code)
