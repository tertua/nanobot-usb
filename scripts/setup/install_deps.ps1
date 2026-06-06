# install_deps.ps1 - Dependencies and configuration module
# Usage: . (Join-Path $SCRIPTS_DIR "install_deps.ps1")

# ===== STEP 6: DEPENDENCIES =====
Write-Step "===== STEP 6: INSTALL DEPENDENCIES ====="
Write-Step "         [API ONLY MODE]"
Write-Info "Install lightweight dependencies..."
Write-OK ""

& $PythonExe -m pip install --no-warn-script-location --upgrade pip setuptools wheel
Write-OK ""

& $PythonExe -m pip install --no-warn-script-location hatchling hatch-vcs
Write-OK ""

$ReqFile = Join-Path $SCRIPTS_DIR "requirements-lite.txt"
if (Test-Path $ReqFile) {
    Write-Info "Built requirements-lite.txt ..."
    & $PythonExe -m pip install --no-warn-script-location -r $ReqFile
} else {
    Write-Warn "file scripts\requirements-lite.txt not found."
    Write-Info "Install core packages manually..."
    & $PythonExe -m pip install --no-warn-script-location openai tiktoken fastapi uvicorn pydantic python-dotenv tqdm click numpy
}
Write-OK ""

Write-Info "Build nanobot core..."
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
    Copy-Item -Path $ConfigFile -Destination "$ConfigFile.prebak" -Force
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
        "# Protection .env by running edit_env.bat"
        "# ========================================="
        ""
        "NANOBOT_CUSTOM_API_KEY=sk-your-api-key-here"
        "NANOBOT_CUSTOM_API_BASE=https://your-api-endpoint/v1"
        ""
        "NVIDIA_API_KEY=null"
    ) -Encoding Ascii
    Write-OK ".env created."
    Write-Warn "!!! Edit first: data\.env - fill in API key !!!"
} else {
    Write-OK ".env already exists."
}
Write-OK ""
