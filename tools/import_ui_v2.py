# UI kit v2 (stone, vines, turquoise gem), cut from one generated sheet: every element is taken out on
# its own, the words baked into the buttons are wiped (each row refilled with the colour of the face
# around the word), then everything is put onto the game's pixels without blending (pixeldown.py
# vote_shrink). The sheet's own pixels are about 3.5 px wide, so k = 2/7 gives back its grid.
#   python tools/import_ui_v2.py            -> assets/ui-v2/*.png + assets/ui-v2/meta.json
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from pixelgrid import trim
from pixeldown import vote_shrink, palette_of

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'ui-v2', 'source', 'ui-kit-source.webp')
OUT = os.path.join(ROOT, 'assets', 'ui-v2')
K = 2 / 7

# name: (x0, y0, x1, y1) in the sheet, found by the gaps in its transparency
BOXES = {
    'panel-lg':     (35, 22, 876, 521),
    'panel-md':     (895, 22, 1506, 521),
    'btn-normal':   (46, 554, 390, 733),
    'btn-hover':    (416, 554, 764, 733),
    'btn-pressed':  (782, 554, 1117, 733),
    'btn-disabled': (1139, 554, 1494, 733),
    'sq-gem':       (33, 761, 217, 991),
    'sq-gear':      (244, 761, 427, 991),
    'sq-play':      (448, 761, 628, 991),
    'sq-close':     (651, 761, 831, 991),
    'sq-check':     (851, 761, 1026, 991),
    'bar':          (1085, 761, 1491, 856),
    'round':        (1085, 857, 1491, 991),     # both round arrows, split below
}
WIPE = {'btn-normal', 'btn-hover', 'btn-pressed', 'btn-disabled'}   # word to remove
BLANK = {'sq-blank': 'sq-play'}                                      # icon removed -> empty square


def wipe_middle(a, frac_x=(0.22, 0.78), frac_y=(0.30, 0.72), pad=10, side_w=12):
    """Finds what stands out from the face in the middle of a button (a word, an icon) and refills
    each of its rows with the median colour of the face just left and right of it. The search zone
    must stay inside the face, or the stone frame would be taken for the word."""
    a = a.copy(); h, w = a.shape[:2]
    y0, y1 = int(h * frac_y[0]), int(h * frac_y[1]); x0, x1 = int(w * frac_x[0]), int(w * frac_x[1])
    zone = a[y0:y1, x0:x1, :3].astype(int)
    face = np.median(zone.reshape(-1, 3), axis=0)
    odd = np.abs(zone - face).sum(2) > 45
    ys, xs = np.nonzero(odd)
    if not len(ys): return a
    by0, by1 = max(y0, y0 + ys.min() - pad), min(y1, y0 + ys.max() + 1 + pad)
    bx0, bx1 = max(x0 + side_w, x0 + xs.min() - pad), min(x1 - side_w, x0 + xs.max() + 1 + pad)
    for y in range(by0, by1):
        side = np.concatenate([a[y, bx0 - side_w:bx0, :3], a[y, bx1:bx1 + side_w, :3]]).astype(int)
        a[y, bx0:bx1, :3] = np.median(side, axis=0).astype(np.uint8)
    return a


def to_game(a):
    bg = a[..., 3] < 128
    return trim(vote_shrink(Image.fromarray(a, 'RGBA'), K, palette_of(a[..., :3][~bg]), bg))


sheet = np.asarray(Image.open(SRC).convert('RGBA'))
crops = {n: sheet[y0:y1, x0:x1] for n, (x0, y0, x1, y1) in BOXES.items()}

# the two round arrows sit side by side in one box
r = crops.pop('round'); cols = np.nonzero((r[..., 3] > 128).any(0))[0]
cut = cols[np.argmax(np.diff(cols))] + 1
crops['round-up'], crops['round-down'] = r[:, :cut], r[:, cut:]

for n in WIPE:      # "Normal" runs further right than the other words
    crops[n] = wipe_middle(crops[n], (0.16, 0.88), side_w=8) if n == 'btn-normal' else wipe_middle(crops[n], (0.18, 0.82))
for n, src in BLANK.items(): crops[n] = wipe_middle(crops[src], (0.24, 0.76), (0.26, 0.72), pad=6, side_w=6)

meta = {}
for n, a in crops.items():
    im = to_game(a); im.save(os.path.join(OUT, n + '.png'))
    meta[n] = list(im.size); print(n, a.shape[1::-1], '->', im.size)
json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
