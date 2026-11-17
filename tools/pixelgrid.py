# Brings a generated "pixel art" picture back to its true pixels.
# Image generators draw pixel art as blocks of N x N image pixels, but N is never a round number and the
# blocks are slightly soft: shrinking the picture by a guessed factor (Image.BOX) blends neighbouring
# blocks and gives mushy, uneven pixels. Here the grid is measured instead: where the colour changes,
# column by column and row by row, falls on a regular comb whose step is the block size. Each block is
# then read at its centre (the median of its middle), so every art pixel keeps one clean colour.
#
#   from pixelgrid import degrid
#   art, info = degrid(Image.open('big.png'))         # info: block size and phase found, x and y
#
# python tools/pixelgrid.py in.png out.png [--preview 3]   (prints the grid found)
import sys
import numpy as np
from PIL import Image

def magenta_mask(a):
    """True where the picture is the flat magenta background."""
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (r > 150) & (b > 150) & (g < 140) & (np.abs(r - b) < 80)

def checker_mask(a):
    """True where the picture shows a painted "transparency" checkerboard: light, colourless greys.
    (A generator asked for a transparent background sometimes paints one instead.)"""
    f = a[..., :3].astype(int)
    return (f.max(axis=2) - f.min(axis=2) < 16) & (f.min(axis=2) > 165)

def background_of(a):
    """The background's kind and where it is: real transparency, a painted checkerboard, or flat magenta.
    Never two at once: bright pink petals would pass for magenta, ivory fangs for a light checker."""
    clear = a[..., 3] < 128
    if clear.mean() > 0.05: return 'alpha', clear
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])[None]
    if checker_mask(border).mean() > 0.8: return 'checker', checker_mask(a)
    return 'magenta', magenta_mask(a)

def edge_profile(a, axis, bg=None):
    """How much the colour changes between neighbours, summed across the other axis. Changes inside
    the background (the squares of a painted checkerboard) do not count: only the drawing's grid."""
    f = a[..., :3].astype(np.float32)
    d = np.abs(np.diff(f, axis=axis)).sum(axis=2)
    if bg is not None:
        both = bg[:, 1:] & bg[:, :-1] if axis == 1 else bg[1:] & bg[:-1]
        d[both] = 0
    return d.sum(axis=1 - axis)

def find_grid(profile, lo=3.0, hi=20.0):
    """The block size and phase whose comb of edges lines up best with the profile.
    A comb of twice the true size also lands on edges only, so the smallest size that scores
    nearly as well as the best one is the true size."""
    e = profile / (profile.mean() + 1e-6)
    n = len(e); best = []
    for p in np.arange(lo, hi, 0.02):
        teeth = np.arange(0, n - 1, p)
        top = (0.0, 0.0)
        for phase in np.arange(0, p, 0.25):
            idx = np.round(teeth + phase).astype(int); idx = idx[idx < n]
            m = e[idx].mean()
            if m > top[0]: top = (m, phase)
        best.append((p, top[0], top[1]))
    peak = max(b[1] for b in best)
    for p, m, phase in best:
        if m >= 0.88 * peak:
            # refine around this size
            cands = [b for b in best if abs(b[0] - p) < 0.3]
            return max(cands, key=lambda b: b[1])
    return max(best, key=lambda b: b[1])

def cut_background(art, tol=42):
    """The flat background around the drawing made transparent, whatever its colour (magenta, white…):
    it is the colour of the border, flooded inwards from the border. The drawing's outline stops the
    flood, so light colours inside it (fangs, thorns) stay."""
    a = np.asarray(art).copy(); H, W = a.shape[:2]
    rgb = a[..., :3].astype(int)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bgc = np.median(border, axis=0)
    near = np.abs(rgb - bgc).sum(axis=2) < tol
    seen = np.zeros((H, W), bool); stack = [(y, x) for y in range(H) for x in (0, W - 1)] + [(y, x) for x in range(W) for y in (0, H - 1)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= H or x >= W or seen[y, x] or not near[y, x]: continue
        seen[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    a[seen, 3] = 0
    return Image.fromarray(a, 'RGBA')

def cut_checker(art, min_gap=6):
    """A painted checkerboard cut out: its pixels flooded from the border, and every patch of it the
    drawing encloses (between legs, roots...) once it is larger than a few pixels."""
    a = np.asarray(art).copy(); H, W = a.shape[:2]
    cand = checker_mask(a) & (a[..., 3] > 0)
    label = np.zeros((H, W), int); n = 0
    for y0 in range(H):
        for x0 in range(W):
            if not cand[y0, x0] or label[y0, x0]: continue
            n += 1; stack = [(y0, x0)]; cells = []; edge = False
            while stack:
                y, x = stack.pop()
                if y < 0 or x < 0 or y >= H or x >= W or label[y, x] or not cand[y, x]: continue
                label[y, x] = n; cells.append((y, x)); edge |= y in (0, H - 1) or x in (0, W - 1)
                stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
            if edge or len(cells) >= min_gap:
                for y, x in cells: a[y, x, 3] = 0
    return Image.fromarray(a, 'RGBA')

def degrid(im, grid=None, keep_bg=False):
    """The picture at its true pixel size, background made transparent."""
    a = np.asarray(im.convert('RGBA'))
    kind, bg = background_of(a)
    if grid is None:
        px, _, phx = find_grid(edge_profile(a, 1, bg))
        py, _, phy = find_grid(edge_profile(a, 0, bg))
        # one grid for both axes: the blocks are square
        p = (px + py) / 2
        grid = (p, (phx + 1) % p, (phy + 1) % p)
    p, ox, oy = grid
    H, W = a.shape[:2]
    cols = int((W - ox) // p); rows = int((H - oy) // p)
    out = np.zeros((rows, cols, 4), np.uint8)
    # a painted checkerboard is read like the drawing, then cut out (cut_checker): a light grey pixel
    # inside the drawing must not be lost on the way
    if kind == 'checker': bg = np.zeros(bg.shape, bool)
    m = max(1, int(p * 0.25))
    for j in range(rows):
        y0 = int(round(oy + j * p)); y1 = int(round(oy + (j + 1) * p))
        for i in range(cols):
            x0 = int(round(ox + i * p)); x1 = int(round(ox + (i + 1) * p))
            cy0, cy1, cx0, cx1 = y0 + m, max(y0 + m + 1, y1 - m), x0 + m, max(x0 + m + 1, x1 - m)
            block = a[cy0:cy1, cx0:cx1, :3].reshape(-1, 3); bgb = bg[cy0:cy1, cx0:cx1].reshape(-1)
            if block.size == 0: continue
            if bgb.mean() > 0.5 and not keep_bg: continue
            fg = block[~bgb] if (~bgb).any() else block
            out[j, i, :3] = np.median(fg, axis=0); out[j, i, 3] = 255
    art = Image.fromarray(out, 'RGBA')
    if not keep_bg: art = cut_checker(art) if kind == 'checker' else cut_background(art)
    return art, {'p': round(float(p), 3), 'ox': round(float(ox), 2), 'oy': round(float(oy), 2), 'size': (cols, rows)}

def fringe_to_outline(im, outline=(26, 16, 36)):
    """Pinkish pixels left by the magenta background along the edges become the outline colour."""
    a = np.asarray(im).copy()
    r, g, b, al = (a[..., k].astype(int) for k in range(4))
    pink = (al > 0) & (r > 90) & (b > 90) & (g < 0.6 * np.minimum(r, b)) & (g < 100)
    a[pink, :3] = outline
    return Image.fromarray(a, 'RGBA')

def reduce_palette(im, colours=48):
    """Merges the near-identical shades a generator leaves into one palette (alpha kept as it is)."""
    a = np.asarray(im)
    rgb = Image.fromarray(a[..., :3], 'RGB').quantize(colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    out = np.dstack([np.asarray(rgb), a[..., 3]])
    return Image.fromarray(out.astype(np.uint8), 'RGBA')

def trim(im, pad=0):
    bb = im.getbbox()
    if not bb: return im
    return im.crop((max(0, bb[0] - pad), max(0, bb[1] - pad), min(im.width, bb[2] + pad), min(im.height, bb[3] + pad)))

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    art, info = degrid(Image.open(src))
    art = trim(reduce_palette(fringe_to_outline(art)))
    art.save(dst); print(info, art.size)
    if '--preview' in sys.argv:
        k = int(sys.argv[sys.argv.index('--preview') + 1])
        bgc = Image.new('RGBA', art.size, (40, 52, 60, 255)); bgc.alpha_composite(art)
        bgc.resize((art.width * k, art.height * k), Image.NEAREST).save(dst.replace('.png', '-x%d.png' % k))
