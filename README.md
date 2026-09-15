# Couch Games

A controller-first platform for playing and privately sharing Godot games on your own computer, displayed on a TV through a direct connection or screen sharing.

- [Product vision](PRODUCT.md)
- [Technical architecture and stack](TECH_STACK.md)
- [V1 implementation plan](IMPLEMENTATION_PLAN.md)
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

**Godot is not required for package/library commands and is not installed or downloaded by them.** `doctor` probes discovered executables with `--headless --version`. Package validation executes no game code: success means that metadata and bytes match, not that a package is playable, signed, or safe.

The Godot launcher, full input/save SDK, runtime installation, game execution, OS sandbox, Neon API, sign-in, downloads, and sharing remain planned work. This is developer tooling, not a playable V1 release.

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
scripts/test_sdk.py         explicit SDK checks using our own Godot discovery
migrations/sqlite/         embedded, checksummed SQLx migrations
schemas/                   JSON Schema for creator/agent tooling
tests/fixtures/package/    tiny non-playable package fixture
.github/workflows/         Rust checks; no Godot installation
```

Schema validation is useful for editor feedback. The Rust validator also enforces cross-field rules such as player-count ordering and unique artifact targets/filenames, and verifies actual content bytes.

## Checks

```sh
cargo fmt --all -- --check
cargo test --workspace --locked
cargo clippy --workspace --all-targets --locked -- -D warnings
```

Rust tests use temporary directories, synthetic content, and test executables. They do not install Godot, run games, need a database server, or access cloud services. CI is configured to run the same checks on Windows, macOS, and Linux; Linux is a development/test environment, not a declared V1 game target. `scripts/test_sdk.py` is a separate explicit check that runs GDScript in an already-installed supported engine.

Shared-PCK runtime execution, rendering, controller hardware, and sandbox validation remain required before distribution is ready.
