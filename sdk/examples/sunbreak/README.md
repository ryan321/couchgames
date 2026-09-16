# Sunbreak

An original single-player first-person island skirmish: warm coastal buildings, turquoise water, leafy trees, a pulse carbine, and three waves of robot enemies. Inspired by the colorful survival-shooter genre; it combines original scenery, armor, weapons, shaders, and effects with CC0 Quaternius character/animation assets and Poly Haven surface textures. No Fortnite assets are used. See [art sources and rendering measurements](../../../docs/sunbreak-art.md).

## Play

Choose **Sunbreak** in the Couch Games library, or run from the repository root:

```sh
python3 scripts/play.py --game sunbreak
```

Uses the already-installed supported Godot, with Forward+ and native Metal on macOS. No engine or export templates are installed. For older graphics hardware, use `--compatibility` for reduced lighting. Editor users can run `island.tscn` with F6; the shared project's default renderer is Compatibility, so use the command above for the intended lighting.

| Action | Keyboard / mouse | Standard gamepad |
| --- | --- | --- |
| Move / look | WASD / hold right mouse and drag | Left / right stick |
| Fire / aim | Left / right mouse | RT / LT |
| Jump | Space | A / Cross |
| Reload | R | X / Square |
| Sprint | Hold Shift | Hold left-stick click |
| Deploy cover | Q | Y / Triangle |
| Pause / resume | Esc | Menu / Options |
| Level view | — | Right-stick click (R3) |
| Graphics preset | F2 or pause-menu button | Pause-menu button |
| Fullscreen | F11 | — |

Use the menu buttons to deploy, retry, or return to the library (a direct launch closes its window). Standard mapped dual-stick controllers are the target; Wii Remote and single Joy-Con FPS control schemes are not implemented. The game owns its single-player FPS actions locally; it uses the SDK's shared runtime check, not a new SDK-wide action API. Press a controller button to select that device; idle connected controllers are not automatically selected. Losing that device or application focus pauses the match. Reconnect and press a button to claim the controller again.

The mouse/trackpad cursor stays visible and free at all times, including deployment and resume. Mouse look requires holding the right button and dragging; right-button aim remains active during that drag. Controller input switches off mouse look until a deliberate mouse-button press in play. Controller look waits for a neutral right stick after selection, start, resume, or R3 recentering, and uses a 22% dead zone on each look axis so horizontal turns suppress small vertical offsets. R3 levels the view if you lose your bearings.

## Match

- Eliminate **18 robots across three waves** (4, 6, then 8). A three-second breather between waves restores 25 shield.
- Aim for the head: body hits deal 34 damage; headshots deal 60. A magazine holds 30 rounds and reloads in 1.6 seconds. Reserve ammunition is unlimited.
- Armored robots pursue using a collision-sampled navigation grid, separate from nearby allies, accelerate/brake into strafes, and visibly charge before firing dodgeable projectiles. Their rig blends locomotion, upper-body aim/fire, stagger, and death clips; hits interrupt a charging shot. Buildings, rocks, crates, and deployed walls stop movement and both sides' shots. Navigation rebuilds after placing cover.
- You begin with 100 health and 100 shield. Cyan canisters restore 40 shield; green canisters restore 35 health. Collect them by walking close. Robots drop supplies.
- The purple storm contracts from 54 to 18 meters over six minutes. Outside it, you take 12 damage per second. The radar shows enemies, your facing, and the safe zone.
- Deploy solid cover on clear ground. You carry up to three charges and regain one per elimination. At most six deployed walls remain; the oldest is removed when another is placed.
- Winning, losing, retrying, and returning to the launcher are implemented. This is a self-contained offline match, without persistent progression.

## Visual direction and limits

Forward+ supplies directional shadows, ambient occlusion, antialiasing, glow, and filmic tonemapping. Scanned ground/rock textures, layered painted surfaces, animated leaf canopies and grass, coastal rock formations, cargo stacks, lamps, and hanging banners dress the outpost. The new rifle has a barrel assembly, reflex sight, rails, bolt, modeled glove fingers and sleeves, and a magazine that is extracted/reseated during reload.

Weapon recoil uses a damped spring; look inertia, speed-driven bob, sprint lowering, eased ADS/FOV, and a restrained landing dip affect presentation. Recoil never changes the camera's aiming pitch. Movement has ground/air acceleration and short jump buffering/coyote time. Controllers and the mouse retain the corrected free-pointer behavior.

**Balanced** is the default: the 3D scene is capped at 1920×1080 while the interface stays at display resolution. **Performance** caps at 1280×720 and disables MSAA; **Cinematic** caps at 2560×1440. Smaller windows render natively. F2 or the pause-menu button cycles modes. Forward+ uses FSR spatial upscaling; Compatibility uses bilinear scaling. Static scenery merges 752 mesh instances by material while retaining individual collision bodies and signs.

This is a substantial step toward the AA visual/motion direction, not a finished AA production. Full building/editing, inventories, destructible scenery, multiplayer, a larger map, high-end authored environments, final audio, and sustained combat performance qualification remain outside this slice. Buildings are solid cover without enterable interiors. Hardware on other operating systems still requires playtesting.

## Verification

```sh
python3 scripts/test_sdk.py
python3 scripts/test_library.py
```

`test_sunbreak.gd` uses the actual scene and physics engine for shooting, headshots, fire/reload timing, cover/projectile occlusion, shield/health order, pickups, deployment overlap, jumping/landing, storm damage, pause/focus/disconnect, clean restart, and all three waves through victory. These are synthetic input/game-state checks, not a human playthrough or proof of physical-controller compatibility. Use `--capture=/absolute/path.png` as a Godot user argument to the test for rendered gameplay/menu captures with a real display.

Local verification on macOS ARM64 with the installed Godot 4.7.2: **68 Sunbreak assertions**, **20 library assertions**, and **8 Python host tests** passed. Forward+ / Metal gameplay and menu captures were visually inspected. The earlier full SDK suite passed. The latest run passes all 68 Sunbreak checks, then stops on a missing Gauntlet `music_ember.ogg` asset from concurrent work. Gauntlet is being edited separately and was not modified for this task. No Rust files, runtimes, or export templates were changed.

Input regression checks cover free-pointer deploy/resume, controller selection before menu event consumption, stale deflected axes, ten seconds of neutral/drift input, both vertical look directions, mouse/controller isolation, and R3 recentering. The connected Xbox One S initially reported neutral axes during diagnosis. The user subsequently reported recurring skyward drift; independent-axis filtering now addresses horizontal turns leaking vertical stick offset, but confirmation on that physical controller is still pending.

Regression checks also sweep the actual player capsule into a rotated/scaled rock, verify collision on all 66 reachable rocks after batching, and keep the head above the pelvis throughout strafing/backpedaling and hit reactions. Bone turns are converted into each parent bone's coordinate frame to avoid rolling soldiers sideways.

Additional upgrade checks cover animated knee poses, stopping blends, hit interruption, death progression, recoil settling without aim drift, moving magazines, static batching, graphics scaling, valid navigation waypoints, and an actual enemy body moving past a building. `preview_sunbreak.gd` is a deterministic, staged art/performance preview with animated figures; its screenshots and frame timings are not a human gameplay acceptance test.
