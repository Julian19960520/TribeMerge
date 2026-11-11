@echo off
rem Local game server: rank, cloud save, shop, campfire race, gift chain.
rem http://127.0.0.1:8765  (close this window to stop it)
rem First run installs the Python packages from server\requirements.txt.
rem Keep this file ASCII-only: cmd misreads UTF-8 lines in .bat files.
title 合合部落 - game server
cd /d "%~dp0server"
set PY=python
where python >nul 2>nul || set PY=py -3
%PY% -c "import fastapi, sqlalchemy, alembic, uvicorn, pydantic_settings" 2>nul
if errorlevel 1 (
  echo Installing server packages...
  %PY% -m pip install -r requirements.txt
)
echo Server: http://127.0.0.1:8765
%PY% run.py %*
echo.
echo Server stopped.
pause
