"""Install Giga Couch brand assets into macOS app bundles. No downloads."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
BRAND = ROOT / "brand"
MARK = BRAND / "mark.png"
LOGO = BRAND / "logo.png"

# Apple iconutil names. Source is brand/mark.png (transparent mint couch).
ICON_SIZES = (
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
)


def require_brand():
    if not MARK.is_file() or not LOGO.is_file():
        raise RuntimeError(f"Brand PNGs missing under {BRAND} (need mark.png and logo.png).")


def plist_icon():
    return {"CFBundleIconFile": "AppIcon"}


def make_icns(destination: Path) -> Path:
    require_brand()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="gigacouch-iconset-") as temp:
        iconset = Path(temp) / "AppIcon.iconset"
        iconset.mkdir()
        for name, size in ICON_SIZES:
            result = subprocess.run(
                ["sips", "-z", str(size), str(size), str(MARK), "--out", str(iconset / name)],
                capture_output=True, text=True,
            )
            if result.returncode:
                raise RuntimeError(result.stderr.strip() or f"sips failed for {name}")
        result = subprocess.run(
            ["iconutil", "-c", "icns", "-o", str(destination), str(iconset)],
            capture_output=True, text=True,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or "iconutil failed")
    return destination


def install_into_app(contents: Path, icns: Path) -> None:
    require_brand()
    resources = contents / "Resources"
    resources.mkdir(parents=True, exist_ok=True)
    shutil.copy2(icns, resources / "AppIcon.icns")
    shutil.copy2(MARK, resources / "mark.png")
    shutil.copy2(LOGO, resources / "logo.png")
