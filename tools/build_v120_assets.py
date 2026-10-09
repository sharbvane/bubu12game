"""Slice image2.5 atlases using actual dimensions, fixed foot anchors, no limb stretching."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'资产/精灵'

def cells(file,columns,rows):
    master=Image.open(ROOT/'资产/原画'/file).convert('RGBA')
    master.putalpha(master.getchannel('A').point(lambda a:255 if a>=240 else 0))
    for y in range(rows):
        for x in range(columns):
            im=master.crop((round(x*master.width/columns),round(y*master.height/rows),round((x+1)*master.width/columns),round((y+1)*master.height/rows)))
            box=im.getbbox()
            assert box, (file,x,y)
            yield im.crop(box)

def plate(im,name,size=80,padding=4):
    im=im.copy(); im.thumbnail((size-padding*2,size-padding*2),Image.Resampling.NEAREST)
    out=Image.new('RGBA',(size,size)); out.alpha_composite(im,((size-im.width)//2,size-padding-im.height)); out.save(OUT/(name+'.png'))

def build():
    for i,im in enumerate(cells('v120_characters.png',3,2)):
        name=('yier' if i<3 else 'bubu')+'_'+['front','side','back'][i%3]
        plate(im,name,96,6)
    # Front view is literally the approved source silhouette, never a rebuilt doll.
    for name,im in zip(('yier','bubu'),cells('bear_refined.png',2,1)):
        plate(im,name+'_front',96,6); plate(im,name+'_portrait',192,12)
    garden=['core_0','core_1','core_2','core_3','core_4','fence','turret','mortar','frost','fountain','scarecrow','spikes','spring','repair','trap','snail']
    for key,im in zip(garden,cells('v120_garden.png',4,4)): plate(im,key,128 if key.startswith('core') or key=='snail' else 96)
    enemy=['sprout','charger','acorn','mole','termite','crow','shield_bug','bomber','healer','mimic','moth','leech']
    for key,im in zip(enemy,cells('v120_enemies.png',4,3)): plate(im,key,72)
    inventory=['slingshot','shears','shovel','honey','bubble','star_wand','radish','thread','moon','flame','magnet_cap','mechanic','first_guard','thorn_vest','dash_boots','runner','skill_stone','lucky','couple','shock','familiar','lantern','purse','world','bomb','heal_seed','fence_kit','decoy','home','vacuum','mirror','freeze','dice','rocket','banana','toolbox']
    for key,im in zip(inventory,cells('v120_inventory.png',6,6)):
        plate(im,key,64)
        if key in inventory[1:10]:
            # Texture rotated so its handle sits at a stable left grip; no orbiting.
            rotated=im.rotate(-45,expand=True,resample=Image.Resampling.NEAREST)
            rotated=rotated.crop(rotated.getbbox()); rotated.thumbnail((43,31),Image.Resampling.NEAREST)
            hand=Image.new('RGBA',(52,40)); hand.alpha_composite(rotated,(6,(40-rotated.height)//2)); hand.save(OUT/('held_'+key+'.png'))
    assert all((OUT/(key+'.png')).is_file() for key in garden+enemy+inventory)
    print('V120_ATLASES_SLICED: 6 views, 16 garden sprites, 12 enemies, 36 icons')

if __name__=='__main__': build()
