#!/usr/bin/env python3
"""Run a source game using the platform-selected Godot. Downloads no engine/templates."""
import argparse
import subprocess
import sys

from godot_tools import ROOT, godot_environment, resolve_godot
from game_catalog import GAMES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", choices=list(GAMES), default="little-world")
    parser.add_argument("--godot", help="Explicit executable or macOS .app")
    parser.add_argument("--wii", action="store_true", help="Enable experimental SDL Wii/Remote Plus/Nunchuk/Classic/Wii U Pro input (pairing required)")
    parser.add_argument("--joycons", choices=["separate", "paired"], default="separate",
                        help="One sideways Joy-Con per player (default), or a combined pair in a grip")
    args = parser.parse_args()
    executable = resolve_godot(args.godot)
    environment = godot_environment(args.wii, args.joycons)
    if args.wii:
        print("Experimental Wii input enabled. Pair controllers with the computer; press F3 for profiles. See docs/wii-controllers.md.", flush=True)
    # Cold checkouts need an import pass before running scripts/resources.
    imported = subprocess.run(
        [executable, "--headless", "--editor", "--path", str(ROOT / "sdk"), "--quit"],
        text=True, capture_output=True, timeout=60, env=environment,
    )
    if imported.returncode or "ERROR:" in imported.stderr:
        print(imported.stdout + imported.stderr, file=sys.stderr)
        return 1
    scene = GAMES[args.game]["scene"]
    if args.game == "pocket-rally":
        scene = "res://examples/pocket_rally/rally.tscn"
    return subprocess.call([executable, "--path", str(ROOT / "sdk"), scene], cwd=ROOT, env=environment)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        print(f"Could not start game: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
