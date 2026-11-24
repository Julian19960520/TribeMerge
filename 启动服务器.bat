@echo off
rem Local game server: rank, cloud save, shop, campfire race, gift chain.
rem Runs in the background with a tray icon (bottom-right); right-click it to view logs, restart or stop.
rem http://127.0.0.1:8765
rem First run installs the Python packages from server\requirements.txt.
rem Keep this file ASCII-only: cmd misreads UTF-8 lines in .bat files.
cd /d "%~dp0server"
set PY=python
where python >/dev/null 2>/dev/null || set PY=py -3
%PY% -c "import fastapi, sqlalchemy, alembic, uvicorn, pydantic_settings" 2>nul
if errorlevel 1 (
  echo Installing server packages...
  %PY% -m pip install -r requirements.txt
  if errorlevel 1 ( pause & exit /b 1 )
)
start "" wscript.exe "%~dp0tools\server_tray.vbs" %*
