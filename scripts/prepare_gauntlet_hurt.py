#!/usr/bin/env python3
"""Prepare checked-in CC0 hurt recordings with existing ffmpeg. No downloads."""
from array import array
import json
import math
import sys
import wave
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'sdk/examples/gauntlet/assets/audio'
SOURCES = AUDIO / 'voices/hurt'

def main():
    for clip in json.loads((SOURCES/'clips.json').read_text()):
        duration = clip['end'] - clip['start']
        output = AUDIO/f'hurt_{clip["class"]}_{clip["take"]}.wav'
        subprocess.run([
            'ffmpeg', '-v', 'error', '-y', '-i', str(SOURCES/clip['source']),
            '-af', f'atrim=start={clip["start"]}:end={clip["end"]},asetpts=PTS-STARTPTS,'
                   f'highpass=f=75,'
                   f'afade=t=in:d=0.005,afade=t=out:st={duration-.018}:d=0.018',
            '-ac', '1', '-ar', '24000', '-c:a', 'pcm_s16le',
            str(output)
        ], check=True)
        # Short grunts can fall below the 400 ms loudness-analysis window.
        # Match RMS directly, preserving dynamics and leaving 3 dB peak headroom.
        with wave.open(str(output), 'rb') as stream:
            params = stream.getparams()
            samples = array('h', stream.readframes(stream.getnframes()))
        if sys.byteorder != 'little':
            samples.byteswap()
        rms = math.sqrt(sum(float(x)*x for x in samples)/len(samples))
        peak = max(abs(x) for x in samples)
        if rms == 0:
            raise ValueError(f'Silent hurt reaction: {output}')
        gain = min(32768*10**(-20/20)/rms, 32768*10**(-3/20)/peak)
        normalized = array('h', (round(x*gain) for x in samples))
        if sys.byteorder != 'little':
            normalized.byteswap()
        with wave.open(str(output), 'wb') as stream:
            stream.setparams(params)
            stream.writeframes(normalized.tobytes())
    print('Prepared twelve recorded hurt reactions, three takes per class.')

if __name__ == '__main__':
    main()
