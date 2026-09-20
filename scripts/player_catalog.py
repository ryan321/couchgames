"""Player shelf: samples, Hub projects, unsigned installs, profiles, save dirs.

Does not download a runtime or claim a synthetic fixture is playable.
"""
from __future__ import annotations
import json
import os
import sqlite3
import sys
from pathlib import Path

from creator_projects import catalog_id, load_registry, read_game_file
from godot_tools import ROOT

INSTALLED_PREFIX = "installed:"
DEFAULT_PROFILES = ("family", "guest")


def data_dir() -> Path:
    override = os.environ.get("COUCH_DATA_DIR")
    if override:
        return Path(override)
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/GigaCouch"
    return Path.home() / ".local/share/GigaCouch"


def player_state_path(root: Path | None = None) -> Path:
    return (root or data_dir()) / "player.json"


def load_player_state(root: Path | None = None) -> dict:
    path = player_state_path(root)
    if path.is_file():
        try:
            data = json.loads(path.read_text())
            if isinstance(data, dict) and isinstance(data.get("profiles"), list) and data.get("profile"):
                profiles = [str(name) for name in data["profiles"] if str(name)]
                if profiles:
                    profile = str(data["profile"])
                    if profile not in profiles:
                        profile = profiles[0]
                    return {"profile": profile, "profiles": profiles[:8]}
        except (OSError, ValueError):
            pass
    return {"profile": "family", "profiles": list(DEFAULT_PROFILES)}


def save_player_state(state: dict, root: Path | None = None) -> Path:
    path = player_state_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "profile": state.get("profile") or "family",
        "profiles": state.get("profiles") or list(DEFAULT_PROFILES),
    }
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n")
    temporary.replace(path)
    return path


def save_dir(game_id: str, profile: str | None = None, root: Path | None = None) -> Path:
    root = root or data_dir()
    who = "".join(ch for ch in (profile or "family") if ch.isalnum() or ch in "-_") or "family"
    slug = "".join(ch for ch in game_id if ch.isalnum() or ch in "-_") or "game"
    path = root / "saves" / who / slug
    path.mkdir(parents=True, exist_ok=True)
    return path


def pck_is_playable(path: Path) -> bool:
    """Godot 4 packs start with GDPC. Tiny unsigned fixtures are not playable."""
    try:
        if path.suffix.lower() != ".pck" or not path.is_file() or path.stat().st_size < 64:
            return False
        with path.open("rb") as handle:
            return handle.read(4) == b"GDPC"
    except OSError:
        return False


def current_target() -> str:
    machine = os.uname().machine if hasattr(os, "uname") else ""
    if sys.platform == "darwin":
        return "macos-aarch64" if machine in ("arm64", "aarch64") else "macos-x86_64"
    return "windows-x86_64"


def installed_games(root: Path | None = None) -> list:
    root = root or data_dir()
    database = root / "data" / "library.sqlite"
    if not database.is_file():
        return []
    target = current_target()
    try:
        connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
        connection.row_factory = sqlite3.Row
        rows = connection.execute(
            """SELECT game_id, release_id, title, version, relative_path
               FROM installed_releases WHERE active = 1 AND target = ?""",
            (target,),
        ).fetchall()
        connection.close()
    except sqlite3.Error:
        return []
    games = []
    for row in rows:
        content = root / row["relative_path"]
        pck = None
        if content.is_dir():
            packs = sorted(content.glob("*.pck"))
            pck = packs[0] if packs else None
        playable = bool(pck and pck_is_playable(pck))
        players = "1–16 players"
        description = "Unsigned local install."
        manifest = content / "release.json"
        if manifest.is_file():
            try:
                meta = json.loads(manifest.read_text())
                bounds = meta.get("players") or {}
                if isinstance(bounds, dict) and bounds.get("max"):
                    players = f"{bounds.get('min', 1)}–{bounds['max']} players"
                if meta.get("title"):
                    pass
            except (OSError, ValueError):
                meta = {}
        else:
            meta = {}
        if not playable:
            description = "Installed package record — not a playable Godot pack yet."
        games.append({
            "id": INSTALLED_PREFIX + row["game_id"],
            "title": row["title"],
            "players": players,
            "description": description,
            "scene": "",
            "color": "8ce8be",
            "source": "installed",
            "playable": playable,
            "reason": "" if playable else "This unsigned import has no playable Godot pack.",
            "content": str(content),
            "pck": str(pck) if pck else "",
            "release_id": row["release_id"],
            "version": row["version"],
        })
    return games


def creator_rows(builtin_ids: set, registry: dict | None = None) -> list:
    registry = registry if registry is not None else load_registry()
    games = []
    used = set(builtin_ids)
    for row in registry.get("projects") or []:
        if not isinstance(row, dict):
            continue
        project = Path(str(row.get("path", "")))
        game = read_game_file(project) or {}
        slug = str(row.get("id") or game.get("id") or project.name)
        entry_id = catalog_id(slug)
        if entry_id in used or slug in used:
            continue
        used.add(entry_id)
        present = project.is_dir() and (project / "project.godot").is_file()
        games.append({
            "id": entry_id,
            "title": str(row.get("title") or game.get("title") or project.name),
            "players": str(game.get("players") or "1–16 players"),
            "description": "Folder missing. Open it again from Creator Hub." if not present else str(game.get("description") or "Your game."),
            "scene": str(game.get("scene") or "res://examples/little_world/world.tscn"),
            "color": str(game.get("color") or "8ce8be"),
            "project": str(project),
            "source": "creator",
            "missing": not present,
            "playable": present,
            "reason": "" if present else "This project folder moved or was removed.",
        })
    return games


def shelf_catalog(builtin: list, registry: dict | None = None, root: Path | None = None) -> list:
    games = []
    used = set()
    for game in builtin:
        row = dict(game)
        row.setdefault("source", "sample")
        row.setdefault("playable", True)
        row.setdefault("missing", False)
        games.append(row)
        used.add(row["id"])
    for row in creator_rows(used, registry):
        games.append(row)
        used.add(row["id"])
    for row in installed_games(root):
        if row["id"] not in used:
            games.append(row)
            used.add(row["id"])
    return games
