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

**Godot is not required for these commands and is not installed or downloaded by them.** No game code is executed. A successful validation means that metadata and bytes match, not that a package is playable, signed, or safe.

The Godot launcher, SDK, runtime management, game execution, OS sandbox, Neon API, sign-in, downloads, and sharing remain planned work. This is developer tooling, not a playable V1 release.

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
| `doctor` | Report configuration and current implementation limits; no filesystem changes |
| `validate <release.json>` | Validate metadata and all declared artifacts |
| `install <release.json> [--target <target>]` | Verify and import the selected target as unsigned local content |
| `library` | List installed releases; `*` marks the active release |

Global options: `--data-dir <path>`, `--json`, `--help`, and `--version`.

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

Tests use temporary directories and synthetic content. They do not install Godot, run games, need a database server, or access cloud services. CI is configured to run the same checks on Windows, macOS, and Linux; Linux is a development/test environment, not a declared V1 game target.

The next engine-independent work can prepare the host protocol and SDK source. Actual shared-runtime, rendering, controller, and sandbox validation must take place on a machine where installing Godot is explicitly allowed.
