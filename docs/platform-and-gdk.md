# What the platform and GDK provide

Status: inventory of responsibilities, September 19, 2026. **Shipped** means it exists in this checkout. **Planned** means it is part of the product and is not implemented yet.

The point of Giga Couch is to make couch games easy: a place to play them, and a kit so creators (and their AI agents) do not have to invent controller assignment, TV launch, or packaging. This document splits that into four buckets.

Related: [GDK product definition](../GDK.md), [player app](giga-couch-app.md), [SDK API](../sdk/README.md), [architecture](../TECH_STACK.md).

## Terms

| Term | Who | What |
| --- | --- | --- |
| **Platform** (Game Player) | People on the couch | `Giga Couch.app` on the computer attached to the TV: library, install, launch, return |
| **GDK** | Game creators and their agents | Everything needed to turn a normal Godot project into a game the Player can run |
| **SDK** | Game code | The Godot addon copied *into each game*; runs inside the game process on the Player |
| **The game** | The creator | Rules, levels, cameras, art. Not the Player, not the GDK tools |

Creators never ship a copy of the Game Player. They ship a Godot project that includes the SDK. The Player starts that game as a **separate** process. Controllers pair to the **computer**, not the TV. HDMI or AirPlay is only display.

```text
TV
 ↑ HDMI / AirPlay
Computer
 ├── Game Player          library, install, start/stop games
 │     └── host           starts Godot + optional USB/Wii helper
 └── Game process         one title
       └── GDK SDK        join, slots, mapped controllers  (ships in the game)
```

---

## 1. Platform code

Lives on the player’s computer. Never goes inside a game. This is the console.

### Shipped

| Piece | Path | What it does so creators don’t |
| --- | --- | --- |
| Game Player app | `apps/player/` | TV library, Play, return after quit or crash |
| Library UI | `sdk/launcher/` | Browse included source games plus **registered creator projects** |
| Launch host | `scripts/library.py` today; Rust host planned | Start a separate Godot process (`--path` is the sample SDK or the creator project); pause library input while a game is up |
| Creator project registry | `~/Library/Application Support/GigaCouch/creator-projects.json` | Hub / `couch init` register a source project; Player merges it into the TV library |
| Shared Godot runtime | Installed editor/runtime, policy in `sdk/addons/couchgames/runtime_policy.json` | One engine; players do not install the Godot editor |
| Doctor at launch | bundled `couch` CLI | Find a supported Godot **4.7.2** standard build |
| Wired USB helper | `tools/macos/xpad_reader.m` | Claim Xbox 360 XID / Xbox One GIP pads Darwin will not bind; write `COUCH_XPAD_NATIVE_STATE` |
| Wii helper | `tools/macos/wii_reader.m` | Same host-file pattern for supported Remotes |
| Package/library crates | `crates/manifests`, `crates/local-library`, `crates/runtime` | Manifest identity, SHA-256, SQLite install records, engine discovery |

HID pads (Xbox Bluetooth, DualShock/DualSense, Switch, most USB HID) are **not** decoded here. Godot/SDL in the game process already sees them.

### Planned

- Install and update of packed games; signed releases
- Accounts, private share, authorized downloads
- Per-game/profile save files on disk (the host namespace; the game talks to a save API, not SQLite)
- Sandbox: game process must not open unauthorized network or the platform database
- Restore library focus and input after crash
- Production Rust desktop host replacing the Python supervisor

**Rule:** the platform owns process lifecycle, library, runtime, and USB claiming. It does not own jump physics.

---

## 2. GDK code that runs on the platform

This is the **SDK**. Copied into every game as `addons/couchgames/`, autoload **`Platform`**. The Game Player launches the game; this code runs *inside* that game process.

### Shipped (in the game)

| File | Creator doesn’t have to write |
| --- | --- |
| `platform.gd` | Entry point; wires input; optional native readers |
| `player_input.gd` | 1–16 session slots; join / leave; device → player; ignore duplicate Joy-Con copies |
| `runtime_check.gd` + `runtime_policy.json` | Fail closed if the running engine is not the supported build |
| `controller_profiles.gd` | Experimental Wii layout names |
| `native_xpad.gd`, `native_wii.gd` | Read host JSON → normal Godot gamepad events. No USB. |
| `plugin.gd` | Editor status panel |
| `pause_overlay.gd` | Start / Esc pause; Resume; Quit to library (`Platform.install_shell()`) |
| `saves.gd` | One JSON save slot API (`save_data` / `load_data`); not SQLite |

Games use:

```gdscript
Platform.input.player_joined.connect(spawn_character)
Platform.input.player_left.connect(remove_character)

var move: Vector2 = Platform.input.movement(player_id)
var jump: bool = Platform.input.consume_jump(player_id)

Platform.install_shell()
Platform.save_data("slot-1", {"level": 1})
Platform.load_data("slot-1")
Platform.quit_to_platform()
```

Player IDs are 1–16 for this session, not hardware IDs. South face (Xbox A / PlayStation Cross) joins and jumps. Hold east face (B / Circle) 1.25s to leave. Keyboard is opt-in for development.

Each game **pins its own copy** of the addon. Updating one title’s SDK must not silently change another.

### Planned (in the game, not extracted yet)

Lobby / ready, remapping, rumble policy, richer TV-safe menus. Gauntlet still has its own lobby. Do not call `Platform.save(...)` or `Platform.input.action(...)` — those names are not methods. Use `save_data` / `load_data` and `install_shell` instead.

### Never in the game

USB decode, SQLite, Neon credentials, install, the library UI.

---

## 3. GDK scripts (creator machine only)

Tools to *make* the game. Players never run these.

### Shipped

| Script / app | Path | Job |
| --- | --- | --- |
| GDK Setup | `apps/gdk-setup/`, `python3 scripts/build_gdk.py` | Check Godot, install a versioned kit, optional agent CLI picker |
| Creator Hub | `apps/creator-hub/` | **New 3D game** copies the 3D starter, writes `couch.game.json` + `AGENTS.md`, registers with the Player; **Show folder** for agents |
| `couch init` | `apps/cli/` | Same scaffold from the CLI (`--parent`, `--template`). Registers the project. Never installs Godot |
| `couch doctor` | `apps/cli/` | Supported editor? `--project` inspects addon/autoload/`couch.game.json` without launching Godot |
| `couch validate` | | Manifest + artifact size and SHA-256 |
| `couch install` | | Unsigned local import. Does **not** run a game |
| `couch library` | | List installed releases |

Setup may detect or install the creator’s Codex / Claude Code / Grok / Kiro / Cursor CLI. Hub **Show folder** plus starter `AGENTS.md` is how the agent is fed the project.

### Planned (the agent-shaped workflow)

```text
couch run my-game                        # playtest through Player lifecycle
couch check / test                       # extra structured TV/controller checks
couch pack                               # PCK + release.json
couch publish --visibility private
```

`init` and `doctor --project` are implemented. [GDK.md](../GDK.md) §7 is the rest of the contract.

Repo helpers `python3 scripts/play.py` and `scripts/library.py` are development launchers in this checkout, not a released creator CLI.

---

## 4. GDK information and instructions

What a person or an agent is supposed to read so they do not reverse-engineer the whole repository.

### Shipped, thin

| File | Audience | Contents |
| --- | --- | --- |
| Starter `AGENTS.md` | Agent in a new Hub / `couch init` project | How to use Platform APIs, what does not exist, controllers, art defaults, run in editor vs Game Player |
| `docs/asset_source_guide.md` | Agent (also in each starter as `docs/`) | Where to get Godot-ready art/audio and how to license it |
| `docs/terminology.md` | Human creator (Hub + first-game guide) | Shared vocabulary so prompts to an agent are shorter and less ambiguous |
| `apps/gdk-setup/docs/index.html` | Human | First-game walkthrough (Hub, F5, join buttons) |
| `sdk/README.md` | Human or agent if they open it | Current input API |
| `runtime_policy.json` | Machine | Allowed Godot version |
| `schemas/manifest.schema.json` | Machine | Package shape |
| CLI `--json` | Agent | Structured doctor / validate errors |
| Setup agent picker | Human | Install a vendor CLI — not Giga Couch game instructions |

Repository-root `AGENTS.md` is for **people building this platform** (do not download Godot, run these tests). It is not shipped to creators.

### Planned — AI integration pack

The missing piece for “AI makes the game; we make it a console game”:

- How to start from a template, and which templates exist
- What the SDK owns vs what the game must implement
- How to get or create assets (default stylized CSG / a few GLBs; photoreal meshes are bring-your-own)
- What to reuse (addon only today; lobby/pause still live in examples)
- How to pack a game and put it on the Game Player
- Explicit list of APIs that do **not** exist, so agents do not invent `Platform.save`

The starter `AGENTS.md` is the first pack. It still does not cover packing, a 2D template, or an asset catalog.

---

## Who owns what

| | Owner |
| --- | --- |
| Library, runtime, launch/stop, USB helpers, later install/share/saves-on-disk | **Platform** |
| In-game couch behavior: slots, join, mapped controllers; later pause/save/quit | **GDK SDK** (in the game) |
| Create / check / pack on the creator’s Mac | **GDK scripts** |
| Tell the human and the agent how to use the three above | **GDK instructions** |
| Rules, levels, cameras, art, what jump *means* in this game | **Creator** |

The GDK does not make a game 16-player, split-screen, or online by itself. It removes couch plumbing. Sixteen software slots are a platform requirement; sixteen simultaneous wireless controllers on every computer is not a verified promise.

**Easy** means: agent reads `AGENTS.md` → `couch init` or Hub New 3D game → writes gameplay against `Platform.input` / save / pause → reopen Giga Couch and play it on the TV. Pack/deploy and private share are still later.
