"""The relic (0.50): the jaguar mask chosen (PixelLab, assets/src/relique/relique-jaguar.png, proposal B3), its
golden lattice, pendants and vines taken away, cut into its five pieces, which lie exactly on each other:

    relique-coeur.png         the heart, the piece Pépito stole (teal)
    relique-couronne.png      the crown of leaves (jade): its socket stays dark when the heart is not in it
    relique-tete-gauche.png   the left half of the head (amber)
    relique-tete-droite.png   the right half of the head (ember red)
    relique-machoire.png      the jaw (moonstone violet)
    relique-complete.png      the five together, a dark seam between them

The crown, the heart and the jaw are found by their colours (green, teal, violet: what they enclose, the
mouth and its teeth, goes with them); the head is cut down the middle, the nose's tip with the left half. Writes assets/img/relic/.

    python tools/cut_relic.py
"""
import colorsys
import pathlib
from collections import deque

from PIL import Image, ImageDraw

here = pathlib.Path(__file__).resolve().parent.parent
src = Image.open(here / 'assets' / 'src' / 'relique' / 'relique-jaguar.png').convert('RGBA')
out = here / 'assets' / 'img' / 'relic'
out.mkdir(exist_ok=True)
W, H = src.size
INK = (38, 18, 22, 255)                 # the picture's own outline colour
SOCKET = (24, 40, 38, 255)              # the heart's empty place in the crown

# the head alone: everything outside this outline is the lattice, the pendants, the vines
HEAD = [(64, 4), (72, 8), (83, 9), (86, 15), (93, 16), (96, 22), (99, 25), (107, 26), (105, 34), (101, 44), (99, 54),
        (98, 66), (96, 78), (92, 86), (88, 89), (86, 96), (83, 106), (77, 113), (68, 116), (57, 116), (48, 113),
        (42, 105), (40, 94), (37, 89), (34, 85), (32, 74), (31, 60), (30, 50), (27, 40), (21, 26), (29, 24), (33, 18),
        (39, 12), (46, 9), (55, 7)]
mask = Image.new('L', src.size, 0)
ImageDraw.Draw(mask).polygon(HEAD, fill=255)
head = Image.new('RGBA', src.size)
head.paste(src, (0, 0), mask)
px = head.load()


def hsv(c):
    h, s, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
    return h * 360, s, v


for y in range(H):                      # the vines' ends left over the jaw's sides
    for x in range(W):
        h, s, v = hsv(px[x, y])
        if px[x, y][3] and y > 70 and 70 < h < 170 and s > 0.25:
            px[x, y] = (0, 0, 0, 0)

# an outline where the lattice was cut away
edge = []
for y in range(H):
    for x in range(W):
        if px[x, y][3]:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] and hsv(px[nx, ny])[2] > 0.3:
                edge.append((x, y))
                break
for x, y in edge:
    px[x, y] = INK

# the pieces. The crown (green), the heart (teal) and the jaw (violet) by their colour, holes filled (the
# mouth, the eyes of the band) and their own outline taken along; the rest is the head, cut down the middle,
# the nose's tip going with the left half (a tab that locks the two halves).
def colour_mask(test):
    m = {(x, y) for y in range(H) for x in range(W) if px[x, y][3] and test(x, y, *hsv(px[x, y]))}
    outside = set()                      # what the outside reaches without crossing the mask: the rest is inside
    todo = deque([(0, 0)])
    while todo:
        q = todo.popleft()
        if q in outside or q in m or not (0 <= q[0] < W and 0 <= q[1] < H):
            continue
        outside.add(q)
        todo.extend(((q[0] + 1, q[1]), (q[0] - 1, q[1]), (q[0], q[1] + 1), (q[0], q[1] - 1)))
    m |= {(x, y) for y in range(H) for x in range(W) if (x, y) not in outside and px[x, y][3]}
    for _ in range(2):                   # its dark outline
        m |= {(x + dx, y + dy) for (x, y) in list(m) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
              if 0 <= x + dx < W and 0 <= y + dy < H and px[x + dx, y + dy][3] and hsv(px[x + dx, y + dy])[2] < 0.3}
    return m


heart = colour_mask(lambda x, y, h, s, v: 160 <= h <= 200 and s > 0.3 and 48 <= x <= 80 and 34 <= y <= 64)
crown = colour_mask(lambda x, y, h, s, v: 70 <= h <= 200 and s > 0.25 and y < 68) - heart
violet = colour_mask(lambda x, y, h, s, v: 250 <= h <= 330 and s > 0.2 and y > 66)


def hull(points):                        # convex hull (monotone chain): the jaw is all its violet encloses
    pts = sorted(points)
    def half(seq):
        h = []
        for q in seq:
            while len(h) >= 2 and (h[-1][0] - h[-2][0]) * (q[1] - h[-2][1]) - (h[-1][1] - h[-2][1]) * (q[0] - h[-2][0]) <= 0:
                h.pop()
            h.append(q)
        return h
    lo, up = half(pts), half(pts[::-1])
    return lo[:-1] + up[:-1]


hm = Image.new('L', src.size, 0)
ImageDraw.Draw(hm).polygon(hull(violet), fill=255)
hp = hm.load()
jaw = {(x, y) for y in range(H) for x in range(W) if px[x, y][3] and hp[x, y]} - crown - heart
label = {}
for y in range(H):
    for x in range(W):
        if not px[x, y][3]:
            continue
        q = (x, y)
        if q in heart:
            label[q] = 'coeur'
        elif q in crown:
            label[q] = 'couronne'
        elif q in jaw:
            label[q] = 'machoire'
        else:
            cut = 68 if 60 <= y <= 70 else 64
            label[q] = 'tete-gauche' if x < cut else 'tete-droite'

def islands():                            # bits of a piece cut off from it (a few pixels): to the piece they touch most
    seen = set()
    for q0 in list(label):
        if q0 in seen:
            continue
        n0 = label[q0]
        comp, todo = [], deque([q0])
        seen.add(q0)
        while todo:
            q = todo.popleft()
            comp.append(q)
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                r = (q[0] + d[0], q[1] + d[1])
                if r in label and r not in seen and label[r] == n0:
                    seen.add(r)
                    todo.append(r)
        if len(comp) < 40:
            touch = {}
            for q in comp:
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    r = (q[0] + d[0], q[1] + d[1])
                    if r in label and label[r] != n0:
                        touch[label[r]] = touch.get(label[r], 0) + 1
            if touch:
                to = max(touch, key=touch.get)
                for q in comp:
                    label[q] = to
            else:
                for q in comp:
                    px[q] = (0, 0, 0, 0)
                    del label[q]


islands()
islands()

NAMES = ['coeur', 'couronne', 'tete-gauche', 'tete-droite', 'machoire']
pieces = {n: Image.new('RGBA', src.size) for n in NAMES}
for (x, y), n in label.items():
    pieces[n].putpixel((x, y), px[x, y])
for (x, y), n in label.items():          # the crown's socket: what the heart covers, dark
    if n == 'coeur':
        pieces['couronne'].putpixel((x, y), SOCKET)
full = Image.new('RGBA', src.size)
for n in NAMES[1:] + ['coeur']:
    full.alpha_composite(pieces[n])
fp = full.load()
for (x, y), n in label.items():          # a dark seam where two pieces meet (drawn on the lower-right one)
    for dx, dy in ((-1, 0), (0, -1)):
        q = (x + dx, y + dy)
        if q in label and label[q] != n and n != 'coeur' and label[q] != 'coeur':
            fp[x, y] = INK
            break
for n, im in pieces.items():
    im.save(out / f'relique-{n}.png')
full.save(out / 'relique-complete.png')
print({n: sum(1 for v in label.values() if v == n) for n in NAMES})
