# Cuts the later generated sheets of tools/raw/gen into game sprites. python tools/import_objets.py
#   objets3.png : amphora, drum, heart, the hero as a ball, a jungle tree, a trunk used as a pillar
#   araignee.png: the spider, legs out and legs curled in
#   libellule.png: the dragonfly mount, four frames (it replaced the Moskito)
#   brouilleur.png: the shop icon of the Brouilleur
#   boss.png    : the giant carnivorous plant, jaws shut and jaws open
#   pepito.png  : Pépito's body with his backpack and the relic, the same under his leaf rotor, the backpack icon
#   gravats.png : four ways of blocking the temple's doorway, for mockups/gravats.html
# Run it AFTER import_gen.py, which still writes the old ruins and city crates.
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, OUT = os.path.join(ROOT, 'tools', 'raw', 'gen'), os.path.join(ROOT, 'assets', 'img')

def magenta(p): return p[0] > 150 and p[2] > 150 and p[1] < 140 and abs(p[0] - p[2]) < 80

def pieces(name, min_area=4000):
    """The separate drawings of a sheet, left to right, each alone on magenta."""
    im = Image.open(os.path.join(SRC, name + '.png')).convert('RGBA'); px = im.load(); w, h = im.size
    seen = bytearray(w * h); out = []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if seen[y * w + x] or magenta(px[x, y]): continue
            q = deque([(x, y)]); seen[y * w + x] = 1; pts = []
            while q:
                cx, cy = q.popleft(); pts.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and not magenta(px[nx, ny]):
                        seen[ny * w + nx] = 1; q.append((nx, ny))
            if len(pts) < min_area: continue
            x0, y0 = min(p[0] for p in pts), min(p[1] for p in pts)
            one = Image.new('RGBA', (max(p[0] for p in pts) + 1 - x0, max(p[1] for p in pts) + 1 - y0), (255, 0, 255, 255)); o = one.load()
            for cx, cy in pts: o[cx - x0, cy - y0] = px[cx, cy]
            out.append((x0, one))
    return [im for _, im in sorted(out, key=lambda t: t[0])]

def shrink(im, k):
    s = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BOX); px = s.load()
    for y in range(s.height):
        for x in range(s.width):
            p = px[x, y]
            if magenta(p) or p[3] < 128: px[x, y] = (0, 0, 0, 0)
            elif p[0] > 90 and p[2] > 90 and p[1] < 0.6 * min(p[0], p[2]) and p[1] < 100: px[x, y] = (26, 16, 36, 255)   # pink fringe -> outline
            else: px[x, y] = (p[0], p[1], p[2], 255)
    return s.crop(s.getbbox())

def tall(im, h): return shrink(im, h / im.height)

def lit(im):
    """Pink that belongs to the drawing (a neon stripe) is not background: only the pink reached from
    the edges is. What is enclosed is repainted in a pink the cut-out no longer mistakes for it."""
    px = im.load(); w, h = im.size; seen = bytearray(w * h)
    q = deque((x, y) for x in range(w) for y in range(h) if (x in (0, w - 1) or y in (0, h - 1)) and magenta(px[x, y]))
    for x, y in q: seen[y * w + x] = 1
    while q:
        cx, cy = q.popleft()
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and magenta(px[nx, ny]): seen[ny * w + nx] = 1; q.append((nx, ny))
    for y in range(h):
        for x in range(w):
            if magenta(px[x, y]) and not seen[y * w + x]: px[x, y] = (255, 150, 235, 255)
    return im
def save(im, name, folder=OUT):
    os.makedirs(folder, exist_ok=True); im.save(os.path.join(folder, name + '.png')); print(name, im.size)

def boxed(im, w, h):
    """The drawing as large as fits in w x h, centred at the bottom of a canvas of exactly that size."""
    s = shrink(im, min(w / im.width, h / im.height))
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0)); out.alpha_composite(s, ((w - s.width) // 2, h - s.height))
    return out

amphora, drum, heart, ball, tree, trunk = pieces('objets3')
save(boxed(amphora, 30, 24), 'ruins-crate')            # what stands in for crates in each scenery
drum = lit(drum)                                       # a drum is narrow: widened a little to fill a crate's place
save(boxed(drum.resize((round(drum.width * 1.25), drum.height), Image.BOX), 28, 24), 'city-crate')
save(tall(heart, 20), 'heart')
save(tall(ball, 22), 'hero-ball')                      # 22: it has to fit in a gallery
save(tall(tree, 112), 'prop-0')                        # replaces the stone column that stood in the jungle
save(tall(trunk, 81), 'pillar')                        # what holds a slab up in the jungle

for i, im in enumerate(pieces('gravats')):
    save(tall(im, 90), 'gravats-%d' % (i + 1), os.path.join(ROOT, 'mockups', 'img'))
    if i == 3: save(tall(im, 90), 'temple-rubble')     # the one chosen: boulders held in roots

# the spider: two frames in cells of the same size, centred, hanging from the top
frames = [tall(im, 32) for im in pieces('araignee')]
cw = max(f.width for f in frames); sheet = Image.new('RGBA', (cw * 2, 32), (0, 0, 0, 0))
for i, f in enumerate(frames): sheet.alpha_composite(f, (i * cw + (cw - f.width) // 2, 0))
save(sheet, 'spider')

# the bat: asleep, wings up, wings down, in cells of the same size, all at the same scale
b = pieces('chauve-souris'); k = 30 / b[0].height
frames = [shrink(im, k) for im in b]
cw, ch = max(f.width for f in frames), max(f.height for f in frames); sheet = Image.new('RGBA', (cw * 3, ch), (0, 0, 0, 0))
for i, f in enumerate(frames): sheet.alpha_composite(f, (i * cw + (cw - f.width) // 2, 0 if i == 0 else (ch - f.height) // 2))
save(sheet, 'bat')

# the spider in two colours: yellow drops to the floor, red stops halfway. Its orange stripes are
# turned, the rest (violet body, yellow eyes) stays.
import colorsys, json
def recolour(im, hue, light=1.0):
    out = im.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a: continue
            h, l, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if 0.03 < h < 0.12 and sat > 0.45:              # the orange of the stripes
                r2, g2, b2 = colorsys.hls_to_rgb(hue, min(0.78, l * light), sat)
                px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return out
spider = Image.open(os.path.join(OUT, 'spider.png')).convert('RGBA')
save(recolour(spider, 0.15, 1.35), 'spider-low')     # a bright yellow: it is the one seen at floor level
save(recolour(spider, 0.99), 'spider-mid')

# the dragonfly: four frames lined up on its leaf saddle, like the other mounts (see import_rig.py)
saddle = lambda p: p[1] > p[0] + 30 and p[1] > p[2] + 80
def centre(im, test):
    px = im.load(); pts = [(x, y) for y in range(im.height) for x in range(im.width) if not magenta(px[x, y]) and test(px[x, y])]
    return sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts)
frames = pieces('libellule')
assert len(frames) == 4, len(frames)
anchors = [centre(f, saddle) for f in frames]
k = 92 / max(f.width for f in frames)
left = max(a[0] for a in anchors); up = max(a[1] for a in anchors)
cw = round(max(left - a[0] + f.width for f, a in zip(frames, anchors)) * k) + 2
ch = round(max(up - a[1] + f.height for f, a in zip(frames, anchors)) * k) + 1
sheet = Image.new('RGBA', (cw * 4, ch), (0, 0, 0, 0))
for i, (f, a) in enumerate(zip(frames, anchors)):
    sm = f.resize((max(1, round(f.width * k)), max(1, round(f.height * k))), Image.BOX); spx = sm.load()
    for y in range(sm.height):
        for x in range(sm.width):
            q = spx[x, y]
            spx[x, y] = (0, 0, 0, 0) if magenta(q) or q[3] < 128 else ((26, 16, 36, 255) if q[0] > 90 and q[2] > 90 and q[1] < 0.6 * min(q[0], q[2]) and q[1] < 100 else (q[0], q[1], q[2], 255))
    sheet.alpha_composite(sm, (i * cw + round((left - a[0]) * k), round((up - a[1]) * k)))
save(sheet, 'mount-dragonfly')
mp = os.path.join(OUT, 'meta.json'); meta = json.load(open(mp))
meta['mounts'].pop('moskito', None)
meta['mounts']['dragonfly'] = {'frames': 4, 'seatX': round(left * k), 'seatY': round(up * k)}
json.dump(meta, open(mp, 'w'), indent=1); print('dragonfly seat', meta['mounts']['dragonfly'])

# (the Brouilleur's icon, brouilleur.png, gave way to the Gros sac à dos: see Pépito below)

# the boss: both drawings cut with the same box (they were drawn at the same place), drips included,
# side by side in one sheet of two frames
im = Image.open(os.path.join(SRC, 'boss.png')).convert('RGBA'); half = im.width // 2
boxes = []
for k in range(2):
    h = im.crop((k * half, 0, (k + 1) * half, im.height)); px = h.load()
    mask = Image.new('L', h.size, 0); mp = mask.load()
    for y in range(h.height):
        for x in range(h.width):
            if not magenta(px[x, y]): mp[x, y] = 255
    boxes.append(mask.getbbox())
box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
k = 290 / (box[3] - box[1])
frames = []
for i in range(2):
    f = im.crop((i * half + box[0], box[1], i * half + box[2], box[3]))
    sm = f.resize((round(f.width * k), round(f.height * k)), Image.BOX); spx = sm.load()
    for y in range(sm.height):
        for x in range(sm.width):
            q = spx[x, y]
            spx[x, y] = (0, 0, 0, 0) if magenta(q) or q[3] < 128 else ((26, 16, 36, 255) if q[0] > 90 and q[2] > 90 and q[1] < 0.6 * min(q[0], q[2]) and q[1] < 100 else (q[0], q[1], q[2], 255))
    frames.append(sm)
sheet = Image.new('RGBA', (frames[0].width * 2, frames[0].height), (0, 0, 0, 0))
for i, f in enumerate(frames): sheet.alpha_composite(f, (i * frames[0].width, 0))
save(sheet, 'boss-plant')

# Pépito: his body (head, leaf hair, trunk, the backpack with the relic sticking out) and the same under
# his leaf rotor, at the size of the body they replace, with the points render.js needs: the middle of
# his head (hx, hy), the middle of the bottom of his trunk (tx), the relic (gx, gy), and for the rotor
# how many rows its blades take (blade).
from PIL import ImageFilter
body, rotor, bag = pieces('pepito')
K = 42 / body.height
def mask_centre(im, test, blur=0):
    px = im.load(); m = Image.new('L', im.size, 0); d = m.load()
    for y in range(im.height):
        for x in range(im.width):
            q = px[x, y]
            if not magenta(q) and test(q): d[x, y] = 255
    if blur: m = m.filter(ImageFilter.GaussianBlur(blur)); d = m.load()
    top = m.getextrema()[1]
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if d[x, y] > top * 0.7]
    return sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts)
dark = lambda q: max(q[:3]) < 50
cyan = lambda q: q[2] > 200 and q[1] > 160 and q[0] < 190
rig = json.load(open(os.path.join(OUT, 'meta.json')))['rig']
for name, im in (('body', body), ('rotor', rotor)):
    hx, hy = mask_centre(im, dark, 14)
    px = im.load(); low = [x for y in range(im.height - 8, im.height) for x in range(im.width) if not magenta(px[x, y])]
    gx, gy = mask_centre(im.crop((0, 0, round(hx), im.height)), cyan)          # the relic: the cyan behind his head
    sm = shrink(im, K); save(sm, 'hero-' + name)
    rig[name] = {'w': sm.width, 'h': sm.height, 'hx': round(hx * K, 1), 'hy': round(hy * K, 1), 'tx': round(sum(low) / len(low) * K, 1), 'gx': round(gx * K, 1), 'gy': round(gy * K, 1)}
px = rotor.load(); wide = [sum(1 for x in range(rotor.width) if not magenta(px[x, y])) for y in range(rotor.height)]
rig['rotor']['blade'] = round(next(y for y in range(int(rotor.height * 0.15), rotor.height) if wide[y] < 0.45 * max(wide)) * K)
save(shrink(bag, 54 / max(bag.size)), 'ico-jammer')                 # the Gros sac à dos
mp = os.path.join(OUT, 'meta.json'); meta = json.load(open(mp)); meta['rig'] = rig
json.dump(meta, open(mp, 'w'), indent=1); print('rig', rig)
