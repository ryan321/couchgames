# Wireless controllers and sixteen-player validation

## Requirement and current evidence

The platform targets **sixteen local players**, including wireless Xbox and PlayStation controllers and mixed groups. The SDK, sample, and package schema accept sixteen slots. Godot 4.7.2 has sixteen joystick slots in its [input implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/core/input/input.h#L104).

This is a software capacity, not a guarantee that every radio/driver/OS combination connects sixteen devices. Windows XInput is capped at four; Godot uses SDL3 but its controller documentation still notes Windows limits. Do not advertise a tested sixteen-wireless-controller configuration until physical tests prove it. [Godot controller documentation](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html)

## Pair with the computer

Controllers pair with the PC or Mac running the game. The TV displays the computer via HDMI or screen sharing. Pairing to the TV does not automatically forward controller input to the computer.

### Xbox over Bluetooth

On this Mac, target Xbox Series X/S controllers, Bluetooth-capable Xbox One model 1708, or Elite Series 2. Turn on the controller, hold its pairing button, then select it in **System Settings → Bluetooth**. Older Xbox controllers without Bluetooth need a compatible connection/adapter; do not assume every model with “wireless” in its name supports Bluetooth. [Apple's Xbox setup and supported models](https://support.apple.com/en-us/111101)

For Windows, use the controller's supported Bluetooth or Xbox Wireless connection and follow [Microsoft's PC setup instructions](https://support.xbox.com/en-US/help/hardware-network/controller/connect-xbox-wireless-controller-to-pc). Receiver and API capacity must be recorded with test results; an adapter is not assumed to remove the sixteen-controller validation requirement.

### PlayStation over Bluetooth

With the controller off and disconnected from USB, hold **PS + Create** on DualSense or **PS + Share** on DualShock 4 until its light flashes. Select it in the computer's Bluetooth settings. [Apple's PlayStation setup](https://support.apple.com/en-us/111100), [Sony's DualSense PC/Mac guide](https://www.playstation.com/en-us/support/hardware/pair-dualsense-controller-bluetooth/)

In Little World, press Xbox **A** or PlayStation **Cross** to join. Left stick/D-pad moves, the same south face button jumps, and holding B/Circle leaves. F3 shows the device names and mapping status reported by Godot. Basic movement/buttons are the current implementation; advanced DualSense features and haptics are not implemented.

## Test matrix

Updated September 15, 2026. The user connected two Xbox Wireless Controllers over Bluetooth on this Mac and confirmed both work in the game, including the left stick. Exact controller models and firmware have not been recorded. The updated disconnect-removal flow still needs physical confirmation. “Pending” means no physical verification of that case in this project.

| Host / connection | Controller group | Counts to test | Status |
| --- | --- | --- | --- |
| macOS ARM64 / Bluetooth | Xbox Wireless Controllers (exact models unrecorded) | 1, 2 | Playable; user-reported. Updated disconnect removal pending |
| macOS ARM64 / Bluetooth | Xbox Series / Bluetooth Xbox One | 4, 8, 16 | Pending |
| macOS ARM64 / Bluetooth | PS5 DualSense / PS4 DualShock 4 | 1, 2, 4, 8, 16 | Pending |
| macOS ARM64 / Bluetooth | Mixed Xbox + PlayStation | 2, 4, 8, 16 | Pending |
| Windows / Bluetooth | Xbox, PlayStation, mixed | 1, 2, 4, 8, 16 | Pending |
| Windows / supported Xbox receiver(s) | Xbox, plus PlayStation Bluetooth | 4, 8, 16 | Pending |
| macOS + Windows / USB and mixed USB/Bluetooth | Xbox + PlayStation | 1, 4, 8, 16 | Pending |
| macOS ARM64 / synthetic mapped events | Sixteen independent device IDs | 16 | SDK and scene/physics checks passed |
| macOS ARM64 / Bluetooth | Wii Remote Plus RVL-CNT-01-TR | 1 | Standard pairing hit PIN prompt; helper 1.2.1 failed with incorrect-PIN log; release, local diagnostic build, and game-closed attempt all failed before input; PIN callback absent; compatibility unverified |
| macOS ARM64 / Bluetooth + native reader | Nintendo RVL-CNT-01, reported 04e8:7021 | 1 | Connected with 0000; user-confirmed movement/jump via live native bridge. Saved launcher, reconnect, mixed play pending |
| macOS + Windows / Bluetooth | Wii Remote / Remote Plus | 1, 2, 4, 8, 16 | Experimental profiles and scoped D-pad correction; physical pairing/input pending |
| macOS + Windows / Bluetooth through Remote | Nunchuk, Classic, Classic Pro | 1, 2, mixed | Experimental profiles; physical tests pending |
| macOS + Windows / Bluetooth | Wii U Pro | 1, 2, mixed | Experimental profile; physical tests pending |
| macOS ARM64 / synthetic mapped events | Five Wii family profiles + mixed standard gamepad | Per-profile and mixed | 53 assertions passed; no physical Wii verification |

See [Wii setup and family coverage](wii-controllers.md) for the explicit startup flag, pairing investigation, and remaining accessory work. A Wii device appearing in Bluetooth is not sufficient: record its Godot name/GUID and verify actual button/axis events.

For each physical session, record OS/version, Godot version, controller model/firmware, adapter/receiver model and driver, connection type, connected count, joined count, and latency/dropouts. Distinguish a device visible in OS Bluetooth from one actually reported to Godot.

1. Join every controller and confirm unique player numbers. Move and jump simultaneously; no device may affect another character.
2. Disconnect one while moving, then two identical controllers. Their characters disappear and their slots become free. Reconnect in reversed order and press A / Cross once on each: each gets a fresh character without changing other active players or accumulating inactive characters.
3. Leave and join again; test full capacity, mixed controller brands, and a seventeenth input source.
4. Run a sustained session, then test focus switching and computer sleep/wake. Record drift, repeat jumps, stuck buttons, disconnects, and recovery.
5. Repeat on a TV via direct connection and one screen-sharing setup. Record readability and added input/display latency.

Source-project checks do not validate exported PCK execution, Bluetooth capacity, haptics, or OS isolation.
