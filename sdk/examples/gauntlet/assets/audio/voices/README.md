# Recorded lobby voices

These are human voice recordings distributed by Kenney under **CC0**. Original archives' licenses and actor credits are included alongside these selected source clips.

| Class | Line | Source pack / original file |
|---|---|---|
| Warrior | Ready! | Voiceover Pack (Fighter), `Audio/ready.ogg` |
| Valkyrie | Ready! | Voiceover Pack, `Female/ready.ogg` |
| Wizard | Prepare yourself! | Voiceover Pack (Fighter), `Audio/prepare_yourself.ogg` |
| Elf | Go! | Voiceover Pack, `Male/go.ogg` |

Sources: [Voiceover Pack](https://kenney.nl/assets/voiceover-pack), [Voiceover Pack (Fighter)](https://kenney.nl/assets/voiceover-pack-fighter). Downloaded September 16, 2026. Voiceover Pack credits Jeffrey M. Smith (male) and Giselle (female). Fighter is credited to Kenney Vleugels; its archive does not separately identify the performer.

`python3 scripts/prepare_gauntlet_voices.py` trims excess silence, removes low-frequency noise, matches loudness, and produces the `choose_*.wav` game files. Pitch and delivery are unchanged. Source recordings remain intact. Only these four clips are included, rather than the entire packs. Playback needs no download or authoring tools.

These are stock voice lines, not bespoke performances of the game's characters. Warrior and Wizard share the Fighter pack voice. The previously synthesized damage reactions are retained because the user liked those “oofs.” Wii speaker streaming is disabled; these lines play on regular speakers.
