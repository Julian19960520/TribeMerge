@echo off
cd /d "%~dp0"
echo 读取 assets\items\bake.json ，用原始绘制代码生成物品图和界面图（PNG）。只重画一部分界面图：生成物品图.bat --only=btn_
"D:\Program\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe" --path "%~dp0." -- --bake-items --bake-sprites %*
python tools\bake_character_sprites.py
if errorlevel 1 exit /b %errorlevel%
"D:\Program\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe" --headless --editor --path "%~dp0." --import
