@echo off
set GODOT=D:\Program\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe
if not exist "%~dp0.godot\global_script_class_cache.cfg" (
  echo Rebuilding Godot cache, please wait...
  "%GODOT%" --headless --path "%~dp0." --import
)
start "" "%GODOT%" --path "%~dp0."
