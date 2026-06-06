# setup_helpers.ps1 - Helper functions for setup process

function Write-OK {
    param([string]$T)
    Write-Host "         $T" -ForegroundColor Gray
}

function Write-Step {
    param([string]$T)
    Write-Host "`n$T" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$T)
    Write-Host "         $T" -ForegroundColor Gray
}

function Write-Error {
    param([string]$T)
    Write-Host "  [ERROR] $T" -ForegroundColor Red
}

function Write-Header {
    param([string]$T)
    Write-Host "$T" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$T)
    Write-Host "  [WARN] $T" -ForegroundColor Yellow
}

function Download-Helper {
    param([string]$Url, [string]$Out)
    & powershell -ExecutionPolicy Bypass -NoProfile -NonInteractive -File (Join-Path $SCRIPTS_DIR "setup\download.ps1") -Url $Url -Out $Out
}

function Extract-Helper {
    param([string]$Zip, [string]$Dest)
    & powershell -ExecutionPolicy Bypass -NoProfile -NonInteractive -File (Join-Path $SCRIPTS_DIR "setup\extract.ps1") -Zip $Zip -Dest $Dest
}
