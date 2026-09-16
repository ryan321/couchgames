#!/usr/bin/env python3
"""Build original Gauntlet audio. Optional authoring dependencies: numpy and ffmpeg.
The game plays checked-in assets; it never runs this generator or installs anything.
"""
from pathlib import Path
import subprocess
import tempfile
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'sdk/examples/gauntlet/assets/audio'
RATE = 24000
RNG = np.random.default_rng(1985)


def fade(signal, attack=.006, release=.025):
    result = signal.copy()
    a, r = min(len(result), int(attack * RATE)), min(len(result), int(release * RATE))
    result[:a] *= np.linspace(0, 1, a)
    result[-r:] *= np.linspace(1, 0, r)
    return result


def noise(n, low=0, high=8000):
    spectrum = np.fft.rfft(RNG.normal(0, 1, n))
    hz = np.fft.rfftfreq(n, 1 / RATE)
    spectrum *= np.clip((hz-low)/max(1,low*.4),0,1) * np.clip((high-hz)/max(1,high*.25),0,1)
    signal = np.fft.irfft(spectrum, n=n)
    return signal / (np.std(signal) + 1e-9)


def tone(hz, seconds, decay=6, partials=(1, .3, .12)):
    t = np.arange(int(seconds*RATE))/RATE
    result = sum(weight*np.sin(2*np.pi*hz*(i+1)*t) for i,weight in enumerate(partials))
    return fade(result*np.exp(-t*decay))


def sweep(start, end, seconds, amount=.5):
    t = np.arange(int(seconds*RATE))/RATE
    hz = np.linspace(start,end,len(t))
    return fade(np.sin(2*np.pi*np.cumsum(hz)/RATE)*np.exp(-t*7))*amount


def write(name, signal, peak=.80):
    signal = np.asarray(signal)
    signal = signal * peak / max(1e-9, float(np.max(np.abs(signal))))
    pcm = np.round(np.clip(signal,-1,1)*32767).astype('<i2')
    with wave.open(str(OUT / (name+'.wav')), 'wb') as wav:
        wav.setnchannels(1 if signal.ndim==1 else signal.shape[1])
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())


def grunt(kind, variant):
    # A voiced /u/ body followed by unvoiced breath: formants give an "oof", not a pitch beep.
    base, duration, rough, formant_scale = [
        (92,.30,.22,.86), (205,.24,.055,1.18), (123,.35,.36,.94), (164,.205,.07,1.09)
    ][kind]
    duration *= [1,.94,1.07][variant]
    base *= [1,1.065,.95][variant]
    t = np.arange(int(duration*RATE))/RATE
    envelope = np.sin(np.pi*np.clip(t/duration,0,1))**.8 * np.exp(-t*3)
    pitch = base*(1.10-.35*t/duration)*(1+.017*np.sin(2*np.pi*31*t))
    phase = 2*np.pi*np.cumsum(pitch)/RATE
    voice = np.zeros(len(t))
    for harmonic in range(1,72):
        hz = base*harmonic
        formants = sum(gain*np.exp(-.5*((hz-center*formant_scale)/width)**2)
                       for center,width,gain in [(390,120,1),(820,170,.75),(2200,280,.22)])
        voice += (formants+.025)*np.sin(harmonic*phase+.08*np.sin(t*49))/harmonic**.45
    voice /= max(1e-9,np.max(np.abs(voice)))
    voice *= 1 + rough*np.sin(phase*.48)
    breath = noise(len(t),1000,6500)
    breath_envelope = np.clip((t/duration-.56)*3,0,1)*np.sin(np.pi*t/duration)
    attack = noise(len(t),70,700)*np.exp(-t*58)
    return fade(np.tanh(voice*1.8)*envelope + breath*.17*breath_envelope + attack*.08, .009,.025)


def effects():
    for kind,name in enumerate(['warrior','valkyrie','wizard','elf']):
        for variant in range(3): write(f'hurt_{name}_{variant}',grunt(kind,variant),.72)
    for name,seconds,low,high,body in [
        ('axe',.35,100,3200,105),('sword',.26,650,8500,245),('bow',.20,1500,10000,430),
        ('impact',.16,100,2600,85),('impact_ghost',.24,800,6000,320),('stone',.23,700,9500,170)]:
        t=np.arange(int(seconds*RATE))/RATE
        env=np.exp(-t*(22 if name in ['impact','stone'] else 12))
        if name in ['axe','sword']: env=np.sin(np.pi*t/seconds)**1.5*np.exp(-t*3)
        air=noise(len(t),low,high)*env
        weight=.32 if name in ['axe','impact'] else .12
        result=air*.22+sweep(body*1.6,body,seconds,weight)
        if name=='bow': result += tone(730,seconds,35,(1,.5,.25))*.13
        if name=='stone': result += tone(2100,seconds,28,(1,.6))*.10
        write(name,result)
    t=np.arange(int(.32*RATE))/RATE
    write('shoot',sweep(1000,180,.32,.5)+np.sin(2*np.pi*2400*t)*np.exp(-t*22)*.15+noise(len(t),1200,9000)*np.exp(-t*19)*.045)
    t=np.arange(int(.72*RATE))/RATE
    write('magic',sweep(110,470,.72,.8)+noise(len(t),150,7500)*np.sin(np.pi*t/.72)**1.2*.15 + np.sin(2*np.pi*880*t)*np.exp(-t*4)*.16)
    t=np.arange(int(.65*RATE))/RATE
    write('destroy',noise(len(t),45,5000)*np.exp(-t*9)*.45+sweep(140,36,.65,.9))
    notes={'pickup':[74,81,86],'key':[62,69,74,78], 'select':[74,81],
           'start':[50,57,62,65,69], 'defeat':[62,60,57,53,50], 'win':[62,65,69,74,77,81]}
    for name,pitches in notes.items():
        step=.04 if name=='select' else (.14 if name in ['win','defeat'] else .065)
        result=np.zeros(int((len(pitches)*step+.45)*RATE))
        for i,midi in enumerate(pitches):
            hz=440*2**((midi-69)/12)
            partials=(1,.30,.08,.04) if name!='defeat' else (1,.4,.2)
            sound=tone(hz,.45,12,partials)
            offset=int(i*step*RATE)
            result[offset:offset+len(sound)] += sound*.5
        write(name,result)


def controller_audio(name, signal):
    # Yamaha ADPCM: two 4 kHz samples per byte, high nibble first on the Wii.
    spectrum=np.fft.rfft(signal)
    hz=np.fft.rfftfreq(len(signal),1/RATE)
    spectrum *= np.clip((1900-hz)/300,0,1)
    samples=np.fft.irfft(spectrum,n=len(signal))[::6]
    samples *= 20000/max(1e-9,np.max(np.abs(samples)))
    if len(samples)%2: samples=np.append(samples,0)
    predictor, step = 0, 127
    nibbles=[]
    for sample in samples:
        error=int(round(sample))-predictor
        magnitude=min(7,int(abs(error)*4/step))
        code=magnitude | (8 if error<0 else 0)
        change=int(step*(2*magnitude+1)/8) * (-1 if error<0 else 1)
        predictor=max(-32768,min(32767,predictor+change))
        step=max(127,min(24576,(step*[230,230,230,230,307,409,512,614][magnitude])//256))
        nibbles.append(code)
    (OUT/(name+'.adpcm')).write_bytes(bytes((a<<4)|b for a,b in zip(nibbles[::2],nibbles[1::2])))


def controller_hurts_and_enemies():
    # Preserve the approved player voices, deriving radio versions from their source WAVs.
    for kind in ['warrior','valkyrie','wizard','elf']:
        for take in range(3):
            name=f'hurt_{kind}_{take}'
            with wave.open(str(OUT/(name+'.wav')),'rb') as wav:
                signal=np.frombuffer(wav.readframes(wav.getnframes()),dtype='<i2').astype(float)/32768
            controller_audio(name,signal)
    for kind,name in enumerate(['grunt','ghost','demon']):
        duration=[.105,.13,.12][kind]
        body=grunt([0,3,2][kind],0)
        signal=np.interp(np.linspace(0,len(body)-1,int(duration*RATE)),np.arange(len(body)),body)
        if kind==1: signal=signal*.6+noise(len(signal),900,4500)*np.sin(np.linspace(0,np.pi,len(signal)))*.035
        write('enemy_'+name,signal,.48)



def music(chapter):
    # Sixteen authored bars; minor-mode plucks, soft bowed chords, bass and frame-drum pulses.
    bpm=[88,92,96][chapter]
    beat=60/bpm
    length=16*4*beat
    n=int(round(length*RATE))
    mix=np.zeros((n,2),dtype=np.float64)
    def add(sound,at,gain,pan=0):
        idx=(np.arange(len(sound))+int(round(at*RATE)))%n
        # Tails wrap around the loop rather than being cut at the seam.
        mix[idx,0] += sound*gain*np.sqrt((1-pan)*.5)
        mix[idx,1] += sound*gain*np.sqrt((1+pan)*.5)
    transpose=[0,5,2][chapter]
    chords=[(50,57,62,65),(46,53,58,62),(53,60,65,69),(48,55,60,64),
            (50,57,62,65),(43,50,58,62),(46,53,58,65),(45,52,61,64)]
    motifs=[[74,0,77,76,74,69,72,0],[70,0,74,72,70,65,69,0],
            [72,0,77,0,76,74,72,69],[72,0,76,74,72,67,69,0],
            [74,77,81,0,79,77,76,74],[70,0,74,77,74,72,70,0],
            [74,0,77,76,74,70,69,65],[73,0,76,0,73,69,0,0]]
    for bar in range(16):
        chord=chords[bar%8]
        at=bar*4*beat
        for i,midi in enumerate(chord):
            hz=440*2**((midi+transpose-69)/12)
            t=np.arange(int(beat*4.8*RATE))/RATE
            bowed=(np.sin(2*np.pi*hz*t+.010*np.sin(t*31)) + .2*np.sin(2*np.pi*hz*2.003*t)+.06*np.sin(2*np.pi*hz*3*t))
            env=np.minimum(t/(beat*.6),1)*np.clip((beat*4.8-t)/(beat*1.2),0,1)
            add(bowed*env,at,.028,[-.7,-.2,.25,.7][i])
        for pulse in [0,2]:
            hz=440*2**((chord[0]+transpose-12-69)/12)
            add(tone(hz,beat*1.8,2.4,(1,.25)),at+pulse*beat,.10)
            drum=sweep(100,48,.24,.8)
            add(drum,at+pulse*beat,.075)
        for tick in [1,3]:
            t=np.arange(int(.09*RATE))/RATE
            add(noise(len(t),1900,6500)*np.exp(-t*55),at+tick*beat,.016,.3)
        for i,midi in enumerate(motifs[bar%8]):
            if not midi: continue
            hz=440*2**((midi+transpose+(12 if bar>=8 and i in [0,4] else 0)-69)/12)
            pluck=tone(hz,beat*1.7,5.0,(1,.27,.08,.04))
            onset=at+i*.5*beat
            pan=.2*np.sin(bar+i)
            add(pluck,onset,.085,pan)
            add(pluck,onset+beat*.75,.018,-pan)
    mix *= .65 / np.max(np.abs(mix))
    name=['music_ember','music_archive','music_crown'][chapter]
    with tempfile.TemporaryDirectory(prefix='gauntlet-audio-') as directory:
        wav_path=Path(directory)/'music.wav'
        with wave.open(str(wav_path),'wb') as wav:
            wav.setnchannels(2); wav.setsampwidth(2); wav.setframerate(RATE)
            wav.writeframes(np.round(mix*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav_path),
                        '-c:a','vorbis','-strict','experimental','-q:a','4',str(OUT/(name+'.ogg'))],check=True)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    effects()
    # Preserve the recorded lobby voices; their source/license lives in assets/audio/voices.
    from prepare_gauntlet_voices import main as prepare_recorded_voices
    prepare_recorded_voices()
    controller_hurts_and_enemies()
    for chapter in range(3): music(chapter)
    print(f'Generated original effects, 12 class hurt takes and three music loops in {OUT}')

if __name__=='__main__': main()
