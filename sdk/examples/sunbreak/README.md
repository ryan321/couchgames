# Sunbreak

An original single-player first-person island skirmish: warm coastal buildings, turquoise water, leafy trees, a pulse carbine, and three waves of robot enemies. Inspired by the colorful survival-shooter genre; it uses original procedural scenery, weapon/robot models, shaders, and synthesized effects. No Fortnite assets or downloaded art are used.

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
| Fullscreen | F11 | — |

Use the menu buttons to deploy, retry, or return to the library (a direct launch closes its window). Standard mapped dual-stick controllers are the target; Wii Remote and single Joy-Con FPS control schemes are not implemented. The game owns its single-player FPS actions locally; it uses the SDK's shared runtime check, not a new SDK-wide action API. Press a controller button to select that device; idle connected controllers are not automatically selected. Losing that device or application focus pauses the match. Reconnect and press a button to claim the controller again.

The mouse/trackpad cursor stays visible and free at all times, including deployment and resume. Mouse look requires holding the right button and dragging; right-button aim remains active during that drag. Controller input switches off mouse look until a deliberate mouse-button press in play. Controller look waits for a neutral right stick after selection, start, resume, or R3 recentering, and uses a 22% radial dead zone. R3 levels the view if you lose your bearings.

## Match

- Eliminate **18 robots across three waves** (4, 6, then 8). A three-second breather between waves restores 25 shield.
- Aim for the head: body hits deal 34 damage; headshots deal 60. A magazine holds 30 rounds and reloads in 1.6 seconds. Reserve ammunition is unlimited.
- Robots strafe, pursue, steer around obstacles, and visibly charge before firing dodgeable projectiles. Buildings, crates, and deployed walls stop both sides' shots.
- You begin with 100 health and 100 shield. Cyan canisters restore 40 shield; green canisters restore 35 health. Collect them by walking close. Robots drop supplies.
- The purple storm contracts from 54 to 18 meters over six minutes. Outside it, you take 12 damage per second. The radar shows enemies, your facing, and the safe zone.
- Deploy solid cover on clear ground. You carry up to three charges and regain one per elimination. At most six deployed walls remain; the oldest is removed when another is placed.
- Winning, losing, retrying, and returning to the launcher are implemented. This is a self-contained offline match, without persistent progression.

## Visual direction and limits

Forward+ supplies directional shadows, ambient occlusion, antialiasing, glow, and filmic tonemapping. Animated water, atmospheric haze, layered architecture, cloud banks, distant silhouettes, batched grass, rifle recoil, reload movement, tracers, and hit effects support the stylized art direction. Assets are small, deterministic, and authored in code.

This is a playable first art/gameplay slice, not Fortnite production-quality graphics or a battle-royale clone. Full building/editing, weapon inventories, destructible scenery, multiplayer, authored character animation, sophisticated navigation, and a large map are outside this version. Robot steering is local obstacle avoidance, not a navigation mesh; crowded routes can need tuning. Buildings are solid cover without enterable interiors. Physical controller feel, sustained GPU performance, and other operating systems still require playtesting.

## Verification

```sh
python3 scripts/test_sdk.py
python3 scripts/test_library.py
```

`test_sunbreak.gd` uses the actual scene and physics engine for shooting, headshots, fire/reload timing, cover/projectile occlusion, shield/health order, pickups, deployment overlap, jumping/landing, storm damage, pause/focus/disconnect, clean restart, and all three waves through victory. These are synthetic input/game-state checks, not a human playthrough or proof of physical-controller compatibility. Use `--capture=/absolute/path.png` as a Godot user argument to the test for rendered gameplay/menu captures with a real display.

Local verification on macOS ARM64 with the installed Godot 4.7.2: **45 Sunbreak assertions**, **20 library assertions**, and **8 Python host tests** passed. Forward+ / Metal gameplay and menu captures were visually inspected. The full `scripts/test_sdk.py` suite passed after the input correction. Gauntlet is being edited separately and was not modified for this task. No Rust files, runtimes, or export templates were changed.

Input regression checks cover free-pointer deploy/resume, controller selection before menu event consumption, stale deflected axes, ten seconds of neutral/drift input, both vertical look directions, mouse/controller isolation, and R3 recentering. The connected Xbox One S reported neutral axes during diagnosis; the user reported improved behavior after the fix; broader physical-controller qualification remains pending.
