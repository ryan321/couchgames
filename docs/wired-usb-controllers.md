# Wired USB controllers on macOS

macOS Game Controller / HID already covers DualShock 4, DualSense, Xbox Bluetooth, Switch, and most HID USB pads. Godot sees those without a helper. Press A / Cross to join.

Some cheap “PS4/PC” and Xbox 360-style wired pads talk **Xbox 360 XID** over a vendor-class USB interface (`ff:5d:01`). Darwin never binds that class, so Little World would not see them. The host helper `tools/macos/xpad_reader.m` claims those devices, parses 20-byte `00 14` reports, and publishes `COUCH_XPAD_NATIVE_STATE`. `native_xpad.gd` turns that file into standard gamepad events.

This is the same host-file pattern as the native Wii reader. It is not a kernel driver and it is not used for HID pads.

## Run

```sh
python3 scripts/play.py
```

If a vendor-class USB pad is plugged in, play.py starts the helper. Keep the **wired USB reader** window open. `python3 scripts/play_xpad_native.py --check` only confirms reports.

Quit Chrome/Brave if they grabbed the USB device. F3 shows whether the helper is live.

## What is claimed

The helper walks every `IOUSBHostDevice`, reads its configuration descriptor **before** `SetConfiguration`, and claims a pad only when `xpad_lookup` in `tools/macos/xpad_devices.h` returns `XPAD_PROTO_XID360`. HID interfaces (class 3), hubs, NICs, and disks are skipped.

Unknown VID/PID still matches if the interface is Xbox 360 XID. Named rows override the generic name and can set quirks.

## Add a controller

1. Plug it in and note USB vendor/product (`ioreg -p IOUSB -l` or System Information).
2. If macOS already lists it as a gamepad, do nothing — Godot will use it.
3. If it is vendor-class XID (`ff:5d:01`), it should work through the generic match. Add a named row only to label it or set quirks:

```c
{0x1234, 0x5678, "Example Pad", XPAD_PROTO_XID360, 0},
```

4. If it uses another protocol (Xbox One GIP, DualShock HID over a vendor class, etc.), add `XPAD_PROTO_…` and a decoder next to `xpad_decode` in `xpad_reports.h`. Do not put USB code in the Godot game.

Rebuild happens automatically from `play.py` when the helper sources change. Physical join still needs a button press after launch.

Xbox One/Series **wired** GIP pads are not implemented. Touchpad, headset jack, and rumble are out of scope.
