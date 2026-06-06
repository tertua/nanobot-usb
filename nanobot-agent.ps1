# nanobot-agent.ps1 - Nanobot Portable CLI Chat (PowerShell 5.1+)
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

# -- Banner ----------------------------------------------------------
Write-Host "`n"
Write-Host "  $('=' * 49)" -ForegroundColor Cyan
Write-Host "       NANOBOT PORTABLE - Simata.id" -ForegroundColor Cyan
Write-Host "  $('=' * 49)" -ForegroundColor Cyan
Write-Host "`n"

# -- Load .env (AES-GCM scrypt) --------------------------------------
$EnvFileEnc = Join-Path $DATA_DIR ".env.encrypted"
$EnvKeyFile = Join-Path $DATA_DIR ".env_key"
$EnvTmpFile = Join-Path $DATA_DIR ".env.tmp"
$EnvPlain   = Join-Path $DATA_DIR ".env"

if (Test-Path $EnvFileEnc) {
    if (Test-Path $EnvKeyFile) {
        $ENV_KEY = (Get-Content -Path $EnvKeyFile -TotalCount 1).Trim()
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

# All Environment load from scripts\init_portable.ps1





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

# -- Resolve workspace from config.json ------------------------------
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

# -- Info ------------------------------------------------------------
Write-Host "  $('=' * 47)" -ForegroundColor Cyan
Write-Host "`n"
Write-Host "  Home  : $NANOBOT_HOME" -ForegroundColor Green
Write-Host "  Conf  : $CONFIG" -ForegroundColor Green
Write-Host "  Works : $WORKSPACE" -ForegroundColor Green
Write-Host "`n"
Write-Host "  $('=' * 47)" -ForegroundColor Cyan
Write-Host "`n  Type your command, Press ESC and then ENTER`n" -ForegroundColor Yellow

# -- Run Agent -------------------------------------------------------
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
