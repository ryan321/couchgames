# Giga Couch: the player app

The player product is **Giga Couch** ([gigacouch.com](https://gigacouch.com)).

## Two apps, two audiences

**Giga Couch** is the app on the computer connected to the TV. Open it to browse your library, choose who is playing, launch games, and return to your library. Every normal player action must work with a controller.

**Giga Couch Creator Hub** is the creator workspace. The native **GDK Setup** prepares Godot, the development kit, and an optional AI coding assistant. Creators use their own agent and Godot to make games; players do not need either an AI agent or a development toolchain.

Both products use the same dark navy and mint-green visual language. The player app needs large type, obvious controller focus, TV-safe margins, and readable distance-based layouts rather than desktop-sized setup cards.

## Player screens

- **Home / Library:** installed games, recently played, owned/shared games, download state, and one clear Play action.
- **Game details:** supported player count, controllers, description, update/install state, Play and game-specific options.
- **Who's playing:** local profiles and guests, controller assignment, reconnect, and up to sixteen players when the game supports them.
- **Friends & family:** invitations, shared games, friends and party state. Implement against real backend features; do not display simulated online activity.
- **Account:** hosted sign-in, account switching and logout. Prefer a phone-assisted QR/device-code flow so TV users do not type passwords with a controller. Identity-provider selection remains pending.
- **Settings:** display/fullscreen, audio, controller setup, accessibility, storage and updates.
- **In-game system menu:** return to game, controller help, and exit to library. The host supervises game exit and restores launcher focus/input, including after crashes.

## Controller contract

Stick or D-pad moves focus; confirm selects; back returns; menu opens context/options. Show device-appropriate prompts for Xbox, PlayStation and supported Nintendo controllers. Every screen, modal, error, empty state and install action has a reachable initial focus and an obvious way back. Reconnecting or switching controllers must not strand the user. A disconnected active controller exposes a join/reconnect path.

When a game starts, pause launcher input so one button cannot control both processes. Restore focus to that game’s library card on return. Local library browsing and installed-game play continue offline. Account and social actions explain when a connection is needed.

## Implementation

- **Godot UI:** TV launcher scenes, controller navigation, visuals and reusable SDK input components.
- **Rust desktop host:** local library in SQLite, runtime selection, installation, launch supervision, credentials and local API. The launcher and each game are separate processes.
- **One compatible runtime installation:** reused across the launcher and games. Players receive a managed runtime; they need not install the editor. Packaging and isolation qualification remain release requirements.
- **Platform backend:** authenticated HTTPS API backed by Neon PostgreSQL. No Neon credentials or direct database connections on player computers.
- **Display:** HDMI/direct connection or compatible operating-system screen sharing to the TV; controllers connect to the computer.

## Delivery order and acceptance

1. Promote the existing source-game library prototype into a complete controller-driven navigation prototype, with the shared visual theme and game details.
2. Connect it to the Rust host and installed SQLite library; launch compatible games and return after normal exit, failure, and crash.
3. Add local profiles/guests, settings, reconnect recovery, and controller-only acceptance on a TV.
4. Add real account sign-in, authorized private sharing, then friends/family features through the backend.
5. Package the player application separately from the GDK; qualify runtime reuse, updates and access boundaries on each supported OS.

A separate local macOS **Giga Couch.app** now opens the sample library, with a Desktop shortcut created by `python3 scripts/build_player.py --desktop`. This preview references the checkout and existing Python/Godot; it is not yet a portable player distribution. The current sample library proves source-game selection and launching. It is not yet the shipped account/social platform. This document defines that product boundary and the next implementation work; it does not mark those features complete.
