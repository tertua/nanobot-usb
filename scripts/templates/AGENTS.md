# Agent Instructions

## Workspace Guidance

Use this file for project-specific preferences, recurring workflow conventions, and instructions you want the agent to remember for this workspace. Keep durable facts about the user in `USER.md`, personality/style guidance in `SOUL.md`, and long-term memory in `memory/MEMORY.md`.

## Platform Context

This nanobot instance runs on **Microsoft Windows** via **Nanowin** (nanobot Windows portable).

- **Shell**: PowerShell 5.1+ (`powershell.exe`). No bash, zsh, or Unix shell available.
- **Package managers**: No `sudo`, `apt`, `pacman`, `brew`, or `choco`. Do not suggest installing system packages.
- **Portable environment**: Everything lives on a USB drive in a single folder. The launcher sets `USERPROFILE`, `HOME`, `TEMP`, `LOCALAPPDATA`, and `APPDATA` to isolated directories inside `data/`. Touches zero host state outside the USB folder.
- **PATH**: Already configured by the launcher — includes `bin\`, `bin\git\cmd`, `bin\nodejs`, `bin\gh\bin`, `bin\Scripts`. Do not modify `tools.exec.pathAppend` in config.
- **`tools.exec.restrictToWorkspace`**: Default `true`. The user can change this via `config.json` or the WebUI — obey the active setting.
- **Git**: Portable MinGit available. Use for version control of memory files (SOUL.md, USER.md, MEMORY.md).
- **Known missing tools**: `tmux`, `screen`, `docker`, `systemctl`, `crontab`, `make`, `gcc`, `python3` (use `python` or `py`), `node` (use `node.exe`), and most Unix utilities.

## Scheduled Reminders

- Before scheduling reminders, check available skills and follow skill guidance first.
- Use the built-in `cron` tool to create/list/remove jobs (do not call `nanobot cron` via `exec`).
- Get USER_ID and CHANNEL from the current session (e.g., `8281248569` and `telegram` from `telegram:8281248569`).

**Do NOT just write reminders to MEMORY.md** — that won't trigger actual notifications.

## Heartbeat Tasks

`HEARTBEAT.md` is checked periodically by the protected heartbeat cron job that `nanobot gateway` registers when `gateway.heartbeat.enabled` is true. Do not create a duplicate heartbeat job unless the user has disabled the built-in one and explicitly wants a custom schedule.

- Use `apply_patch` for normal task-list updates, especially when adding, removing, or changing multiple lines.
- Use `edit_file` only for small exact replacements copied from the current `HEARTBEAT.md`.
- Use `write_file` for first creation or intentional full-file rewrites.

When the user asks for a recurring/periodic heartbeat task, update `HEARTBEAT.md` instead of creating a one-time reminder. Use the built-in `cron` tool for separate reminders or custom schedules that should not be part of the heartbeat task list.
