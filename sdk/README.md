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

`players` contains session state keyed by player ID, including `device`, `name`, and `connected`. Treat it as read-only. A join signal creates the character. Disconnect calls `leave(id)`, removes the player and device ownership, and emits `player_left` followed by `roster_changed`. Games should remove the character when `player_left` fires. `player_for_device(device)` returns 0 when unassigned. These IDs and device names are not durable profile identities.

Disconnected players are not reserved. Reconnecting a controller does not spawn a character until the player presses a join button. Joining assigns the lowest free slot with fresh input state; other players retain their IDs. Repeated disconnect/reconnect cycles cannot accumulate inactive characters. The prototype no longer exposes a reserved-slot chooser.

Mapped south face is Xbox A / PlayStation Cross; holding east face (B / Circle) for 1.25 seconds leaves. Pairing belongs to the computer's OS. Godot/SDL supplies mapped events over either Bluetooth or USB; we do not install drivers or establish Bluetooth connections ourselves. See [wireless setup and pending hardware tests](../docs/controller-test-matrix.md).

Keyboard input is opt-in (`Platform.input.keyboard_enabled = true`). Enter or Space joins, WASD/arrows move, Space jumps, Backspace leaves. Keyboard input occupies one of the sixteen slots, never all characters. Focus loss clears held actions. The API is a prototype validated by the sample; per-game actions/remapping and a full pause lifecycle remain future work.

### Experimental Wii layouts

`controller_profiles.gd` supplies basic-action profiles for Remote/Remote Plus, Nunchuk, Classic/Classic Pro, and Wii U Pro. The sample's F3 panel offers auto-detection and overrides. Games keep calling `movement` and `consume_jump` regardless of profile.

```gdscript
var profile: Dictionary = Platform.input.profile_for_device(device_id)
# Optional manual override; "auto" restores detection.
Platform.input.set_device_profile(device_id, "wii_nunchuk")
```

Profile IDs: `gamepad`, `wii_remote`, `wii_nunchuk`, `wii_classic`, `wii_classic_pro`, `wii_u_pro`, and `wii_unknown` (unplayable). `device_profile_override` returns the override or `auto`. Overrides clear on disconnect; changing a joined player's layout clears input. These are preset layouts, not a general action-remapping API.

Use `python3 scripts/play.py --wii` to enable SDL's driver and the pinned bare-Remote D-pad correction **before engine startup**. Addon installation alone does not configure the native driver. Physical Wii compatibility is unverified; motion/IR and specialty accessories remain future work. See [Wii setup, mapping sources, and coverage](../docs/wii-controllers.md).

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

### Native macOS Wii prototype

For the physically tested `04e8:7021` variant, the host command `python3 scripts/play_wii_native.py` runs a separate native reader and sets `COUCH_WII_NATIVE_STATE` to a private session file. `Platform` starts the optional `native_wii.gd` consumer only when that absolute path is provided. It translates snapshots into a single device's movement/jump/leave events and removes the player on missing or expired input. Regular launches do not read this file or start native processes. See [native setup and limitations](../docs/wii-controllers.md).
