#!/usr/bin/env python3
"""Player shelf catalog tests. No Godot, no downloads."""
from pathlib import Path
import tempfile
import unittest

from player_catalog import pck_is_playable, save_dir, shelf_catalog


class PlayerCatalogTests(unittest.TestCase):
    def test_tiny_pck_is_not_playable(self):
        with tempfile.TemporaryDirectory() as directory:
            pack = Path(directory) / "fixture.pck"
            pack.write_bytes(b"not a godot pack" * 2)
            self.assertFalse(pck_is_playable(pack))
            pack.write_bytes(b"GDPC" + b"\x00" * 80)
            self.assertTrue(pck_is_playable(pack))

    def test_save_dir_is_per_profile_and_game(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            family = save_dir("little-world", "family", root)
            guest = save_dir("little-world", "guest", root)
            self.assertNotEqual(family, guest)
            self.assertTrue(str(family).endswith("family/little-world"))
            self.assertTrue(family.is_dir())

    def test_missing_creator_project_stays_on_shelf(self):
        with tempfile.TemporaryDirectory() as directory:
            registry = Path(directory) / "creator-projects.json"
            registry.write_text('{"format":1,"projects":[{"id":"gone","title":"Gone","path":"/nope"}]}')
            import os
            os.environ["COUCH_CREATOR_PROJECTS"] = str(registry)
            os.environ["COUCH_DATA_DIR"] = directory
            try:
                catalog = shelf_catalog([], root=Path(directory))
            finally:
                os.environ.pop("COUCH_CREATOR_PROJECTS", None)
                os.environ.pop("COUCH_DATA_DIR", None)
            self.assertEqual(catalog[0]["id"], "local:gone")
            self.assertTrue(catalog[0]["missing"])
            self.assertFalse(catalog[0]["playable"])


if __name__ == "__main__":
    unittest.main()
