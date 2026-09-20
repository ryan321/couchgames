#!/usr/bin/env python3
"""Build the local Giga Couch player app using installed tools; no downloads."""
from pathlib import Path
import argparse
import platform
import plistlib
import shutil
import subprocess
import sys

from branding import install_into_app, make_icns, plist_icon

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / ".gigacouch/player/Giga Couch.app"


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--desktop", action="store_true", help="Create or update our Desktop app shortcut")
    args = parser.parse_args()
    if sys.platform != "darwin" or platform.machine() != "arm64":
        raise RuntimeError("This preview targets macOS Apple Silicon.")
    run("cargo", "build", "--locked", "-p", "couch-cli")
    output = APP.parent
    output.mkdir(parents=True, exist_ok=True)
    binary = output / "GigaCouch"
    run("xcrun", "swiftc", "-swift-version", "5", "-O", "-target", "arm64-apple-macos13.0",
        "-framework", "AppKit", "-framework", "CryptoKit",
        str(ROOT / "apps/gdk-setup/macos/SetupCore.swift"),
        str(ROOT / "apps/gdk-setup/macos/SetupStyle.swift"),
        str(ROOT / "apps/player/macos/PlayerApp.swift"), "-o", str(binary))
    if APP.exists():
        shutil.rmtree(APP)
    contents = APP / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    (contents / "Resources").mkdir()
    shutil.copy2(binary, contents / "MacOS/GigaCouch")
    shutil.copy2(ROOT / "target/debug/couch", contents / "Resources/couch")
    run("strip", "-x", str(contents / "Resources/couch"))
    run("codesign", "--force", "--sign", "-", str(contents / "Resources/couch"))
    icns = output / "AppIcon.icns"
    make_icns(icns)
    install_into_app(contents, icns)
    info = {
        "CFBundleExecutable": "GigaCouch", "CFBundleIdentifier": "com.gigacouch.player",
        "CFBundleName": "Giga Couch", "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1",
        "LSMinimumSystemVersion": "13.0", "NSHighResolutionCapable": True,
        "GigaSourceRoot": str(ROOT), "GigaPython": sys.executable,
    }
    info.update(plist_icon())
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    run("codesign", "--force", "--sign", "-", str(APP))
    if args.desktop:
        shortcut = Path.home() / "Desktop/Giga Couch.app"
        if shortcut.is_symlink() and shortcut.readlink() == APP:
            pass
        elif not shortcut.exists() and not shortcut.is_symlink():
            shortcut.symlink_to(APP, target_is_directory=True)
        else:
            raise RuntimeError(f"Existing Desktop item preserved: {shortcut}. App built at {APP}")
    print(f"Player app: {APP}\nLocal preview uses this checkout and existing Python/Godot. No game assets copied.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
