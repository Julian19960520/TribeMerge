@echo off
chcp 65001 >nul
rem Same as the launcher in the project root: background server with a tray icon.
rem Docker instead: run  docker compose up --build  in this folder (app + PostgreSQL).
call "%~dp0..\启动服务器.bat" %*
