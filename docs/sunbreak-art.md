# Sunbreak: visual and movement pass

The first playable version is committed as `f9d0a21`. This pass keeps its solo match and free-cursor controls, and improves the environment, first-person presentation, and enemy animation toward the requested AA direction. It does not claim finished AA or Fortnite production quality.

## Assets and rights

All source assets are stored under `sdk/examples/sunbreak/assets`. `sources.json` records per-file origin, license, and SHA-256. The character dependencies are separate copies, so Sunbreak does not depend on changes to Gauntlet's scenes, scripts, or source assets.

- **Quaternius Universal Base Characters, Standard:** humanoid mesh/skeleton and normal/roughness maps, CC0. Reused from the repository's existing licensed assets; skin is recolored as a dark undersuit, with original bone-attached armor, helmet, visor, and weapon. [Source](https://quaternius.com/packs/universalbasecharacters.html). License included at `assets/characters/Base_Characters_License.txt`.
- **Quaternius Universal Animation Library 1, Standard:** free standard archive, CC0. Uses Idle/Pistol Idle, aim, walk/jog, shoot, chest hit, and Death01 clips. The in-place Godot GLB is checked in; no root-motion simulation is imported. [Source](https://quaternius.com/packs/universalanimationlibrary.html). License included at `assets/characters/Animation_License.txt`.
- **Poly Haven Grass Path 2, Rob Tuytel:** 1K diffuse, OpenGL normal, and AO/roughness/metal maps, CC0. [Source](https://polyhaven.com/a/grass_path_2).
- **Poly Haven Rock 01, Rob Tuytel:** 1K diffuse, OpenGL normal, and AO/roughness/metal maps, CC0. [Source](https://polyhaven.com/a/rock_01).
- Architecture, layered armor, first-person weapon and gloves, scenery geometry, shaders, UI, and synthesized sound are authored for Sunbreak.

Texture downloads were checked against the provider's byte counts and MD5 metadata, then recorded with SHA-256. No Godot runtime, export templates, Blender, or other toolchain was installed. Source assets add approximately 27 MB before Godot's local import cache.

## Movement and animation

The physics bodies own gameplay. Imported animations are presentation only. The enemy blends speed-driven locomotion under filtered upper-body aim/fire/hit actions. The pelvis follows travel with a compensating torso turn, both transformed into the parent bone frame so the imported Z-up root cannot roll strafing enemies sideways; backwards movement reverses the locomotion cycle. A hit interrupts charge and briefly slows the body. Death disables enemy collision/scoring immediately and keeps a four-second animated corpse before cleanup.

An A* grid samples actual static collision with actor clearance. Replanning steers around buildings and cover; local separation reduces crowding, and acceleration/braking replaces instant direction flips. Deploying cover invalidates routes. This is an arena-scale navigation implementation, not a general dynamic-world navigation system.

The first-person weapon has a damped recoil spring, look inertia, a moving magazine, and support-hand reload motion. Sprint/aim transitions ease into their pose/FOV. Camera bob, strafe roll, and landing response stay restrained; rifle recoil never changes the camera's aiming pitch. The mouse is never captured. Controller neutral gating and R3 recentering remain intact. Per-axis dead zones prevent small vertical offsets from leaking into horizontal turns. The user's recurring Xbox skyward-drift report still needs physical-controller confirmation after this correction.

## Rendering and measurements

All 34 island rocks and 32 reachable coastal outcrops have convex collision for movement, shots, and navigation; distant islands remain visual scenery.

Repeated static scenery is merged by material and vertex format, leaving collision bodies and signs intact. Wind-driven vegetation uses MultiMesh instances. Textured ground and rock use 1K maps; painted surfaces add restrained detail. The scene retains Forward+ lighting with a Compatibility fallback.

The game previously rendered at the desktop window's native **5120×2584** pixels on this Mac. Balanced now limits 3D rendering to 1920×1080 (1920×969 at that window aspect); UI remains at native resolution. Performance uses a 1280×720 cap without MSAA; Cinematic uses 2560×1440. FSR spatial scaling is used with Forward+, bilinear with Compatibility. The scale has the engine's 0.25 floor. F2 and a pause-menu button select presets.

A short, staged `preview_sunbreak.gd` run on Apple M1 / Metal, with four animated figures and a stationary camera, produced:

| Configuration | Mean frame time | P95 frame time | Reported draw calls |
| --- | ---: | ---: | ---: |
| Native 5120×2584, before static batching | 151.4 ms | 216.1 ms | 1,771 |
| Balanced, 0.375 render scale, 752 meshes merged | 33.3 ms | 33.9 ms | 935 |
| Performance, 0.25 render scale, same batching | 33.3 ms | 33.9 ms | 935 |

Each sample covered 120 frames after 30 warmup frames. These numbers include display/frame pacing and other local system activity; they are not a controlled benchmark, a sustained combat result, a guaranteed frame rate, or evidence of 60 FPS. Performance and Balanced hit the same observed cadence in this sample. Shader compilation on first use occurs outside steady-state expectations.

The preview arranges one enemy near the camera for art review. Its screenshots are staged diagnostic captures of the real renderer, not screenshots from a completed human match. Run with the installed Godot:

```sh
/path/to/Godot --rendering-method forward_plus --rendering-driver metal \
  --path sdk --script res://tests/preview_sunbreak.gd \
  -- --quality=1 --capture=/tmp/sunbreak-enhanced.png
```

Omit `--rendering-driver metal` outside macOS. Quality IDs are Performance=0, Balanced=1, Cinematic=2.

## Checks run and remaining work

The latest `python3 scripts/test_sdk.py` run passed **72 Sunbreak assertions** for combat, input isolation, jump/landing, animated bone movement, hit/death lifecycle, recoil settling, magazine movement, pause, route validity, an actual enemy navigating building cover, rendering caps, and victory/retry. The full suite subsequently stopped on a resource-in-use-at-exit error in the concurrent Gauntlet audio test; Gauntlet was not changed to repair it. The earlier full suite passed before these final regressions were added. Forward+ / Metal gameplay and enemy close-up renders were visually inspected. A render-window version of the keyboard test encountered focus interference while other windows were active; the Sunbreak headless checks pass, and the separate deterministic art preview avoids treating OS focus changes as a gameplay result.

Remaining production work includes sustained full-match performance, physical controller balance and feel, foot-contact/IK polish, more varied buildings/interiors and terrain, more sophisticated tactical enemy behavior, professionally produced audio, richer effects, and Windows testing. Gauntlet files were not changed by this task.

## Xbox release-drift diagnosis

The physical Xbox One S trace reproduced the reported fault after `b25f637`: after right-stick release, X settled near -0.07 while Y progressed through -0.21, -0.33, -0.45, -0.56, -0.66, and -0.75. Camera pitch increased in response. This is a large controller-input signal, not residual camera or rifle recoil. Per-axis dead zones fix small cross-axis offsets but cannot safely suppress this trace while preserving deliberate upward aiming.

Both SDL HIDAPI and Apple's GCController path reproduced a growing upward axis signal. The user additionally reported that it appears when moving, jumping, or firing without touching the right stick. The Apple backend experiment used SDL's documented [Xbox One backend switch](https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE) and [GCController switch](https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_MFI); its launcher overrides were removed because it did not fix the problem. Default launch behavior remains unchanged.

Four additional checks exercise the normal player tick with controlled controller axes: actual movement/jumping/firing together, stable pitch under neutral right-stick input, intentional look during movement/fire, and stopping look on release while movement/fire continue. All **72 Sunbreak assertions pass**. This distinguishes game camera behavior from the non-neutral physical input trace; it does not establish a hardware fix or identify whether the false signal originates in the controller or macOS.

A temporary standalone reader using Apple's GameController framework is being used to compare native input outside Godot. Physical input comparison is pending; the drift is unresolved. No engine replacement, persistent system setting, or Gauntlet modification was made.
