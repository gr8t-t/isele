@echo off
title Isele First-Time Setup
cd /d "%~dp0"

REM Needs admin to change the DNS setting. If not elevated, relaunch as admin.
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0isele-setup.ps1"
echo.
echo You can close this window now.
pause
