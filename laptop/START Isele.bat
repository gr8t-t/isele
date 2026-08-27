@echo off
title Isele
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0isele-launch.ps1"
echo.
echo Isele has stopped. You can close this window.
pause
