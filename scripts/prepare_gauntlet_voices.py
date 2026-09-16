#!/usr/bin/env python3
"""Prepare the checked-in CC0 voice recordings with existing ffmpeg. No downloads."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'sdk/examples/gauntlet/assets/audio'

def main():
    for kind in ['warrior', 'valkyrie', 'wizard', 'elf']:
        subprocess.run([
            'ffmpeg', '-v', 'error', '-y', '-i', str(AUDIO/'voices'/f'{kind}.ogg'),
            '-af', 'silenceremove=start_periods=1:start_threshold=-48dB:start_silence=0.02,'
                   'areverse,silenceremove=start_periods=1:start_threshold=-48dB:start_silence=0.04,'
                   'areverse,highpass=f=70,loudnorm=I=-16:TP=-2:LRA=7',
            '-ac', '1', '-ar', '24000', '-c:a', 'pcm_s16le', str(AUDIO/f'choose_{kind}.wav')
        ], check=True)
    print('Prepared four recorded character-selection lines; original pitch and delivery preserved.')

if __name__ == '__main__':
    main()
