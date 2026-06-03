#!/usr/bin/env python3
"""
Nanobot Portable - Smart Launcher
Mendeteksi entry point yang benar dan menjalankan Nanobot.
"""

import os
import sys
import subprocess
import argparse
import importlib
from pathlib import Path
from typing import Optional


def find_entry_point(app_dir: str) -> list:
    """Deteksi entry point yang tersedia."""
    candidates = []

    # Cek file-file kandidat
    entry_files = [
        "run.py", "app.py", "main.py", "server.py",
        "manage.py", "wsgi.py", "start.py",
    ]

    for f in entry_files:
        full_path = os.path.join(app_dir, f)
        if os.path.isfile(full_path):
            candidates.append(("file", full_path))

    # Cek module yang bisa dijalankan
    modules = ["nanobot", "nanobot.server", "nanobot.app", "nanobot.main"]
    for mod in modules:
        try:
            importlib.import_module(mod)
            candidates.append(("module", mod))
        except ImportError:
            pass

    return candidates


def detect_framework(app_dir: str) -> Optional[str]:
    """Deteksi web framework yang digunakan."""
    req_files = [
        os.path.join(app_dir, "requirements.txt"),
        os.path.join(app_dir, "pyproject.toml"),
    ]

    content = ""
    for f in req_files:
        if os.path.isfile(f):
            with open(f, "r", encoding="utf-8", errors="ignore") as fh:
                content += fh.read().lower()

    frameworks = {
        "fastapi": "fastapi",
        "flask": "flask",
        "gradio": "gradio",
        "streamlit": "streamlit",
        "uvicorn": "uvicorn",
        "gunicorn": "gunicorn",
        "django": "django",
    }

    for key, name in frameworks.items():
        if key in content:
            return name

    return None


def run_streamlit(entry: str, host: str, port: int):
    """Jalankan dengan Streamlit."""
    cmd = [
        sys.executable, "-m", "streamlit", "run",
        entry if entry.endswith(".py") else f"{entry}.__main__",
        "--server.address", host,
        "--server.port", str(port),
        "--server.headless", "true",
    ]
    subprocess.run(cmd)


def run_gradio(entry: str, host: str, port: int):
    """Jalankan dengan Gradio."""
    env = os.environ.copy()
    env["GRADIO_SERVER_NAME"] = host
    env["GRADIO_SERVER_PORT"] = str(port)

    if os.path.isfile(entry):
        cmd = [sys.executable, entry, "--host", host, "--port", str(port)]
    else:
        cmd = [sys.executable, "-m", entry, "--host", host, "--port", str(port)]

    subprocess.run(cmd, env=env)


def run_uvicorn(entry: str, host: str, port: int):
    """Jalankan dengan Uvicorn (FastAPI)."""
    # Coba deteksi app variable
    app_var = "app"
    if os.path.isfile(entry):
        # Baca file untuk cari app = FastAPI()
        with open(entry, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if "= FastAPI(" in line or "= FastAPI (" in line:
                    var_name = line.split("=")[0].strip()
                    if var_name.isidentifier():
                        app_var = var_name
                    break

        module_name = os.path.splitext(os.path.basename(entry))[0]
        uvicorn_target = f"{module_name}:{app_var}"
    else:
        uvicorn_target = f"{entry}:{app_var}"

    cmd = [
        sys.executable, "-m", "uvicorn",
        uvicorn_target,
        "--host", host,
        "--port", str(port),
    ]
    subprocess.run(cmd)


def run_default(entry: str, host: str, port: int):
    """Jalankan dengan cara default."""
    env = os.environ.copy()
    env["HOST"] = host
    env["PORT"] = str(port)

    if os.path.isfile(entry):
        cmd = [sys.executable, entry, "--host", host, "--port", str(port)]
    else:
        cmd = [sys.executable, "-m", entry, "--host", host, "--port", str(port)]

    result = subprocess.run(cmd, env=env)

    # Jika gagal dengan --host/--port, coba tanpa flag
    if result.returncode != 0:
        if os.path.isfile(entry):
            subprocess.run([sys.executable, entry], env=env)
        else:
            subprocess.run([sys.executable, "-m", entry], env=env)


def main():
    parser = argparse.ArgumentParser(description="Nanobot Portable Launcher")
    parser.add_argument("--host", default=os.environ.get("NANOBOT_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("NANOBOT_PORT", "8900")))
    parser.add_argument("--entry", default=None, help="Entry point override")
    args = parser.parse_args()

    root = Path(__file__).parent.parent
    app_dir = str(root / "app")

    print(f"  [Launcher] Host: {args.host}")
    print(f"  [Launcher] Port: {args.port}")

    # Tentukan entry point
    entry = args.entry
    if entry and entry != "nanobot":
        print(f"  [Launcher] Entry: {entry}")
    else:
        candidates = find_entry_point(app_dir)
        if candidates:
            entry_type, entry_val = candidates[0]
            entry = entry_val
            print(f"  [Launcher] Auto-detected entry ({entry_type}): {entry}")
        else:
            entry = "nanobot"
            print(f"  [Launcher] Using default module: {entry}")

    # Deteksi framework
    framework = detect_framework(app_dir)
    print(f"  [Launcher] Framework: {framework or 'unknown'}")

    # Tulis PID file
    pid_file = root / ".nanobot.pid"
    pid_file.write_text(str(os.getpid()))

    print()

    # Jalankan sesuai framework
    try:
        if framework == "streamlit":
            run_streamlit(entry, args.host, args.port)
        elif framework == "gradio":
            run_gradio(entry, args.host, args.port)
        elif framework in ("fastapi", "uvicorn"):
            run_uvicorn(entry, args.host, args.port)
        else:
            run_default(entry, args.host, args.port)
    except KeyboardInterrupt:
        print("\n  [INFO] Nanobot stopped.")
    finally:
        if pid_file.exists():
            pid_file.unlink()


if __name__ == "__main__":
    main()