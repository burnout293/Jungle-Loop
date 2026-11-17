# The platforms of the dungeon and the city, and the lianas, generated on 17/11 (tools/raw/gen), put on
# the game's pixels by colour vote (pixeldown.py), whatever their background.
#   walkway.png    -> walkway.png : the dungeon's walkway, hanging from two chains (render.js draws the
#                     chains on up to the top of the screen from the two stubs)
#   hover-plat.png -> hover-plat.png : the city's platform levitating on three thrusters
#   vines.png      -> vine-garland.png (one stretch of the braided liana, repeated mirrored) and
#                     vine-hang.png (five hanging lianas side by side, the shortest first)
# meta.json gets, for each: the frame size, `top` (the row the hero stands on), and the chains' columns,
# the thrusters' columns, the hanging lianas' boxes.               python tools/import_platforms.py
import os, sys, json
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelgrid import background_of
from pixeldown import vote_shrink, palette_of

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, OUT = os.path.join(ROOT, 'tools', 'raw', 'gen'), os.path.join(ROOT, 'assets', 'img')
mp = os.path.join(OUT, 'meta.json'); meta = json.load(open(mp))

def load(name):
    im = Image.open(os.path.join(SRC, name + '.png')).convert('RGBA'); a = np.asarray(im)
    return im, background_of(a)[1], palette_of(a[..., :3][~background_of(a)[1]])

def to_width(name, width):
    im, bg, pal = load(name)
    xs = np.nonzero((~bg).any(axis=0))[0]
    s = vote_shrink(im, width / (xs.max() - xs.min() + 1), pal, bg)
    return s.crop(s.getbbox())

def walk_top(im, share=0.7):
    a = np.asarray(im)[..., 3] > 0; rows = np.nonzero(a.sum(axis=1) > share * im.width)[0]
    return int(rows[0]) if len(rows) else 0

def runs(cols):
    out, start = [], None
    for i, c in enumerate(list(cols) + [False]):
        if c and start is None: start = i
        if not c and start is not None: out.append((start, i)); start = None
    return out

# the dungeon's walkway: the planks span the platform (113 pixels), the brackets stick out a little
wk = to_width('walkway', 120); top = walk_top(wk)
a = np.asarray(wk)[..., 3] > 0
chains = [int((s + e) / 2) for s, e in runs(a[0:3].any(axis=0))]
wk.save(os.path.join(OUT, 'walkway.png'))
meta['walkway'] = {'w': wk.width, 'h': wk.height, 'top': top, 'chains': chains}
print('walkway', meta['walkway'])

# the city's levitating platform; its thrusters are where the cyan glows at the bottom
hv = to_width('hover-plat', 120); top = walk_top(hv)
p = np.asarray(hv).astype(int); low = p[int(hv.height * 0.6):]
cyan = (low[..., 2] > 170) & (low[..., 1] > 150) & (low[..., 0] < 140) & (low[..., 3] > 0)
jets = [int((s + e) / 2) for s, e in runs(cyan.any(axis=0)) if e - s >= 3]
hv.save(os.path.join(OUT, 'hover-plat.png'))
meta['hoverplat'] = {'w': hv.width, 'h': hv.height, 'top': top, 'jets': jets}
print('hoverplat', meta['hoverplat'])

# the lianas: the braided garland across the top of the sheet, the five hanging ones below
im, bg, pal = load('vines')
fg = ~bg; H, W = fg.shape
m = Image.fromarray((fg * 255).astype(np.uint8), 'L'); boxes = []
for y in range(0, H, 4):
    for x in range(0, W, 4):
        if m.getpixel((x, y)) != 255: continue
        ImageDraw.floodfill(m, (x, y), 100); b = np.asarray(m) == 100; ys, xs = np.nonzero(b)
        if len(ys) > 3000: boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        m.paste(0, mask=Image.fromarray((b * 255).astype(np.uint8), 'L'))
garland = max(boxes, key=lambda b: b[2] - b[0])
hangs = sorted([b for b in boxes if b is not garland and b[1] > garland[1]], key=lambda b: b[3] - b[1])
k = 22 / (garland[3] - garland[1])                      # the garland 22 pixels thick in the game
def cut(box):
    part = im.crop(box); s = vote_shrink(part, k, pal, bg[box[1]:box[3], box[0]:box[2]]); return s.crop(s.getbbox())
g = cut((garland[0] + 8, garland[1], garland[2] - 8, garland[3]))   # its ends cut clean
g.save(os.path.join(OUT, 'vine-garland.png'))
hs = [cut(b) for b in hangs]
cw = max(h.width for h in hs); ch = max(h.height for h in hs)
sheet = Image.new('RGBA', (cw * len(hs), ch))
for i, h in enumerate(hs): sheet.alpha_composite(h, (i * cw + (cw - h.width) // 2, 0))
sheet.save(os.path.join(OUT, 'vine-hang.png'))
meta['vines'] = {'garland': [g.width, g.height], 'hang': {'w': cw, 'h': ch, 'n': len(hs), 'len': [h.height for h in hs]}}
print('vines', meta['vines'])
json.dump(meta, open(mp, 'w'), indent=1)

prev = Image.new('RGBA', (max(g.width, sheet.width, 260) + 20, g.height + sheet.height + wk.height + hv.height + 50), (52, 70, 72, 255)); y = 5
for part in (g, sheet, wk, hv): prev.alpha_composite(part, (10, y)); y += part.height + 10
prev.resize((prev.width * 3, prev.height * 3), Image.NEAREST).save(os.path.join(ROOT, 'tools', 'raw', 'platforms-preview.png'))
