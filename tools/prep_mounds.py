"""The forest mounds behind the platforms (0.49, more in 0.50), from PixelLab's pictures in assets/src/hills
(monticule-1 to 4): trimmed to what they show, then darkened to the same brightness (about 72 % of the
0.49 mound's) and a little greyer, so that the platforms in front stand out. Writes
assets/img/hill-forest-3.png to hill-forest-6.png (art.gd HILL_SETS, render.gd draw_hills).

    python tools/prep_mounds.py
"""
import colorsys
import pathlib

from PIL import Image

here = pathlib.Path(__file__).resolve().parent.parent
src = here / 'assets' / 'src' / 'hills'
out = here / 'assets' / 'img'
TARGET = 46.5                       # the mean brightness of their opaque pixels (0.49's mound: 64.6)
GREY = 0.85                         # saturation kept


def trim(im):
    box = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    return im.crop(box) if box else im


def mean(im):
    px = im.load()
    v = [0.3 * px[x, y][0] + 0.59 * px[x, y][1] + 0.11 * px[x, y][2] for y in range(im.height) for x in range(im.width) if px[x, y][3] > 128]
    return sum(v) / len(v)


for i in range(1, 5):
    im = trim(Image.open(src / f'monticule-{i}.png').convert('RGBA'))
    k = max(0.6, min(1.15, TARGET / mean(im)))
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s * GREY, min(1, v * k))
            px[x, y] = (round(r2 * 255), round(g2 * 255), round(min(1, b2 * 1.04) * 255), a)
    im.save(out / f'hill-forest-{i + 2}.png')
    print(f'hill-forest-{i + 2}.png', im.size, 'x%.2f' % k, round(mean(im), 1))
