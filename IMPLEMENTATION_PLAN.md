# V1 Implementation Plan

This is the execution checklist for [TECH_STACK.md](TECH_STACK.md). V1 is complete when a creator can build a Godot game, integrate our SDK, play it from the couch, and privately share it with another player.

## Current constraints

- The user authorized the standard Godot 4.7.2 editor for development and dogfooding. Do not install export templates or additional runtime versions implicitly; disk space remains limited.
- Do not automatically install toolchains or download runtimes from build scripts, tests, or CLI commands.
- Keep Rust debug symbols and incremental compilation disabled to limit disk use.
- Develop engine-independent components and run the source sample locally. Physical controller hardware, shared PCK execution, other OS targets, and sandbox validation remain separate required checks.
- Neon is our server database. SQLite and save files live on player computers.
- A TV uses a direct display connection or an existing screen-sharing setup. V1 does not build a streaming system.

## First implementation slice: local package library

Build a real, testable content path without executing any game code:

```text
Local manifest + exported PCK
  -> validate metadata and artifact bytes
  -> select target OS/architecture
  -> stage and verify copied content
  -> install immutable release
  -> activate in SQLite
  -> list installed library
```

The initial package contract is provisional until shared-runtime feasibility is demonstrated. Test packages contain synthetic bytes; accepting them proves the content-management path, not Godot compatibility or game safety.

### Deliverables

- [x] Rust workspace with small build profiles and a dependency lockfile.
- [x] Manifest v1 types and JSON Schema, with bounded fields and portable identifiers.
- [x] Streaming SHA-256 and byte-size checks; reject unsafe paths and non-regular artifact files.
- [x] SQLite migration for immutable installed releases and one active release per game/target.
- [x] Staged local installation, idempotent retry, immutable-release conflict detection, and preservation of the previous active release on failure.
- [x] CLI: `doctor`, `validate`, `install`, and `library`, with structured operational JSON output.
- [x] Tests for invalid packages, simulated interrupted/retried installation, update failures, persistence, and CLI behavior.
- [x] Manually dispatched Windows/macOS/Linux checks that do not install Godot; push/pull-request triggers removed at user request. Remote runs remain pending.
- [x] README with a small, explicitly non-playable fixture workflow.

Unsigned local imports are developer tooling only. They do not authorize public or private distribution. This slice does not download, install, or launch a runtime.

Verified locally on macOS ARM64 with Rust 1.97.1: 21 tests passed; formatting and Clippy passed. This does not verify other operating systems, actual PCK compatibility, abrupt power-loss recovery, game execution, or sandboxing. See the README for the current guarantees and limits.

## Subsequent milestones

### Runtime detection and SDK onboarding

- [x] Shared policy for standard official Godot 4.7.2 stable, embedded by Rust and read by GDScript.
- [x] Host discovery through explicit path, environment, PATH, and common application locations.
- [x] Missing, unsupported, and unusable states with setup instructions; `doctor --require-godot` for readiness gating.
- [x] Bounded version probes; explicit override precedence; tests for failure, timeout, and selecting a supported installation.
- [x] SDK autoload and editor status panel using the same version policy.
- [x] Explicit SDK test runner that selects Godot through our own doctor command.
- [x] Dogfood missing → installation → supported on this Mac, then run the real SDK checks.

This is a development-engine version check, not certification of the final shared distribution runtime, its signature, or its sandbox.

Dogfood result: the host first reported a missing engine with setup instructions. The official standard macOS archive was verified against its release SHA-256, its app signature was verified, and Godot was installed in the user's Applications directory. Auto-discovery then selected `4.7.2.stable.official.ed1daf0bf` without a path override. The SDK editor plugin imported successfully and seven shared compatibility cases plus the real-engine check passed. The exercise exposed a short first-start timeout and JSON number formatting mismatch; both were addressed. Export templates were not installed.

Verification after this slice: 31 Rust tests passed on macOS ARM64, along with formatting and Clippy. Engine-backed SDK checks passed separately through `scripts/test_sdk.py`. Remote CI and real Windows engine discovery are not yet verified.

### 0. Shared runtime and OS feasibility — engine validation pending

1. Select exact Godot release/build flags and supported Windows/macOS targets.
2. Export two tiny projects plus the launcher and reuse one installed runtime to run them.
3. Prototype the desktop host, readiness handshake, crash recovery, and return to launcher.
4. Demonstrate OS isolation for PCK access, GPU/audio/controllers, restricted communication, scratch storage, and per-game saves.

**Exit:** both games run from the same installed engine on each supported OS, a crash returns to the launcher, and adversarial tests demonstrate the access boundary. Until then, avoid claims that game distribution is safe or that PCKs work across targets.

### 1. SDK and sixteen-player sample

1. GDScript addon, `Platform` autoload, starter project, and documented API.
2. Per-player input state; join, leave, disconnect removal, and fresh rejoin flow.
3. Action remapping, analog dead zones, glyph fallback, and basic rumble.
4. Controller-driven menus, pause, TV-safe layout, and quit-to-platform.
5. Asynchronous local save/load with explicit errors, atomic replacement, and schema migration hooks.

**Exit:** sixteen independent controllers can complete a session, reconnect without stealing another player's slot, and restore a saved game. Wireless Xbox, PlayStation, and mixed groups are required hardware test cases. Check direct TV output and one screen-sharing setup.

#### Little World: first playable slice

- [x] A 3D island with original procedural characters, steps, platforms, a shared camera, movement, jumping, and fall recovery.
- [x] Sixteen player slots in the SDK, package validator, and JSON Schema.
- [x] Device-isolated left-stick/D-pad movement, radial dead zone, and mapped south-button jump (Xbox A / PlayStation Cross).
- [x] Join, hold-to-leave, immediate character/slot removal on disconnect, and one-button rejoin; keyboard fallback uses one of the same sixteen slots.
- [x] Clear held input on focus loss/disconnect; normalize diagonal movement.
- [x] Source-project launch through the platform's installed-engine discovery; no export template downloads.
- [x] Engine-backed synthetic routing tests and actual scene/physics tests; rendered visual inspection on this Mac.
- [x] Wireless setup instructions and a hardware test matrix with untested cases marked pending.
- [x] Maximized startup, 16:9 scaling, and keyboard/controller/button fullscreen toggle; native maximized → fullscreen → maximized verified on this Mac.
- [x] Roku/AirPlay window-sharing instructions using the existing OS flow. Actual TV compatibility, window selection, and latency still need a physical test.
- [x] Experimental Wii family action profiles, per-device F3 layout selection, explicit SDL driver startup, and scoped bare-Remote D-pad mappings; 53 synthetic profile assertions pass.
- [x] Install and open the small Wii pairing helper on this Mac after the Remote Plus hit the standard Bluetooth PIN prompt; archive digest and bundle signature checked. Release, local diagnostic, and game-closed pairing attempts failed; Bluetooth compatibility is a recorded blocker for this Mac/Remote Plus setup.
- [x] User-confirmed movement/jump with one `04e8:7021` Remote via the native macOS report reader. Saved `play_wii_native.py` with private session state and SDK input expiry handling; broader hardware coverage remains pending.
- [x] Cloudbound single-pilot 3D flight sample, native acceleration decoding, factory/approximate scaling, steady-pose calibration, and pause on stale motion. Native compilation, C protocol fixtures, 34 synthetic motion/game assertions, and rendered capture passed. Saved launcher received live motion and factory calibration on this Mac; user confirmed flight, then requested sideways steering and away-to-dive after reporting reversed banking. User confirmed revised sideways flight controls; reconnect acceptance pending.
- [x] Shared Godot controller motion adapter and Cloudbound per-player motion, original Joy-Con separate/paired modes, Switch/Pro family profiles, and explicit stick fallback. 61 synthetic adapter/profile/game assertions pass; Switch hardware qualification pending.
- [x] Pocket Rally standalone 3D car game: 1–16 local players, adaptive split-screen chase cameras, per-driver Wii tilt calibration, acceleration/brake/reverse, collisions, checkpoints, and disconnect/rejoin handling. Driving-only native helper supplies sixteen independent observed-variant channels; Cloudbound source and its original reader preserved. Synthetic scene/input checks and rendered 2/4/16-view inspection passed; physical driving and multi-Remote qualification pending.
- [ ] Switch 2 runtime/driver integration and hardware qualification; profile recognition alone is not support. See `docs/switch-controllers.md`.
- [ ] Physical Wii Remote/Plus, Nunchuk, Classic/Pro, and Wii U Pro pairing, driver mapping, reconnect, and mixed-controller tests; integrate verified setup into the desktop host.
- [ ] Specialty Wii accessories, GameCube adapters, Wii U GamePad connection path, motion/IR APIs, and third-party variants. Track individually in `docs/wii-controllers.md`.
- [ ] Physical wireless Xbox, PlayStation, and mixed-controller sessions at 1, 2, 4, 8, and 16 players.
- [ ] Full pause/menu, remapping, haptics, persistence, host lifecycle, and packaged launch.

Verified locally on macOS ARM64: 32 Rust tests, formatting, Clippy, eight runtime checks, 557 synthetic input assertions, 53 Wii profile assertions, 16 native-reader assertions, and 31 headless scene/physics assertions passed. A rendered run passed the same scene tests plus screenshot capture. This validates source-game behavior, not physical wireless connections or a packaged distribution runtime.

### 2. Desktop library and runtime management

- [x] Godot library screen for the source games, mouse/keyboard/standard gamepad navigation, controller setup options, separate game processes, Wii helper selection/cleanup, and return-to-library with selected card restoration. Development Python supervisor reuses the existing Rust runtime doctor. UI/process tests and real headless launches for all three games passed on this Mac.
- [x] Add single-player World 1-1 recreation with original captured NES artwork, tile layout, item/enemy mechanics, underground room, flag/castle completion, and SDK input. Source provenance and deviations documented; game and library checks pass with synthetic input, rendered views inspected, physical playthrough/frame comparison pending. Four-game library uses a 2×2 card layout and all launchers share one catalog. Jump tuning after user feedback increases standing/running height and short-hop height; tests cover all pipe heights without the run button and overhead block hits.
- [x] Gauntlet-inspired first dungeon, The Ember Vault: shared-screen 1–16 local heroes, four selectable classes, enemies/generators, ranged combat/magic, two keyed doors, shared supplies, ally revival, team exit, results/retry, pause/focus recovery, and native Wii fleet integration. Full solo/16-player simulated playthroughs and controller/lifecycle checks pass; rendered game/library inspected. Library now scrolls to accommodate five games. Flying/driving game sources preserved. Physical Gauntlet and sixteen-wireless-controller acceptance pending.
- [x] Gauntlet playtest revision: A/Cross/Wii 2 confirms start after joining (including buffered quick taps), mouse start/resume fallback, individual portal escapes and all-player completion, six-second victory return to the library, fallen-teammate rescue guard, and a lit procedural 3D dungeon with animated heroes/class portraits, stone shaders, torch shadows and portal/spell effects. Synthetic controller/escape/real-process-return tests and rendered inspection completed; physical retest pending.
- [ ] Connect the library to playable installed releases in SQLite through the production Rust host; source catalog and private-file prototype IPC do not establish distribution or sandbox readiness.


1. Rust desktop host owns SQLite, credentials, installation, and child processes.
2. Godot launcher consumes a versioned local API and shares SDK UI/input components.
3. Runtime inventory, approved artifact verification, automatic reuse, and rollback.
4. Download recovery, disk-space checks, crash recovery, and signed app updates.
5. Local profiles and saves survive game updates/uninstall; offline play needs no Neon connection.

**Exit:** a clean machine installs the app and two games, launches them without the editor, survives an interrupted update, and remains playable offline.

### 3. Private sharing and platform backend

1. Rust/Axum API, Neon migrations, and object storage integration.
2. Managed identity provider selected for PKCE/native login and phone-assisted TV login.
3. Creator-owned drafts, immutable releases, validation jobs, and signed metadata.
4. Family membership, invitations, explicit access grants, and authorized download URLs.
5. Disposable game-validation workers without production credentials.
6. CLI packaging/publishing and stable machine-readable diagnostics.

**Exit:** another authorized account installs a privately shared game on a second computer; unauthorized accounts are denied; retries do not duplicate publication; distributed games pass isolation checks on every supported OS.

### 4. V1 release readiness

1. Signed Windows installers and signed/notarized macOS bundles.
2. Recovery tests for installation, runtime updates, SQLite migrations, and saves.
3. Hardware matrix for controllers, Bluetooth, TV resolutions, audio, sleep/wake, and mirroring.
4. AI-readable SDK docs, starter walkthrough, local validation, and sample projects.
5. Opt-in diagnostic exports, operational backups, and restore drill.

**Exit:** an unfamiliar creator can create/play/share, and a recipient can install/play from the couch without managing Godot or a database.

## Verification strategy

Run Rust formatting, tests, and Clippy locally. Cover actual package corruption, path containment, idempotency, conflicting immutable releases, database persistence, and failed updates. Use subprocess tests for the CLI contract and failure exit codes.

The manually dispatched GitHub Actions workflow repeats engine-independent checks on Windows and macOS. Add headless Godot checks only in an explicitly separate workflow once a runtime is selected; never make local tests install an engine. Real-device testing remains necessary even after headless checks pass.

## Deferred scope

Payments, public discovery, cloud saves, online multiplayer infrastructure, custom streaming, additional engines, and marketplace recommendations remain outside this first V1 build sequence.

### Multiplayer workstream — documented, implementation pending

See [Multiplayer: LAN and managed online relaying](docs/multiplayer.md). Online servers forward messages; a player's computer owns game simulation. Scheduling this work does not change the V1 exit criteria above.

- [ ] Session roster and LAN Little World proof: two computers, two players each, independent views.
- [ ] Authenticated online room and relay prototype with bounded routing and queues.
- [ ] Real-network latency, transport, controller, cross-OS, and sandbox qualification.
- [ ] Reusable SDK templates, usage metering, and a measured monthly developer-service proposal.
