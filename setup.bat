@echo off
setlocal enabledelayedexpansion

rem ==========================================================
rem  setup.bat - Nanobot Portable Bootstrap (Windows 10/11)
rem  Minimal requirement: Windows 10 version 1809+
rem ==========================================================

title Nanobot Portable Setup Bootstrap

rem ── Root directory (script location) ─────────────────────
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

cd /d "%ROOT%"

rem ── UTF-8 console ─────────────────────────────────────────
chcp 65001 >nul 2>&1

rem ── Banner ────────────────────────────────────────────────
echo.
echo ================================================================
echo    NANOBOT PORTABLE SETUP - Bootstrap
echo ================================================================
echo.
echo  This script will install the following components into
echo  a fully self-contained portable environment at:
echo    %ROOT%
echo.
echo  [1] PowerShell 7.x portable
echo      - Required for running all Nanobot management scripts
echo.
echo  [2] Python 3.x portable (embed package + pip)
echo      - Core runtime for the Nanobot AI agent
echo.
echo  [3] Git portable (MinGit)
echo      - For repository cloning and version management
echo.
echo  [4] Node.js portable
echo      - Required for web interface and MCP tools
echo.
echo  [5] Nanobot source code
echo      - Cloned from GitHub repository
echo.
echo  [6] Python dependencies (via pip)
echo      - nanobot package and required libraries
echo.
echo  [7] Configuration and lockfile setup
echo      - Initial config.json, .env, and software versions
echo.
echo  All components are installed inside %ROOT%
echo  and will NOT affect your host system.
echo.
echo ================================================================
echo  Press any key to start installation, or close this window
echo  to cancel.
echo ================================================================
pause >nul
echo.

rem ── Check minimum Windows version ─────────────────────────
for /f "tokens=2 delims=[]" %%v in ('ver') do (
    for /f "tokens=2" %%a in ("%%v") do (
        for /f "tokens=1 delims=." %%b in ("%%a") do set "WIN_VER=%%b"
    )
)
if not defined WIN_VER set "WIN_VER=0"
if %WIN_VER% LSS 10 (
    echo [ERROR] Windows 10 atau lebih baru diperlukan.
    echo         Versi Windows Anda: %WIN_VER%
    pause
    exit /b 1
)

rem ── Paths ─────────────────────────────────────────────────
set "BIN_DIR=%ROOT%\bin"
set "TMP_DIR=%ROOT%\tmp"
set "PS7_DIR=%BIN_DIR%\pwsh7"
set "PS7_EXE=%PS7_DIR%\pwsh.exe"
set "PS7_ZIP=%TMP_DIR%\pwsh7.zip"
set "SETUP_SCRIPT=%ROOT%\nanobot-setup.ps1"

rem ── Create temp directory ─────────────────────────────────
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

rem ── Check if PowerShell 7 already installed ───────────────
if exist "%PS7_EXE%" (
    echo [OK] PowerShell 7 sudah terinstall: %PS7_DIR%
    echo.
    goto :run_setup
)

echo [INFO] PowerShell 7 tidak ditemukan. Memulai instalasi...
echo.

rem ── Detect architecture ───────────────────────────────────
echo [1/4] Mendeteksi arsitektur sistem...
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[Environment]::Is64BitOperatingSystem"`) do set "IS64=%%a"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')"`) do set "PROC_ARCH=%%a"

if /i "%PROC_ARCH%"=="ARM64" (
    set "ARCH=arm64"
) else if /i "%IS64%"=="True" (
    set "ARCH=x64"
) else (
    set "ARCH=x86"
)

echo       Arsitektur: %ARCH%
echo.

rem ── Download PowerShell 7 ─────────────────────────────────
set "PS7_VER=7.6.2"
set "PS7_URL=https://github.com/PowerShell/PowerShell/releases/download/v%PS7_VER%/PowerShell-%PS7_VER%-win-%ARCH%.zip"

echo [2/4] Mengunduh PowerShell 7 portable...
echo       URL: %PS7_URL%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\download.ps1" -Url "%PS7_URL%" -Out "%PS7_ZIP%"

if errorlevel 1 (
    echo [ERROR] Gagal mengunduh PowerShell 7.
    pause
    exit /b 1
)

if not exist "%PS7_ZIP%" (
    echo [ERROR] File ZIP tidak ditemukan setelah download.
    pause
    exit /b 1
)

echo       Download selesai: %PS7_ZIP%
echo.

rem ── Extract PowerShell 7 ──────────────────────────────────
echo [3/4] Mengekstrak PowerShell 7...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\extract.ps1" -Zip "%PS7_ZIP%" -Dest "%PS7_DIR%"

if errorlevel 1 (
    echo [ERROR] Gagal mengekstrak PowerShell 7.
    pause
    exit /b 1
)

if not exist "%PS7_EXE%" (
    echo [ERROR] pwsh.exe tidak ditemukan setelah ekstraksi.
    pause
    exit /b 1
)

echo       Ekstraksi selesai: %PS7_DIR%
echo.

rem ── Cleanup ───────────────────────────────────────────────
echo [4/4] Membersihkan file sementara...
del /f /q "%PS7_ZIP%" >nul 2>&1
echo       Cleanup selesai.
echo.

echo [OK] PowerShell 7 portable berhasil diinstal.
echo.

rem ── Run main setup ────────────────────────────────────────
:run_setup
echo ================================================================
echo    Menjalankan Setup Utama (nanobot-setup.ps1)
echo ================================================================
echo.

if not exist "%SETUP_SCRIPT%" (
    echo [ERROR] Script setup tidak ditemukan: %SETUP_SCRIPT%
    pause
    exit /b 1
)

"%PS7_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SETUP_SCRIPT%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo ================================================================
echo    Setup Bootstrap Selesai (Exit Code: %EXIT_CODE%)
echo ================================================================
echo.

if %EXIT_CODE% neq 0 (
    echo [WARN] Setup utama keluar dengan error code %EXIT_CODE%.
    pause
    exit /b %EXIT_CODE%
)

pause
exit /b 0
