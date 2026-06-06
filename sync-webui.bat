@echo off
chcp 65001 >nul 2>&1
title Nanobot WebUI Sync

:: Check for PowerShell
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] PowerShell not found in PATH.
    echo  Windows PowerShell 5.1+ is required.
    echo.
    pause
    exit /b 1
)

echo.
echo  ^>^> Syncing manually-built webui to installed package ^<^<
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\sync_webui.ps1"

if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] Sync failed with code %errorlevel%
    echo.
    pause
)

exit /b %errorlevel%
