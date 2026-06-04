#Requires -Version 7.0
# nanobot-gateway.ps1 - Nanobot Portable Gateway (PowerShell 7+)
# Place this script at the Nanobot root directory (\nanobot-usb\)
# PS X:\nanobot-usb> pwsh -NoProfile .\nanobot-gateway.ps1

$ErrorActionPreference = 'Stop'

# -- Root directory = script location --------------------------------
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ROOT = $ScriptDir

Set-Location $ROOT

# -- UTF-8 output ----------------------------------------------------
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

# -- Paths -----------------------------------------------------------
$PY        = Join-Path $ROOT "bin\python.exe"
$DATA_DIR  = Join-Path $ROOT "data"
$NANOBOT_HOME = $DATA_DIR
$CONFIG    = Join-Path $NANOBOT_HOME "config.json"
$WORKSPACE = Join-Path $NANOBOT_HOME "workspace"
$HOME_DIR  = Join-Path $DATA_DIR "home"
$USERPROFILE = $HOME_DIR

# -- Read ports from config.json via Python ----------------------------
$HTTP_PORT = $null
$WS_PORT   = $null
try {
    $configJson = & $PY -c "import json; c=json.load(open(r'$CONFIG')); print(c['api']['port'], c['channels']['websocket']['port'])" 2>$null
    if ($LASTEXITCODE -eq 0 -and $configJson) {
        $parts = $configJson.Trim() -split '\s+'
        if ($parts.Count -ge 2) {
            $HTTP_PORT = $parts[0]
            $WS_PORT   = $parts[1]
        }
    }
} catch {
    # fallback to defaults
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
$EnvFileEnc = Join-Path $DATA_DIR ".env.encrypted"
$EnvKeyFile = Join-Path $DATA_DIR ".env_key"
$EnvTmpFile = Join-Path $DATA_DIR ".env.tmp"
$EnvPlain   = Join-Path $DATA_DIR ".env"

if (Test-Path $EnvFileEnc) {
    if (Test-Path $EnvKeyFile) {
        $ENV_KEY = (Get-Content -Path $EnvKeyFile -First 1).Trim()
        $env:NANOBOT_ENV_KEY = $ENV_KEY
        & $PY (Join-Path $ROOT "scripts\env_crypt.py") load --noninteractive
    } else {
        & $PY (Join-Path $ROOT "scripts\env_crypt.py") load
    }

    if (Test-Path $EnvTmpFile) {
        Get-Content -Path $EnvTmpFile | ForEach-Object {
			$idx = $_.IndexOf('=')
			if ($idx -gt 0) {
				$name = $_.Substring(0, $idx).Trim()
				$val  = $_.Substring($idx + 1).Trim()
				[Environment]::SetEnvironmentVariable($name, $val, 'Process')
			}
        }
        Remove-Item -Path $EnvTmpFile -Force
    }
} elseif (Test-Path $EnvPlain) {
    Get-Content -Path $EnvPlain | ForEach-Object {
		$idx = $_.IndexOf('=')
		if ($idx -gt 0) {
			$name = $_.Substring(0, $idx).Trim()
			$val  = $_.Substring($idx + 1).Trim()
			[Environment]::SetEnvironmentVariable($name, $val, 'Process')
		}
    }
}

# -- Environment -----------------------------------------------------
$env:NANOBOT_HOME = $NANOBOT_HOME
$env:HOME = $HOME_DIR
$env:HOMEPATH = $HOME_DIR
$env:USERPROFILE = $HOME_DIR

# -- Inject portable PATH --------------------------------------------
$PortablePaths = @(
    Join-Path $ROOT "bin"
    Join-Path $ROOT "bin\pwsh7"    
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
