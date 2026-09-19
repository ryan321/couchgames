# Blender art workflow

Blender is an authoring tool for Giga Couch models, shapes, props and animation. Players use the exported assets through Godot and do not need Blender installed.

## Local setup

The development installation is `~/Applications/Blender.app` (official Blender 5.2.2 LTS, Apple Silicon). It occupies approximately 907 MiB. The installer was removed after verifying SHA-256 and macOS notarization. [Official release files and checksums](https://download.blender.org/release/Blender5.2/).

Open it from Finder or run:

```sh
open -a "$HOME/Applications/Blender.app" art/gauntlet/gauntlet_props.blend
```

## First prop study

[Gauntlet source project](gauntlet/gauntlet_props.blend) contains an original brass-bound chest, jade potion flask and ember brazier with a lit studio presentation. [Preview](gauntlet/preview.png). Individual models are in [exports](gauntlet/exports/). Consolidated exports of all three now replace the corresponding live game props; the original study remains editable.

- Editable `.blend` sources live in `art/`, outside the Godot project.
- Export **glTF Binary (`.glb`)** with selected model objects only, applied modifiers, and no presentation cameras/lights.
- Work in meters, with a floor-centered origin. Blender's exporter converts its Z-up coordinates into glTF/Godot Y-up coordinates.
- Use named roots and mesh parts, reasonable polygon counts, and Principled BSDF materials. Bake complex procedural materials to textures before shipping them.
- Copy approved GLBs into the relevant game's `sdk/examples/<game>/assets/` directory. Godot imports them; gameplay collision remains a separate deliberate choice.
- Keep the `.blend` source and corresponding approved exports in version control. Blender backups (`.blend1`, `.blend2`) and rendered experiments should remain local.

Godot recommends glTF and can also import `.blend` by invoking a local Blender installation. Explicit GLB exports keep the game project usable without requiring Blender on every machine. [Godot format/import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

## Rebuild this study

Use the already-installed Blender executable:

```sh
"$HOME/Applications/Blender.app/Contents/MacOS/Blender" \
  --background --python scripts/blender/create_gauntlet_props.py
```

This regenerates the study's `.blend`, three GLBs and preview, replacing those generated files. Save hand-edited variants under a new filename before rebuilding. The script downloads and installs nothing and uses no external assets, textures or add-ons. Materials, meshes and studio lighting are authored for this project. The preview uses Cycles; runtime materials use ordinary glTF properties.

## Verification

Rendered with Blender 5.2.2 Cycles and visually inspected. Godot 4.7.2 loaded each GLB through `GLTFDocument` and instantiated its scene with nonempty geometry and materials on every surface: chest 4,384 triangles, flask 1,984, brazier 4,332. This verifies the authoring/export path; gameplay placement, collision, animation and crowded-scene performance remain separate integration work.

## Live Gauntlet cast

The [cast project](gauntlet/cast/gauntlet_cast.blend) contains the original armor, weapons, shields and three creatures now integrated into Gauntlet. [Godot render](gauntlet/cast/in_game_cast.png). See the [cast asset notes](../sdk/examples/gauntlet/assets/cast/README.md) for generation, animation and rendering details. The hero source rigs/animations retain their existing CC0 attribution.

## Live dungeon environment

The [environment source](gauntlet/gauntlet_environment.blend) and [asset notes](../sdk/examples/gauntlet/assets/environment/README.md) cover eleven modeled props and masonry blocks now used by Gauntlet. [Gathered party](gauntlet/dungeon_party.png), [separated party](gauntlet/dungeon_split_party.png), and [sixteen-player overview](gauntlet/dungeon_sixteen.png) show the live renderer and temporary party fog. The cast preview also includes a [walking/attacking pose](gauntlet/cast/in_game_motion.png).
