# Haymaker

An original LAN last-one-standing brawler: a colorful carnival lot, melee fights, loot, and a shrinking ring. Inspired by the battle-royale brawler genre. Every player uses their own computer and screen; one of those computers hosts the match. No third-party characters, maps, or assets.

This is the first in-repo LAN prototype. It uses Godot ENet through `Platform.install_lan_session()`. The host is the authority. Online relay, LAN discovery, and sandbox-qualified network access remain later work; see [multiplayer design](../../../docs/multiplayer.md).

## Play

Choose **Haymaker** in the Giga Couch library, or run from the repository root:

```sh
python3 scripts/play.py --game haymaker
```

Uses the already-installed supported Godot, with Forward+ and native Metal on macOS. No engine, templates, or extra art packs are downloaded. For older graphics hardware, use `--compatibility`.

| Action | Keyboard / mouse | Standard gamepad |
| --- | --- | --- |
| Menu | Enter / click | A / Cross confirms, D-pad or left stick moves |
| Move / look | WASD / hold right mouse and drag | Left / right stick |
| Punch | Left click | A / Cross, X / Square, or RT |
| Heavy | F | Y / Triangle or LT |
| Dodge | Shift | LB or B / Circle |
| Jump | Space | RB |
| Pause this screen | Esc | Menu / Options |
| Fullscreen | F11 | — |

**A / Cross punches.** Jump is RB or Space. The menu highlights Practice first; press A / Cross to start. After a win or loss, **Play again** is highlighted — press A / Cross to restart. One local player per computer in this slice.

### Practice

**Practice** starts a match on this computer against three bots. Use it to learn the lot without another machine.

### Host a LAN match

On the host computer:

```sh
python3 scripts/play.py --game haymaker --host
```

Or choose **Host LAN match** in the menu. The menu and waiting room list this computer's Wi-Fi/LAN IPv4 address (never loopback `127.0.0.1`) and port **24567**. Other players type that address. Press **Start match** when everyone is in.

macOS may ask for local-network permission the first time the host binds a port.

### Join from another computer

Both computers need this same source checkout (or the same installed game) and a local network that allows device-to-device traffic. Guest Wi-Fi that isolates clients will not work.

```sh
python3 scripts/play.py --game haymaker --join 192.168.1.12
```

Or choose **Join LAN match**, enter `host` or `host:port`, and confirm. `--join 127.0.0.1` joins another window on the same computer.

```sh
python3 scripts/play.py --game haymaker --host --port 24567
python3 scripts/play.py --game haymaker --join 127.0.0.1:24567
```

Internet access is not required. If the host quits, the session ends on every computer.

## Match

- Up to eight computers. Each computer is one fighter.
- Start with 100 health. Armor absorbs damage first. A bat pickup raises punch/heavy damage for a short time. Health pickups restore 35.
- The green ring shrinks from 42 m to 9 m over 90 seconds. Standing outside it drains health.
- Green pads launch you upward. Falling off the lot hurts and returns you to a spawn.
- Last living fighter wins. A host disconnect ends the session.

This is a playable LAN slice, not a full licensed clone: no classes, loadouts, vehicles, or 40-player lobby.

## Verification

```sh
python3 scripts/test_sdk.py
```

`test_haymaker.gd` covers practice spawning, movement, jump, punch/heavy damage, dodge i-frames, loot, ring damage, last-standing results, input ownership, address parsing, and a loopback ENet host/client handshake. Those checks do not prove two-household Wi-Fi, firewalls, physical controllers, or online play.
