"""The relic (0.51): the jaguar mask (PixelLab, assets/src/relique/relique-jaguar.png, proposal B3), without its
golden lattice, pendants and vines, in four pieces that lie exactly on each other, each a slab with its own
thickness (its side drawn under it, its edges lit from the top left):

    relique-couronne.png      the crown of leaves (jade) with the heart set in it (teal)
    relique-tete-gauche.png   the left half of the head (amber)
    relique-tete-droite.png   the right half of the head (ember red)
    relique-machoire.png      the jaw (moonstone violet: all of it, its teeth too, repainted in the violet)
    relique-complete.png      the four together

The head under the crown comes from assets/src/relique/tete-nue.png: the same mask with its crown taken off and
its forehead painted again by PixelLab (inpainting, 22/11/2026). The head is cut straight down the middle.
Writes assets/img/relic/ (and assets/src/relique/relique-propre.png, the mask cleaned, one piece).

    python tools/cut_relic.py
"""
import colorsys
import pathlib
from collections import deque

from PIL import Image, ImageDraw

here = pathlib.Path(__file__).resolve().parent.parent
src = Image.open(here / 'assets' / 'src' / 'relique' / 'relique-jaguar.png').convert('RGBA')
bare = Image.open(here / 'assets' / 'src' / 'relique' / 'tete-nue.png').convert('RGBA')
out = here / 'assets' / 'img' / 'relic'
out.mkdir(exist_ok=True)
W, H = src.size
INK = (38, 18, 22, 255)                 # the picture's own outline colour
DEPTH = 3                               # a piece's thickness, in pixels (its side, under it)

# ---- the mask cleaned: the head alone (outside this outline: the lattice, the pendants, the vines) ----
HEAD = [(64, 4), (72, 8), (83, 9), (86, 15), (93, 16), (96, 22), (99, 25), (107, 26), (105, 34), (101, 44), (99, 54),
        (98, 66), (96, 78), (92, 86), (88, 89), (86, 96), (83, 106), (77, 113), (68, 116), (57, 116), (48, 113),
        (42, 105), (40, 94), (37, 89), (34, 85), (32, 74), (31, 60), (30, 50), (27, 40), (21, 26), (29, 24), (33, 18),
        (39, 12), (46, 9), (55, 7)]


def hsv(c):
    h, s, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
    return h * 360, s, v


def clean(im):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).polygon(HEAD, fill=255)
    res = Image.new('RGBA', im.size)
    res.paste(im, (0, 0), mask)
    p = res.load()
    for y in range(H):                  # the vines' ends left over the jaw's sides and the right ear
        for x in range(W):
            h, s, v = hsv(p[x, y])
            if p[x, y][3] and (y > 70 or x > 92) and 50 < h < 170 and s > 0.2:
                p[x, y] = (0, 0, 0, 0)
            elif p[x, y][3] and y > 70 and (x < 44 or x > 86) and 38 < h < 170 and v < 0.6:   # their dark olive

                p[x, y] = (0, 0, 0, 0)
    outline(p)
    return res


def outline(p):                         # an outline where something was cut away
    edge = []
    for y in range(H):
        for x in range(W):
            if p[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and p[nx, ny][3] and hsv(p[nx, ny])[2] > 0.3:
                    edge.append((x, y))
                    break
    for x, y in edge:
        p[x, y] = INK


full = clean(src)
fp = full.load()
head = clean(bare)
hp = head.load()


def colour_mask(p, test):
    """The pixels passing `test`, what they enclose (holes filled) and their dark outline."""
    m = {(x, y) for y in range(H) for x in range(W) if p[x, y][3] and test(x, y, *hsv(p[x, y]))}
    outside = set()
    todo = deque([(0, 0)])
    while todo:
        q = todo.popleft()
        if q in outside or q in m or not (0 <= q[0] < W and 0 <= q[1] < H):
            continue
        outside.add(q)
        todo.extend(((q[0] + 1, q[1]), (q[0] - 1, q[1]), (q[0], q[1] + 1), (q[0], q[1] - 1)))
    m |= {(x, y) for y in range(H) for x in range(W) if (x, y) not in outside and p[x, y][3]}
    for _ in range(2):
        m |= {(x + dx, y + dy) for (x, y) in list(m) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
              if 0 <= x + dx < W and 0 <= y + dy < H and p[x + dx, y + dy][3] and hsv(p[x + dx, y + dy])[2] < 0.3}
    return m


def hull(points):                       # convex hull (monotone chain)
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


# ---- the crown: leaves, band and heart (green and teal, above the eyes) ----
crown = colour_mask(fp, lambda x, y, h, s, v: 70 <= h <= 200 and s > 0.25 and y < 68)

# ---- the jaw: all the violet's outline encloses (a clean curve on top: the nose's tip goes with it) ----
violet = colour_mask(hp, lambda x, y, h, s, v: 250 <= h <= 330 and s > 0.2 and y > 66)
jm = Image.new('L', (W, H), 0)
ImageDraw.Draw(jm).polygon(hull(violet), fill=255)
jp = jm.load()
jaw = {(x, y) for y in range(H) for x in range(W) if hp[x, y][3] and jp[x, y]}

# the jaw in violet only. Its gold (the teeth, the nose's tip) becomes the palest violets, by brightness among
# the golds, so the fangs still stand out; its reds and darks (the mouth, the outline) the darkest ones
lum = lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
is_violet = lambda c: 250 <= hsv(c)[0] <= 330 and hsv(c)[1] > 0.12
ramp = sorted({hp[q][:3] for q in jaw if is_violet(hp[q])}, key=lum)
DARKS = [(30, 8, 30), (46, 16, 50)] + [c for c in ramp if lum(c) < 70]
PALES = [c for c in ramp if lum(c) >= 150] + [(236, 214, 252), (250, 238, 255)]
DARKS.sort(key=lum)
PALES.sort(key=lum)
others = {hp[q][:3] for q in jaw} - set(ramp)
golds = sorted([c for c in others if 20 <= hsv(c)[0] <= 65 and hsv(c)[2] > 0.45], key=lum)
rest = sorted(others - set(golds), key=lum)
swap = {}
for group, to in ((golds, PALES), (rest, DARKS + [c for c in ramp if 70 <= lum(c) < 150])):
    if not group:
        continue
    lo, hi = lum(group[0]), lum(group[-1]) + 0.001
    for c in group:
        swap[c] = to[min(len(to) - 1, int((lum(c) - lo) / (hi - lo) * len(to)))]

# ---- the pieces ----
pieces = {n: Image.new('RGBA', (W, H)) for n in ['couronne', 'tete-gauche', 'tete-droite', 'machoire']}
for (x, y) in crown:
    pieces['couronne'].putpixel((x, y), fp[x, y])
for y in range(H):
    for x in range(W):
        if not hp[x, y][3]:
            continue
        if (x, y) in jaw:
            c = hp[x, y][:3]
            pieces['machoire'].putpixel((x, y), swap.get(c, c) + (255,))
        else:
            pieces['tete-gauche' if x < 64 else 'tete-droite'].putpixel((x, y), hp[x, y])


def shade(c, k):                        # lighter (k > 1) or darker (k < 1), the hue kept
    return tuple(max(0, min(255, round(v * k))) for v in c[:3]) + (255,)


def tidy(p):
    """A piece without its loose threads (pixels holding on by one side) nor its crumbs (under 30 pixels)."""
    for _ in range(6):
        thin = [(x, y) for y in range(H) for x in range(W) if p[x, y][3] and
                sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= x + dx < W and 0 <= y + dy < H and p[x + dx, y + dy][3]) <= 1]
        for q in thin:
            p[q] = (0, 0, 0, 0)
    seen = set()
    for y in range(H):
        for x in range(W):
            if not p[x, y][3] or (x, y) in seen:
                continue
            comp, todo = [], deque([(x, y)])
            seen.add((x, y))
            while todo:
                q = todo.popleft()
                comp.append(q)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    r = (q[0] + dx, q[1] + dy)
                    if 0 <= r[0] < W and 0 <= r[1] < H and r not in seen and p[r][3]:
                        seen.add(r)
                        todo.append(r)
            if len(comp) < 30:
                for q in comp:
                    p[q] = (0, 0, 0, 0)


def slab(im):
    """The piece as a slab: its outline closed, its edges lit from the top left, its side under it."""
    p = im.load()
    tidy(p)
    for y in range(H):                  # its own outline, where the cut opened it
        for x in range(W):
            if p[x, y][3] or not any(0 <= x + dx < W and 0 <= y + dy < H and p[x + dx, y + dy][3] and hsv(p[x + dx, y + dy])[2] > 0.3
                                     for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                continue
            p[x, y] = INK
    face = im.copy()
    f = face.load()
    solid = lambda x, y: 0 <= x < W and 0 <= y < H and p[x, y][3] and p[x, y][:3] != INK[:3]
    for y in range(H):                  # the bevel: lit along the top and left, darker along the bottom and right
        for x in range(W):
            if not solid(x, y):
                continue
            top = not solid(x, y - 1) or not solid(x - 1, y)
            low = not solid(x, y + 1) or not solid(x + 1, y)
            if top and not low:
                f[x, y] = shade(p[x, y], 1.28)
            elif low and not top:
                f[x, y] = shade(p[x, y], 0.72)
    side_c = {}
    res = Image.new('RGBA', (W, H))
    r = res.load()
    for k in range(DEPTH, 0, -1):       # the side: the piece's colours, dark, a pixel lower each time
        for y in range(H - k):
            for x in range(W):
                if f[x, y][3] and f[x, y][:3] != INK[:3]:
                    r[x, y + k] = shade(f[x, y], 0.42 if k < DEPTH else 0.3)
    for y in range(H):                  # the side's outline
        for x in range(W):
            if r[x, y][3] and not f[x, y][3]:
                if y + 1 >= H or not (r[x, y + 1][3] or f[x, y + 1][3]) or x + 1 >= W or x == 0 or not r[x - 1, y][3] or not r[x + 1, y][3]:
                    r[x, y] = INK
    res.alpha_composite(face)
    return res


slabs = {n: slab(im) for n, im in pieces.items()}
for n, im in slabs.items():
    im.save(out / f'relique-{n}.png')
complete = Image.new('RGBA', (W, H))
for n in ['machoire', 'tete-gauche', 'tete-droite', 'couronne']:       # lowest first: the crown on top
    complete.alpha_composite(slabs[n])
complete.save(out / 'relique-complete.png')
old = out / 'relique-coeur.png'                                           # 0.50's fifth piece, now in the crown
if old.exists():
    old.unlink()
print({n: sum(1 for v in im.getdata() if v[3]) for n, im in pieces.items()})
