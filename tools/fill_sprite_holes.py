# Fills the see-through holes the old cut-out left inside some sprites: purple and pink shades were
# taken for the magenta background (bat wings, the veins of the dragonfly's wings). A hole is a
# transparent pixel the drawing encloses; it takes the colour most of its neighbours have, from the
# edge of the hole inwards. `vein` darkens what was filled, so a lost vein still shows as a line.
#   python tools/fill_sprite_holes.py
import os
from collections import deque, Counter
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(ROOT, 'assets', 'img')
SPRITES = {'bat': 1.0, 'mount-dragonfly': 0.82}       # name: how much the filled pixels are darkened

def enclosed(a):
    clear = a[..., 3] == 0; H, W = clear.shape; out = np.zeros_like(clear)
    q = deque([(y, x) for y in range(H) for x in (0, W - 1)] + [(y, x) for x in range(W) for y in (0, H - 1)])
    while q:
        y, x = q.popleft()
        if 0 <= y < H and 0 <= x < W and not out[y, x] and clear[y, x]: out[y, x] = True; q.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    return clear & ~out

for name, dark in SPRITES.items():
    p = os.path.join(IMG, name + '.png'); a = np.asarray(Image.open(p).convert('RGBA')).copy()
    holes = enclosed(a); todo = set(zip(*np.nonzero(holes))); n = len(todo); filled = []
    while todo:
        done = []
        for y, x in todo:
            nb = [tuple(int(v) for v in a[y + dy, x + dx]) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                  if (dy or dx) and 0 <= y + dy < a.shape[0] and 0 <= x + dx < a.shape[1] and a[y + dy, x + dx, 3] > 0 and (y + dy, x + dx) not in todo]
            nb = [c for c in nb if sum(c[:3]) > 125] or nb          # rather the wing's colour than the outline's
            if len(nb) >= 2: done.append(((y, x), Counter(nb).most_common(1)[0][0]))
        if not done: break
        for (y, x), c in done: a[y, x] = c; todo.discard((y, x)); filled.append((y, x))
    for y, x in filled: a[y, x, :3] = (a[y, x, :3] * dark).astype(np.uint8)
    Image.fromarray(a, 'RGBA').save(p); print(name, 'holes', n, 'filled', len(filled))
