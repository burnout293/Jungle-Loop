"""(0.70) The heights' waterfalls, found in their pictures (heights-mid, heights-bg) so the game can make them
flow (art.gd: falls). A waterfall's column: pixels lighter than both their neighbours a few pixels aside (or the
mid's wide fall: very light, bluish white), running down at least MIN_RUN pixels. Writes assets/img/heights-falls.json:
{picture: [[x, y0, y1], ...]}.   python tools/find_falls.py"""
import json
from PIL import Image

MIN_RUN = 14
OUT = 'assets/img/heights-falls.json'


def lum(p):
    return 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]


def columns(name, test, ymax):
    im = Image.open('assets/img/%s.png' % name).convert('RGBA')
    W, H = im.size
    px = im.load()
    out = []
    for x in range(3, W - 3):
        run0 = None
        for y in range(0, ymax + 1):
            on = y < ymax and px[x, y][3] > 200 and test(px, x, y)
            if on and run0 is None:
                run0 = y
            elif not on and run0 is not None:
                if y - run0 >= MIN_RUN:
                    out.append([x, run0, y - 1])
                run0 = None
    return out


def mid_test(px, x, y):
    p = px[x, y]
    return p[0] > 170 and p[1] > 190 and p[2] > 190 and p[2] >= p[0]


def bg_test(px, x, y):
    c = lum(px[x, y])
    return c > lum(px[x - 3, y]) + 9 and c > lum(px[x + 3, y]) + 9


falls = {'heights-mid': columns('heights-mid', mid_test, 212), 'heights-bg': columns('heights-bg', bg_test, 250)}
json.dump(falls, open(OUT, 'w'))
for k, v in falls.items():
    xs = sorted(set(c[0] for c in v))
    print(k, len(v), 'columns, x from', xs[:3], 'to', xs[-3:], 'rows', min(c[1] for c in v), max(c[2] for c in v))
