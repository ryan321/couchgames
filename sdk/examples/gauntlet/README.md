# Gauntlet — The Ember Vault

A complete, original first dungeon inspired by the 1985 arcade Gauntlet, for **1–16 local players on one shared screen**. Pick a Warrior, Valkyrie, Wizard, or Elf; destroy four monster generators, collect two keys, open the two doors, and gather at the exit. Includes a title/class-selection lobby, victory results, defeat/retry, pause, synthesized effects, and controller disconnect recovery.

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
| Begin | Menu / Options | Home | Enter again |
| Move and aim | Left stick / D-pad | D-pad, with 1/2 on the right | WASD / arrows |
| Fire (hold) | A / Cross | 2 | Space |
| Magic potion | X / Square | 1 | X |
| Pause/resume | Menu / Options | Home | P |
| Leave player | Hold B / Circle | Hold Minus | Backspace |
| Retry after win/defeat | Menu / Options | Home | R |

F1 shows help and pauses play. F11 toggles fullscreen. Escape closes the game and returns to a supervising library. Switching away from the game pauses it; resume when ready. The keyboard occupies one of the sixteen slots.

## The first level

- **Entry hall:** gather the party, find the western ghost generator and first key.
- **Lower crypt:** unlock the bronze door and destroy the grunt generator.
- **Upper crypt:** follow the central passage, destroy the second ghost generator, and collect the second key.
- **Eastern vault:** open the second door, defeat the demon generator, and return north to the exit.
- When all four generators are destroyed, all standing heroes must stay within the exit circle for 1.5 seconds. Fallen heroes do not strand the party.

Warrior has the strongest individual shots and most health; Valkyrie absorbs more damage; Wizard has the strongest area magic; Elf moves and fires fastest. Multiple players can choose the same class. Every player has a numbered character and matching HUD entry.

Health slowly drains. Contact attacks and demon projectiles cause damage with a brief recovery interval. Food heals every living hero, treasure contributes to the team score, and keys belong to the party. Potions are personal. Stand within 48 pixels of a fallen hero for 2.5 seconds to revive them with 40% health. If everyone falls, retry from the lobby. Disconnects remove only that controller's hero; mid-level recruits appear beside a standing teammate. Losing a controller cannot lose a key or leave a phantom player at the exit.

Generators spawn ghosts, grunts, and ranged demons. Enemy pressure scales with the active party and is capped at 96 enemies. Closed doors isolate rooms. Wall-aware movement and swept projectiles prevent passing through masonry; party members do not block or shoot one another.

## Reference and scope

The four hero archetypes, health, ranged attacks, magic, food, treasure, keys, and monster generators take their reference from [Atari's 1985 Gauntlet operator manual, mirrored at Manualzz](https://manualzz.com/doc/13044003/atari-games-gauntlet-user-manual). This is an original dungeon layout with original code-drawn artwork and synthesized sounds, not a reproduction of the original level map, ROM, sprites, soundtrack, or exact balance. Sixteen-player capacity, team food/keys, reviving, and the four-generator exit objective are adaptations for this platform.

The font reuses the existing Press Start 2P asset and its accompanying OFL license in `../world_1_1/assets/`. No Gauntlet art download is needed. Only this first dungeon is implemented; no online multiplayer, progression saves, additional levels, or original arcade emulation is included.

## Verification

`python3 scripts/test_sdk.py` includes `sdk/tests/test_gauntlet.gd`:

- Full one-hero and sixteen-hero runs use SDK movement/fire events to traverse the real map, gather both keys, unlock doors, destroy all generators and finish.
- Sixteen distinct spawns and ownership, player cap, per-player class changes, simultaneous Start presses, disconnect/rejoin, shared food, friendly-fire exclusion, projectile hits, wall/door collision, magic inventory, ally revival, pause, defeat/retry, and exit membership.
- Sixteen synthetic native Wii packets exercise the existing fleet adapter, sideways D-pad, held 2 firing, and stale-channel removal.
- Rendered gameplay and library captures inspected on macOS ARM64 with Godot 4.7.2.

These are synthetic controller tests. Physical Gauntlet gameplay, sixteen simultaneous wireless connections, other Wii variants, Switch drivers, PlayStation hardware, and TV readability still require hands-on qualification. The game's native Wii path reuses the observed `04e8:7021` variant and existing Pocket Rally fleet adapter; it does not extend hardware compatibility. The flying and driving game files are unchanged.
