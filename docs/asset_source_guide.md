# GigaCouch Asset Sourcing Guide for AI Agents

## Purpose

Use this guide whenever you need external assets while creating or modifying a GigaCouch game.

GigaCouch games are real Godot projects. You may use external:

- 2D art
- sprites
- icons
- UI graphics
- 3D models
- characters
- environments
- props
- textures
- materials
- HDRIs
- animations
- sound effects
- music
- fonts
- shaders
- Godot plugins
- reusable game systems

The goal is to find high-quality assets quickly while preserving the creator's ability to:

- modify the project
- share the game privately
- publish the game publicly
- sell the game commercially
- distribute the game through GigaCouch

Do not assume that an asset found online is legal to use.

---

# Core Rule

Prefer assets with simple, permissive licenses.

Priority:

1. **CC0 / public-domain-style assets**
2. Assets explicitly licensed for commercial games without attribution
3. Assets licensed for commercial games with attribution
4. Paid assets with a clear commercial game license
5. Anything else only after verifying the license

When equivalent assets exist, prefer the asset with the simpler license.

Do not download an asset merely because it is publicly accessible.

---

# Preferred Sources

## 1. Kenney

Website:

[https://kenney.nl/assets](https://kenney.nl/assets)

### Best for

- 2D game art
- sprites
- UI
- icons
- tiles
- platformer assets
- vehicles
- characters
- basic 3D assets
- game audio
- prototypes

### Why prefer it

Kenney is one of the safest default asset sources for GigaCouch projects.

Many Kenney game assets are released under CC0.

### Agent guidance

When the creator does not specify an art source, check Kenney early.

Example:

> Find a simple asset pack for a four-player pirate game.

Search Kenney before attempting to generate every prop individually.

---

# 2. Quaternius

Website:

[https://quaternius.com/](https://quaternius.com/)

### Best for

- stylized 3D games
- characters
- animals
- monsters
- fantasy environments
- medieval environments
- towns
- sci-fi environments
- props
- vehicles
- animation-ready models

### Why prefer it

Quaternius offers large collections of coherent game-ready assets.

This is particularly useful when an entire game should share a consistent visual style.

### Agent guidance

Prefer Quaternius when building stylized 3D games.

Examples:

- dungeon crawler
- fantasy adventure
- racing game
- survival game
- town simulator
- low-poly shooter
- couch multiplayer arena

Verify the current Quaternius license before using assets and record the license in the project.

---

# 3. Poly Haven

Website:

[https://polyhaven.com/](https://polyhaven.com/)

### Best for

- realistic textures
- PBR materials
- HDRIs
- environmental lighting
- realistic 3D objects

### License

Poly Haven assets are generally CC0.

### Agent guidance

Use Poly Haven when the game needs realistic materials or environmental assets.

Examples:

- wood
- stone
- concrete
- metal
- bricks
- floors
- walls
- terrain
- skies
- lighting environments

Prefer Poly Haven over scraping textures from image search results.

---

# 4. ambientCG

Website:

[https://ambientcg.com/](https://ambientcg.com/)

### Best for

- textures
- PBR materials
- surfaces
- terrain materials
- HDRIs

### License

Assets are generally CC0.

### Agent guidance

Use ambientCG when searching for a specific material.

Examples:

- cracked concrete
- worn leather
- marble
- oak flooring
- asphalt
- rusty metal
- medieval stone
- dirt
- mud
- snow
- roof tiles

Use game-appropriate texture resolutions.

Do not automatically download 8K or 16K textures for a game that only needs 1K or 2K versions.

Optimize for reasonable game download size and GPU memory.

---

# 5. [itch.io](http://itch.io) Game Assets

Website:

[https://itch.io/game-assets](https://itch.io/game-assets)

### Best for

- pixel art
- sprites
- characters
- tilesets
- backgrounds
- UI
- icons
- music
- sound effects
- 2D animation
- themed asset packs
- inexpensive indie assets

### Important licensing warning

There is no single [itch.io](http://itch.io) asset license.

Each creator sets their own terms.

### Agent requirements

Before using an [itch.io](http://itch.io) asset:

1. Read the asset's license.
2. Confirm commercial game use is allowed if the project could ever be sold.
3. Determine whether attribution is required.
4. Determine whether modification is allowed.
5. Determine whether redistribution inside a compiled game is allowed.
6. Record the asset creator.
7. Record the asset URL.
8. Record the license.

Do not assume that purchasing an asset automatically allows unrestricted use.

---

# 6. Fab

Website:

[https://www.fab.com/](https://www.fab.com/)

### Best for

- premium 3D models
- environments
- realistic characters
- props
- vehicles
- animations
- VFX
- high-quality materials

### Agent guidance

Use Fab when free sources do not provide sufficient quality.

Fab assets may originally have been designed for Unreal Engine.

Before using an asset in Godot, determine whether the useful files are available in portable formats such as:

- GLTF
- GLB
- FBX
- OBJ
- PNG
- JPG
- EXR
- WAV

Avoid depending on Unreal-specific Blueprints, materials, shaders, or systems unless they can reasonably be recreated in Godot.

Verify the current Fab license before use.

---

# 7. Godot Asset Store / Godot Asset Library

Use the official Godot asset ecosystem when looking for reusable Godot functionality.

### Best for

- shaders
- plugins
- camera systems
- dialogue systems
- inventory systems
- procedural generation
- save systems
- UI helpers
- terrain tools
- navigation helpers
- effects
- development utilities

### Important

Every Godot asset may have its own license.

Inspect the license before incorporating it.

Also inspect the code before introducing a large third-party dependency.

Prefer:

- actively maintained projects
- permissive licenses
- small dependencies
- clear documentation
- Godot versions compatible with the GigaCouch runtime

---

# Sound Effects

## 8. Sonniss

Website:

[https://sonniss.com/](https://sonniss.com/)

Game Audio GDC collections:

[https://sonniss.com/gameaudiogdc/](https://sonniss.com/gameaudiogdc/)

### Best for

Professional sound effects including:

- impacts
- footsteps
- ambience
- machinery
- doors
- weapons
- vehicles
- weather
- animals
- monsters
- UI effects
- foley
- environmental audio

### Agent guidance

Sonniss should be one of the first places checked for high-quality game sound effects.

The free GDC collections are particularly useful for maintaining a reusable sound library.

Verify the license associated with the specific collection being used and record it.

---

# 9. Freesound

Website:

[https://freesound.org/](https://freesound.org/)

### Best for

Very specific individual sounds.

Examples:

- horse walking on gravel
- refrigerator opening
- distant church bell
- squeaky gate
- crowd cheering
- forest ambience
- old engine starting

### Licensing warning

Freesound contains assets under different licenses.

Prefer:

**CC0**

Avoid unnecessary licensing complexity.

If an asset requires attribution, record the attribution requirements.

Do not use a noncommercial license in a game that could later be sold.

---

# Music

Music licensing deserves additional care.

Music can produce copyright claims even when the developer believed the track was reusable.

Whenever possible, use music created specifically for games under a clear game-development license.

---

# 10. [itch.io](http://itch.io) Music Packs

Search:

[https://itch.io/game-assets/tag-music](https://itch.io/game-assets/tag-music)

### Best for

- complete game soundtracks
- looping tracks
- battle music
- menu music
- atmospheric music
- retro music
- fantasy music
- horror music
- cozy music

Using a coherent music pack can create a more consistent game than selecting unrelated tracks from multiple sources.

Always check the individual creator's license.

---

# 11. GameDev Market

Website:

[https://www.gamedevmarket.net/](https://www.gamedevmarket.net/)

### Best for

- music
- sound effects
- 2D assets
- UI
- sprites
- 3D assets

This is useful when the creator is willing to purchase inexpensive professional assets.

Verify the current license before using an asset.

---

# 12. Pixabay

Website:

[https://pixabay.com/](https://pixabay.com/)

### Best for

- music
- sound effects
- photos
- backgrounds
- miscellaneous graphics

### Warning

Exercise extra caution with music.

Some tracks may participate in content-identification systems even when licensed for use.

Keep documentation showing:

- where the track came from
- the creator
- the license at the time of download
- the date downloaded

Prefer dedicated game-music libraries when equally good alternatives exist.

---

# 13. OpenGameArt

Website:

[https://opengameart.org/](https://opengameart.org/)

### Best for

- sprites
- pixel art
- tilesets
- textures
- music
- sounds
- older/open-source game assets

### Licensing warning

OpenGameArt contains multiple licenses.

Inspect each asset separately.

Prefer:

1. CC0
2. permissive commercial licenses
3. attribution licenses when necessary

Do not mix assets into the project without recording the license.

---

# Search Order

When an AI agent needs an asset, use approximately this order.

## Stylized 3D

1. Quaternius
2. Kenney
3. [itch.io](http://itch.io)
4. Fab
5. Generate or create manually

## Realistic 3D

1. Poly Haven
2. Fab
3. [itch.io](http://itch.io)
4. Create or generate

## Textures and materials

1. Poly Haven
2. ambientCG
3. Fab
4. [itch.io](http://itch.io)

## 2D sprites and game art

1. Kenney
2. [itch.io](http://itch.io)
3. OpenGameArt
4. Generate or create

## UI and icons

1. Kenney
2. [itch.io](http://itch.io)
3. Godot asset ecosystem
4. Create or generate

## Sound effects

1. Sonniss
2. Freesound CC0
3. [itch.io](http://itch.io)
4. GameDev Market
5. Generate or record

## Music

1. [itch.io](http://itch.io) game music packs
2. GameDev Market
3. Pixabay with license verification
4. Commission or generate original music

## Godot systems and plugins

1. Official Godot asset ecosystem
2. GitHub repositories with clear licenses
3. Implement directly

---

# Using GitHub

GitHub can be useful for:

- Godot addons
- shaders
- game systems
- procedural-generation tools
- dialogue systems
- utilities
- open-source sample projects

Do not assume code on GitHub is free to use.

Before copying code:

1. Find the repository license.
2. Confirm the license permits the intended use.
3. Record the repository URL.
4. Record the license.
5. Respect attribution or notice requirements.
6. Avoid repositories with no clear license.

"No license" does **not** mean public domain.

---

# Do Not Use Random Google Images

Do not search Google Images, Bing Images, Pinterest, Instagram, ArtStation, DeviantArt, Reddit, or similar websites and simply copy an image into the game.

These websites may help identify:

- visual references
- art direction
- style inspiration

They should not normally be treated as asset libraries.

Finding an image publicly accessible on the internet does not give permission to redistribute it in a game.

---

# AI-Generated Assets

AI generation may be appropriate when:

- no suitable stock asset exists
- the game requires something personalized
- a consistent custom visual style is important
- the asset would be trivial to generate
- the creator wants original characters or locations

AI generation is especially useful for:

- concept art
- backgrounds
- portraits
- UI decoration
- texture variations
- fictional posters
- fictional brands
- game-specific illustrations

Use appropriate tools for:

- images
- 3D
- animations
- sound
- music

Do not intentionally ask an AI generator to duplicate copyrighted characters or protected commercial assets unless the user has the necessary rights.

---

# Prefer Asset Packs Over Random Individual Assets

When possible, use coherent packs.

For example, prefer:

> Quaternius Fantasy Pack

over:

> one tree from one website + one knight from another + one castle from another + random barrels from another.

Asset packs improve:

- visual consistency
- scale consistency
- material consistency
- animation compatibility
- licensing simplicity
- AI understanding
- development speed

---

# Godot Import Preferences

For GigaCouch games, prefer common portable formats.

## 3D

Preferred:

1. `.glb`
2. `.gltf`
3. `.fbx` when necessary
4. `.obj` for simple static objects

GLB/GLTF is generally preferred for Godot.

## Images

Preferred:

- PNG
- WebP
- JPG where lossless transparency is unnecessary

## Audio

Preferred source formats:

- WAV
- OGG
- MP3 where appropriate

Godot may convert or import assets internally.

Keep the original source asset available when practical.

---

# Performance Matters

Do not select assets based only on appearance.

GigaCouch games may run on ordinary family computers rather than high-end gaming machines.

Prefer reasonable:

- polygon counts
- texture sizes
- material counts
- animation complexity
- audio sizes

For example, a background barrel usually does not need:

- 150,000 polygons
- six 8K textures
- multiple expensive shaders

Optimize the asset for its actual role in the game.

---

# Keep Source Assets Organized

Recommended project structure:

```text
assets/
    2d/
    3d/
        characters/
        environments/
        props/
    textures/
    materials/
    audio/
        music/
        sfx/
        ambience/
    ui/
    fonts/
    third_party/

```

Do not place hundreds of unrelated files in one folder.

---

# Asset Provenance

Every externally sourced asset should have provenance information.

Create:

```text
ASSETS.md

```

or:

```text
ASSETS.json

```

in the project.

Record at minimum:

- asset name
- file or folder
- source
- source URL
- creator
- license
- attribution requirement
- date obtained
- whether the asset was modified

Example:

```markdown
## Stylized Fantasy Buildings

Files:
- `assets/3d/environment/fantasy_buildings/`

Creator:
Quaternius

Source:
https://quaternius.com/

License:
Quaternius Asset License

Obtained:
2026-09-19

Modified:
Textures adjusted for this project.

```

Example:

```markdown
## Forest Ground Texture

File:
`assets/textures/forest_ground/`

Source:
Poly Haven

License:
CC0

Obtained:
2026-09-19

```

---

# Attribution File

If any assets require attribution, also maintain:

```text
ATTRIBUTION.md

```

This should contain the exact credits that must eventually appear in:

- the game
- its credits screen
- documentation
- marketplace listing

as required by the relevant licenses.

Do not rely on remembering this at release time.

---

# Commercial-Use Assumption

Unless explicitly told otherwise, assume a GigaCouch project **might eventually be sold**.

Therefore:

Do not use assets restricted to:

- personal use
- noncommercial use
- educational use only

unless the creator explicitly approves that restriction.

A game might begin as:

> "a silly game I'm making for my kids"

and later become something people want to buy.

Avoid introducing licensing problems unnecessarily.

---

# Redistribution vs. Asset Resale

A license that allows use in a game usually does **not** mean the original asset files can be redistributed as an asset pack.

A normal game can contain:

```text
tree.glb
castle.glb
character.png

```

as part of the game's content when the license permits game distribution.

Do not take those files and create:

```text
My Huge Free Asset Pack.zip

```

unless the license specifically permits redistribution of the standalone assets.

---

# Marketplace Assets

If a creator purchases an asset:

- keep proof of purchase
- record the marketplace
- record the asset creator
- record the applicable license
- record the date
- do not expose purchased source assets unnecessarily

Do not assume another GigaCouch creator can reuse an asset merely because one creator purchased it.

Licenses belong to whoever acquired them according to the marketplace's terms.

---

# Asset Selection Philosophy

The goal is not:

> Generate everything with AI.

The goal is:

> Make the best game with the least unnecessary work.

Use existing high-quality assets when appropriate.

Use AI when customization provides value.

Use human-created packs when they provide stronger art direction.

Use procedural generation when scale demands it.

Mix approaches intelligently.

---

# Agent Decision Rule

Before creating a new asset from scratch, ask internally:

1. Does an appropriate reusable asset probably already exist?
2. Can I legally use it?
3. Is its style compatible with the game?
4. Is its performance appropriate?
5. Can I import it cleanly into Godot?
6. Is customizing it easier than creating something new?
7. Can I clearly record its provenance?

If yes, using the existing asset may be preferable.

---

# Asset Search Examples

## Request

> Make a couch multiplayer medieval battle game.

Search:

1. Quaternius for characters, weapons and buildings.
2. Poly Haven or ambientCG for surfaces if more realism is needed.
3. Sonniss for impacts, footsteps and environment sounds.
4. [itch.io](http://itch.io) for music.
5. Godot assets for useful shaders or systems.

---

## Request

> Make a four-player pixel-art fishing game.

Search:

1. [itch.io](http://itch.io) for cohesive pixel fishing/environment packs.
2. Kenney for UI/icons.
3. [itch.io](http://itch.io) for music.
4. Sonniss or Freesound CC0 for water and fishing sounds.

---

## Request

> Make a realistic abandoned-house horror game.

Search:

1. Poly Haven for materials and HDRIs.
2. Fab for environment models and props.
3. Sonniss for doors, impacts, footsteps and ambience.
4. Freesound CC0 for unusually specific environmental sounds.
5. [itch.io](http://itch.io) or GameDev Market for horror music.

---

# Sources to Treat With Extra Caution

Exercise caution with:

- random web image results
- Pinterest
- social-media posts
- ripped video-game models
- fan asset websites
- ROM/game-extraction websites
- models ripped from commercial games
- copyrighted character packs
- unofficial soundtrack downloads
- YouTube audio extracted from videos
- "free download" mirror websites
- assets with no identifiable creator
- assets with no license
- repositories with no license

If licensing cannot be determined, find a different asset.

---

# Final Checklist

Before considering a third-party asset successfully incorporated, verify:

- Source is known.
- Creator is known when applicable.
- License has been checked.
- Commercial use is allowed if needed.
- Modification is allowed if modification is needed.
- Game distribution is allowed.
- Attribution requirements are known.
- Asset provenance has been recorded.
- Required attribution has been recorded.
- File format imports properly into Godot.
- Asset performs appropriately on target hardware.
- Asset fits the game's visual or audio style.
- The project does not depend unnecessarily on proprietary engine-specific functionality.

---

# Default Recommendation

When no better reason exists to choose something else:

```text
2D / UI:
Kenney + itch.io

Stylized 3D:
Quaternius

Realistic materials:
Poly Haven + ambientCG

Premium 3D:
Fab

Sound effects:
Sonniss + Freesound CC0

Music:
itch.io + GameDev Market

Godot functionality:
Official Godot asset ecosystem

Custom/personalized content:
AI generation or original creation

```

Favor assets with clear licensing, portable formats, coherent visual style and reasonable performance.

The objective is to let the creator or AI agent spend its time making the **game**, rather than recreating every tree, footstep, button icon, wall texture and music track from scratch.