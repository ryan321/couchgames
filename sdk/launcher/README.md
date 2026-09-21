# Giga Couch library

```sh
python3 scripts/library.py
```

The library uses the same navy/mint studio chrome as GDK Setup, with TV-sized type and controller focus. It shows Little World, Cloudbound, Pocket Rally, World 1-1, Gauntlet, Sunbreak, and Haymaker, then Hub/source projects and unsigned installs. Cards are tagged SAMPLE / YOUR GAME / INSTALLED. Game info, Settings, Refresh, and Who's playing (Family/Guest) are on the chrome. Confirm prompts show **A** or **Cross** from the first gamepad. Scroll the game grid to see more games. Click a card, or use keyboard arrows / a standard gamepad's D-pad and Enter / A / Cross. Sample games open with `--path` on this checkout's `sdk/` folder; Hub-registered games open with `--path` set to that project folder. Close its window to return to the library; the selected card regains focus. After creating a game, reopen Giga Couch to see it here. The library also offers **Close game & return**, **Quit library**, and F11 fullscreen.

On this Mac, **Wii Remote + gamepads** is selected by default. It uses the native reader for the observed `04e8:7021` Remote: the single-device helper for Little World/Cloudbound/World 1-1 and the multi-device helper for Pocket Rally and Gauntlet. For Sunbreak, use **Gamepads / keyboard**; its FPS controls require mouse/keyboard or a standard dual-stick controller. Select **Gamepads / keyboard** to run without a helper, or **Other Wii · experimental** for the existing SDL Wii path. Joy-Cons can be separate or paired. The native Wii helper runs only during a game; browse the library with a mouse, keyboard, or regular gamepad.

Pair controllers with the computer first. Close standalone games/readers before using the library. A controller must join each new game again; player assignments are game-local. Closing the library stops only the game/helper it launched. A closed Wii helper returns to the library with an error so the game can be relaunched. Logs are written to the temporary session directory printed in the terminal.

## Development scope

`games.json` is the checked-in catalog of the seven playable source examples. The host merges Hub-registered source projects from `creator-projects.json` (override with `COUCH_CREATOR_PROJECTS`) and writes the combined list to the session `catalog.json` for the UI (`COUCH_LIBRARY_CATALOG`). Cards are rendered in Godot in a scrolling grid; focus navigation brings off-screen cards into view. Covers use original vector artwork, except for World 1-1’s documented NES artwork. This does not list or run imported test PCKs from SQLite. Catalog entries contain game IDs and fixed scene paths; local games use `local:` ids. Requests can select catalog IDs, not arbitrary executables or paths.

`scripts/library.py` is a development supervisor built on the existing Python launch tooling. It checks the runtime through our Rust doctor once, imports once, owns game/helper processes, and exchanges small atomic JSON files with the UI in a private local session directory. Requests have IDs so an old status cannot acknowledge a newer click. Games do not inherit the library session or another game's native input paths. UI input is disabled during launch/play; crash/exit restores selection with a short cooldown. Creator games do not start the native Wii helper unless the catalog row declares `native_wii`.

The production Rust desktop host, SQLite-backed playable release catalog, packaged runtime lifecycle, signed distribution, authenticated IPC, and OS sandbox remain planned. Separate child processes and private local files are not a security boundary against other processes running as the same user. No engine, templates, or toolchains are installed by this command.

## Verification

- `python3 scripts/test_library.py`: fake-process tests for fixed catalog launches, Hub-registered source projects (`--path` at the project folder), missing-project errors, duplicate requests, crash/retry, reader selection/cleanup, spawn failure, request validation, stop, and environment separation.
- `python3 scripts/test_sdk.py`: actual Godot UI tests including card activation, pending request acknowledgments, disabled launch input, error recovery, and restored focus.
- Earlier real headless child launches and clean returns passed for the initial three scenes on this Mac. Gauntlet adds full solo/16-player synthetic playthroughs and fifth-card launch/scroll tests. Rendered library capture inspected. Native reader/gameplay hardware coverage remains as documented for each game; library gamepad navigation and TV behavior need physical acceptance.
