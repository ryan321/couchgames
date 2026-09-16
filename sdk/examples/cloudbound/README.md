# Cloudbound

A single-pilot 3D flying game for Wii tilt controls. Fly a coral-and-cream glider through golden rings over floating islands. The course loops; missing a ring keeps you flying. Uses the same installed Godot as Little World, with original procedural art and no asset downloads.

## Play on this Mac

Pair the observed `Nintendo RVL-CNT-01` (`04e8:7021`) in macOS Bluetooth settings. Close any old standalone Wii probe/game first, then:

```sh
python3 scripts/play_wii_native.py --game cloudbound
```

The explicit developer launcher compiles the small reader with the existing Xcode compiler if needed. It launches the reader and game together and stops the reader when the game closes. No engine, export templates, or compiler are installed.

1. Hold the Remote **sideways: D-pad on the left, 1/2 buttons on the right**. Keep both ends at about the same height, with buttons facing up or comfortably angled toward you.
2. Press **2** (or **A**) to join, and hold your comfortable sideways grip steady for one second. The calibration indicator reaches 100%, then flight begins.
3. Turn like a steering wheel: lower the left end to bank left, or the right end to bank right. **Roll away from your body to dive; roll toward yourself to climb.** About 30 degrees reaches full steering.
4. Hold the underside **B trigger** to boost. Press **2** to pause and recenter with another steady pose. Hold **minus** to leave.
5. **F11** or the fullscreen button toggles fullscreen. **R** or Restart flight resets the course; **Esc** closes the game.

The dot shows steering; the motion line shows live acceleration. If samples stop, the game pauses and requires a fresh steady pose. A controller disconnect removes the pilot; reconnect and press 2 to join again.

This sample uses **one pilot**, and the native reader supports **one observed Wii variant**. Little World retains its sixteen-player slots. The saved launcher opened both apps on this Mac and received fresh acceleration reports with valid factory calibration from the connected Remote. The user confirmed flight works and reported reversed banking in the original lengthwise grip. The game now uses the requested sideways grip; the user confirmed the revised sideways controls work; reconnect still needs physical confirmation. No MotionPlus gyroscope or IR/sensor-bar input is used.

## Keyboard / normal gamepad

```sh
python3 scripts/play.py --game cloudbound
```

Enter joins; arrows/WASD steer, Up/W climbs, Space gives a short boost, Backspace leaves. Standard controller: A/Cross joins and boosts, left stick steers, hold B/Circle to leave. Original Switch Joy-Con / Pro controllers can use the shared engine motion path here without the native helper. Single Joy-Cons are sideways with SL/SR edge up; add `--joycons paired` for a pair in a grip. Press a face button, then hold steady. Lower face recenters, shoulder boosts; M / Menu or the button switches between tilt and stick. Switch hardware tests remain pending; Switch 2 needs a compatible driver. See [controller coverage](../../../docs/switch-controllers.md).

## Implementation and checks

- `flight.gd`: course, swept ring crossings, bounded flight area, disconnect pause, and UI.
- `flight_controls.gd`: steady-pose calibration, dead zone, acceleration-spike rejection, time-based smoothing.
- `Platform.motion.sample_for_player(id)`: fresh acceleration in Wii hardware axes, in g including gravity; empty dictionary when unavailable. See the SDK README.
- Native report `0x31` includes buttons + acceleration, decoded by `tools/macos/wii_reports.h`. A read-only EEPROM request loads valid factory calibration; otherwise nominal scaling is marked `approximate`. No EEPROM writes.
- Native snapshots are rate-limited to 50 Hz with immediate button changes; SDK motion expires after 250 ms. This is a prototype file bridge, not a lossless event stream.

Run `python3 scripts/test_sdk.py` for synthetic motion and scene checks. On a machine with an existing C compiler, also run:

```sh
cc -Wall -Wextra -Werror tools/macos/test_wii_reports.c -o /tmp/couch-wii-report-tests
/tmp/couch-wii-report-tests
```

Protocol references: [WiiBrew report modes and acceleration](https://wiibrew.org/wiki/Wiimote), [Godot's pinned SDL Wii decoder](https://github.com/godotengine/godot/blob/4.7.2-stable/thirdparty/sdl/joystick/hidapi/SDL_hidapi_wii.c). Physical tilt direction, smoothness, reconnect, and performance remain manual acceptance checks.
