# Blender-authored Gauntlet cast

Original meshes and materials created for Giga Couch with Blender 5.2.2 LTS. No external creature/armor assets or textures were downloaded for this pass. These models supplement the existing, separately credited CC0 Quaternius hero rigs and animation library.

## Models

- `WarriorArmor` / `ValkyrieArmor`: fitted metal cuirasses, layered trim and inset ornament.
- `WizardDetails`: embroidered stole, amulet and spellbook; existing fitted hat and animated robe remain.
- `ElfArmor`: leather vest, leaf-shaped plates, crossbody belt and a stocked quiver.
- `WarriorAxe`, `ValkyrieSword`, `WizardStaff`, `ElfBow`: separate modeled weapons attached to the existing animated hands.
- `WarriorShield` / `ValkyrieShield`: a domed riveted shield and a smaller kite shield, with per-player painted fields.
- `Wraith`: hood, hollow face, spectral eyes, ragged robe and long fingers.
- `Raider`: armored grunt with pointed ears, tusks, bracers, knee guards and a flanged mace.
- `EmberDemon`: curved horns, carmine hide, claws, rib plates and a spined tail.

Source: [`art/gauntlet/cast/gauntlet_cast.blend`](../../../../../art/gauntlet/cast/gauntlet_cast.blend). Generator: [`scripts/blender/create_gauntlet_cast.py`](../../../../../scripts/blender/create_gauntlet_cast.py). The source uses Godot-oriented coordinates converted to Blender Z-up before GLB export. Creature meshes have named arm/leg pivots; no new engine-side skeleton is required.

## Rendering and motion

`cast_assets.gd` caches PackedScenes, so instances share imported geometry. Hero identity cloth uses per-instance overrides backed by immutable cached palette materials, avoiding renderer cleanup errors when lobby portraits are rapidly replaced. Existing hero animation blending, body proportions, player colors, wizard cloth drag, simulation collision and attack balance are retained.

Each creature uses three, seven or eight mesh parts with one vertex-colored surface each. A shared opaque shader adds restrained emission only to the authored bright eye/gem colors. Creature animation runs on the existing presentation tick: footfall follows distance traveled, knees bend under their thigh pivots, torsos shift weight, the demon tail follows through, sleeves drift, limbs settle when movement stops, pause freezes the pose, and attack counters trigger brief swings. Actual successful contact damage and demon projectile emission increment those counters without changing damage or cooldowns. Existing damage overlays and temporary health bars work on the new mesh parts.

## Rebuild / inspect

From the repository root, with the existing Blender and Godot installations:

```sh
"$HOME/Applications/Blender.app/Contents/MacOS/Blender" --background \
  --python-exit-code 1 --python scripts/blender/create_gauntlet_cast.py
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --headless --editor --path sdk --quit
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --rendering-method forward_plus \
  --rendering-driver metal --path sdk --script "$PWD/scripts/preview_gauntlet_cast.gd"
```

Regeneration overwrites the generated source/export files; save manually edited variants separately. The last command renders all four live hero models and the three creatures, writes `art/gauntlet/cast/in_game_cast.png` and `in_game_motion.png`, and exits. It does not start gameplay or send controller feedback. For another OS, choose its supported rendering driver.

These are a stylized cast upgrade, not a claim of finished AAA character production. Full skeletal creature animation, facial animation, texture painting and sustained worst-case combat profiling remain future art work.

Validation: 65 cast/animation assertions, 236 gameplay assertions, 103 audio checks and 374 campaign assertions pass, along with final process return. The live Metal cast render was inspected. The SDK run also passed all other game/input checks.

The polish pass adds rivets, engraved cuirasses and layered faulds, stitched wizard ornament, and fitted ranger pouches. Hero bodies lean into actual travel and breathe subtly without periodic idle attacks. The Warrior now uses a dedicated axe sweep rather than the imported sword swings. `axe_swing.gd` defines windup, blade path, contact window and recovery for both simulation and presentation. `axe_motion.gd` poses the right arm and hand onto the wrapped grip while the legs keep walking. Live skeleton tests compare weapon coordinates with the damage path in four moving/facing directions and check hand contact and pause.
