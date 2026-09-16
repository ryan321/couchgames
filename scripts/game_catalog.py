"""Shared catalog of checked-in playable source examples."""
import json
from godot_tools import ROOT
CATALOG = json.loads((ROOT / "sdk/launcher/games.json").read_text())
GAMES = {game["id"]: game for game in CATALOG}
