# Little World

A small 3D couch playground: colorful characters run and jump around a floating garden. Climb the steps, hop between pillars, or wander with friends. Falling respawns the character. There are no objectives, network services, or saves yet.

## Run

From the repository root:

```sh
python3 scripts/play.py
```

Uses the supported installed Godot selected by our host. For a custom location, pass `--godot /path/to/Godot.app`. No engine, templates, models, textures, or dependencies beyond the existing workspace toolchain are installed by the game. Geometry and characters are generated in GDScript.

| Action | Xbox | PlayStation | Keyboard |
| --- | --- | --- | --- |
| Join | A | Cross | Enter |
| Move | Left stick / D-pad | Left stick / D-pad | WASD / arrows |
| Jump | A | Cross | Space |
| Leave | Hold B, 1.25 seconds | Hold Circle, 1.25 seconds | Backspace |

The game opens maximized with a 16:9 layout that preserves proportions on other screen shapes. F11, Xbox Menu (☰), PlayStation Options, or the on-screen button toggles fullscreen and restores the previous window mode. F3 shows controllers reported by Godot and their player assignments. For Roku/AirPlay, see [TV display and window sharing](../../../docs/tv-display.md). Close the window to exit. Sixteen slots are available, including the optional keyboard player. Colors and numbers identify players. Characters pass through one another so no one can block a jump or spawn point.

Pair wireless controllers with the computer before joining; no cable is required for a compatible Bluetooth controller. [Setup and hardware test matrix](../../../docs/controller-test-matrix.md).

For experimental Wii family profiles, run `python3 scripts/play.py --wii`. Use F3 to inspect or select a device layout. A sideways Remote/Remote Plus uses D-pad movement and **2** to join/jump; Nunchuk and Classic/Pro layouts use the left stick and **A**. Hold **minus** to leave; **plus** toggles fullscreen. Physical Wii pairing and input still need testing. [Wii setup and current limits](../../../docs/wii-controllers.md).

Disconnecting removes your character and frees its slot immediately. Reconnect and press A / Cross once to join again with a fresh character. Other players keep their characters and numbers. Hold B / Circle to leave while keeping the controller connected; a keyboard player leaves with Backspace. Falling teleports that same character back to its spawn; it does not create another player. If macOS also exposes a combined copy of a Joy-Con pair, F3 shows it as **duplicate ignored** and jump/respawn will not join it.

## Integration and checks

This is the main scene of `sdk/project.godot`, using the same addon as SDK tests. The game consumes `Platform.input`; controller ownership and device filtering live in the addon rather than the game. `character.gd` supplies camera-relative movement, acceleration, jump buffering, coyote time, collisions, and respawning. `shapes.gd` is the procedural art kit.

```sh
python3 scripts/test_sdk.py
```

The input tests cover sixteen independent devices, capacity, dead zones, diagonal normalization, disconnect removal, repeated reconnects, reused IDs, focus clearing, leave, and keyboard isolation. The scene test drives real Godot input dispatch, spawns sixteen characters, moves and jumps one, checks landing/step collisions, respawns after a fall, verifies disconnected character nodes are freed without disturbing another player, and rejoins with a fresh character.

Visual inspection can capture a rendered test run using an already-selected supported executable:

```sh
/path/to/Godot --path sdk --script res://tests/test_playground.gd -- --capture=/tmp/little-world.png
```

Verified on this Mac: source-game rendering and synthetic scene/input checks. The user also confirmed two wireless Xbox controllers work, including their left sticks. Physical verification of the updated disconnect removal, PlayStation controllers, sixteen simultaneous radio connections, TV/mirroring, Windows rendering, full controller menus, saves, and shared-PCK launch remain pending. The sample is trusted local source content, not a signed or sandboxed distribution package.
