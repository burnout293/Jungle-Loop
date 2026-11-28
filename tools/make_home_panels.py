"""(0.68) The home screen's two corner panels (ÉQUIPEMENT 126 x 58, TON GROUPE 150 x 58) cut from one PixelLab
plaque (assets/src/home/panel-pixellab.png, 192 x 58): its left end and its right end kept whole, joined where
their columns match best (never stretched).   python tools/make_home_panels.py"""
from PIL import Image
import numpy as np

SRC = 'assets/src/home/panel-pixellab.png'
OUT = 'assets/img/ui-v2/wood/panel-%d.png'

im = Image.open(SRC).convert('RGBA')
a = np.asarray(im).astype(int)
W = a.shape[1]
for target in (126, 150):
    best = None
    for left in range(40, target - 40):
        right = target - left
        c1 = a[:, left - 1]
        c2 = a[:, W - right]
        d = np.abs(c1 - c2).sum()
        if best is None or d < best[0]:
            best = (d, left)
    left = best[1]
    out = np.concatenate([a[:, :left], a[:, W - (target - left):]], axis=1).astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(OUT % target)
    print(target, 'cut at', left, 'diff', best[0])
