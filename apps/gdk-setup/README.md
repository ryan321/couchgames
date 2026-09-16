# Native GDK setup — macOS preview

A standalone AppKit application opens before Godot is installed. It checks the editor through the bundled Rust `couch doctor`, installs a small versioned creator kit, and starts the Godot Creator Hub. The Hub creates independent Little World-based 3D projects and opens them in the editor or as source playtests.

## Build and run

From the repository root, with an existing Rust toolchain, Python 3 and Xcode/Command Line Tools:

```sh
python3 scripts/build_gdk.py
open '.couchgames/gdk/Couch Games GDK Setup.app'
```

The first build targets **macOS Apple Silicon**, with a macOS 13 deployment target. Other Mac versions and Windows are not qualified. The script builds the existing CLI with `cargo build --locked`, compiles the small native front end with Swift/AppKit/CryptoKit, and produces:

- `.couchgames/gdk/Couch Games GDK Setup.app`
- `.couchgames/gdk/CouchGames-GDK-0.1.0-preview.1-macos-arm64.zip`
- Its `.zip.sha256` checksum.

No engine, export template, compiler or toolchain is installed. The built app needs neither Cargo nor Python on the recipient's machine. `--skip-build` repackages existing binaries during development. Generated binaries/archives remain under the existing ignored `.couchgames/` directory. No GitHub Actions workflow is added.

## Creator flow

1. Setup detects a compatible editor using the existing shared policy. **Choose Godot** supports custom locations; **Detect automatically** clears the saved manual selection. The existing `COUCH_GODOT` environment override still takes precedence over normal discovery.
2. If absent, wrong or unusable, setup displays the problem and enables the pinned official **Download Godot** page. This is guided manual editor installation, not automatic downloading. Extract the standard editor and choose it afterward. Existing incompatible editors remain untouched.
3. Choose a parent folder and select **Install GDK**. The default is `~/Library/Application Support/CouchGames/GDK/<version>`; no administrator permission is needed.
4. Select **Open Creator Hub**. It verifies the installed kit, rechecks Godot, imports the small Hub project, then starts it in a separate process.
5. **New 3D game** copies a starter and its SDK into a new project folder. Open it in Godot once for import, then run it from the editor or Hub. Existing projects can be added to the recent list by selecting their `project.godot`.
6. Reopen the installed `Couch Games Creator.app` to return. It uses the native setup screen when an editor needs attention; otherwise it opens the Hub automatically.

The bundled offline guide is `docs/index.html`. Hub startup diagnostics go to the installed kit's `logs/creator-hub.log`. Project sources live wherever the creator chooses, independently of the kit.

## Installation behavior

`SetupCore.swift` validates a bounded `kit.json` inventory, paths, file sizes and SHA-256 hashes. It rejects source symlinks, traversal, duplicate paths and damaged payloads. It checks disk space, copies only declared files into a sibling staging directory, verifies the copy, and renames the completed directory into place. Failure removes that attempt's staging directory. Identical reinstall verifies and reuses the existing version; a changed or damaged destination fails without overwriting user files. New versions install alongside older ones.

These integrity checks are not a signature or sandbox guarantee. The destination is a user-owned local directory; hostile concurrent modification by processes with the same user permissions is outside this preview's protection. Sudden power loss can leave a staging directory. The installer does not silently repair or replace modified SDK source.

Godot's generated `.godot/` caches and Hub logs are not shipped. The kit includes a prebuilt CLI, the addon, the small 3D starter, native launcher and Hub, an offline guide, and creator instructions. Large game assets, Blender files, credentials, test fixtures and engine binaries are excluded by an explicit packaging allowlist.

## Tests

```sh
python3 scripts/test_gdk.py
# Optional: retain the test installation for UI review.
python3 scripts/test_gdk.py --keep /tmp/couch-gdk-review
```

The test command requires the already-installed supported editor and local Swift tools. It runs native tests for staging/reinstall, conflict preservation, bad paths, tampering, symlinks, missing/unsupported engine diagnostics, literal executable paths and process timeout. Synthetic engine fixtures only test setup behavior, not playability. It then installs the real bundle outside the checkout, tests Hub project creation/no-overwrite/cleanup, imports and runs the created 3D project in real Godot, and checks the installed launcher's ad-hoc signature.

The recipient needs none of these test/build tools. The installed creator experience itself invokes only the bundled CLI, system frameworks and the selected Godot executable.

## Verification performed

On this macOS ARM64 machine, 15 native installer assertions and eight real-engine project/Hub assertions passed. A fresh kit installed outside the checkout; a generated standalone project imported and ran in Godot 4.7.2. Native UI review exercised missing-editor guidance, automatic reuse, installation and setup-to-Hub handoff. Creating a project through the Hub and opening its editor also worked. The final installed launcher passed ad-hoc signature verification, and the bundled CLI ran with Cargo/Python absent from PATH. No additional engine or export templates were downloaded. These checks do not establish clean-machine, minimum-OS, physical-controller or public-distribution qualification.

## Limits

This is an **internal developer preview**, ad-hoc signed for local testing. Developer ID signing/notarization, a public code license and complete dependency-notice review are release work; do not present the ZIP as a public production installer. It is not a player-platform installer.

The Hub currently provides source project creation/opening/play, not packaged-game supervision. Generalized saves/lifecycle/lobby, the 2D starter, game packaging, private sharing, automatic Godot downloads, and Windows setup remain planned. The native Wii helper is not bundled. Physical controllers/TVs, clean recipient machines and the declared minimum OS need separate acceptance testing.
