@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  start_chat.bat - Nanobot Agent (CLI Chat Mode)
rem  Menggunakan PowerShell 7 portable (bin\pwsh7\pwsh.exe)
rem ============================================================

title Nanobot Agent

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "PS7_EXE=%ROOT%\bin\pwsh7\pwsh.exe"

if not exist "%PS7_EXE%" (
    echo [ERROR] PowerShell 7 tidak ditemukan di %PS7_EXE%
    echo.
    echo Jalankan setup.bat dulu untuk menginstal PowerShell 7.
    pause
    exit /b 1
)

set "SCRIPT=%ROOT%\nanobot-agent.ps1"

if not exist "%SCRIPT%" (
    echo [ERROR] Script tidak ditemukan: %SCRIPT%
    pause
    exit /b 1
)

echo ================================================================
echo    Nanobot Agent - CLI Chat Mode
echo ================================================================
echo.

"%PS7_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

set "EXIT_CODE=%ERRORLEVEL%"

if %EXIT_CODE% neq 0 (
    echo.
    echo [WARN] Agent keluar dengan error code %EXIT_CODE%.
    echo.
)

pause
exit /b %EXIT_CODE%
