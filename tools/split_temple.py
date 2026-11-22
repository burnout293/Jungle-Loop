"""The temple of 0.50 (PixelLab, assets/src/temple/temple-complet.png, 256 x 256) cut into three layers of
the same size, which lie exactly on each other (render.gd draws them at the same place):

    temple.png        behind the floor: the pyramid, its stairs and the shrine on top
    temple-mid.png    on the floor: the porch, its doorway blocked by boulders, the steps, the terraces
    temple-front.png  in front of Pépito: the two jaguar pillars and the ferns at their feet

The picture's own grass and earth (row 225 and below) are cut off: the game's forest floor is drawn there.

    python tools/split_temple.py
"""
import pathlib

from PIL import Image

here = pathlib.Path(__file__).resolve().parent.parent
src = Image.open(here / 'assets' / 'src' / 'temple' / 'temple-complet.png').convert('RGBA')
H = 225                                   # rows kept (render.gd TEMPLE_FLOOR: row 222 stands on the floor line)
src = src.crop((0, 0, src.width, H))


def front(x, y):
    return y >= 126 and (x < 34 or x >= 221)


def mid(x, y):
    return (y >= 176 and 34 <= x < 221) or (94 <= x < 163 and y >= 124)


layers = {n: Image.new('RGBA', src.size) for n in ('temple', 'temple-mid', 'temple-front')}
px = src.load()
out = {n: im.load() for n, im in layers.items()}
for y in range(src.height):
    for x in range(src.width):
        c = px[x, y]
        if c[3] == 0:
            continue
        n = 'temple-front' if front(x, y) else ('temple-mid' if mid(x, y) else 'temple')
        out[n][x, y] = c
for n, im in layers.items():
    im.save(here / 'assets' / 'img' / f'{n}.png')
    print(n, im.size, im.getbbox())
