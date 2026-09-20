# Giga Couch — agent instructions

You are helping a person make a **couch game** for the Giga Couch Game Player (TV + controllers). This is a normal Godot 4.7.2 project. Do not download Godot, export templates, engines, or toolchains unless the human explicitly asks.

## What this project already has

- `addons/couchgames/` — pinned SDK. Do not replace it from the internet.
- Autoload **Platform** (`res://addons/couchgames/platform.gd`).
- `couch.game.json` — game id, title, and entry scene for the Game Player.
- A playable 3D starter under `examples/little_world/`.

## Use only these Platform APIs

```gdscript
Platform.is_runtime_supported()
Platform.input.player_joined.connect(spawn)
Platform.input.player_left.connect(remove)
Platform.input.movement(player_id)      # Vector2, length ≤ 1
Platform.input.consume_jump(player_id)  # true once per press
Platform.quit_to_platform()             # leave the game; return to the library
var saved = Platform.save_data("slot-name", data)   # {ok: true} or {ok: false, error: "..."}
var loaded = Platform.load_data("slot-name")        # {ok: true, data: ...} or {ok: false, error: "..."}
Platform.install_shell()                # Start/Esc pause + Quit to library (call once from the main scene)
```

Player IDs are **1–16** for this session, not hardware IDs. Spawn on `player_joined`, free on `player_left`. Xbox **A** / PlayStation **Cross** joins and jumps. Hold **B** / **Circle** to leave.

## Do not call these — they do not exist

`Platform.save(...)`, `Platform.input.action(...)`, `Platform.input.glyph(...)`, `Platform.quit_to_platform` alternatives that talk to SQLite or the network. Do not open USB. Do not connect to Neon. Do not edit `addons/couchgames/` unless fixing a bug the human asked for.

## Controllers and the Player

Pair pads in the **OS**, not the TV. HID pads (Xbox Bluetooth, DualShock, Switch, most USB HID) already work through Godot. The Game Player starts optional USB/Wii helpers; game code only reads `Platform.input`.

## Art

Keep the default look: CSG, a few simple meshes, the starter palette. Do not generate photoreal / Unreal-scale scenes.

When you need **external** art, audio, fonts, or plugins, read **`docs/asset_source_guide.md`** in this project (Kenney, CC0, Godot-ready sources, license rules). Do not grab random web files. Record attribution the guide asks for.

The human may speak in everyday language. If they want shorter, clearer prompts, **`docs/terminology.md`** is the shared vocabulary (hitbox, hurtbox, prefab, tick, and so on). Use those terms when they help; do not require the human to learn them.

## How to run

1. Open `project.godot` in the supported Godot **4.7.2** standard editor. Wait for import.
2. F5 runs the project. After the first import, Creator Hub **Play** also works.
3. Creating or `couch init` **registers** the project. Reopen **Giga Couch** (the Game Player) to see it on the TV library and press Play there.

## What you own vs the kit

You own rules, levels, cameras, characters, scoring, and art. The SDK owns join/leave, slots, and pause/quit/save. Do not copy Gauntlet, Sunbreak, or other sample games from a Giga Couch checkout into this project.

## Packaging

`couch pack` / private publish are **not implemented**. Do not invent a store upload. Local play from the editor or Game Player is the current loop.
