#!/usr/bin/env python3
"""Run SDK checks through our own Godot discovery. Never downloads an engine."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Explicit executable or macOS .app")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    command = ["cargo", "run", "--quiet", "--locked", "-p", "couch-cli", "--", "--json"]
    if args.godot:
        command += ["--godot", args.godot]
    command += ["doctor", "--require-godot"]
    doctor = subprocess.run(command, cwd=root, text=True, capture_output=True, timeout=180)
    if doctor.returncode:
        print(doctor.stdout, end="")
        print(doctor.stderr, end="", file=sys.stderr)
        return doctor.returncode
    report = json.loads(doctor.stdout)["data"]["godot"]
    executable = report["executable"]
    # Import/parse the editor plugin as well as checking the headless SDK API.
    for arguments, expected in [
        (["--headless", "--editor", "--path", str(root / "sdk"), "--quit"], None),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_runtime.gd"], "SDK runtime checks passed:"),
    ]:
        result = subprocess.run([executable, *arguments], cwd=root, text=True, capture_output=True, timeout=60)
        print(result.stdout, end="")
        print(result.stderr, end="", file=sys.stderr)
        if result.returncode or "SCRIPT ERROR:" in result.stderr or (expected and expected not in result.stdout):
            return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError, KeyError) as error:
        print(f"SDK check failed: {error}", file=sys.stderr)
        sys.exit(1)
