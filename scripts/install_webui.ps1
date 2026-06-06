# install_webui.ps1 - Build upstream webui and sync to installed package
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File install_webui.ps1
#        or run build-webui.bat
#
# Why: Lite sets NANOBOT_SKIP_WEBUI_BUILD=1 in install_deps.ps1, so the upstream
# hatch hook never builds nanobot\web\dist\. This script is the manual
# equivalent: detect runner (bun > npm), run install + build, then call
# sync_webui.ps1 to push the build into bin\Lib\site-packages\nanobot\web\dist\.
#
# Failure: exits 1 with clear error. setup.bat is unaffected (this is a
# separate, manual step). User can re-run build-webui.bat to retry.
#
# Idempotent: bun download skipped if bin/bun/bun.exe exists; npm/bun
# install is incremental (skips already-installed packages).

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
$BunExe    = Join-Path $ROOT "bin\bun\bun.exe"

# -- Pre-flight: source must be cloned --------------------------------------
if (-not (Test-Path $WebPkgJson)) {
    Write-Host "[ERROR] app\webui\package.json not found." -ForegroundColor Red
    Write-Host "         Lite ZIP install does not include webui source." -ForegroundColor Red
    Write-Host "         Run setup.bat (clones from git) before build-webui.bat." -ForegroundColor Red
    exit 1
}

# -- Resolve runner ---------------------------------------------------------
# Priority: portable bun in bin\bun\ > system bun > auto-install bun > npm fallback
$runner = $null
$runnerLabel = $null

# 1. Portable bun (Lite convention: prefer local to avoid host pollution)
if (Test-Path $BunExe) {
    $runner = $BunExe
    $runnerLabel = "portable bun"
}

# 2. System bun
if (-not $runner) {
    $sysBun = Get-Command "bun" -ErrorAction SilentlyContinue
    if ($sysBun) {
        $runner = $sysBun.Source
        $runnerLabel = "system bun"
    }
}

# 3. Auto-install portable bun
if (-not $runner) {
    Write-Host "[INFO] bun not found, attempting auto-install..." -ForegroundColor Cyan
    $installBun = Join-Path $ScriptDir "install_bun.ps1"
    if (Test-Path $installBun) {
        try {
            & $installBun
            if ($LASTEXITCODE -eq 0 -and (Test-Path $BunExe)) {
                $runner = $BunExe
                $runnerLabel = "auto-installed bun"
            }
        } catch {
            Write-Host "[WARN] bun install failed: $_" -ForegroundColor Yellow
        }
    }
}

# 4. npm fallback (Node.js always installed by setup.bat)
if (-not $runner) {
    Write-Host "[WARN] bun unavailable, falling back to npm..." -ForegroundColor Yellow
    $sysNpm = Get-Command "npm" -ErrorAction SilentlyContinue
    if ($sysNpm) {
        $runner = $sysNpm.Source
        $runnerLabel = "npm (fallback)"
    }
}

if (-not $runner) {
    Write-Host "[ERROR] No build runner available." -ForegroundColor Red
    Write-Host "         Tried: portable bun, system bun, auto-install bun, system npm." -ForegroundColor Red
    Write-Host "         Ensure Node.js is installed (run setup.bat)." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Runner: $runnerLabel" -ForegroundColor Green
Write-Host "     Path:  $runner"

# -- Run install ------------------------------------------------------------
Write-Host ""
Write-Host "[INFO] Running '$runner install' in app\webui..." -ForegroundColor Cyan
Write-Host "       (this may take several minutes for first run)"
Push-Location $WebuiDir
try {
    & $runner install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] $runner install failed (exit $LASTEXITCODE)" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} catch {
    Write-Host "[ERROR] $runner install exception: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}

# -- Run build --------------------------------------------------------------
Write-Host ""
Write-Host "[INFO] Running '$runner run build' in app\webui..." -ForegroundColor Cyan
try {
    & $runner run build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] $runner run build failed (exit $LASTEXITCODE)" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} catch {
    Write-Host "[ERROR] $runner run build exception: $_" -ForegroundColor Red
    Pop-Location
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
