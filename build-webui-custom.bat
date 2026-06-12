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

rmdir /S /Q "%ROOT%app\webui\" 2>nul
xcopy /E /I /Y /H /K "%CUSTOM_DIR%\*" "%ROOT%app\webui\"
if errorlevel 4 (
    echo [ERROR] Copy failed
    pause
    exit /b 1
)

call "%ROOT%build-webui.bat"

pause
