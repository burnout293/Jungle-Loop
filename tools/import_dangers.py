# The dangers drawn on the generated sheets of tools/raw/gen, cut again with the clean chain (17/11):
#   araignee.png      : the spider, legs out and legs curled (then turned yellow and red)
#   chauve-souris.png : the bat, asleep, wings up, wings down
#   mosquito.png      : the mosquito, four frames lined up on its eye
#   dangers1.png      : vulture (two frames), wasp, ball of brambles
#   dangers2.png      : stone idol, bear trap (two frames)
#   dangers3.png      : missile, arrow, combat drone, little drone
#   dangers4.png      : the city's spiky robot
# The magenta background is the magenta reached from the edges of the sheet, plus any pure magenta
# left between legs or wings: the violets and pinks of the drawings themselves (bat wings, spider body)
# are never taken for it, which the old cut did and left holes. Each drawing is then put straight onto
# the game's pixels by colour vote (pixeldown.py vote_shrink): no blending, outline kept. The sizes are
# those the game already uses.                                          python tools/import_dangers.py
import os, sys, colorsys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelgrid import magenta_mask
from pixeldown import vote_shrink, palette_of

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, OUT = os.path.join(ROOT, 'tools', 'raw', 'gen'), os.path.join(ROOT, 'assets', 'img')

def save(im, name): im.save(os.path.join(OUT, name + '.png')); print(name, im.size)

def load(name):
    """The sheet, where its background is, and one palette for all its drawings."""
    im = Image.open(os.path.join(SRC, name + '.png')).convert('RGBA'); a = np.asarray(im)
    loose = magenta_mask(a)
    m = Image.fromarray((loose * 255).astype(np.uint8), 'L')
    for xy in ((0, 0), (m.width - 1, 0), (0, m.height - 1), (m.width - 1, m.height - 1)):
        if m.getpixel(xy) == 255: ImageDraw.floodfill(m, xy, 128)
    r, g, b = (a[..., k].astype(int) for k in range(3))
    bg = (np.asarray(m) == 128) | ((r > 225) & (b > 225) & (g < 45))
    return im, bg, palette_of(a[..., :3][~bg])

def columns(bg, gap=14, least=1500):
    """The boxes of the drawings, each with the bits floating next to it, left to right."""
    used = (~bg).any(axis=0); W = len(used); spans, x = [], 0
    while x < W:
        if not used[x]: x += 1; continue
        a = x
        while x < W and (used[x] or used[x:x + gap].any()): x += 1
        spans.append((a, x))
    boxes = []
    for a, b in spans:
        ys = np.nonzero((~bg[:, a:b]).any(axis=1))[0]; xs = np.nonzero((~bg[:, a:b]).any(axis=0))[0]
        box = (a + xs.min(), ys.min(), a + xs.max() + 1, ys.max() + 1)
        if (box[2] - box[0]) * (box[3] - box[1]) > least: boxes.append(box)
    return boxes

def blobs(bg, least=4000):
    """The boxes of the big separate drawings (for frames too close for columns), left to right."""
    m = Image.fromarray(((~bg) * 255).astype(np.uint8), 'L'); a = np.asarray(m).copy(); boxes = []
    H, W = a.shape
    for y in range(0, H, 3):
        for x in range(0, W, 3):
            if a[y, x] != 255: continue
            ImageDraw.floodfill(m, (x, y), 100); b = np.asarray(m) == 100
            ys, xs = np.nonzero(b)
            if len(ys) >= least: boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
            m.paste(0, mask=Image.fromarray((b * 255).astype(np.uint8), 'L')); a = np.asarray(m).copy()
    return sorted(boxes)

def small(sheet, box, k):
    """One drawing at the game's size (k game pixels per sheet pixel), trimmed."""
    im, bg, pal = sheet
    part = im.crop(box); m = bg[box[1]:box[3], box[0]:box[2]]
    s = vote_shrink(part, k, pal, m)
    bb = s.getbbox(); return s.crop(bb) if bb else s

def size(box): return box[2] - box[0], box[3] - box[1]

def strip(frames, align='bottom'):
    cw, ch = max(f.width for f in frames), max(f.height for f in frames)
    out = Image.new('RGBA', (cw * len(frames), ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        y = {'bottom': ch - f.height, 'top': 0, 'middle': (ch - f.height) // 2}[align if isinstance(align, str) else align[i]]
        out.alpha_composite(f, (i * cw + (cw - f.width) // 2, y))
    return out

# the spider: two frames at one scale, hanging from the top
sp = load('araignee'); boxes = columns(sp[1]); assert len(boxes) == 2, boxes
k = 32 / max(size(b)[1] for b in boxes)
frames = [small(sp, b, k) for b in boxes]
k *= 32 / max(f.height for f in frames)                 # the box held a few loose specks: 32 pixels for the spider itself
spider = strip([small(sp, b, k) for b in boxes], 'top'); save(spider, 'spider')
def recolour(im, hue, light=1.0):
    """Its orange stripes turned to another colour; the rest (violet body, yellow eyes) stays."""
    out = im.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a: continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if 0.03 < h < 0.12 and s > 0.45:
                r2, g2, b2 = colorsys.hls_to_rgb(hue, min(0.78, l * light), s)
                px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return out
save(recolour(spider, 0.15, 1.35), 'spider-low')       # bright yellow: the one seen at floor level
save(recolour(spider, 0.99), 'spider-mid')

# the bat: asleep (hanging from the top), wings up, wings down, all at the scale of the sleeping one
bt = load('chauve-souris'); boxes = columns(bt[1]); assert len(boxes) == 3, boxes
k = 30 / size(boxes[0])[1]
save(strip([small(bt, b, k) for b in boxes], ['top', 'middle', 'middle']), 'bat')

# the mosquito: four frames lined up on its yellow eye, so nothing jumps from one to the next
mq = load('mosquito'); boxes = blobs(mq[1]); assert len(boxes) == 4, boxes
a = np.asarray(mq[0])
def eye_of(box):
    p = a[box[1]:box[3], box[0]:box[2]].astype(int)
    m = (p[..., 0] > 200) & (p[..., 1] > 170) & (p[..., 2] < 90) & ~mq[1][box[1]:box[3], box[0]:box[2]]
    ys, xs = np.nonzero(m); return xs.mean(), ys.mean()
Q = 36 / max(size(b)[1] for b in boxes)
eyes = [eye_of(b) for b in boxes]
left = max(e[0] for e in eyes); up = max(e[1] for e in eyes)
cw = round(max(left - e[0] + size(b)[0] for b, e in zip(boxes, eyes)) * Q) + 1
ch = round(max(up - e[1] + size(b)[1] for b, e in zip(boxes, eyes)) * Q) + 1
out = Image.new('RGBA', (cw * 4, ch), (0, 0, 0, 0))
for i, (b, e) in enumerate(zip(boxes, eyes)):
    im, bg, pal = mq; f = vote_shrink(im.crop(b), Q, pal, bg[b[1]:b[3], b[0]:b[2]])   # untrimmed: the eye stays where it was measured
    out.alpha_composite(f, (i * cw + round((left - e[0]) * Q), round((up - e[1]) * Q)))
save(out, 'mosquito')

# the other sceneries
d1 = load('dangers1'); vul1, vul2, wasp, thorns = columns(d1[1])
k = 46 / max(size(vul1)[0], size(vul2)[0]); save(strip([small(d1, vul1, k), small(d1, vul2, k)]), 'vulture')
save(small(d1, wasp, 40 / size(wasp)[0]), 'wasp')
save(small(d1, thorns, 30 / size(thorns)[0]), 'thornball')
d2 = load('dangers2'); idol, trap1, trap2, mine = columns(d2[1])
save(small(d2, idol, 30 / size(idol)[1]), 'idol')
k = 38 / max(size(trap1)[0], size(trap2)[0]); save(strip([small(d2, trap1, k), small(d2, trap2, k)]), 'beartrap')
d3 = load('dangers3'); missile, arrow, drone, minidrone = columns(d3[1])
save(small(d3, missile, 46 / size(missile)[0]), 'missile')
save(small(d3, arrow, 46 / size(arrow)[0]), 'arrow')
save(small(d3, drone, 46 / size(drone)[0]), 'drone-big')
save(small(d3, minidrone, 32 / size(minidrone)[0]), 'drone')
d4 = load('dangers4'); robot = columns(d4[1])[0]
save(small(d4, robot, 34 / size(robot)[0]), 'spikebot')
