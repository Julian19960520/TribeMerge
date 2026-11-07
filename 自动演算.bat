@echo off
setlocal
cd /d "%~dp0"
if not defined GODOT_BIN set "GODOT_BIN=D:\Program\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe"
if not exist "%GODOT_BIN%" (
  echo Set GODOT_BIN to your Godot 4.6.3 executable and try again.
  pause
  exit /b 1
)
set "SIM_PY=python"
where python >nul 2>nul
if errorlevel 1 set "SIM_PY=py"
"%GODOT_BIN%" --headless --editor --path "%~dp0." --import
if errorlevel 1 exit /b 1
"%SIM_PY%" tools\sim\run.py --godot "%GODOT_BIN%" --publish-report %*
pause
