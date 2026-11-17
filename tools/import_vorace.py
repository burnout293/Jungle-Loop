# Vorace (version C, the queen flower), cut into three layers that can never come apart.
#
# Every picture in tools/raw/gen/vorace3/ comes from ONE model picture (master.png) and from edits of it:
# the body alone, the head alone, the legs alone, then each pose of the head, of the legs and of the
# body, edited from those. An edit keeps the framing of the picture but neither its pixel size nor its
# background (real transparency, or a painted checkerboard), so every picture is put straight onto the
# game's pixels at one common scale, by colour vote on one palette shared by all
# (tools/pixeldown.py vote_shrink: no blending, the outline kept), then laid on what it continues:
# a part on the master, a head pose by its stem, a leg pose by its stump and its feet on the floor,
# the cracked body by its outline.
#
# The game draws the layers back to front: legs, head, body. The body's leaf collar covers the stem and
# its belly covers the top of the legs, so the joints are hidden by the drawing itself: whatever the
# head or the legs do, nothing can show between the parts.
#
# Writes assets/img/vorace-legs.png, vorace-head.png, vorace-body.png (one frame per pose, side by side)
# and meta.json "vorace": the creature's size, where its feet touch the floor, each layer's box, and
# the mouth, the crown and the feet. A look at every pose: tools/raw/vorace3-poses.png.
#                                                                           python tools/import_vorace.py
import os, json, sys
from collections import deque
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelgrid import background_of
from pixeldown import vote_shrink

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, OUT = os.path.join(ROOT, 'tools', 'raw', 'gen', 'vorace3'), os.path.join(ROOT, 'assets', 'img')
HEIGHT = 250                      # the creature's height in the game, in art pixels (the screen is 320)
MOUTH = (26, 16, 36)              # what fills a hole the generator left in a mouth

# the poses, in the order the game reads them (js/render.js, voraceFrame)
LEGS = ['legs', 'legs-1', 'legs-2', 'legs-3', 'legs-4']                  # walk 0-3, collapsed
HEAD = ['head', 'head-1', 'head-2', 'head-3', 'head-4', 'head-5']        # shut, opening, open, spitting, crushed, broken
BODY = ['body', 'body-1']                                                # whole, cracked

def raw(name): return Image.open(os.path.join(SRC, name + '.png'))

def scale_of(im):
    """Game pixels per picture pixel: the master's drawing brought to HEIGHT."""
    a = np.asarray(im)[..., 3] > 128; ys = np.nonzero(a.any(axis=1))[0]
    return HEIGHT / (ys.max() - ys.min() + 1)

ALL = ['master'] + LEGS + HEAD + BODY
def shared_palette():
    """One palette for every picture, so that a pose never changes the shades of what stays: the
    master's own colours (its orange eye however few pixels it has), plus what a pose brings that the
    master lacks (boiling acid, the faded petals of the end)."""
    def pixels(name):
        a = np.asarray(raw(name).convert('RGBA')); _, bg = background_of(a); return a[..., :3][~bg]
    def colours(px, n):
        q = Image.fromarray(px[None].astype(np.uint8), 'RGB').quantize(n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        return np.array(q.getpalette()[:n * 3]).reshape(-1, 3)
    def add_missing(pal, px, far):
        # every colour still far from the palette joins it (a median cut merges small areas, like the
        # eye, into their neighbours): the farthest first, until none is left that far
        P = np.array(pal, float); px = px.astype(float)
        while len(P) < 256:
            d = np.abs(px[:, None, :] - P[None]).sum(axis=2).min(axis=1)
            i = int(d.argmax())
            if d[i] <= far: break
            P = np.vstack([P, px[i]])
        return [p for p in P.astype(int)]
    mp = pixels('master'); pal = list(colours(mp[::3], 96))
    pal = add_missing(pal, mp[::23], 40)
    for name in ALL[1:]:
        if not os.path.exists(os.path.join(SRC, name + '.png')): continue
        pal = add_missing(pal, pixels(name)[::41], 44)
    img = Image.new('P', (1, 1)); flat = [int(v) for c in pal for v in c]
    img.putpalette(flat + flat[-3:] * (256 - len(pal)))
    print('palette', len(pal), 'colours')
    return img

def to_game(name, s):
    """The picture on the game's pixels (same canvas for all: the whole picture at that scale)."""
    im = raw(name); a = np.asarray(im.convert('RGBA')); kind, bg = background_of(a)
    return vote_shrink(im, s, PAL, bg)

def fill_holes(im, colour):
    """Transparent pixels enclosed by the drawing (a generator leaves them inside open mouths) get filled."""
    a = np.asarray(im).copy(); clear = a[..., 3] == 0; H, W = clear.shape
    out = np.zeros_like(clear); q = deque([(y, x) for y in range(H) for x in (0, W - 1)] + [(y, x) for x in range(W) for y in (0, H - 1)])
    while q:
        y, x = q.popleft()
        if 0 <= y < H and 0 <= x < W and not out[y, x] and clear[y, x]: out[y, x] = True; q.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    holes = clear & ~out
    a[holes] = colour + (255,)
    return Image.fromarray(a, 'RGBA'), int(holes.sum())

def place(part, ref, search=6, rows=None, by='colour', dys=None):
    """The shift (dx, dy) that lays `part` best on `ref`, judged only on `rows` (y0, y1) when given:
    by colour (where both are drawn, the colours agree most) or by shape (their outlines overlap most)."""
    P = np.asarray(part).astype(int); R = np.asarray(ref).astype(int)
    H, W = R.shape[:2]; best = (1e18, 0, 0)
    for dy in (dys if dys is not None else range(-search, search + 1)):
        for dx in range(-search, search + 1):
            p = P[max(0, -dy):H - max(0, dy), max(0, -dx):W - max(0, dx)]
            r = R[max(0, dy):H - max(0, -dy), max(0, dx):W - max(0, -dx)]
            if rows:
                y0 = max(0, rows[0] - max(0, dy)); y1 = max(y0, rows[1] - max(0, dy)); p = p[y0:y1]; r = r[y0:y1]
            pa, ra = p[..., 3] > 0, r[..., 3] > 0
            if by == 'shape':
                u = (pa | ra).sum()
                if not u: continue
                cost = 1 - (pa & ra).sum() / u
            else:
                both = pa & ra
                if both.sum() < 100: continue
                cost = np.abs(p[..., :3] - r[..., :3]).sum(axis=2)[both].mean()
            if cost < best[0]: best = (cost, dx, dy)
    return best[1], best[2], round(float(best[0]), 3)

def bottom(im): return int(np.nonzero(np.asarray(im)[..., 3].any(axis=1))[0].max())
def top(im): return int(np.nonzero(np.asarray(im)[..., 3].any(axis=1))[0].min())
def solid_top(im, n=45): return int(np.nonzero((np.asarray(im)[..., 3] > 0).sum(axis=1) >= n)[0].min())   # the first row really drawn, not a drop

def moved(im, dx, dy):
    out = Image.new('RGBA', im.size, (0, 0, 0, 0)); out.paste(im, (dx, dy)); return out

s = scale_of(raw('master'))
PAL = shared_palette()
master = to_game('master', s)
print('scale', round(s, 4), 'master', master.getbbox())

layers = {}
layers_base_body = to_game('body', s); _bx, _by, _ = place(layers_base_body, master, 6)
layers_base_body = moved(layers_base_body, _bx, _by)
for group in (LEGS, HEAD, BODY):
    frames = []
    for i, name in enumerate(group):
        if not os.path.exists(os.path.join(SRC, name + '.png')):
            print('  - missing', name, '(the base pose stands in)'); frames.append(frames[0]); continue
        g = to_game(name, s)
        if group is HEAD:
            g, n = fill_holes(g, MOUTH)
            if n: print('   ', name, 'filled', n, 'holes')
        # the base of a part is laid on the master; a pose on its base, by what the edit kept
        if i == 0: dx, dy, cost = place(g, master, 6)
        elif group is HEAD:                              # by its stem, below where the collar starts
            cut = top(layers_base_body) + 6
            dx, dy, cost = place(g, frames[0], 8, rows=(cut, g.height), by='shape')
        elif group is LEGS:                              # feet on the same floor, stump in the same place
            dy = bottom(frames[0]) - bottom(g); t0 = top(frames[0])
            dx, _, cost = place(g, frames[0], 8, rows=(t0, t0 + 30), by='shape', dys=[dy])
        else:                                            # the cracked body by its outline
            dx, dy, cost = place(g, frames[0], 8, by='shape')
        print('  ', name, 'shift', dx, dy, 'cost', cost)
        frames.append(moved(g, dx, dy))
    layers[group[0]] = frames

# the creature's frame: the master's box
mb = master.getbbox(); ox, oy = mb[0], mb[1]; W, H = mb[2] - mb[0], mb[3] - mb[1]
meta_layers, imgs = {}, {}
for key, fr in layers.items():
    boxes = [f.getbbox() for f in fr]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    w, h = box[2] - box[0], box[3] - box[1]
    sheet = Image.new('RGBA', (w * len(fr), h), (0, 0, 0, 0))
    for i, f in enumerate(fr): sheet.alpha_composite(f.crop(box), (i * w, 0))
    sheet.save(os.path.join(OUT, 'vorace-%s.png' % key)); print('vorace-%s' % key, sheet.size)
    meta_layers[key] = {'x': box[0] - ox, 'y': box[1] - oy, 'w': w, 'h': h, 'frames': len(fr)}
    if key == 'legs': meta_layers[key]['drop'] = [top(f) - top(fr[0]) for f in fr]   # the body follows the stump
    if key == 'head': meta_layers[key]['tops'] = [solid_top(f) - oy for f in fr]    # where the trunk lands on each pose (not on the splashes)
    imgs[key] = fr

# landmarks, in the creature's frame
legs0, legs2, head0 = (np.asarray(x) for x in (imgs['legs'][0], imgs['legs'][2], imgs['head'][0]))
ground = int(np.nonzero(legs0[..., 3].any(axis=1))[0].max()) + 1 - oy
def feet(a):
    y = int(np.nonzero(a[..., 3].any(axis=1))[0].max())
    xs = np.nonzero(a[y - 7:y + 1, :, 3].any(axis=0))[0]            # the claws: what touches the lowest rows
    runs, start = [], xs[0]
    for p, q in zip(xs, xs[1:]):
        if q - p > 6: runs.append((start + p) // 2 - ox); start = q
    runs.append((start + xs[-1]) // 2 - ox)
    return [int(r) for r in runs]
ivory = (head0[..., 0] > 185) & (head0[..., 1] > 165) & (head0[..., 2] > 120) & (head0[..., 3] > 0)
ys, xs = np.nonzero(ivory)
mouth = [int(xs.min()) + 4 - ox, int(np.median(ys)) - oy]
hb = imgs['head'][0].getbbox()
crown = [int((hb[0] + hb[2]) / 2) - ox, hb[1] - oy]

mp = os.path.join(OUT, 'meta.json'); meta = json.load(open(mp))
meta['vorace'] = {'w': W, 'h': H, 'ground': ground, 'mouth': mouth, 'crown': crown, 'feet': [feet(legs0), feet(legs2)], **meta_layers}
json.dump(meta, open(mp, 'w'), indent=1); print('meta', json.dumps(meta['vorace']))

# a look at it: the poses put together as the game does, on the forest's colour, x2
prev = []
for L, Hd, B in ((0, 0, 0), (1, 0, 0), (2, 1, 0), (3, 2, 0), (0, 3, 0), (4, 4, 1), (4, 5, 1)):
    c = Image.new('RGBA', (W + 24, H + 24), (52, 70, 72, 255))
    for key, f in (('legs', L), ('head', Hd), ('body', B)):
        m = meta['vorace'][key]; im = Image.open(os.path.join(OUT, 'vorace-%s.png' % key))
        c.alpha_composite(im.crop((f * m['w'], 0, (f + 1) * m['w'], m['h'])), (12 + m['x'], 12 + m['y']))
    prev.append(c)
strip = Image.new('RGBA', (sum(p.width for p in prev), H + 24)); x = 0
for p in prev: strip.alpha_composite(p, (x, 0)); x += p.width
strip.resize((strip.width * 2, strip.height * 2), Image.NEAREST).save(os.path.join(ROOT, 'tools', 'raw', 'vorace3-poses.png'))
print('preview tools/raw/vorace3-poses.png')
