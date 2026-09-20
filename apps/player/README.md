# Giga Couch player app — local macOS preview

Double-click **Giga Couch.app** on the Desktop to open the game library. This is separate from **Giga Couch Creator.app** and **Giga Couch Setup.app**.

```sh
python3 scripts/build_player.py --desktop
```

The build uses existing Rust, Swift and Python tools. It creates `.gigacouch/player/Giga Couch.app`, ad-hoc signs it and optionally creates the Desktop shortcut. The Dock/app icon is `brand/mark.png`. No engine, export templates or toolchains are downloaded. An existing unrelated Desktop item is preserved.

The native entry point checks supported Godot with its bundled doctor CLI, then starts **`couch host`**. That host opens the TV library, merges sample games, Hub projects, and unsigned SQLite installs, and sets per-profile save directories. Opening the app needs no Terminal, Cargo, or Python. `python3 scripts/library.py` remains available for development tests. This preview still uses the installed Godot **editor** as the runtime; it does not bundle a player-only engine or play synthetic package fixtures. Its navy-and-mint loading window stays visible with an animated indicator and stage updates through engine checks, resource preparation and library startup. The library signals readiness after rendering; simply starting its process does not dismiss the loading window. A startup failure shows a native error, and a library that never signals readiness times out after 60 seconds. Library navigation, game launching and return behavior remain as described in [library controls](../../sdk/launcher/README.md). Reopening the Desktop app or clicking its Dock icon brings the existing library or active game forward. A minimized library is restored; reopening does not start a duplicate session. Quit the library to end the session, or quit Giga Couch from its Dock menu; the supervisor cleans up its game and Wii helper.

This local preview records the checkout and Python paths at build time and reuses the existing source games to avoid duplicating large assets. Rebuild after moving the checkout/Python. It is not a portable or notarized player release. The full SQLite-backed library, accounts and social features remain planned. Standard gamepads navigate the existing library; native Wii navigation is still limited to games.

Startup diagnostics: `~/Library/Logs/GigaCouch/player.log`. It includes the session-directory path for game logs. Missing Godot or moved paths produce a native error dialog.

Verification: all 11 `python3 scripts/test_library.py` tests passed, including startup phases, malformed/missing readiness and session isolation. `python3 scripts/test_sdk.py` passed against the installed Godot. The persistent loading window and transition to the rendered library were visually checked. Minimizing the library and double-clicking the Desktop shortcut restored the existing window; foreground process routing also has a synthetic regression test. Native launch, game launch/return, and quit cleanup are manually checked against the already-installed Godot; physical-controller qualification is separate.
