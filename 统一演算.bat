@echo off
rem Unified autoplay: fill in the parameters, then watch the bot play.
rem Tutorial bot clicks through onboarding, then the strategy bot
rem plays on schedule up to the target level. Game screen shown throughout.
rem Uses a throwaway save under user://autoplay_run, never the real save.
rem Run mode "background batch" = the old auto-sim: several intensities x seeds
rem in parallel, no screen, comparison table at the end.
rem Results go to tools/sim/results/autoplay-*; timelines open via tools/sim/view.py.
rem Keep this file ASCII-only: cmd misreads UTF-8 lines in .bat files.
setlocal
cd /d "%~dp0"
if not defined GODOT_BIN set "GODOT_BIN=D:\Program\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe"
if not exist "%GODOT_BIN%" (
  echo Set GODOT_BIN to your Godot 4.6.3 executable and try again.
  pause
  exit /b 1
)
if not exist "%~dp0.godot\global_script_class_cache.cfg" (
  echo Rebuilding Godot cache, please wait...
  "%GODOT_BIN%" --headless --path "%~dp0." --import
)
rem Start every run from a clean throwaway save.
if exist "%APPDATA%\TribeMerge\autoplay_run" rmdir /s /q "%APPDATA%\TribeMerge\autoplay_run"
rem "start" hands the game its own window and closes this console right away.
start "" "%GODOT_BIN%" --path "%~dp0." --script tools/sim/autoplay.gd -- --replay-test --cloud-off --save=user://autoplay_run/s.json --cloud-state=user://autoplay_run/c.json --rank-state=user://autoplay_run/r.json --hot-file=user://autoplay_run/h.json %*
