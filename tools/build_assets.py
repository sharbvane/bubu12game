"""Reproducible pixel assets, animation sheets and original synthesized audio.
Uses the image25 bear master; never needs an API key. Requires Pillow.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
import random, math, wave, struct, urllib.request

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'资产/精灵'
OUT.mkdir(parents=True,exist_ok=True)
INK='#503b35'; CREAM='#fff2cf'; PINK='#e78994'; GREEN='#788f5b'; DARK='#485d42'

def canvas(n=32):
    im=Image.new('RGBA',(n,n)); return im,ImageDraw.Draw(im)

def save(im,name): im.save(OUT/(name+'.png'))

def bears():
    master=Image.open(ROOT/'资产/原画/bear_master.png').convert('RGBA')
    for idx,name in enumerate(('yier','bubu')):
        im=master.crop((idx*master.width//2,0,(idx+1)*master.width//2,master.height))
        im.putalpha(im.getchannel('A').point(lambda a: 255 if a>=128 else 0))
        pixels=im.load()
        for y in range(im.height):
            for x in range(im.width):
                r,g,b,a=pixels[x,y]
                if r>170 and b>150 and g<110: pixels[x,y]=(0,0,0,0)
        bbox=im.getbbox()
        if bbox is None: raise ValueError('Empty bear master')
        im=im.crop(bbox)
        im.thumbnail((42,52),Image.Resampling.NEAREST)
        base=Image.new('RGBA',(64,64)); base.alpha_composite(im,((64-im.width)//2,58-im.height))
        save(base,name)
        # Five named rows x four frames; source character stays consistent across actions.
        sheet=Image.new('RGBA',(256,320))
        for row in range(5):
            for frame in range(4):
                b=base.copy()
                dx=0; dy=0
                if row==0: dy=[0,0,-1,0][frame]
                if row==1:
                    dy=[0,-2,0,-2][frame]; dx=[-1,0,1,0][frame]
                    if frame in (0,2):
                        feet=b.crop((14,48,50,62)); b.paste((0,0,0,0),(14,48,50,62)); b.alpha_composite(feet,(14+dx,48))
                if row==2:
                    tint=Image.new('RGBA',b.size,(255,133,133,0)); tint.putalpha(b.getchannel('A').point(lambda x:int(x*.55)))
                    b=Image.alpha_composite(b,tint); dx=[-2,2,-1,0][frame]
                if row==3:
                    b=b.rotate([0,-8,5,0][frame],resample=Image.Resampling.NEAREST)
                    dy=[0,-1,-2,0][frame]
                if row==4:
                    b=b.rotate(80,resample=Image.Resampling.NEAREST); b=Image.blend(b,ImageOps.grayscale(b).convert('RGBA'),.30)
                    b.putalpha(base.rotate(80,resample=Image.Resampling.NEAREST).getchannel('A'))
                sheet.alpha_composite(b,(frame*64+dx,row*64+dy))
        save(sheet,name+'_sheet')

def enemies():
    for kind in ('sprout','bee','mushroom','acorn','boss'):
        im,d=canvas(64)
        if kind=='sprout':
            d.ellipse((12,25,52,58),fill=INK); d.ellipse((15,27,49,55),fill='#b9c980')
            d.ellipse((18,28,44,45),fill='#d6dea0'); d.line((32,28,32,10),fill=DARK,width=4)
            d.ellipse((16,9,32,20),fill='#859e65'); d.ellipse((32,5,49,17),fill='#acbb75')
            d.rectangle((21,40,25,45),fill=INK); d.rectangle((38,40,42,45),fill=INK)
            d.line((29,47,33,48,36,46),fill=INK,width=2)
        elif kind=='bee':
            d.ellipse((7,12,27,35),fill='#d9e7d5'); d.ellipse((35,11,55,35),fill='#e9f1dc')
            d.ellipse((10,24,55,52),fill=INK); d.ellipse((13,26,52,49),fill='#edc574')
            d.rectangle((26,27,31,49),fill='#795344'); d.rectangle((39,28,43,47),fill='#795344')
            d.rectangle((16,34,20,39),fill=INK); d.rectangle((15,42,20,44),fill=PINK)
        elif kind=='mushroom':
            d.rounded_rectangle((20,29,46,58),7,fill=INK); d.rounded_rectangle((23,30,43,55),5,fill=CREAM)
            d.ellipse((4,6,59,43),fill=INK); d.ellipse((7,8,56,39),fill='#c36d65')
            d.rectangle((7,28,56,36),fill='#e6977d'); d.ellipse((16,15,25,24),fill=CREAM); d.ellipse((38,12,46,19),fill=CREAM)
            d.rectangle((26,43,29,47),fill=INK); d.rectangle((36,43,39,47),fill=INK)
        elif kind=='acorn':
            d.ellipse((13,18,52,57),fill=INK); d.ellipse((16,21,49,54),fill='#c59161')
            d.ellipse((11,12,54,32),fill=INK); d.ellipse((13,14,52,28),fill='#89704b')
            d.line((30,14,34,5,41,4),fill=DARK,width=4)
            for x in range(16,48,7): d.line((x,17,x+4,24),fill='#b09868',width=2)
            d.rectangle((24,33,27,38),fill=INK); d.rectangle((38,33,41,38),fill=INK)
            d.ellipse((28,40,39,49),fill=INK); d.ellipse((32,43,36,46),fill='#d9b17b')
        else:
            d.ellipse((2,15,62,61),fill=INK); d.ellipse((5,17,59,57),fill='#d2874d')
            for x in (14,27,39): d.arc((x-9,18,x+21,57),275,85,fill='#f2b65e',width=3)
            d.polygon([(12,37),(24,33),(24,41)],fill=INK); d.polygon([(40,33),(53,37),(40,41)],fill=INK)
            d.line((23,47,29,50,35,48,41,49),fill=INK,width=3)
            d.line((30,18,33,4,40,3),fill=DARK,width=5); d.ellipse((15,6,32,17),fill='#97a467')
            d.polygon([(17,16),(13,6),(24,9),(31,0),(37,10),(49,6),(45,18)],fill='#edce85',outline=INK)
        save(im,kind)

def icons():
    for kind in ('heart','berry','leaf','boot','star','shield','flower','milk','wand','spoon','petal','needle','coin'):
        im,d=canvas()
        if kind in ('heart','berry','wand'):
            if kind=='wand': d.line((9,29,22,9),fill=INK,width=6); d.line((9,27,21,10),fill='#e4ba78',width=3)
            x,y=(18,11) if kind=='wand' else (16,16)
            d.polygon([(x-10,y-6),(x-5,y-10),(x,y-6),(x+5,y-10),(x+10,y-6),(x+10,y),(x,y+11),(x-10,y)],fill=INK)
            d.polygon([(x-8,y-5),(x-4,y-7),(x,y-3),(x+4,y-7),(x+8,y-5),(x+7,y),(x,y+8),(x-7,y)],fill='#e7868d')
            if kind!='heart':
                d.polygon([(x-7,y-8),(x-3,y-11),(x,y-7),(x+5,y-12),(x+7,y-6)],fill=GREEN)
                for dx,dy in ((-4,0),(3,0),(0,4)): d.point((x+dx,y+dy),fill=CREAM)
        elif kind=='spoon':
            d.line((7,29,21,10),fill=INK,width=7); d.line((8,28,21,11),fill='#ba8759',width=3)
            d.ellipse((14,1,29,18),fill=INK); d.ellipse((16,3,27,15),fill='#efbf6b'); d.ellipse((19,5,25,12),fill='#bf8e50')
        elif kind in ('star','needle'):
            if kind=='needle': d.line((4,27,24,7),fill=INK,width=6); d.line((5,26,24,7),fill='#e1dbc4',width=3)
            d.polygon([(17,2),(21,11),(30,13),(23,19),(24,29),(16,24),(8,29),(9,20),(2,13),(12,10)],fill=INK)
            d.polygon([(17,6),(20,13),(26,14),(20,18),(21,24),(16,20),(11,24),(12,18),(6,14),(14,13)],fill='#f4d78c')
        elif kind in ('petal','flower'):
            for x,y in ((9,9),(22,9),(7,20),(23,21),(16,25)): d.ellipse((x-5,y-5,x+5,y+5),fill=INK); d.ellipse((x-3,y-3,x+3,y+3),fill='#f0b7af')
            d.ellipse((10,10,22,22),fill='#eaca83')
        elif kind=='leaf':
            d.ellipse((8,3,27,26),fill=DARK); d.ellipse((10,5,25,24),fill='#aac17a'); d.line((6,29,22,9),fill='#5e794d',width=2)
        elif kind=='shield':
            d.polygon([(4,4),(16,1),(28,4),(26,22),(16,30),(6,22)],fill=INK)
            d.polygon([(7,7),(16,4),(25,7),(23,20),(16,26),(9,20)],fill='#93ada0'); d.line((16,6,16,24),fill=CREAM,width=2)
        elif kind=='boot':
            d.polygon([(8,4),(21,4),(21,18),(29,21),(29,28),(5,28),(5,20)],fill=INK); d.polygon([(10,6),(19,6),(19,21),(27,23),(27,25),(8,25)],fill='#c79775')
        elif kind=='milk':
            d.rounded_rectangle((9,3,23,29),3,fill=INK); d.rectangle((11,9,21,26),fill=CREAM); d.rectangle((11,3,21,8),fill='#a7c2b1'); d.rectangle((13,15,20,22),fill=PINK)
        else:
            d.ellipse((4,3,28,29),fill=INK); d.ellipse((6,5,26,27),fill='#e8c775'); d.ellipse((9,8,23,24),outline='#b6894c',width=2); d.line((16,11,16,21),fill=CREAM,width=3)
        save(im,kind)

def environment():
    rng=random.Random(928)
    im=Image.new('RGB',(800,520),'#90a873'); d=ImageDraw.Draw(im)
    # Low-contrast grass so hostile shots and character silhouettes stay legible.
    for _ in range(11500):
        x,y=rng.randrange(800),rng.randrange(520)
        c=rng.choice(('#8ca56e','#94ab76','#99af7a','#86a06b'))
        d.rectangle((x,y,x+rng.randrange(1,5),y+1),fill=c)
    d.rounded_rectangle((335,210,465,310),32,fill='#b6b789')
    d.rounded_rectangle((343,218,457,302),30,fill='#c5bf95')
    for _ in range(250):
        x,y=rng.randrange(350,450),rng.randrange(220,300)
        d.point((x,y),fill='#b8b38b')
    for _ in range(150):
        x,y=rng.randrange(35,765),rng.randrange(35,485)
        d.line((x,y,x-2,y-3),fill='#708c59'); d.line((x,y,x+2,y-4),fill='#708c59')
    for x in range(12,800,18):
        for y in (10,503):
            d.rectangle((x,y,x+5,y+12),fill=INK); d.rectangle((x+1,y+1,x+4,y+10),fill='#b59669')
    for y in (13,20,506,513): d.rectangle((12,y,788,y+2),fill='#a18760')
    for y in range(27,503,18):
        for x in (12,782):
            d.rectangle((x,y,x+5,y+12),fill=INK); d.rectangle((x+1,y+1,x+4,y+10),fill='#b59669')
    for x in (14,785): d.rectangle((x,26,x+2,502),fill='#a18760')
    for _ in range(220):
        x,y=rng.randrange(800),rng.randrange(520)
        if 42<x<758 and 42<y<478: continue
        d.ellipse((x-7,y-4,x+7,y+6),fill='#56764a'); d.ellipse((x-5,y-5,x+5,y+3),fill='#729253')
        if rng.random()<.5:
            d.rectangle((x-2,y-1,x+2,y+1),fill='#f1d7aa'); d.rectangle((x,y-2,x,y+2),fill=CREAM)
            d.point((x,y),fill='#daa66a')
    save(im,'garden')
    im,d=canvas(64)
    d.ellipse((4,25,60,60),fill='#59734d'); d.ellipse((8,7,56,53),fill=INK)
    d.ellipse((11,9,53,49),fill='#879584'); d.polygon([(16,18),(37,11),(48,26),(39,35),(14,35)],fill='#a4ae99')
    d.line((23,13,30,26,24,35),fill='#6c7d71',width=2)
    for x,y in ((8,42),(39,47),(49,37)): d.ellipse((x,y,x+10,y+7),fill='#69884e')
    save(im,'rock')

def sound():
    folder=ROOT/'audio'; folder.mkdir(exist_ok=True)
    rate=22050
    def write(name,samples):
        with wave.open(str(folder/(name+'.wav')),'wb') as w:
            w.setparams((1,2,rate,0,'NONE','not compressed'))
            w.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v))*32767)) for v in samples))
    for name,freq,duration in [('click',640,.065),('hit',180,.08),('pickup',900,.08),('skill',480,.42),('level',740,.35),('hurt',125,.16)]:
        write(name,[math.sin(2*math.pi*freq*(1+(t/rate/duration)*.6)*(t/rate))*math.exp(-5*t/rate/duration)*.22 for t in range(int(rate*duration))])
    # Original 16-bar, 90 BPM music loop with a soft plucked melody and bass.
    beat=60/90; duration=32*beat; samples=[0.0]*int(rate*duration)
    notes=[72,76,79,76,74,77,81,77,71,74,79,74,69,72,76,72,72,79,84,79,74,77,81,79,76,74,72,71,69,71,72,67]
    for n,midi in enumerate(notes):
        freq=440*2**((midi-69)/12)
        start=int(n*beat*rate)
        for i in range(min(int(beat*1.5*rate),len(samples)-start)):
            t=i/rate; env=math.exp(-t*5)*min(1,t*80)
            samples[start+i]+=(math.sin(2*math.pi*freq*t)+.25*math.sin(2*math.pi*freq*2*t))*env*.09
        if n%4==0:
            bass=440*2**((([48,53,55,45][(n//4)%4])-69)/12)
            for i in range(min(int(beat*3*rate),len(samples)-start)):
                t=i/rate; samples[start+i]+=math.sin(2*math.pi*bass*t)*math.exp(-t*2)*.065
    write('garden_loop',samples)

def font():
    path=ROOT/'assets/fonts'; path.mkdir(parents=True,exist_ok=True)
    target=path/'NotoSansSC.ttf'
    if not target.exists():
        print('Downloading OFL Noto Sans SC font',flush=True)
        urllib.request.urlretrieve('https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf',target)
        urllib.request.urlretrieve('https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt',path/'OFL.txt')

if __name__=='__main__':
    bears(); enemies(); icons(); environment(); sound(); font()
    icon=Image.new('RGBA',(128,128),'#7e966a')
    for name,x in [('yier',-1),('bubu',55)]:
        b=Image.open(OUT/(name+'.png')).resize((76,76),Image.Resampling.NEAREST); icon.alpha_composite(b,(x,24))
    icon.resize((512,512),Image.Resampling.NEAREST).save(OUT/'icon.png')
    art=Image.open(ROOT/'资产/原画/garden_keyart.png').convert('RGB')
    art.resize((1536,1024),Image.Resampling.LANCZOS).save(OUT/'menu.jpg',quality=92)
    print('Assets, five animation rows per bear, font and audio ready')
