# Pocket Rally

A local multiplayer 3D driving prototype for 1–16 players. Each driver gets a chase camera: two side-by-side views, four in a 2×2 grid, and up to sixteen in a 4×4 grid. All cameras show the same world, cars, and physics. Join or leave at any time; the grid resizes automatically.

Drive clockwise around the oval, cross four ordered checkpoints, and build up laps. Grass slows cars; the outer barrier contains them. Cars collide with one another. There are no items, AI opponents, online multiplayer, or finish-line race results yet.

## Play with the Wii Remote on this Mac

Close the other game and Wii reader first. Pair the previously tested `Nintendo RVL-CNT-01` variant (`04e8:7021`) with the computer, then run:

```sh
python3 scripts/play_wii_native.py --game pocket-rally
```

1. Each player holds their Remote sideways, **D-pad left, 1/2 buttons right**.
2. Press **2** to join and hold a comfortable, near-level grip steady for one second. Each player calibrates separately.
3. Turn it like a steering wheel: lower the left end to turn left, or the right end to turn right. About 30 degrees gives full steering.
4. Hold **2** for gas. Hold **1** to brake, then reverse when stopped.
5. Press **Home** to return your car to its starting position and recalibrate. Hold **minus** to leave.

If motion stops arriving, only that car stops and requests calibration. A native device removal deletes its car and camera; a stopped file stream expires after two seconds. Reconnect and press 2 to join again. Completed laps survive Home rescue; an incomplete lap does not. **New race** resets every driver's laps and position.

**F11** or the button toggles fullscreen; **Esc** quits. Each view has a **Use stick / Use tilt** button for that player's input mode. On a Wii Remote, stick mode uses the sideways D-pad.

## Other controllers and keyboard

```sh
python3 scripts/play.py --game pocket-rally
```

- Xbox / PlayStation: **A / Cross** joins and accelerates, **X / Square** or left shoulder brakes/reverses, **left stick / D-pad** steers, **Menu / Options** rescues. Hold **B / Circle** to leave.
- Keyboard: **Enter** joins, **W / Up / Space** accelerates, **S / Down** brakes/reverses, **A/D or Left/Right** steers, **R** rescues, **Backspace** leaves. One keyboard consumes one of the sixteen slots.
- Original Switch controller profiles and available motion use the existing SDK adapter; `--joycons paired` selects a combined grip instead of separate sideways Joy-Cons. Switch hardware qualification remains pending. Switch 2 needs a compatible driver; use the on-screen stick fallback if motion is unavailable. See [coverage](../../../docs/switch-controllers.md).
- Standard Nintendo Wii devices can try `--wii` through the engine driver; those devices, extensions, and their motion orientations have not been qualified in this driving game.

## Implementation and verification

This game has its own steering, cars, track, UI, and native multi-Remote adapter. Cloudbound's game files, controls, shared motion service, and original single-device reader are preserved.

The driving launcher builds `tools/macos/wii_fleet.m` with the existing macOS compiler. This separate helper opens up to sixteen matching `04e8:7021` devices, keeps independent report buffers and factory calibration, and atomically writes one private session snapshot per Remote. Connection generations prevent a reused device slot from inheriting the previous player's car. Four physical player LEDs repeat; the game identifies all sixteen players on screen. The original single-Remote helper remains the path for Little World and Cloudbound.

The helper reuses the existing button/acceleration decoder. It does not pair controllers, add extension decoding, or use MotionPlus gyroscopes or IR. Snapshot motion expires after 250 ms. This file bridge can miss very brief presses; it is a prototype rather than a lossless controller transport.

Run `python3 scripts/test_sdk.py` for automated verification. Rally checks exercise sixteen synthetic native channels, join limits, separate viewports sharing one world, independent calibration and steering, actual car motion/collisions, lap checkpoints, disconnects, reused slots, and rejoining. Rendered 2-, 4-, and 16-player views have been inspected on this Mac. Shadows are disabled above four players to reduce rendering work.

The saved driving launcher opened the helper and game on this Mac and received live motion and factory calibration from one connected Remote.

Physical steering feel, multiple Wii Remotes, mixed controllers, sustained sixteen-view performance, reconnects, and TV readability/latency still need real hardware tests. Sixteen software slots do not establish Bluetooth capacity.
