@echo off
chcp 65001 >nul 2>&1
title Nanobot WebUI Custom Build

set "ROOT=%~dp0"
set "CUSTOM_DIR=%ROOT%data\webui-src"

if not exist "%CUSTOM_DIR%" (
    echo [ERROR] data/webui-src/ not found
    pause
    exit /b 1
)
if not exist "%CUSTOM_DIR%\package.json" (
    echo [ERROR] data/webui-src/package.json not found
    pause
    exit /b 1
)

xcopy /E /I /Y "%CUSTOM_DIR%\*" "%ROOT%app\webui\" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Overlay copy failed
    pause
    exit /b 1
)

call "%ROOT%build-webui.bat"

pause
