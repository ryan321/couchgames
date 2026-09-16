#!/usr/bin/env python3
"""Play with observed 04e8:7021 Wii Remotes on macOS. No downloads."""
from pathlib import Path
import argparse
import plistlib
import subprocess
import sys
import tempfile

from godot_tools import ROOT, godot_environment, resolve_godot


def build_reader(fleet=False):
    """Build the selected helper with an existing compiler; never install tools."""
    source = ROOT / ("tools/macos/wii_fleet.m" if fleet else "tools/macos/wii_reader.m")
    app = ROOT / (".couchgames/Wii Fleet.app" if fleet else ".couchgames/Wii Reader.app")
    binary = app / "Contents/MacOS/CouchWiiReader"
    if not binary.exists() or max(source.stat().st_mtime, source.with_name("wii_reports.h").stat().st_mtime) > binary.stat().st_mtime:
        # Explicit developer command uses existing compiler/frameworks only.
        subprocess.run(["xcrun", "--find", "clang"], check=True, capture_output=True)
        binary.parent.mkdir(parents=True, exist_ok=True)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleExecutable": "CouchWiiReader",
            "CFBundleIdentifier": "local.couchgames.WiiFleet" if fleet else "local.couchgames.WiiReader",
            "CFBundleName": "Couch Games Wii Reader", "CFBundlePackageType": "APPL",
            "NSBluetoothAlwaysUsageDescription": "Read your connected Wii controller for Couch Games.",
            "NSHighResolutionCapable": True,
        }))
        subprocess.run(["xcrun", "clang", "-fobjc-arc", "-framework", "Cocoa", "-framework", "IOKit",
                        str(source), "-o", str(binary)], check=True)
        subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
    return binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", choices=["little-world", "cloudbound", "pocket-rally"], default="little-world")
    parser.add_argument("--joycons", choices=["separate", "paired"], default="separate",
                        help="One sideways Joy-Con per player (default), or a combined pair in a grip")
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise RuntimeError("The experimental native Wii reader currently requires macOS.")
    executable = resolve_godot(None)
    fleet = args.game == "pocket-rally"
    binary = build_reader(fleet)
    # Private, disposable path shared only with this helper and this game session.
    with tempfile.TemporaryDirectory(prefix="couch-wii-") as session:
        environment = godot_environment(True, args.joycons)
        state_path = session if fleet else str(Path(session) / "state.json")
        environment["COUCH_WII_FLEET_DIR" if fleet else "COUCH_WII_NATIVE_STATE"] = state_path
        if fleet:
            environment.pop("COUCH_WII_NATIVE_STATE", None)
        imported = subprocess.run([executable, "--headless", "--editor", "--path", str(ROOT / "sdk"), "--quit"],
                                  capture_output=True, text=True, timeout=60, env=godot_environment(True, args.joycons))
        if imported.returncode or "ERROR:" in imported.stderr:
            raise RuntimeError(imported.stdout + imported.stderr)
        scene = "res://examples/cloudbound/flight.tscn" if args.game == "cloudbound" else "res://examples/little_world/world.tscn"
        if not fleet:
            print("Native Wii reader enabled for one 04e8:7021 Remote. " +
                  ("Cloudbound: hold sideways, press 2, then tilt to fly; B boosts." if args.game == "cloudbound"
                   else "Little World: 2 joins/jumps, sideways D-pad moves."), flush=True)
        if fleet:
            scene = "res://examples/pocket_rally/rally.tscn"
            print("Pocket Rally: up to 16 Wii reader channels; physical multi-Remote testing pending. Tilt steers; 2 gas; 1 brake.", flush=True)
        helper = subprocess.Popen([str(binary), state_path])
        try:
            return subprocess.call([executable, "--path", str(ROOT / "sdk"), scene], env=environment)
        finally:
            if helper.poll() is None:
                helper.terminate()
                try:
                    helper.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    helper.kill()
                    helper.wait()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Could not start native Wii play: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
