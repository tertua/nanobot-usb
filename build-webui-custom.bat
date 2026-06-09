@echo off
chcp 65001 >nul 2>&1
title Nanobot WebUI Custom Build

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

set "ROOT=%~dp0"
set "CUSTOM_DIR=%ROOT%data\webui-src"

:: -- Validate ----------------------------------------------------------------
if not exist "%CUSTOM_DIR%" (
    echo.
    echo  [ERROR] data/webui-src/ not found.
    echo          Place your custom webui source files there.
    echo.
    echo  How to use:
    echo    1. Copy your webui source (with package.json) into:
    echo       data/webui-src/
    echo    2. Run this script again.
    echo.
    pause
    exit /b 1
)

if not exist "%CUSTOM_DIR%\package.json" (
    echo.
    echo  [ERROR] data/webui-src/package.json not found.
    echo          data/webui-src/ must be a valid npm/vite project.
    echo.
    pause
    exit /b 1
)

:: -- Instructions & Confirmation --------------------------------------------
echo.
echo  ============================================================
echo    NANOBOT WEBUI CUSTOM BUILD GUIDE
echo  ============================================================
echo.
echo  This script overlays your custom webui source files onto
echo  the build directory, then builds and deploys.
echo.
echo  Step 1: Overlay data/webui-src/*  -^>  app/webui/
echo          ^(existing files with same name will be overwritten^)
echo.
echo  Step 2: Run npm install + npm run build in app/webui/
echo.
echo  Step 3: Copy build output to deployed gateway path.
echo.
echo  Press Enter to continue, or Ctrl+C to cancel.
echo.
pause >nul

:: -- Execute -----------------------------------------------------------------
echo.
echo  [..] Overlaying data/webui-src/* into app/webui/...
xcopy /E /I /Y "%CUSTOM_DIR%\*" "%ROOT%app\webui\" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Overlay copy failed.
    echo.
    pause
    exit /b 1
)
echo  [OK]  Overlay applied.
echo.
echo  [..] Running build...
echo.

call "%ROOT%build-webui.bat"
