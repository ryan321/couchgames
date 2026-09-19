#!/usr/bin/env python3
"""Build a self-contained macOS GDK setup app using installed tools; no downloads."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
VERSION = "0.1.0-preview.4"
APP = "Giga Couch GDK Setup.app"
CREATOR = "Giga Couch Creator.app"


def copy_tree(source, target, suffixes=None):
    for path in sorted(source.rglob("*")):
        relative = path.relative_to(source)
        if any(part.startswith(".") or part == "__pycache__" for part in relative.parts):
            continue
        if path.is_symlink():
            raise ValueError(f"Unexpected symlink: {path}")
        if path.is_file() and (suffixes is None or path.suffix in suffixes):
            destination = target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)


def app_info(installed):
    return {
        "CFBundleExecutable": "GDKSetup",
        "CFBundleIdentifier": "com.gigacouch.creator" if installed else "com.gigacouch.gdk-setup",
        "CFBundleName": "Giga Couch Creator" if installed else "Giga Couch GDK Setup",
        "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "4", "LSMinimumSystemVersion": "13.0",
        "NSHighResolutionCapable": True, "GigaGDKInstalled": installed,
    }


def make_app(path, binary, installed):
    contents = path / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    shutil.copy2(binary, contents / "MacOS/GDKSetup")
    (contents / "Info.plist").write_bytes(plistlib.dumps(app_info(installed)))


def manifest(root):
    files = []
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"Unexpected symlink: {path}")
        if path.is_file():
            data = path.read_bytes()
            files.append({"path": path.relative_to(root).as_posix(), "size": len(data),
                          "sha256": hashlib.sha256(data).hexdigest(), "executable": bool(path.stat().st_mode & 0o111)})
    return {"format": 1, "version": VERSION, "files": files}


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-build", action="store_true", help="Reuse existing couch and native setup binaries")
    args = parser.parse_args()
    if sys.platform != "darwin" or platform.machine() != "arm64":
        raise RuntimeError("The initial setup build targets macOS Apple Silicon only.")
    output = ROOT / ".gigacouch/gdk"
    output.mkdir(parents=True, exist_ok=True)
    binary = output / "GDKSetup"
    if not args.skip_build:
        run("cargo", "build", "--locked", "-p", "couch-cli")
        run("xcrun", "swiftc", "-swift-version", "5", "-O", "-target", "arm64-apple-macos13.0",
            "-framework", "AppKit", "-framework", "CryptoKit",
            str(ROOT / "apps/gdk-setup/macos/SetupCore.swift"),
            str(ROOT / "apps/gdk-setup/macos/SetupStyle.swift"),
            str(ROOT / "apps/gdk-setup/macos/AgentCore.swift"),
            str(ROOT / "apps/gdk-setup/macos/AgentSetup.swift"),
            str(ROOT / "apps/gdk-setup/macos/SetupApp.swift"), "-o", str(binary))
    app = output / APP
    if app.exists():
        shutil.rmtree(app)
    make_app(app, binary, False)
    payload = app / "Contents/Resources/payload"
    payload.mkdir(parents=True)
    (payload / "bin").mkdir()
    shutil.copy2(ROOT / "target/debug/couch", payload / "bin/couch")
    run("strip", "-x", str(payload / "bin/couch"))
    run("codesign", "--force", "--sign", "-", str(payload / "bin/couch"))
    copy_tree(ROOT / "sdk/addons/couchgames", payload / "sdk/addons/couchgames", {".gd", ".uid", ".cfg", ".json", ".txt"})
    copy_tree(ROOT / "apps/creator-hub", payload / "creator-hub", {".gd", ".uid", ".tscn", ".godot"})
    # project.godot is included; generated .godot/ caches are excluded by copy_tree.
    template = payload / "templates/3d-couch"
    copy_tree(ROOT / "sdk/addons/couchgames", template / "addons/couchgames", {".gd", ".uid", ".cfg", ".json", ".txt"})
    copy_tree(ROOT / "sdk/examples/little_world", template / "examples/little_world", {".gd", ".uid", ".tscn"})
    shutil.copy2(ROOT / "sdk/project.godot", template / "project.godot")
    (template / "README.md").write_text("# Your Giga Couch project\n\nOpen project.godot in supported Godot, wait for import, then press F5.\n\nEdit examples/little_world/world.gd and character.gd. The SDK is pinned in addons/couchgames.\nThis prototype provides input and runtime checks; generic saves, pause/lobby components and distribution remain planned.\n")
    (template / "AGENTS.md").write_text("# Creator instructions\n\nUse the installed Godot version required by addons/couchgames/runtime_policy.json. Do not download tools implicitly.\nUse Platform.input player_joined/player_left, movement and consume_jump for this prototype.\nKeep input per-player; remove characters on player_left. Do not assume planned save/action/publishing APIs exist.\nRun the project in the installed engine and verify controller routing separately from synthetic tests.\n")
    copy_tree(ROOT / "apps/gdk-setup/docs", payload / "docs", {".html"})
    (payload / "START_HERE.txt").write_text("Open Giga Couch Creator.app. For offline setup and first-game instructions, open docs/index.html.\nThis is an internal macOS Apple Silicon preview, not a notarized public release.\n")
    (payload / "NOTICE.txt").write_text("Giga Couch internal development preview. Public SDK/source licensing and dependency notice review remain release work.\nGodot is separately obtained under its own license. No third-party game art or engine binary is included here.\n")
    make_app(payload / CREATOR, binary, True)
    run("codesign", "--force", "--sign", "-", str(payload / CREATOR))
    metadata = manifest(payload)
    (payload / "kit.json").write_text(json.dumps(metadata, indent=2) + "\n")
    run("codesign", "--force", "--sign", "-", str(app))
    archive = output / f"GigaCouch-GDK-{VERSION}-macos-arm64.zip"
    archive.unlink(missing_ok=True)
    run("ditto", "-c", "-k", "--keepParent", str(app), str(archive))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n")
    print(f"Setup app: {app}\nArchive: {archive}\nKit payload: {sum(f['size'] for f in metadata['files']):,} bytes")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
