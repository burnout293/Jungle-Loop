"""The scenery behind the path (the « hills » of 0.43), from PixelLab's pictures kept in assets/src/hills:
trimmed to what they show, the containers without the strip of ground drawn under them, the whole ruin wall
broken (its top stepped down block by block, some blocks gone). Writes assets/img/hill-<scenery>-<n>.png.

    python tools/prep_hills.py
"""
import pathlib
import random
from PIL import Image

here = pathlib.Path(__file__).resolve().parent.parent
src = here / 'assets' / 'src' / 'hills'
out = here / 'assets' / 'img'


def trim(im):
    box = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    return im.crop(box) if box else im


def without_ground(im):
    """The rows at the bottom covered from edge to edge are the ground drawn under the containers."""
    w, h = im.size
    a = im.getchannel('A').load()
    y = h - 1
    while y > 0 and sum(1 for x in range(w) if a[x, y] > 8) > 0.93 * w:
        y -= 1
    return im.crop((0, 0, w, y + 1))


def broken(im, seed, block=16):
    """A whole wall made a ruin: its top steps down from the middle, blocks gone along the edge."""
    rnd = random.Random(seed)
    im = im.copy()
    w, h = im.size
    px = im.load()
    cols = (w + block - 1) // block
    tops = []
    for c in range(cols):
        e = abs((c + 0.5) / cols * 2 - 1)            # 0 in the middle, 1 at the ends
        keep = 1.0 - 0.55 * e ** 1.4 - rnd.uniform(0, 0.18)
        tops.append(int(h * (1 - max(0.25, min(1.0, keep)))))
    for c in range(cols):
        t = tops[c] // (block // 2) * (block // 2)   # stepped on half blocks
        for x in range(c * block, min(w, (c + 1) * block)):
            for y in range(0, min(h, t)):
                px[x, y] = (0, 0, 0, 0)
        if rnd.random() < 0.35 and t + block < h:    # a block gone just under the edge
            x0 = c * block + rnd.choice([0, block // 2])
            for x in range(x0, min(w, x0 + block // 2)):
                for y in range(t, min(h, t + block // 2)):
                    px[x, y] = (0, 0, 0, 0)
    return im


plan = [
    ('forest-1', 'forest-rock.png', None),
    ('forest-2', 'forest-root.png', None),
    ('ruins-1', 'ruins-wall-b.png', None),
    ('ruins-2', 'ruins-wall-a.png', 'broken'),
    # (the dungeon's walls, dungeon-door.png and dungeon-bars.png: taken out of the game in 0.44)
    ('city-1', 'city-building.png', None),
    ('city-2', 'city-containers.png', 'ground'),
]
for name, f, how in plan:
    im = Image.open(src / f).convert('RGBA')
    if how == 'ground':
        im = without_ground(trim(im))
    if how == 'broken':
        im = broken(im, 7)
    im = trim(im)
    im.save(out / f'hill-{name}.png')
    print(name, im.size)
