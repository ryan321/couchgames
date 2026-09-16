#!/usr/bin/env python3
"""Open the local source-game library using the installed shared Godot runtime."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from godot_tools import ROOT, godot_environment, resolve_godot
from play_wii_native import build_reader

from game_catalog import CATALOG, GAMES


def clean_environment():
    environment = godot_environment()
    for name in ("COUCH_WII_NATIVE_STATE", "COUCH_WII_FLEET_DIR", "COUCH_LIBRARY_SESSION"):
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
    def __init__(self, executable, session, popen=subprocess.Popen, reader_builder=build_reader):
        self.executable = executable
        self.session = Path(session)
        self.popen = popen
        self.reader_builder = reader_builder
        self.game = self.helper = self.wii_session = self.log = None
        self.state = {"phase": "idle", "message": "Choose something to play.", "native_wii": sys.platform == "darwin"}
        self.publish()

    def publish(self):
        self.state["updated"] = time.time()
        path = self.session / "status.json"
        temporary = path.with_suffix(".tmp")
        temporary.write_text(json.dumps(self.state))
        temporary.replace(path)

    def cleanup(self):
        stop(self.game)
        stop(self.helper)
        self.game = self.helper = None
        if self.log:
            self.log.close()
            self.log = None
        if self.wii_session:
            self.wii_session.cleanup()
            self.wii_session = None

    def launch(self, request):
        if self.game is not None:
            return  # Only one active game; duplicate clicks never create another.
        game_id = request.get("game")
        mode = request.get("input", "standard")
        joycons = request.get("joycons", "separate")
        if not isinstance(game_id, str) or game_id not in GAMES or mode not in ("standard", "native-wii", "sdl-wii") or joycons not in ("separate", "paired"):
            raise ValueError("That game or controller setup is unavailable.")
        if mode == "native-wii" and sys.platform != "darwin":
            raise ValueError("The native Wii reader requires macOS.")
        game = GAMES[game_id]
        self.state.update(phase="starting", game=game_id, message="Opening " + game["title"] + "…")
        self.publish()
        environment = clean_environment()
        environment.update(godot_environment(mode != "standard", joycons))
        for name in ("COUCH_LIBRARY_SESSION", "COUCH_WII_NATIVE_STATE", "COUCH_WII_FLEET_DIR"):
            environment.pop(name, None)
        self.log = (self.session / "game.log").open("w")
        if mode == "native-wii":
            fleet = game_id == "pocket-rally"
            binary = self.reader_builder(fleet)
            self.wii_session = tempfile.TemporaryDirectory(prefix="couch-library-wii-")
            state_path = self.wii_session.name if fleet else str(Path(self.wii_session.name) / "state.json")
            environment["COUCH_WII_FLEET_DIR" if fleet else "COUCH_WII_NATIVE_STATE"] = state_path
            self.helper = self.popen([str(binary), state_path], stdout=self.log, stderr=subprocess.STDOUT, env=clean_environment())
        self.game = self.popen([self.executable, "--path", str(ROOT / "sdk"), game["scene"]],
                               cwd=ROOT, env=environment, stdout=self.log, stderr=subprocess.STDOUT)
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Existing Godot executable or .app")
    args = parser.parse_args()
    executable = resolve_godot(args.godot)
    imported = subprocess.run([executable, "--headless", "--editor", "--path", str(ROOT / "sdk"), "--quit"],
                              capture_output=True, text=True, timeout=60, env=clean_environment())
    if imported.returncode or "ERROR:" in imported.stderr:
        raise RuntimeError(imported.stdout + imported.stderr)
    # Logs survive this session; input snapshots are removed when each game closes.
    session = Path(tempfile.mkdtemp(prefix="couch-library-"))
    print("Library session/logs:", session, flush=True)
    host = LibraryHost(executable, session)
    environment = clean_environment()
    environment["COUCH_LIBRARY_SESSION"] = str(session)
    ui = None
    try:
        ui = subprocess.Popen([executable, "--path", str(ROOT / "sdk"), "res://launcher/library.tscn"], env=environment)
        while ui.poll() is None:
            host.tick()
            time.sleep(0.1)
        return ui.returncode
    finally:
        host.cleanup()
        stop(ui)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Could not open the library: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
