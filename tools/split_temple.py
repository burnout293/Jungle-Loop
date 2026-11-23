"""The temple (0.52): seen from the side (PixelLab, assets/src/temple/temple-profil.png: the step pyramid, its
staircase climbing its right flank, and at its foot a corridor seen from the side whose open end, on the
right, is blocked by boulders), cut into three pictures of the same size that lie exactly on each other:

    temple.png        behind the floor: the pyramid, the corridor's roof, and the dark inside of its open end
                      (painted here: what the boulders hid, seen once they have blown out)
    temple-mid.png    on the floor: the boulders blocking the open end (not drawn once they have blown out)
    temple-front.png  in front of Pépito: the corridor's near wall and the open end's right pillar, so that he
                      comes out of the corridor and passes behind the pillar

Writes assets/img/temple*.png (render.gd TEMPLE_X, DOOR_X, TEMPLE_FLOOR). The 0.50 temple (front view) is kept
in Projects/Archives/Jungle-Loop/godot/temple-0.50.

    python tools/split_temple.py
"""
import pathlib

from PIL import Image

here = pathlib.Path(__file__).resolve().parent.parent
src = Image.open(here / 'assets' / 'src' / 'temple' / 'temple-profil.png').convert('RGBA')
out = here / 'assets' / 'img'
W, H = src.size
OPEN = (220, 177, 250, 218)             # the open end: x from, y from, x to, y to (the boulders)
DARK = [(13, 10, 24), (18, 16, 28), (22, 22, 34), (26, 30, 38)]   # its inside, darkest at the top


def front(x, y):
    return (176 <= x < OPEN[0] and y >= 156) or (x >= OPEN[2] and y >= 170)


def mid(x, y):
    return OPEN[0] <= x < OPEN[2] and OPEN[1] <= y < OPEN[3]


layers = {n: Image.new('RGBA', (W, H)) for n in ('temple', 'temple-mid', 'temple-front')}
p = src.load()
for y in range(H):
    for x in range(W):
        if not p[x, y][3]:
            continue
        name = 'temple-front' if front(x, y) else ('temple-mid' if mid(x, y) else 'temple')
        layers[name].putpixel((x, y), p[x, y])
back = layers['temple'].load()
for y in range(OPEN[1], OPEN[3]):       # the corridor's inside, behind the boulders
    k = (y - OPEN[1]) / (OPEN[3] - OPEN[1])
    for x in range(OPEN[0], OPEN[2]):
        c = DARK[min(len(DARK) - 1, int(k * len(DARK)))]
        if (x + y) % 2 and int(k * len(DARK) * 2) % 2:   # a dither between two rows of its darkness
            c = DARK[max(0, min(len(DARK) - 1, int(k * len(DARK)) - 1))]
        back[x, y] = c + (255,)
for name, im in layers.items():
    im.save(out / f'{name}.png')
    print(f'{name}.png', im.size, im.getbbox())
