"""The mounds behind the road, from PixelLab's pictures in assets/src/hills: the forest's behind its platforms
(0.49, more in 0.50: monticule-1 to 4) and the dungeon's (0.51: donjon-1 to 4, heaps of its fallen masonry).
Trimmed to what they show, then brought to one brightness per scenery and a little greyer, so that what is
in front stands out. Writes assets/img/hill-forest-3.png to hill-forest-6.png and hill-dungeon-1.png to
hill-dungeon-4.png (art.gd HILL_SETS, render.gd draw_hills).

    python tools/prep_mounds.py
"""
import colorsys
import pathlib

from PIL import Image

here = pathlib.Path(__file__).resolve().parent.parent
src = here / 'assets' / 'src' / 'hills'
out = here / 'assets' / 'img'
# source, written as, first number written, mean brightness of their opaque pixels (0.49's mound: 64.6),
# saturation kept
SETS = [('monticule-%d', 'hill-forest-%d', 3, 46.5, 0.85), ('donjon-%d', 'hill-dungeon-%d', 1, 50.0, 0.9)]


def trim(im):
    box = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    return im.crop(box) if box else im


def mean(im):
    px = im.load()
    v = [0.3 * px[x, y][0] + 0.59 * px[x, y][1] + 0.11 * px[x, y][2] for y in range(im.height) for x in range(im.width) if px[x, y][3] > 128]
    return sum(v) / len(v)


for name, out_name, first, target, grey in SETS:
    for i in range(1, 5):
        f = src / (name % i + '.png')
        if not f.exists():
            continue
        im = trim(Image.open(f).convert('RGBA'))
        k = max(0.6, min(1.15, target / mean(im)))
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if not a:
                    continue
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                r2, g2, b2 = colorsys.hsv_to_rgb(h, s * grey, min(1, v * k))
                px[x, y] = (round(r2 * 255), round(g2 * 255), round(min(1, b2 * 1.04) * 255), a)
        n = out_name % (first + i - 1)
        im.save(out / f'{n}.png')
        print(f'{n}.png', im.size, 'x%.2f' % k, round(mean(im), 1))
