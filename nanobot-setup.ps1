#Requires -Version 7.0
# setup.ps1 - Nanobot Portable Setup (PowerShell 7+)
#bin\pwsh7\pwsh -NoProfile .\nanobot-setup.ps1

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ROOT = $ScriptDir
Set-Location $ROOT

[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$Host.UI.RawUI.WindowTitle = "Nanobot Portable - Setup"

$PY_DIR      = Join-Path $ROOT "bin"
$APP_DIR     = Join-Path $ROOT "app"
$DATA_DIR    = Join-Path $ROOT "data"
$TMP_DIR     = Join-Path $ROOT "tmp"
$SCRIPTS_DIR = Join-Path $ROOT "scripts"

$env:PIP_CACHE_DIR = Join-Path $TMP_DIR "pip-cache"
$env:TMP  = $TMP_DIR
$env:TEMP = $TMP_DIR
$env:HOME = Join-Path $DATA_DIR "home"
$env:HOMEPATH = Join-Path $DATA_DIR "home"
$env:USERPROFILE = Join-Path $DATA_DIR "home"
$env:NPM_CONFIG_CACHE  = Join-Path $TMP_DIR "npm-cache"
$env:NPM_CONFIG_PREFIX = Join-Path $ROOT "bin\nodejs\global"

if (-not (Test-Path $TMP_DIR)) { New-Item -ItemType Directory -Path $TMP_DIR -Force | Out-Null }

$Is64    = [Environment]::Is64BitOperatingSystem
$ProcArch = [Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")

# Architecture-derived variables
$ArchPython      = if ($Is64) { "amd64" } else { "win32" }
$ArchNode        = if ($ProcArch -eq "ARM64") { "arm64" } elseif ($Is64) { "x64" } else { "x86" }
$ArchMinGit      = if ($Is64) { "64-bit" } else { "32-bit" }
$ArchPwsh        = if ($ProcArch -eq "ARM64") { "arm64" } elseif ($Is64) { "x64" } else { "x86" }
$MinGwDir        = if ($Is64) { "mingw64\bin" } else { "mingw32\bin" }

# Software version
$PyVer      = "3.12.0"
$GitVer     = "2.54.0"
$NodeVer    = "24.16.0"
$PS7Ver     = "7.6.2"

function Write-OK      { param([string]$T) Write-Host "         $T" -ForegroundColor Gray }
function Write-Step    { param([string]$T) Write-Host "`n$T" -ForegroundColor Cyan }
function Write-Info    { param([string]$T) Write-Host "         $T" -ForegroundColor Gray }
function Write-Error   { param([string]$T) Write-Host "  [ERROR] $T" -ForegroundColor Red }
function Write-Header  { param([string]$T) Write-Host "$T" -ForegroundColor Cyan }
function Write-Warn    { param([string]$T) Write-Host "  [WARN] $T" -ForegroundColor Yellow }

function Download-Helper {
    param([string]$Url, [string]$Out)
    & powershell -ExecutionPolicy Bypass -NoProfile -NonInteractive -File (Join-Path $SCRIPTS_DIR "download.ps1") -Url $Url -Out $Out
}
function Extract-Helper {
    param([string]$Zip, [string]$Dest)
    & powershell -ExecutionPolicy Bypass -NoProfile -NonInteractive -File (Join-Path $SCRIPTS_DIR "extract.ps1") -Zip $Zip -Dest $Dest
}

Write-Host "`n  ===================================================" -ForegroundColor Cyan
Write-Host "       NANOBOT USB SETUP - Simata.id" -ForegroundColor Cyan
Write-Host "  ===================================================" -ForegroundColor Cyan
Write-Host "  Folder: $ROOT"
Write-Host ""

$LockFile = Join-Path $DATA_DIR ".lockhead"
if (Test-Path $LockFile) {
    Write-Host "  [lockhead] Setup was already completed before."
    Write-Host "  Delete file:  data\.lockhead"
    Write-Host "  then run again to re-setup."
    Write-Host ""
    exit 0
}

# ===== STEP 1: INTERNET =====
Write-Step "===== STEP 1: INTERNET CONNECTION ====="
try {
    $ping = Test-Connection -ComputerName "github.com" -Count 1 -Quiet -ErrorAction Stop
    if (-not $ping) { throw "No response" }
    Write-OK "Internet OK"
} catch {
    Write-Error "Cannot reach github.com"
    pause
    exit 1
}
Write-OK ""

# ===== STEP 2: DIRECTORIES =====
Write-Step "===== STEP 2: CREATE DIRECTORIES ====="
if (-not (Test-Path $PY_DIR))    { New-Item -ItemType Directory -Path $PY_DIR -Force | Out-Null }
if (-not (Test-Path $DATA_DIR))  { New-Item -ItemType Directory -Path $DATA_DIR -Force | Out-Null }
$kd = Join-Path $DATA_DIR "knowledge"
if (-not (Test-Path $kd)) { New-Item -ItemType Directory -Path $kd -Force | Out-Null }
$ld = Join-Path $DATA_DIR "logs"
if (-not (Test-Path $ld)) { New-Item -ItemType Directory -Path $ld -Force | Out-Null }
if (-not (Test-Path $TMP_DIR))   { New-Item -ItemType Directory -Path $TMP_DIR -Force | Out-Null }
$homeDir = Join-Path $ROOT "data\home"
if (-not (Test-Path $homeDir)) { New-Item -ItemType Directory -Path $homeDir -Force | Out-Null }
if (-not (Test-Path $SCRIPTS_DIR)) { New-Item -ItemType Directory -Path $SCRIPTS_DIR -Force | Out-Null }
Write-OK "OK"
Write-OK ""

# ===== STEP 2b: CHECK HELPERS =====
Write-Step "===== STEP 2b: CHECK HELPER SCRIPTS ====="
$dh = Join-Path $SCRIPTS_DIR "download.ps1"
$eh = Join-Path $SCRIPTS_DIR "extract.ps1"
if (-not (Test-Path $dh)) {
    Write-Error "$dh NOT FOUND!"
    Write-Info "Create those files first."
    pause
    exit 1
}
if (-not (Test-Path $eh)) {
    Write-Error "$eh NOT FOUND!"
    Write-Info "Create those files first."
    pause
    exit 1
}
try {
    $null = & powershell -ExecutionPolicy Bypass -NoProfile -Command "Write-Host 'PS OK'" 2>&1
} catch {
    Write-Error "PowerShell cannot run!"
    pause
    exit 1
}
Write-OK "OK"
Write-OK ""

# ===== STEP 3: PYTHON =====
Write-Step "===== STEP 3: PREPARE PYTHON ====="
$PythonExe = Join-Path $PY_DIR "python.exe"
if (Test-Path $PythonExe) {
    Write-Info "Python already exists:"
    & $PythonExe --version
} else {
    $PyArch = $ArchPython
    $PyUrl = "https://www.python.org/ftp/python/$PyVer/python-$PyVer-embed-$PyArch.zip"
    $PyZip = Join-Path $TMP_DIR "python-embed.zip"
    Write-Info "Download Python $PyVer ($PyArch)..."
    if (Test-Path $PyZip) { Remove-Item -Path $PyZip -Force -ErrorAction SilentlyContinue }
    Download-Helper -Url $PyUrl -Out $PyZip
    if (-not (Test-Path $PyZip)) {
        Write-Error "Failed to download Python!"
        Write-Info "Manual download: $PyUrl"
        Write-Info "Save to: $PyZip"
        pause
        exit 1
    }
    $fi = Get-Item $PyZip
    Write-Info "File size: $($fi.Length) bytes"
    Write-Info "Extracting..."
    Extract-Helper -Zip $PyZip -Dest $PY_DIR
    if (-not (Test-Path $PythonExe)) {
        Write-Error "Failed to extract Python!"
        pause
        exit 1
    }
    Write-Info "Patching ._pth..."
    Get-ChildItem -Path $PY_DIR -Filter "*._pth" | ForEach-Object {
        $baseName = $_.BaseName
        Set-Content -Path $_.FullName -Value @(
            "$baseName.zip", ".", "Lib", "Lib\site-packages", "..\app"
        )
    }
    Write-Info "Python installed:"
    & $PythonExe --version
}
Write-OK ""

# ===== STEP 4: PIP =====
Write-Step "===== STEP 4: PREPARE PIP ====="
$pipExists = $false
try {
    $null = & $PythonExe -m pip --version 2>&1
    if ($LASTEXITCODE -eq 0) { $pipExists = $true }
} catch {}
if ($pipExists) {
    Write-Info "pip already exists:"
    & $PythonExe -m pip --version
} else {
    $GetPip = Join-Path $TMP_DIR "get-pip.py"
    if (Test-Path $GetPip) { Remove-Item -Path $GetPip -Force -ErrorAction SilentlyContinue }
    Write-Info "Download get-pip.py..."
    Download-Helper -Url "https://bootstrap.pypa.io/get-pip.py" -Out $GetPip
    if (-not (Test-Path $GetPip)) {
        Write-Error "Failed to download get-pip.py"
        pause
        exit 1
    }
    Write-Info "Installing pip..."
    & $PythonExe $GetPip --no-warn-script-location
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install pip"
        pause
        exit 1
    }
    Write-Info "pip installed:"
    & $PythonExe -m pip --version
}
Write-OK ""

TIMEOUT /T 6 /NOBREAK
cls

# ===== STEP 4.5: GIT =====
Write-Step "===== STEP 4.5: CHECK GIT ====="
$GitReady = $false

# Always use portable MinGit -- ignore host system Git
if (Test-Path (Join-Path $ROOT "bin\git\cmd\git.exe")) {
    Write-Info "Portable git found on USB."
    $GitReady = $true
    $env:PATH = "$ROOT\bin\pwsh7;$ROOT\bin\nodejs;$ROOT\bin\git\cmd;$ROOT\bin\git\$MinGwDir;$env:PATH"
} else {
    Write-Info "Git not found, downloading portable MinGit..."
    Write-Info "Download MinGit..."
    $GitUrl = "https://github.com/git-for-windows/git/releases/download/v${GitVer}.windows.1/MinGit-${GitVer}-${ArchMinGit}.zip"
    $GitZip = Join-Path $TMP_DIR "MinGit-${GitVer}-${ArchMinGit}.zip"
    Download-Helper -Url $GitUrl -Out $GitZip
    if (-not (Test-Path $GitZip)) {
        Write-Error "Failed to download MinGit!"
        pause
        exit 1
    }
    Write-Info "Extracting..."
    $GitDir = Join-Path $ROOT "bin\git"
    if (Test-Path $GitDir) { Remove-Item -Path $GitDir -Recurse -Force -ErrorAction SilentlyContinue }
    Extract-Helper -Zip $GitZip -Dest $GitDir
    if (Test-Path (Join-Path $GitDir "cmd\git.exe")) {
        Write-Info "MinGit installed successfully."
        Remove-Item -Path $GitZip -Force -ErrorAction SilentlyContinue
        $GitReady = $true
    }
    if (-not $GitReady) {
        # Check subfolder
        $nestedGit = Get-ChildItem -Path $GitDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName "cmd\git.exe") } | Select-Object -First 1
        if ($nestedGit) {
            Get-ChildItem -Path $nestedGit.FullName -Recurse | Move-Item -Destination $GitDir -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $nestedGit.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path (Join-Path $GitDir "cmd\git.exe")) {
            Write-Info "MinGit OK (subfolder)."
            Remove-Item -Path $GitZip -Force -ErrorAction SilentlyContinue
            $GitReady = $true
        }
    }
    if (-not $GitReady) {
        Write-Error "MinGit extraction failed!"
        if (Test-Path $GitDir) { Remove-Item -Path $GitDir -Recurse -Force -ErrorAction SilentlyContinue }
        pause
        exit 1
    }
    $env:PATH = "$ROOT\bin\pwsh7;$ROOT\bin\nodejs;$ROOT\bin\git\cmd;$ROOT\bin\git\$MinGwDir;$env:PATH"
}
Write-Info "Git:"
& git --version
Write-OK ""

cls

# ===== STEP 4.7: NODE.JS =====
Write-Step "===== STEP 4.7: CHECK NODE.JS ====="
$NodeDir = Join-Path $ROOT "bin\nodejs"
$NodeExe = Join-Path $NodeDir "node.exe"
$NodeReady = $false
if (Test-Path $NodeExe) {
    Write-Info "Node.js portable found on USB."
    $env:PATH = "$ROOT\bin\nodejs;$env:PATH"
    $NodeReady = $true
}
if (-not $NodeReady) {
    try {
        $null = & node --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "System Node.js found."
            $NodeReady = $true
        }
    } catch {}
}
if (-not $NodeReady) {
    Write-Info "Node.js not found, downloading portable..."
    Write-Info "Download Node.js v$NodeVer ($ArchNode)..."
    $NodeZipUrl = "https://nodejs.org/dist/v$NodeVer/node-v$NodeVer-win-$ArchNode.zip"
    $NodeZip = Join-Path $TMP_DIR "node-v$NodeVer-win-$ArchNode.zip"
    Download-Helper -Url $NodeZipUrl -Out $NodeZip
    if (-not (Test-Path $NodeZip)) {
        Write-Error "Failed to download Node.js!"
        pause
        exit 1
    }
    Write-Info "Extracting..."
    if (Test-Path $NodeDir) { Remove-Item -Path $NodeDir -Recurse -Force -ErrorAction SilentlyContinue }
    Extract-Helper -Zip $NodeZip -Dest $NodeDir
    if (Test-Path $NodeExe) {
        Write-Info "Node.js installed successfully."
        Remove-Item -Path $NodeZip -Force -ErrorAction SilentlyContinue
        $env:PATH = "$ROOT\bin\nodejs;$env:PATH"
        $NodeReady = $true
    }
    if (-not $NodeReady) {
        $nestedNode = Get-ChildItem -Path $NodeDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName "node.exe") } | Select-Object -First 1
        if ($nestedNode) {
            Copy-Item -Path "$($nestedNode.FullName)\*" -Destination $NodeDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $nestedNode.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $NodeExe) {
            Write-Info "Node.js OK (subfolder)."
            Remove-Item -Path $NodeZip -Force -ErrorAction SilentlyContinue
            $env:PATH = "$ROOT\bin\nodejs;$env:PATH"
            $NodeReady = $true
        }
    }
    if (-not $NodeReady) {
        Write-Error "Node.js extraction failed!"
        if (Test-Path $NodeDir) { Remove-Item -Path $NodeDir -Recurse -Force -ErrorAction SilentlyContinue }
        pause
        exit 1
    }
}
if ($NodeReady) {
    Write-Info "Node.js:"
    & $NodeExe --version
}
Write-OK ""
TIMEOUT /T 11 /NOBREAK
cls

# ===== STEP 4.9: POWERSHELL 7 PORTABLE =====
Write-Step "===== STEP 4.9: POWERSHELL 7 PORTABLE ====="
$PS7Dir = Join-Path $ROOT "bin\pwsh7"
$PS7Exe = Join-Path $PS7Dir "pwsh.exe"
$PS7Ready = $false

if (Test-Path $PS7Exe) {
    Write-Info "PowerShell 7 portable found on USB."
    $PS7Ready = $true
} else {
    Write-Info "PowerShell 7 not found, downloading portable..."
    $PS7Zip = Join-Path $TMP_DIR "PowerShell-$PS7Ver-win-$ArchPwsh.zip"
    $PS7Url = "https://github.com/PowerShell/PowerShell/releases/download/v$PS7Ver/PowerShell-$PS7Ver-win-$ArchPwsh.zip"
    Download-Helper -Url $PS7Url -Out $PS7Zip
    if (-not (Test-Path $PS7Zip)) {
        Write-Error "Failed to download PowerShell 7!"
        pause
        exit 1
    }
    if (Test-Path $PS7Dir) { Remove-Item -Path $PS7Dir -Recurse -Force -ErrorAction SilentlyContinue }
    Extract-Helper -Zip $PS7Zip -Dest $PS7Dir
    if (Test-Path $PS7Exe) {
        Write-Info "PowerShell 7 installed successfully."
        $PS7Ready = $true
        Remove-Item -Path $PS7Zip -Force -ErrorAction SilentlyContinue
    } else {
        Write-Error "PowerShell 7 extraction failed!"
        if (Test-Path $PS7Dir) { Remove-Item -Path $PS7Dir -Recurse -Force -ErrorAction SilentlyContinue }
        pause
        exit 1
    }
}
if ($PS7Ready) {
    $env:PATH = "$PS7Dir;$env:PATH"
}
Write-OK ""
cls

# ===== STEP 5: SOURCE CODE =====
Write-Step "===== STEP 5: PREPARE NANOBOT SOURCE CODE ====="
$SrcOk = $false
if (Test-Path $APP_DIR) {
    if (Test-Path (Join-Path $APP_DIR ".git")) {
        Write-Info "Update repo..."
        & git -C $APP_DIR pull
        $SrcOk = $true
    }
}
if (-not $SrcOk) {
    try {
        $null = & git --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Cloning repository..."
            if (Test-Path $APP_DIR) { Remove-Item -Path $APP_DIR -Recurse -Force -ErrorAction SilentlyContinue }
            & git clone --depth 1 --single-branch --branch main https://github.com/HKUDS/nanobot.git $APP_DIR
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Clone successful."
                $SrcOk = $true
            } else {
                Write-Info "Clone failed, trying ZIP..."
            }
        }
    } catch {}
}
if (-not $SrcOk) {
    $RepoZip = Join-Path $TMP_DIR "nanobot-main.zip"
    if (Test-Path $RepoZip) { Remove-Item -Path $RepoZip -Force -ErrorAction SilentlyContinue }
    Write-Info "Download ZIP..."
    Download-Helper -Url "https://github.com/HKUDS/nanobot/archive/refs/heads/main.zip" -Out $RepoZip
    if (-not (Test-Path $RepoZip)) {
        Write-Error "Failed to download source code!"
        pause
        exit 1
    }
    Write-Info "Extracting ZIP..."
    $ExtractDir = Join-Path $TMP_DIR "repo_extract"
    if (Test-Path $ExtractDir) { Remove-Item -Path $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
    Extract-Helper -Zip $RepoZip -Dest $ExtractDir
    $extracted = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
    if ($extracted) {
        if (Test-Path $APP_DIR) { Remove-Item -Path $APP_DIR -Recurse -Force -ErrorAction SilentlyContinue }
        Move-Item -Path $extracted.FullName -Destination $APP_DIR -Force
    }
    Remove-Item -Path $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path (Join-Path $APP_DIR "README.md")) {
        Write-OK "ZIP successful."
    } else {
        Write-Error "Extraction failed"
        pause
        exit 1
    }
}
Write-OK ""

# ===== PORTABLE PATHS PATCH =====
$patchScript = Join-Path $SCRIPTS_DIR "portable_paths.py"
if (Test-Path $patchScript) {
    Write-Info "Apply portable paths patch..."
    & $PythonExe $patchScript
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Patch failed. Setup continues."
    } else {
        Write-OK "Path patch applied."
    }
}
Write-OK ""

cls

# ===== STEP 6: DEPENDENCIES =====
Write-Step "===== STEP 6: INSTALL DEPENDENCIES ====="
Write-Step "         [API ONLY MODE]"
Write-Info "Install lightweight dependencies..."
Write-OK ""

& $PythonExe -m pip install --no-warn-script-location --upgrade pip setuptools wheel
Write-OK ""

& $PythonExe -m pip install --no-warn-script-location hatchling hatch-vcs
Write-OK ""

$ReqFile = Join-Path $SCRIPTS_DIR "requirements-api-only.txt"
if (Test-Path $ReqFile) {
    Write-Info "Built requirements-api-only.txt ..."
    & $PythonExe -m pip install --no-warn-script-location -r $ReqFile
} else {
    Write-Warn "file scripts\requirements-api-only.txt not found."
    Write-Info "Install core packages manually..."
    & $PythonExe -m pip install --no-warn-script-location openai tiktoken fastapi uvicorn pydantic python-dotenv tqdm click numpy
}
Write-OK ""

Write-Info "Built nanobot core..."
$env:NANOBOT_SKIP_WEBUI_BUILD = "1"
$PyProject = Join-Path $APP_DIR "pyproject.toml"
if (Test-Path $PyProject) {
    & $PythonExe -m pip install --no-warn-script-location --no-deps $APP_DIR
} elseif (Test-Path $APP_DIR) {
    Write-Info "Adding app to PYTHONPATH..."
}
Write-OK ""

Write-OK ""
Write-Header "  ----------------------------------------"
Write-Header "  Installed packages:"
& $PythonExe -m pip list 2>$null
Write-Header "  ----------------------------------------"
Write-OK ""

# ===== STEP 7: CONFIGURATION =====
Write-Step "===== STEP 7: GENERATE CONFIGURATION ====="
$env:NANOBOT_HOME = $DATA_DIR
$ConfigFile = Join-Path $DATA_DIR "config.json"
$WorkspaceDir = "data/.nanobot/workspace"
if (Test-Path $ConfigFile) {
    Write-Info "config.json already exists. Skipping."
} else {
    Write-Info "Generate config via nanobot onboard..."
    & $PythonExe -m nanobot onboard "--config=$ConfigFile" "--workspace=$WorkspaceDir"
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Failed to generate config.json!"
        pause
        exit 1
    }
    Write-Info "Post-process config for portable..."
    Copy-Item -Path $ConfigFile -Destination "$ConfigFile.prebak" -Force -ErrorAction SilentlyContinue
    & $PythonExe (Join-Path $SCRIPTS_DIR "post_config.py") $ConfigFile $ROOT
}
Write-OK "config.json ready."

& $PythonExe (Join-Path $SCRIPTS_DIR "write_lockhead.py") $ROOT
Write-OK "lockhead installed."

$EnvFile = Join-Path $DATA_DIR ".env"
if (-not (Test-Path $EnvFile)) {
    Write-Info "Create .env template..."
    Set-Content -Path $EnvFile -Value @(
        "# Nanobot Portable - Environment Variables"
        "# Fill in API key before running the bot"
        ""
        "NANOBOT_CUSTOM_API_KEY=sk-your-api-key-here"
        "NANOBOT_CUSTOM_API_BASE=https://your-api-endpoint/v1"
    ) -Encoding Ascii
    Write-OK ".env created."
    Write-Warn "!!! Edit first: data\.env - fill in API key !!!"
} else {
    Write-OK ".env already exists."
}
Write-OK ""

# ===== CLEANUP PRE-BUILD FILES =====
Remove-Item -Path (Join-Path $TMP_DIR "python-embed.zip") -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $TMP_DIR "get-pip.py") -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $TMP_DIR "nanobot-main.zip") -Force -ErrorAction SilentlyContinue

# ===== VERIFICATION =====
Write-Header ""
Write-Header "  ==================================================="
Write-Header "               VERIFICATION!"
Write-Header "  ==================================================="
Write-Host ""

Write-Host "  Python: " -NoNewline
& $PythonExe --version 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "    [MISSING]" }

Write-Host "  pip: " -NoNewline
& $PythonExe -m pip --version 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "    [MISSING]" }

Write-Host "  Source code: " -NoNewline
if (Test-Path (Join-Path $APP_DIR "README.md")) { Write-OK "OK" } else { Write-Host "    [MISSING]" }

Write-Host "  Config: " -NoNewline
if (Test-Path (Join-Path $DATA_DIR "config.json")) { Write-OK "OK (config.json)" } else { Write-Host "    [MISSING] config.json" }

Write-Host "  .env: " -NoNewline
if (Test-Path $EnvFile) { Write-OK "OK" } else { Write-Host "    [MISSING]" }
Write-Host ""

# ===== LOCKHEAD FALLBACK =====
if (-not (Test-Path (Join-Path $DATA_DIR ".lockhead"))) {
    & $PythonExe (Join-Path $SCRIPTS_DIR "write_lockhead.py") $ROOT
    Write-Info ".lockhead created."
}
Write-Info "    Please wait..."
Write-OK ""

# ===== HEALTH CHECK =====
Write-Header ""
Write-Header "  ==================================================="
Write-Header "               HEALTH CHECK"
Write-Header "  ==================================================="
Write-Host ""
Write-Info "Running system verification..."
$HealthScript = Join-Path $SCRIPTS_DIR "healthcheck.py"
if (Test-Path $HealthScript) {
    & $PythonExe $HealthScript
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Health check passed!"
    } else {
        Write-Warn "Health check reported warnings. Review output above."
    }
} else {
    Write-Warn "healthcheck.py not found, skipping."
}
Write-OK ""

# ===== FINAL CLEANUP =====
if (Test-Path $APP_DIR) { Remove-Item -Path $APP_DIR -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path $TMP_DIR) { Remove-Item -Path $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue }
TIMEOUT /T 11 /NOBREAK
cls

# ===== FINISH SETUP =====
Write-Header ""
Write-Header "  ==================================================="
Write-Header "             SETUP COMPLETE!"
Write-Header "  ==================================================="
Write-Host ""
Write-Host "  NEXT STEPS:"
Write-Host "    1. Run  edit_env.bat  to  Encrypt  your API KEY"
Write-Host "    2. Run  start_chat.bat  or  start_gate.bat"
Write-Host ""
pause
