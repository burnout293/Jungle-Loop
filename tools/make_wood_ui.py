"""The wood buttons (0.50): the kit's buttons made again from the two PixelLab drawings in assets/src/ui-bois
(bouton-large 192 x 48, bouton-carre 48 x 48), under the same names as the stone ones, in
assets/img/ui-v2/wood/. The stone ones stay: they are the skin « Pierre du temple ».

    python tools/make_wood_ui.py
    python tools/make_wood_ui.py <dir of the two drawings> <folder under ui-v2>   (a skin's buttons, same kit)

The ends (kept whole, the middle stretched): 30 art pixels wide at height 30, 34 at 38, 40 at 50 and 58
(main.gd WOOD_CAP). Heights the kit needs (30, 38, 50, 58): rows are taken out of (or repeated in) the middle of the plank, so
every pixel stays whole. Squares (28, 36, 42): the same with rows and columns. The squares' icons (gear,
gem, play, close, check) are lifted from the stone squares (what differs from sq-blank) and laid on the wood.
States: hover (and chosen) brighter with gold gems, pressed darker, disabled grey; variants -gold (Jouer),
-green (Reprendre), -red (Abandonner).
"""
import colorsys
import pathlib
import sys

from PIL import Image

here = pathlib.Path(__file__).resolve().parent.parent
src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 2 else here / 'assets' / 'src' / 'ui-bois'
stone = here / 'assets' / 'img' / 'ui-v2'
out = stone / (sys.argv[2] if len(sys.argv) > 2 else 'wood')
out.mkdir(exist_ok=True)


def crop(im):
    return im.crop(im.getbbox())


def fit_rows(im, h, keep=()):
    """`im` made `h` tall: rows taken out of (or repeated among) the plain ones, evenly; the rows in `keep`
    (the gems, the moss's edge, the bottom rim) are never touched."""
    w, h0 = im.size
    free = [y for y in range(h0) if y not in keep]
    order = list(range(h0))
    if h < h0:
        drop = h0 - h
        gone = {free[round((i + 0.5) * len(free) / drop - 0.5)] for i in range(drop)}
        order = [y for y in order if y not in gone]
    elif h > h0:
        more = h - h0
        twice = [free[round((i + 0.5) * len(free) / more - 0.5)] for i in range(more)]
        order = sorted(order + twice)
    res = Image.new('RGBA', (w, h))
    for y, sy in enumerate(order):
        res.paste(im.crop((0, sy, w, sy + 1)), (0, y))
    return res


def fit_cols(im, w, keep=()):
    return fit_rows(im.transpose(Image.TRANSPOSE), w, keep).transpose(Image.TRANSPOSE)


def gem_rows(im):
    px = im.load()
    return {y for y in range(im.height) for x in range(im.width) if px[x, y][3] and is_gem(*px[x, y][:3])}


def span(a, b):
    return set(range(a, b))


def gem_cols(im):
    px = im.load()
    return {x for y in range(im.height) for x in range(im.width) if px[x, y][3] and is_gem(*px[x, y][:3])}


def drop_cols(im, cols):
    keep = [x for x in range(im.width) if x not in cols]
    res = Image.new('RGBA', (len(keep), im.height))
    for i, x in enumerate(keep):
        res.paste(im.crop((x, 0, x + 1, im.height)), (i, 0))
    return res


def narrow(im, n):
    """The two ends made `n` columns narrower each (short buttons): columns taken out of the trunk and the
    vines, never the gem, the leaves outside or the frame of the plank."""
    g = gem_cols(im)
    w = im.width
    left = [x for x in range(6, 34) if x not in g]
    right = [x for x in range(w - 30, w - 6) if x not in g]
    pick = lambda c: {c[round((i + 0.5) * len(c) / n - 0.5)] for i in range(n)}
    return drop_cols(im, pick(left) | pick(right))


def is_gem(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return 0.44 < h < 0.56 and s > 0.35 and v > 0.45


def recolour(im, fn):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                r, g, b = fn(r, g, b)
                px[x, y] = (max(0, min(255, round(r))), max(0, min(255, round(g))), max(0, min(255, round(b))), a)
    return im


def bright(k):
    return lambda r, g, b: (r * k, g * k, b * k)


def gold_gems(k=1.08):
    def f(r, g, b):
        if is_gem(r, g, b):
            v = max(r, g, b) / 255
            return (255 * min(1, v * 1.15), 211 * min(1, v * 1.1), 92 * v)
        return (r * k, g * k, b * k)
    return f


def grey(r, g, b):
    m = (r * 0.3 + g * 0.59 + b * 0.11)
    return (m * 0.62 + r * 0.1, m * 0.62 + g * 0.1, m * 0.66 + b * 0.1)


def hue_wood(to, sat, val):
    """The wood (not the moss, not the gems) turned towards hue `to` (degrees)."""
    def f(r, g, b):
        if is_gem(r, g, b):
            return (r, g, b)
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if 0.18 < h < 0.42 and s > 0.45:              # the moss stays
            return (r, g, b)
        h2 = to / 360
        rr, gg, bb = colorsys.hsv_to_rgb(h2, min(1, s * sat + 0.12), min(1, v * val))
        return (rr * 255, gg * 255, bb * 255)
    return f


big = crop(Image.open(src / 'bouton-large.png').convert('RGBA'))      # 183 x 48
sq = crop(Image.open(src / 'bouton-carre.png').convert('RGBA'))       # 41 x 40

STATES = {'normal': bright(1.0), 'hover': gold_gems(1.1), 'pressed': bright(0.82), 'disabled': grey}
VARIANTS = {'': None, '-gold': gold_gems(1.05), '-green': hue_wood(95, 0.9, 1.0), '-red': hue_wood(8, 1.15, 0.95)}
NEEDED = {30: [''], 38: ['', '-green', '-red'], 50: ['', '-green', '-red'], 58: ['-gold']}

made = 0
for h, variants in NEEDED.items():
    keep = gem_rows(big) | span(0, 4) | span(big.height - 4, big.height)   # the gems, the moss tips, the rim
    base = fit_rows(big, h, keep)
    base = narrow(base, {30: 10, 38: 6}.get(h, 0)) if h in (30, 38) else base     # ends of 30 and 34 (40 above)
    for var in variants:
        b = recolour(base, VARIANTS[var]) if VARIANTS[var] else base
        for st, fn in STATES.items():
            im = recolour(b, fn)
            im.save(out / f'btn-{st}-{h}{var}.png')
            made += 1

for size in (28, 36, 42):
    inner = size - 2
    blank = fit_cols(fit_rows(sq, inner, span(0, 9) | span(sq.height - 6, sq.height)), inner, span(0, 6) | span(sq.width - 12, sq.width))
    canvas = Image.new('RGBA', (size, size))
    canvas.paste(blank, (1, 1))
    canvas.save(out / f'sq-blank-{size}.png')
    made += 1
    for ic in ('gear', 'gem', 'play', 'close', 'check'):
        s_icon = stone / f'sq-{ic}-{size}.png'
        s_blank = stone / f'sq-blank-{size}.png'
        if not s_icon.exists() or not s_blank.exists():
            continue
        a = Image.open(s_icon).convert('RGBA')
        z = Image.open(s_blank).convert('RGBA')
        im = canvas.copy()
        pa, pz, pi = a.load(), z.load(), im.load()
        m = round(size * 0.22)                       # only the middle: the stone frames' leaves differ too
        for y in range(m, size - m):
            for x in range(m, size - m):
                r, g, b, al = pa[x, y]
                v = max(r, g, b) / 255
                slate = 0.2 < v < 0.5 and b > r + 10      # the stone's slate face behind the icon stays behind
                if pa[x, y] != pz[x, y] and al > 0 and not slate:
                    pi[x, y] = pa[x, y]
        im.save(out / f'sq-{ic}-{size}.png')
        made += 1
print(f'{made} images dans {out.relative_to(here)}')
