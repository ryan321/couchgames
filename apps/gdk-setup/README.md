# Native GDK setup — macOS preview

A standalone AppKit application opens before Godot is installed. It checks the editor through the bundled Rust `couch doctor`, installs a small versioned creator kit, and starts the Godot Creator Hub. The Hub creates independent Little World-based 3D projects and opens them in the editor or as source playtests.

## Build and run

From the repository root, with an existing Rust toolchain, Python 3 and Xcode/Command Line Tools:

```sh
python3 scripts/build_gdk.py
open '.gigacouch/gdk/Giga Couch GDK Setup.app'
```

The first build targets **macOS Apple Silicon**, with a macOS 13 deployment target. Other Mac versions and Windows are not qualified. The script builds the existing CLI with `cargo build --locked`, compiles the small native front end with Swift/AppKit/CryptoKit, installs the couch mark as the app icon, and produces:

- `.gigacouch/gdk/Giga Couch GDK Setup.app`
- `.gigacouch/gdk/GigaCouch-GDK-0.1.0-preview.4-macos-arm64.zip`
- Its `.zip.sha256` checksum.

No engine, export template, compiler or toolchain is installed. The built app needs neither Cargo nor Python on the recipient's machine. `--skip-build` repackages existing binaries during development. Generated binaries/archives remain under the existing ignored `.gigacouch/` directory. No GitHub Actions workflow is added.

## Creator flow

The native setup uses a dark studio layout with separate editor and kit cards. Each compares **You need** with **On this Mac**; readiness badges, installation size, free disk space and one primary next action make the remaining steps visible.

1. Setup detects a compatible editor using the existing shared policy. **Choose editor** supports custom locations; **Check again** clears the saved manual selection. The existing `COUCH_GODOT` environment override still takes precedence over normal discovery.
2. If absent, wrong or unusable, setup displays the problem and enables the pinned official **Get Godot** page. This is guided manual editor installation, not automatic downloading. Extract the standard editor and choose it afterward. Existing incompatible editors remain untouched.
3. Choose a parent folder and select **Install GDK**. The default is `~/Library/Application Support/GigaCouch/GDK/<version>`; no administrator permission is needed.
4. Select **Open Creator Hub**. It verifies the installed kit, rechecks Godot, imports the small Hub project, then starts it in a separate process.
5. **New 3D game** copies a starter and its SDK into a new project folder. Open it in Godot once for import, then run it from the editor or Hub. Existing projects can be added to the recent list by selecting their `project.godot`.
6. Reopen the installed `Giga Couch Creator.app` to return. It uses the native setup screen when an editor needs attention; otherwise it opens the Hub automatically.

The bundled offline guide is `docs/index.html`. Hub startup diagnostics go to the installed kit's `logs/creator-hub.log`. Project sources live wherever the creator chooses, independently of the kit.

## AI coding assistant

The optional agent card checks Codex, Claude Code, Grok, Kiro and Cursor CLI version commands in PATH and common per-user locations (including Finder launches without a shell PATH). It distinguishes Grok’s `agent` alias from Cursor. Detection means a runnable CLI was found, not that its account, subscription or game-authoring behavior was verified.

**Choose an agent** opens a native picker. Close it with the top-right **×**, **Done**, or **Esc**; closing is disabled while an installation/check is in progress. A detected CLI can be selected; **I already have an agent** records a creator-confirmed external/editor/desktop workflow without requiring a CLI. Either choice persists in setup preferences. AI setup never blocks kit installation or Creator Hub.

For an absent CLI, **Install agent** first shows its official source. **Download & install** fetches that fixed HTTPS vendor script, then runs its documented shell installer in the background. Setup waits, reports errors, and probes again before claiming the CLI is detected. It does not install all agents or run installs during detection/builds/tests. Vendor installers control their files, updates and shell-profile changes. Sign-in, provider terms and billing remain with the provider; setup does not collect AI credentials or launch a coding session.

Installation sources checked September 16, 2026:

- [Codex CLI](https://developers.openai.com/codex/cli/): standalone installer, no npm/Homebrew prerequisite.
- [Claude Code](https://code.claude.com/docs/en/setup): native installer.
- [Grok](https://docs.x.ai/build/overview): official CLI installer.
- [Kiro](https://kiro.dev/downloads/): official CLI installer.
- [Cursor CLI](https://cursor.com/docs/cli/installation): official CLI installer.

The installer catalog is maintained in `macos/AgentCore.swift`. Kiro is the provisional interpretation of the requested “kik”; other agents remain usable through the existing-agent choice. Preferred-agent selection is setup metadata, not an embedded chat integration or a launcher for agent sessions.

## Installation behavior

`SetupCore.swift` validates a bounded `kit.json` inventory, paths, file sizes and SHA-256 hashes. It rejects source symlinks, traversal, duplicate paths and damaged payloads. It checks disk space, copies only declared files into a sibling staging directory, verifies the copy, and renames the completed directory into place. Failure removes that attempt's staging directory. Identical reinstall verifies and reuses the existing version; a changed or damaged destination fails without overwriting user files. New versions install alongside older ones. Setup remembers the chosen parent folder, detects and verifies an existing copy before offering to open Creator Hub, and shows other installed versions when the current kit is absent. A modified or conflicting kit is marked as needing attention and must be installed elsewhere; it is never silently overwritten.

These integrity checks are not a signature or sandbox guarantee. The destination is a user-owned local directory; hostile concurrent modification by processes with the same user permissions is outside this preview's protection. Sudden power loss can leave a staging directory. The installer does not silently repair or replace modified SDK source.

Godot's generated `.godot/` caches and Hub logs are not shipped. The kit includes a prebuilt CLI, the addon, the small 3D starter, native launcher and Hub, an offline guide, and creator instructions. Large game assets, Blender files, credentials, test fixtures and engine binaries are excluded by an explicit packaging allowlist.

## Tests

```sh
python3 scripts/test_gdk.py
# Optional: retain the test installation for UI review.
python3 scripts/test_gdk.py --keep /tmp/couch-gdk-review
```

Agent tests use synthetic executables and injected download/installer responses. They cover discovery, a failed probe, the Grok/Cursor alias collision, fixed-source installation sequencing and download failures; they never download a real agent.

The test command requires the already-installed supported editor and local Swift tools. It runs native tests for absent/existing/older/damaged kit detection, staging/reinstall, conflict preservation, bad paths, tampering, symlinks, missing/unsupported engine diagnostics, literal executable paths and process timeout. Synthetic engine fixtures only test setup behavior, not playability. It then installs the real bundle outside the checkout, tests Hub project creation/no-overwrite/cleanup, imports and runs the created 3D project in real Godot, and checks the installed launcher's ad-hoc signature.

The recipient needs none of these test/build tools. The installed creator experience itself invokes only the bundled CLI, system frameworks and the selected Godot executable.

## Verification performed

On this macOS ARM64 machine, 28 native installer assertions and eight real-engine project/Hub assertions passed. A fresh kit installed outside the checkout; a generated standalone project imported and ran in Godot 4.7.2. Native UI review exercised missing-editor guidance, automatic reuse, installation and setup-to-Hub handoff. Creating a project through the Hub and opening its editor also worked. The final installed launcher passed ad-hoc signature verification, and the bundled CLI ran with Cargo/Python absent from PATH. The redesigned setup and agent picker were visually reviewed, including detected/missing agents and cancellation before download. Live vendor installation and provider sign-in remain untested; existing Codex, Claude Code and Grok CLIs were detected on this Mac. No additional agents, engine or export templates were downloaded. These checks do not establish clean-machine, minimum-OS, physical-controller or public-distribution qualification.

## Limits

This is an **internal developer preview**, ad-hoc signed for local testing. Developer ID signing/notarization, a public code license and complete dependency-notice review are release work; do not present the ZIP as a public production installer. It is not a player-platform installer.

The Hub currently provides source project creation/opening/play, not packaged-game supervision. Generalized saves/lifecycle/lobby, the 2D starter, game packaging, private sharing, automatic Godot downloads, and Windows setup remain planned. The native Wii helper is not bundled. Physical controllers/TVs, clean recipient machines and the declared minimum OS need separate acceptance testing.
