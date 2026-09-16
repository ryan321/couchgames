# Couch Games

A controller-first platform for playing and privately sharing Godot games on your own computer, displayed on a TV through a direct connection or screen sharing.

- [Product vision](PRODUCT.md)
- [Technical architecture and stack](TECH_STACK.md)
- [V1 implementation plan](IMPLEMENTATION_PLAN.md)
- [Multiplayer design: LAN and managed online relaying](docs/multiplayer.md)
- [Package manifest schema](schemas/manifest.schema.json)

## Current implementation

The first V1 slice is **local package validation and installation**:

- Manifest parsing and validation for provisional Windows/macOS package targets.
- Streaming artifact size and SHA-256 verification.
- Staged installation with immutable release identities.
- SQLite library persistence and one active release per game/target.
- Idempotent retry, previous-release retention, and recovery by retry after a filesystem rename succeeds but database activation fails.
- A CLI with human-readable output and `--json` for automation.
- Shared Godot discovery/version policy, setup instructions, and an initial SDK editor plugin/autoload that checks the running engine.
- A playable **Little World** 3D sample, with 16 player slots, device-isolated input, jumping, and reconnect/leave handling through the SDK.

**Godot is not required for package/library commands and is not installed or downloaded by them.** `doctor` probes discovered executables with `--headless --version`. Package validation executes no game code: success means that metadata and bytes match, not that a package is playable, signed, or safe.

A source-game library screen is implemented. The production desktop host, full input/save SDK, runtime installation, packaged game launch, OS sandbox, Neon API, sign-in, downloads, and sharing remain planned work. Little World is a playable source prototype, not a complete V1 platform release.

## Open the game library

```sh
python3 scripts/library.py
```

Click **Little World**, **Cloudbound**, **Pocket Rally**, or **Super Mario Bros. — World 1-1** to play. Each game runs in its own process; closing it returns you to the library with the same card selected. Keyboard arrows + Enter and standard gamepad D-pad + A / Cross also navigate the cards. F11 toggles fullscreen.

On this Mac, **Wii Remote + gamepads** uses our existing native Wii reader automatically for the selected game. Choose **Gamepads / keyboard** to play without it. Close any standalone game/reader first. See [library controls and implementation](sdk/launcher/README.md).

This first library lists the four included source games. The production Rust supervisor and launching installed releases from SQLite remain planned.

## Play Little World

```sh
python3 scripts/play.py
```

The script uses `couch doctor` to find a supported installed Godot, imports the project, and opens the 3D game. It does not download an engine, export templates, or art assets. Alternatively, open `sdk/project.godot` in the supported editor and press F6 on `examples/little_world/world.tscn`, or F5 for the project.

- Pair wireless Xbox or PlayStation controllers to the **computer**, then press **A / Cross** to join.
- Use the **left stick or D-pad** to move; **A / Cross** jumps. Hold **B / Circle** for 1.25 seconds to leave.
- Keyboard: **Enter** joins, **WASD / arrows** move, **Space** jumps, and **Backspace** leaves. The keyboard consumes one player slot.
- The game opens maximized with a 16:9 layout. **F11**, Xbox **Menu (☰)**, PlayStation **Options**, or the on-screen button toggles fullscreen; **F3** shows controller diagnostics. Fullscreen returns to the previous window mode.
- For a compatible Roku TV, use macOS AirPlay to share just the game window. See [TV display and window sharing](docs/tv-display.md).
- Disconnecting a controller removes its character and frees the slot immediately. Reconnect and press A / Cross once to join again; other players keep their characters.

For experimental Wii Remote/Remote Plus, Nunchuk, Classic/Classic Pro, and Wii U Pro profiles, run `python3 scripts/play.py --wii`. F3 includes per-device layout selection. Physical Wii pairing and play remain unverified; see [Wii setup and coverage](docs/wii-controllers.md).

The tested `Nintendo RVL-CNT-01` variant (`04e8:7021`) needs our native macOS reader. After closing the current game and standalone probe, use **`python3 scripts/play_wii_native.py`**. It builds the small reader with the existing Xcode compiler if needed, launches the reader and game together, and cleans up the reader on exit. One Wii Remote was physically verified for movement/jumping; other Wii variants and multiple native Remotes remain unverified. The Little World native path supports one Remote alongside the regular SDK player slots. Pocket Rally has a separate multi-Remote helper.


See [the game README](sdk/examples/little_world/README.md) and [wireless setup and hardware tests](docs/controller-test-matrix.md). The software supports sixteen slots. Physical wireless compatibility and simultaneous controller counts still need testing on the listed hardware.

## Play Cloudbound — Wii flying game

```sh
python3 scripts/play_wii_native.py --game cloudbound
```

A second **3D source game**, sharing the installed runtime. Hold the Wii Remote **sideways, D-pad left and 1/2 buttons right**. Press **2**, hold steady for one second, then turn left/right to bank. **Roll away from your body to dive; toward yourself to climb.** **B** boosts; **2** recenters. Fly through the golden rings.

The experimental native reader now requests acceleration as well as buttons for the observed `04e8:7021` variant. Live motion status, neutral calibration, and pause on stale input are built in. Sideways Wii flight, live acceleration, and factory calibration are physically confirmed on this Mac. Close the old standalone probe/game before starting this launcher.

For original Switch Joy-Con / Pro motion or keyboard/controller flight: `python3 scripts/play.py --game cloudbound`. Individual Joy-Cons are separate by default; add `--joycons paired` for a grip. Motion uses actual driver capabilities, with an explicit stick fallback. Switch hardware tests are pending; Switch 2 has profiles but needs a compatible driver not included in the pinned runtime. See [Switch coverage and setup](docs/switch-controllers.md). See [Cloudbound controls and verification](sdk/examples/cloudbound/README.md).

## Play Pocket Rally — split-screen driving

```sh
python3 scripts/play_wii_native.py --game pocket-rally
```

A separate **1–16 player 3D driving game**, with a chase camera for every car. Two players get side-by-side views; four get a 2×2 grid; sixteen get a 4×4 grid. Hold the Wii sideways, press **2**, and hold steady for one second. **Tilt steers, 2 accelerates, 1 brakes/reverses, Home rescues/recalibrates, and holding minus leaves.** Each controller owns its car and calibration. Disconnecting removes its car and view.

For keyboard or regular controllers: `python3 scripts/play.py --game pocket-rally`. Enter joins; WASD/arrows drive. Xbox A / PlayStation Cross joins and accelerates; left stick steers, X / Square brakes. F11 toggles fullscreen.

Pocket Rally uses a separate native helper with sixteen independent channels for the observed Wii variant. Physical multi-Remote and sixteen-player performance tests remain pending. Cloudbound's game and existing reader are preserved. See [Pocket Rally controls and verification](sdk/examples/pocket_rally/README.md).

## Play Super Mario Bros. — World 1-1

Choose its card in the library, or run `python3 scripts/play_wii_native.py --game world-1-1` on this Mac. For ordinary gamepads and keyboard: `python3 scripts/play.py --game world-1-1`.

The single-player recreation uses original NES sprite captures and the World 1-1 layout, with enemies, power-ups, hidden 1-up, the underground coin room, and the flagpole/castle finish. Wii: sideways D-pad moves, **2 jumps**, **1 runs/fires**; hold jump for height. Xbox/PlayStation: A/Cross jumps, B/Circle runs. Keyboard: arrows + Space/Shift. Esc returns to the library.

The gameplay is recreated, not frame-perfect NES emulation. Synthesized effects replace the original audio; music and fireworks are absent. See [controls, asset credits, tests, and fidelity limits](sdk/examples/world_1_1/README.md).

## Prerequisites

Use an existing current stable Rust toolchain with Cargo. The workspace uses Rust edition 2024. Builds fetch Rust crates as needed and compile a bundled SQLite library; no separate SQLite server or installation is necessary.

Development and test builds disable debug symbols and incremental compilation to save disk space. No build script downloads Godot or export templates. Once finished testing, `cargo clean` removes this checkout's generated build artifacts; a later Cargo command rebuilds them.

## Try the CLI

From the repository root:

```sh
cargo run --locked -p couch-cli -- doctor
cargo run --locked -p couch-cli -- validate tests/fixtures/package/release.json
cargo run --locked -p couch-cli -- --data-dir .local-demo install tests/fixtures/package/release.json --target macos-aarch64
cargo run --locked -p couch-cli -- --data-dir .local-demo library
```

The fixture contains three tiny text files with `.pck` filenames. **They are synthetic test data, not real Godot games.** This walkthrough only demonstrates metadata checks, file copying, and the SQLite library. It creates a small `.local-demo/` directory, ignored by Git.

The explicit target makes this content-only demo work on any development OS. Real imports default to the current computer's target. Provisional targets are `windows-x86_64`, `macos-x86_64`, and `macos-aarch64`; runtime/hardware support has not yet been verified.

`doctor` is read-only. `install` and `library` initialize their data directory and SQLite database. Without `--data-dir`, they use the OS's per-user application-data location. No Neon or other cloud connection is made.

### Commands

| Command | Behavior |
| --- | --- |
| `doctor [--require-godot]` | Detect Godot, check the supported version, and show setup guidance; optional readiness failure exit |
| `validate <release.json>` | Validate metadata and all declared artifacts |
| `install <release.json> [--target <target>]` | Verify and import the selected target as unsigned local content |
| `library` | List installed releases; `*` marks the active release |

Global options: `--data-dir <path>`, `--godot <executable-or-app>`, `--godot-timeout-secs <1–120>`, `--json`, `--help`, and `--version`.

## Godot setup and SDK checks

The initial supported development engine is **Godot 4.7.2 stable, standard official build**. The shared policy is in [runtime_policy.json](sdk/addons/couchgames/runtime_policy.json).

```sh
cargo run --locked -p couch-cli -- doctor --require-godot
python3 scripts/test_sdk.py
```

Discovery checks `--godot` first, then `COUCH_GODOT`, then executables on `PATH` and common application locations (including `/Applications` and `~/Applications` on macOS). An explicit path is authoritative: if it fails, the tool reports the problem instead of silently choosing another installation. Auto-detection can skip an old/broken candidate and find a supported one.

If Godot is missing, unusable, or unsupported, the report includes the pinned official download page and setup instructions. `--require-godot` exits 1 with a `GODOT_NOT_READY` error while preserving the report in JSON `data`. Ordinary `doctor` still succeeds so package-only development can continue. Each executable probe has a 15-second timeout and bounded output; no shell command is constructed from the executable path. For a slow first launch, open Godot normally to complete OS checks, then retry; `--godot-timeout-secs 60` can allow more time.

The [SDK README](sdk/README.md) explains the editor status panel and `Platform.is_runtime_supported()`. The SDK checks the engine it is running inside; missing-engine detection necessarily happens in the Rust host before Godot starts. The SDK check script dogfoods the host's selected executable and never downloads an engine. Export templates are unnecessary for these checks.

Example automation:

```sh
cargo run --quiet --locked -p couch-cli -- --json validate tests/fixtures/package/release.json
```

Operational results use one stdout JSON envelope:

```json
{"ok":true,"data":{"game_id":"example.fixture","release_id":"release-001","artifacts_verified":3,"scope":"metadata_and_content_integrity","playability_verified":false,"signature_verified":false}}
```

Operational failures return `{"ok":false,"error":{"code":"...","message":"..."}}` and exit status 1. CLI usage errors/help are handled by Clap and use its standard text output (usage errors exit 2). Cargo itself may print build diagnostics to stderr; a built `couch` executable has no Cargo wrapper output.

### Import guarantees and limits

- Manifest JSON is capped at 64 KiB; each artifact is limited to 4 GiB in the provisional contract.
- Artifact paths are portable lowercase basenames. Traversal, absolute paths, symlinks, directories, and reserved Windows device names are rejected.
- Bytes are verified while copying to staging before changing the active library entry.
- Retrying an identical installed release does not create a duplicate or roll back a newer active release.
- Reusing a release ID with changed metadata fails. Make a new release ID for an update.
- A failed import leaves the previous active database entry unchanged. A retry can reuse matching orphaned content left between rename and database commit.
- Old releases and save directories are preserved. Save/load APIs and garbage collection are not implemented yet.
- The library directory is assumed to be controlled by the current user. These checks do not sandbox hostile processes running under that same account.
- Recovery from sudden power loss, proactive free-space checks, abandoned staging cleanup, signed packages, and automatic repair of missing installed content remain future work. `library` lists database state; it does not rehash every installed file.

## Repository

```text
apps/cli/                  couch executable
crates/manifests/          manifest model, semantic checks, streaming verification
crates/local-library/      SQLite persistence and staged local import
crates/runtime/            discovery, version checks, and setup reports for the host
sdk/                       GDScript addon, shared runtime policy, engine test harness
sdk/examples/little_world/ playable 3D source sample using the SDK
scripts/play.py             launch sample through platform runtime discovery
scripts/test_sdk.py         explicit SDK checks using our own Godot discovery
migrations/sqlite/         embedded, checksummed SQLx migrations
schemas/                   JSON Schema for creator/agent tooling
tests/fixtures/package/    tiny non-playable package fixture
.github/workflows/         manually dispatched Rust checks; no automatic triggers
```

Schema validation is useful for editor feedback. The Rust validator also enforces cross-field rules such as player-count ordering and unique artifact targets/filenames, and verifies actual content bytes.

## Checks

```sh
cargo fmt --all -- --check
cargo test --workspace --locked
cargo clippy --workspace --all-targets --locked -- -D warnings
```

Rust tests use temporary directories, synthetic content, and test executables. They do not install Godot, run games, need a database server, or access cloud services. The manually dispatched GitHub Actions workflow runs the same checks on Windows, macOS, and Linux; Linux is a development/test environment, not a declared V1 game target. `scripts/test_sdk.py` is a separate explicit check that runs GDScript in an already-installed supported engine.

The source sample has rendered and passed scene/physics checks on macOS ARM64. Shared-PCK runtime execution, other graphics/OS targets, physical controller hardware, and sandbox validation remain required before distribution is ready.

GitHub Actions runs only through **workflow_dispatch** (manual invocation). Pushes and pull requests do not start workflows.
