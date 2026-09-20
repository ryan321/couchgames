#!/usr/bin/env python3
"""Brand asset and macOS icon packaging checks. No downloads."""
from pathlib import Path
import plistlib
import tempfile
import unittest

from branding import BRAND, LOGO, MARK, install_into_app, make_icns, plist_icon, require_brand


class BrandingTests(unittest.TestCase):
    def test_source_pngs_exist(self):
        require_brand()
        self.assertGreater(MARK.stat().st_size, 1024)
        self.assertGreater(LOGO.stat().st_size, 1024)
        self.assertEqual(MARK.parent, BRAND)

    def test_godot_and_docs_copies(self):
        root = MARK.parents[1]
        self.assertEqual((root / "sdk/launcher/mark.png").read_bytes(), MARK.read_bytes())
        self.assertEqual((root / "apps/creator-hub/mark.png").read_bytes(), MARK.read_bytes())
        self.assertEqual((root / "apps/gdk-setup/docs/logo.png").read_bytes(), LOGO.read_bytes())

    def test_icns_and_app_resources(self):
        with tempfile.TemporaryDirectory(prefix="gigacouch-brand-") as temp:
            icns = Path(temp) / "AppIcon.icns"
            make_icns(icns)
            self.assertGreater(icns.stat().st_size, 1024)
            self.assertEqual(icns.read_bytes()[:4], b"icns")
            contents = Path(temp) / "Fake.app" / "Contents"
            (contents / "MacOS").mkdir(parents=True)
            install_into_app(contents, icns)
            resources = contents / "Resources"
            self.assertTrue((resources / "AppIcon.icns").is_file())
            self.assertEqual((resources / "mark.png").read_bytes(), MARK.read_bytes())
            self.assertEqual((resources / "logo.png").read_bytes(), LOGO.read_bytes())
            self.assertEqual(plist_icon()["CFBundleIconFile"], "AppIcon")


if __name__ == "__main__":
    unittest.main()
