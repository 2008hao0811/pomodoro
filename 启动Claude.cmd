@echo off
rem Launch Claude Code in the D: project directory.
chcp 65001 >nul

rem Make sure we're in the project directory.
cd /d "%~dp0"

rem Start Claude Code.
claude
