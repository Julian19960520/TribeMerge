"""石器部落 · 合成 —— 排行榜服务器。

只用 Python 标准库（http.server + sqlite3），不需要装任何依赖。

接口（全部返回 JSON，UTF-8）：
  GET  /api/health                      → {"ok": true}
  POST /api/submit                      body: {"id", "name", "progress", "time"}
        → {"ok": true, "rank": 名次, "total": 总人数, "progress": 服务器记录的进度}
  GET  /api/top?n=50&id=玩家id          → {"ok": true, "total", "top": [...], "me": {...} 或 null}

排序：进度从高到低；进度相同，先达到（reached_at 小）的排前面；再相同按 id。
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ID_RE = re.compile(r"^[A-Za-z0-9_\-]{1,32}$")
NAME_MAX = 16
PROGRESS_MAX = 100000
TOP_MAX = 200
BODY_MAX = 4096

_lock = threading.Lock()
_db: sqlite3.Connection = None  # type: ignore


def open_db(path: str) -> sqlite3.Connection:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    db = sqlite3.connect(path, check_same_thread=False)
    db.execute(
        """CREATE TABLE IF NOT EXISTS players (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            progress INTEGER NOT NULL,
            reached_at REAL NOT NULL,
            updated_at REAL NOT NULL
        )"""
    )
    db.execute("CREATE INDEX IF NOT EXISTS idx_rank ON players (progress DESC, reached_at ASC, id ASC)")
    db.commit()
    return db


def rank_of(db: sqlite3.Connection, pid: str):
    row = db.execute("SELECT id, name, progress, reached_at FROM players WHERE id = ?", (pid,)).fetchone()
    if row is None:
        return None
    _, name, progress, reached = row
    ahead = db.execute(
        """SELECT COUNT(*) FROM players WHERE progress > ?
           OR (progress = ? AND (reached_at < ? OR (reached_at = ? AND id < ?)))""",
        (progress, progress, reached, reached, pid),
    ).fetchone()[0]
    return {"rank": ahead + 1, "id": pid, "name": name, "progress": progress, "reached_at": reached}


def submit(body: dict) -> dict:
    pid = str(body.get("id", ""))
    if not ID_RE.match(pid):
        raise ValueError("bad id")
    name = str(body.get("name", "")).strip()[:NAME_MAX] or pid
    try:
        progress = int(body.get("progress", 0))
    except (TypeError, ValueError):
        raise ValueError("bad progress")
    if progress < 0 or progress > PROGRESS_MAX:
        raise ValueError("bad progress")
    now = time.time()
    try:
        reached = float(body.get("time", now))
    except (TypeError, ValueError):
        reached = now
    reached = min(reached, now)  # 不接受未来时间
    with _lock:
        row = _db.execute("SELECT progress, reached_at FROM players WHERE id = ?", (pid,)).fetchone()
        if row is None:
            _db.execute("INSERT INTO players VALUES (?, ?, ?, ?, ?)", (pid, name, progress, reached, now))
        elif progress > row[0]:
            _db.execute(
                "UPDATE players SET name = ?, progress = ?, reached_at = ?, updated_at = ? WHERE id = ?",
                (name, progress, reached, now, pid),
            )
        else:
            # 进度没涨：只更新昵称；同进度下更早的达成时间可以覆盖（补传离线成绩）
            new_reached = min(row[1], reached) if progress == row[0] else row[1]
            _db.execute(
                "UPDATE players SET name = ?, reached_at = ?, updated_at = ? WHERE id = ?",
                (name, new_reached, now, pid),
            )
        _db.commit()
        me = rank_of(_db, pid)
        total = _db.execute("SELECT COUNT(*) FROM players").fetchone()[0]
    return {"ok": True, "rank": me["rank"], "total": total, "progress": me["progress"]}


def top(n: int, pid: str) -> dict:
    n = max(1, min(TOP_MAX, n))
    with _lock:
        rows = _db.execute(
            "SELECT id, name, progress, reached_at FROM players ORDER BY progress DESC, reached_at ASC, id ASC LIMIT ?",
            (n,),
        ).fetchall()
        total = _db.execute("SELECT COUNT(*) FROM players").fetchone()[0]
        me = rank_of(_db, pid) if ID_RE.match(pid) else None
    out = [
        {"rank": i + 1, "id": r[0], "name": r[1], "progress": r[2], "reached_at": r[3]}
        for i, r in enumerate(rows)
    ]
    return {"ok": True, "total": total, "top": out, "me": me}


class Handler(BaseHTTPRequestHandler):
    server_version = "TribeRank/1.0"

    def _send(self, code: int, obj: dict) -> None:
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path == "/api/health":
            self._send(200, {"ok": True})
        elif u.path == "/api/top":
            try:
                n = int(q.get("n", ["50"])[0])
            except ValueError:
                n = 50
            self._send(200, top(n, q.get("id", [""])[0]))
        else:
            self._send(404, {"ok": False, "error": "not found"})

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/api/submit":
            self._send(404, {"ok": False, "error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > BODY_MAX:
                raise ValueError("bad body")
            body = json.loads(self.rfile.read(length).decode("utf-8"))
            if not isinstance(body, dict):
                raise ValueError("bad body")
            self._send(200, submit(body))
        except (ValueError, json.JSONDecodeError) as e:
            self._send(400, {"ok": False, "error": str(e)})

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def log_message(self, fmt: str, *args) -> None:
        print("[%s] %s" % (time.strftime("%H:%M:%S"), fmt % args), flush=True)


def main() -> None:
    # 控制台可能是 GBK/Big5，避免中文输出直接崩
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description="石器部落排行榜服务器")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--db", default=os.path.join(here, "rank.db"))
    args = ap.parse_args()
    global _db
    _db = open_db(args.db)
    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    print("排行榜服务器已启动：http://%s:%d  数据：%s" % (args.host, args.port, args.db), flush=True)
    print("按 Ctrl+C 停止。", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()
        _db.close()


if __name__ == "__main__":
    main()
