#!/usr/bin/env python3
"""Run SDK checks through our own Godot discovery. Never downloads an engine."""
import argparse
import json
import subprocess
import sys

from godot_tools import ROOT, godot_environment, resolve_godot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Explicit executable or macOS .app")
    parser.add_argument("--wii", action="store_true", help="Also exercise startup with the experimental Wii driver enabled")
    args = parser.parse_args()
    root = ROOT
    executable = resolve_godot(args.godot)
    environment = godot_environment(args.wii)
    # Import/parse the editor plugin as well as checking the headless SDK API.
    for arguments, expected in [
        (["--headless", "--editor", "--path", str(root / "sdk"), "--quit"], None),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_runtime.gd"], "SDK runtime checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_input.gd"], "SDK input checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_wii.gd"], "Wii profile checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_native_wii.gd"], "Native Wii checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_playground.gd"], "Playground checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_flight.gd"], "Flight checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_controller_motion.gd"], "Controller motion checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_rally.gd"], "Rally checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_library.gd"], "Library checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_sunbreak.gd"], "Sunbreak checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_world_1_1.gd"], "World 1-1 checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_gauntlet_visibility.gd"], "Gauntlet visibility checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_gauntlet_cast.gd"], "Gauntlet cast checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_gauntlet.gd"], "Gauntlet checks passed:"),
        (["--headless", "--audio-driver", "Dummy", "--path", str(root / "sdk"), "--script", "res://tests/test_gauntlet_audio.gd"], "Gauntlet audio checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_gauntlet_campaign.gd"], "Gauntlet campaign checks passed:"),
        (["--headless", "--path", str(root / "sdk"), "--script", "res://tests/test_gauntlet_return.gd"], "Gauntlet return checks passed:"),
    ]:
        result = subprocess.run([executable, *arguments], cwd=root, text=True, capture_output=True, timeout=60, env=environment)
        print(result.stdout, end="")
        print(result.stderr, end="", file=sys.stderr)
        if result.returncode or "ERROR:" in result.stderr or (expected and expected not in result.stdout):
            return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError, KeyError) as error:
        print(f"SDK check failed: {error}", file=sys.stderr)
        sys.exit(1)
