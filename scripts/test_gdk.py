#!/usr/bin/env python3
"""Test a built GDK outside the checkout using already-installed tools and Godot."""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile

from build_gdk import ROOT, APP, VERSION
from godot_tools import resolve_godot


def run(command, expected=None):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=180)
    print(result.stdout, end="", flush=True)
    print(result.stderr, end="", flush=True)
    if result.returncode or "ERROR:" in result.stderr or (expected and expected not in result.stdout):
        raise RuntimeError(f"Check failed: {command[0]}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep", help="Keep the installed test kit under this parent folder for UI testing")
    args = parser.parse_args()
    output = ROOT / ".gigacouch/gdk"
    payload = output / APP / "Contents/Resources/payload"
    executable = resolve_godot()
    test_binary = output / "setup-tests"
    run(["xcrun", "swiftc", "-swift-version", "5", "-framework", "CryptoKit",
         str(ROOT / "apps/gdk-setup/macos/SetupCore.swift"),
         str(ROOT / "apps/gdk-setup/macos/AgentCore.swift"),
         str(ROOT / "tests/gdk/SetupCoreTests.swift"), "-o", str(test_binary)])
    with tempfile.TemporaryDirectory(prefix="couch-gdk-independent-") as temp:
        install_parent = Path(args.keep).resolve() if args.keep else Path(temp) / "installed"
        run([str(test_binary), str(payload / "bin/couch"), str(payload), str(install_parent)], "GDK installer checks passed:")
        installed = install_parent / VERSION
        hub = installed / "creator-hub"
        run([executable, "--headless", "--editor", "--path", str(hub), "--quit"])
        run([executable, "--headless", "--path", str(hub), "--script", str(ROOT / "tests/gdk/test_projects.gd"), "--",
             str(installed / "templates/3d-couch"), temp], "Creator Hub checks passed:")
        game = Path(temp) / "our-first-game"
        run([executable, "--headless", "--editor", "--path", str(game), "--quit"])
        run([executable, "--headless", "--path", str(game), "--quit-after", "20"])
        run(["codesign", "--verify", "--deep", "--strict", str(installed / "Giga Couch Creator.app")])
        print("Fresh GDK install, standalone project import/run, and launcher signature checks passed. Physical controllers not tested.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
