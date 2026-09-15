# Repository guidance

## Development constraints

- Do not download or install Godot, export templates, or engine binaries on this computer unless the user explicitly asks to do so. Disk space is limited.
- Local builds, tests, and CLI commands must not implicitly install a runtime or toolchain.
- Keep the low-disk Rust build profiles in `Cargo.toml`. Use synthetic byte fixtures for engine-independent tests and clearly label them as non-playable.
- Do not claim game execution, controller behavior, runtime compatibility, or sandboxing is verified by package-integrity tests.

## Architecture

- Read `PRODUCT.md`, `TECH_STACK.md`, and `IMPLEMENTATION_PLAN.md` for scope and current milestones.
- Games execute on player-owned computers. SQLite is local; Neon PostgreSQL is accessible through the platform backend only.
- Reuse one installed runtime for compatible games. Keep game processes separate from the launcher and privileged host operations.
- Keep package identity and validation in `crates/manifests`, and local persistence/install behavior in `crates/local-library`.
- Treat unsigned imports as local developer content, not approved distribution artifacts.

## Verification

- Run `cargo fmt --all -- --check`, `cargo test --workspace --locked`, and `cargo clippy --workspace --all-targets --locked -- -D warnings` for relevant Rust changes.
- Update the implementation checklist and README when behavior changes; distinguish configured CI from checks actually run.
- Database migrations are embedded in `crates/local-library/src/migrations.rs`. Add new migrations to that list and do not rewrite migrations already released to users.
