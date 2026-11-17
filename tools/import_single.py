# Single objects generated one per picture (tools/raw/gen), put straight onto the game's pixels
# without any blending: whatever their background (transparent, painted checkerboard, magenta), it is
# cut out, then each game pixel takes the colour covering most of its footprint, outline kept
# (pixeldown.py vote_shrink), at the width the object has in the game.   python tools/import_single.py
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from pixelgrid import background_of, trim
from pixeldown import vote_shrink

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, OUT = os.path.join(ROOT, 'tools', 'raw', 'gen'), os.path.join(ROOT, 'assets', 'img')

ITEMS = {                     # game name: (generated picture, width in the game in art pixels)
    'crate-big': ('big-crate-2', 58),     # the forest's big crate, to smash
    'vorace-log': ('vorace-log-1', 176),  # the trunk that falls on Vorace
}

def palette_of(px, n=64, far=40):
    """Its main colours (median cut), plus every colour still far from them (small details)."""
    q = Image.fromarray(px[None].astype(np.uint8), 'RGB').quantize(n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    P = np.array(q.getpalette()[:n * 3]).reshape(-1, 3).astype(float); sample = px[::17].astype(float)
    while len(P) < 256:
        d = np.abs(sample[:, None] - P[None]).sum(axis=2).min(axis=1); i = int(d.argmax())
        if d[i] <= far: break
        P = np.vstack([P, sample[i]])
    img = Image.new('P', (1, 1)); flat = [int(v) for c in P.astype(int) for v in c]
    img.putpalette(flat + flat[-3:] * (256 - len(P))); return img

only = sys.argv[1:]
for name, (src, width) in ITEMS.items():
    if only and name not in only: continue
    p = os.path.join(SRC, src + '.png')
    if not os.path.exists(p): print('missing', src); continue
    im = Image.open(p).convert('RGBA'); a = np.asarray(im); kind, bg = background_of(a)
    xs = np.nonzero((~bg).any(axis=0))[0]
    k = width / (xs.max() - xs.min() + 1)
    small = trim(vote_shrink(im, k, palette_of(a[..., :3][~bg]), bg))
    small.save(os.path.join(OUT, name + '.png')); print(name, kind, im.size, '->', small.size)
