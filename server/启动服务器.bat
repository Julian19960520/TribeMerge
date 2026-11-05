@echo off
chcp 65001 >nul
cd /d "%~dp0"
rem 不用 Docker 时：本机 Python 3.12 + SQLite（server\tribe.db）。第一次会装依赖。
rem 用 Docker：在这个目录运行  docker compose up --build  （app + PostgreSQL）
set PY=python
where python >nul 2>nul || set PY=py -3
%PY% -c "import fastapi, sqlalchemy, alembic, uvicorn, pydantic_settings" 2>nul || %PY% -m pip install -r requirements.txt
%PY% run.py %*
pause
