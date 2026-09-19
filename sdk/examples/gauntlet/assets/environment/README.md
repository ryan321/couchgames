# Original Blender dungeon assets

Eleven original GLBs authored for Giga Couch, with no new downloads or external dependencies. Players do not need Blender.

- **VaultChest, JadePotion, EmberBrazier:** consolidated versions of the original prop study, now used for treasure, potions and torches.
- **RunicKey, FeastPlatter:** carved key and a pewter platter with roast, bread and fruit. Key tint still matches the lock.
- **SummoningAltar:** stepped carved stone, brass cradle and jade ornament; the existing animated crystal remains separate.
- **CeramicUrn, OakBarrel, WingRelief:** glazed vessels, bound oak staves and carved wall tablets. Tall dressing stays on existing solid masonry and away from doors.
- **FloorGrate:** a recessed iron grate used as a room-floor motif.
- **DressedStone:** beveled unit block, instanced in the existing masonry batches with the scanned stone materials.

The runtime caches scenes and shares mesh resources. Every prop is one mesh with a small number of material surfaces. Decoration adds no collision or navigation obstacles. Floor motifs alternate between bronze/jade mosaics, fringed runners, drains and worn stone details; their three-by-three footprint must avoid walls and doors.

## Rebuild

Run explicitly from the repository root using the existing Blender installation:

```sh
"$HOME/Applications/Blender.app/Contents/MacOS/Blender" --background \
  --python-exit-code 1 --python scripts/blender/create_gauntlet_environment.py
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --headless --editor --path sdk --quit
```

This overwrites `art/gauntlet/gauntlet_environment.blend` and these exports. It reuses the checked-in study exports in `art/gauntlet/exports/` and the cast generator's geometry helpers. Save hand-edited variants separately before regenerating.

`test_gauntlet_visibility.gd` checks shared geometry and the current-sight policy. `scripts/preview_gauntlet_dungeon.gd` renders gathered, separated and sixteen-player views using the actual dungeon scene. These checks do not establish sustained frame rates or physical controller compatibility.
