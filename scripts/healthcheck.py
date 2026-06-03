#!/usr/bin/env python3
"""
Nanobot Portable - Health Check
Memeriksa kesiapan lingkungan sebelum menjalankan Nanobot.
"""

import sys
import os
from pathlib import Path


def check_python_version():
    """Cek versi Python."""
    version = sys.version_info
    if version >= (3, 9):
        print(f"  [OK] Python {version.major}.{version.minor}.{version.micro}")
        return True
    else:
        print(f"  [WARN] Python {version.major}.{version.minor} - recommended 3.9+")
        return False


def check_packages():
    """Cek paket-paket penting."""
    important = {
        "openai": "OpenAI API",
        "langchain": "LangChain",
        "fastapi": "FastAPI",
        "uvicorn": "Uvicorn",
        "gradio": "Gradio",
        "chromadb": "ChromaDB",
        "sentence_transformers": "Sentence Transformers",
        "numpy": "NumPy",
        "pandas": "Pandas",
        "tiktoken": "Tiktoken",
    }

    found = 0
    missing = []

    for pkg, name in important.items():
        try:
            mod = __import__(pkg)
            ver = getattr(mod, "__version__", "?")
            print(f"  [OK] {name}: {ver}")
            found += 1
        except ImportError:
            missing.append(pkg)

    if missing:
        print(f"  [INFO] {len(missing)} package not found: {', '.join(missing)}")

    return len(missing) == 0


def check_config():
    """Cek konfigurasi."""
    root = Path(__file__).parent.parent
    config_dir = root / "data"

    env_file = config_dir / ".env"
    if env_file.exists():
        content = env_file.read_text(encoding="utf-8", errors="ignore")
        if "sk-your-api-key" in content or "your-api-key" in content:
            print("  [WARN] API key is not configured in .env")
            return False
        else:
            print("  [OK] .env file found")
            return True
    else:
        print("  [WARN] File .env not found")
        return False


def check_directories():
    """Cek direktori penting."""
    root = Path(__file__).parent.parent

    dirs = {
        "data": root / "data",
        "knowledge": root / "data" / "knowledge",
        "logs": root / "data" / "logs",
        "app": root / "app",
        "config": root / "data",
    }

    all_ok = True
    for name, path in dirs.items():
        if path.exists():
            print(f"  [OK] {name}/ ({path})")
        else:
            print(f"  [WARN] {name}/ not found")
            all_ok = False

    return all_ok


def check_nanobot_entry():
    """Cek entry point Nanobot."""
    root = Path(__file__).parent.parent
    app_dir = root / "app"

    entry_files = ["run.py", "app.py", "main.py", "server.py", "manage.py"]

    found = False
    for f in entry_files:
        if (app_dir / f).exists():
            print(f"  [OK] Entry point: {f}")
            found = True
            break

    if not found:
        try:
            import nanobot
            print(f"  [OK] Nanobot module available")
            found = True
        except ImportError:
            print("  [WARN] Entry point not found")

    return found


def main():
    print()
    print("  ═══════════════════════════════════════")
    print("    NANOBOT PORTABLE - HEALTH CHECK")
    print("  ═══════════════════════════════════════")
    print()

    results = []

    print("  ▸ Python Version")
    results.append(check_python_version())
    print()

    print("  ▸ Python Packages")
    results.append(check_packages())
    print()

    print("  ▸ Configuration")
    results.append(check_config())
    print()

    print("  ▸ Directories")
    results.append(check_directories())
    print()

    print("  ▸ Entry Points")
    results.append(check_nanobot_entry())
    print()

    all_ok = all(results)
    if all_ok:
        print("   All checks passed!")
    else:
        print("   Some checks are problematic.")
        print("   Run setup.bat to fix.")

    print()
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())