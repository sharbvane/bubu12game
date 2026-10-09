"""Tiny original chiptune cues for new boss, loot and building feedback."""
from pathlib import Path
import math, random, struct, wave

OUT=Path(__file__).resolve().parents[1]/'audio'
RATE=22050

def cue(name, notes, seconds, noise=0):
    rng=random.Random(140+len(name))
    samples=[]
    for i in range(int(RATE*seconds)):
        t=i/RATE
        index=min(len(notes)-1,int(t/seconds*len(notes)))
        hz=notes[index]
        envelope=min(1,t*32)*max(0,1-t/seconds)**1.4
        tone=math.sin(2*math.pi*hz*t)*.55+math.sin(2*math.pi*hz*2*t)*.18
        samples.append(int(max(-1,min(1,(tone+(rng.random()*2-1)*noise)*envelope*.65))*32767))
    with wave.open(str(OUT/(name+'.wav')),'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(RATE)
        wav.writeframes(struct.pack('<'+'h'*len(samples),*samples))

cue('boss_intro',[164,220,277,330,415],.75,.12)
cue('boss_down',[523,466,392,330,262,196],1.1,.16)
cue('build_place',[392,523,659],.23,.08)
cue('loot_chime',[523,659,784,1047],.48,.02)
print('V140_AUDIO_PASS')
