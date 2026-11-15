# Finishing pass on the game art: python tools/polish.py   (from the Jungle-Loop folder)
# Reads the untouched images in tools/raw and writes the finished ones to assets/img,
# so it can be run again at any time without stacking its effects.
#
# What a pixel artist would ask for, applied the same way to every asset:
#  - one outline colour around everything the player interacts with (readability);
#  - no stray pixels or coloured fringes left by the background removal;
#  - scenery pushed back with a little haze, so it never competes with the action.
import json, os, random, shutil
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW, OUT = os.path.join(ROOT, 'tools', 'raw'), os.path.join(ROOT, 'assets', 'img')
OUTLINE = (26, 16, 36, 255)
HAZE = (150, 205, 245)

def raw(name): return Image.open(os.path.join(RAW, name + '.png')).convert('RGBA')
def save(im, name): im.save(os.path.join(OUT, name + '.png')); print(name, im.size)

def hard_alpha(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im

def despeckle(im, min_area):
    """Removes the small islands of pixels that float away from the drawing."""
    px = im.load(); w, h = im.size; seen = set()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and (x, y) not in seen:
                q = deque([(x, y)]); seen.add((x, y)); blob = []
                while q:
                    cx, cy = q.popleft(); blob.append((cx, cy))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] and (nx, ny) not in seen:
                                seen.add((nx, ny)); q.append((nx, ny))
                if len(blob) < min_area:
                    for p in blob: px[p] = (0, 0, 0, 0)
    return im

def outline(im):
    """Dark 1-pixel outline wherever the edge of the drawing is not dark already."""
    src = im.copy().load(); px = im.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]: continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                    r, g, b, _ = src[nx, ny]
                    if 0.3 * r + 0.59 * g + 0.11 * b > 70: px[x, y] = OUTLINE; break
    return im

def pad(im, n=1):
    out = Image.new('RGBA', (im.width + 2 * n, im.height + 2 * n), (0, 0, 0, 0))
    out.alpha_composite(im, (n, n)); return out

def trim(im): return im.crop(im.getbbox())

def sprite(name, speck=5, crop=0):
    im = hard_alpha(raw(name))
    if crop: im = im.crop((crop, crop, im.width - crop, im.height - crop))
    save(trim(outline(pad(despeckle(im, speck)))), name)

def sheet(name, frames, speck=5, keep_size=False):
    im = hard_alpha(raw(name)); fw = im.width // frames; cells = []
    for i in range(frames):
        f = despeckle(im.crop((i * fw, 0, (i + 1) * fw, im.height)), speck)
        cells.append(outline(f if keep_size else pad(f)))
    out = Image.new('RGBA', (cells[0].width * frames, cells[0].height), (0, 0, 0, 0))
    for i, c in enumerate(cells): out.alpha_composite(c, (i * cells[0].width, 0))
    save(out, name)

def haze(im, amount):
    r, g, b, a = im.split()
    mixed = Image.blend(Image.merge('RGB', (r, g, b)), Image.new('RGB', im.size, HAZE), amount)
    return Image.merge('RGBA', (*mixed.split(), a))

if not os.path.isdir(RAW): shutil.copytree(OUT, RAW)          # first run: keep the originals safe
meta = json.load(open(os.path.join(RAW, 'meta.json')))

# --- what the player touches: clean edges, one outline ---
sheet('hero', 9, keep_size=True)
sheet('fly', meta['fly']['frames'], speck=6)
sheet('coin', meta['coin']['frames'])
sprite('crate', crop=1)                                         # its edge rows kept a blue and green fringe
for n in ('spiky', 'gem', 'heart', 'coin-icon', 'platform'): sprite(n)

# --- floor: variant 0 comes from a photo-like crop and kept crumbs above the moss ---
for i in range(meta['grounds']):
    g = hard_alpha(raw('ground-%d' % i))
    save(despeckle(g, 60) if i == 0 else g, 'ground-%d' % i)

# --- middle distance: its canopy stopped on a ruler-straight line; give it a leafy silhouette ---
mid = raw('mid'); px = mid.load(); rnd = random.Random(7); bumps = []
x = -4
while x < mid.width + 8:
    bumps.append((x, rnd.randint(20, 52), rnd.randint(11, 22))); x += rnd.randint(9, 20)
# treetops of very different heights: seen from afar the canopy must not draw a level line
for y in range(56):
    for x in range(mid.width):
        if not any((x - cx) ** 2 + (y - cy) ** 2 <= r * r for cx, cy, r in bumps): px[x, y] = (0, 0, 0, 0)
save(haze(mid, 0.2), 'mid')

# --- scenery props: a touch of haze sets them behind the action ---
for i in range(meta['props']): save(haze(hard_alpha(raw('prop-%d' % i)), 0.14), 'prop-%d' % i)

# --- icons: a 3x3 sheet, one per skill plus the level star and the objective target ---
icons = os.path.join(RAW, 'icons.png')
if os.path.exists(icons):
    im = hard_alpha(Image.open(icons).convert('RGBA')); c = im.width // 3
    names = ['jump', 'magnet', 'break', 'dash', 'slow', 'flight', 'rewind', 'star', 'target']
    for k, n in enumerate(names):
        cell = despeckle(im.crop((k % 3 * c, k // 3 * c, k % 3 * c + c, k // 3 * c + c)), 4)
        save(trim(cell), 'ico-' + n)
