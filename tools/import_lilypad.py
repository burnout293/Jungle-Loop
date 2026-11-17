# The giant living lily pad that flies (it replaced the platforms on 17/11): three frames from one
# generated picture and two edits of it (wings up, eyes shut), put on the game's pixels by colour vote
# with one palette (pixeldown.py), then laid on the first frame by the pad's middle, which the edits
# kept (the wings and the eyes are what changes).
# Writes assets/img/lilypad.png (frames side by side: wings down, wings up, blink) and meta.json
# "lilypad": the frame size and `top`, the row of the sprite the hero stands on.
#                                                                         python tools/import_lilypad.py
import os, sys, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelgrid import background_of
from pixeldown import vote_shrink, palette_of

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, OUT = os.path.join(ROOT, 'tools', 'raw', 'gen'), os.path.join(ROOT, 'assets', 'img')
WIDTH = 124                   # the whole sprite in the game (the pad itself about 113: PLAT_W, 254 units)
NAMES = ['lilypad', 'lilypad-up', 'lilypad-blink']

raws = [Image.open(os.path.join(SRC, n + '.png')).convert('RGBA') for n in NAMES]
bgs = [background_of(np.asarray(r))[1] for r in raws]
xs = np.nonzero((~bgs[0]).any(axis=0))[0]
k = WIDTH / (xs.max() - xs.min() + 1)
pal = palette_of(np.concatenate([np.asarray(r)[..., :3][~b][::3] for r, b in zip(raws, bgs)]))
frames = [vote_shrink(r, k, pal, b) for r, b in zip(raws, bgs)]

def place(part, ref, search=6):
    """Shift laying `part` on `ref` by the middle of the pad (its outline overlapping most)."""
    P = np.asarray(part)[..., 3] > 0; R = np.asarray(ref)[..., 3] > 0
    H, W = R.shape; c0, c1 = int(W * 0.25), int(W * 0.75); best = (2, 0, 0)
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            p = P[max(0, -dy):H - max(0, dy), max(0, -dx):W - max(0, dx)][:, c0:c1]
            r = R[max(0, dy):H - max(0, -dy), max(0, dx):W - max(0, -dx)][:, c0:c1]
            u = (p | r).sum(); cost = 1 - (p & r).sum() / u if u else 2
            if cost < best[0]: best = (cost, dx, dy)
    return best[1], best[2]
placed = [frames[0]]
for f in frames[1:]:
    dx, dy = place(f, frames[0]); g = Image.new('RGBA', f.size); g.paste(f, (dx, dy)); placed.append(g); print('shift', dx, dy)
def sparkle(im):
    """At this size its eyes are two dark dots: each gets a white glint, top left, so it looks alive."""
    a = np.asarray(im).copy(); H, W = a.shape[:2]
    dark = (a[..., :3].astype(int).sum(axis=2) < 140) & (a[..., 3] > 0)
    zone = np.zeros_like(dark); zone[int(H * 0.45):int(H * 0.9), int(W * 0.3):int(W * 0.7)] = True
    seen = np.zeros_like(dark)
    for y, x in zip(*np.nonzero(dark & zone)):
        if seen[y, x]: continue
        stack, pts = [(y, x)], []
        while stack:
            cy, cx = stack.pop()
            if 0 <= cy < H and 0 <= cx < W and dark[cy, cx] and zone[cy, cx] and not seen[cy, cx]:
                seen[cy, cx] = True; pts.append((cy, cx)); stack += [(cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)]
        if 9 <= len(pts) <= 60:                                     # an eye, not the outline
            ys, xs = zip(*pts); gy, gx = min(ys) + 1, min(xs) + 1
            a[gy, gx, :3] = 255
    return Image.fromarray(a, 'RGBA')
placed = [sparkle(placed[0]), sparkle(placed[1]), placed[2]]
boxes = [f.getbbox() for f in placed]
box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
w, h = box[2] - box[0], box[3] - box[1]
sheet = Image.new('RGBA', (w * 3, h))
for i, f in enumerate(placed): sheet.alpha_composite(f.crop(box), (i * w, 0))
sheet.save(os.path.join(OUT, 'lilypad.png'))
# where he stands: a third of the way down the pad's flat top (the first row spanning most of the pad, and the
# row of its rim's widest point)
a = np.asarray(placed[0].crop(box))[..., 3] > 0
span = a.sum(axis=1); rows = np.nonzero(span > 0.6 * w)[0]
top = int(rows[0] + (rows[len(rows) // 2] - rows[0]) * 0.45) if len(rows) else 6
mp = os.path.join(OUT, 'meta.json'); meta = json.load(open(mp)); meta['lilypad'] = {'frames': 3, 'w': w, 'h': h, 'top': top}
json.dump(meta, open(mp, 'w'), indent=1); print('lilypad', meta['lilypad'])
prev = Image.new('RGBA', (w * 3 + 20, h + 10), (52, 70, 72, 255)); prev.alpha_composite(sheet, (10, 5))
prev.resize((prev.width * 4, prev.height * 4), Image.NEAREST).save(os.path.join(ROOT, 'tools', 'raw', 'lilypad-preview.png'))
