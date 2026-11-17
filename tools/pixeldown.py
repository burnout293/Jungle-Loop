# Shrinks clean pixel art by any factor without blending colours: each new pixel takes the colour that
# covers most of its footprint in the old picture, and the dark outline wins as soon as it covers a
# third of it, so the contour never breaks. No new colour is ever made.
#   from pixeldown import shrink_art; small = shrink_art(art, 2/3)
import numpy as np
from PIL import Image

OUTLINE_MAX = 125         # a pixel this dark (sum of r, g, b) counts as outline (#1a1024 is 78)

def shrink_art(im, k, outline_bias=1/3):
    a = np.asarray(im.convert('RGBA')).astype(int)
    H, W = a.shape[:2]; h, w = max(1, round(H * k)), max(1, round(W * k))
    out = np.zeros((h, w, 4), np.uint8)
    s = 1 / k
    for j in range(h):
        y0, y1 = j * s, (j + 1) * s
        for i in range(w):
            x0, x1 = i * s, (i + 1) * s
            votes = {}
            for y in range(int(y0), min(H, int(np.ceil(y1)))):
                wy = min(y + 1, y1) - max(y, y0)
                if wy <= 0: continue
                for x in range(int(x0), min(W, int(np.ceil(x1)))):
                    wx = min(x + 1, x1) - max(x, x0)
                    if wx <= 0: continue
                    p = a[y, x]; key = tuple(p) if p[3] > 0 else (0, 0, 0, 0)
                    votes[key] = votes.get(key, 0) + wx * wy
            area = (y1 - y0) * (x1 - x0)
            dark = [(v, c) for c, v in votes.items() if c[3] > 0 and c[0] + c[1] + c[2] < OUTLINE_MAX]
            if dark and sum(v for v, _ in dark) >= outline_bias * area:
                c = max(dark)[1]
            else:
                c = max(votes.items(), key=lambda kv: kv[1])[0]
            out[j, i] = c
    return Image.fromarray(out, 'RGBA')


def vote_shrink(im, k, palette, bg=None, outline_max=OUTLINE_MAX, bias=1/3, sub=8):
    """A large generated picture straight onto the game's pixels, without measuring its grid: its
    colours are first mapped onto `palette` (a 'P' image), then each game pixel takes the colour that
    covers most of its footprint, the dark outline winning from a third. `bg` marks the background
    (True = transparent). Works whatever the picture's own pixel size, even an uneven one."""
    a = np.asarray(im.convert('RGBA'))
    H, W = a.shape[:2]; h, w = max(1, round(H * k)), max(1, round(W * k))
    pal = np.array(palette.getpalette()[:768]).reshape(-1, 3)
    n = len(pal)
    idx = np.asarray(Image.fromarray(a[..., :3], 'RGB').quantize(palette=palette, dither=Image.Dither.NONE)).astype(np.int32)
    if bg is None: bg = a[..., 3] < 128
    idx[bg] = n                                                    # one more index: transparent
    big = np.asarray(Image.fromarray(idx).resize((w * sub, h * sub), Image.NEAREST))
    blocks = big.reshape(h, sub, w, sub).transpose(0, 2, 1, 3).reshape(h, w, sub * sub)
    counts = np.stack([(blocks == v).sum(-1) for v in range(n + 1)], -1)
    pick = counts.argmax(-1)
    dark = [v for v in range(n) if pal[v].sum() < outline_max]
    if dark:
        dc = counts[..., dark]; dsum = dc.sum(-1)
        use = (dsum >= bias * sub * sub) & (pick != n) | (dsum >= 0.5 * sub * sub)
        pick = np.where(use, np.array(dark)[dc.argmax(-1)], pick)
    out = np.zeros((h, w, 4), np.uint8)
    solid = pick != n
    out[solid, :3] = pal[pick[solid]]; out[solid, 3] = 255
    return Image.fromarray(out, 'RGBA')


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
