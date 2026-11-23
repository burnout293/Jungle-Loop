"""The relic (0.52): the four pieces as he drew them himself (assets/src/relique/relique-v51-*.png, from his
relique-v51.psd kept in Projects/Archives/Jungle-Loop/relique), each put back at its place in the whole mask so
that the pieces lie exactly on each other (the same 86 x 112 picture for all):

    relique-complete.png      the whole mask                     (relique-v51-full)
    relique-couronne.png      the crown of leaves and its heart  (relique-v51-green, jade)
    relique-tete-gauche.png   the left half of the head          (relique-v51-yellow, amber)
    relique-tete-droite.png   the right half of the head         (relique-v51-red, ember)
    relique-machoire.png      the jaw                            (relique-v51-purple, moonstone)

Each piece's place is found by matching its pixels against the whole mask. Writes assets/img/relic/.

    python tools/place_relic.py
"""
import pathlib

import numpy as np
from PIL import Image

here = pathlib.Path(__file__).resolve().parent.parent
src = here / 'assets' / 'src' / 'relique'
out = here / 'assets' / 'img' / 'relic'
out.mkdir(exist_ok=True)
full = Image.open(src / 'relique-v51-full.png').convert('RGBA')
fa = np.array(full).astype(int)
H, W = fa.shape[:2]
full.save(out / 'relique-complete.png')
for colour, name in (('green', 'couronne'), ('yellow', 'tete-gauche'), ('red', 'tete-droite'), ('purple', 'machoire')):
    piece = Image.open(src / f'relique-v51-{colour}.png').convert('RGBA')
    pa = np.array(piece).astype(int)
    h, w = pa.shape[:2]
    solid = pa[:, :, 3] > 0
    best = (-1.0, 0, 0)
    for oy in range(H - h + 1):
        for ox in range(W - w + 1):
            diff = np.abs(fa[oy:oy + h, ox:ox + w, :3] - pa[:, :, :3]).sum(axis=2)[solid]
            same = float((diff < 6).mean())
            if same > best[0]:
                best = (same, ox, oy)
    canvas = Image.new('RGBA', (W, H))
    canvas.alpha_composite(piece, (best[1], best[2]))
    canvas.save(out / f'relique-{name}.png')
    print(f'relique-{name}.png at {best[1]},{best[2]} ({best[0]:.0%} of its pixels as in the whole)')
