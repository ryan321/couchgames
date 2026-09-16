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

The four hero archetypes, health, ranged attacks, magic, food, treasure, keys, and monster generators take their reference from [Atari's 1985 Gauntlet operator manual, mirrored at Manualzz](https://manualzz.com/doc/13044003/atari-games-gauntlet-user-manual). This is an original dungeon layout with original scenery plus CC0 character and material assets and synthesized sounds, not a reproduction of the original level map, ROM, sprites, soundtrack, or exact balance. Sixteen-player capacity, team food/keys, reviving, and individual portal escapes are adaptations for this platform.

The renderer uses textured, rigged heroes with blended idle/walk and upper-body combat animation, scanned stone with normal/roughness/occlusion maps, metal reflections, animated torch flames, gate arches, banners, spell rings, and a glowing portal. A wider shared camera follows the party and immediately pulls back when players spread out; fallen teammates stay in view too. Camera edges never restrict movement. Press **F3** to toggle a full-dungeon overview. Zooming back in is smooth, with a wider minimum view for navigation; a minimap shows walls, locked doors, keys, and the exit. The low foreground wall keeps feet visible. Class portraits use the same animated models. Movement speed controls the stride, including easing to idle against walls. Heroes can walk while swinging, shooting, or casting. Warrior and Valkyrie alternate swings; the Elf draws a recurved bow; the Wizard holds a staff and casts with his free hand. Damage produces a separate flinch, knockdown eases into a fall, and revival restores the standing pose. Turns blend smoothly, and pausing freezes combat animation. Muted clothing, beveled axe/sword blades, wrapped grips, smaller rimmed shields, and restrained helmets distinguish the heroes. The Warrior has a broader, stockier build; the female Valkyrie has swept-back hair and paired braids, with no helmet or circlet; the Elf is 14% shorter. These visual proportions apply in portraits and gameplay without changing movement speeds or collision. The wizard wears a long indigo robe with sleeves and a narrow felt hat with a modest brim and bent tip, plus a beard and a crooked wooden staff.

Gauntlet alone selects **Forward+** through the library and both direct launchers, using native Metal on macOS. **F2** switches cinematic/performance lighting. If that renderer will not start on your graphics hardware, add `--compatibility` to either direct play command above. This uses the project's existing Compatibility renderer. The engine is reused; no new engine/templates are downloaded. Assets are checked into the repository and require no runtime network access.

Movement, collisions, and damage remain in the deterministic 2D simulation. Shared meshes/animations, batched masonry, pooled effects, mipmaps, GPU texture compression, and 1K character texture import limits control rendering cost. See [art assets, performance evidence, and remaining AA work](../../../docs/gauntlet-art.md). This is a substantial art foundation, with prototype monsters and some equipment still awaiting custom art. Only this first dungeon is implemented; no online multiplayer, progression saves, additional levels, or original arcade emulation is included.

## Verification

`python3 scripts/test_sdk.py` includes `sdk/tests/test_gauntlet.gd`:

- Full one-hero and sixteen-hero runs use SDK movement/fire events to traverse the real map, gather both keys, unlock doors, destroy all generators and finish.
- Sixteen distinct spawns and ownership, player cap, per-player class changes, simultaneous Start presses, disconnect/rejoin, shared food, friendly-fire exclusion, projectile hits, wall/door collision, magic inventory, ally revival, pause, defeat/retry, and exit membership.
- Sixteen synthetic native Wii packets exercise the existing fleet adapter, sideways D-pad, held 2 firing, and stale-channel removal.
- Controller-start regression tests cover a quick press/release of A and a held join followed by a fresh native Wii 2 press. Exit tests cover staggered escapes, safety after escape, fallen teammates, disconnects, single awards, and the return countdown.
- Imported rig playback must change the leg pose; the shared camera must keep all sixteen spread-out heroes and their labels on screen.
- `test_gauntlet_return.gd` verifies that the victory countdown actually terminates the game process successfully.
- Rendered 3D gameplay and class-selection captures inspected on macOS ARM64 with Godot 4.7.2. Optional `--stress` capture exercises 16 heroes and 96 monsters. Performance and TV/controller behavior on other hardware need qualification.

These are synthetic controller tests. Physical Gauntlet gameplay, sixteen simultaneous wireless connections, other Wii variants, Switch drivers, PlayStation hardware, and TV readability still require hands-on qualification. The game's native Wii path reuses the observed `04e8:7021` variant and existing Pocket Rally fleet adapter; it does not extend hardware compatibility. The flying and driving game files are unchanged.
