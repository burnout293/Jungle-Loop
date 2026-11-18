"""The UI kit v2 for the Godot version: assets/img/ui-v2/.

The kit is made in the web repository (Jungle-Loop: tools/import_ui_v2.py, assets/ui-v2/) at the exact
sizes of its interface, so that nothing is ever stretched or cut. This script copies it here, then makes
the few panels whose size differs in the Godot version, with the very same functions (assembled at their
size from the sheet's panel, no pixel resized):
    settings-left 262 x 262, settings-right 265 x 262   (Réglages: taller panes, nothing under them)
    shop-preview-wide 253 x 282                         (the shop as a list: the preview is wider)

    python tools/import_ui_v2_godot.py [path of the Jungle-Loop repository]
"""
import os, sys, json, glob, shutil

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(HERE), 'Jungle-Loop')
sys.path.insert(0, os.path.join(WEB, 'tools'))
import numpy as np
from PIL import Image
import import_ui_v2 as K

OUT = os.path.join(HERE, 'assets', 'img', 'ui-v2')
PANELS = {
    'settings-left': (262, 262),
    'settings-right': (265, 262),
    'shop-preview-wide': (253, 282),
}


def opaque(a):
    ys, xs = np.nonzero(a[..., 3] > 128)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, '*.png')):
        os.remove(f)
    src_dir = os.path.join(WEB, 'assets', 'ui-v2')
    for f in glob.glob(os.path.join(src_dir, '*.png')) + [os.path.join(src_dir, 'meta.json')]:
        shutil.copy(f, OUT)
    meta = json.load(open(os.path.join(OUT, 'meta.json')))
    sheet = np.asarray(Image.open(K.SRC).convert('RGBA'))
    crop = {n: sheet[y0:y1, x0:x1].copy() for n, (x0, y0, x1, y1) in K.BOXES.items() if n.startswith('panel')}
    src = {n: K.shrink(opaque(crop[n]), K.K_PANEL) for n in ('panel-lg', 'panel-md')}
    parts = {n: K.split_panel(P) for n, P in src.items()}
    for name, (W2, H2) in PANELS.items():
        def change(n):                          # as in import_ui_v2.py: the sheet panel needing least change
            h, w = src[n].shape[:2]
            c = (W2 - w if W2 >= w else 4 * (w - W2)) + (H2 - h if H2 >= h else 4 * (h - H2))
            if H2 <= parts[n][3] + parts[n][4] + 8:
                c += 1e6
            return c
        best = min(src, key=change)
        F, face, fc, T, B, L, R = parts[best]
        fr, leaves = K.build_frame(F, T, B, L, R, W2, H2)
        out = K.fill_face(K.put_leaves(fr, leaves), flat=fc)
        Image.fromarray(out).save(os.path.join(OUT, name + '.png'))
        meta['panels'][name] = {'width': W2, 'height': H2, 'from': best, 'godot': True}
        print(f'{name}: {out.shape[1]}x{out.shape[0]} from {best}')
    json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
    print('copied and made:', len(glob.glob(os.path.join(OUT, '*.png'))), 'pictures in', OUT)


if __name__ == '__main__':
    main()
