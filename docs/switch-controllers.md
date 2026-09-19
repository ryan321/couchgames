# Switch controllers and shared motion input

## Current coverage

| Controller | SDK / Cloudbound implementation | Hardware status |
| --- | --- | --- |
| Original Switch Pro Controller | Auto-detected profile; engine motion, normal grip | Physical test pending |
| Original Joy-Con (L) or (R) | Separate player by default; sideways, SL/SR edge up; driver normalizes axes | User paired both halves over Bluetooth on this Mac and reached Little World join/move/fall. A combined/MFI copy of the pair also joined, so one A press created two players and a later jump/respawn created a third that shared input. SDK now ignores that duplicate; physical retest pending |
| Original Joy-Con pair in a grip | Explicit paired mode; engine uses right Joy-Con's motion as the shared sensor | Physical test pending |
| Switch 2 Pro; Joy-Con 2 left, right, or pair | Profile recognition; uses motion only if the host driver exposes it; explicit unavailable state and stick fallback | **Native driver missing in pinned runtime; not claimed supported** |
| Third-party Switch-compatible controllers | Generic buttons/sticks; motion selected only from reported capabilities | Model/firmware/connection dependent; not all have sensors |
| Observed Wii Remote `04e8:7021` | Existing native reader, sideways grip | User confirmed flight and revised direction controls |

Godot 4.7.2 includes SDL **3.2.28**. Its source contains the original Switch driver but no dedicated `SDL_hidapi_switch2.c`. Newer upstream SDL has a Switch 2 driver, but its presence upstream does not add it to our installed engine or establish Bluetooth compatibility on this Mac. Full Switch 2 support needs a separately validated runtime/driver integration and hardware acceptance. No runtime or toolchain was installed or upgraded for this change.

## Play

Pair controllers with the **computer**, then run:

```sh
python3 scripts/play.py --game cloudbound
```

A single Joy-Con is held horizontally, SL/SR edge up, buttons facing you/up. Pro controllers and a paired grip use their ordinary two-handed grip. Press a face button to join; hold steady for one second. Bank left/right and roll away from your body to dive, toward yourself to climb. The lower face button recenters; either shoulder (SL/SR on a single Joy-Con) boosts. Hold the right face button to leave.

The launcher defaults to separate Joy-Cons so two halves can be two players in multiplayer games. Cloudbound itself remains single-pilot. For a combined pair in a grip:

```sh
python3 scripts/play.py --game cloudbound --joycons paired
```

These options also work with Little World and `play_wii_native.py`. The native Wii launcher is needed only for the observed Wii variant, not original Switch controllers. Restart the game to change separate/paired mode. Direct editor launches follow their inherited SDL settings instead of the launcher's explicit policy.

On macOS, SDL can list both HIDAPI Joy-Con halves and a combined Apple/MFI copy of the same controllers. Join and jump use the same south face button, so that extra device used to become another player the next time someone jumped or fell. The SDK ignores the combined copy when separate halves are connected, and ignores the halves when paired grip mode is on. Two physical Joy-Cons remain two players. F3 labels an ignored copy as **duplicate ignored**. This is a software guard, not a claim that every Switch pairing path is qualified.

Godot may also print `Error opening gamepad at index N: Couldn't load stick calibration` from `drivers/sdl/joypad_sdl.cpp` while opening an extra Switch-family pad. The index is SDL's device id, not a player number. SDL's Switch HIDAPI driver failed to read that pad's stick calibration, so Godot skips it and it never becomes a connected controller. Observed here with two Bluetooth Joy-Cons after the join-guard fix: play still used the two halves. We cannot hide that engine line from the game. If a connected Joy-Con's stick actually drifts, that is a separate calibration problem on a pad that *did* open.

If motion isn't available, the game says so. Press **Menu / + / −**, **M**, or click **Use stick** to select stick control. Keyboard Enter/arrow keys/Space remain available. Losing a selected motion stream pauses flight; it does not silently swap control modes.

Button names here assume the stock SDL position mappings. Third-party remapping tools may change them. A profile identifies layout; it does not prove that the OS exposes that device's sensors.

## SDK integration

`Platform.motion.set_enabled(true)` opts the current game into polling controller sensors. It uses `Input.has_joy_motion_sensors()` and enables supported sensors, including devices connected after launch. Stop with `set_enabled(false)` when leaving the game. Only sensors enabled by this service are disabled; existing requests are left alone.

`sample_for_player(id)` and `sample_for_device(id)` return `{}` when unavailable, or a dictionary:

- `acceleration`: `Vector3`, g including gravity. Shared grip coordinates: **+X toward the player, +Y right, +Z out through the buttons** (up with the controller held flat).
- `updated`: Unix seconds.
- `source`: `native` or `godot`.
- `calibration`: native `factory` / `approximate`, or `driver` (not an SDK-verified calibration).
- `freshness`: native `report` or engine `polled`.
- `gyroscope`: present on the engine path, raw Godot X/Y/Z angular rates in rad/s. Cloudbound uses acceleration, not gyro integration.

Godot negates SDL acceleration and reports m/s². The adapter converts units and axes once. SDL already rotates a separate Joy-Con into its horizontal grip; the SDK does not rotate it a second time. Paired Joy-Cons use the right sensor through the ordinary engine sensor API.

Samples expire after 250 ms without an SDK update. **Godot exposes polled values without a hardware timestamp**, so repeated values cannot distinguish a perfectly still controller from a frozen driver cache. The engine path detects disconnect, disabled/missing sensors, invalid values, and stopped SDK polling; it cannot promise to detect every frozen radio stream. Native Wii timestamps come from actual HID reports.

## Verification

`python3 scripts/test_sdk.py` includes profile recognition/join, per-device motion, zero/invalid data, hotplug/reused IDs, sensor cleanup, four-direction pose fixtures, actual non-Wii motion-to-flight, pause, and explicit stick-fallback checks. These are synthetic tests, not radio/hardware qualification.

Manual acceptance remains: each original Joy-Con independently, the pair, Pro, then Switch 2 with a working driver; test pairing, neutral calibration, all four motion directions, buttons, reconnect, mixed Wii/Switch use, and multi-controller capacity. Do not advertise sixteen physical wireless controllers based only on software slots.

## Source evidence

- [Pinned Godot SDL sensor adapter](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/sdl/joypad_sdl.cpp)
- [Pinned original Switch driver](https://github.com/godotengine/godot/blob/4.7.2-stable/thirdparty/sdl/joystick/hidapi/SDL_hidapi_switch.c)
- [Godot motion API](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-get-joy-accelerometer)
- [SDL Joy-Con pairing mode](https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_COMBINE_JOY_CONS)
- [SDL Joy-Con horizontal/vertical mode](https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS)
- [Upstream Switch 2 driver](https://github.com/libsdl-org/SDL/blob/main/src/joystick/hidapi/SDL_hidapi_switch2.c)
