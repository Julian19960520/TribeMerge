"""本地启动：先把数据库迁移到最新（alembic upgrade head），再起 Uvicorn。

  python server/run.py                         # 默认 127.0.0.1:8765，SQLite 在 server/tribe.db
  python server/run.py --port 18767 --database-url sqlite:///C:/tmp/t.db
  python server/run.py --host 0.0.0.0 --workers 4   # 多进程（PostgreSQL 时用；SQLite 只开 1 个）

正式部署用 Docker（见 Dockerfile / docker-compose.yml），前面放 HTTPS 反向代理。
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main() -> None:
    ap = argparse.ArgumentParser(description="石器部落游戏服务器")
    ap.add_argument("--host", default=os.environ.get("TRIBE_HOST", "127.0.0.1"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("TRIBE_PORT", "8765")))
    ap.add_argument("--database-url", help="覆盖 TRIBE_DATABASE_URL")
    ap.add_argument("--workers", type=int, default=1)
    ap.add_argument("--no-migrate", action="store_true", help="跳过 alembic upgrade head")
    args = ap.parse_args()
    if args.database_url:
        os.environ["TRIBE_DATABASE_URL"] = args.database_url
    os.chdir(HERE)
    sys.path.insert(0, HERE)
    if not args.no_migrate:
        from alembic import command
        from alembic.config import Config

        command.upgrade(Config(os.path.join(HERE, "alembic.ini")), "head")
    import uvicorn

    uvicorn.run("app.main:app", host=args.host, port=args.port, workers=args.workers, log_config=None,
                proxy_headers=True, forwarded_allow_ips="*" if os.environ.get("TRIBE_TRUST_FORWARDED") else "127.0.0.1")


if __name__ == "__main__":
    main()
