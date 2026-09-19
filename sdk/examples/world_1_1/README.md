# Super Mario Bros. — World 1-1 recreation

A single-player Godot recreation of the original NES World 1-1, using captured original sprites and scenery. Open **Super Mario Bros.** in the Giga Couch library:

```sh
python3 scripts/library.py
```

Direct launch with the tested native Wii path on this Mac:

```sh
python3 scripts/play_wii_native.py --game world-1-1
```

Or use regular gamepads/keyboard: `python3 scripts/play.py --game world-1-1`.

## Controls

| Action | Sideways Wii Remote | Xbox / PlayStation | Keyboard |
| --- | --- | --- | --- |
| Join | 2 | A / Cross | Enter |
| Move | D-pad | D-pad / left stick | Arrows / A,D |
| Jump; hold to jump higher | 2 | A / Cross | Space / Z |
| Run; press to throw fireball when powered up | 1 | B / Circle or X / Square | Shift / X |
| Duck / enter secret pipe | D-pad down | D-pad / stick down | Down / S |
| Pause/resume | Home | Menu / Options | P |
| Leave player slot | Minus | — | Backspace |

F1 shows help, F11 toggles fullscreen, R starts a fresh run, and Esc closes the game and returns to the library. Jump starts another run after game over or course clear. Reconnect and join again to resume a disconnected session. The SDK's general hold-B-to-leave action is disabled in this game's process because B is the run button.

Held jumps now rise about 82 pixels from standing/walking and 96 pixels at running speed, with roughly 18-pixel quick hops. This intentionally gives more clearance over the 64-pixel pipes and easier access to overhead blocks. Hold 2 / A / Cross / Space for the full jump.

## Implemented

- Original captured small, Super, and Fire Mario standing/running/jumping/skidding sprites; big-Mario crouch, item and enemy animation frames, bricks, question blocks, pipes, hills, clouds, bushes, ground, castle, and flags.
- A 256×240 game viewport with nearest-neighbor filtering, presented in a 4:3 frame.
- World 1-1's tile layout: three pits, six pipes, 44 interactive blocks including hidden items, both staircase pairs and the final stairs; 16 Goombas and a green Koopa.
- Acceleration, running, friction, variable-height jumps, floor/ceiling/wall collision, crouching, and a forward-only camera.
- Coins, mushroom growth, fire flowers, bouncing fireballs, star invincibility, hidden 1-up, multi-coin brick, brick breaking and bumping enemies from below.
- Enemy stomps, Koopa shell stopping/kicking and hitting other enemies, damage/shrink recovery, lives, timer, death/restart, and a midpoint checkpoint.
- The fourth pipe's underground room, 19 collectible coins, and return through the fifth pipe.
- Flag sliding, castle walk, conversion of remaining time into points, and a course-clear state.

## Fidelity limits

This is a fresh gameplay implementation, not NES emulation or a frame-perfect port. Movement constants, enemy activation/timing, hitboxes, camera timing, score chaining, checkpoint details, power-up transitions, and pipe/flag animations still need comparison against hardware. The multi-coin block uses a ten-hit count rather than the NES timing window. Stomp/death/flag poses, star palette cycling, and debris are approximations using the available frames. The font is Press Start 2P. Effects are short original synthesized sounds; the original music and sound recordings are not included. Fireworks, the original title screen, two-player alternating turns, and progression to World 1-2 are not implemented.

## Asset provenance

The original artwork is Nintendo's. Map capture: Rick N. Bruns / NES Maps. Individual sprite captures: NES Maps. Original downloaded files are preserved; GIF animation frames are losslessly decoded to PNG for Godot import. Exact source URLs and download SHA-256 hashes are recorded in [assets/sources.json](assets/sources.json). Runtime atlas regions select scenery from the map without redrawing it. These graphics are not presented as original project artwork or as openly licensed assets; no Nintendo affiliation or distribution clearance is asserted.

- [NES Maps sprites](https://www.nesmaps.com/maps/SuperMarioBrothers/sprites/SuperMarioBrothersSprites.html)
- [Rick N. Bruns' World 1-1 map](https://www.nesmaps.com/maps/SuperMarioBrothers/SuperMarioBrosWorld1-1Map.html)
- [Layout, enemies, and items reference](https://www.mariowiki.com/World_1-1_(Super_Mario_Bros.))
- [Press Start 2P source](https://github.com/google/fonts/tree/main/ofl/pressstart2p), with its included [SIL Open Font License](assets/FONT-LICENSE.txt).

## Verification

`python3 scripts/test_sdk.py` exercises the real game with synthetic inputs: player join/disconnect, jump-height control, run/friction, tallest-pipe clearance, wide-pit clearance, head hits, adjacent-ceiling regression, block contents, growth, fireballs, recovery, 1-ups, stars, multi-coins, stomps, shell kicking, deaths/restart, timer, underground coins/exit, and flag-to-castle completion. Native Wii button routing is synthetic here; actual motion/hardware is not required by tests. Rendered start, middle, underground, end, and library views have been inspected on this Mac. A complete physical-controller playthrough and NES timing comparison remain manual acceptance work.
