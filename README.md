# Nanobot Portable Lite

Portable nanobot-ai runtime for Windows. No system installation required.

**Lite** = uses built-in Windows PowerShell 5.1+. No PowerShell 7 needed.

## Requirements

- Windows 10/11 (64-bit)
- PowerShell 5.1+ (built-in)
- ~500MB disk space

## Files

```
nanobot-usb/
|-- nanobot-setup.ps1       # Setup orchestrator
|-- nanobot-agent.ps1       # CLI chat mode
|-- nanobot-gateway.ps1     # Gateway mode
|-- setup.bat               # Batch launcher for setup
|-- edit_env.bat            # .env editor launcher
|-- start-chat.bat          # Batch launcher for chat
|-- start-gateway.bat       # Batch launcher for gateway
|-- scripts/
|   |-- init_portable.ps1
|   |-- env_crypt.py
|   |-- healthcheck.py
|   |-- portable_paths.py
|   |-- post_config.py
|   |-- resolve_workspace.py
|   |-- write_lockhead.py
|   |-- unzip.vbs
|   |-- requirements-lite.txt
|   |-- setup/
|       |-- setup_helpers.ps1
|       |-- install_python.ps1
|       |-- install_git.ps1
|       |-- install_nodejs.ps1
|       |-- install_source.ps1
|       |-- install_deps.ps1
|       |-- download.ps1
|       |-- extract.ps1
```

## Quick Start

Run `nanobot-setup.ps1` once. Setup downloads and installs all dependencies into `bin/`.

Configure API key via `edit_env.bat`, then run `nanobot-agent.ps1` or `nanobot-gateway.ps1`.

## Uninstall

Delete the folder. Nothing is installed on the system.

---

Based on [nanobot-ai](https://github.com/HKUDS/nanobot). Fully portable from USB drive.
