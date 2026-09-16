# Recorded hero hurt reactions

These stock human performances are distributed under **Creative Commons CC0 1.0**. Downloaded September 16, 2026. They replace the synthesized player damage voices; no original Gauntlet audio is used.

## Sources and credits

- **HaelDB — [Male Grunt/Yelling Sounds](https://opengameart.org/content/male-gruntyelling-sounds)**. The source page offers CC0 and OGA-BY 3.0 as alternative licenses; this project uses CC0. The author describes four male voices recorded with a Neumann microphone and Avalon preamp. The nine included WAVs are unchanged files from `yelling sounds.zip`; individual performers are not named.
- **AuraVoice (OpenGameArt username Nocturnal_Vanguard) — [Female hurt grunts / groans](https://opengameart.org/content/female-hurt-grunts-groans)**. The source page offers CC0 and identifies AuraVoice as the voice artist. The included `female_hurt_grunts_groans_1.ogg` is the unchanged source compilation.

| Class | Source recordings |
|---|---|
| Warrior | `3grunt1.wav`, `3grunt2.wav`, `3grunt3.wav` |
| Valkyrie | First three reactions in `female_hurt_grunts_groans_1.ogg` |
| Wizard | `2yell1.wav`, `2yell10.wav`, `2yell7.wav` |
| Elf | `1yell1.wav`, `1yell15.wav`, `1yell16.wav` |

License: [CC0 summary](https://creativecommons.org/publicdomain/zero/1.0/) and [full legal text](https://creativecommons.org/publicdomain/zero/1.0/legalcode). Credits are retained for provenance even though CC0 does not require attribution.

## Preparation

`clips.json` records the source file, class, take and trim boundaries in seconds. Run `python3 scripts/prepare_gauntlet_hurt.py` from the repository root with an existing ffmpeg installation. No download or installation occurs.

Preparation trims silence, applies a 75 Hz high-pass filter, matches RMS toward -20 dBFS with a -3 dB sample-peak ceiling, and adds 5 ms / 18 ms edge fades. Game WAVs are mono 24 kHz PCM16. Performances retain their natural pitch and speed; clips last 0.22–0.84 seconds. Playback uses a fixed pitch and a shared gain across classes. Final speaker/TV mix quality still needs listening during play.

The full audio generator also rebuilds the disabled experimental Wii ADPCM copies. That transport limits its copies to 0.78 seconds; regular-speaker WAVs retain their complete prepared duration. Wii speaker streaming remains disabled in normal play.
