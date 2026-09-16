# Gauntlet audio

**Current hardware status:** Wii speaker streaming is disabled by default after physical tests produced choppy sound and connection drops. All class-selection and hurt voices play on regular speakers. Native Wii gameplay requests motor pulses only; physical rumble confirmation is pending. The ADPCM transport described below is experimental and is not used in normal play.

Weapon/enemy effects and music are original deterministic synthesis made for this project. Hero damage uses CC0 human recordings from HaelDB and AuraVoice; lobby selections use CC0 recordings from Kenney; see [recording sources, actor credits and licenses](voices/README.md). No original Gauntlet audio or third-party music is included.

- Four performers provide three recorded hurt reactions per class, cycling across successful hits. Clips run 0.22–0.84 seconds, with trimmed silence, light filtering, matched loudness and natural pitch. See [hurt sources and preparation](voices/hurt/README.md).
- Layered axe/sword swishes, bow release, magic bolts/bursts, body/ghost/stone impacts, crumbling generators, and short interface/reward cues.
- Three original 16-bar minor-mode scores: Ember (88 BPM), Archive (92 BPM), Crown (96 BPM). Stereo sustained chords, plucked melody, bass, and restrained percussion. Note tails wrap around the loop boundary.

The game plays checked-in 24 kHz PCM16 WAV effects and compressed Ogg Vorbis music. No downloads, Python, NumPy, or ffmpeg are needed to play.

To regenerate, use `python3 scripts/generate_gauntlet_audio.py` from the repository root. Authoring requires an existing Python environment with NumPy and ffmpeg's native Vorbis encoder; the script installs nothing. It uses a fixed random seed. To rebuild only player hurt WAVs, run `python3 scripts/prepare_gauntlet_hurt.py` (ffmpeg only; no downloads). Import the resulting assets with the existing Godot editor before testing.

Music fades toward a quiet level for the current game phase and briefly ducks under hurt reactions. Eight effect voices are reserved for player reactions, three for impacts, and five for weapons/interface cues. Per-player hurt throttling allows simultaneous reactions from different players; per-effect throttling controls crowded combat noise. Sound effects and music have separate controller-accessible pause-menu switches. Settings last for the current game process.

Automated checks verify asset playback, distinct takes, damage/invulnerability routing, crowded playback, chapter selection, loop configuration, and independent menu toggles. Waveform checks verify non-silence and peak headroom. Speaker/TV listening and final mix balancing still need playtesting.

## Class-selection utterances

`choose_*.wav` are four recorded lobby lines prepared from the CC0 sources in `voices/`. The old `choose_*.adpcm` synthesized prototypes are retained only for experimental transport tests; they do not represent the new recordings and are not used in normal play. Native speaker streaming remains disabled.

The native fleet helper follows the [WiiBrew speaker protocol](https://wiibrew.org/wiki/Wiimote#Speaker), using 20-byte data chunks (40 samples), modest speaker volume, and per-device connection identifiers. A 2 ms scheduling tick follows absolute 10 ms audio deadlines. Asynchronous IOKit writes keep synchronous Bluetooth completion delays out of the streaming loop, with at most four writes in flight per Remote. Its command bridge accepts no arbitrary paths or register writes from game code. Synthetic packet checks: `xcrun clang -Wall -Wextra -Werror tools/macos/test_wii_speaker.c -o /tmp/test_wii_speaker && /tmp/test_wii_speaker`. Godot audio tests cover routing, debounce, reconnection isolation, and cancellation.

## Damage feedback

Enemies have quiet 0.105–0.130 second grunt/ghost/demon reactions on regular speakers, below hero voice volume. Player damage retains the regular-speaker class “oof” and has an experimental route for its matching `hurt_*.adpcm` clip, currently disabled. Compatible physical gamepads are sent a 120 ms weak/strong rumble through Godot; native Wii is sent a 120 ms motor pulse. Invulnerability blocks repeated feedback and passive health drain remains silent. Pause, leave, reset and shutdown cancel feedback; the host bounds pulse duration at 250 ms and preserves the rumble bit on every speaker report. The pause menu has a separate Controller rumble switch; Sound effects controls both regular and Wii speech.

Physical diagnosis found that synchronous output could stretch a 0.39-second clip to 1.36 seconds. An asynchronous 0.30-second test completed its streaming/cleanup phase in 0.354 seconds with two late packets. The user still heard choppy audio and then reported connection drops. Streaming is consequently disabled in normal play. This timing measurement does not establish speaker compatibility; the remaining native feedback is rumble-only.
