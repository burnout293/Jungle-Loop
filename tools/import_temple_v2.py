# Temple v2: the temple's doorway blocked by boulders held in vines, the whole building down to its
# steps (the old one was cut off at the bottom). Generated with ElevenLabs (gpt-image-2.6-sunburst, 2K,
# max, the old temple as reference: flow "Jungle Loop — temple obstrué"), four takes kept in
# tools/raw/gen/temple-v2/temple-obstrue-1..4.png. Take 2 is the one chosen.
# Put onto the game's pixels without blending (pixeldown.py vote_shrink), as tall as the old temple
# (174), then the few see-through pixels the painted checkerboard left inside are filled with the
# colour most of their neighbours have.
#   python tools/import_temple_v2.py [take]      -> assets/img/temple-v2.png
import os, sys
from collections import deque, Counter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from pixelgrid import background_of, trim
from pixeldown import vote_shrink, palette_of

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TAKE = sys.argv[1] if len(sys.argv) > 1 else '2'
SRC = os.path.join(ROOT, 'tools', 'raw', 'gen', 'temple-v2', f'temple-obstrue-{TAKE}.png')
OUT = os.path.join(ROOT, 'assets', 'img', 'temple-v2.png')
HEIGHT = 174                                   # the old temple's height
# take 2 at this height, in its own pixels: the opening between the two carved pillars, from under
# the lintel down to the first step, where the blast must open the way out
DOOR = {'left': 90, 'right': 134, 'top': 72, 'bottom': 140}


def enclosed(a):
    clear = a[..., 3] == 0; H, W = clear.shape; out = np.zeros_like(clear)
    q = deque([(y, x) for y in range(H) for x in (0, W - 1)] + [(y, x) for x in range(W) for y in (0, H - 1)])
    while q:
        y, x = q.popleft()
        if 0 <= y < H and 0 <= x < W and not out[y, x] and clear[y, x]:
            out[y, x] = True; q.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    return clear & ~out


im = Image.open(SRC).convert('RGBA'); a = np.asarray(im); kind, bg = background_of(a)
ys = np.nonzero((~bg).any(axis=1))[0]
k = HEIGHT / (ys.max() - ys.min() + 1)
s = np.asarray(trim(vote_shrink(im, k, palette_of(a[..., :3][~bg]), bg))).copy()
todo = set(zip(*np.nonzero(enclosed(s)))); holes = len(todo)
while todo:
    done = []
    for y, x in todo:
        nb = [tuple(int(v) for v in s[y + dy, x + dx]) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
              if (dy or dx) and 0 <= y + dy < s.shape[0] and 0 <= x + dx < s.shape[1]
              and s[y + dy, x + dx, 3] > 0 and (y + dy, x + dx) not in todo]
        if nb: done.append(((y, x), Counter(nb).most_common(1)[0][0]))
    for (y, x), c in done: s[y, x] = c; todo.discard((y, x))
Image.fromarray(s).save(OUT)
print(f'take {TAKE} ({kind} background) -> {s.shape[1]}x{s.shape[0]}, {holes} holes filled, doorway {DOOR}')
