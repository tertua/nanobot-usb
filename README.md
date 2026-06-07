![nanobot README cover](https://rawcdn.githack.com/HKUDS/nanobot/851150fcd8f72461cea398d56d20f18766232aa3/images/readme-cover.png)

# Nanobot Portable for Windows

> **Info:** Latest portable version -- Python Embedded, MinGit, and Node.js are all bundled in `bin/`. The `app/` folder is temporary (cleaned up after setup). 
> See [CHANGELOG.md](CHANGELOG.md) for full history.

Portable version of **nanobot-ai** that runs without installation on host.
Just extract, setup, and go!

## Requirements

- **Windows 10/11** (64-bit)
- **PowerShell 7+** (recommended for .ps1 scripts)
- **Internet connection** (for setup and API calls)
- **~500MB** disk space

## Quick Start

### Step 1: Setup
```powershell
# PowerShell 7 (recommended):
.\nanobot-setup.ps1

# Or legacy batch:
setup.bat
```
The script will automatically:
- Download Python 3.14 Embedded -> `bin/`
- Install pip
- Clone the Nanobot repository -> `app/`
- Install all dependencies -> `bin/Lib/site-packages/`
- Download MinGit -> `bin/git/`
- Download Node.js portable -> `bin/nodejs/`
- Apply portable paths patch
- Generate default configuration (data/config.json)
- Clean up staging folder (`app/`)

### Step 2: Configure API Key

**Option A -- Safe editor (automatic encryption):**
```powershell
edit_env.bat              # Batch version
```
Opens Notepad with `data\.env` contents. Add your API key, save, close Notepad --
the file is automatically encrypted to `data\.env.encrypted` (AES-256-GCM).

**Option B -- Manual (no encryption):**
```
Edit file: data\.env
```
Replace `sk-your-api-key-here` with your OpenAI Compatible API key.

### Step 3: Run
```powershell
.\nanobot-gateway.ps1    -> Gateway (WebSocket + WebUI)
.\nanobot-agent.ps1      -> CLI Chat Mode
```

Gateway will display the browser address (default: http://127.0.0.1:8765, see config.json -> channels.websocket.port)

## Directory Structure

```
nanobot-usb/
+-- nanobot-setup.ps1               <- Initial setup (PowerShell 7)
+-- nanobot-gateway.ps1             <- Start Gateway and WebSocket
+-- nanobot-agent.ps1               <- Start Chat CLI mode
+-- setup.bat                       <- Legacy batch setup
+-- bin/
|   +-- python.exe                  <- Python Embedded runtime
|   +-- Lib/site-packages/          <- Installed Nanobot runtime
|   +-- git/                        <- Portable MinGit
|   +-- nodejs/                     <- Portable Node.js
+-- data/
|   +-- home/                       <- Portable HOME for Git (contains .ssh/)
|   +-- workspace/                  <- Agent workspace and skills
|   +-- config.json                 <- Main configuration
|   +-- .env                        <- Plaintext (temporary, auto-cleaned)
|   +-- .env.encrypted              <- AES-256-GCM encrypted
|   +-- .env_key                    <- Optional passphrase cache
+-- tmp/                            <- Portable temporary files and npm cache
+-- scripts/
|   +-- download.ps1                <- Download utilities
|   +-- extract.ps1                 <- Extract archives (with VBS fallback)
|   +-- env_crypt.py                <- AES-256-GCM + scrypt encrypt/decrypt
|   +-- edit_env.ps1                <- Safe .env editor with encryption
|   +-- healthcheck.py              <- Post-setup health verification
|   +-- portable_paths.py           <- Apply portable paths patch
|   +-- post_config.py              <- Initial config generation
|   +-- resolve_workspace.py        <- Workspace resolver
|   +-- write_lockhead.py           <- System metadata writer
|   +-- unzip.vbs                   <- VBS fallback for extraction
|   +-- requirements-api-only.txt   <- Minimal API dependencies
```

## Encryption .env

API keys are securely stored using **AES-256-GCM** with **scrypt key derivation** (OWASP 2023).

### Workflow

```
edit_env.bat
  |
  +--> Decrypt .env.encrypted -> .env (passphrase prompted)
  +--> Open Notepad for editing
  +--> Encrypt .env -> .env.encrypted, delete .env

start_gate.bat / start_chat.bat
  |
  +--> Detect .env.encrypted
  +--> Load passphrase (interactive or from data\.env_key)
  +--> Decrypt -> set environment variable (never written to disk)
  +--> Launch Nanobot
```

### Related Files

| File | Function |
|------|----------|
| `scripts/env_crypt.py` | Encrypt/decrypt AES-256-GCM + scrypt |
| `edit_env.bat` | Safe editor: open -> edit -> auto-encrypt |
| `data/.env.encrypted` | Encrypted file (salt + nonce + ciphertext + tag) |
| `data/.env_key` | Optional: passphrase cache for non-interactive mode |
| `data/.env` | Plaintext file (only exists during edit, immediately deleted) |

> **Security:** Without `data/.env_key`, passphrase is prompted on every startup.
> Delete `.env_key` to return to interactive mode. Passphrase stays in your head, not on disk.

## Troubleshooting

### Python not found
Re-run `setup.bat`

### Dependencies failed to install
```
bin\python.exe -m pip install -r app\requirements.txt
```

### Port already in use
Edit `data/config.json`:
- `api.port` (default 8900) -> HTTP API
- `channels.websocket.port` (default 8765) -> WebSocket/WebUI

### Check readiness
```
bin\python.exe scripts\healthcheck.py
```

## Using Other Providers

### OpenAI-Compatible API
```env
CUSTOM_API_BASE=https://your-custom-url/v1
CUSTOM_API_KEY=sk-your-api-key
```

## Update to Latest Version

```powershell
# Re-run setup to update:
.\nanobot-setup.ps1
```

The setup script uses a hybrid update strategy:

- **FAST mode** -- if `app/.git` exists, update via `git fetch` + `git reset --hard origin/main`
- **FRESH mode** -- if `app/` does not exist, check the installed Nanobot package and clone the latest source from GitHub only when needed

Runtime is built-in `bin/Lib/site-packages/`. The `app/` folder is only a temporary staging clone and safely removed after setup/update completed.

## Uninstall

Backup `data` folder and then delete the `nanobot-usb/` folder -- nothing is installed on the system.

---

## Flow Diagram

```
nanobot-setup.ps1
   |
   +--> Download Python 3.14 Embedded -> bin/
   +--> Install pip
   +--> Download MinGit -> bin/git/
   +--> Download Node.js -> bin/nodejs/
   +--> Clone github.com/HKUDS/nanobot -> app/
   +--> pip install -> bin/Lib/site-packages/
   +--> Apply portable patches
   +--> Generate config (data/config.json)
   +--> Write .lockhead metadata
   +--> Clean up app/ (staging only)

nanobot-gateway.ps1
   |
   +--> Set $env:HOME to data/home (portable Git)
   +--> WebUI: http://127.0.0.1:8765 (config -> channels.websocket.port)

nanobot-agent.ps1
   |
   +--> Set $env:HOME to data/home (portable Git)
   +--> Load .env (or .env.encrypted)
   +--> Resolve workspace path
   +--> $ python -m nanobot agent --config data/config.json
```

This package is **fully portable** -- it can run from a USB stick, requires no system-wide Python installation, and can be removed by simply deleting the folder.
