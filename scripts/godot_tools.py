"""Select an installed supported engine through the platform's own doctor."""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def godot_environment(wii=False, joycons="separate"):
    """Enable the experimental Wii driver only for the child engine process."""
    environment = os.environ.copy()
    # One horizontal Joy-Con per player by default. Pair mode is explicit at startup.
    environment["SDL_JOYSTICK_HIDAPI_COMBINE_JOY_CONS"] = "1" if joycons == "paired" else "0"
    environment["SDL_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS"] = "0"
    if wii:
        environment["SDL_JOYSTICK_HIDAPI_WII"] = "1"
        # Godot 4.7.2's SDL maps the bare Remote D-pad to a nonexistent hat.
        # Supply button mappings only for Nintendo's two Remote HIDAPI IDs.
        # Preserve caller mappings, with their entries last so they take priority.
        mappings = (ROOT / "sdk/addons/couchgames/wii_sdl_mappings.txt").read_text()
        mappings = "\n".join(line for line in mappings.splitlines() if line and not line.startswith("#"))
        environment["SDL_GAMECONTROLLERCONFIG"] = mappings + "\n" + environment.get("SDL_GAMECONTROLLERCONFIG", "")
    return environment


def resolve_godot(override=None):
    # The local player app supplies its bundled CLI, so Finder launches never build Rust.
    cli = os.environ.get("COUCH_CLI")
    command = [cli, "--json"] if cli else ["cargo", "run", "--quiet", "--locked", "-p", "couch-cli", "--", "--json"]
    if override:
        command += ["--godot", override]
    command += ["doctor", "--require-godot"]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=300)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return json.loads(result.stdout)["data"]["godot"]["executable"]
