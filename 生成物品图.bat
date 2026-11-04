@echo off
cd /d "%~dp0"
echo 读取 assets\items\bake.json ，用原始绘制代码生成 PNG 和 anim.json
"D:\Program\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe" --path "%~dp0." -- --bake-items
