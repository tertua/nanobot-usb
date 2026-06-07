# nanobot-gateway.ps1 - Nanobot Portable Gateway (PowerShell 5.1+)
# Place this script at the Nanobot root directory (\nanobot-usb\)

# Universal execution policy handler
$currentPolicy = Get-ExecutionPolicy
if ($currentPolicy -match 'Restricted|AllSigned') {
    $psExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
    Write-Host "Relaunching with execution policy bypass..." -ForegroundColor Yellow
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    exit $LASTEXITCODE
}

$ErrorActionPreference = 'Stop'

# -- Root directory = script location --------------------------------
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ROOT = $ScriptDir

Set-Location $ROOT

# -- Load portable environment setup ---------------------------------
. (Join-Path $ROOT "scripts\init_portable.ps1")

# -- UTF-8 output ----------------------------------------------------
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

# -- Paths -----------------------------------------------------------
$PY        = Join-Path $ROOT "bin\python.exe"
$CONFIG    = Join-Path $DATA_DIR "config.json"
$WORKSPACE = Join-Path $DATA_DIR "workspace"

# -- Read ports from config.json --------------------------------------
$HTTP_PORT = $null
$WS_PORT   = $null
try {
    $cfg = Get-Content -Path $CONFIG -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($cfg.api -and $cfg.api.port)                       { $HTTP_PORT = [int]$cfg.api.port }
    if ($cfg.channels.websocket -and $cfg.channels.websocket.port) { $WS_PORT   = [int]$cfg.channels.websocket.port }
} catch {
    Write-Warn "Could not read ports from $CONFIG : $($_.Exception.Message). Using defaults."
}

if (-not $HTTP_PORT) { $HTTP_PORT = 8900 }
if (-not $WS_PORT)   { $WS_PORT   = 8765 }

$WS_HOST = "127.0.0.1"

# -- Check Python ----------------------------------------------------
if (-not (Test-Path $PY)) {
    Write-Host "`n  [ERROR] Python not found: $PY" -ForegroundColor Red
    Write-Host "  Setup incomplete.`n" -ForegroundColor Red
    exit 1
}

# -- Check Config ----------------------------------------------------
if (-not (Test-Path $CONFIG)) {
    Write-Host "`n  [ERROR] Config not found: $CONFIG" -ForegroundColor Red
    Write-Host "  Run setup.bat or copy config first.`n" -ForegroundColor Red
    exit 1
}

# -- Check / kill process on target port -----------------------------
$portInUse = $false
try {
    $netstat = netstat -ano | Select-String ":$WS_PORT " | Select-String "LISTENING"
    if ($netstat) {
        $portInUse = $true
    }
} catch { }

if ($portInUse) {
    Write-Host "`n  [INFO] Port $WS_PORT already in use." -ForegroundColor Yellow
    $choice = $host.UI.PromptForChoice("Port Conflict", "Kill the process using it and restart?", @("&Yes", "&No"), 1)
    if ($choice -eq 0) {
        try {
            $netstat | ForEach-Object {
                if ($_ -match '\s+(\d+)$') {
                    $pid = $matches[1]
                    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                }
            }
            Start-Sleep -Seconds 2
        } catch { }
    } else {
        exit 0
    }
}

# -- Banner ----------------------------------------------------------
Write-Host "`n"
Write-Host "  $('=' * 49)" -ForegroundColor Cyan
Write-Host "       NANOBOT GATEWAY - Simata.id" -ForegroundColor Cyan
Write-Host "  $('=' * 49)" -ForegroundColor Cyan
Write-Host "`n"

Write-Host "  Home  : $NANOBOT_HOME" -ForegroundColor Green
Write-Host "  Conf  : $CONFIG" -ForegroundColor Green
Write-Host "  Works : $WORKSPACE" -ForegroundColor Green
Write-Host "`n"
Write-Host "  Host  : $WS_HOST" -ForegroundColor Green
Write-Host "  Port  : $WS_PORT" -ForegroundColor Green
Write-Host "  $('=' * 47)" -ForegroundColor Cyan
Write-Host "`n  Please wait..." -ForegroundColor Yellow

# -- Resolve workspace from config.json ------------------------------
try {
    $ResolveScript = Join-Path $ROOT "scripts\resolve_workspace.py"
    if (Test-Path $ResolveScript) {
        $resolved = & $PY $ResolveScript $CONFIG $ROOT 2>$null
        if ($LASTEXITCODE -eq 0 -and $resolved) {
            $WORKSPACE = $resolved.Trim()
        }
    }
} catch {
    # fallback: keep default WORKSPACE
}

# -- Load .env (AES-GCM scrypt) --------------------------------------
Load-EnvEncrypted -Root $ROOT -DataDir $DATA_DIR -Python $PY

# -- Inject portable PATH --------------------------------------------
$PortablePaths = @(
    Join-Path $ROOT "bin"
    Join-Path $ROOT "bin\nodejs"
    Join-Path $ROOT "bin\git\cmd"
    Join-Path $ROOT "bin\git\mingw64\bin"
    Join-Path $ROOT "scripts"
    $DATA_DIR
)
$env:PATH = ($PortablePaths -join ';') + ';' + $env:PATH

# -- Kill existing processes on same ports --------------------------
try {
    netstat -ano | Select-String ":$HTTP_PORT " | Select-String "LISTENING" | ForEach-Object {
        if ($_ -match '\s+(\d+)$') {
            Stop-Process -Id $matches[1] -Force -ErrorAction SilentlyContinue
        }
    }
    netstat -ano | Select-String ":$WS_PORT " | Select-String "LISTENING" | ForEach-Object {
        if ($_ -match '\s+(\d+)$') {
            Stop-Process -Id $matches[1] -Force -ErrorAction SilentlyContinue
        }
    }
} catch { }

Write-Host "`n"
Write-Host "  Browser: http://$WS_HOST`:$WS_PORT" -ForegroundColor Green

# -- 10-second countdown ----------------------------------------------
Write-Host "`n  Starting Gateway in 10 seconds..." -ForegroundColor Yellow
for ($i = 10; $i -ge 1; $i--) {
    Write-Host "  `r$i second(s) remaining..." -NoNewline
    Start-Sleep -Seconds 1
}
Write-Host "`r                              " -NoNewline
Write-Host "`n"

Write-Host "  HTTP Port : $HTTP_PORT (for Health/API)" -ForegroundColor Gray
Write-Host "  WS Port   : $WS_PORT (for WebSocket/UI)" -ForegroundColor Gray
Write-Host "`n"

# -- Run Gateway ------------------------------------------------------
try {
    & $PY -m nanobot gateway `
        "--config=$CONFIG" `
        "--port=$HTTP_PORT"
    $exitCode = $LASTEXITCODE
} catch {
    Write-Host "`n  [ERROR] Gateway crashed: $_" -ForegroundColor Red
    $exitCode = 1
}

Write-Host "`n"
Write-Host "  Nanobot Gateway Stopped." -ForegroundColor Cyan
Write-Host "`n  Press Enter to exit..." -NoNewline
$null = Read-Host
