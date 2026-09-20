"""Local creator-project registry for the Game Player library.

Unsigned source projects only. Does not install a runtime or pack a release.
Override the registry path with COUCH_CREATOR_PROJECTS for tests.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import sys

from godot_tools import ROOT

FORMAT = 1
LOCAL_PREFIX = "local:"


def default_registry_path() -> Path:
    override = os.environ.get("COUCH_CREATOR_PROJECTS")
    if override:
        return Path(override)
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/GigaCouch/creator-projects.json"
    return Path.home() / ".local/share/GigaCouch/creator-projects.json"


def load_registry(path: Path | None = None) -> dict:
    path = path or default_registry_path()
    if not path.is_file():
        return {"format": FORMAT, "projects": []}
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return {"format": FORMAT, "projects": []}
    if not isinstance(data, dict) or not isinstance(data.get("projects"), list):
        return {"format": FORMAT, "projects": []}
    return data


def save_registry(data: dict, path: Path | None = None) -> Path:
    path = path or default_registry_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"format": FORMAT, "projects": data.get("projects") or []}
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n")
    temporary.replace(path)
    return path


def read_game_file(project: Path) -> dict | None:
    game_path = project / "couch.game.json"
    if not game_path.is_file() or game_path.stat().st_size > 8192:
        return None
    try:
        data = json.loads(game_path.read_text())
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict) or not isinstance(data.get("scene"), str):
        return None
    if not data["scene"].startswith("res://"):
        return None
    return data


def write_game_file(project: Path, title: str, game_id: str) -> dict:
    game_path = project / "couch.game.json"
    existing = read_game_file(project) or {}
    payload = {
        "format": FORMAT,
        "id": game_id,
        "title": title,
        "scene": existing.get("scene") or "res://examples/little_world/world.tscn",
        "players": existing.get("players") or "1–16 players",
        "description": existing.get("description") or "A Giga Couch 3D starter. Join with A / Cross.",
        "color": existing.get("color") or "8ce8be",
    }
    game_path.write_text(json.dumps(payload, indent=2) + "\n")
    return payload


def register_project(project: Path, title: str | None = None, game_id: str | None = None, path: Path | None = None) -> dict:
    project = project.resolve()
    if not (project / "project.godot").is_file():
        raise ValueError("That folder is not a Godot project.")
    game = read_game_file(project)
    slug = game_id or (game or {}).get("id") or project.name
    name = title or (game or {}).get("title") or project.name
    if not game:
        game = write_game_file(project, name, slug)
    else:
        game = write_game_file(project, name, slug)
    registry = load_registry(path)
    projects = [row for row in registry["projects"] if isinstance(row, dict) and Path(str(row.get("path", ""))) != project]
    projects.insert(0, {"id": slug, "title": name, "path": str(project)})
    registry["projects"] = projects[:32]
    save_registry(registry, path)
    return {"id": slug, "title": name, "path": str(project), "scene": game["scene"]}


def catalog_id(slug: str) -> str:
    if slug.startswith(LOCAL_PREFIX):
        return slug
    return LOCAL_PREFIX + slug


def merged_catalog(builtin: list, registry: dict | None = None) -> list:
    """Built-in samples first, then registered source projects (never replacing a sample id)."""
    registry = registry if registry is not None else load_registry()
    games = [dict(game) for game in builtin]
    used = {game["id"] for game in games}
    for row in registry.get("projects") or []:
        if not isinstance(row, dict):
            continue
        project = Path(str(row.get("path", "")))
        if not project.is_dir() or not (project / "project.godot").is_file():
            continue
        game = read_game_file(project) or {}
        slug = str(row.get("id") or game.get("id") or project.name)
        entry_id = catalog_id(slug)
        if entry_id in used or slug in used:
            continue
        used.add(entry_id)
        games.append({
            "id": entry_id,
            "title": str(row.get("title") or game.get("title") or project.name),
            "players": str(game.get("players") or "1–16 players"),
            "description": str(game.get("description") or "Your game."),
            "scene": str(game.get("scene") or "res://examples/little_world/world.tscn"),
            "color": str(game.get("color") or "8ce8be"),
            "project": str(project),
            "source": "creator",
        })
    return games


def launch_spec(game: dict) -> tuple[Path, str]:
    """Godot --path directory and main scene for a catalog row."""
    if game.get("project"):
        return Path(game["project"]), game["scene"]
    return ROOT / "sdk", game["scene"]
