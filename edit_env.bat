@echo off
cd /d "%~dp0"
setlocal EnableDelayedExpansion
title Nanobot Protect .env

set "ROOT=%~dp0"
set "PY=%ROOT%bin\python.exe"
set "PATH=%ROOT%bin;%ROOT%bin\nodejs;%ROOT%scripts;%ROOT%data;%PATH%"
set "HOME=%ROOT%data\home"
set "NPM_CONFIG_CACHE=%ROOT%tmp\npm-cache"
set "NPM_CONFIG_PREFIX=%ROOT%bin\nodejs\global"

echo.
echo  ========================================
echo    EDIT API KEY (.env)
echo  ========================================
echo.

if exist "data\.env" goto :decrypt
if exist "data\.env.encrypted" goto :decrypt

if not exist "data\.env.example" (
    echo  [ERROR] No file.
    pause
    exit /b 1
)

copy "data\.env.example" "data\.env" >nul
echo  [OK] .env template created.

:decrypt
if not exist "data\.env.encrypted" (
    echo  [1/3] skip
    goto :edit
)

echo  [1/3] Decrypting...
if exist "data\.env_key" (
    set /p ENV_KEY=<"data\.env_key"
    set "NANOBOT_ENV_KEY=!ENV_KEY!"
    "%PY%" "%ROOT%scripts\env_crypt.py" decrypt --noninteractive
) else (
    "%PY%" "%ROOT%scripts\env_crypt.py" decrypt
)
if errorlevel 1 (
    echo  [ERROR] Failed.
    pause
    exit /b 1
)

:edit
echo  [2/3] Open Notepad...
start /wait notepad "data\.env"

echo  [3/3] Re-encryption...
if exist "data\.env_key" (
    set /p ENV_KEY=<"data\.env_key"
    set "NANOBOT_ENV_KEY=!ENV_KEY!"
    "%PY%" "%ROOT%scripts\env_crypt.py" encrypt --noninteractive
) else (
    "%PY%" "%ROOT%scripts\env_crypt.py" encrypt
)
if errorlevel 1 (
    echo  [ERROR] Failed.
    pause
    exit /b 1
)

echo.
echo  Finished.
pause
