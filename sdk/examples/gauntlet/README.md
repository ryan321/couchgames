# Gauntlet — The Ember Vault

A complete, original first dungeon inspired by the 1985 arcade Gauntlet, for **1–16 local players on one shared screen**. Pick a Warrior, Valkyrie, Wizard, or Elf; collect two keys, open the doors, and escape through the portal. Monster generators are optional combat/score objectives. Includes a title/class-selection lobby, victory results, defeat/retry, pause, synthesized effects, and controller disconnect recovery.

## Play

Choose **Gauntlet** in `python3 scripts/library.py`. Scroll down or navigate down through the game cards.

```sh
# Xbox / PlayStation / supported gamepads and keyboard
python3 scripts/play.py --game gauntlet

# The observed native Wii Remote variant on this Mac, alongside gamepads
python3 scripts/play_wii_native.py --game gauntlet
```

Both launchers reuse the already-installed supported Godot. The native path selects the existing multi-Remote reader and never installs an engine. Pair controllers with the computer first; close another game or standalone Wii reader before launching.

| Action | Xbox / PlayStation | Sideways Wii Remote | Keyboard |
| --- | --- | --- | --- |
| Join | A / Cross | 2 | Enter |
| Change class in lobby | X / Square | 1 | Tab |
| Begin | Release and press A / Cross again | Release and press 2 again | Enter again / Space |
| Move and aim | Left stick / D-pad | D-pad, with 1/2 on the right | WASD / arrows |
| Fire (hold) | A / Cross | 2 | Space |
| Magic potion | X / Square | 1 | X |
| Pause/resume | Menu / Options | Home | P |
| Leave player | Hold B / Circle | Hold Minus | Backspace |
| Retry after win/defeat | Menu / Options | Home | R |

F1 shows help and pauses play. F11 toggles fullscreen. Escape closes the game and returns to a supervising library. Switching away from the game pauses it; press A / Cross / Wii 2 to resume. Menu / Options / Wii Home can still start or pause. There is also a clickable **Enter the vault** button. Quick confirm taps are buffered through the SDK; holding the join button cannot accidentally start. The keyboard occupies one of the sixteen slots.

## The first level

- **Entry hall:** gather the party, find the western ghost generator and first key.
- **Lower crypt:** unlock the bronze door and destroy the grunt generator.
- **Upper crypt:** follow the central passage, destroy the second ghost generator, and collect the second key.
- **Eastern vault:** open the second door, defeat the demon generator, and return north to the exit.
- Enter the glowing portal to escape immediately. Your hero disappears from play and your HUD says **ESCAPED**. There is no generator requirement or group proximity timer.
- Every connected hero must escape. The last standing hero stays inside if a fallen teammate still needs reviving. A disconnect removes that player from the required party.
- Once everyone escapes, victory awards are shown and the game closes after six seconds, returning to a supervising library. Press confirm or click **Return to library** to leave sooner; **Play again** cancels the return by resetting the level.

Warrior has the strongest individual shots and most health; Valkyrie absorbs more damage; Wizard has the strongest area magic; Elf moves and fires fastest. Multiple players can choose the same class. Every player has a numbered character and matching HUD entry.

Health slowly drains. Contact attacks and demon projectiles cause damage with a brief recovery interval. Food heals every living hero, treasure contributes to the team score, and keys belong to the party. Potions are personal. Stand within 48 pixels of a fallen hero for 2.5 seconds to revive them with 40% health. If everyone falls, retry from the lobby. Disconnects remove only that controller's hero; mid-level recruits appear beside a standing teammate. Losing a controller cannot lose a key or leave a phantom player at the exit.

Generators spawn ghosts, grunts, and ranged demons. Enemy pressure scales with the active party and is capped at 96 enemies. Closed doors isolate rooms. Wall-aware movement and swept projectiles prevent passing through masonry; party members do not block or shoot one another.

## Reference and scope

The four hero archetypes, health, ranged attacks, magic, food, treasure, keys, and monster generators take their reference from [Atari's 1985 Gauntlet operator manual, mirrored at Manualzz](https://manualzz.com/doc/13044003/atari-games-gauntlet-user-manual). This is an original dungeon layout with original procedural 3D artwork and synthesized sounds, not a reproduction of the original level map, ROM, sprites, soundtrack, or exact balance. Sixteen-player capacity, team food/keys, reviving, and individual portal escapes are adaptations for this platform.

The renderer uses modeled heroes and equipment, animated limbs, textured stone, brass floor inlays, torch lights, dynamic shadows, floating pickups, spell rings, and an animated portal. The interface uses Godot’s bundled font and live 3D class portraits. The scene uses the existing Compatibility renderer with 2× MSAA; it needs no new engine, models, or texture downloads. Collision and movement remain in the deterministic 2D simulation; the 3D view is presentation only. Floor/wall meshes are batched, fixed character geometry shares baked meshes, and effect meshes are pooled. The local rendered stress run displayed 16 heroes plus 96 monsters for 120 frames in about 3.7 seconds (about 33 frames/second); this is a short rendering sample, not a hardware or sustained gameplay guarantee.  Only this first dungeon is implemented; no online multiplayer, progression saves, additional levels, or original arcade emulation is included.

## Verification

`python3 scripts/test_sdk.py` includes `sdk/tests/test_gauntlet.gd`:

- Full one-hero and sixteen-hero runs use SDK movement/fire events to traverse the real map, gather both keys, unlock doors, destroy all generators and finish.
- Sixteen distinct spawns and ownership, player cap, per-player class changes, simultaneous Start presses, disconnect/rejoin, shared food, friendly-fire exclusion, projectile hits, wall/door collision, magic inventory, ally revival, pause, defeat/retry, and exit membership.
- Sixteen synthetic native Wii packets exercise the existing fleet adapter, sideways D-pad, held 2 firing, and stale-channel removal.
- Controller-start regression tests cover a quick press/release of A and a held join followed by a fresh native Wii 2 press. Exit tests cover staggered escapes, safety after escape, fallen teammates, disconnects, single awards, and the return countdown.
- `test_gauntlet_return.gd` verifies that the victory countdown actually terminates the game process successfully.
- Rendered 3D gameplay and class-selection captures inspected on macOS ARM64 with Godot 4.7.2. Optional `--stress` capture exercises 16 heroes and 96 monsters. Performance and TV/controller behavior on other hardware need qualification.

These are synthetic controller tests. Physical Gauntlet gameplay, sixteen simultaneous wireless connections, other Wii variants, Switch drivers, PlayStation hardware, and TV readability still require hands-on qualification. The game's native Wii path reuses the observed `04e8:7021` variant and existing Pocket Rally fleet adapter; it does not extend hardware compatibility. The flying and driving game files are unchanged.
