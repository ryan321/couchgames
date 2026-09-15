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
| Select reserved player | D-pad left/right | D-pad left/right | Left/right arrows |
| Confirm reclaim | A | Cross | Enter |
| Cancel reclaim | B | Circle | Escape |

F11 toggles fullscreen; F3 shows controllers reported by Godot and their player assignments. Close the window to exit. Sixteen slots are available, including the optional keyboard player. Colors and numbers identify players. Characters pass through one another so no one can block a jump or spawn point.

Pair wireless controllers with the computer before joining; no cable is required for a compatible Bluetooth controller. [Setup and hardware test matrix](../../../docs/controller-test-matrix.md).

Disconnecting reserves your character and clears held inputs. Reconnect, press a face button, then choose and confirm your player number. This explicit step handles identical controllers and changed device IDs. Selecting “New player” uses a free slot without taking a reserved character.

## Integration and checks

This is the main scene of `sdk/project.godot`, using the same addon as SDK tests. The game consumes `Platform.input`; controller ownership and device filtering live in the addon rather than the game. `character.gd` supplies camera-relative movement, acceleration, jump buffering, coyote time, collisions, and respawning. `shapes.gd` is the procedural art kit.

```sh
python3 scripts/test_sdk.py
```

The input tests cover sixteen independent devices, capacity, dead zones, diagonal normalization, reconnect selection, reused IDs, focus clearing, leave, and keyboard isolation. The scene test drives real Godot input dispatch, spawns sixteen characters, moves and jumps one, checks landing/step collisions, respawns after a fall, and reclaims an existing character.

Visual inspection can capture a rendered test run using an already-selected supported executable:

```sh
/path/to/Godot --path sdk --script res://tests/test_playground.gd -- --capture=/tmp/little-world.png
```

Verified on this Mac: source-game rendering and synthetic scene/input checks. Physical wireless Xbox/PlayStation tests, sixteen simultaneous radio connections, TV/mirroring, Windows rendering, full controller menus, saves, and shared-PCK launch remain pending. The sample is trusted local source content, not a signed or sandboxed distribution package.
