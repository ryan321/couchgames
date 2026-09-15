#!/usr/bin/env python3
"""Run Little World using the platform-selected Godot. Downloads no engine/templates."""
import argparse
import subprocess
import sys

from godot_tools import ROOT, resolve_godot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Explicit executable or macOS .app")
    args = parser.parse_args()
    executable = resolve_godot(args.godot)
    # Cold checkouts need an import pass before running scripts/resources.
    imported = subprocess.run(
        [executable, "--headless", "--editor", "--path", str(ROOT / "sdk"), "--quit"],
        text=True, capture_output=True, timeout=60,
    )
    if imported.returncode or "ERROR:" in imported.stderr:
        print(imported.stdout + imported.stderr, file=sys.stderr)
        return 1
    return subprocess.call([executable, "--path", str(ROOT / "sdk")], cwd=ROOT)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        print(f"Could not start Little World: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
