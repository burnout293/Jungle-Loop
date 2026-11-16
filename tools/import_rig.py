# The hero's loose parts, the mounts, the mosquito and the newer shop icons, cut out of the generated
# sheets in tools/raw/gen (flat magenta behind). python tools/import_rig.py
#
# The hero is no longer a sheet of poses: his body, one fist and one shoe are separate images that
# render.js moves by itself, which gives a run as smooth as the frame rate. Mount frames are lined
# up on their leaf saddle and mosquito frames on their eye, so nothing jumps from one frame to the next.
import json, os
from collections import deque
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, OUT = os.path.join(ROOT, 'tools', 'raw', 'gen'), os.path.join(ROOT, 'assets', 'img')
PINK = (255, 0, 255, 255)

def magenta(p): return p[0] > 150 and p[2] > 150 and p[1] < 140 and abs(p[0] - p[2]) < 80
def sheet(name): return Image.open(os.path.join(SRC, name + '.png')).convert('RGBA')
def save(im, name): im.save(os.path.join(OUT, name + '.png')); print(name, im.size)

def shrink(im, k):
    s = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BOX); px = s.load()
    for y in range(s.height):
        for x in range(s.width):
            p = px[x, y]
            if magenta(p) or p[3] < 128: px[x, y] = (0, 0, 0, 0)
            elif p[0] > 90 and p[2] > 90 and p[1] < 0.6 * min(p[0], p[2]): px[x, y] = (26, 16, 36, 255)   # pink fringe -> outline
            else: px[x, y] = (p[0], p[1], p[2], 255)
    return s

def components(im, min_area=150):
    """Every connected drawing of a sheet: (box, pixels)."""
    px = im.load(); w, h = im.size; seen = bytearray(w * h); out = []
    for y in range(h):
        for x in range(w):
            if seen[y * w + x] or magenta(px[x, y]): continue
            q = deque([(x, y)]); seen[y * w + x] = 1; pts = []
            while q:
                cx, cy = q.popleft(); pts.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and not magenta(px[nx, ny]):
                        seen[ny * w + nx] = 1; q.append((nx, ny))
            if len(pts) >= min_area:
                xs, ys = [p[0] for p in pts], [p[1] for p in pts]
                out.append(((min(xs), min(ys), max(xs) + 1, max(ys) + 1), pts))
    return out

def cut(im, comp):
    """One drawing alone on magenta, whatever else its box overlaps."""
    (x0, y0, x1, y1), pts = comp
    out = Image.new('RGBA', (x1 - x0, y1 - y0), PINK); o, px = out.load(), im.load()
    for x, y in pts: o[x - x0, y - y0] = px[x, y]
    return out

def centre(im, test, blur=0):
    """Where the pixels passing `test` are, on average (or where they are densest, with `blur`)."""
    px = im.load(); m = Image.new('L', im.size, 0); d = m.load()
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if not magenta(p) and p[3] > 128 and test(p): d[x, y] = 255
    if blur: m = m.filter(ImageFilter.GaussianBlur(blur)); d = m.load()
    top = m.getextrema()[1]
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if d[x, y] > top * 0.7]
    return sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)

dark = lambda p: max(p[:3]) < 60
leaf = lambda p: p[1] > p[0] + 40 and p[1] > p[2] + 40
eye = lambda p: p[0] > 200 and p[1] > 170 and p[2] < 90
meta = {}

# ---------- the hero's parts ----------
K = 0.214                                              # same size as the sheet of poses he replaces
h = sheet('hero3'); comps = components(h)
def at(x, y): return next(c for c in comps if c[0][0] <= x < c[0][2] and c[0][1] <= y < c[0][3] and (x, y) in set(c[1]))
body, fist, shoe, rotor = cut(h, at(430, 185)), cut(h, at(462, 236)), cut(h, at(421, 290)), cut(h, at(890, 520))
rig = {}
for name, im in (('body', body), ('rotor', rotor)):
    hx, hy = centre(im, dark, 14)                      # the black ball of his head
    px = im.load(); low = [x for y in range(im.height - 6, im.height) for x in range(im.width) if not magenta(px[x, y])]
    s = shrink(im, K); save(s, 'hero-' + name)
    rig[name] = { 'w': s.width, 'h': s.height, 'hx': round(hx * K, 1), 'hy': round(hy * K, 1), 'tx': round(sum(low) / len(low) * K, 1) }
# the rotor's blades are the wide rows at the top: render.js squeezes them sideways to make them spin
px = rotor.load(); wide = [sum(1 for x in range(rotor.width) if not magenta(px[x, y])) for y in range(rotor.height)]
rig['rotor']['blade'] = round(next(y for y in range(20, rotor.height) if wide[y] < 0.45 * max(wide)) * K)
for name, im in (('fist', fist), ('shoe', shoe)):
    s = shrink(im, K); save(s, 'hero-' + name); rig[name] = { 'w': s.width, 'h': s.height }
meta['rig'] = rig

# ---------- mounts ----------
# Frames of one animal are lined up on an anchor, so nothing jumps from one frame to the next: the
# leaf saddle for a gallop or a flight (the rider sits still), the gripping fist for the gorilla
# hanging from the vines (the body swings under a hand that stays put; the saddle's place is then
# noted for each frame).
saddle = lambda p: p[1] > p[0] + 30 and p[1] > p[2] + 80
def strip(frames, anchors, k):
    left = max(a[0] for a in anchors); up = max(a[1] for a in anchors)
    cw = round(max(left - a[0] + f.width for f, a in zip(frames, anchors)) * k) + 2
    ch = round(max(up - a[1] + f.height for f, a in zip(frames, anchors)) * k) + 1
    out = Image.new('RGBA', (cw * len(frames), ch), (0, 0, 0, 0)); offs = []
    for i, (f, a) in enumerate(zip(frames, anchors)):
        ox, oy = round((left - a[0]) * k), round((up - a[1]) * k)
        out.alpha_composite(shrink(f, k), (i * cw + ox, oy)); offs.append((ox, oy))
    return out, round(left * k), round(up * k), offs

def rows(name, count):
    im = sheet(name); found = sorted(components(im, 4000), key=lambda c: (c[0][1] // 300, c[0][0]))
    assert len(found) == count, (name, len(found))
    return [cut(im, c) for c in found]

meta['mounts'] = json.load(open(os.path.join(OUT, 'meta.json'))).get('mounts', {})   # keeps the dragonfly, cut by import_objets.py
meta['mounts'].pop('moskito', None)
g = rows('gorilla2', 8); old = rows('mounts', 8)
for name, frames, k in (('gorilla', g[:4], 0.3), ('rhino', old[4:], 0.3)):    # (the Moskito is gone: the dragonfly is in import_objets.py)
    out, sx, sy, _ = strip(frames, [centre(f, saddle) for f in frames], k)
    save(out, 'mount-' + name)
    meta['mounts'][name] = { 'frames': len(frames), 'seatX': sx, 'seatY': sy }
hang = g[4:]; grips = []
for f in hang:                                         # the fist at the very top of the drawing
    px = f.load(); xs = [x for y in range(14) for x in range(f.width) if not magenta(px[x, y])]
    grips.append((sum(xs) / len(xs), 0))
out, gx, _, offs = strip(hang, grips, 0.3)
save(out, 'mount-gorilla-hang')
seats = [centre(f, saddle) for f in hang]
meta['mounts']['gorilla-hang'] = { 'frames': 4, 'seatX': gx, 'seats': [[round(s[0] * 0.3 + o[0]), round(s[1] * 0.3 + o[1])] for s, o in zip(seats, offs)] }

# ---------- the mosquito: wings up, level, down, and diving; lined up on its eye ----------
q = sheet('mosquito'); found = sorted(components(q, 4000), key=lambda c: c[0][0])
assert len(found) == 4, len(found)
frames = [cut(q, c) for c in found]; eyes = [centre(f, eye) for f in frames]
Q = 36 / max(f.height for f in frames)
left = max(e[0] for e in eyes); up = max(e[1] for e in eyes)
cw = round(max(left - e[0] + f.width for f, e in zip(frames, eyes)) * Q) + 1
ch = round(max(up - e[1] + f.height for f, e in zip(frames, eyes)) * Q) + 1
out = Image.new('RGBA', (cw * 4, ch), (0, 0, 0, 0))
for i, (f, e) in enumerate(zip(frames, eyes)): out.alpha_composite(shrink(f, Q), (i * cw + round((left - e[0]) * Q), round((up - e[1]) * Q)))
save(out, 'mosquito')
meta['mosquito'] = { 'frames': 4 }

# ---------- shop icons: loose bits (bubbles, an arrow) belong to the icon next to them ----------
def groups(im, cell=8, grow=1):
    px = im.load(); gw, gh = im.width // cell, im.height // cell
    solid = [[any(not magenta(px[x, y]) for y in range(gy * cell, gy * cell + cell, 2) for x in range(gx * cell, gx * cell + cell, 2)) for gx in range(gw)] for gy in range(gh)]
    fat = [[any(solid[y][x] for y in range(max(0, gy - grow), min(gh, gy + grow + 1)) for x in range(max(0, gx - grow), min(gw, gx + grow + 1))) for gx in range(gw)] for gy in range(gh)]
    seen = [[False] * gw for _ in range(gh)]; boxes = []
    for gy in range(gh):
        for gx in range(gw):
            if not fat[gy][gx] or seen[gy][gx]: continue
            todo = deque([(gx, gy)]); seen[gy][gx] = True; box = [gx, gy, gx, gy]; n = 0
            while todo:
                cx, cy = todo.popleft()
                if solid[cy][cx]: n += 1; box = [min(box[0], cx), min(box[1], cy), max(box[2], cx), max(box[3], cy)]
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < gw and 0 <= ny < gh and fat[ny][nx] and not seen[ny][nx]: seen[ny][nx] = True; todo.append((nx, ny))
            if n > 60: boxes.append((box[0] * cell, box[1] * cell, (box[2] + 1) * cell, (box[3] + 1) * cell))
    boxes.sort(key=lambda b: ((b[1] + b[3]) // 2 // (im.height // 2), b[0]))
    return [im.crop(b) for b in boxes]

icons = groups(sheet('icons2'))
assert len(icons) == 8, len(icons)
for name, im in zip(('leap', 'drunk', 'nature', 'shoes', 'spring', 'heart', 'saddle', 'lucky'), icons):
    save(shrink(im, 54 / max(im.size)), 'ico-' + name)

path = os.path.join(OUT, 'meta.json')
old = json.load(open(path)); old.pop('hero', None); old.update(meta)
json.dump(old, open(path, 'w'), indent=1)
print(json.dumps(meta))
