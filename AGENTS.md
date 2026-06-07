# AGENTS.md — nanobot-usb

Windows-portable runtime for [HKUDS/nanobot](https://github.com/HKUDS/nanobot). "Lite" edition runs on the built-in Windows PowerShell 5.1+; no PowerShell 7 required. Everything is meant to live on a USB drive and touch zero host state.

## Environment

- Windows 10 1809+ / Windows 11, 64-bit (x64 or ARM64). 32-bit is partially supported.
- Built-in `powershell.exe` 5.1+ (already present on supported Windows).
- No Python/Node/Git on the host — `nanobot-setup.ps1` fetches portable versions into `bin/`.
- No package manifest, no CI, no test runner, no linter, no type checker. There is nothing to `npm test` or `ruff check`.

## Layout

```
nanobot-setup.ps1     # one-shot installer (downloads Python/Git/Node, clones/patches nanobot, writes config + lockhead)
nanobot-agent.ps1     # launches `python -m nanobot agent`
nanobot-gateway.ps1   # launches `python -m nanobot gateway` (HTTP :8900, WS :8765)
setup.bat             # batch wrapper for setup (also enforces Win10+ and PS5.1+)
start-chat.bat        # batch wrapper for nanobot-agent.ps1
start-gateway.bat     # batch wrapper for nanobot-gateway.ps1
edit_env.bat          # decrypt .env → notepad → re-encrypt
scripts/
  init_portable.ps1   # dot-sourced by all root .ps1; redirects USERPROFILE/HOME/TEMP to portable paths
  setup/              # install_python, install_git, install_nodejs, install_source, install_deps, download, extract, setup_helpers
  env_crypt.py        # AES-256-GCM + scrypt .env encryption (encrypt/load/decrypt subcommands)
  portable_paths.py   # patches upstream nanobot source to never use ~/.nanobot
  post_config.py      # post-processes `nanobot onboard` config for portable use
  resolve_workspace.py, write_lockhead.py, healthcheck.py
  requirements-lite.txt
  unzip.vbs           # last-resort zip extraction fallback
data/                 # gitignored runtime data (config.json, .env* , .lockhead, knowledge/, logs/, workspace/)
bin/                  # gitignored; portable Python, MinGit, Node.js
app/                  # gitignored; cloned/extracted nanobot source
tmp/                  # gitignored; download/extract scratch space
```

## Commands

All commands run from the repo root on Windows. The `.bat` files are the user-facing entrypoints and handle error pauses.

- One-time install: `setup.bat`  (or `powershell -NoProfile -ExecutionPolicy Bypass -File nanobot-setup.ps1`)
- Set/edit the API key: `edit_env.bat`
- CLI chat: `start-chat.bat`  (or `nanobot-agent.ps1`)
- Web gateway: `start-gateway.bat`  (or `nanobot-gateway.ps1`, then open `http://127.0.0.1:8765`)
- Re-verify after install: `bin\python.exe scripts\healthcheck.py`
- Check for a newer portable release: `check_update.bat`  (records a baseline SHA in `data\.wrapper_sha` on first run; not auto-invoked)
- To re-run setup from scratch, delete `data\.lockhead` and run `setup.bat` again.

Setup log: `setup_log.txt`. Runtime logs land in `data\logs\nanobot_YYYY-MM-DD.log`.

## Editing rules that will surprise you

- **Whitelist `.gitignore`.** The root `.gitignore` starts with `/*` and only re-allows specific paths. Any new top-level file or directory must be added to `.gitignore` with a `!/path` rule, otherwise it will silently not be tracked. Confirmed tracked set: `setup.bat`, `start-chat.bat`, `start-gateway.bat`, `edit_env.bat`, `check_update.bat`, `build-webui.bat`, `sync-webui.bat`, the three `nanobot-*.ps1` files, `scripts/` tree (recursive), `README.md`, `SECURITY.md`, `AGENTS.md`, `LICENSE`, `.github/`, `.gitattributes`, `.gitignore`.
- **Line endings are enforced.** `.gitattributes` pins `*.ps1`/`*.bat`/`*.vbs`/etc. to CRLF and `*.py`/`*.md`/`*.json`/etc. to LF. Don't re-save `.ps1` files as LF — PowerShell 5.1 chokes on them.
- **Hard-coded upstream versions live in `nanobot-setup.ps1`** (`$PyVer`, `$GitVer`, `$NodeVer`, `$ArchPython`, `$ArchNode`, `$ArchMinGit`, `$MinGwDir`). Bump them there; nothing reads a manifest.
- **`check_update.bat` is standalone.** It calls the GitHub API for `tertua/nanobot-usb` `lite` and compares against `data\.wrapper_sha` (gitignored). First run records a baseline; subsequent runs notify (one yellow line) or say OK. It does **not** auto-update nanobot itself — re-running `setup.bat` from a fresh release is the update path. Delete `data\.wrapper_sha` to reset the baseline.
- **Patches target upstream source.** `scripts/portable_paths.py` rewrites `paths.py`, `loader.py`, `schema.py`, and `cli/commands.py` in the cloned/zip-extracted nanobot tree so nothing leaks to `~/.nanobot` or `%USERPROFILE%`. If upstream nanobot refactors these files, the patcher logs `[WARN] pattern not found` for each miss and continues — re-check after every upstream bump.
- **`commands.py` log-handler patches use 3 small regex subs** (A: `logger.remove(_log_handler_id)` → `logger.remove()`; B: file level INFO/WARNING → DEBUG; C: conditional `if X: logger.add(sys.stderr, level="DEBUG",...)` → unconditional ternary) shared via `_patch_log_handlers` (idempotent, no-op if not matched) + one upstream full-block fallback per function. Sentinel check (post-`_log_dir.mkdir` log section contains `logger.remove()` + `"DEBUG" if X else "INFO"` + `level="DEBUG", rotation="1 day"`) makes the patcher re-runnable. Post-condition WARN means "incomplete after subs — delete data\.lockhead and re-run setup.bat".
- **`.env` is encrypted at rest.** Plaintext is written to `data\.env` only by `edit_env.bat` (decrypt→notepad→re-encrypt). Launchers (`nanobot-agent.ps1` / `nanobot-gateway.ps1`) call `Load-EnvEncrypted` from `scripts\init_portable.ps1:48-89`, which runs `env_crypt.py load` to write `data\.env.tmp`, parses it into process env vars, and `Remove-Item`s the temp file. Never write a real key into a tracked file or into `data\.env` outside the edit_env flow.
- **`data\.env_key` is an optional stored passphrase** so the launcher can run non-interactively. Delete it to force an interactive passphrase prompt every run (per `SECURITY.md` recommendation).
- **`data\.env_key` is a convenience, not a security feature.** It stores the passphrase on disk so the launcher runs non-interactive. The LLM in your active nanobot already has the API key via process env vars regardless (`nanobot-agent.ps1` decrypts then sets env at startup). Encryption's purpose is to keep plaintext out of the LLM's *context window* (no file read, no tool output echo, no conversation log leak) — preserved either way.
- **Real risk of `.env_key`**: physical theft of the USB becomes instant-decrypt instead of needing scrypt brute-force. Acceptable for scheduled tasks, screen-share, or demos where the USB is always with you. For unattended USBs, prefer interactive passphrase entry (`delete data\.env_key`).
- **By default, Lite sets `tools.exec.restrictToWorkspace=true`** (see `post_config.py:138`; top-level `tools.restrictToWorkspace` at `:142`), so the LLM cannot read `data\.env_key` even with file-read tools enabled — it lives outside `data\workspace\`.
- **`data\.lockhead` is the setup-done sentinel.** `nanobot-setup.ps1` short-circuits if it exists. It is an INI file with `[system]` and `[software]` sections written by `write_lockhead.py` (hostname, OS build, device, drive, terminal, date, plus detected versions).
- **`NANOBOT_HOME` env var** is the portable override that `nanobot.config.loader` consults before falling back to `~/.nanobot/config.json`. It is set in `scripts/init_portable.ps1` to `data/` — any new launcher that dot-sources that file inherits the redirect.
- **New launchers should dot-source `scripts/init_portable.ps1`** as their second step (after defining `$ROOT`). It does both jobs: redirects `USERPROFILE`/`HOME`/`TEMP` to portable paths, and exports `Load-EnvEncrypted` to handle the `data\.env.encrypted` → process env vars flow. Don't reimplement either piece — copy the existing launcher pattern.
- **Nanobot is invoked as a Python module**, not via a CLI binary: `& $PY -m nanobot agent` / `& $PY -m nanobot gateway`. The `agent` and `gateway` subcommands are what the patcher expects to find in `cli/commands.py`.
- **`tools.exec.pathAppend` in `data/config.json` is auto-set** by `post_config.py` to `bin`, `scripts`, `bin/git/cmd`, `bin/nodejs` (insertion order). Don't hand-edit it after `setup.bat` — re-run `post_config.py` instead.
- **Default ports**: HTTP 8900, WS 8765 (read from `config.json` in `nanobot-gateway.ps1`; falls back to those values). `start-gateway.bat` will prompt to kill whatever is bound to the WS port.

## Optional: WebUI drop zone

For cross-machine builds (build on a dev box, then copy to USB): drop the webui `dist/*` into `data\webui\`, then `sync-webui.bat` to install. Idempotent (mtime check) — re-run after every `setup.bat` since Lite's `pip install --no-deps` wipes the installed `dist\`. Same-machine builds should use `build-webui.bat` (one-shot build + sync).

Detect: `bin\Lib\site-packages\nanobot\web\dist\index.html` must exist after sync; upstream checks `is_dir()` on that path via `_default_webui_dist()` in `nanobot/channels/manager.py`.

## Optional: WebUI auto-build

Manual trigger via `build-webui.bat` — not part of `setup.bat`. Use this if you want a one-shot build with auto-sync.

The script (`scripts/install_webui.ps1`):

1. Checks for `app\webui\package.json` (full source clone required; ZIP install does not include webui).
2. Resolves `npm` from `bin/nodejs\npm.cmd` first (Lite's standard location after `setup.bat`), falls back to system PATH.
3. Runs `npm install` then `npm run build` in `app\webui\`.
4. Direct-copies the build output (`app\nanobot\web\dist\*`) into `bin\Lib\site-packages\nanobot\web\dist\`.

**Why npm only, not bun**: bun is not used here. Lite redirects `HOME`/`USERPROFILE` to the USB via `init_portable.ps1`, which makes bun's HOME-relative package store (`~/.bun/install/cache/`) land on the USB filesystem. On exFAT/FAT32 the `MoveFileEx` writes fail with `EINVAL: Invalid argument`, and bun exits 0 leaving `node_modules` incomplete. There is no bun flag/env that disables the package-store cache — only `--no-cache`, which skips the manifest cache (binary `*.npm` registry metadata) and does not affect the package store. npm's flat `node_modules/` writes work on any filesystem, so npm is the only path that is truly portable.

If the build fails, the script exits 1 with a clear error. Setup was already completed; you can re-run `build-webui.bat` after fixing the issue.

## Skills auto-disabled by Lite

Lite always writes `agents.defaults.disabledSkills = ["summarize", "tmux"]` into `data/config.json` via `post_config.py:_LITE_DISABLED_SKILLS`. Reason: these two upstream skills depend on tooling that does not exist on a bare Windows host (`tmux` binary; yt-dlp / shell-pipeline summaries via PS5.1). The `requires.bins` check in `SkillsLoader._check_requirements` would already mark them `(unavailable)`, but they would still appear in the skills summary and waste context tokens. Disabling is cleaner.

- Schema: `nanobot/config/schema.py:AgentDefaults.disabled_skills` (upstream first-class field, plumbed to `SkillsLoader.list_skills`).
- User override preserved: if `data/config.json` already has `disabledSkills`, the list is merged (de-duped, user order first). Idempotent — re-running `setup.bat` produces no diff.
- To re-enable for testing: edit `data/config.json` directly, remove the entries. Note that `setup.bat` re-runs `post_config.py`, so re-add by hand if you re-onboard.

## Branches

- `lite` — this branch, the "built-in PS 5.1 only" edition (active development here).
- `master` / `main` — other variants referenced in `SECURITY.md` (full edition, etc.). Don't merge from them blindly; they target different toolchain assumptions.

## Things that look like bugs but aren't

- `nanobot-setup.ps1` lines 157–161: "Cleanup skipped — app/ preserved for inspection; tmp/ cleaned (download/extract cache, not needed after install)." `app/` is the cloned/extracted nanobot source and stays on disk for debugging. Don't re-enable the `$APP_DIR` `Remove-Item` line unless you want a wiped source tree; the `$TMP_DIR` remove is intentional.
- `nanobot-gateway.ps1` has a hard-coded 10-second countdown before launching. Bypass by invoking `nanobot-gateway.ps1` directly only if you really mean it; the `.bat` launcher doesn't skip it.
- The PS5.1+ banner in `setup.bat` line 91 and several other strings are mixed Indonesian/English. Don't "fix" the Indonesian strings.
