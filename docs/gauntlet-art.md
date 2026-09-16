# Gauntlet art direction and asset pipeline

## Target

Stylized fantasy with believable materials, warm fire against cool shadows, readable silhouettes, and animated characters. The September 15, 2026 pass establishes the rendering and asset foundation for that direction. It is not a claim of finished AA/AAA production quality.

Implemented:

- Textured humanoid models with shared skeletal idle, walk, attack, and casting clips; class-colored equipment and live character portraits.
- Scanned stone albedo, normal, roughness, and ambient-occlusion textures; metal reflections, torch flames, gate arches, banners, and a hall runner.
- Forward+ selected per game, with Metal on macOS, ambient occlusion, restrained volumetric haze, glow, and directional shadows. The global project renderer stays unchanged for the other games.
- Wider party-following shared camera, immediate zoom-out to include spread-out and fallen players, F3 full-dungeon overview, minimap, and low foreground masonry for visibility.
- F2 performance mode removes expensive lighting/shadows, disables MSAA, and renders the 3D scene at 75% resolution in Forward+. The HUD stays at its normal resolution. Toggle again to restore cinematic settings.
- `python3 scripts/play.py --game gauntlet --compatibility` and the equivalent native Wii command use the older renderer when Forward+ cannot start. F2 does not switch renderers while a game is running.

## Sources and licenses

Only free standard packs were downloaded. No paid assets, editor versions, or export templates were purchased or installed. Assets load locally without a network request.

| Asset | Source | License |
| --- | --- | --- |
| Ranger and peasant outfits, rigged glTF | [Quaternius Modular Character Outfits — Fantasy](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html) | CC0 1.0; included `characters/License_Standard.txt` |
| Male/female heads, eyes, eyebrows, textures | [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) | CC0 1.0; included `characters/Base_Characters_License.txt` |
| In-place animation source GLB | [Quaternius Universal Animation Library 2](https://quaternius.com/packs/universalanimationlibrary2.html) | CC0 1.0; included `characters/Animation_License.txt` |
| 2K scanned floor maps | [Poly Haven Monastery Stone Floor](https://polyhaven.com/a/monastery_stone_floor) | [CC0](https://polyhaven.com/license) |
| 1K scanned wall maps | [Poly Haven Medieval Wall 01](https://polyhaven.com/a/medieval_wall_01) | [CC0](https://polyhaven.com/license) |

The selected source assets occupy approximately **126 MiB**, before Godot's generated import cache. Unpacked FBX/Blender duplicates and temporary download archives are not retained. Source file hashes and archive paths are recorded in [`sources.json`](../sdk/examples/gauntlet/assets/sources.json). Texture `.import` settings enable GPU compression and mipmaps; character textures have a 1024-pixel import limit. Original files remain available for higher-resolution imports later.

`hero_actor.gd` extracts head triangles from the supplied base meshes, preserves their UVs/materials, attaches them to the outfit's head bone, and reuses the common skeleton animation paths. Equipment attaches to bones. Animation is visual only: controller ownership, position, damage, and collisions still belong to the existing simulation. Stone meshes and static creatures are batched/shared; effects use a bounded pool.

## Character movement revision — September 16

`hero_motion.gd` uses a separate Godot AnimationTree per hero. Idle-to-walk blending affects the pelvis and legs, while filtered one-shot actions affect the spine, arms, and head. Walking therefore continues during attacks. Actual position changes drive stride speed, so pressing against a wall settles into idle; visual turning and stopping ease over a short interval. [Godot AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html), [filtered one-shot animations](https://docs.godotengine.org/en/stable/classes/class_animationnodeoneshot.html).

Monotonic attack, potion, and hit counters connect presentation to the simulation's actual events. Damage immunity after revival does not generate a fake hit reaction. Weapon animation duration follows each class's existing firing cadence. Warrior/Valkyrie alternate swing clips, the Wizard holds the staff with his right hand and casts with his left, and the Elf uses newly authored arm poses based on the existing skeleton. The attack layer is independent from potion casting and hit reactions. Animation does not advance while paused. Knockdown/revival blend the model without tipping its player label.

Equipment now includes beveled metal blades, wrapped handles, smaller rimmed/riveted shields, an open recurved bow, restrained steel helmets, and muted class clothing. The wizard has a pleated long robe with a front opening, fitted sleeves, layered beard, curved felt brim and bent crown, leather hatband, and a crooked wooden staff. His robe and hat use a matte cloth shader, with subtle motion at the robe hem. A stale local male-head import was rebuilt to restore missing face/eye textures; tests now require the head materials to retain their texture maps. These are local code-generated additions to the existing CC0 models; no additional packs were downloaded. The underlying attacks retain the existing ranged game rules.

## Verification and practical limits

- Full SDK checks include the existing solo and 16-player dungeon routes, controller-start regression, independent escapes, and actual process exit after victory.
- Added tests require walk playback to change the imported leg pose and require all sixteen spread-out heroes' feet and labels to project inside the shared viewport.
- Python library tests cover game-specific graphics selection, macOS Metal arguments, explicit compatibility fallback, and unchanged renderer selection for the other games.
- Rendered inspection uses the installed Godot 4.7.2 on an Apple M1. Short render samples are diagnostic measurements, not sustained frame-rate or physical controller qualification.

At a 4593 × 2584 captured window size, a baseline 120-frame wide-view sample taken before the character-movement revision with sixteen heroes spread across the map and 96 synthetic monsters took **4.103 seconds (29.2 FPS)** with cinematic settings and **4.159 seconds (28.9 FPS)** with performance settings. These runs do not establish a frame-rate improvement from the performance preset; CPU work, presentation pacing, and sustained combat still need profiling. The test renders the scene but does not run a physical 16-controller session. Both Forward+/Metal and Compatibility captures passed the game assertions without script/render errors.

The current monsters, some equipment, pickups, and effects remain prototype art. The next quality pass needs a coherent custom creature/armor set, better weapon silhouettes and attack-specific animation, richer environment composition, impact VFX/audio, accessibility/TV inspection, and sustained performance profiling. Target 60 FPS during normal play and qualify worst-case 16-player combat on each supported hardware tier before calling the presentation complete.
