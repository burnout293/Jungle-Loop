"""Picture skins (0.58+): Pépito and the mounts redrawn in a theme (skeleton, cyber, hell, divine), by
PixelLab edits of the game's own pictures, so every shape, size, frame and anchor stays the same: a skin
is a folder of pictures named like the ones they replace (assets/img/skins/<skin id>/<texture>.png).

The PixelLab work lives in Archives/Jungle-Loop/propositions/skins:
  source/            what was sent: Pépito's parts each centred on a 48 x 48 cell (cells.json says where),
                     the mounts' sheets cut into their frames
  <theme>/brut/      what came back, under the same names

    python tools/make_skins.py cells                 cut the sources (Pépito's cells, the mounts' frames)
    python tools/make_skins.py pepito <theme>        Pépito's parts back to their own size and place
    python tools/make_skins.py mount <name> <theme>  a mount's frames back into its sheet
    python tools/make_skins.py buttons <theme>       the two button drawings, middle made plain, then the
                                                     whole kit by make_wood_ui.py (assets/img/ui-v2/<theme>)

What comes back is put on the original picture's grid: same size, alpha made all-or-nothing, and nothing
outside the original picture's box (a few pixels the edit may add around are left out).
"""
import json
import pathlib
import sys

from PIL import Image

here = pathlib.Path(__file__).resolve().parent.parent
IMG = here / 'assets' / 'img'
ARCH = here.parent / 'Archives' / 'Jungle-Loop' / 'propositions' / 'skins'
OUT = IMG / 'skins'
CELL = 48
PARTS = ['hero-body', 'hero-fist', 'hero-ball', 'hero-shoe', 'hero-rotor']
SHEETS = {'gorilla': ['mount-gorilla', 'mount-gorilla-hang'], 'rhino': ['mount-rhino'], 'dragonfly': ['mount-dragonfly']}
FRAMES = 4


def solid(im):
    """Alpha all or nothing, as the game's pixel art."""
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im


def cells():
    src = ARCH / 'source'
    src.mkdir(parents=True, exist_ok=True)
    info = {}
    for n in PARTS:
        im = Image.open(IMG / f'{n}.png').convert('RGBA')
        cell = Image.new('RGBA', (CELL, CELL))
        ox, oy = (CELL - im.width) // 2, (CELL - im.height) // 2
        cell.alpha_composite(im, (ox, oy))
        cell.save(src / f'{n}-cell.png')
        info[n] = [ox, oy, im.width, im.height]
    (src / 'cells.json').write_text(json.dumps(info))
    for sheets in SHEETS.values():
        for n in sheets:
            im = Image.open(IMG / f'{n}.png').convert('RGBA')
            w = im.width // FRAMES
            for i in range(FRAMES):
                im.crop((i * w, 0, (i + 1) * w, im.height)).save(src / f'{n}-{i}.png')
    print('sources in', src)


# The small parts (the fist, 8 x 8, and the shoe, 12 x 9) are too small for an edit to change: they are the
# original pictures with their light mapped onto the theme's ramp (dark to light), the outline kept.
RAMPS = {
    'squelette': ['#3a3230', '#6e6458', '#a89c86', '#d8cfb6', '#f4eedc'],
    'cyber': ['#1a2440', '#2e4a7a', '#3e8ee0', '#5cf2e0', '#e6fffb'],
    'enfer': ['#3a0a0a', '#7a1414', '#c0301e', '#ff7a1e', '#ffd35c'],
    'divin': ['#6a4a12', '#b0801e', '#e0b03e', '#ffe08a', '#fffaf0'],
}
SMALL = ['hero-fist', 'hero-shoe']


def ramped(im, ramp):
    cols = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in ramp]
    im = im.convert('RGBA')
    px = im.load()
    lum = [0.3 * r + 0.59 * g + 0.11 * b for x in range(im.width) for y in range(im.height)
           for r, g, b, a in [px[x, y]] if a and r + g + b >= 125]
    lo, hi = (min(lum), max(lum)) if lum else (0, 255)
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a or r + g + b < 125:          # transparent, or the dark outline: kept
                continue
            t = 0 if hi == lo else (0.3 * r + 0.59 * g + 0.11 * b - lo) / (hi - lo)
            px[x, y] = cols[min(len(cols) - 1, round(t * (len(cols) - 1)))] + (255,)
    return im


def divine_ball(im):
    """(PixelLab refused this one twice) The rolled-up Pépito of the divine skin by colour: the green leaves on
    a white-to-gold ramp, the dark face royal blue, the eyes gold; the outline kept."""
    import colorsys
    leaf = RAMPS['divin'][1:] + ['#ffffff']
    blue = ['#141a4a', '#1e2a78', '#2e3ea8']
    cols = lambda r: [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in r]
    leaf, blue = cols(leaf), cols(blue)
    im = im.convert('RGBA')
    px = im.load()
    src = im.copy().load()
    edge = lambda x, y: any(not (0 <= x + dx < im.width and 0 <= y + dy < im.height) or src[x + dx, y + dy][3] == 0
                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a or r + g + b < 60 or (edge(x, y) and r + g + b < 200):    # the outline stays
                continue
            h, sat, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.45 < h < 0.58 and v > 0.55:                 # the eyes
                px[x, y] = (255, 211, 92, 255)
            elif 0.15 < h < 0.5 and sat > 0.2:              # the leaves
                px[x, y] = leaf[min(len(leaf) - 1, int(v * len(leaf)))] + (255,)
            elif v < 0.45:                                  # the face
                px[x, y] = blue[min(len(blue) - 1, int(v / 0.45 * len(blue)))] + (255,)
    return im


FALLBACK = {('divin', 'hero-ball'): divine_ball}


def skin_dir(target, theme):
    d = OUT / f'{target}-{theme}'
    d.mkdir(parents=True, exist_ok=True)
    return d


def pepito(theme):
    info = json.loads((ARCH / 'source' / 'cells.json').read_text())
    brut = ARCH / theme / 'brut'
    out = skin_dir('pepito', theme)
    for n in PARTS:
        if n in SMALL:
            ramped(Image.open(IMG / f'{n}.png'), RAMPS[theme]).save(out / f'{n}.png')
            print(n, 'ramp')
            continue
        p = brut / f'{n}-cell.png'
        if not p.exists() and (theme, n) in FALLBACK:
            FALLBACK[(theme, n)](Image.open(IMG / f'{n}.png')).save(out / f'{n}.png')
            print(n, 'by colour')
            continue
        if not p.exists():
            print('missing', p.name)
            continue
        ox, oy, w, h = info[n]
        solid(Image.open(p)).crop((ox, oy, ox + w, oy + h)).save(out / f'{n}.png')
        print(n, w, 'x', h)


def mount(name, theme):
    brut = ARCH / theme / 'brut'
    out = skin_dir(name, theme)
    for n in SHEETS[name]:
        orig = Image.open(IMG / f'{n}.png').convert('RGBA')
        w = orig.width // FRAMES
        sheet = Image.new('RGBA', orig.size)
        for i in range(FRAMES):
            f = solid(Image.open(brut / f'{n}-{i}.png'))
            assert f.size == (w, orig.height), (n, i, f.size)
            sheet.alpha_composite(f, (i * w, 0))
        sheet.save(out / f'{n}.png')
        print(n, sheet.size)


def plain_middle(im, cap):
    """The middle of the long button (between its two ends, `cap` wide each) made of one plain column, the
    commonest colour of each row there: the game stretches that part, so nothing in it may have a shape
    (a skull, a rivet) that would be drawn out."""
    im = im.convert('RGBA')
    px = im.load()
    x0, x1 = cap, im.width - cap
    col = []
    for y in range(im.height):
        seen = {}
        for x in range(x0, x1):
            seen[px[x, y]] = seen.get(px[x, y], 0) + 1
        col.append(max(seen, key=seen.get))
    for x in range(x0, x1):
        for y in range(im.height):
            px[x, y] = col[y]
    return im


# A theme whose drawing came out with a light inner panel gets it darkened (the buttons' text is light):
# the panel is flooded from the middle over colours close to the middle's (it stops at the gold trim),
# made a clean rounded box, and its light mapped onto this ramp.
PANEL = {'divin': ['#0e1338', '#141c50', '#1c2868', '#263682', '#33479c']}


def panel_mask(wood):
    w = wood.convert('RGBA')
    px = w.load()
    W, H = w.size
    c = px[W // 2, H // 2]
    near = lambda p: p[3] and sum(abs(p[i] - c[i]) for i in range(3)) < 60
    seen, todo = set(), [(W // 2, H // 2)]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < W and 0 <= y < H) or not near(px[x, y]):
            continue
        seen.add((x, y))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    # the wood's grain makes that region ragged: the panel is its box, a pixel in, with rounded corners
    xs, ys = [x for x, _ in seen], [y for _, y in seen]
    x0, x1, y0, y1 = min(xs) + 1, max(xs) - 1, min(ys) + 1, max(ys) - 1
    r = 3
    def inside(x, y):
        cx = min(max(x, x0 + r), x1 - r)
        cy = min(max(y, y0 + r), y1 - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r
    return {(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1) if inside(x, y)}


def dark_panel(im, wood, ramp):
    cols = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in ramp]
    im = im.convert('RGBA')
    px = im.load()
    mask = panel_mask(wood)
    lum = [0.3 * px[x, y][0] + 0.59 * px[x, y][1] + 0.11 * px[x, y][2] for x, y in mask]
    lo, hi = min(lum), max(lum)
    for (x, y), l in zip(mask, lum):
        t = 0 if hi == lo else (l - lo) / (hi - lo)
        px[x, y] = cols[min(len(cols) - 1, round(t * (len(cols) - 1)))] + (255,)
    return im


def buttons(theme):
    import subprocess
    brut = ARCH / theme / 'brut'
    src = here / 'assets' / 'src' / f'ui-{theme}'
    src.mkdir(parents=True, exist_ok=True)
    big = solid(Image.open(brut / 'bouton-large.png'))
    sq = solid(Image.open(brut / 'bouton-carre.png'))
    if theme in PANEL:
        big = dark_panel(big, big, PANEL[theme])
        sq = dark_panel(sq, sq, PANEL[theme])
    plain_middle(big.crop(big.getbbox()), 44).save(src / 'bouton-large.png')
    sq.save(src / 'bouton-carre.png')
    subprocess.run([sys.executable, str(here / 'tools' / 'make_wood_ui.py'), str(src), theme], check=True)


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'cells':
        cells()
    elif cmd == 'pepito':
        pepito(sys.argv[2])
    elif cmd == 'mount':
        mount(sys.argv[2], sys.argv[3])
    elif cmd == 'buttons':
        buttons(sys.argv[2])
