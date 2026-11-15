# Turns the large generated sheets of tools/raw/gen (drawn on flat magenta) into game sprites:
# cut each drawing out, shrink it to the game's pixel size, harden its edges. python tools/import_gen.py
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, OUT = os.path.join(ROOT, 'tools', 'raw', 'gen'), os.path.join(ROOT, 'assets', 'img')

def magenta(p): return p[0] > 150 and p[2] > 150 and p[1] < 140 and abs(p[0] - p[2]) < 80
def green(p): return p[1] > 170 and p[0] < 130 and p[2] < 130      # for sheets whose art holds pink neon
is_bg = magenta

def pieces(name, min_area=4000, is_bg=magenta, where=False):
    """The separate drawings of a sheet, as RGBA images, sorted top to bottom then left to right."""
    im = Image.open(os.path.join(SRC, name + '.png')).convert('RGBA'); px = im.load(); w, h = im.size
    seen = bytearray(w * h); out = []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if seen[y * w + x] or is_bg(px[x, y]): continue
            q = deque([(x, y)]); seen[y * w + x] = 1; x0 = x1 = x; y0 = y1 = y; n = 0
            while q:
                cx, cy = q.popleft(); n += 1
                x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and not is_bg(px[nx, ny]):
                        seen[ny * w + nx] = 1; q.append((nx, ny))
            if n >= min_area: out.append((x0, y0, x1 + 1, y1 + 1))
    out.sort(key=lambda b: (b[1] // 200, b[0]))
    return [(im.crop(b), b) for b in out] if where else [im.crop(b) for b in out]

def shrink(im, height, is_bg=magenta, k=None):
    k = k or height / im.height; height = max(1, round(im.height * k))
    s = im.resize((max(1, round(im.width * k)), height), Image.BOX); px = s.load()
    for y in range(s.height):
        for x in range(s.width):
            p = px[x, y]
            if is_bg(p) or p[3] < 128: px[x, y] = (0, 0, 0, 0)
            elif is_bg is magenta and p[0] > 90 and p[2] > 90 and p[1] < 0.6 * min(p[0], p[2]): px[x, y] = (26, 16, 36, 255)   # pink fringe -> outline
            else: px[x, y] = (p[0], p[1], p[2], 255)
    return s

def save(im, name): im.save(os.path.join(OUT, name + '.png')); print(name, im.size)

# buttons: temple nameplates in the style of the title plaque (green, slate, gold inner panel)
# (plaques-a is the sheet kept; plaques-b is the other proposal). Each is shrunk once per button height
# used by the interface, so the browser never has to rescale it.
for n, im in zip(['green', 'slate', 'gold'], pieces('plaques-a')):
    for h in (50, 38, 30): save(shrink(im, h), 'ui-btn-%s-%d' % (n, h))

m = [shrink(im, 62) for im in pieces('monkey')]            # two poses -> one sheet, aligned on the vine's top
w = max(f.width for f in m); sheet = Image.new('RGBA', (w * 2, 62), (0, 0, 0, 0))
for i, f in enumerate(m[:2]): sheet.alpha_composite(f, (i * w + (w - f.width) // 2, 0))
save(sheet, 'monkey')

s = pieces('struct')
save(shrink(s[0], 34), 'slab')
save(shrink(s[1], 72), 'log')

# (the hero, the mounts, the mosquito and the newer icons are cut out by tools/import_rig.py)

# ---------- sceneries ----------
def haze(im, colour, k):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3]: px[x, y] = tuple(round(p[c] + (colour[c] - p[c]) * k) for c in range(3)) + (255,)
    return im

def whole(name, key):                                             # a full 16:9 picture at the game's size
    return shrink(Image.open(os.path.join(SRC, name + '.png')).convert('RGBA'), 320, key)

save(haze(whole('jungle-mid', magenta), (120, 170, 205), 0.22), 'mid')
for biome, key, mist, amount in (('ruins', magenta, (236, 170, 130), 0.22), ('city', green, (70, 50, 130), 0.25), ('dungeon', magenta, (36, 40, 84), 0.3)):
    bg = Image.open(os.path.join(SRC, biome + '-bg.png')).convert('RGB').resize((569, 320), Image.BOX)
    save(bg, biome + '-bg')
    save(haze(whole(biome + '-mid', key), mist, amount), biome + '-mid')
    parts = pieces(biome + '-sheet', is_bg=key)
    for i, im in enumerate(parts[:4]): save(shrink(im, 0, key, k=0.24), '%s-prop-%d' % (biome, i))
    save(shrink(parts[4], 49, key), biome + '-ground')

# ---------- what is built in each scenery: ledge, pillar, crate, bridge, hollow pipe ----------
# The five drawings of a sheet are told apart by their shape, not by where they sit.
def tall(im, height):                                             # a hollow pipe at the game's size: scaled to its
    s = shrink(im, 0, key, k=344 / im.width)                      # length, then its middle row repeated until a hero fits
    out = Image.new('RGBA', (s.width, height), (0, 0, 0, 0)); m = s.height // 2
    out.paste(s.crop((0, 0, s.width, m)), (0, 0))
    row = s.crop((0, m, s.width, m + 1))
    for y in range(m, height - (s.height - m)): out.paste(row, (0, y))
    out.paste(s.crop((0, m, s.width, s.height)), (0, height - (s.height - m)))
    return out

for biome, key in (('ruins', magenta), ('city', green), ('dungeon', magenta)):
    found = sorted(pieces(biome + '-struct', is_bg=key, where=True), key=lambda f: -f[0].width)[:5]
    slab, pipe = [f[0] for f in sorted(found[:2], key=lambda f: f[1][1])]      # the pipe is the lower of the two long ones
    parts = [f[0] for f in found]
    rest = sorted(parts[2:], key=lambda im: im.height / im.width)
    pillar = rest[2]; ledge, crate = sorted(rest[:2], key=lambda im: -im.width)
    save(shrink(ledge, 0, key, k=114 / ledge.width), biome + '-platform')
    save(shrink(pillar, 81, key), biome + '-pillar')
    save(shrink(crate, 0, key, k=28 / crate.width).resize((28, 24), Image.NEAREST), biome + '-crate')
    save(shrink(slab, 30, key), biome + '-slab')
    save(tall(pipe, 72), biome + '-tunnel')
