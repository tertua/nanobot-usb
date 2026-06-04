# Changelog

All notable changes to the Nanobot Portable project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with date-based minor/patch releases.

---

## [2026-06-04] -- v1.0.2

### Added

- **Health check integration** -- `healthcheck.py` now runs automatically at end of `nanobot-setup.ps1` for post-setup verification
- **VBS extraction fallback** -- `unzip.vbs` integrated into `extract.ps1` as method 4 when PowerShell/NET methods fail

### Changed

- `healthcheck.py` -- rewritten with clearer checks: Python version, Nanobot module, config, .env, directories, lockhead
- `extract.ps1` -- added VBS fallback method for corporate environments with restricted PowerShell

### Removed

- `bootstrap.py` -- redundant with existing setup.ps1 logic (download pip, install deps)
- `launcher.py` -- unused Python launcher (PowerShell launchers already handle this)

---

## [2026-06-02] -- v0.2.1

### Added

- **Node.js portable** -- automatic download and extraction (v26.3.0+, dynamic architecture detection)
- **Git portable** -- MinGit bundled in `bin/git/` for fully offline-capable updates
- Hybrid update mode in `update.bat`:
  - **FAST mode** -- `git fetch` + `reset --hard` if `app/.git` exists
  - **FRESH mode** -- clone from GitHub if `app/` missing, with version check
- Version comparison logic in `update.bat` (local vs remote git hash)
- User prompts for "already up-to-date" and "reinstall anyway?" scenarios
- Installed Nanobot version display at end of update
- PATH isolation for Git and npm: `HOME=%ROOT%\data\home`, `NPM_CONFIG_CACHE`, `NPM_CONFIG_PREFIX`

### Changed

- **setup.bat** -- all portable tools now under unified `bin/` structure:
  - `bin/python/` -> Python Embedded
  - `bin/git/` -> MinGit portable
  - `bin/nodejs/` -> Node.js portable
- **setup.bat** -- fixed batch parser errors:
  - `echo.` -> `echo(` to prevent "`. was unexpected at this time.`"
  - Moved `set "PATH=...;!PATH!"` outside parentheses blocks
  - Escaped parentheses in echo messages: `echo ^(subfolder^)`
- **update.bat** -- no longer requires `app/.git` to exist (supports fresh installs)
- **update.bat** -- skips unnecessary git operations if user declines update
- Node.js extraction now uses `xcopy /E /I /Y` for reliable nested folder handling
- Git and Node.js are now injected into PATH for all batch scripts (`start_gate.bat`, `start_chat.bat`, `update.bat`)

### Fixed

- Batch syntax error: `. was unexpected at this time.` caused by `!PATH!` expansion inside `if (...)` blocks
- Node.js nested folder extraction (from `node-vXX.X.X-win-x64/` to `bin/nodejs/`)
- Portable path leakage to host system (`%APPDATA%`, `%USERPROFILE%`) -- now fully contained in USB root

### Removed

- Hard dependency on `app/.git` existing for `update.bat` to run

---

## [2026-06-01] -- v0.2.0

### Added

- AES-256-GCM .env encryption via `scripts/env_crypt.py` with scrypt key derivation (OWASP 2023)
- `edit_env.bat` -- safe editor that decrypts, opens Notepad, then re-encrypts automatically
- Non-interactive passphrase mode via `data/.env_key` file (for automated startup)
- `start_gw.bat` and `start_chat.bat` now detect `.env.encrypted` and decrypt on-the-fly
- Audit logging for encryption operations (`data/logs/encrypt.log`)

### Changed

- `.gitignore`: added `.env.encrypted`, `.env_key`, `.env.tmp` to sensitive files section
- **Security:** Migrated from Windows-only DPAPI to cross-platform AES-256-GCM + scrypt

---

## [2026-06-01] -- v0.2.0

### Added

- AES-256-GCM encrypted `.env` support for portable API key storage
- `scripts/env_crypt.py` -- encrypt, decrypt, and load environment variables
- `edit_env.bat` -- integrated editor with auto-encryption workflow
- `data/.env_key` support for passphrase caching (non-interactive mode)
- Audit logging for encryption in `data/logs/encrypt.log`

### Changed

- Migrated from Windows DPAPI to AES-256-GCM + scrypt (cross-platform, OWASP 2023)
- Batch files (`start_gw.bat`, `start_chat.bat`, `edit_env.bat`): added `.env.encrypted` detection
- `.gitignore`: added `.env.encrypted`, `.env_key`, `.env.tmp`

### Security

- API keys encrypted at rest -- plaintext `.env` only exists during editing
- Passphrase-derived key using PBKDF2-SHA256 (100,000 iterations) or scrypt
- No secrets written to stdout or logs

---

## [2026-05-31] -- v0.1.3

### Added

- `scripts/portable_paths.py` -- patch Nanobot source to use portable paths
- `scripts/resolve_workspace.py` -- workspace path resolver for portable setup
- `scripts/write_lockhead.py` -- system metadata writer for portable identity
- Log redirection: CLI agent mode logs only WARNING+ level to prevent conversation leakage

### Changed

- `scripts/post_config.py`: backup `config.json` to `config.json.bak` on first run
- `start_gw.bat` and `start_chat.bat`: fixed `"%PY%"` quoting error in backtick commands
- Logging: redirected from stderr to workspace parent `logs/` with rotation
- `NANOBOT_HOME` env var support as portable config path fallback
- Patched `paths.py`, `loader.py`, `schema.py`, `commands.py` for portable path containment

### Fixed

- Batch quoting error causing parser failure in `for /f usebackq` loops

---

## [2026-05-31] -- v0.1.2

### Added

- Git ignore rules for batch scripts, OS files, and editor artifacts
- Python-based `.env` encryption using `cryptography` library

### Changed

- Improved `.gitignore` with categorized sections

---

## [2026-05-31] -- v0.1.1

### Fixed

- Gateway script port detection and configuration
- Environment folder path resolution

### Changed

- Moved `.env` folder path to `data/` directory

---

## [2026-05-30] -- v0.1.0

### Added

- Initial release of Nanobot Portable for Windows
- `setup.bat` -- automated setup: downloads Python Embedded, clones Nanobot repo, installs dependencies
- `start_gw.bat` -- launch Nanobot Gateway (WebSocket + WebUI)
- `start_chat.bat` -- launch Nanobot CLI Agent mode
- `update.bat` -- pull latest changes and reinstall dependencies
- `scripts/download.ps1` -- PowerShell download utility
- `scripts/extract.ps1` -- archive extraction utility
- `scripts/unzip.vbs` -- VBS fallback for extraction
- `scripts/post_config.py` -- initial configuration generation
- `scripts/healthcheck.py` -- system readiness check
- `scripts/bootstrap.py` -- reusable Python bootstrap module
- `scripts/launcher.py` -- process launcher
- `tests/` -- test suite
- `data/config.json` -- auto-generated configuration
- `data/knowledge/` -- knowledge base directory
- `data/logs/` -- log directory
- GitHub Actions integration for release automation

### Features

- Fully portable -- runs from USB stick, no system-wide installation
- Self-contained Python Embedded (no preinstalled Python required)
- Reusable kill-backup-patch-reinstall update workflow
- Cross-platform proxy provider support (Ollama, LM Studio, Azure OpenAI)
- Dynamic port detection for process management

---

## Legend

- **Added** -- new features
- **Changed** -- changes in existing functionality
- **Deprecated** -- soon-to-be removed features
- **Removed** -- now removed features
- **Fixed** -- bug fixes
- **Security** -- vulnerability fixes
