#!/usr/bin/env python3
"""Registry merge tests; no Godot, no downloads."""
import json
from pathlib import Path
import tempfile
import unittest

from creator_projects import (
    LOCAL_PREFIX,
    catalog_id,
    launch_spec,
    load_registry,
    merged_catalog,
    register_project,
    write_game_file,
)
from godot_tools import ROOT


class RegistryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.registry = Path(self.temp.name) / "creator-projects.json"

    def tearDown(self):
        self.temp.cleanup()

    def _project(self, name="my-game"):
        root = Path(self.temp.name) / name
        root.mkdir()
        (root / "project.godot").write_text("[application]\nconfig/name=\"Demo\"\n")
        write_game_file(root, "Demo", name)
        return root

    def test_register_and_merge_does_not_replace_samples(self):
        project = self._project()
        register_project(project, title="Demo", game_id="my-game", path=self.registry)
        builtin = [{"id": "little-world", "title": "Little World", "scene": "res://a.tscn", "color": "aaa"}]
        catalog = merged_catalog(builtin, load_registry(self.registry))
        self.assertEqual(catalog[0]["id"], "little-world")
        self.assertEqual(catalog[1]["id"], catalog_id("my-game"))
        self.assertTrue(catalog[1]["id"].startswith(LOCAL_PREFIX))
        path, scene = launch_spec(catalog[1])
        self.assertEqual(path.resolve(), project.resolve())
        self.assertTrue(scene.startswith("res://"))
        sample_path, _ = launch_spec(catalog[0])
        self.assertEqual(sample_path, ROOT / "sdk")

    def test_missing_project_skipped_by_source_merge(self):
        self.registry.write_text(json.dumps({"format": 1, "projects": [{"id": "gone", "title": "Gone", "path": "/nope"}]}))
        catalog = merged_catalog([], load_registry(self.registry))
        self.assertEqual(catalog, [])

    def test_refuse_non_godot_folder(self):
        empty = Path(self.temp.name) / "empty"
        empty.mkdir()
        with self.assertRaises(ValueError):
            register_project(empty, path=self.registry)


if __name__ == "__main__":
    unittest.main()
