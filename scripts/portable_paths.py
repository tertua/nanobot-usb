"""Patch nanobot source paths to never leak to ~/.nanobot/ or %USERPROFILE%.

Target priority:
  1. app/nanobot/config/ (source before pip install -- fresh setup flow)
  2. site-packages/nanobot/config/ (already installed -- existing setup)
"""
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent

# -- Find target directory ------------------------------------------
candidates = [
    ROOT / "app" / "nanobot" / "config",
    ROOT / "bin" / "Lib" / "site-packages" / "nanobot" / "config",
]

target = None
for p in candidates:
    if (p / "paths.py").exists() and (p / "loader.py").exists() and (p / "schema.py").exists():
        target = p
        break

if target is None:
    print("[ERROR] Cannot find nanobot/config/ directory.")
    for p in candidates:
        print(f"    {p}")
    sys.exit(1)

print(f"Target: {target}")

# -- Helper ---------------------------------------------------------
def patch_file(filename: str, patcher) -> int:
    """Read file, call patcher(content), write back if changed."""
    path = target / filename
    content = path.read_text("utf-8")
    new_content, changed = patcher(content)
    if changed:
        path.write_text(new_content, "utf-8")
    return changed

def simple_replace(content: str, old: str, new: str, label: str) -> tuple[str, int]:
    """Replace old text with new; report status."""
    if old in content:
        content = content.replace(old, new)
        print(f"  [OK] {label}")
        return content, 1
    if new in content:
        print(f"  [SKIP] {label}: already patched")
        return content, 0
    print(f"  [WARN] {label}: pattern not found -- version mismatch?")
    return content, 0

# -- 1. paths.py ----------------------------------------------------
def patch_paths(content: str) -> tuple[str, int]:
    c, changed = content, 0
    patterns = [
        ('Path.home() / ".nanobot" / "workspace"',
         '(get_config_path().parent / "workspace")',
         "paths.py get_workspace_path fallback"),
        ('default = Path.home() / ".nanobot" / "workspace"',
         'default = get_config_path().parent / "workspace"',
         "paths.py is_default_workspace fallback"),
        ('Path.home() / ".nanobot" / "history" / "cli_history"',
         'get_data_dir() / ".cli_history"',
         "paths.py get_cli_history_path"),
        ('Path.home() / ".nanobot" / "bridge"',
         'get_data_dir() / "bridge"',
         "paths.py get_bridge_install_dir"),
        ('Path.home() / ".nanobot" / "sessions"',
         'get_data_dir() / "sessions"',
         "paths.py get_legacy_sessions_dir"),
    ]
    for old, new, label in patterns:
        c, ch = simple_replace(c, old, new, label)
        changed += ch
    return c, changed

paths_changed = patch_file("paths.py", patch_paths)

# -- 2. loader.py ---------------------------------------------------
def patch_loader(content: str) -> tuple[str, int]:
    old = """def get_config_path() -> Path:
    \"\"\"Get the configuration file path.\"\"\"
    if _current_config_path:
        return _current_config_path
    return Path.home() / \".nanobot\" / \"config.json\""""

    new = """def get_config_path() -> Path:
    \"\"\"Get the configuration file path.\"\"\"
    if _current_config_path:
        return _current_config_path
    # Portable: honor NANOBOT_HOME before falling back to ~/.nanobot
    home = os.environ.get(\"NANOBOT_HOME\")
    if home:
        return Path(home) / \"config.json\"
    return Path.home() / \".nanobot\" / \"config.json\""""

    return simple_replace(content, old, new, "loader.py get_config_path NANOBOT_HOME")

loader_changed = patch_file("loader.py", patch_loader)

# -- 3. schema.py ---------------------------------------------------
def patch_schema(content: str) -> tuple[str, int]:
    return simple_replace(
        content,
        '    workspace: str = "~/.nanobot/workspace"',
        '    workspace: str = "data/workspace"',
        "schema.py default workspace",
    )

schema_changed = patch_file("schema.py", patch_schema)


# -- 4. commands.py -------------------------------------------------
# commands.py is at nanobot/cli/commands.py, not nanobot/config/.
COMMANDS_TARGETS = [
    ROOT / "app" / "nanobot" / "cli" / "commands.py",
    ROOT / "bin" / "Lib" / "site-packages" / "nanobot" / "cli" / "commands.py",
]

commands_target = None
for p in COMMANDS_TARGETS:
    if p.exists():
        commands_target = p
        break

if commands_target is None:
    print("[ERROR] Cannot find nanobot/cli/commands.py.")
else:
    print(f"Commands file: {commands_target}")

def patch_serve(content):
    """4a. serve(): file logging; --verbose controls stderr."""
    old = (
        '    if verbose:\n'
        '        logger.enable("nanobot")\n'
        '    else:\n'
        '        logger.disable("nanobot")\n'
        '\n'
        '    runtime_config = _load_runtime_config(config, workspace)'
    )
    new = (
        '    runtime_config = _load_runtime_config(config, workspace)\n'
        '\n'
        '    # Redirect loguru from stderr to file, terminal only if verbose.\n'
        '    _log_dir = (runtime_config.workspace_path.parent / "logs").resolve()\n'
        '    _log_dir.mkdir(parents=True, exist_ok=True)\n'
        '    logger.remove(_log_handler_id)\n'
        '    if verbose:\n'
        '        logger.add(\n'
        '            sys.stderr,\n'
        '            format=(\n'
        '                "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "\n'
        '                "<level>{level: <5}</level> | "\n'
        '                "<cyan>{extra[channel]}</cyan> | "\n'
        '                "<level>{message}</level>"\n'
        '            ),\n'
        '            level="DEBUG",\n'
        '            colorize=None,\n'
        '            filter=lambda record: record["extra"].setdefault("channel", "-") or True,\n'
        '        )\n'
        '    logger.add(\n'
        '        _log_dir / "nanobot_{time:YYYY-MM-DD}.log",\n'
        '        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <5} | {extra[channel]} | {message}",\n'
        '        level="INFO",\n'
        '        rotation="1 day",\n'
        '        retention="14 days",\n'
        '        filter=lambda record: record["extra"].setdefault("channel", "-") or True,\n'
        '    )'
    )
    return simple_replace(content, old, new, "4a. serve() file logging")

def patch_gateway(content):
    """4b. gateway(): file logging; --verbose controls stderr."""
    old = (
        '    if verbose:\n'
        '        logger.remove(_log_handler_id)\n'
        '        logger.add(\n'
        '            sys.stderr,\n'
        '            format=(\n'
        '                "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "\n'
        '                "<level>{level: <5}</level> | "\n'
        '                "<cyan>{extra[channel]}</cyan> | "\n'
        '                "<level>{message}</level>"\n'
        '            ),\n'
        '            level="DEBUG",\n'
        '            colorize=None,\n'
        '            filter=lambda record: record["extra"].setdefault("channel", "-") or True,\n'
        '        )\n'
        '    cfg = _load_runtime_config(config, workspace)'
    )
    new = (
        '    cfg = _load_runtime_config(config, workspace)\n'
        '\n'
        '    # Redirect loguru from stderr to file, terminal only if verbose.\n'
        '    _log_dir = (cfg.workspace_path.parent / "logs").resolve()\n'
        '    _log_dir.mkdir(parents=True, exist_ok=True)\n'
        '    logger.remove(_log_handler_id)\n'
        '    if verbose:\n'
        '        logger.add(\n'
        '            sys.stderr,\n'
        '            format=(\n'
        '                "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "\n'
        '                "<level>{level: <5}</level> | "\n'
        '                "<cyan>{extra[channel]}</cyan> | "\n'
        '                "<level>{message}</level>"\n'
        '            ),\n'
        '            level="DEBUG",\n'
        '            colorize=None,\n'
        '            filter=lambda record: record["extra"].setdefault("channel", "-") or True,\n'
        '        )\n'
        '    logger.add(\n'
        '        _log_dir / "nanobot_{time:YYYY-MM-DD}.log",\n'
        '        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <5} | {extra[channel]} | {message}",\n'
        '        level="WARNING",\n'
        '        rotation="1 day",\n'
        '        retention="14 days",\n'
        '        filter=lambda record: record["extra"].setdefault("channel", "-") or True,\n'
        '    )'
    )
    return simple_replace(content, old, new, "4b. gateway() file logging")

def patch_agent(content):
    """4c. agent(): file logging level adaptive to --logs flag."""
    old = (
        '\n    if logs:\n'
        '        logger.enable("nanobot")\n'
        '    else:\n'
        '        logger.disable("nanobot")'
    )
    new = (
        '\n'
        '    # Redirect loguru from stderr to file, just WARNING+ so that the conversation does not join.\n'
        '    _log_dir = (config.workspace_path.parent / "logs").resolve()\n'
        '    _log_dir.mkdir(parents=True, exist_ok=True)\n'
        '    try:\n'
        '        logger.remove(_log_handler_id)\n'
        '    except ValueError:\n'
        '        pass\n'
        '    logger.add(\n'
        '        _log_dir / "nanobot_{time:YYYY-MM-DD}.log",\n'
        '        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <5} | {extra[channel]} | {message}",\n'
        '        level="WARNING",\n'
        '        rotation="1 day",\n'
        '        retention="14 days",\n'
        '        filter=lambda record: record["extra"].setdefault("channel", "-") or True,\n'
        '    )'
    )
    return simple_replace(content, old, new, "4c. agent() file logging")

def patch_multiline(content):
    """4d. _init_prompt_session(): set multiline=True untuk multi-baris input."""
    old = '        multiline=False,  # Enter submits (single line mode)'
    new = '        multiline=True,  # Enter -> newline, Escape+Enter -> submit'
    return simple_replace(content, old, new, "4d. _init_prompt_session() multiline=True")

if commands_target:
    content = commands_target.read_text("utf-8")
    commands_changed = 0
    content, ch = patch_serve(content)
    commands_changed += ch
    content, ch = patch_gateway(content)
    commands_changed += ch
    content, ch = patch_agent(content)
    commands_changed += ch
    content, ch = patch_multiline(content)
    commands_changed += ch
    if commands_changed:
        commands_target.write_text(content, "utf-8")
        print(f"  -> {commands_changed} patch(es) applied to commands.py")
    else:
        print("  -> No changes to commands.py")
else:
    commands_changed = 0

# -- Summary --------------------------------------------------------
total = paths_changed + loader_changed + schema_changed + commands_changed
print(f"\nDone. {total} file(s) patched.")
if total:
    print("Please restart nanobot to apply changes.")
