"""Slice the approved image25 v1.4 atlases into game-ready pixel sprites."""
from PIL import Image, ImageDraw
from build_v120_assets import ROOT, OUT, cells, plate
from build_v130_assets import isolate

ENEMIES = [
    'queen_wasp', 'queen_wasp_down', 'moon_treant', 'moon_treant_down',
    'wasp', 'thornling', 'hedgehog', 'seedcaster',
    'shade', 'crystal_crab', 'spore_bat', 'root_brute',
]
INVENTORY = [
    'bee_blade', 'hive_bow', 'prism_staff', 'root_hammer',
    'hive_helm', 'petal_mantle', 'moon_boots', 'root_charm',
    'nectar', 'thorn_orb', 'moonbell', 'rescue_flower',
    'beehive', 'wall', 'moon_lantern', 'root_tower',
]

def build():
    gallery = Image.new('RGB', (4*180, 7*194), (246, 239, 217))
    draw = ImageDraw.Draw(gallery)
    for i, (key, im) in enumerate(zip(ENEMIES, cells('v140_enemies.png', 4, 3))):
        plate(isolate(im), key, 160 if i < 4 else 80, 5)
    for key, im in zip(INVENTORY, cells('v140_inventory.png', 4, 4)):
        im = isolate(im)
        plate(im, key, 80 if key in INVENTORY[:12] else 96, 5)
        if key in INVENTORY[:4]:
            rotated = im.rotate(-45, expand=True, resample=Image.Resampling.NEAREST)
            rotated = rotated.crop(rotated.getbbox())
            rotated.thumbnail((43, 31), Image.Resampling.NEAREST)
            hand = Image.new('RGBA', (52, 40))
            hand.alpha_composite(rotated, (6, (40-rotated.height)//2))
            hand.save(OUT / ('held_'+key+'.png'))
    for i, key in enumerate(ENEMIES+INVENTORY):
        im = Image.open(OUT/(key+'.png')).resize((128,128), Image.Resampling.NEAREST)
        x, y = i % 4*180+26, i // 4*194+5
        gallery.paste(im, (x,y), im)
        draw.text((i%4*180+8,y+132), key, fill=(75,67,49))
    preview = ROOT/'tests/output/v140_assets.png'
    preview.parent.mkdir(parents=True, exist_ok=True)
    gallery.save(preview)
    print('V140_ASSETS_PASS:', len(ENEMIES), 'enemy states,', len(INVENTORY), 'items; preview', preview)

if __name__ == '__main__': build()
