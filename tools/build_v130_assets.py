"""image25 sheets -> crisp full-body costumes and UI icons, preserving foot anchors."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
from build_v120_assets import cells, plate, OUT, ROOT

THEMES=['casual','garden','adventure','pajamas','spring','magic']
ICONS=['ui_cat_weapon','ui_cat_gear','ui_cat_charm','ui_cat_item','ui_cat_build','ui_cat_core',
       'ui_slot_offhand','ui_slot_hand','ui_slot_head','ui_slot_body','ui_slot_feet','ui_slot_charm',
       'ui_slot_item','core_hp','core_regen','core_armor','core_aura','core_repair',
       'core_shield','core_guard','core_attack','core_vine','ui_slot_build','ui_coin']
UPGRADES=['spoon','wand','ui_thread_unused','petal','ui_upgrade_heart','ui_upgrade_regen','ui_upgrade_power','ui_upgrade_haste','ui_upgrade_speed','ui_upgrade_crit','ui_upgrade_armor','ui_upgrade_magnet','ui_upgrade_builder','ui_upgrade_area','ui_upgrade_cooldown','ui_skill']

def isolate(im):
    """Remove neighboring cell fragments while keeping connected outfit decorations."""
    mask=im.getchannel('A').filter(ImageFilter.MaxFilter(9))
    w,h=mask.size; data=bytearray(mask.tobytes()); best=[]
    for start in range(w*h):
        if data[start]==0: continue
        data[start]=0; stack=[start]; component=[]
        while stack:
            n=stack.pop(); component.append(n); x=n%w; y=n//w
            for q in ([n-1] if x else [])+([n+1] if x<w-1 else [])+([n-w] if y else [])+([n+w] if y<h-1 else []):
                if data[q]: data[q]=0; stack.append(q)
        if len(component)>len(best): best=component
    keep=bytearray(w*h)
    for n in best: keep[n]=255
    alpha=im.getchannel('A')
    from PIL import ImageChops
    im.putalpha(ImageChops.multiply(alpha,Image.frombytes('L',(w,h),bytes(keep))))
    return im.crop(im.getbbox())

def build():
    gallery=Image.new('RGB',(960,6*208),(246,239,217)); draw=ImageDraw.Draw(gallery)
    for row,theme in enumerate(THEMES):
        for i,im in enumerate(cells('v130_'+theme+'.png',3,2)):
            key=('yier' if i<3 else 'bubu')+'_'+theme+'_'+['front','side','back'][i%3]
            plate(isolate(im),key,96,6)
            sprite=Image.open(OUT/(key+'.png')).resize((192,192),Image.Resampling.NEAREST)
            # Three views per character: gallery uses 160px display, game stays 96px.
            sprite=sprite.resize((160,160),Image.Resampling.NEAREST)
            gallery.paste(sprite,(i*160,row*208+24),sprite)
        draw.text((8,row*208+5),theme,fill=(75,67,49))
    master=Image.open(ROOT/'资产/原画/v130_icons.png').convert('RGBA')
    # This generated sheet has a taller first row; measured gutters, not assumed squares.
    ys=[0,290,516,748,1024]; xs=[0,256,512,768,1024,1260,1536]
    for i,key in enumerate(ICONS):
        row,col=divmod(i,6)
        im=master.crop((xs[col],ys[row],xs[col+1],ys[row+1]))
        im.putalpha(im.getchannel('A').point(lambda a:255 if a>=(100 if key.startswith('ui_slot_') else 240) else 0))
        plate(im.crop(im.getbbox()) if key=='ui_slot_feet' else isolate(im),key,80,5)
    gallery.save(ROOT/'tests/output/v130_costumes.png')
    preview=Image.new('RGB',(6*128,4*145),(246,239,217)); draw=ImageDraw.Draw(preview)
    for i,key in enumerate(ICONS):
        im=Image.open(OUT/(key+'.png')).resize((104,104),Image.Resampling.NEAREST)
        preview.paste(im,(i%6*128+12,i//6*145),im)
        draw.text((i%6*128+2,i//6*145+109),key,fill=(75,67,49))
    preview.save(ROOT/'tests/output/v130_icons.png')
    for key,im in zip(UPGRADES,cells('v130_upgrades.png',4,4)):
        if key!='ui_thread_unused': plate(isolate(im),key,80,5)
    im=next(cells('v130_crossbow.png',1,1)); plate(isolate(im),'needle',80,5)
    for theme in THEMES:
        for character in ['yier','bubu']:
            for view in ['front','side','back']:
                im=Image.open(OUT/(f'{character}_{theme}_{view}.png'))
                assert im.size==(96,96) and im.getbbox()[3]==90
    print('V130_ASSETS_PASS: 12 full costumes / 36 views / 40 icons; all foot anchors y=90')

if __name__=='__main__': build()
