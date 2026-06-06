"""Write .lockhead with host metadata (INI-style, batch-friendly)."""

import os
import platform
import re
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path


def _run(cmd: list[str], timeout: int = 5) -> str:
    try:
        r = subprocess.run(cmd, capture_output=True, text=False, timeout=timeout)
        return r.stdout.decode("utf-8", errors="replace").strip()
    except Exception:
        return ""


def _wmic_value(cmd: list[str]) -> str:
    """Extract first non-empty value from wmic output (skip header)."""
    raw = _run(cmd, timeout=3)
    for line in raw.splitlines():
        line = line.strip()
        if line and not line.lower().startswith(("name", "model", "caption", "version")):
            return line
    return "?"


def _tz_name() -> str:
    try:
        import zoneinfo
        now = datetime.now()
        off = now.astimezone().utcoffset()
        if off is not None:
            sign = "+" if off >= timedelta(0) else "-"
            total = int(off.total_seconds())
            h, m = divmod(abs(total) // 60, 60)
            return f"UTC{sign}{h:02d}:{m:02d}"
    except Exception:
        pass
    return "UTC"


def detect_software(root: str) -> dict[str, str]:
    sw = {}
    py_dir = os.path.join(root, "bin")
    git_dir = os.path.join(root, "bin", "git", "cmd")
    scripts_dir = os.path.join(root, "scripts")
    nodejs_dir = os.path.join(root, "bin", "nodejs")

    # Python
    py_exe = os.path.join(py_dir, "python.exe")
    if os.path.isfile(py_exe):
        ver = _run([py_exe, "--version"])
        # "Python 3.11.9" -> "3.11.9"
        m = re.search(r"(\d+\.\d+\.\d+)", ver)
        if m:
            sw["python"] = m.group(1)

    # Nanobot
    ver = _run([py_exe, "-m", "nanobot", "--version"])
    if ver:
        m = re.search(r"v?(\d+\.\d+\.\d+(?:[a-z0-9.-]+)?)", ver)
        if m:
            sw["nanobot"] = m.group(1)

    # Git (portable first)
    git_exe = os.path.join(git_dir, "git.exe")
    if not os.path.isfile(git_exe):
        git_exe = "git.exe"
    ver = _run([git_exe, "--version"])
    if ver:
        m = re.search(r"(\d+\.\d+\.\d+)", ver)
        if m:
            sw["git"] = m.group(1)

    # Node.js (portable first)
    node_exe = os.path.join(nodejs_dir, "node.exe")
    if not os.path.isfile(node_exe):
        node_exe = "node.exe"
    ver = _run([node_exe, "--version"])
    if ver:
        m = re.search(r"v(\d+\.\d+\.\d+)", ver)
        if m:
            sw["nodejs"] = m.group(1)

    # Windows PowerShell (built-in)
    ps_exe = "powershell.exe"
    ver = _run([ps_exe, "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"])
    if ver:
        sw["powershell"] = ver.strip()

    return sw


def detect_system(root: str) -> dict[str, str]:
    info = {}

    # Hostname
    info["hostname"] = os.environ.get("COMPUTERNAME")
    if not info["hostname"]:
        info["hostname"] = _run(["hostname"])
    if not info["hostname"]:
        info["hostname"] = "?"

    # OS
    try:
        ver = sys.getwindowsversion()
        info["os"] = f"Windows {platform.release()} (build {ver.build})"
    except Exception:
        info["os"] = platform.platform()

    # Device / motherboard
    device = _wmic_value(["wmic", "csproduct", "get", "name"])
    if device == "?":
        device = _wmic_value(["wmic", "computersystem", "get", "model"])
    info["device"] = device

    # Drive
    drive = os.path.splitdrive(root)[0]
    info["drive"] = drive.upper() if drive else "?"

    # Terminal
    ppid_name = _run(["wmic", "process", "get", "name", "/format:csv"], timeout=3)
    if ppid_name:
        info["terminal"] = "?"
    parent = os.environ.get("PROMPT", "")
    if "pwsh" in os.environ.get("TERM_PROGRAM", "").lower():
        info["terminal"] = "pwsh"
    elif "powershell" in os.environ.get("PSModulePath", "").lower():
        info["terminal"] = "powershell"
    elif parent:
        info["terminal"] = "cmd"
    else:
        info["terminal"] = "?"

    # Date
    tz_str = _tz_name()
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    info["date_setup"] = f"{now} {tz_str}"

    return info


def write_lockhead(root: str) -> None:
    data_dir = Path(root) / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    lockhead = data_dir / ".lockhead"

    system = detect_system(root)
    software = detect_software(root)

    lines = []
    lines.append("[system]")
    for key in ("hostname", "os", "device", "drive", "terminal", "date_setup"):
        val = system.get(key, "?")
        lines.append(f"{key}={val}")

    lines.append("")
    lines.append("[software]")
    for key in ("python", "nanobot", "git", "nodejs", "powershell"):
        val = software.get(key, "")
        if val:
            lines.append(f"{key}={val}")

    lines.append("")
    lockhead.write_text("\n".join(lines), encoding="utf-8")
    print(f"  lockhead written  -> {lockhead}")
    print(f"  {system['hostname']} | {system['device']} | {system['os']}")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        root = sys.argv[1]
    else:
        root = str(Path(__file__).resolve().parent.parent)
    write_lockhead(root)
