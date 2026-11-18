# Shop buttons of the Godot version, from the UI kit v2 sheet, at the exact sizes of its list layout
# (game pixels). Nothing is stretched nor cut: each picture is drawn at its very size.
#   - back button 54 x 36 and category tabs 54 x 64: the kit's text button made exactly 54 wide, then
#     lengthened in height by identical rows (its plain middle row), corners and leaves kept whole;
#   - item rows 236 x 30: the 30 high button (whole caps, plain middle columns), with a sunken frame
#     for the item's picture, 26 x 24, 5 px from the left edge, centred in height.
# States: normal, hover, pressed / selected (the kit's pressed button: no gold in the kit).
#   python tools/import_shop_v2.py      -> assets/ui-v2/shop/*.png + meta.json
import os, sys, json, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
import import_ui_v2 as U

OUT = os.path.join(U.OUT, 'shop')
BACK = (54, 36)
TAB = (54, 64)
ITEM = (236, 30)
SLOT = {'x': 5, 'y': 3, 'w': 26, 'h': 24}
STATES = {'normal': 'normal', 'hover': 'hover', 'pressed': 'pressed'}      # file state: kit state
TAB_STATES = {'normal': 'normal', 'hover': 'hover', 'selected': 'pressed'}


def tr(a): return a.transpose(1, 0, 2)


def taller(b, H):
    """`b` brought to H rows: top and bottom kept whole, its plain middle row repeated between."""
    bt = tr(b)
    plain, top, bottom = U.cut_caps(bt)
    if top + bottom > H: raise ValueError(f'{H} rows is less than its top and bottom ({top} + {bottom})')
    return tr(U.three_parts(bt, plain, top, bottom, top, bottom, mid=H - top - bottom)), top, bottom


def face_box(a):
    """The plain face inside the frame: from the centre, how far the face colour goes on each side."""
    H, W = a.shape[:2]; c = a[H // 2, W // 2].astype(int)
    same = lambda p: np.abs(p.astype(int) - c).sum(-1) <= 30
    row, col = same(a[H // 2]), same(a[:, W // 2])
    l = W // 2
    while l > 0 and row[l - 1]: l -= 1
    r = W // 2
    while r < W - 1 and row[r + 1]: r += 1
    t = H // 2
    while t > 0 and col[t - 1]: t -= 1
    b = H // 2
    while b < H - 1 and col[b + 1]: b += 1
    return {'left': int(l), 'right': int(W - 1 - r), 'top': int(t), 'bottom': int(H - 1 - b)}


def sunken_slot(a, deep, light):
    """A frame sunk into the stone for the item's picture: dark rim, shadow on its top and left
    inner edges, stone light on its bottom and right ones, a deep face. The leaves that grew over
    its rim are put back on top, so it looks carved into the button, not pasted on it."""
    x, y, w, h = SLOT['x'], SLOT['y'], SLOT['w'], SLOT['h']
    before = a.copy()
    dark = min((tuple(p) for p in a.reshape(-1, 4) if p[3] > 0), key=lambda p: int(p[0]) + int(p[1]) + int(p[2]))
    a[y:y + h, x:x + w] = deep
    a[y, x:x + w] = dark; a[y + h - 1, x:x + w] = dark; a[y:y + h, x] = dark; a[y:y + h, x + w - 1] = dark
    a[y + 1, x + 1:x + w - 1] = dark; a[y + 1:y + h - 1, x + 1] = dark            # shadow under the rim
    a[y + h - 2, x + 2:x + w - 1] = light; a[y + 2:y + h - 1, x + w - 2] = light  # lit far edges
    ring = np.zeros(a.shape[:2], bool); ring[y:y + h, x:x + w] = True; ring[y + 2:y + h - 2, x + 2:x + w - 2] = False
    leaf = ring & U.is_green(before) & (before[..., 3] > 0)
    a[leaf] = before[leaf]
    return a


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, '*.png')): os.remove(f)
    crop = U.load_crops()
    meta = {'back': {}, 'tab': {}, 'item': {'slot': SLOT}}
    canv = dict(zip(U.STATES, U.aligned([crop['btn-' + s] for s in U.STATES], both=False)))

    # back button and tabs: the button made exactly 54 wide, then taller by identical rows
    for kind, (W, H), states in (('back', BACK, STATES), ('tab', TAB, TAB_STATES)):
        for name, kit in states.items():
            c = canv[kit]; b = U.shrink(c, W / c.shape[1])
            assert b.shape[1] == W, b.shape
            img, top, bottom = taller(b, H)
            Image.fromarray(img).save(os.path.join(OUT, f'{kind}-{name}.png'))
            meta[kind][name] = {'top': top, 'bottom': bottom, 'face': face_box(img)}
            print(f'{kind}-{name}: {img.shape[1]}x{img.shape[0]}, top {top}, bottom {bottom}, face {face_box(img)}')

    # item rows: the 30 high button, whole caps, plain middle, a sunken frame for the picture
    W, H = ITEM
    deep = None
    small = {s: U.shrink(c, H / c.shape[0]) for s, c in canv.items()}
    cuts = {s: U.cut_caps(b) for s, b in small.items()}
    cap = max(max(l, r) for _, l, r in cuts.values())
    p = small['pressed']; deep = p[H // 2, p.shape[1] // 2].copy()   # the darkest face of the kit
    for name, kit in TAB_STATES.items():
        b = small[kit]; plain, l, r = cuts[kit]
        img = U.three_parts(b, plain, l, r, cap, cap, mid=W - 2 * cap)
        light = plain[H - 5]                    # the stone of the bottom band, a mid tone
        img = sunken_slot(img.copy(), deep, light)
        Image.fromarray(img).save(os.path.join(OUT, f'item-{name}.png'))
        meta['item'][name] = {'cap': cap, 'face': face_box(img)}
        print(f'item-{name}: {img.shape[1]}x{img.shape[0]}, caps {cap}, face {face_box(img)}')
    json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()
