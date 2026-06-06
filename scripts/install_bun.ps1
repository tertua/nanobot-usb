# install_bun.ps1 - Download & extract portable bun (Windows x64)
# Usage: . (Join-Path $SCRIPTS_DIR "install_bun.ps1")
#        powershell -File install_bun.ps1
#
# Why: Optional build dependency for build-webui.bat. Upstream hatch_build.py
# prefers bun over npm. Lite does not ship bun by default; this script
# downloads the portable Windows build on first use.
#
# Idempotent: exits 0 immediately if bin/bun/bun.exe already exists.
# Called by install_webui.ps1; can also be invoked manually.

$ErrorActionPreference = 'Stop'

# -- Root resolution --------------------------------------------------------
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ROOT = Split-Path -Parent $ScriptDir

# -- Paths ------------------------------------------------------------------
$BinDir  = Join-Path $ROOT "bin"
$BunDir  = Join-Path $BinDir "bun"
$BunExe  = Join-Path $BunDir "bun.exe"
$TmpDir  = Join-Path $ROOT "tmp"

# -- Version (edit this line to change bun version) -------------------------
$BunVer  = "1.3.14"

# -- Arch detection (Lite targets x64 / ARM64) ------------------------------
$ProcArch = $env:PROCESSOR_ARCHITECTURE
$Arch     = if ($ProcArch -eq "ARM64") { "arm64" } else { "x64" }

# -- Idempotent: skip if already installed ---------------------------------
if (Test-Path $BunExe) {
    $ver = & $BunExe --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $ver) {
        Write-Host "[OK] bun already installed: $ver" -ForegroundColor Green
        Write-Host "     Path: $BunExe"
        Write-Host "     (delete this file to force re-install)"
        exit 0
    }
}

# -- Pre-flight: ensure target dirs exist -----------------------------------
if (-not (Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir -Force | Out-Null }
if (-not (Test-Path $TmpDir)) { New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null }
if (-not (Test-Path $BunDir)) { New-Item -ItemType Directory -Path $BunDir -Force | Out-Null }

# -- Download ---------------------------------------------------------------
# Always pull the `-baseline` variant: portable across any x64 CPU since ~2008,
# no AVX2 required. The optimized `bun-windows-x64.zip` panics on older hosts.
$ZipUrl  = "https://github.com/oven-sh/bun/releases/download/bun-v$BunVer/bun-windows-$Arch-baseline.zip"
$ZipPath = Join-Path $TmpDir "bun-windows-$Arch-baseline.zip"

Write-Host "[INFO] Downloading bun v$BunVer ($Arch, baseline)..." -ForegroundColor Cyan
Write-Host "       From: $ZipUrl"
Write-Host "       To:   $ZipPath"

# Try download (with one retry)
$maxAttempts = 2
$success = $false
for ($i = 1; $i -le $maxAttempts; $i++) {
    try {
        if ($i -gt 1) { Write-Host "[INFO] Retry $i/$maxAttempts..." -ForegroundColor Yellow }
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop
        $ProgressPreference = 'Continue'
        if (Test-Path $ZipPath) {
            $size = (Get-Item $ZipPath).Length
            if ($size -gt 100000) {  # bun zip is ~50MB
                $success = $true
                break
            }
        }
    } catch {
        Write-Host "[WARN] Download attempt $i failed: $_" -ForegroundColor Yellow
    }
}

if (-not $success) {
    Write-Host "[ERROR] Failed to download bun v$BunVer from GitHub." -ForegroundColor Red
    Write-Host "         Check network, or edit `$BunVer in this script to a known-good version." -ForegroundColor Red
    Write-Host "         Fallback: install_webui.ps1 will use npm if bun is unavailable." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Downloaded $([math]::Round((Get-Item $ZipPath).Length / 1MB, 1)) MB" -ForegroundColor Green

# -- Extract ----------------------------------------------------------------
Write-Host "[INFO] Extracting bun to $BunDir..." -ForegroundColor Cyan

# Use Expand-Archive (built-in, PS5.1+)
try {
    Expand-Archive -Path $ZipPath -DestinationPath $BunDir -Force -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Extract failed: $_" -ForegroundColor Red
    Write-Host "         Trying unzip.vbs fallback..." -ForegroundColor Yellow
    $vbs = Join-Path $ROOT "scripts\unzip.vbs"
    if (Test-Path $vbs) {
        try {
            & cscript //NoLogo $vbs $ZipPath $BunDir
        } catch {
            Write-Host "[ERROR] unzip.vbs fallback also failed: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        exit 1
    }
}

# -- Verify -----------------------------------------------------------------
# Bun's Windows zip may have bun.exe at root or under bun-windows-x64/
if (-not (Test-Path $BunExe)) {
    $nested = Get-ChildItem -Path $BunDir -Recurse -Filter "bun.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nested) {
        Write-Host "[INFO] Found bun.exe at nested path: $($nested.FullName)" -ForegroundColor Cyan
        # Move to expected location
        Move-Item -Path $nested.FullName -Destination $BunExe -Force
        # Clean nested dir
        Get-ChildItem -Path $BunDir -Directory | ForEach-Object {
            $contents = Get-ChildItem -Path $_.FullName -Recurse
            if ($contents.Count -eq 0) { Remove-Item $_.FullName -Recurse -Force }
        }
    } else {
        Write-Host "[ERROR] bun.exe not found after extract." -ForegroundColor Red
        Write-Host "         Expected: $BunExe" -ForegroundColor Red
        exit 1
    }
}

# -- Cleanup ----------------------------------------------------------------
Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue

# -- Report -----------------------------------------------------------------
$ver = & $BunExe --version 2>$null
Write-Host "[OK] bun installed: v$ver" -ForegroundColor Green
Write-Host "     Path: $BunExe"
