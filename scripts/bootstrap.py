#!/usr/bin/env python3
"""
Nanobot Portable - Bootstrap Utility
Utilitas untuk setup manual dan troubleshooting.
"""

import os
import sys
import subprocess
import urllib.request
import zipfile
import shutil
from pathlib import Path


def run_cmd(cmd, cwd=None):
    """Jalankan command dan return output."""
    result = subprocess.run(
        cmd, shell=True, capture_output=True, text=True, cwd=cwd
    )
    return result.returncode, result.stdout, result.stderr


def download_file(url, dest):
    """Download file dari URL."""
    print(f"  Downloading: {url}")
    urllib.request.urlretrieve(url, dest)
    print(f"  Saved to: {dest}")


def install_pip(python_exe):
    """Install pip ke embedded Python."""
    get_pip = Path(__file__).parent.parent / "tmp" / "get-pip.py"
    get_pip.parent.mkdir(parents=True, exist_ok=True)

    download_file("https://bootstrap.pypa.io/get-pip.py", str(get_pip))
    subprocess.run([python_exe, str(get_pip)], check=True)
    print("  pip installed successfully")


def patch_pth(python_dir):
    """Patch ._pth file untuk mengaktifkan site-packages."""
    pth_files = list(Path(python_dir).glob("*._pth"))
    if not pth_files:
        print("  [WARN] No ._pth file found")
        return

    for pth_file in pth_files:
        lines = [
            f"{pth_file.stem.replace('_', '.')}.zip\n",
            ".\n",
            "Lib\n",
            "Lib\\site-packages\n",
            "..\\app\n",
        ]
        pth_file.write_text("".join(lines), encoding="utf-8")
        print(f"  Patched: {pth_file.name}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python bootstrap.py [install_pip|patch_pth|install_deps]")
        return

    command = sys.argv[1]
    root = Path(__file__).parent.parent

    if command == "install_pip":
        python_exe = root / "bin" / "python.exe"
        install_pip(str(python_exe))

    elif command == "patch_pth":
        python_dir = root / "bin"
        patch_pth(str(python_dir))

    elif command == "install_deps":
        python_exe = str(root / "bin" / "python.exe")
        app_dir = root / "app"
        req_file = app_dir / "requirements.txt"

        if req_file.exists():
            subprocess.run(
                [python_exe, "-m", "pip", "install", "--no-warn-script-location",
                 "-r", str(req_file)],
                check=True,
            )
        else:
            print("  No requirements.txt found")

    else:
        print(f"  Unknown command: {command}")


if __name__ == "__main__":
    main()