# Gauntlet — Three Vaults

An original three-level campaign inspired by the 1985 arcade Gauntlet, for **1–16 local players on one shared screen**. Pick a Warrior, Valkyrie, Wizard, or Elf; find shared keys, open matching gates, and bring the whole party through each portal to advance. Monster generators are optional combat/score objectives. Includes a dedicated join/hero-selection/ready lobby, victory results, defeat/retry, pause, synthesized effects, and controller disconnect recovery.

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
| Change hero (clears ready) | Left/right or X / Square | Sideways D-pad left/right or 1 | Left/right or Tab |
| Color | Up, left/right, A / Cross to confirm | Sideways Up, left/right, 2 to confirm | Up, left/right, Enter; or C cycles |
| Ready (tap Back to edit) | Release and press A / Cross again | Release and press 2 again | Enter again / Space |
| Begin once everyone is ready | A / Cross again, or Menu / Options | 2 again, or + / Home | Enter again / P |
| Lobby buttons | Down, then left/right and A / Cross | Sideways down, then left/right and 2 | Down, left/right, Enter |
| Move and aim | Left stick / D-pad | D-pad, with 1/2 on the right | WASD / arrows |
| Attack (release after menu, then hold) | A / Cross | 2 | Space |
| Magic potion | X / Square | 1 | X |
| Open / close game menu | Menu / Options | + / Home | Esc / P |
| Navigate menu / select | Up/down, A / Cross | Sideways D-pad up/down, 2 | Up/down, Enter / Space |
| Leave player | Hold B / Circle | Hold Minus | Backspace |
| Continue after a level (after the opening animation) | A / Cross or Menu / Options | 2 or + / Home | Enter / Space |
| Retry after defeat | A / Cross or Menu / Options | 2 or + / Home | R / Space |

The full-screen lobby keeps all sixteen join cards visible below four animated hero previews. Each joined player chooses independently and marks themselves ready; changing class clears that player's readiness. When everyone is ready, a fresh A / Cross / Wii 2 enters the vault; the final ready press never starts automatically. Down selects the lobby button row; left/right chooses Game library, Controls, Fullscreen, or Enter the vault; confirm activates the selection. Up or B / Circle / Wii Minus returns to the hero card. Tapping back on a hero card clears readiness. Menu / Options / Wii + / Home can also start, and every button still supports the mouse. A held join button cannot mark a player ready or begin the level. Disconnects remove that player's readiness requirement; reconnecting requires joining and readying again. Mouse arrows and ready buttons operate the corresponding player card. The keyboard occupies one of the sixteen slots.

Each player also chooses a color independently from sixteen color swatches. **Up** from the hero card selects color; **left/right** cycles backward/forward; confirm returns to the hero card, then confirm again to ready. Down or Back also leaves the color selector. Keyboard **C** cycles color directly, and the mouse can click the swatch. Changing class preserves color; changing color clears readiness. Returning to the lobby retains class and color for connected players. Reconnecting begins a fresh player slot with its default color. Duplicate colors are allowed; player numbers remain visible.

The selected color tints clothing (including the Wizard's robe/hat and Elf's hood) and shields, while keeping skin, hair, and metal details intact. Player labels, floor rings, minimap dots, HUD bars, and magic rings match. Each class preview shows the most recently edited player of that class and shows their player number and color swatch, so choosing a color gives immediate visual feedback. The palette supplies distinct defaults across all sixteen slots; color does not change combat stats.

During play, the dungeon gets a wider, taller viewport. Only joined players appear in the compact health/magic strip. The minimap is transparent over a dedicated header region outside the dungeon, so it cannot hide the portal, and can be hidden entirely from the menu. The strip grows to a second row only for parties larger than eight.

**Esc / Menu / Options / Wii + / Home / P** opens the paused menu. Navigate up/down and confirm with A / Cross / Wii 2 / Enter; mouse clicks also work. Options include resume, full-dungeon/party camera, minimap visibility, cinematic/performance lighting, sound, controls, fullscreen, return to hero lobby, and return to game library. Leaving an active run requires confirmation with the safe option selected initially. Returning to the lobby resets the run and readiness while keeping the connected heroes and their class choices. Switching away from the game opens this menu and pauses all gameplay. F1 shows the controls guide; closing it returns to the menu during a run. F11 toggles fullscreen. In the lobby, Escape returns to the supervising library.

## The first level

- **Entry hall:** gather the party, find the western ghost generator and ruby key.
- **Lower crypt:** unlock the ruby gate and destroy the grunt generator.
- **Upper crypt:** follow the central passage, destroy the second ghost generator, and collect the sapphire key.
- **Eastern vault:** open the sapphire gate, defeat the demon generator, and return north to the exit.
- Enter the glowing portal to escape immediately. Your hero disappears from play and your HUD says **ESCAPED**. There is no generator requirement or group proximity timer.
- Every connected hero must escape. The last standing hero stays inside if a fallen teammate still needs reviving. A disconnect removes that player from the required party.
- Once everyone escapes, an animated portal screen celebrates the party and introduces the next vault. The next level starts after six seconds; after the first two seconds, confirm or click **Continue** to enter sooner. After the third vault, the final victory screen returns to the supervising library.

## Three increasingly difficult vaults

| Level | Bounds (tiles) | Generators | Initial enemies | Locks |
| --- | --- | --- | --- | --- |
| The Ember Vault | 40 × 20 | 4 | 0; generators spawn them | Ruby and sapphire |
| The Sunken Archive | 56 × 34 | 6 | 12 | Ruby, sapphire, emerald |
| The Crown Labyrinth | 76 × 48 | 12 | 24 | Ruby, sapphire, emerald, amber, amethyst |

Bounds describe the enclosing area, not a filled rectangle. The two later maps use individually placed rooms with different proportions, L-shaped extensions, cut corners, pillar loops, crooked two-tile passages, staggered gate locations, and optional dead ends with supplies. The Archive has a broad entrance, a hooked western archive, a narrow gallery and a detached eastern treasury. The Labyrinth adds offset towers, a ring chamber, a reliquary and longer return routes. Only carved floors and their bordering walls render; solid void cannot be crossed.

Keys are shared and consumed by gates of the matching color. Gates have no overhead stone arch: low solid colored leaves and thin colored floor inlays keep the lock visible from either corridor direction. Each gate and key shows only its color name. Unlocking retracts the leaves into the sides, leaving a visibly empty passage with colored edge inlays; there are no open/closed words or letter prefixes. Gate and key labels use a color name as well as hue; the HUD shows the party's held keys, and the minimap colors both keys and gates. Keys are in distant branches, so finding the next key can require returning to an earlier junction. Each map has an authored, deterministic key sequence, with no randomly placed or unreachable required keys.

Progression retains connected players, classes, chosen colors, score and cumulative kills. Each hero recovers 35% of their maximum health (at least 65% health, capped at full) and starts the next chapter with at least two potions. Level-specific keys, projectiles, pending attacks and escape flags reset. All connected heroes must exit; fallen allies still need rescue. New recruits and disconnects use the existing party handling. Returning to the hero lobby or retrying starts a fresh run at level one. Campaign progress is not saved between launches.

Enemy health increases by 12% and then 25% relative to level one, contact/projectile damage by 10% and then 20%, and movement speed by 4.5% and then 9%. Generators spawn faster, and larger parties allow more active enemies. These are initial balance values; later-map puzzle routes are verified separately from combat difficulty.

Basic attacks match the equipped weapons. All heroes still begin with two area-magic potions.

Potion blasts expand over 0.65 seconds to a 200-unit radius. Damage reaches each enemy or generator with the visible ring, once per target per potion, using the casting class's magic strength. The blast stays at the cast location as the player moves; pausing freezes its expansion and damage.

| Hero | Basic attack | Damage per hit | Minimum interval |
| --- | --- | --- | --- |
| Warrior | Axe cleave, 0.14s windup | 82 | 0.72s |
| Valkyrie | Sword strike, 0.08s windup | 42 | 0.40s |
| Wizard | Blue magic bolt | 38 | 0.46s |
| Elf | Fast arrow with shaft, metal tip, and fletching | 18 | 0.24s |

Melee can hit multiple enemies in a forward arc but cannot hit behind the hero, outside weapon reach, or through walls/closed doors. It also damages nearby generators. Only Wizard/Elf basic attacks create projectiles. Basic attacks never hurt teammates. Warriors have the most health, Valkyries absorb more damage, Wizards have the strongest area magic, and Elves move fastest. These are initial playtest values, not final balance. Multiple players can choose the same class. Every player has a numbered character and matching HUD entry.

The imported periodic arm gestures have been replaced by quiet ready poses. Walking remains blended with attacks. Entering or resuming requires releasing the confirm/attack button before combat can begin, so menu input does not turn into a held attack.

Actual damage triggers a short torso/head flinch on heroes, a slight squash/tilt on enemies, a soft sound, and a brief local tint. Enemy tint shifts from muted green to amber/red with remaining health. A small health bar appears above a damaged living enemy for 1.15 seconds, then fades over 0.40 seconds; later hits refresh it. Unhurt enemies have no visible bars, and health is also represented by bar length rather than color alone. Hit feedback pauses with the game. Sound rate limits and reserved hit voices keep crowds audible without a wall of impact sounds. Projectiles, melee, and area magic share the damage-feedback path.

Health slowly drains. Contact attacks and demon projectiles cause damage with a brief recovery interval. Food heals every living hero, treasure contributes to the team score, and keys belong to the party. Potions are personal. Stand within 48 pixels of a fallen hero for 2.5 seconds to revive them with 40% health. If everyone falls, retry from the lobby. Disconnects remove only that controller's hero; mid-level recruits appear beside a standing teammate. Losing a controller cannot lose a key or leave a phantom player at the exit.

Generators spawn ghosts, grunts, and ranged demons. Enemy pressure scales with the active party: caps are 20/34/46 for solo play and 96/124/128 for sixteen heroes across the three levels. Closed doors isolate rooms. Wall-aware movement and swept projectiles prevent passing through masonry; party members do not block or shoot one another.

## Audio

Each class has three CC0 recorded hurt reactions, with different performers for Warrior, Valkyrie, Wizard and Elf. Short takes retain their natural pitch and have matched loudness. Enemies have softer, shorter grunt/ghost/demon reactions (about 0.11–0.13 seconds). Class scrolling plays a CC0 recorded line: Warrior and Valkyrie say “Ready!”, Wizard says “Prepare yourself!”, and Elf says “Go!”. Quick scrolling keeps the latest choice and cuts off that player’s previous line without interrupting teammates. See [voice actors, source packs and licenses](assets/audio/voices/README.md). **All voices currently play through the regular speakers, including for Wii players.**

Actual player damage requests a 120 ms rumble on compatible gamepads or native Wii Remotes. Passive drain and invulnerable contacts do not trigger feedback. **Controller rumble** and **Sound effects** have independent pause-menu switches. Pause, reset, leave and shutdown stop active feedback. The tested Wii Remote stayed connected but produced no felt rumble; gamepad vibration remains physically unverified.

Wii speaker streaming is disabled: testing on the connected Remote produced choppy audio and connection drops, including after moving to asynchronous 4 kHz ADPCM. The experimental transport remains for development tests, but production defaults send no Wii voice data. Class selection falls back to regular speakers; native Wii hurt feedback sends only bounded motor pulses. Maintaining the controller connection takes priority over its speaker.

Each vault also has a quiet original music loop that softens during pause/transitions and briefly ducks on a hero hit. **Music** has its own pause-menu switch. Settings last for the game session. See [audio assets and regeneration](assets/audio/README.md). Weapon/enemy effects and music are original synthesis; lobby and hero hurt voices are licensed human recordings. Playback needs no downloads.

## Reference and scope

The four hero archetypes, health, class-specific melee/ranged attacks, magic, food, treasure, keys, and monster generators take their reference from [Atari's 1985 Gauntlet operator manual, mirrored at Manualzz](https://manualzz.com/doc/13044003/atari-games-gauntlet-user-manual). This is an original dungeon layout with original scenery plus CC0 character and material assets and a mix of synthesized effects and CC0 recorded voices, not a reproduction of the original level map, ROM, sprites, soundtrack, or exact balance. Sixteen-player capacity, team food/keys, reviving, and individual portal escapes are adaptations for this platform.

The renderer uses textured, rigged heroes with blended idle/walk and upper-body combat animation, scanned stone with normal/roughness/occlusion maps, metal reflections, animated torch flames, low colored gates, banners, spell rings, and a glowing portal. A wider shared camera follows the party and immediately pulls back when players spread out; fallen teammates stay in view too. Camera edges never restrict movement. Press **F3** to toggle a full-dungeon overview. Zooming back in is smooth, with a wider minimum view for navigation; a minimap shows walls, locked doors, keys, and the exit. The low foreground wall keeps feet visible. Class portraits use the same animated models. Movement speed controls the stride, including easing to idle against walls. Heroes can walk while swinging, shooting, or casting. Warrior and Valkyrie alternate swings; the Elf draws a recurved bow; the Wizard holds a staff and casts with his free hand. Damage produces a separate flinch, knockdown eases into a fall, and revival restores the standing pose. Turns blend smoothly, and pausing freezes combat animation. Muted clothing, beveled axe/sword blades, wrapped grips, smaller rimmed shields, and restrained helmets distinguish the heroes. The Warrior has a broader, stockier build; the female Valkyrie has swept-back hair and paired braids, with no helmet or circlet; the Elf is 14% shorter. These visual proportions apply in portraits and gameplay without changing movement speeds or collision. The Wizard's robe and trim trail opposite his actual movement and settle when he stops; the skirt keeps the hip bounce without inheriting its forward pitch. The wizard wears a long robe in his selected color with sleeves and a narrow felt hat with a modest brim and bent tip, plus a beard and a crooked wooden staff.

Gauntlet alone selects **Forward+** through the library and both direct launchers, using native Metal on macOS. **F2** switches cinematic/performance lighting. If that renderer will not start on your graphics hardware, add `--compatibility` to either direct play command above. This uses the project's existing Compatibility renderer. The engine is reused; no new engine/templates are downloaded. Assets are checked into the repository and require no runtime network access.

Movement, collisions, and damage remain in the deterministic 2D simulation. Shared meshes/animations, batched masonry, pooled effects, mipmaps, GPU texture compression, and 1K character texture import limits control rendering cost. See [art assets, performance evidence, and remaining AA work](../../../docs/gauntlet-art.md). This is a substantial art foundation, with prototype monsters and some equipment still awaiting custom art. Three local campaign levels are implemented; online multiplayer, progression saves and original arcade emulation are not included.

## Verification

`python3 scripts/test_sdk.py` includes `sdk/tests/test_gauntlet.gd`:

- Full one-hero and sixteen-hero runs use SDK movement/fire events to traverse the real map, gather both keys, unlock doors, destroy all generators and finish.
- Sixteen distinct spawns and ownership, player cap, per-player class changes, simultaneous Start presses, disconnect/rejoin, shared food, friendly-fire exclusion, projectile hits, wall/door collision, magic inventory, ally revival, pause, defeat/retry, and exit membership.
- Sixteen synthetic native Wii packets exercise the existing fleet adapter, sideways D-pad, held 2 firing, and stale-channel removal.
- Controller-start regression tests cover a quick press/release of A and a held join followed by a fresh native Wii 2 press. Exit tests cover staggered escapes, safety after escape, fallen teammates, disconnects, single awards, and the return countdown.
- Imported rig playback must change the leg pose; the shared camera must keep all sixteen spread-out heroes and their labels on screen.
- `test_gauntlet_campaign.gd` traverses the key/door/exit routes with one and sixteen heroes using real movement collision and inventory. It checks wrong-key rejection, supplies, irregular footprints, gate orientation, increasing map/enemy counts, camera bounds, transitions and state carry-over. Combat is disabled in these puzzle-route checks.
- `test_gauntlet_return.gd` verifies that the first two exits advance and only the third victory countdown terminates the game process successfully.
- Rendered 3D gameplay and class-selection captures inspected on macOS ARM64 with Godot 4.7.2. Optional `--stress` capture exercises 16 heroes and 96 monsters. Performance and TV/controller behavior on other hardware need qualification.

These are synthetic controller tests. Physical Gauntlet gameplay, sixteen simultaneous wireless connections, other Wii variants, Switch drivers, PlayStation hardware, and TV readability still require hands-on qualification. The game's native Wii path reuses the observed `04e8:7021` variant and existing Pocket Rally fleet adapter; it does not extend hardware compatibility. The flying and driving game files are unchanged.

## Blender cast

Heroes now wear modeled class-specific armor and weapons. Ghosts, grunts and demons use original hooded, armored and horned creature models with moving limbs, event-driven attack poses, and the existing hit/health feedback. [Source models, regeneration and limitations](assets/cast/README.md).

### Art and current party sight

Heroes have detailed Blender equipment, movement lean and quiet breathing. Enemies have articulated knees, smoother turns and secondary robe/tail motion. The Warrior uses a controlled axe cleave with a readable windup, contact and recovery. The visible blade and damage follow the same path and clock; facing stays fixed during the stroke, and walking continues. Modeled treasure, food, keys, potions, altars, braziers and wall dressing accompany beveled stone and varied room-floor motifs.

Fog follows every player: seven tiles completely clear, then a three-tile soft edge. Nearby sight combines across all sixteen players, including fallen allies. Rooms become hidden again when everyone moves away; the minimap and full-dungeon camera respect this. Sight depends only on distance to the party; walls and doors do not block the circular reveal. Menus remain unobscured; no controls are required to reveal the area around you.
