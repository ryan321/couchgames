# Haymaker

An original LAN last-one-standing brawler in a Grapital-inspired carnival city: a central wrestling ring, painted asphalt streets, brick apartments, jump pads, prize crates, and four wrestler body types. Inspired by the battle-royale brawler look (dense colorful city, melee, shrinking ring). Every player uses their own computer and screen; one of those computers hosts the match. No Rumbleverse characters, maps, or logos.

Art lives under `assets/`: generated albedo textures (asphalt, brick, plaster, canvas, metal) and concept posters applied to constructed meshes. Sources are listed in `assets/sources.json`.

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
| Strike combo | Left click | A / Cross or X / Square |
| Vicious grab / slam | F | Y / Triangle |
| Dash | Shift | LT |
| Block | — | RT or LB |
| Dodge | Ctrl | B / Circle |
| Jump | Space | RB |
| Dropkick | Dash + strike | LT + A |
| Elbow drop | Jump + strike | RB + A |
| Pause this screen | Esc | Menu / Options |
| Fullscreen | F11 | — |

**A / Cross is a three-hit strike combo** (Hammer Fist). **Y** grabs and slams. Dash into strike for a dropkick; jump into strike for an elbow drop. Hold RT to block. The menu highlights Practice first; after a win or loss, **Play again** is highlighted. One local player per computer in this slice.

Fighters use the CC0 Quaternius Universal Base humanoid (male/female) already in this repository, recolored as four wrestler builds, with idle/walk/run/strike/throw clips from the Universal Animation Library. Collision and netcode stay on the capsule body.

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
