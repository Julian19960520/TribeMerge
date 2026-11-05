"""结构化日志：每行一个 JSON，带 request_id / account_id，方便接 ELK / Loki。"""

import json
import logging
import sys
import time
from contextvars import ContextVar

request_id_var: ContextVar[str] = ContextVar("request_id", default="")
account_var: ContextVar[str] = ContextVar("account_id", default="")


class JsonFormatter(logging.Formatter):
    def format(self, rec: logging.LogRecord) -> str:
        out = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(rec.created)) + ".%03dZ" % rec.msecs,
            "level": rec.levelname.lower(),
            "logger": rec.name,
            "msg": rec.getMessage(),
        }
        rid = request_id_var.get()
        if rid:
            out["request_id"] = rid
        acc = account_var.get()
        if acc:
            out["account_id"] = acc
        extra = getattr(rec, "fields", None)
        if isinstance(extra, dict):
            out.update(extra)
        if rec.exc_info:
            out["exc"] = self.formatException(rec.exc_info)
        return json.dumps(out, ensure_ascii=False)


def setup(level: str = "INFO", as_json: bool = True) -> None:
    h = logging.StreamHandler(sys.stdout)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
    except (AttributeError, ValueError):
        pass
    h.setFormatter(JsonFormatter() if as_json else logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s"))
    root = logging.getLogger()
    root.handlers[:] = [h]
    root.setLevel(level.upper())
    for name in ("uvicorn", "uvicorn.error"):
        logging.getLogger(name).handlers[:] = []
        logging.getLogger(name).propagate = True
    # 访问日志由我们自己的中间件写（带 request_id、耗时），关掉 uvicorn 的
    logging.getLogger("uvicorn.access").disabled = True


def log(logger: logging.Logger, level: int, msg: str, **fields) -> None:
    logger.log(level, msg, extra={"fields": fields})
