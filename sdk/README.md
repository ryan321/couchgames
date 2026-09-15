# Couch Games SDK: runtime checks

This initial addon checks runtime compatibility and provides setup guidance. Controller, save, and full lifecycle APIs are still planned.

## Shared supported-version policy

`addons/couchgames/runtime_policy.json` is the single policy source. The Rust `couch-runtime` crate embeds the same file at build time, and GDScript reads it from the addon. The initial development target is **Godot 4.7.2 stable, official standard build**. Other patches, prereleases, custom builds, and .NET builds are rejected until explicitly supported and tested.

Matching a version is not executable signature verification, a sandbox check, or proof that exported packages work on every platform. The development version policy does not finalize the distribution runtime's build flags or OS isolation design.

## Missing engine vs. wrong engine

- Before Godot can run, the platform's Rust host/tooling must find it. `couch doctor --require-godot` uses the reusable discovery crate, reports missing/unusable/unsupported states, and provides installation instructions. It never installs anything.
- Once a project opens, the SDK can inspect its **running** engine through `Engine.get_version_info()` and feature tags. The editor plugin displays status in the **Couch Games** bottom panel; unsupported engines get setup instructions and a download-page button.
- The `Platform` autoload exposes `runtime_status` and `is_runtime_supported()`. It reports an error for unsupported engines. It does not automatically close a creator's project or install/replace their engine.

An SDK running inside Godot cannot detect that Godot is absent before it starts. That is why the host check and in-engine check are both needed.

## Add to a project

1. Copy `addons/couchgames/` into the Godot project's `addons/` directory.
2. Enable **Couch Games** in Project Settings → Plugins.
3. Add `res://addons/couchgames/platform.gd` as an autoload named `Platform`.
4. For exports, include `addons/couchgames/runtime_policy.json` using the export preset's non-resource file filter (for example `*.json`). The SDK fails closed if the policy is missing.

```gdscript
if not Platform.is_runtime_supported():
    print(Platform.runtime_status["instructions"])
```

The SDK project in this directory already enables the plugin and autoload. It is a development/test harness, not a sample game.

## Dogfood the setup flow

From the repository root:

```sh
cargo run --locked -p couch-cli -- doctor --require-godot
python3 scripts/test_sdk.py
```

For a custom installation:

```sh
cargo run --locked -p couch-cli -- --godot /path/to/Godot.app doctor --require-godot
python3 scripts/test_sdk.py --godot /path/to/Godot.app
```

The script obtains the executable from our doctor command, imports the editor plugin, and runs seven shared compatibility cases plus a check of the real running engine. It never installs Godot or templates. Rust tests exercise missing/wrong/failing/timeout cases with test executables, not real engine downloads.

This flow has been exercised on macOS ARM64 with `4.7.2.stable.official.ed1daf0bf`: missing-engine guidance before installation, automatic detection afterward, plugin import, and all runtime checks passed. Windows discovery paths and other hardware still need real-device verification. If initial macOS startup is slow, open Godot once and retry; the CLI also accepts `--godot-timeout-secs 60`.

Version information: [Godot Engine API](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-method-get-version-info), [feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html).
