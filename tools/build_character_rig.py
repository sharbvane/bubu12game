"""Split the image25 master into crisp pixel parts and aligned wearable sockets.
Reuses the approved character identity; generated images are never fetched here.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math, random, struct, wave
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'资产/精灵'
INK='#4c3228'

def save(im,name): im.save(OUT/(name+'.png'))
def canvas(w,h):
    im=Image.new('RGBA',(w,h)); return im,ImageDraw.Draw(im)

def characters():
    master=Image.open(ROOT/'资产/原画/bear_refined.png').convert('RGBA')
    for idx,name in enumerate(('yier','bubu')):
        im=master.crop((idx*master.width//2,0,(idx+1)*master.width//2,master.height))
        im.putalpha(im.getchannel('A').point(lambda a:255 if a>=240 else 0))
        im=im.crop(im.getbbox())
        portrait=im.copy(); portrait.thumbnail((164,174),Image.Resampling.NEAREST)
        plate=Image.new('RGBA',(192,192)); plate.alpha_composite(portrait,((192-portrait.width)//2,184-portrait.height)); save(plate,name+'_portrait')
        head=im.crop((0,0,im.width,round(im.height*.69))).resize((66,56),Image.Resampling.NEAREST)
        head=head.quantize(colors=28,method=Image.Quantize.FASTOCTREE).convert('RGBA')
        save(head,name+'_head')
        blink=head.copy(); d=ImageDraw.Draw(blink)
        for fraction in ((.29,.71) if name=='yier' else (.29,)):
            x=round(66*fraction); y=round(56*.63)
            skin=head.getpixel((x,y-7))
            d.rectangle((x-5,y-5,x+5,y+4),fill=skin)
            d.line((x-4,y,x,y+2,x+4,y),fill=INK,width=2)
        save(blink,name+'_blink')
        torso=im.crop((round(im.width*.23),round(im.height*.665),round(im.width*.77),round(im.height*.935))).resize((40,30),Image.Resampling.NEAREST)
        save(torso,name+'_torso')
        skin='#fff8e9' if name=='yier' else '#cf9e78'
        shade='#e4d8c1' if name=='yier' else '#ae7b58'
        arm,d=canvas(12,19); d.rounded_rectangle((1,0,10,17),4,fill=INK); d.rounded_rectangle((3,1,8,15),3,fill=skin); d.line((8,6,8,13),fill=shade,width=1)
        save(arm,name+'_arm')
        foot,d=canvas(16,12); d.rounded_rectangle((0,1,15,10),4,fill=INK); d.rounded_rectangle((2,1,13,8),3,fill=skin); d.line((4,7,11,7),fill=shade,width=1)
        save(foot,name+'_foot')
        paw,d=canvas(10,10); d.ellipse((0,0,9,9),fill=INK); d.ellipse((2,1,7,7),fill=skin); save(paw,name+'_paw')

def held_weapons():
    for name in ('wand','spoon','needle','petal'):
        im,d=canvas(52,32)
        if name=='spoon':
            d.rounded_rectangle((2,13,37,19),2,fill=INK); d.rectangle((4,15,37,17),fill='#c99861'); d.ellipse((29,4,50,28),fill=INK); d.ellipse((32,6,48,25),fill='#e7b76b'); d.ellipse((35,9,46,23),fill='#ba8449'); d.arc((35,9,46,23),230,60,fill='#ffdea2',width=2)
        elif name=='wand':
            d.rectangle((3,13,38,18),fill=INK); d.rectangle((5,14,39,16),fill='#cfa97b'); d.polygon([(31,8),(39,6),(48,10),(46,21),(38,28),(30,18)],fill=INK); d.polygon([(33,10),(39,8),(46,12),(44,20),(38,25),(32,17)],fill='#e68c92'); d.polygon([(30,8),(32,3),(38,6),(42,3),(47,8),(37,11)],fill='#8ea669')
            for x,y in [(35,14),(42,15),(38,21)]: d.rectangle((x,y,x+1,y+1),fill='#fff0c0')
        elif name=='needle':
            d.rectangle((3,12,45,19),fill=INK); d.rectangle((5,14,43,17),fill='#bb9163'); d.line((30,1,41,6,45,16,40,26,30,31),fill=INK,width=4); d.line((31,3,38,7,42,16,38,25,31,29),fill='#edce8e',width=2); d.line((30,3,34,16,30,28),fill='#dfdac5',width=1); d.line((17,15,50,15),fill='#fff0c5',width=2)
        else:
            d.rectangle((3,13,23,18),fill=INK); d.rectangle((5,14,26,16),fill='#92a87c')
            for x,y in [(32,8),(42,8),(27,17),(46,17),(35,25)]: d.ellipse((x-5,y-5,x+5,y+5),fill=INK); d.ellipse((x-3,y-3,x+3,y+3),fill='#edb1af')
            d.ellipse((32,12,42,22),fill='#ecc97e')
        save(im,'held_'+name)

def sounds():
    rate=22050; rng=random.Random(41)
    for name,freq,duration in [('swing',180,.19),('wand_fire',650,.15),('needle_fire',1100,.065),('petal_fire',520,.30),('impact',210,.10)]:
        data=[]
        for i in range(round(rate*duration)):
            t=i/rate; decay=math.exp(-t/duration*5)
            noise=rng.uniform(-1,1)
            value=math.sin(2*math.pi*freq*(t+.2*t*t/duration))*decay
            value=(value*.5+noise*.6 if name in ('swing','impact') else value)*.20
            data.append(struct.pack('<h',int(value*32767)))
        with wave.open(str(ROOT/'audio'/(name+'.wav')),'wb') as w:
            w.setparams((1,2,rate,0,'NONE','not compressed')); w.writeframes(b''.join(data))

if __name__=='__main__':
    raise SystemExit("Legacy rig retired. Use build_v120_assets.py and build_v130_assets.py; do not regenerate old costumes.")
