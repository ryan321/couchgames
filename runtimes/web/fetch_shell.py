#!/usr/bin/env python3
"""Download the Electron prototype shell onto the external drive.

The couch CLI and the tests never call this script. It refuses to write to
the internal disk. Re-running it leaves an existing verified copy in place.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import ssl
import sys
import urllib.request
import zipfile
from pathlib import Path

VERSION = "44.4.4"
DEST = Path("/Volumes/External/projects/gigacouch-electron")
BINARY = DEST / "Electron.app" / "Contents" / "MacOS" / "Electron"
ASSET = f"electron-v{VERSION}-darwin-arm64.zip"
BASE = f"https://github.com/electron/electron/releases/download/v{VERSION}"


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    partial = dest.with_suffix(dest.suffix + ".partial")
    context = ssl.create_default_context(cafile=os.environ.get("SSL_CERT_FILE", "/etc/ssl/cert.pem"))
    print(f"Fetching {url}")
    with urllib.request.urlopen(url, context=context) as response, partial.open("wb") as handle:
        shutil.copyfileobj(response, handle)
    partial.replace(dest)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_hash(sums: str) -> str:
    for line in sums.splitlines():
        digest, name = line.split(None, 1)
        if name.lstrip("*") == ASSET:
            return digest
    fail(f"{ASSET} is missing from SHASUMS256.txt")
    return ""


def main() -> None:
    if sys.platform != "darwin" or os.uname().machine != "arm64":
        fail("This fetch installs the macOS arm64 shell. Windows needs its own Electron build.")
    if not Path("/Volumes/External").is_dir():
        fail("Mount /Volumes/External first. The shell download does not use the internal disk.")
    if BINARY.is_file() and (DEST / "VERSION").read_text(encoding="utf-8").strip() == VERSION:
        repair_symlinks(DEST)
        mark_executables(DEST)
        print(f"Shell already present: {BINARY}")
        return
    DEST.mkdir(parents=True, exist_ok=True)
    sums_path = DEST / "SHASUMS256.txt"
    archive = DEST / ASSET
    download(f"{BASE}/SHASUMS256.txt", sums_path)
    download(f"{BASE}/{ASSET}", archive)
    digest = sha256(archive)
    want = expected_hash(sums_path.read_text(encoding="utf-8"))
    if digest != want:
        archive.unlink(missing_ok=True)
        fail(f"Checksum mismatch for {ASSET}: {digest} != {want}")
    print(f"Unpacking {archive.name}")
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(DEST)
        for info in bundle.infolist():
            mode = (info.external_attr >> 16) & 0o777
            target = DEST / info.filename
            if mode and target.is_file():
                target.chmod(mode)
    archive.unlink()
    repair_symlinks(DEST)
    mark_executables(DEST)
    (DEST / "VERSION").write_text(VERSION + "\n", encoding="utf-8")
    if not os.access(BINARY, os.X_OK):
        fail(f"Unpack finished without an executable {BINARY}")
    print(f"Installed {BINARY}")


def repair_symlinks(root: Path) -> None:
    """zipfile writes symlink entries as plain files. Turn those back into links."""
    changed = True
    while changed:
        changed = False
        files = [
            path
            for path in root.rglob("*")
            if path.is_file() and not path.is_symlink() and path.stat().st_size <= 200
        ]
        files.sort(key=lambda path: len(path.parts), reverse=True)
        for path in files:
            data = path.read_bytes()
            if not data or b"\0" in data or b"\n" in data or b"\r" in data:
                continue
            text = data.decode("utf-8")
            if text.startswith(("{", "APPL", "<?xml")):
                continue
            if text.startswith("/") or text == ".":
                continue
            target = path.parent / text
            try:
                resolved = target.resolve()
            except OSError:
                continue
            if not resolved.is_relative_to(root.resolve()) or not target.exists():
                continue
            path.unlink()
            path.symlink_to(text)
            changed = True


def mark_executables(root: Path) -> None:
    for path in root.rglob("*"):
        if path.is_file() and path.parent.name in {"MacOS", "Helpers"}:
            path.chmod(path.stat().st_mode | 0o755)


if __name__ == "__main__":
    main()
