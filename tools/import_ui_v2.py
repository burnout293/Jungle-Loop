# UI kit v2 (stone, vines, turquoise gem), cut from one generated sheet and made at the exact sizes the
# interface uses, so the browser never has to stretch or cut a picture:
#   - text buttons, 30/38/50 high, 4 states on one canvas: three parts, the middle made of identical
#     columns (stretching it changes no pixel), caps of equal width so the text stays centred;
#   - square buttons 36 and 28, round arrows 28: drawn straight at that size;
#   - bars 12 and 8 high: three parts, identical middle columns;
#   - panels of a fixed size: assembled at that very size from the sheet's panel, by repeating or
#     removing plain stretches of stone between the ornaments (no pixel resized), the face refilled
#     with the sheet's own cracked stone, mirrored;
#   - panels whose height follows their text: exact width, three parts top/middle/bottom, the middle
#     made of identical rows.
# Everything goes onto the game's pixels without blending (pixeldown.py vote_shrink).
#   python tools/import_ui_v2.py      -> assets/ui-v2/*.png + assets/ui-v2/meta.json (slices for CSS)
import os, sys, json, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from pixeldown import vote_shrink, palette_of

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'ui-v2', 'source', 'ui-kit-source.webp')
OUT = os.path.join(ROOT, 'assets', 'ui-v2')

# ---------- What the interface needs (game pixels, style.css) ----------
BUTTON_H = (30, 38, 50)                 # button.small, button, button.big
SQUARE = (36, 28)                       # button.square, .vol button.square
ROUND = (28,)
BAR_H = (12, 8)                         # .vol .bar, .bar
K_PANEL = 0.2                           # same stone size as the 38 high buttons and the squares
PANELS = {                              # name: (width, height), None = follows the text
    'pane-left': (262, 204),            # .pane.left
    'pane-right': (265, 204),           # .pane.right
    'shop-card': (262, 82),             # #shop-card
    'shop-preview': (227, 282),         # #shop-preview (top 30, bottom 8 of a 320 high scene)
    'intro-pane': (361, None),          # #intro-pane
    'menu-info': (300, None),           # #menu-info
}

# ---------- Where things are in the sheet (found by the gaps in its transparency) ----------
BOXES = {
    'panel-lg': (35, 22, 876, 521), 'panel-md': (895, 22, 1506, 521),
    'btn-normal': (46, 554, 390, 733), 'btn-hover': (416, 554, 764, 733),
    'btn-pressed': (782, 554, 1117, 733), 'btn-disabled': (1139, 554, 1494, 733),
    'sq-gem': (33, 761, 217, 991), 'sq-gear': (244, 761, 427, 991), 'sq-play': (448, 761, 628, 991),
    'sq-close': (651, 761, 831, 991), 'sq-check': (851, 761, 1026, 991),
    'bar': (1085, 761, 1491, 856), 'round': (1085, 857, 1491, 991),
}
STATES = ('normal', 'hover', 'pressed', 'disabled')
ICONS = ('gem', 'gear', 'play', 'close', 'check')


# ---------- Small tools ----------
def is_green(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (g > r + 25) & (g > b + 15)


def ornament(a):
    """Turquoise gems and glyphs: never repeated nor taken apart. Only dense patches count: the
    stones also have a few bluish pixels along their edges."""
    m = (a[..., 2].astype(int) - a[..., 0].astype(int) > 45) & (a[..., 3] > 0)
    p = np.pad(m, 2).astype(int); h, w = m.shape
    n = sum(p[dy:dy + h, dx:dx + w] for dy in range(5) for dx in range(5))
    return m & (n >= 7)


def shrink(a, k):
    bg = a[..., 3] < 128
    return np.asarray(vote_shrink(Image.fromarray(a, 'RGBA'), k, palette_of(a[..., :3][~bg]), bg)).copy()


def differ(u, v):
    """How many pixels differ between two lines of pixels (colour far apart, or one see-through)."""
    u, v = u.astype(int), v.astype(int)
    sol = (u[..., 3] > 0) != (v[..., 3] > 0)
    col = (np.abs(u[..., :3] - v[..., :3]).sum(-1) > 40) & (u[..., 3] > 0) & (v[..., 3] > 0)
    return int((sol | col).sum())


def line_mode(block):
    """For each row of `block` (h, n, 4), its most frequent colour: a line with no joint, no leaf."""
    out = np.zeros((block.shape[0], 4), np.uint8)
    for y in range(block.shape[0]):
        vals, n = np.unique(block[y].reshape(-1, 4), axis=0, return_counts=True)
        out[y] = vals[n.argmax()]
    return out


def body_box(a):
    """The stone body of an element (rows and columns mostly made of non-green opaque pixels)."""
    st = (a[..., 3] > 128) & ~is_green(a)
    rs, cs = st.sum(1), st.sum(0)
    r = np.nonzero(rs > 0.5 * rs.max())[0]; c = np.nonzero(cs > 0.5 * cs.max())[0]
    return r[0], r[-1] + 1, c[0], c[-1] + 1


def aligned(crops, both):
    """Same-size canvases for several elements, lined up on the centre of their stone body, so that
    states or icons never jump from one picture to the next."""
    info = []
    for a in crops:
        y0, y1, x0, x1 = body_box(a); op = a[..., 3] > 128
        ys, xs = np.nonzero(op.any(1))[0], np.nonzero(op.any(0))[0]
        cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
        info.append((cy, cx, cy - ys[0], ys[-1] + 1 - cy, cx - xs[0], xs[-1] + 1 - cx))
    up, down = max(i[2] for i in info), max(i[3] for i in info)
    left, right = max(i[4] for i in info), max(i[5] for i in info)
    if both:                                   # square canvas, body in the middle
        half = max(up, down, left, right); up = down = left = right = half
    out = []
    for a, (cy, cx, *_r) in zip(crops, info):
        p = np.pad(a, ((up + down, up + down), (left + right, left + right), (0, 0)))
        oy, ox = cy + up + down, cx + left + right
        if both: out.append(p[oy - up:oy + down, ox - left:ox + right])
        else:
            xs = np.nonzero((a[..., 3] > 128).any(0))[0]
            out.append(p[oy - up:oy + down, xs[0] + left + right:xs[-1] + 1 + left + right])
    return out


def wipe_middle(a, frac_x=(0.22, 0.78), frac_y=(0.30, 0.72), pad=10, side_w=12):
    """Finds what stands out from the face in the middle of a button (a word, an icon) and refills
    each of its rows with the median colour of the face just left and right of it."""
    a = a.copy(); h, w = a.shape[:2]
    y0, y1 = int(h * frac_y[0]), int(h * frac_y[1]); x0, x1 = int(w * frac_x[0]), int(w * frac_x[1])
    zone = a[y0:y1, x0:x1, :3].astype(int)
    face = np.median(zone.reshape(-1, 3), axis=0)
    ys, xs = np.nonzero(np.abs(zone - face).sum(2) > 45)
    if not len(ys): return a
    by0, by1 = max(y0, y0 + ys.min() - pad), min(y1, y0 + ys.max() + 1 + pad)
    bx0, bx1 = max(x0 + side_w, x0 + xs.min() - pad), min(x1 - side_w, x0 + xs.max() + 1 + pad)
    for y in range(by0, by1):
        side = np.concatenate([a[y, bx0 - side_w:bx0, :3], a[y, bx1:bx1 + side_w, :3]]).astype(int)
        a[y, bx0:bx1, :3] = np.median(side, axis=0).astype(np.uint8)
    return a


# ---------- Three parts with a plain middle (buttons, bars) ----------
def cut_caps(b, tol=2):
    """Where the left and right ends can be cut: the first spot, past the ornament, where two
    columns in a row already look like the plain middle."""
    h, w = b.shape[:2]
    plain = line_mode(b[:, int(w * .35):int(w * .65)])
    d = [differ(b[:, c], plain) for c in range(w)]
    lo, hi = max(3, int(w * .10)), int(w * .5)
    def first(test):
        for c in range(lo, hi):
            if test(c): return c
        return min(range(lo, hi), key=lambda c: test.cost(c))
    left = next((c for c in range(lo, hi) if d[c - 1] <= tol and d[c - 2] <= tol),
                min(range(lo, hi), key=lambda c: d[c - 1] + d[c - 2]))
    right = next((k for k in range(lo, hi) if d[w - k] <= tol and d[w - k + 1] <= tol),
                 min(range(lo, hi), key=lambda k: d[w - k] + d[w - k + 1]))
    return plain, left, right


def three_parts(b, plain, capl, capr, wl, wr, mid=4):
    """Left end (padded with plain columns up to wl), `mid` plain columns, right end (up to wr)."""
    w = b.shape[1]; col = plain[:, None]
    L = np.concatenate([b[:, :capl], np.repeat(col, wl - capl, 1)], 1)
    R = np.concatenate([np.repeat(col, wr - capr, 1), b[:, w - capr:]], 1)
    return np.concatenate([L, np.repeat(col, mid, 1), R], 1)


# ---------- Panels: repeat or remove plain stretches of stone ----------
def flood(allowed, seed):
    m = np.zeros_like(allowed); m[seed] = True
    while True:
        g = m.copy()
        g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
        g &= allowed
        if (g == m).all(): return m
        m = g


def split_panel(P):
    """The panel's face (flooded from its centre over face-like colours) and the four bands of its
    frame: top and bottom keep their corners and the leaves that hang inwards."""
    H, W = P.shape[:2]
    c = P[H // 2 - 5:H // 2 + 5, W // 2 - 5:W // 2 + 5, :3].reshape(-1, 3)
    face_c = np.median(c, 0)
    like = (np.abs(P[..., :3].astype(int) - face_c).sum(-1) < 75) & (P[..., 3] > 0) & ~is_green(P)
    face = flood(like, (H // 2, W // 2))
    frame = (P[..., 3] > 0) & ~face
    mid = frame[:, int(W * .2):int(W * .8)]
    T = max(r for r in range(H // 2) if mid[r].any()) + 1
    B = H - min(r for r in range(H // 2, H) if mid[r].any())
    side = frame[T:H - B]
    L = max(cc for cc in range(W // 2) if side[:, cc].any()) + 1
    R = W - min(cc for cc in range(W // 2, W) if side[:, cc].any())
    F = P.copy(); F[face] = 0
    return F, face, face_c, T, B, L, R


def face_texture(P, face):
    """The largest rectangle of the face with nothing over it."""
    ys, xs = np.nonzero(face); y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    while not face[y0:y1, x0:x1].all():
        bad = [(~face[y0, x0:x1]).sum(), (~face[y1 - 1, x0:x1]).sum(),
               (~face[y0:y1, x0]).sum(), (~face[y0:y1, x1 - 1]).sum()]
        k = int(np.argmax(bad))
        if k == 0: y0 += 1
        elif k == 1: y1 -= 1
        elif k == 2: x0 += 1
        else: x1 -= 1
    return P[y0:y1, x0:x1]


def mirror(v, n):
    v = v % (2 * n); return np.where(v < n, v, 2 * n - 1 - v)


def stretch_cols(band, bad, lo, hi, n_add, donor=None, dbad=None, tol=1):
    """The columns lo..hi-1 of `band` with n_add more (or fewer, if negative), and for each new
    column the old one it comes from (-1 for an added one). `bad` marks what must never be
    repeated nor cut (leaves, glyphs, gems, patched stone).
    Fewer: columns equal to their neighbour go, or whole runs between two look-alike columns.
    More: copies of runs of wall that start and end on look-alike columns (both joins invisible),
    spread over distinct places; if the band has none, runs borrowed from `donor`."""
    sub = band[:, lo:hi]; n = hi - lo; badc = bad[:, lo:hi].any(0)
    if n_add == 0: return sub, list(range(lo, hi))
    for t in range(tol, 6):
        clean = [c for c in plain_lines(sub, t) if not badc[c]]
        if n_add > 0 or len(clean) >= -n_add: break
    if n_add < 0:
        if len(clean) >= -n_add:               # enough columns equal to their neighbour
            drop = {clean[int(i * len(clean) / -n_add)] for i in range(-n_add)}
        else:                                  # whole runs between two look-alike columns
            drop, need = set(), -n_add
            cand = sorted((differ(sub[:, i], sub[:, j]), -(j - i), i, j) for i in clean for j in clean
                          if 1 <= j - i <= need)
            for cost, _, i, j in cand:
                run = set(range(i + 1, j + 1))
                if cost > 3 or run & drop or len(run) > need: continue
                drop |= run; need -= len(run)
                if not need: break
            if need: raise ValueError(f'cannot take {-n_add} lines out of {n}: {need} left')
        keep = [c for c in range(n) if c not in drop]
        return sub[:, keep], [lo + c for c in keep]

    def find_runs(src, srcbad):
        out = []
        for i in range(src.shape[1]):
            if srcbad[i]: continue
            for j in range(i + 8, min(src.shape[1], i + 41)):     # whole blocks, joints included
                if srcbad[j]: break
                cost = differ(src[:, i], src[:, j])
                if cost <= 1: out.append((cost, j - i, i, j))
        return out

    runs = [(c, l, sub[:, i + 1:j + 1], j, (i, j)) for c, l, i, j in find_runs(sub, badc)]
    if donor is not None and not runs:         # nothing to repeat here: borrow from the other side
        spots = [p for p in range(n - 1) if not badc[p] and not badc[p + 1]
                 and differ(sub[:, p], sub[:, p + 1]) <= 2]
        for c, l, i, j in find_runs(donor, dbad.any(0)):
            for p in spots:
                cost = max(differ(sub[:, p], donor[:, i]), differ(sub[:, p], donor[:, j]))
                if cost <= 2: runs.append((cost, l, donor[:, i + 1:j + 1], p, None))
    runs.sort(key=lambda r: (r[0], -r[1]))
    chosen, used, spots_used = [], set(), set()
    for r in runs:                             # distinct places, no overlap
        span = set(range(r[4][0], r[4][1] + 1)) if r[4] else {r[3]}
        if span & used or r[3] in spots_used: continue
        chosen.append(r); used |= span; spots_used.add(r[3])
    after, left, k = {}, n_add, 0
    chosen.sort(key=lambda r: r[3])
    while chosen and left >= min(r[1] for r in chosen):
        r = chosen[k % len(chosen)]; k += 1
        if r[1] > left: continue
        after.setdefault(r[3], []).append(r[2]); left -= r[1]
    if left > 0:                               # the last few: single plain columns, spread out
        pool = clean or [c for c in range(n) if not badc[c]] or list(range(n))
        for i in range(left):
            c = pool[int((i + .5) * len(pool) / left)]
            after.setdefault(c, []).append(sub[:, c:c + 1])
    out, src = [], []
    for c in range(n):
        out.append(sub[:, c:c + 1]); src.append(lo + c)
        for piece in after.get(c, []):
            out.append(piece); src.extend([-1] * piece.shape[1])
    res = np.concatenate(out, 1)
    assert res.shape[1] == n + n_add
    return res, src


def resize_band(band, bad, target, lo, hi, split, donor=None, dbad=None):
    """Brings `band` (rows, columns) to `target` columns, keeping 0..lo and hi.. untouched, half
    of the change on each side of `split` (the ornament in the middle stays in the middle).
    Returns the band and, for each old column, where it now is."""
    n = band.shape[1]; add = target - n; a1 = add // 2; a2 = add - a1
    m1, s1 = stretch_cols(band, bad, lo, split, a1, donor, dbad)
    m2, s2 = stretch_cols(band, bad, split, hi, a2, donor, dbad)
    out = np.concatenate([band[:, :lo], m1, m2, band[:, hi:]], 1)
    src = list(range(lo)) + s1 + s2 + list(range(hi, n))
    assert out.shape[1] == target, (out.shape[1], target)
    where, last = np.zeros(n, int), 0
    pos = {s: k for k, s in enumerate(src) if s >= 0}
    for x in range(n):                          # a removed column: where its neighbour went
        last = pos.get(x, last); where[x] = last
    return out, where


def dilate(m):
    g = m.copy(); g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
    return g


def components(m):
    """Connected patches of a mask (8 neighbours), as (ys, xs)."""
    m = m.copy(); out = []
    while m.any():
        y, x = map(int, np.argwhere(m)[0]); c = np.zeros_like(m); c[y, x] = True
        while True:
            g = dilate(c); g[1:, 1:] |= c[:-1, :-1]; g[:-1, :-1] |= c[1:, 1:]
            g[1:, :-1] |= c[:-1, 1:]; g[:-1, 1:] |= c[1:, :-1]; g &= m
            if (g == c).all(): break
            c = g
        out.append(np.nonzero(c)); m &= ~c
    return out


def mode_colour(px):
    vals, n = np.unique(px.reshape(-1, 4), axis=0, return_counts=True)
    return vals[n.argmax()]


class Edge:
    """One side of the frame, read along its length (columns): what must stay as it is (corners,
    carved blocks around gems and glyphs) and what is bare beam between them. The bare beam is
    redrawn at any length from its own plain line and one of its own joints, a joint every block."""

    def __init__(self, band, orn):
        self.band = band; n = band.shape[1]
        ornc = orn.any(0)
        mid = [c for c in range(n // 4, 3 * n // 4) if not ornc[c]] or list(range(n))
        self.plain = line_mode(band[:, mid])
        d = np.array([differ(band[:, c], self.plain) for c in range(n)])
        like = (d <= 2) & ~ornc
        self.d, self.ornc = d, ornc
        self.segs, c = [], 0                    # ('fix'|'fill', start, end)
        while c < n:
            e = c
            while e < n and like[e] == like[c]: e += 1
            kind = 'fill' if like[c] or e - c <= 3 else 'fix'
            if self.segs and self.segs[-1][0] == kind: self.segs[-1] = (kind, self.segs[-1][1], e)
            else: self.segs.append((kind, c, e))
            c = e
        joints = []                             # short runs unlike the plain line, inside the fills
        for kind, a, b in self.segs:
            if kind != 'fill': continue
            c = a
            while c < b:
                if not like[c]:
                    e = c
                    while e < b and not like[e]: e += 1
                    if a < c and e < b: joints.append((int(d[c:e].sum()), c, e))
                    c = e
                else: c += 1
        if joints:                              # the most ordinary joint of the edge
            widths = [e - c for _, c, e in joints]; w0 = max(set(widths), key=widths.count)
            same = [(c, e) for _, c, e in joints if e - c == w0]
            c, e = min(same, key=lambda j: sum(differ(band[:, j[0]:j[1]], band[:, o[0]:o[1]]) for o in same))
            self.joint = band[:, c:e]
            starts = sorted(j[1] for j in joints); gaps = [g for g in np.diff(starts) if 8 <= g <= 40]
            self.block = int(np.median(gaps)) if gaps else 18
        else:
            self.joint, self.block = None, 18

    def fill(self, n):
        cols = np.repeat(self.plain[:, None], n, 1)
        if self.joint is not None and n >= self.block + 4:
            m = max(1, round(n / self.block)); w = self.joint.shape[1]
            for i in range(1, m):
                x = round(i * n / m) - w // 2
                cols[:, x:x + w] = self.joint
        return cols

    def build(self, target, centre=False):
        """The edge at `target` columns, and where every old column went (a column of a fill
        goes with the nearer fixed block, at the same distance from it). With `centre`, the carved
        block nearest the middle (gem, motif) ends up exactly in the middle."""
        if not any(k == 'fill' for k, _, _ in self.segs):
            # nothing bare on this edge: it opens where it is plainest (no carving), and that very
            # line is what fills the gap
            n = self.band.shape[1]
            free = [c for c in range(2, n - 2) if not self.ornc[c]] or list(range(n - 1))
            c = min(free, key=lambda c: (differ(self.band[:, c], self.band[:, c + 1]), abs(c - n // 2)))
            self.segs = [('fix', 0, c), ('fill', c, c), ('fix', c, n)]
            self.plain, self.joint = self.band[:, c].copy(), None
        self.fixed_cols = np.zeros(self.band.shape[1], bool)
        for k, a, b in self.segs:
            if k == 'fix': self.fixed_cols[a:b] = True
        fixed = sum(b - a for k, a, b in self.segs if k == 'fix')
        fills = [b - a for k, a, b in self.segs if k == 'fill']
        room = target - fixed
        if room < 0: raise ValueError('edge too short for its carved blocks')
        def share(lengths, room):
            tot = sum(lengths)
            new = [f * room / tot for f in lengths] if tot else [room / len(lengths)] * len(lengths)
            got = [int(v) for v in new]
            for i in sorted(range(len(new)), key=lambda i: new[i] - got[i], reverse=True)[:room - sum(got)]:
                got[i] += 1
            return got
        got = share(fills, room)
        n = self.band.shape[1]
        mids = [(abs((a + b) / 2 - n / 2), i) for i, (k, a, b) in enumerate(self.segs)
                if k == 'fix' and 0 < i < len(self.segs) - 1]
        if centre and mids:
            ci = min(mids)[1]; ca, cb = self.segs[ci][1:]
            before = round(target / 2 - (cb - ca) / 2)
            fix_l = sum(b - a for k, a, b in self.segs[:ci] if k == 'fix')
            fl = [b - a for k, a, b in self.segs[:ci] if k == 'fill']
            fr = [b - a for k, a, b in self.segs[ci:] if k == 'fill']
            rl = before - fix_l; rr = room - rl
            if fl and fr and rl >= 0 and rr >= 0: got = share(fl, rl) + share(fr, rr)
        parts, where, x, fi = [], np.zeros(self.band.shape[1], int), 0, 0
        for kind, a, b in self.segs:
            if kind == 'fix':
                parts.append(self.band[:, a:b]); where[a:b] = np.arange(x, x + b - a); x += b - a
            else:
                n2 = got[fi]; fi += 1; parts.append(self.fill(n2))
                for c in range(a, b):
                    where[c] = x + (c - a) if c - a < b - c else x + n2 - (b - c)
                where[a:b] = np.clip(where[a:b], x, x + max(n2 - 1, 0))
                x += n2
        out = np.concatenate(parts, 1)
        assert out.shape[1] == target
        return out, where


def build_frame(F, T, B, L, R, W2, H2):
    """The frame at W2 x H2. The leaves are lifted off first (the stone under them patched with the
    colour of its row, or of its column on the sides); each edge is redrawn at its new length
    around its corners and carved blocks; then every leaf goes back, unchanged, at the same
    distance from the corner or carved block it hangs from."""
    H, W = F.shape[:2]; op = F[..., 3] > 0
    green = is_green(F) & op
    dark = F[..., :3].astype(int).sum(-1) < 125
    V = (green | (dilate(green) & dark)) & op
    S = F.copy(); S[V] = 0
    xs_mid, ys_mid = (np.arange(W) >= L) & (np.arange(W) < W - R), (np.arange(H) >= T) & (np.arange(H) < H - B)
    for r in list(range(T)) + list(range(H - B, H)):
        keep = ~V[r, L:W - R]
        if keep.sum() and op[r, L:W - R][keep].mean() > .6:
            S[r, V[r] & xs_mid] = mode_colour(F[r, L:W - R][keep & op[r, L:W - R]])
    for c in list(range(L)) + list(range(W - R, W)):
        keep = ~V[T:H - B, c]
        if keep.sum() and op[T:H - B, c][keep].mean() > .6:
            S[V[:, c] & ys_mid, c] = mode_colour(F[T:H - B, c][keep & op[T:H - B, c]])
    orn = ornament(S)
    for _ in range(4): orn = dilate(orn)
    orn &= S[..., 3] > 0

    def tr(a): return a.transpose(1, 0, 2) if a.ndim == 3 else a.T
    top = Edge(S[:T], orn[:T]); bot = Edge(S[H - B:], orn[H - B:])
    left = Edge(tr(S[T:H - B, :L]), tr(orn[T:H - B, :L]))
    right = Edge(tr(S[T:H - B, W - R:]), tr(orn[T:H - B, W - R:]))
    for a, b in ((left, right), (right, left)):  # a side with no joint of its own borrows one
        if a.joint is None and b.joint is not None:
            j = b.joint[::-1] if b.joint.shape[0] == a.band.shape[0] else None
            if j is not None: a.joint, a.block = j, b.block
    hs = H2 - T - B
    if hs <= 0: raise ValueError('panel too short for its frame')
    t, wt = top.build(W2, True); bo, wb = bot.build(W2, True); l, wl = left.build(hs); r, wr = right.build(hs)
    out = np.zeros((H2, W2, 4), np.uint8)
    out[:T] = t; out[H2 - B:] = bo
    side = out[T:H2 - B]
    side[:, :L] = np.where(side[:, :L, 3:] > 0, side[:, :L], tr(l))
    side[:, W2 - R:] = np.where(side[:, W2 - R:, 3:] > 0, side[:, W2 - R:], tr(r))
    def shift(edge, where, coords):
        # a leaf lying on a corner or carved block moves with it; otherwise with its first pixel
        fx = edge.fixed_cols[coords]
        if fx.any():
            v, cnt = np.unique(where[coords[fx]] - coords[fx], return_counts=True); return v[cnt.argmax()]
        c0 = coords.min(); return where[c0] - c0
    leaves = []
    for ys, xs in components(V):                # each leaf back, unchanged
        if not green[ys, xs].any(): continue    # a crumb of outline cut off from its leaf
        y0, x0 = ys.min(), xs.min()
        if y0 < T: dy, dx = 0, shift(top, wt, xs)
        elif y0 >= H - B: dy, dx = H2 - H, shift(bot, wb, xs)
        else:
            m = (ys >= T) & (ys < H - B)
            if x0 < W // 2: dy, dx = shift(left, wl, ys[m] - T), 0
            else: dy, dx = shift(right, wr, ys[m] - T), W2 - W
        leaves.append((ys + dy, xs + dx, F[ys, xs]))
    return out, leaves


def put_leaves(out, leaves):
    H2, W2 = out.shape[:2]
    for ys, xs, px in leaves:
        ok = (ys >= 0) & (ys < H2) & (xs >= 0) & (xs < W2)
        out[ys[ok], xs[ok]] = px[ok]
    return out


def fill_face(out, tex=None, flat=None):
    H2, W2 = out.shape[:2]
    inside = flood(out[..., 3] == 0, (H2 // 2, W2 // 2))
    assert not (inside[0].any() or inside[-1].any() or inside[:, 0].any() or inside[:, -1].any()), 'face leaks'
    ys, xs = np.nonzero(inside)
    if tex is not None:
        th, tw = tex.shape[:2]
        ty, tx = mirror(ys - ys.min(), th), mirror(xs - xs.min(), tw)
        out[ys, xs] = tex[ty, tx]
    else:
        out[ys, xs, :3] = flat; out[ys, xs, 3] = 255
    return out


# ---------- Build ----------
def main():
    for f in glob.glob(os.path.join(OUT, '*.png')): os.remove(f)
    sheet = np.asarray(Image.open(SRC).convert('RGBA'))
    crop = {n: sheet[y0:y1, x0:x1].copy() for n, (x0, y0, x1, y1) in BOXES.items()}
    crop['btn-normal'] = wipe_middle(crop['btn-normal'], (0.16, 0.88), side_w=8)   # longest word
    for s in ('hover', 'pressed', 'disabled'):
        crop['btn-' + s] = wipe_middle(crop['btn-' + s], (0.18, 0.82))
    crop['sq-blank'] = wipe_middle(crop['sq-play'], (0.24, 0.76), (0.26, 0.72), pad=6, side_w=6)
    r = crop.pop('round'); cols = np.nonzero((r[..., 3] > 128).any(0))[0]
    cut = cols[np.argmax(np.diff(cols))] + 1
    crop['round-up'], crop['round-down'] = r[:, :cut], r[:, cut:]
    meta = {'buttons': {}, 'squares': {}, 'bars': {}, 'panels': {}}

    # text buttons: one cap width per height, for the four states
    canv = aligned([crop['btn-' + s] for s in STATES], both=False)
    for h in BUTTON_H:
        small = [shrink(c, h / c.shape[0]) for c in canv]
        cuts = [cut_caps(b) for b in small]
        cap = max(max(l, r) for _, l, r in cuts)
        for s, b, (plain, l, r) in zip(STATES, small, cuts):
            img = three_parts(b, plain, l, r, cap, cap)
            Image.fromarray(img).save(os.path.join(OUT, f'btn-{s}-{h}.png'))
        meta['buttons'][h] = {'cap': cap, 'width': img.shape[1]}
        print(f'buttons {h}: cap {cap}, picture {img.shape[1]}x{h}')

    # square buttons and round arrows, straight at their size
    names = ICONS + ('blank',)
    canv = aligned([crop['sq-' + n] for n in names], both=True)
    for S in SQUARE:
        for n, c in zip(names, canv):
            Image.fromarray(shrink(c, S / c.shape[0])).save(os.path.join(OUT, f'sq-{n}-{S}.png'))
        meta['squares'][S] = list(names)
    canv = aligned([crop['round-up'], crop['round-down']], both=True)
    for S in ROUND:
        for n, c in zip(('up', 'down'), canv):
            Image.fromarray(shrink(c, S / c.shape[0])).save(os.path.join(OUT, f'round-{n}-{S}.png'))
    print('squares', SQUARE, 'round', ROUND)

    # bars: the gem end and the far end differ, so their caps may differ too
    b0 = crop['bar']; ys = np.nonzero((b0[..., 3] > 128).any(1))[0]; b0 = b0[ys[0]:ys[-1] + 1]
    for h in BAR_H:
        b = shrink(b0, h / b0.shape[0]); plain, l, r = cut_caps(b)
        img = three_parts(b, plain, l, r, l, r)
        trough = [int(y) for y in np.nonzero(np.abs(plain[:, :3].astype(int) - plain[h // 2, :3]).sum(-1) < 30)[0]]
        Image.fromarray(img).save(os.path.join(OUT, f'bar-{h}.png'))
        meta['bars'][h] = {'left': l, 'right': r, 'width': img.shape[1], 'trough_rows': [min(trough), max(trough) + 1]}
        print(f'bar {h}: caps {l}/{r}')

    # panels
    def opaque(a):
        ys, xs = np.nonzero(a[..., 3] > 128); return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    src = {n: shrink(opaque(crop[n]), K_PANEL) for n in ('panel-lg', 'panel-md')}
    parts = {n: split_panel(P) for n, P in src.items()}
    for n, P in src.items():
        F, face, fc, T, B, L, R = parts[n]
        print(f'{n}: {P.shape[1]}x{P.shape[0]}, frame top {T} bottom {B} left {L} right {R}')
    for name, (W2, H2) in PANELS.items():
        # the sheet panel that needs the least change; taking stone out is much harder than adding
        # some (leaves and glyphs leave few plain lines), so it weighs four times as much
        def change(n):
            h, w = src[n].shape[:2]
            c = (W2 - w if W2 >= w else 4 * (w - W2))
            if H2 is not None:
                c += (H2 - h if H2 >= h else 4 * (h - H2))
                if H2 <= parts[n][3] + parts[n][4] + 8: c += 1e6
            return c
        best = min(src, key=change)
        P = src[best]; F, face, fc, T, B, L, R = parts[best]
        if H2 is not None:
            fr, leaves = build_frame(F, T, B, L, R, W2, H2)
            out = fill_face(put_leaves(fr, leaves), flat=fc)
            meta['panels'][name] = {'width': W2, 'height': H2, 'from': best}
        else:                                  # height follows the text: top / plain rows / bottom
            H = P.shape[0] + 60                 # tall enough for the top and bottom leaves to part
            fr, leaves = build_frame(F, T, B, L, R, W2, H)
            full = fill_face(put_leaves(fr, leaves), flat=fc)
            # the top and bottom parts hold every leaf, so the plain rows between them have none
            leafy = np.zeros(full.shape[:2], bool)
            for ys, xs, _ in leaves:
                ok = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W2); leafy[ys[ok], xs[ok]] = True
            rows = np.nonzero(leafy.any(1))[0]
            ta = max([T] + [r + 1 for r in rows if r < H // 2]); ba = max([B] + [H - r for r in rows if r >= H // 2])
            row = line_mode(full[ta:H - ba].transpose(1, 0, 2))
            out = np.concatenate([full[:ta], np.repeat(row[None], 4, 0), full[H - ba:]], 0)
            meta['panels'][name] = {'width': W2, 'top': int(ta), 'bottom': int(ba), 'from': best}
        Image.fromarray(out).save(os.path.join(OUT, name + '.png'))
        print(f'{name}: {out.shape[1]}x{out.shape[0]} from {best}')
    json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()
