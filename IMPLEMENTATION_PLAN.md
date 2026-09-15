# V1 Implementation Plan

This is the execution checklist for [TECH_STACK.md](TECH_STACK.md). V1 is complete when a creator can build a Godot game, integrate our SDK, play it from the couch, and privately share it with another player.

## Current constraints

- Do not install Godot, export templates, or engine binaries on this development computer until the user explicitly authorizes it.
- Do not automatically install toolchains or download runtimes from build scripts, tests, or CLI commands.
- Keep Rust debug symbols and incremental compilation disabled to limit disk use.
- Develop and test engine-independent components locally. Actual game execution, rendering, controller hardware, and OS sandbox validation remain separate required checks on a suitable machine.
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
- [x] Windows/macOS/Linux CI configuration that does not install Godot; remote runs remain pending.
- [x] README with a small, explicitly non-playable fixture workflow.

Unsigned local imports are developer tooling only. They do not authorize public or private distribution. This slice does not download, install, or launch a runtime.

Verified locally on macOS ARM64 with Rust 1.97.1: 21 tests passed; formatting and Clippy passed. This does not verify other operating systems, actual PCK compatibility, abrupt power-loss recovery, game execution, or sandboxing. See the README for the current guarantees and limits.

## Subsequent milestones

### 0. Shared runtime and OS feasibility — engine validation pending

1. Select exact Godot release/build flags and supported Windows/macOS targets.
2. Export two tiny projects plus the launcher and reuse one installed runtime to run them.
3. Prototype the desktop host, readiness handshake, crash recovery, and return to launcher.
4. Demonstrate OS isolation for PCK access, GPU/audio/controllers, restricted communication, scratch storage, and per-game saves.

**Exit:** both games run from the same installed engine on each supported OS, a crash returns to the launcher, and adversarial tests demonstrate the access boundary. Until then, avoid claims that game distribution is safe or that PCKs work across targets.

### 1. SDK and four-player sample

1. GDScript addon, `Platform` autoload, starter project, and documented API.
2. Per-player input state; join, leave, disconnect, and reclaim-slot flow.
3. Action remapping, analog dead zones, glyph fallback, and basic rumble.
4. Controller-driven menus, pause, TV-safe layout, and quit-to-platform.
5. Asynchronous local save/load with explicit errors, atomic replacement, and schema migration hooks.

**Exit:** four independent controllers can complete a session, reconnect without stealing another player's slot, and restore a saved game. Check direct TV output and one screen-sharing setup.

### 2. Desktop library and runtime management

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

CI repeats engine-independent checks on Windows and macOS. Add headless Godot checks only in an explicitly separate workflow once a runtime is selected; never make local tests install an engine. Real-device testing remains necessary even after headless checks pass.

## Deferred scope

Payments, public discovery, cloud saves, online multiplayer infrastructure, custom streaming, additional engines, and marketplace recommendations remain outside this first V1 build sequence.
