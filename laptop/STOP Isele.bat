@echo off
title Stop Isele
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0isele-launch.ps1" stop
