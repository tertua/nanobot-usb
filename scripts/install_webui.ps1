# install_webui.ps1 - Build upstream webui and sync to installed package
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File install_webui.ps1
#        or run build-webui.bat
#
# Why: Lite sets NANOBOT_SKIP_WEBUI_BUILD=1 in install_deps.ps1, so the upstream
# hatch hook never builds nanobot\web\dist\. This script is the manual
# equivalent: run npm install + build, then call sync_webui.ps1 to push the
# build into bin\Lib\site-packages\nanobot\web\dist\.
#
# Runner: npm only. Lite redirects HOME/USERPROFILE to the USB via
# init_portable.ps1, which makes bun's HOME-relative package store
# (~/.bun/install/cache) land on exFAT/FAT32 where MoveFileEx returns EINVAL.
# Bun's --no-cache flag only skips the manifest cache, not the package store,
# and there is no env var to override the cache dir. npm's flat node_modules
# writes work on every filesystem, so npm is the only path that is truly
# portable. Bun is not used here.
#
# Failure: exits 1 with clear error. setup.bat is unaffected (this is a
# separate, manual step). User can re-run build-webui.bat to retry.
#
# Idempotent: npm install is incremental (skips already-installed packages).
# node_modules persists across runs.

$ErrorActionPreference = 'Stop'

# -- Root resolution --------------------------------------------------------
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ROOT = Split-Path -Parent $ScriptDir

# -- Paths ------------------------------------------------------------------
$WebuiDir  = Join-Path $ROOT "app\webui"
$WebPkgJson = Join-Path $WebuiDir "package.json"
$BuildOut  = Join-Path $ROOT "app\nanobot\web\dist"
$IndexOut  = Join-Path $BuildOut "index.html"

# -- Pre-flight: source must be cloned --------------------------------------
if (-not (Test-Path $WebPkgJson)) {
    Write-Host "[ERROR] app\webui\package.json not found." -ForegroundColor Red
    Write-Host "         Lite ZIP install does not include webui source." -ForegroundColor Red
    Write-Host "         Run setup.bat (clones from git) before build-webui.bat." -ForegroundColor Red
    exit 1
}

# -- Resolve npm ------------------------------------------------------------
$npm = Get-Command "npm" -ErrorAction SilentlyContinue
if (-not $npm) {
    Write-Host "[ERROR] npm not found in PATH." -ForegroundColor Red
    Write-Host "         Re-run setup.bat to install Node.js into bin\." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Runner: npm" -ForegroundColor Green
Write-Host "     Path:  $($npm.Source)"

# -- Run install ------------------------------------------------------------
Write-Host ""
Write-Host "[INFO] Running 'npm install' in app\webui..." -ForegroundColor Cyan
Write-Host "       (first run may take several minutes for ~250MB node_modules)"
Push-Location $WebuiDir
try {
    & $npm.Source install
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Host "[ERROR] npm install failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
} catch {
    Pop-Location
    Write-Host "[ERROR] npm install exception: $_" -ForegroundColor Red
    exit 1
}

# -- Run build --------------------------------------------------------------
Write-Host ""
Write-Host "[INFO] Running 'npm run build' in app\webui..." -ForegroundColor Cyan
try {
    & $npm.Source run build
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Host "[ERROR] npm run build failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
} catch {
    Pop-Location
    Write-Host "[ERROR] npm run build exception: $_" -ForegroundColor Red
    exit 1
}
Pop-Location

# -- Verify build output ----------------------------------------------------
if (-not (Test-Path $IndexOut)) {
    Write-Host "[ERROR] Build succeeded but $IndexOut is missing." -ForegroundColor Red
    Write-Host "         Check app\webui\vite.config.ts (outDir)." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Build output: $BuildOut" -ForegroundColor Green

# -- Sync to installed package ----------------------------------------------
Write-Host ""
Write-Host "[INFO] Syncing to installed package..." -ForegroundColor Cyan
$syncScript = Join-Path $ScriptDir "sync_webui.ps1"
if (-not (Test-Path $syncScript)) {
    Write-Host "[ERROR] sync_webui.ps1 not found at $syncScript" -ForegroundColor Red
    exit 1
}
try {
    & $syncScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] sync_webui.ps1 failed (exit $LASTEXITCODE)" -ForegroundColor Red
        Write-Host "         webui built but not synced. Run sync-webui.bat manually." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[ERROR] sync_webui.ps1 exception: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] Webui build + sync complete." -ForegroundColor Green
Write-Host "     Next: run start-gateway.bat" -ForegroundColor Cyan
