#!/usr/bin/env python3
"""Compile the macOS arm64 web-1 Chromium runtime.

The checkout is kept on the external volume. This script refuses to use the
internal disk. It downloads CEF's current automate-git.py, pins branch 7977,
and builds cefsimple with the development GN args.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = Path(__file__).resolve().parent
POLICY_ARGS = RUNTIME / "args.macos.dev.gn"
DEFAULT_DIR = Path("/Volumes/External/projects/gigacouch-chromium")
CEF_BRANCH = "7977"
AUTOMATE_URL = (
    "https://raw.githubusercontent.com/chromiumembedded/cef/master/"
    "tools/automate/automate-git.py"
)
MIN_FREE_BYTES = 120 * 1024**3


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(1)


def place_on_external(link: Path, target: Path) -> None:
    """Point a home-directory cache at a directory on the external volume."""
    target.mkdir(parents=True, exist_ok=True)
    if link.is_symlink() and link.resolve() == target.resolve():
        return
    if link.is_symlink() or link.is_file():
        link.unlink()
    elif link.is_dir():
        for child in link.iterdir():
            dest = target / child.name
            if not dest.exists():
                shutil.move(str(child), str(dest))
        link.rmdir()
    link.parent.mkdir(parents=True, exist_ok=True)
    link.symlink_to(target, target_is_directory=True)


def use_external_disk(download_dir: Path) -> dict[str, str]:
    """Keep temp files and tool caches off the internal disk."""
    tmp = download_dir / "tmp"
    cache = download_dir / "cache"
    tmp.mkdir(parents=True, exist_ok=True)
    (cache / "git").mkdir(parents=True, exist_ok=True)
    (cache / "cipd").mkdir(parents=True, exist_ok=True)
    place_on_external(Path.home() / "Library/Caches/depot_tools", cache / "depot_tools")
    place_on_external(
        Path.home() / ".cache" / f"vpython-root.{os.getuid()}",
        cache / "vpython",
    )
    return {
        "TMPDIR": str(tmp),
        "TEMP": str(tmp),
        "TMP": str(tmp),
        "GIT_CACHE_PATH": str(cache / "git"),
        "CIPD_CACHE_DIR": str(cache / "cipd"),
    }


def gn_defines(path: Path) -> str:
    parts: list[str] = []
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if line:
            parts.append(line)
    if not parts:
        fail(f"{path} has no GN args")
    return " ".join(parts)


def reexec_under_caffeinate() -> None:
    if os.environ.get("GIGACOUCH_CAFFEINATED") == "1":
        return
    if shutil.which("caffeinate") is None:
        return
    os.environ["GIGACOUCH_CAFFEINATED"] = "1"
    os.execvp(
        "caffeinate",
        ["caffeinate", "-ims", sys.executable, "-u", str(Path(__file__).resolve()), *sys.argv[1:]],
    )


def prepare_automate(download_dir: Path, jobs: str) -> Path:
    script = download_dir / "automate-git.py"
    os.environ.setdefault("SSL_CERT_FILE", "/etc/ssl/cert.pem")
    print(f"Fetching {AUTOMATE_URL}")
    urllib.request.urlretrieve(AUTOMATE_URL, script)
    text = script.read_text()
    needle = "  command = 'autoninja '\n"
    replacement = f"  command = 'autoninja -j {jobs} '\n"
    if needle not in text:
        fail("CEF automate-git.py no longer builds with autoninja; the job cap was not applied.")
    script.write_text(text.replace(needle, replacement, 1))
    return script


def main() -> None:
    reexec_under_caffeinate()
    if sys.platform != "darwin":
        fail("This script builds macOS arm64. Windows uses the same CEF branch with --x64-build.")

    download_dir = Path(os.environ.get("GIGACOUCH_CHROMIUM_DIR", DEFAULT_DIR))
    if "External" not in download_dir.parts and os.environ.get("GIGACOUCH_ALLOW_INTERNAL_DISK") != "1":
        fail(
            f"Refusing to put Chromium on {download_dir}. "
            "The internal disk is too small. Mount /Volumes/External or set GIGACOUCH_CHROMIUM_DIR."
        )
    if not download_dir.parent.is_dir():
        fail(f"Parent directory does not exist: {download_dir.parent}")

    usage = shutil.disk_usage(download_dir.parent)
    if usage.free < MIN_FREE_BYTES:
        fail(
            f"{download_dir.parent} has {usage.free / 1024**3:.0f} GiB free. "
            f"A Chromium checkout needs at least {MIN_FREE_BYTES / 1024**3:.0f} GiB."
        )

    jobs = os.environ.get("GIGACOUCH_NINJA_JOBS", "2")
    if not jobs.isdigit() or int(jobs) < 1:
        fail(f"GIGACOUCH_NINJA_JOBS must be a positive integer, got {jobs!r}")

    download_dir.mkdir(parents=True, exist_ok=True)
    status = download_dir / "build.status"
    pid_path = download_dir / "build.pid"
    status.write_text("running\n")
    pid_path.write_text(f"{os.getpid()}\n")

    external_env = use_external_disk(download_dir)
    script = prepare_automate(download_dir, jobs)
    defines = gn_defines(POLICY_ARGS)
    env = os.environ.copy()
    env.update(external_env)
    env.update(
        {
            "SSL_CERT_FILE": "/etc/ssl/cert.pem",
            "GIT_SSL_CAINFO": "/etc/ssl/cert.pem",
            "CURL_CA_BUNDLE": "/etc/ssl/cert.pem",
            "REQUESTS_CA_BUNDLE": "/etc/ssl/cert.pem",
            "GN_DEFINES": defines,
            "CEF_ARCHIVE_FORMAT": "tar.bz2",
            "GIGACOUCH_NINJA_JOBS": jobs,
        }
    )
    command = [
        sys.executable,
        str(script),
        f"--download-dir={download_dir}",
        f"--branch={CEF_BRANCH}",
        "--url=https://github.com/chromiumembedded/cef.git",
        "--arm64-build",
        "--no-debug-build",
        "--no-distrib",
        "--no-release-tests",
        "--no-chromium-history",
        "--build-log-file",
        "--build-target=cefsimple",
    ]
    print("web-1 macOS arm64 build")
    print(f"directory: {download_dir}")
    print(f"temp: {external_env['TMPDIR']}")
    print(f"git cache: {external_env['GIT_CACHE_PATH']}")
    print(f"GN_DEFINES: {defines}")
    print(f"jobs: {jobs}")
    print("command:", " ".join(command))
    try:
        subprocess.check_call(command, cwd=download_dir, env=env)
    except subprocess.CalledProcessError as error:
        status.write_text(f"failed {error.returncode}\n")
        fail(f"Chromium build failed with exit code {error.returncode}")
    status.write_text("ok\n")
    print("cefsimple build finished")


if __name__ == "__main__":
    main()
