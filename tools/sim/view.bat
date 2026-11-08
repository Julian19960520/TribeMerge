@echo off
rem Double-click to open the newest simulation result. Drag a batch folder or report.json onto this file to open that one.
cd /d "%~dp0..\.."
python -X utf8 tools\sim\view.py %*
if errorlevel 1 pause
