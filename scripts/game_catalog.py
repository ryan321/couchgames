"""Shared catalog of checked-in playable source examples."""
import json
from godot_tools import ROOT
CATALOG = json.loads((ROOT / "sdk/launcher/games.json").read_text())
GAMES = {game["id"]: game for game in CATALOG}


def rendering_arguments(game_id, *, compatibility=False):
    """Select only the renderer declared by this game; share the installed engine."""
    import sys
    if compatibility or GAMES[game_id].get("renderer") != "forward_plus":
        return []
    arguments = ["--rendering-method", "forward_plus"]
    if sys.platform == "darwin":
        arguments += ["--rendering-driver", "metal"]
    return arguments
