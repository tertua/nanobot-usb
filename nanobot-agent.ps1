#Requires -Version 7.0
# nanobot-agent.ps1 - Nanobot Portable CLI Chat (PowerShell 7+)
# Place this script at the Nanobot root directory (\nanobot-usb\).

$ErrorActionPreference = 'Stop'

# ── Root directory = script location ────────────────────────────────
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ROOT = $ScriptDir

Set-Location $ROOT

# ── UTF-8 output ────────────────────────────────────────────────────
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

# ── Paths ───────────────────────────────────────────────────────────
$PY             = Join-Path $ROOT "bin\python.exe"
$DATA_DIR       = Join-Path $ROOT "data"
$NANOBOT_HOME   = $DATA_DIR
$CONFIG         = Join-Path $NANOBOT_HOME "config.json"
$WORKSPACE      = Join-Path $NANOBOT_HOME "workspace"
$HOME_DIR       = Join-Path $NANOBOT_HOME "home"
$USERPROFILE    = $HOME_DIR

# ── Check Python ────────────────────────────────────────────────────
if (-not (Test-Path $PY)) {
    Write-Host "`n  [ERROR] Python not found: $PY" -ForegroundColor Red
    Write-Host "  Setup incomplete.`n" -ForegroundColor Red
    exit 1
}

# ── Check Config ────────────────────────────────────────────────────
if (-not (Test-Path $CONFIG)) {
    Write-Host "`n  [ERROR] Config not found: $CONFIG" -ForegroundColor Red
    Write-Host "  Run setup.bat or copy config first.`n" -ForegroundColor Red
    exit 1
}

# ── Banner ──────────────────────────────────────────────────────────
Write-Host "`n"
Write-Host "  $('═' * 49)" -ForegroundColor Cyan
Write-Host "       NANOBOT PORTABLE - Simata.id" -ForegroundColor Cyan
Write-Host "  $('═' * 49)" -ForegroundColor Cyan
Write-Host "`n"

# ── Load .env (AES-GCM scrypt) ──────────────────────────────────────
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

# ── Environment ─────────────────────────────────────────────────────
$env:NANOBOT_HOME = $NANOBOT_HOME
$env:HOME = $HOME_DIR
$env:HOMEPATH = $HOME_DIR
$env:USERPROFILE = $HOME_DIR

# ── Inject portable PATH ────────────────────────────────────────────
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

# ── Resolve workspace from config.json ──────────────────────────────
try {
    $ResolveScript = Join-Path $ROOT "scripts\resolve_workspace.py"
    if (Test-Path $ResolveScript) {
        $WORKSPACE = & $PY $ResolveScript $CONFIG $ROOT 2>$null
        if ($LASTEXITCODE -eq 0 -and $WORKSPACE) {
            $WORKSPACE = $WORKSPACE.Trim()
        }
    }
} catch {
    # fallback: keep default WORKSPACE
}

# ── Info ────────────────────────────────────────────────────────────
Write-Host "  $('=' * 47)" -ForegroundColor Cyan
Write-Host "`n"
Write-Host "  Home  : $NANOBOT_HOME" -ForegroundColor Green
Write-Host "  Conf  : $CONFIG" -ForegroundColor Green
Write-Host "  Works : $WORKSPACE" -ForegroundColor Green
Write-Host "`n"
Write-Host "  $('=' * 47)" -ForegroundColor Cyan
Write-Host "`n  Type your command, then press Esc → Enter`n" -ForegroundColor Yellow

# ── Run Agent ───────────────────────────────────────────────────────
try {
    & $PY -m nanobot agent "--config=$CONFIG"
    $exitCode = $LASTEXITCODE
} catch {
    Write-Host "`n  [ERROR] Agent crashed: $_" -ForegroundColor Red
    $exitCode = 1
}

Write-Host "`n  Chat session ended (exit code: $exitCode)" -ForegroundColor Gray

if ($exitCode -ne 0) {
    Write-Host "`n  Press Enter to exit..." -NoNewline
    $null = Read-Host
}
