@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title Nanobot Update Check

set "ROOT=%~dp0"
set "SHA_FILE=%ROOT%data\.wrapper_sha"
set "REPO=tertua/nanobot-usb"
set "BRANCH=lite"

echo.
echo  ============================================
echo    Nanobot Portable - Update Check
echo  ============================================
echo.

set "REMOTE_SHA="
for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { (Invoke-RestMethod -Uri 'https://api.github.com/repos/%REPO%/branches/%BRANCH%' -TimeoutSec 5).commit.sha } catch { '' }"`) do set "REMOTE_SHA=%%i"

if not defined REMOTE_SHA (
    echo  [WARN] Cannot reach GitHub. Check your network.
    goto :end
)
set "REMOTE_SHORT=!REMOTE_SHA:~0,7!"

set "LOCAL_SHA="
if exist "%SHA_FILE%" set /p LOCAL_SHA=<"%SHA_FILE%"

if not defined LOCAL_SHA (
    > "%SHA_FILE%" echo !REMOTE_SHA!
    echo  [INFO] Baseline recorded: !REMOTE_SHORT!
    echo         Re-run to check for updates.
    goto :end
)
set "LOCAL_SHORT=!LOCAL_SHA:~0,7!"

if /i "%LOCAL_SHA%"=="%REMOTE_SHA%" (
    echo  [OK]   Up to date. ^(!LOCAL_SHORT!^)
) else (
    echo  [INFO] Update available: !LOCAL_SHORT! -^> !REMOTE_SHORT!
    echo         https://github.com/%REPO%/releases
    echo         Re-download and re-run setup.bat to apply.
    > "%SHA_FILE%" echo !REMOTE_SHA!
)

:end
echo.
pause
