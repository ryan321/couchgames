"""Select an installed supported engine through the platform's own doctor."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def resolve_godot(override=None):
    command = ["cargo", "run", "--quiet", "--locked", "-p", "couch-cli", "--", "--json"]
    if override:
        command += ["--godot", override]
    command += ["doctor", "--require-godot"]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=300)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return json.loads(result.stdout)["data"]["godot"]["executable"]
