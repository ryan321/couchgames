#!/usr/bin/env python3
"""Open the local source-game library using the installed shared Godot runtime."""
import argparse
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from godot_tools import ROOT, godot_environment, resolve_godot
from play_wii_native import build_reader
from play_xpad_native import build_reader as build_xpad_reader, pad_connected as xpad_connected

from creator_projects import launch_spec, merged_catalog
from game_catalog import CATALOG, GAMES, rendering_arguments

SESSION_VARS = (
    "COUCH_WII_NATIVE_STATE",
    "COUCH_WII_FLEET_DIR",
    "COUCH_XPAD_NATIVE_STATE",
    "COUCH_LIBRARY_SESSION",
    "COUCH_PLAYER_STARTUP",
    "COUCH_LIBRARY_CATALOG",
)


def clean_environment():
    environment = godot_environment()
    for name in SESSION_VARS:
        environment.pop(name, None)
    return environment


def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


class LibraryHost:
    """Own only this library session's child processes and disposable input files."""
    def __init__(self, executable, session, popen=subprocess.Popen, reader_builder=build_reader,
                 xpad_builder=None, xpad_available=None):
        self.executable = executable
        self.session = Path(session)
        self.popen = popen
        self.reader_builder = reader_builder
        self.xpad_builder = xpad_builder
        self.xpad_available = xpad_available or (lambda: False)
        self.game = self.helper = self.xpad_helper = self.wii_session = self.xpad_session = self.log = None
        self.state = {"phase": "idle", "message": "Choose something to play.", "native_wii": sys.platform == "darwin"}
        self.games = merged_catalog(CATALOG)
        self.by_id = {game["id"]: game for game in self.games}
        self.catalog_path = self.session / "catalog.json"
        self.write_catalog()
        self.publish()

    def write_catalog(self):
        temporary = self.catalog_path.with_suffix(".tmp")
        temporary.write_text(json.dumps(self.games))
        temporary.replace(self.catalog_path)

    def publish(self):
        self.state["updated"] = time.time()
        path = self.session / "status.json"
        temporary = path.with_suffix(".tmp")
        temporary.write_text(json.dumps(self.state))
        temporary.replace(path)

    def cleanup(self):
        stop(self.game)
        stop(self.helper)
        stop(self.xpad_helper)
        self.game = self.helper = self.xpad_helper = None
        if self.log:
            self.log.close()
            self.log = None
        if self.wii_session:
            self.wii_session.cleanup()
            self.wii_session = None
        if self.xpad_session:
            self.xpad_session.cleanup()
            self.xpad_session = None

    def launch(self, request):
        if self.game is not None:
            return  # Only one active game; duplicate clicks never create another.
        game_id = request.get("game")
        mode = request.get("input", "standard")
        joycons = request.get("joycons", "separate")
        game = self.by_id.get(game_id) if isinstance(game_id, str) else None
        if game is None or mode not in ("standard", "native-wii", "sdl-wii") or joycons not in ("separate", "paired"):
            raise ValueError("That game or controller setup is unavailable.")
        if mode == "native-wii" and sys.platform != "darwin":
            raise ValueError("The native Wii reader requires macOS.")
        path, scene = launch_spec(game)
        if not isinstance(scene, str) or not scene.startswith("res://"):
            raise ValueError("That game or controller setup is unavailable.")
        try:
            readable = path.is_dir() and (path / "project.godot").is_file()
        except OSError:
            readable = False
        if not readable:
            if game.get("project"):
                raise ValueError("This project folder is missing or unreadable. Open it again from Creator Hub.")
            raise ValueError("That game or controller setup is unavailable.")
        self.state.update(phase="starting", game=game_id, message="Opening " + game["title"] + "…")
        self.publish()
        environment = clean_environment()
        environment.update(godot_environment(mode != "standard", joycons))
        for name in SESSION_VARS:
            environment.pop(name, None)
        self.log = (self.session / "game.log").open("w")
        # Samples keep Wii helpers. Creator rows only get one when they declare native_wii.
        if mode == "native-wii" and (game.get("native_wii") or not game.get("project")):
            fleet = game.get("native_wii") == "fleet"
            binary = self.reader_builder(fleet)
            self.wii_session = tempfile.TemporaryDirectory(prefix="couch-library-wii-")
            state_path = self.wii_session.name if fleet else str(Path(self.wii_session.name) / "state.json")
            environment["COUCH_WII_FLEET_DIR" if fleet else "COUCH_WII_NATIVE_STATE"] = state_path
            self.helper = self.popen([str(binary), state_path], stdout=self.log, stderr=subprocess.STDOUT, env=clean_environment())
        if self.xpad_builder and self.xpad_available():
            self.xpad_session = tempfile.TemporaryDirectory(prefix="couch-library-xpad-")
            xpad_path = str(Path(self.xpad_session.name) / "state.json")
            environment["COUCH_XPAD_NATIVE_STATE"] = xpad_path
            self.xpad_helper = self.popen([str(self.xpad_builder()), xpad_path], stdout=self.log, stderr=subprocess.STDOUT, env=clean_environment())
        cwd = path if game.get("project") else ROOT
        self.game = self.popen([self.executable, *rendering_arguments(game_id), "--path", str(path), scene],
                               cwd=cwd, env=environment, stdout=self.log, stderr=subprocess.STDOUT)
        self.state.update(phase="running", message=game["title"] + " is playing. Close its window to come back.")
        self.publish()

    def tick(self):
        if self.game is not None and self.game.poll() is not None:
            code = self.game.returncode
            self.cleanup()
            self.state.update(phase="idle" if code == 0 else "error",
                              message="Welcome back. Pick your next game." if code == 0 else "The game closed unexpectedly. You can try again.")
        elif self.helper is not None and self.helper.poll() is not None:
            self.cleanup()
            self.state.update(phase="error", message="The Wii reader closed. Open the game again to reconnect it.")
        request_path = self.session / "request.json"
        if request_path.exists():
            try:
                if request_path.stat().st_size > 2048:
                    raise ValueError("Library request is too large.")
                request = json.loads(request_path.read_text())
                if not isinstance(request, dict):
                    raise ValueError("Invalid library request.")
                self.state["request_id"] = request.get("request_id", "")
                if request.get("action") == "launch":
                    self.launch(request)
                elif request.get("action") == "stop":
                    self.cleanup()
                    self.state.update(phase="idle", message="Back to your games.")
                else:
                    raise ValueError("Unknown library action.")
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
                self.cleanup()
                self.state.update(phase="error", message=str(error))
            finally:
                request_path.unlink(missing_ok=True)
        self.publish()


def startup_status(phase):
    """Only the native app supplies this disposable, per-launch status path."""
    value = os.environ.get("COUCH_PLAYER_STARTUP")
    if value:
        path = Path(value)
        temporary = path.with_suffix(".tmp")
        temporary.write_text(json.dumps({"phase": phase}))
        temporary.replace(path)


def startup_ready(path):
    try:
        return path.stat().st_size <= 4096 and json.loads(path.read_text()).get("phase") == "ready"
    except (OSError, ValueError, AttributeError):
        return False


def publish_foreground(startup, library_pid, game_pid=None):
    """Give the native app the owned window to activate on a Dock/Finder reopen."""
    path = Path(startup).parent / "foreground.json"
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps({"pid": game_pid or library_pid, "library_pid": library_pid}))
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Existing Godot executable or .app")
    args = parser.parse_args()
    startup_status("checking")
    executable = resolve_godot(args.godot)
    startup_status("importing")
    imported = subprocess.run([executable, "--headless", "--editor", "--path", str(ROOT / "sdk"), "--quit"],
                              capture_output=True, text=True, timeout=60, env=clean_environment())
    if imported.returncode or "ERROR:" in imported.stderr:
        raise RuntimeError(imported.stdout + imported.stderr)
    # Logs survive this session; input snapshots are removed when each game closes.
    session = Path(tempfile.mkdtemp(prefix="couch-library-"))
    print("Library session/logs:", session, flush=True)
    host = LibraryHost(executable, session, xpad_builder=build_xpad_reader, xpad_available=xpad_connected)
    environment = clean_environment()
    environment["COUCH_LIBRARY_SESSION"] = str(session)
    environment["COUCH_LIBRARY_CATALOG"] = str(host.catalog_path)
    startup = os.environ.get("COUCH_PLAYER_STARTUP")
    if startup:
        environment["COUCH_PLAYER_STARTUP"] = startup
    ui = None
    def terminate_session(_signum, _frame):
        raise KeyboardInterrupt
    previous_handler = signal.signal(signal.SIGTERM, terminate_session)
    try:
        startup_status("opening")
        ui = subprocess.Popen([executable, "--path", str(ROOT / "sdk"), "res://launcher/library.tscn"], env=environment)
        opened_at = time.monotonic()
        ready = not startup
        foreground_pid = None
        while ui.poll() is None:
            if not ready:
                path = Path(startup)
                ready = startup_ready(path)
                if not ready and time.monotonic() - opened_at > 60:
                    raise RuntimeError("The library did not finish drawing within 60 seconds. Please try again.")
            host.tick()
            active_pid = host.game.pid if host.game is not None else ui.pid
            if startup and active_pid != foreground_pid:
                publish_foreground(startup, ui.pid, active_pid)
                foreground_pid = active_pid
            time.sleep(0.1)
        return ui.returncode
    finally:
        host.cleanup()
        stop(ui)
        signal.signal(signal.SIGTERM, previous_handler)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Could not open the library: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
