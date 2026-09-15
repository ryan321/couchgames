# Couch Games SDK

This addon checks runtime compatibility and provides per-player movement, jump, join, leave, and reconnect handling for sixteen local player slots. Save APIs, full lifecycle handling, remapping, and haptics are still planned.

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

The SDK project in this directory already enables the plugin and autoload. Its main scene is the playable [Little World](examples/little_world/README.md) 3D example.

## Player input API (prototype)

```gdscript
Platform.input.player_joined.connect(spawn_character)
Platform.input.player_left.connect(remove_character)
Platform.input.roster_changed.connect(update_join_ui)

# In a character's physics tick, using its assigned ID from player_joined:
var move: Vector2 = Platform.input.movement(player_id)
var jump: bool = Platform.input.consume_jump(player_id)
```

Player IDs are integers 1–16, independent of Godot device IDs. `movement` returns a vector capped at length 1 with a 0.2 radial dead zone; X points screen-right, Y points screen-down. The game chooses how those axes map into its world. D-pad inputs work alongside left-stick input. `consume_jump` consumes a queued rising edge once; call it every physics tick, including when airborne. Unknown/disconnected players have zero movement; disconnect clears queued actions.

`players` contains session state keyed by player ID, including `device`, `name`, and `connected`. Treat it as read-only. A join signal creates the character; disconnect retains it and emits `roster_changed`. `leave(id)` removes ownership and emits `player_left`. `player_for_device(device)` returns 0 when unassigned. These IDs and device names are not durable profile identities.

When disconnected slots exist, a new controller enters `pending_claims`. Use `claim_selection(device)` and `claim_options()` to draw the chooser: positive IDs are reserved players, 0 means a new player, and -1 means the selection is no longer available. D-pad left/right selects, south face confirms, east face cancels. If two controllers select the same slot, the second must choose again; its selection never silently switches to another player. The SDK never treats a reused device ID or identical controller name as proof of ownership.

Mapped south face is Xbox A / PlayStation Cross; holding east face (B / Circle) for 1.25 seconds leaves. Pairing belongs to the computer's OS. Godot/SDL supplies mapped events over either Bluetooth or USB; we do not install drivers or establish Bluetooth connections ourselves. See [wireless setup and pending hardware tests](../docs/controller-test-matrix.md).

Keyboard input is opt-in (`Platform.input.keyboard_enabled = true`). Enter or Space joins, WASD/arrows move, Space jumps, Backspace leaves. Keyboard input occupies one of the sixteen slots, never all characters. Focus loss clears held actions. The API is a prototype validated by the sample; per-game actions/remapping and a full pause lifecycle remain future work.

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

The script obtains the executable from our doctor command, imports the editor plugin, runs seven shared compatibility cases plus a real-engine check, tests synthetic input through all sixteen player slots, and runs the actual sample scene's 3D physics checks. It never installs Godot or templates. Synthetic input does not establish physical controller compatibility. Rust tests exercise missing/wrong/failing/timeout cases with test executables, not real engine downloads.

This flow has been exercised on macOS ARM64 with `4.7.2.stable.official.ed1daf0bf`: missing-engine guidance before installation, automatic detection afterward, plugin import, and all runtime checks passed. Windows discovery paths and other hardware still need real-device verification. If initial macOS startup is slow, open Godot once and retry; the CLI also accepts `--godot-timeout-secs 60`.

Version information: [Godot Engine API](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-method-get-version-info), [feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html).
