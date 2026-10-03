@echo off
rem One-click setup: create desktop shortcut + launch Pomodoro
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Pomodoro.ps1" -CreateShortcut
start "" wscript.exe "%~dp0PomodoroLauncher.vbs"
echo.
echo DONE - Pomodoro is starting...
timeout /t 2 >nul
