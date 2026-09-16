# Wii controllers (experimental)

The platform targets the Wii controller family alongside Xbox and PlayStation. Basic input profiles are implemented for the core controllers below. **One `Nintendo RVL-CNT-01` variant (`04e8:7021`) has user-confirmed movement and jumping through our native macOS reader.** Other profiles and controller counts remain unverified. Bluetooth pairing, driver detection, mapped input, and reliable simultaneous play are separate acceptance checks.

## Working native path for the tested Remote

After closing the standalone input probe and previous game window:

```sh
python3 scripts/play_wii_native.py
```

This explicit developer command builds `tools/macos/wii_reader.m` using the existing macOS compiler (no downloads), caches the app under ignored `.couchgames/`, and starts the reader and normal game. It matches only vendor `04e8`, product `7021`, name `Nintendo RVL-CNT-01`. Pair the Remote with the computer first; the user successfully used `0000` for this particular device.

Hold sideways with 1/2 on the right. **2** joins/jumps, D-pad moves, and hold **minus** to leave. This native prototype does not map plus to fullscreen; use the on-screen button or F11. The reader supports one Remote per session; Xbox/PlayStation can use the other regular player slots, but that mixed physical session has not yet been tested.

The native process initializes LED/status/button reports and atomically writes button state into a private temporary session directory. The SDK reads the host-provided `COUCH_WII_NATIVE_STATE` file, converts bit changes to per-player actions, and removes the player if the state disappears or becomes over two seconds old. Closing the game stops the helper. This is a trusted local prototype: fast taps between snapshots may be missed, general remapping and multiple native Remotes are unfinished, and packaged/sandboxed distribution has not been tested.

The user confirmed actual movement and jumping with the initial live prototype. The saved reader compiles, and synthetic checks cover bit routing, expiry/removal, rejoining, and malformed snapshots. The saved combined launcher still needs a fresh physical end-to-end session; the successful live game was left running.

## Experimental SDL path for other Wii layouts

```sh
python3 scripts/play.py --wii
```

Pair the controller with the **computer**, not the TV. Press **F3** in the game to see devices reported by Godot, their player assignments, and a layout selector. Auto-detection uses SDL's device names; select the correct layout manually if needed. Overrides last for the current connection and are cleared on disconnect. Changing a joined player's layout clears held input.

| Controller | Move | Join / jump | Leave | Status |
| --- | --- | --- | --- | --- |
| Wii Remote / Wii Remote Plus | Sideways D-pad, 1/2 buttons on the right | 2 | Hold minus | Experimental profile |
| Remote / Remote Plus + Nunchuk | Nunchuk stick | Remote A | Hold minus | Experimental profile |
| Classic Controller | Left stick / D-pad | A | Hold minus | Experimental profile |
| Classic Controller Pro | Left stick / D-pad | A | Hold minus | Experimental profile |
| Wii U Pro Controller | Left stick / D-pad | A | Hold minus | Experimental profile |

Classic controllers connect through a Wii Remote. The Remote and its extension represent one player. Plus toggles fullscreen. Leave requires a 1.25-second hold. Reconnect and press the appropriate join button for a fresh character. Standard Xbox/PlayStation mappings remain independent in mixed groups.

## Pairing on this Mac

**Current result: first Remote Plus pairing failed; second Remote connected through macOS with PIN `0000`, and movement/jumping were confirmed using the native reader.** The release helper and diagnostic attempts did not pair the first Remote. The second device has reached native report reading as described below; these are distinct hardware observations.


The Remote Plus (`Nintendo RVL-CNT-01-TR`) reached a PIN prompt in macOS Bluetooth settings during dogfooding. Official Wii protocol documentation describes a binary pairing key. Our initial blanket advice that `0000` could never work was too broad: the user subsequently connected a different Remote with `0000`. Record exact device identities and observed behavior rather than assuming every controller advertising a Nintendo name uses the same pairing path.

1. Open `~/Applications/WiimotePair.app` and allow Bluetooth access if macOS requests it.
2. Cancel any old PIN dialog. Briefly press the red **SYNC** button under the Remote's battery cover; do not press other buttons during pairing.
3. Wait for **Wii Remote Connected** in the helper. Use **Show Details** to distinguish Bluetooth pairing from physical HID input (the controller data connection).
4. With Little World running via `python3 scripts/play.py --wii`, press F3 and check whether Godot reports the controller. If the helper holds the controller while Godot cannot see it, its **Pair Another Remote** action releases its HID handle while preserving pairing; test the handoff before closing the helper.
5. Once detected, return to the game and press **2** to join. Verify movement and jumping before marking the controller playable.

If an existing Wii entry prevents fresh pairing, forget only that Wii controller and retry. Do not remove unrelated controllers or toggle the computer's Bluetooth globally. Later reconnection uses an ordinary button press after opening the helper/game; red SYNC is for fresh pairing.

[WiimotePairPlus instructions](https://github.com/GabrielLascoskiFerraz/WiimotePairPlus) describe this pairing and handoff flow. The helper is a separate third-party dogfood tool, not a bundled platform dependency. The game currently neither performs Bluetooth pairing nor installs drivers.

### Local installation record — September 15, 2026

- Installed [WiimotePairPlus v1.2.1 (build 11)](https://github.com/GabrielLascoskiFerraz/WiimotePairPlus/releases/tag/v1.2.1), ARM64, to `~/Applications/WiimotePair.app` with user authorization.
- Archive: 299,758 bytes; installed file contents: 427,267 bytes. No Xcode build, additional runtime, or driver download was needed.
- SHA-256 matched the publisher's release digest: `492cd333275a6c3d7e56fa897bf9450b83ce5ff74ce6268625b8ab51c8f86b75`.
- The ad hoc code signature passed `codesign --verify --deep --strict`. This verifies bundle integrity, not publisher identity or notarization; the release is not Apple-notarized.
- Opened successfully on this Mac. UI reported **Bluetooth Ready**, **HID Monitoring**, and **Searching for Wii Remotes**. The first pairing attempts failed. The alert showed `(os/kern) protection failure`; macOS logs confirmed Bluetooth permission was granted and recorded `CBInternalErrorDomain Code=11` (incorrect PIN). SDL handoff and gameplay remain unverified.

### Local pairing diagnostic build

Source inspection found no guard against repeated discovery callbacks starting overlapping pairing attempts. Apple’s public `IOBluetoothDevicePair.h` also documents that the framework can legitimately perform two low-level attempts; duplicate start log entries alone do not prove an application race. A separate **WiimotePair Couch Test.app** was built from the v1.2.1 source with a [small local patch](wiimote-pair-local.patch): serialize discovery/pairing, ignore stale completion callbacks, and log whether the binary-PIN callback runs. No PIN values are logged. This is a diagnostic experiment, not an established fix for the observed failure.

- Source: upstream v1.2.1, tree `8e7f9b12db2da520e4f868305c4861cdf58fa15f`; upstream code is GPL-2.0-or-later.
- Build: existing Xcode, Release ARM64, separate bundle ID `local.couchgames.WiimotePairTest`, ad hoc signing with the existing Bluetooth entitlement. Compilation and signature verification passed.
- Local path: `~/Applications/WiimotePair Couch Test.app`. The original release is retained but was closed before testing this build.
- App opened with Bluetooth Ready and HID Monitoring. A fresh red-SYNC attempt also failed. The diagnostic PIN callback never ran; macOS logged a Just Works pairing path, then incorrect PIN. The serialization patch did not resolve pairing. An isolated attempt with Little World closed also failed at 18:46:39 local log time. It again reported status 2 and incorrect PIN with no PIN callback; the game running concurrently is not required to reproduce the failure. Do not run both helpers at once.

The diagnostic patch uses zero context; apply it to the upstream v1.2.1 source with `git apply --unidiff-zero /path/to/wiimote-pair-local.patch`. This separate helper is not integrated into the platform or distributed with the SDK. Keep the patch and upstream attribution when reproducing this experiment; address licensing before bundling third-party helper code.

### Second Remote test

A different physical Wii Remote produced `(os/kern) default set`. Logs at 18:51–18:52 show **Pincode Pairing** and a PIN request, followed by `CBInternalErrorDomain Code=11` (PIN or link key incorrect). This is a different observed callback path from the first Remote's Just Works path. The user confirmed red SYNC only. The second Remote's exact revision is not recorded yet; this result does not establish a shared root cause.

The helper computes the key for red-SYNC bonding (reversed host Bluetooth address). Holding 1 + 2 instead uses temporary pairing with the reversed Remote address, so confirm the button method before another attempt. [WiiBrew protocol documentation](https://wiibrew.org/wiki/Wiimote#Bluetooth_Pairing)

### Second Remote: connection and native input investigation

The user reports macOS accepted PIN `0000` for the second Remote, displayed as `Nintendo RVL-CNT-01`. The running game had been launched without `--wii`; it was restarted with the experimental driver and mappings explicitly enabled.

Godot then reported a connected raw device with vendor `0x04e8`, product `0x7021`, GUID `03001c56e80400002170000001000000`, and profile `wii_unknown`. No mapped button events arrived when the user pressed buttons. These IDs differ from the Nintendo `0x057e:0x0306/0x0330` IDs accepted by SDL's Wii driver. The reported name alone does not establish manufacturer/model authenticity.

IORegistry exposed a Wii-style vendor-report descriptor. A small local `Couch Wii Input Probe.app` matched only this vendor/product/name, opened it without exclusive access, requested LED 1, button report mode `0x30`, and status. It successfully received repeated `0x30` reports. The game subsequently registered Player 1 through a temporary native bridge, and the user confirmed movement and jumping. The working approach is saved in the native path above. This probe is outside the SDK, does not modify EEPROM or pair devices, and is not distributed as a supported driver.

The host Bluetooth-address API was also checked: it returned a parseable, nonzero address matching System Information. That rules out an obviously missing/malformed host address in the CLI diagnostic context, not every possible pairing failure.

### Next investigation

The alternative WiiMacMote implementation uses the same binary-PIN callback/coordinator mechanism. It has [a recent macOS pairing failure report](https://github.com/gdemontalivet/wiimacmote/issues/5) and [a report including the same status-2 error](https://github.com/gdemontalivet/wiimacmote/issues/2). It was inspected but not installed. These reports are supporting context, not proof of our root cause.

Further hardware work should test the still-unpaired first Remote Plus and additional native/SDL variants separately. A computer receiver would need explicit Wii Remote Plus, macOS, and Godot input verification before recommending purchase. The native reader works for the observed second device; it does not establish compatibility with the first Remote Plus. The failed helper was closed; the original release and diagnostic app remain installed for later investigation.

## Driver setup for SDK developers

The installed standard Godot 4.7.2 includes SDL's Wii HIDAPI driver, which is disabled by default. Our `--wii` option sets `SDL_JOYSTICK_HIDAPI_WII=1` only in child engine processes, before SDL initializes. Enabling it inside an already-running SDK autoload is too late. SDL explicitly excludes DolphinBar from this driver. [SDL Wii driver documentation](https://wiki.libsdl.org/SDL3/SDL_HINT_JOYSTICK_HIDAPI_WII)

The launcher also loads `sdk/addons/couchgames/wii_sdl_mappings.txt` into `SDL_GAMECONTROLLERCONFIG`. Source inspection found that this engine's SDL maps the bare Remote D-pad to hat 0, while its Wii driver emits buttons 11–14. Our four mappings correct that for the original/Plus Nintendo HIDAPI identities, with no extension, under the USB/Bluetooth bus classifications. Other controller identities are unaffected. Caller-provided mappings are retained with priority. This correction is source-derived; physical D-pad verification remains pending.

For a custom host/editor launch, set both the Wii hint and the supplied mappings before starting Godot. The Python helper `godot_environment(wii=True)` demonstrates that setup. Copying the GDScript addon alone supplies profiles but does not enable the native driver or apply startup mappings. The future desktop host must carry this setup into packaged-game launches.

Mapping references for the pinned engine:

- [Godot 4.7.2 SDL Wii driver](https://github.com/godotengine/godot/blob/4.7.2-stable/thirdparty/sdl/joystick/hidapi/SDL_hidapi_wii.c)
- [Godot 4.7.2 SDL gamepad mappings](https://github.com/godotengine/godot/blob/4.7.2-stable/thirdparty/sdl/joystick/SDL_gamepad.c)
- [Godot 4.7.2 SDL Nintendo extension identities](https://github.com/godotengine/godot/blob/4.7.2-stable/thirdparty/sdl/joystick/hidapi/SDL_hidapi_nintendo.h)

Recheck these mappings when changing the supported engine version. SDL does not distinguish Classic and Classic Pro in every name; they currently share the same action layout. Raw `RVL-CNT` or unknown-extension identities default to an unsupported layout until the actual input path is established.

## Remaining family coverage

“All Wii controllers” remains a product target, not a completed compatibility claim:

- Balance Board, guitars, drums, drawing tablets, and other specialty accessories need device-specific input adapters and games designed for those controls.
- Wii U GamePad is distinct from Wii U Pro and has no implemented connection/input path here.
- GameCube controllers used with a Wii need a compatible computer adapter and a separately tested profile.
- Third-party clones and USB adapters need their own mapping/hardware checks.
- MotionPlus gestures, accelerometer actions, IR pointer aiming, speaker output, and haptics are not exposed by this prototype API.

Unknown accessories do not silently create a player with an assumed layout. A manual profile override cannot supply a missing Bluetooth connection or unsupported native driver.

## Verification

`python3 scripts/test_sdk.py` runs 53 synthetic Wii profile assertions alongside the existing runtime, sixteen-player, and scene tests. `python3 scripts/test_sdk.py --wii` additionally starts the engine with the experimental driver and mapping environment. Neither run uses Wii radio packets or proves physical compatibility.

For each family member: record model, OS, connection path, Godot device name/GUID, selected profile, join, all movement directions, jump, leave, disconnect/rejoin, and a mixed Xbox/PlayStation session. Reconnect after changing an extension and verify the new layout. Track results in [the hardware matrix](controller-test-matrix.md). Sixteen software slots do not establish sixteen wireless connections.
