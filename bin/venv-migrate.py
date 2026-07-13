#!/usr/bin/env python3
"""Safely rebuild a legacy ./venv as ./.venv."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def _venv_python(root: Path) -> Path:
    if sys.platform == "win32":
        return root / "Scripts" / "python.exe"
    return root / "bin" / "python"


def main() -> int:
    legacy = Path("venv")
    target = Path(".venv")
    backup = Path("venv.migrated-backup")

    if target.exists():
        print("[venv.migrate] ./.venv already exists; nothing was changed.", file=sys.stderr)
        return 1
    if not legacy.is_dir():
        print("[venv.migrate] Legacy ./venv was not found; nothing was changed.", file=sys.stderr)
        return 1
    if backup.exists():
        print("[venv.migrate] ./venv.migrated-backup already exists; nothing was changed.", file=sys.stderr)
        return 1

    legacy_python = _venv_python(legacy)
    if not legacy_python.is_file():
        print("[venv.migrate] Legacy ./venv has no usable Python interpreter.", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="venv-migrate-") as temp_dir:
        requirements = Path(temp_dir) / "requirements.txt"
        try:
            frozen = subprocess.run(
                [str(legacy_python), "-m", "pip", "freeze"],
                check=True,
                capture_output=True,
                text=True,
            )
            requirements.write_text(frozen.stdout, encoding="utf-8")
            subprocess.run([sys.executable, "-m", "venv", str(target)], check=True)
            if frozen.stdout.strip():
                subprocess.run(
                    [str(_venv_python(target)), "-m", "pip", "install", "-r", str(requirements)],
                    check=True,
                )
        except (OSError, subprocess.CalledProcessError) as error:
            shutil.rmtree(target, ignore_errors=True)
            print(f"[venv.migrate] Migration failed: {error}", file=sys.stderr)
            print("[venv.migrate] The legacy ./venv was left unchanged.", file=sys.stderr)
            return 1

    try:
        legacy.rename(backup)
    except OSError as error:
        shutil.rmtree(target, ignore_errors=True)
        print(f"[venv.migrate] Could not retire the legacy ./venv: {error}", file=sys.stderr)
        print("[venv.migrate] The legacy ./venv was left unchanged.", file=sys.stderr)
        return 1

    try:
        shutil.rmtree(backup)
    except OSError as error:
        print(f"[venv.migrate] Migration succeeded, but {backup} could not be removed: {error}", file=sys.stderr)
    print("[venv.migrate] Migrated ./venv to ./.venv. Run venv.activate to activate it.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
