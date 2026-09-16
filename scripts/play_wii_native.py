#!/usr/bin/env python3
"""Play with one observed 04e8:7021 Wii Remote on macOS. No downloads."""
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile

from godot_tools import ROOT, godot_environment, resolve_godot


def main():
    if sys.platform != "darwin":
        raise RuntimeError("The experimental native Wii reader currently requires macOS.")
    executable = resolve_godot(None)
    source = ROOT / "tools/macos/wii_reader.m"
    app = ROOT / ".couchgames/Wii Reader.app"
    binary = app / "Contents/MacOS/CouchWiiReader"
    if not binary.exists() or source.stat().st_mtime > binary.stat().st_mtime:
        # Explicit developer command uses existing compiler/frameworks only.
        subprocess.run(["xcrun", "--find", "clang"], check=True, capture_output=True)
        binary.parent.mkdir(parents=True, exist_ok=True)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleExecutable": "CouchWiiReader",
            "CFBundleIdentifier": "local.couchgames.WiiReader",
            "CFBundleName": "Couch Games Wii Reader", "CFBundlePackageType": "APPL",
            "NSBluetoothAlwaysUsageDescription": "Read your connected Wii controller for Couch Games.",
            "NSHighResolutionCapable": True,
        }))
        subprocess.run(["xcrun", "clang", "-fobjc-arc", "-framework", "Cocoa", "-framework", "IOKit",
                        str(source), "-o", str(binary)], check=True)
        subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
    # Private, disposable path shared only with this helper and this game session.
    with tempfile.TemporaryDirectory(prefix="couch-wii-") as session:
        environment = godot_environment(True)
        environment["COUCH_WII_NATIVE_STATE"] = str(Path(session) / "state.json")
        imported = subprocess.run([executable, "--headless", "--editor", "--path", str(ROOT / "sdk"), "--quit"],
                                  capture_output=True, text=True, timeout=60, env=godot_environment(True))
        if imported.returncode or "ERROR:" in imported.stderr:
            raise RuntimeError(imported.stdout + imported.stderr)
        print("Native Wii reader enabled for one 04e8:7021 Remote. Pair first; 2 joins/jumps, sideways D-pad moves.", flush=True)
        helper = subprocess.Popen([str(binary), environment["COUCH_WII_NATIVE_STATE"]])
        try:
            return subprocess.call([executable, "--path", str(ROOT / "sdk")], env=environment)
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
