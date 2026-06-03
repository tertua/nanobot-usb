![nanobot README cover](https://rawcdn.githack.com/HKUDS/nanobot/851150fcd8f72461cea398d56d20f18766232aa3/images/readme-cover.png)

# 🤖 Nanobot Portable for Windows

> **Info:** Latest portable version — Python Embedded, MinGit, and Node.js are all bundled in `bin/`. The `app/` folder is temporary (cleaned up after setup). 
> See [CHANGELOG.md](CHANGELOG.md) for full history.

Portable version of **nanobot-ai** that runs without installation on host.
Just extract, setup, and go!

## 📋 Requirements

- **Windows 10/11** (64-bit)
- **Internet connection** (for setup and API calls)
- **~500MB** disk space

## 🚀 Quick Start

### Step 1: Setup
```
Double-click: setup.bat
```
The script will automatically:
- Download Python 3.14 Embedded → `bin/`
- Install pip
- Clone the Nanobot repository → `app/`
- Install all dependencies → `bin/Lib/site-packages/`
- Download MinGit → `bin/git/`
- Download Node.js portable → `bin/nodejs/`
- Apply portable paths patch
- Generate default configuration (data/config.json)
- Clean up staging folder (`app/`)

### Step 2: Configure API Key

**Option A — Safe editor (automatic encryption):**
```
Double-click: edit_env.bat
```
Opens Notepad with `data\.env` contents. Add your API key, save, close Notepad —
the file is automatically encrypted to `data\.env.encrypted` (AES-256-GCM).

**Option B — Manual (no encryption):**
```
Edit file: data\.env
```
Replace `sk-your-api-key-here` with your OpenAI Compatible API key.

### Step 3: Run
```
Double-click: start_gate.bat    → Gateway (WebSocket + WebUI)
Double-click: start_chat.bat    → CLI Chat Mode
```

Gateway will display the browser address (default: http://127.0.0.1:8765, see config.json → channels.websocket.port)

## 📂 Directory Structure

```
nanobot-usb/
├── setup.bat                       ← Initial setup (run once)
├── start_gate.bat                  ← Start Gateway and WebSocket
├── start_chat.bat                  ← Start Chat CLI mode
├── edit_env.bat                    ← Edit .env with auto-encryption
├── update.bat                      ← Update to latest version
├── bin/
│   ├── python.exe                  ← Python Embedded runtime
│   ├── Lib/site-packages/          ← Installed Nanobot runtime
│   ├── git/                        ← Portable MinGit
│   └── nodejs/                     ← Portable Node.js
├── data/
│   ├── home/                       ← Portable HOME for Git
│   ├── knowledge/                  ← Knowledge base
│   ├── logs/                       ← Log files
│   ├── .env                        ← Plaintext (temporary, auto-cleaned)
│   ├── .env.encrypted              ← AES-256-GCM encrypted
│   └── .env_key                    ← Optional passphrase cache
├── tmp/                            ← Portable temporary files and npm cache
├── scripts/
│   ├── env_crypt.py                ← AES-256-GCM + scrypt encrypt/decrypt
│   ├── download.ps1                ← Download utilities
│   ├── extract.ps1                 ← Extract archives
│   ├── unzip.vbs                   ← VBS fallback for extraction
│   ├── post_config.py              ← Initial config generation
│   ├── portable_paths.py           ← Apply portable paths patch
│   ├── resolve_workspace.py        ← Workspace resolver
│   ├── write_lockhead.py           ← System metadata writer
│   └── requirements-api-only.txt
└── app/                            ← Temporary source staging (auto-cleaned after setup)
```

## 🔐 .env Encryption

API keys are securely stored using **AES-256-GCM** with **scrypt key derivation** (OWASP 2023).

### Workflow

```
edit_env.bat
  │
  ├─→ Decrypt .env.encrypted → .env (passphrase prompted)
  ├─→ Open Notepad for editing
  └─→ Encrypt .env → .env.encrypted, delete .env

start_gate.bat / start_chat.bat
  │
  ├─→ Detect .env.encrypted
  ├─→ Load passphrase (interactive or from data\.env_key)
  ├─→ Decrypt → set environment variable (never written to disk)
  └─→ Launch Nanobot
```

### Related Files

| File | Function |
|------|----------|
| `scripts/env_crypt.py` | Encrypt/decrypt AES-256-GCM + scrypt |
| `edit_env.bat` | Safe editor: open → edit → auto-encrypt |
| `data/.env.encrypted` | Encrypted file (salt + nonce + ciphertext + tag) |
| `data/.env_key` | Optional: passphrase cache for non-interactive mode |
| `data/.env` | Plaintext file (only exists during edit, immediately deleted) |

> **Security:** Without `data/.env_key`, passphrase is prompted on every startup.
> Delete `.env_key` to return to interactive mode. Passphrase stays in your head, not on disk.

## 🔧 Troubleshooting

### Python not found
Re-run `setup.bat`

### Dependencies failed to install
```
bin\python.exe -m pip install -r app\requirements.txt
```

### Port already in use
Edit `data/config.json`:
- `api.port` (default 8900) → HTTP API
- `channels.websocket.port` (default 8765) → WebSocket/WebUI

### Check readiness
```
bin\python.exe scripts\healthcheck.py
```

## 🌐 Using Other Providers

### Azure OpenAI
```env
OPENAI_API_TYPE=azure
OPENAI_API_BASE=https://your-resource.openai.azure.com/
OPENAI_API_KEY=your-azure-key
AZURE_API_VERSION=2023-12-01-preview
```

## 🔄 Update to Latest Version

```
Double-click: update.bat
```

`update.bat` uses a hybrid update strategy:

- **FAST mode** — if `app/.git` exists, update via `git fetch` + `git reset --hard origin/main`
- **FRESH mode** — if `app/` does not exist, check the installed Nanobot package and clone the latest source from GitHub only when needed

Runtime is built-in `bin/Lib/site-packages/`. The `app/` folder is only a temporary staging clone and safely removed after setup/update completed.

## 🧹 Uninstall

Simply delete the `nanobot-usb/` folder — nothing is installed on the system.

---

## Flow Diagram

```
setup.bat
   │
   ├─→ Download Python 3.14 Embedded → bin/
   ├─→ Install pip
   ├─→ Download MinGit → bin/git/
   ├─→ Download Node.js → bin/nodejs/
   ├─→ Clone github.com/HKUDS/nanobot → app/
   ├─→ pip install → bin/Lib/site-packages/
   ├─→ Apply portable patches
   ├─→ Generate config (data/config.json)
   ├─→ Write .lockhead metadata
   └─→ Clean up app/ (staging only)

start_gate.bat
   └─→ WebUI: http://127.0.0.1:8765 (config → channels.websocket.port)

start_chat.bat
   │
   ├─→ Load .env
   ├─→ Resolve workspace path
   └─→ $ python -m nanobot agent --config data/config.json
```

This package is **fully portable** — it can run from a USB stick, requires no system-wide Python installation, and can be removed by simply deleting the folder.
