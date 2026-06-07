@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title Nanobot Update Check

set "ROOT=%~dp0"
set "LOCKHEAD=%ROOT%data\.lockhead"
set "REPO=tertua/nanobot-usb"
set "BRANCH=lite"

echo.
echo  ============================================
echo    Nanobot Portable - Update Check
echo  ============================================
echo.

:: Fetch remote SHA via GitHub API
set "REMOTE_SHA="
for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { (Invoke-RestMethod -Uri 'https://api.github.com/repos/%REPO%/branches/%BRANCH%' -TimeoutSec 5).commit.sha } catch { '' }"`) do set "REMOTE_SHA=%%i"

if not defined REMOTE_SHA (
    echo  [WARN] Cannot reach GitHub. Check your network.
    goto :end
)
set "REMOTE_SHORT=!REMOTE_SHA:~0,7!"

:: Read local SHA from [sha] section in .lockhead (if any).
:: .lockhead is the single source of truth: setup-done sentinel + wrapper SHA.
:: Hapus .lockhead = conscious reset/rebuild.
set "LOCAL_SHA="
set "LOCKHEAD_EXISTS=0"
if exist "%LOCKHEAD%" (
    set "LOCKHEAD_EXISTS=1"
    set "IN_SHA=0"
    for /f "usebackq tokens=* delims=" %%l in ("%LOCKHEAD%") do (
        set "LINE=%%l"
        if "!LINE:~0,1!"=="[" (
            if /i "!LINE!"=="[sha]" (set "IN_SHA=1") else (set "IN_SHA=0")
        )
        if "!IN_SHA!"=="1" if "!LINE:~0,4!"=="sha=" set "LOCAL_SHA=!LINE:~4!"
    )
)

if "!LOCKHEAD_EXISTS!"=="0" (
    :: No lockhead: create minimal with [sha] only. Run setup.bat later to populate the rest.
    > "%LOCKHEAD%" echo [sha]
    >> "%LOCKHEAD%" echo sha=!REMOTE_SHA!
    echo  [INFO] Baseline recorded: !REMOTE_SHORT!
    echo         Re-run to check for updates.
) else if not defined LOCAL_SHA (
    >> "%LOCKHEAD%" echo.
    >> "%LOCKHEAD%" echo [sha]
    >> "%LOCKHEAD%" echo sha=!REMOTE_SHA!
    echo  [INFO] Baseline recorded: !REMOTE_SHORT!
    echo         Re-run to check for updates.
) else if "!LOCAL_SHA!"=="!REMOTE_SHA!" (
    set "LOCAL_SHORT=!LOCAL_SHA:~0,7!"
    echo  [OK]   Up to date. ^(!LOCAL_SHORT!^)
) else (
    set "LOCAL_SHORT=!LOCAL_SHA:~0,7!"
    :: Update: rewrite lockhead with new sha= in [sha] section, preserve other lines.
    set "TMP=%TEMP%\lockhead_!RANDOM!.tmp"
    set "IN_SHA=0"
    for /f "usebackq tokens=* delims=" %%l in ("%LOCKHEAD%") do (
        set "LINE=%%l"
        if "!LINE:~0,1!"=="[" (
            if /i "!LINE!"=="[sha]" (set "IN_SHA=1") else (set "IN_SHA=0")
        )
        if "!IN_SHA!"=="1" if "!LINE:~0,4!"=="sha=" (
            >> "%TMP%" echo sha=!REMOTE_SHA!
        ) else (
            >> "%TMP%" echo !LINE!
        )
    )
    move /y "%TMP%" "%LOCKHEAD%" >nul
    echo  [INFO] Update available: !LOCAL_SHORT! -^> !REMOTE_SHORT!
    echo         https://github.com/%REPO%/releases
    echo         Re-download and re-run setup.bat to apply.
)

:end
echo.
pause
