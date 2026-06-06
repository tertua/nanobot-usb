# init_portable.ps1 - Portable environment initialization (shared)
# Dot-source this from all main .ps1 scripts
# on Windows: PATH, SYSTEMROOT, COMSPEC, USERPROFILE, and related system variables are forwarded.
# docs: `https://learn.microsoft.com/en-us/powershell/scripting/learn/shell/creating-profiles?view=powershell-5.1`
# Usage: . (Join-Path $ROOT "scripts\init_portable.ps1")

if (-not $ROOT) {
    Write-Error "init_portable.ps1 requires `$ROOT to be defined in calling scope"
    exit 1
}

# -- Common portable paths --------------------------------------------
$DATA_DIR = Join-Path $ROOT "data"
$HOME_DIR = Join-Path $DATA_DIR "home"
$TMP_DIR  = Join-Path $ROOT "tmp"
$NANOBOT_HOME = $DATA_DIR

# -- Redirect environment variables to portable locations -------------
$Env:USERPROFILE      = $HOME_DIR
$Env:HOME             = $HOME_DIR
$Env:HOMEPATH         = $HOME_DIR
$Env:LOCALAPPDATA     = Join-Path $HOME_DIR "AppData\Local"
$Env:APPDATA          = Join-Path $HOME_DIR "AppData\Roaming"
$Env:TMP              = $TMP_DIR
$Env:TEMP             = $TMP_DIR
$Env:NANOBOT_HOME     = $DATA_DIR
$Env:GH_CONFIG_DIR 	  = $APPDATA

# -- Python/Node.js cache paths ---------------------------------------
$Env:PIP_CACHE_DIR    = Join-Path $TMP_DIR "pip-cache"
$Env:NPM_CONFIG_CACHE = Join-Path $TMP_DIR "npm-cache"
$Env:NPM_CONFIG_PREFIX = Join-Path $ROOT "bin\nodejs\global"

# -- Create portable directories if missing ---------------------------
if (-not (Test-Path $HOME_DIR)) { 
    New-Item -ItemType Directory -Path $HOME_DIR -Force | Out-Null 
}
if (-not (Test-Path (Join-Path $HOME_DIR "AppData\Local"))) { 
    New-Item -ItemType Directory -Path (Join-Path $HOME_DIR "AppData\Local") -Force | Out-Null 
}
if (-not (Test-Path (Join-Path $HOME_DIR "AppData\Roaming"))) { 
    New-Item -ItemType Directory -Path (Join-Path $HOME_DIR "AppData\Roaming") -Force | Out-Null 
}
if (-not (Test-Path $TMP_DIR)) {
    New-Item -ItemType Directory -Path $TMP_DIR -Force | Out-Null
}

function Load-EnvEncrypted {
    param(
        [string]$Root,
        [string]$DataDir,
        [string]$Python
    )

    $EnvFileEnc = Join-Path $DataDir ".env.encrypted"
    $EnvKeyFile = Join-Path $DataDir ".env_key"
    $EnvTmpFile = Join-Path $DataDir ".env.tmp"
    $EnvPlain   = Join-Path $DataDir ".env"

    if (Test-Path $EnvFileEnc) {
        if (Test-Path $EnvKeyFile) {
            $env:NANOBOT_ENV_KEY = (Get-Content -Path $EnvKeyFile -TotalCount 1).Trim()
            & $Python (Join-Path $Root "scripts\env_crypt.py") load --noninteractive
        } else {
            & $Python (Join-Path $Root "scripts\env_crypt.py") load
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
}
