# Giga Couch brand assets

Source artwork for the macOS apps. Do not put USB or game code here.

| File | Use |
| --- | --- |
| `mark.png` | App icon and dark UI (Game Player splash, Setup rail, library, Creator Hub). Transparent mint couch. |
| `logo.png` | Wordmark for light surfaces (offline first-game guide). Navy type plus mark. |

`scripts/branding.py` builds `AppIcon.icns` from `mark.png` during `build_player.py` and `build_gdk.py`. Godot projects keep a copy of the mark next to their scenes so `res://` loads work.
