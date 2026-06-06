@echo off
chcp 65001 >nul 2>&1
title Nanobot WebUI Build

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
echo  ^>^> Building webui and syncing to installed package ^<^<
echo.
echo  This downloads ~50MB bun (if not present) and ~250MB node_modules.
echo  Requires internet. Re-runnable for retries.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install_webui.ps1"

if %errorlevel% neq 0 (
    echo.
    echo  [WARN] Webui build failed (exit %errorlevel%).
    echo         setup.bat already completed - retry by running build-webui.bat again.
    echo.
    pause
)

exit /b %errorlevel%
