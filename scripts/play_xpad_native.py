#!/usr/bin/env python3
"""Play with wired Xbox 360-style USB pads that macOS does not expose as HID. No downloads."""
from pathlib import Path
import argparse
import plistlib
import subprocess
import sys
import tempfile

from godot_tools import ROOT, godot_environment, resolve_godot
from game_catalog import GAMES, rendering_arguments


def pad_connected():
    """True when a vendor-class USB device that is not a hub/NIC/disk is present."""
    if sys.platform != "darwin":
        return False
    try:
        output = subprocess.check_output(["ioreg", "-p", "IOUSB", "-l", "-w0"], text=True, timeout=8)
    except (OSError, subprocess.SubprocessError):
        return False
    skip = ("usb3.1 hub", "usb2.1 hub", "usb3 hub", "usb2 hub", " lan", "ethernet", "storage", "express")
    for block in output.split("+-o "):
        if "<class IOUSBHostDevice" not in block or '"bDeviceClass" = 255' not in block:
            continue
        lower = block.lower()
        if any(token in lower for token in skip):
            continue
        return True
    return False


def build_reader():
    source = ROOT / "tools/macos/xpad_reader.m"
    headers = [ROOT / "tools/macos/xpad_reports.h", ROOT / "tools/macos/xpad_devices.h"]
    app = ROOT / ".gigacouch/Xpad Reader.app"
    binary = app / "Contents/MacOS/CouchXpadReader"
    newest = max(path.stat().st_mtime for path in [source, *headers])
    if not binary.exists() or newest > binary.stat().st_mtime:
        subprocess.run(["xcrun", "--find", "clang"], check=True, capture_output=True)
        binary.parent.mkdir(parents=True, exist_ok=True)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleExecutable": "CouchXpadReader",
            "CFBundleIdentifier": "local.gigacouch.XpadReader",
            "CFBundleName": "Giga Couch wired USB reader",
            "CFBundlePackageType": "APPL",
            "NSHighResolutionCapable": True,
        }))
        subprocess.run(["xcrun", "clang", "-fobjc-arc", "-framework", "Cocoa", "-framework", "IOKit",
                        "-framework", "CoreFoundation", str(source), "-o", str(binary)], check=True)
        subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
    return binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", choices=list(GAMES), default="little-world")
    parser.add_argument("--check", action="store_true", help="Open matching USB pads, confirm input reports, then exit")
    parser.add_argument("--dump", action="store_true", help="Print USB candidates and catalog rows for an unknown pad")
    parser.add_argument("--compatibility", action="store_true", help="Use the simpler renderer on older graphics hardware")
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise RuntimeError("The wired USB reader currently requires macOS.")
    binary = build_reader()
    if args.dump:
        return subprocess.call([str(binary), "--dump"])
    if args.check:
        return subprocess.call([str(binary), "--check"])
    executable = resolve_godot(None)
    with tempfile.TemporaryDirectory(prefix="couch-xpad-") as session:
        environment = godot_environment(False, "separate")
        state_path = str(Path(session) / "state.json")
        environment["COUCH_XPAD_NATIVE_STATE"] = state_path
        imported = subprocess.run([executable, "--headless", "--editor", "--path", str(ROOT / "sdk"), "--quit"],
                                  capture_output=True, text=True, timeout=60, env=godot_environment(False, "separate"))
        if imported.returncode or "ERROR:" in imported.stderr:
            raise RuntimeError(imported.stdout + imported.stderr)
        print("Wired USB reader enabled for Xbox 360-style pads. Press A / Cross to join. Hold B / Circle to leave.", flush=True)
        helper = subprocess.Popen([str(binary), state_path])
        try:
            return subprocess.call([executable, *rendering_arguments(args.game, compatibility=args.compatibility),
                                    "--path", str(ROOT / "sdk"), GAMES[args.game]["scene"]], env=environment)
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
        print(f"Could not start wired USB play: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
