"""Convert image25's 4x2 animation sheets into fixed-pivot Godot strips."""
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter
import numpy as np
import cv2

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / '资产' / '原画' / 'v150'
DEST = ROOT / '资产' / '动画'
DEST.mkdir(exist_ok=True)


def clean_background(cell: Image.Image, name: str) -> Image.Image:
    rgba = np.array(cell.convert('RGBA'))
    if name == 'bubu_melee':
        # This one generated sheet contains a brown vignette despite its alpha edges.
        rgb = rgba[:, :, :3].astype(np.int16)
        foreground = (rgb[:, :, 0] > 112) & (rgb[:, :, 1] > 70) & (rgba[:, :, 3] > 30)
        dark = (~foreground).astype(np.uint8)
        cv2.floodFill(dark, np.zeros((dark.shape[0]+2, dark.shape[1]+2), np.uint8), (0, 0), 2)
        foreground |= (dark == 1) & (rgba[:, :, 3] > 30)
        rgba[:, :, 3] = np.where(foreground, rgba[:, :, 3], 0).astype(np.uint8)
    if name.endswith('_down'):
        # Falling figures can bleed across the 4x2 row boundary. Keep the body,
        # discard disconnected fragments from the previous row.
        count, labels, stats, _ = cv2.connectedComponentsWithStats((rgba[:, :, 3] > 30).astype(np.uint8))
        if count > 1:
            largest = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
            rgba[:, :, 3] = np.where(labels == largest, rgba[:, :, 3], 0)
    return Image.fromarray(rgba, 'RGBA')


def convert(path: Path) -> tuple[str, float]:
    sheet = Image.open(path).convert('RGBA')
    w, h = sheet.width // 4, sheet.height // 2
    name = path.stem
    size = 192 if name.startswith(('snail_', 'queen_wasp_', 'moon_treant_')) else 128 if name.startswith(('yier_', 'bubu_', 'fx_')) else 96
    cells = [clean_background(sheet.crop((col*w, row*h, (col+1)*w, (row+1)*h)), name)
             for row in range(2) for col in range(4)]
    bounds = [c.getchannel('A').point(lambda a: 255 if a > 28 else 0).getbbox() for c in cells]
    if any(b is None for b in bounds):
        raise ValueError(f'{name}: empty frame')
    max_w = max(b[2]-b[0] for b in bounds)
    max_h = max(b[3]-b[1] for b in bounds)
    scale = min((size-10)/max_w, (size-10)/max_h)
    atlas = Image.new('RGBA', (size*8, size))
    previews = []
    for i, (cell, bbox) in enumerate(zip(cells, bounds)):
        figure = cell.crop(bbox)
        width = max(1, round(figure.width*scale))
        height = max(1, round(figure.height*scale))
        figure = figure.resize((width, height), Image.Resampling.NEAREST)
        canvas = Image.new('RGBA', (size, size))
        canvas.alpha_composite(figure, ((size-width)//2, size-5-height))
        # Make lost outlines in the vignette sheet visible without restoring its background.
        if name == 'bubu_melee':
            edge = canvas.getchannel('A').filter(ImageFilter.MaxFilter(3))
            under = Image.new('RGBA', (size, size), (67, 35, 22, 0))
            under.putalpha(edge)
            under.alpha_composite(canvas)
            canvas = under
        atlas.alpha_composite(canvas, (i*size, 0))
        previews.append(canvas)
    differences = []
    for a, b in zip(previews, previews[1:]+previews[:1]):
        diff = ImageChops.difference(a, b)
        differences.append(np.count_nonzero(np.asarray(diff.getchannel('A')) > 30)/(size*size))
    out = DEST / (name+'.png')
    atlas.save(out, optimize=True)
    return name, min(differences)


if __name__ == '__main__':
    results = [convert(p) for p in SOURCE.glob('*.png') if not p.stem.endswith('_master')]
    for name, difference in results:
        print(f'{name}: 8 frames; min adjacent silhouette change {difference:.1%}')
    assert results and all(d > .005 for _, d in results), 'A sheet contains nearly duplicate frames'
