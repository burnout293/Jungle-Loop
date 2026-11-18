"""Coloured buttons made from the UI kit's own (assets/img/ui-v2/btn-<state>-<h>.png), for Jouer (a gold
frame, taller: 58), Reprendre (a green plate) and Abandonner (a red-orange plate). Nothing is drawn by
hand: the stone keeps its pixels, only their colours change (a gradient on their brightness); the
leaves keep theirs. The inner plate is found by filling from the middle across like colours.

    python tools/make_ui_colours.py            (writes assets/img/ui-v2/btn-<state>-<h>-<colour>.png)
"""
import colorsys
import os
import sys
from PIL import Image

KIT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'img', 'ui-v2')
STATES = ['normal', 'hover', 'pressed', 'disabled']


def lum(p):
    return (0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]) / 255


def leafy(p):
    h, l, s = colorsys.rgb_to_hls(p[0] / 255, p[1] / 255, p[2] / 255)
    return 0.17 < h < 0.45 and s > 0.35 and p[1] > p[2] + 10


def inner_mask(im):
    """The plate inside the frame: filled from the middle while the brightness stays close."""
    w, h = im.size
    px = im.load()
    seen = set()
    c = px[w // 2, h // 2]
    base = lum(c)
    todo = [(w // 2, h // 2)]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        p = px[x, y]
        if p[3] == 0 or abs(lum(p) - base) > 0.11 or leafy(p):
            continue
        seen.add((x, y))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


def gmap(p, stops):
    l = lum(p)
    for i in range(len(stops) - 1):
        l0, c0 = stops[i]
        l1, c1 = stops[i + 1]
        if l <= l1 or i == len(stops) - 2:
            k = max(0.0, min(1.0, (l - l0) / (l1 - l0)))
            return tuple(int(c0[j] + (c1[j] - c0[j]) * k) for j in range(3)) + (p[3],)


GOLD = [(0.0, (40, 22, 6)), (0.18, (110, 66, 12)), (0.4, (196, 142, 36)), (0.62, (246, 204, 84)), (0.85, (255, 244, 190))]
GREEN = [(0.0, (8, 30, 14)), (0.2, (22, 92, 40)), (0.4, (46, 150, 62)), (0.6, (110, 206, 96)), (0.85, (200, 250, 170))]
RED = [(0.0, (34, 8, 6)), (0.2, (120, 34, 14)), (0.4, (196, 70, 26)), (0.6, (240, 128, 54)), (0.85, (255, 214, 160))]


def recolour(im, frame_stops, plate_stops, lift=0.0):
    out = im.copy()
    px = out.load()
    plate = inner_mask(im)
    w, h = im.size
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] == 0 or leafy(p):
                continue
            q = (min(255, p[0] + lift * 255), min(255, p[1] + lift * 255), min(255, p[2] + lift * 255), p[3])
            if (x, y) in plate:
                if plate_stops:
                    px[x, y] = gmap(q, plate_stops)
            elif frame_stops and lum(p) > 0.12:   # the dark outline stays dark
                px[x, y] = gmap(q, frame_stops)
    return out


def taller(im, extra):
    """The same button `extra` pixels taller: its middle row repeated (the plate is plain there)."""
    w, h = im.size
    mid = h // 2
    out = Image.new('RGBA', (w, h + extra))
    out.paste(im.crop((0, 0, w, mid)), (0, 0))
    row = im.crop((0, mid, w, mid + 1))
    for k in range(extra):
        out.paste(row, (0, mid + k))
    out.paste(im.crop((0, mid, w, h)), (0, mid + extra))
    return out


def main():
    made = []
    for st in STATES:
        b50 = Image.open(os.path.join(KIT, 'btn-%s-50.png' % st)).convert('RGBA')
        b38 = Image.open(os.path.join(KIT, 'btn-%s-38.png' % st)).convert('RGBA')
        jobs = {
            'btn-%s-58-gold.png' % st: recolour(taller(b50, 8), GOLD, None, 0.04 if st == 'hover' else 0.0),
            'btn-%s-50-green.png' % st: recolour(b50, None, GREEN, 0.06 if st == 'hover' else 0.0),
            'btn-%s-38-green.png' % st: recolour(b38, None, GREEN, 0.06 if st == 'hover' else 0.0),
            'btn-%s-38-red.png' % st: recolour(b38, None, RED, 0.06 if st == 'hover' else 0.0),
            'btn-%s-50-red.png' % st: recolour(b50, None, RED, 0.06 if st == 'hover' else 0.0),
        }
        for name, im in jobs.items():
            im.save(os.path.join(KIT, name))
            made.append(name)
    print('\n'.join(made))


if __name__ == '__main__':
    sys.exit(main())
