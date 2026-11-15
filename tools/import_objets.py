# Cuts the later generated sheets of tools/raw/gen into game sprites. python tools/import_objets.py
#   objets3.png : amphora, drum, heart, the hero as a ball, a jungle tree, a trunk used as a pillar
#   araignee.png: the spider, legs out and legs curled in
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
