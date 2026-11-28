"""(0.72) The game's animation strips, from the frames PixelLab drew (assets/src/anim/<name>/f0.png, f1.png, ...).
Each strip is the frames side by side, all cropped to the box that holds every one of them (so nothing jumps),
maybe mirrored (facing left: the way the dangers come) and recoloured (a hue range turned to another hue).
Run from the game's folder:   python tools/make_anim.py            (every strip of STRIPS)
                              python tools/make_anim.py sky-toucan (only those named)
The strips go to assets/img/<out>.png; render.gd / art.gd know their frame counts (HAZ_FRAMES, ...)."""
import colorsys
import pathlib
import sys
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent.parent
SRC = HERE / 'assets' / 'src' / 'anim'
OUT = HERE / 'assets' / 'img'

# out: the strip's name; src: the folder of frames; frames: which (in order); mirror: flipped left-right;
# hues: [(lo, hi, to, s, v)] a pixel whose hue (degrees) is in lo..hi (and is colourful) turns to `to`,
# its saturation and brightness multiplied by s and v; pad: transparent pixels kept round the box.
RHINO_BOX = (3, 6, 90, 66)          # (0.72) one box for the three rhinos: no jump from one to the other
STRIPS = [
    {'out': 'sky-toucan', 'src': 'toucan', 'frames': range(8), 'mirror': True},
    # the little flying lily pads (AF violet, AM red: 0.72, the user's choice « C, en violet / rouge »)
    {'out': 'sky-lily', 'src': 'lily', 'frames': range(8),
     'hues': [(130, 215, 274, 1.1, 1.02), (60, 129, 300, 0.8, 1.0), (250, 310, 318, 1.05, 1.2)]},
    {'out': 'sky-lily-am', 'src': 'lily', 'frames': range(8),
     'hues': [(130, 215, 356, 1.4, 1.15), (60, 129, 22, 1.0, 1.05), (250, 310, 335, 1.1, 1.15)]},
    {'out': 'rocket', 'src': 'rocket', 'frames': range(6)},
    # the home's rhino (0.72, « rhino B »): running, snorting, walking off; erase: the pale thread left at its
    # nostrils by the puff taken off its picture (x from, y from, at most this saturated, at least this bright)
    {'out': 'scene-rhino-run', 'src': 'rhino-run', 'frames': range(8), 'box': RHINO_BOX, 'erase': (76, 36, 0.16, 0.5)},
    {'out': 'scene-rhino-snort', 'src': 'rhino-snort', 'frames': range(9), 'box': RHINO_BOX},          # (played once: it ends baring its teeth)
    {'out': 'scene-rhino-walk', 'src': 'rhino-walk', 'frames': range(8), 'box': RHINO_BOX, 'erase': (76, 36, 0.16, 0.5)},
]


def turn(im, hues):
    if not hues:
        return im
    im = im.copy()
    px = im.load()
    memo = {}
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            key = p[:3]
            if key not in memo:
                h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in key))
                out = key
                for lo, hi, to, ks, kv in hues:
                    if lo <= h * 360 <= hi and s >= 0.12 and v >= 0.08:
                        r, g, b = colorsys.hsv_to_rgb((to + (h * 360 - (lo + hi) / 2) * 0.35) % 360 / 360, min(1, s * ks), min(1, v * kv))
                        out = (round(r * 255), round(g * 255), round(b * 255))
                        break
                memo[key] = out
            px[x, y] = memo[key] + (p[3],)
    return im


def build(spec):
    folder = SRC / spec['src']
    frames = [Image.open(folder / f'f{i}.png').convert('RGBA') for i in spec['frames']]
    if spec.get('erase'):
        x0, y0, s_max, v_min = spec['erase']
        for im in frames:
            px = im.load()
            for y in range(y0, im.height):
                for x in range(x0, im.width):
                    p = px[x, y]
                    if p[3]:
                        h, sat, v = colorsys.rgb_to_hsv(*(c / 255 for c in p[:3]))
                        if sat <= s_max and v >= v_min:
                            px[x, y] = (0, 0, 0, 0)
    # the alpha is clean: PixelLab leaves a few nearly clear pixels, gone
    for im in frames:
        a = im.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
        im.putalpha(a)
    box = None
    for im in frames:
        b = im.getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    pad = spec.get('pad', 1)
    box = (max(0, box[0] - pad), max(0, box[1] - pad), min(frames[0].width, box[2] + pad), min(frames[0].height, box[3] + pad))
    if spec.get('box'):
        box = spec['box']
    w, h = box[2] - box[0], box[3] - box[1]
    strip = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        cut = turn(im.crop(box), spec.get('hues'))
        if spec.get('mirror'):
            cut = cut.transpose(Image.FLIP_LEFT_RIGHT)
        strip.alpha_composite(cut, (i * w, 0))
    strip.save(OUT / (spec['out'] + '.png'))
    print(spec['out'], f'{len(frames)} x {w}x{h}', 'box', box)


def crates():
    """The city's crates (0.72, the user's choice « caisse A »): one crate (city-crate-a), what lights up on it
    (city-crate-a-lit: its cyan glyph made bright and a halo of cyan on the wood round it; render.gd fades it in
    and out over the crate), and three of them in a heap (city-crates: Art.decor's picture, its quarters the
    pieces that fly when it is smashed)."""
    src = Image.open(SRC / 'crate' / 'f0.png').convert('RGBA')
    box = src.getbbox()
    one = src.crop((box[0] - 1, box[1] - 1, box[2] + 1, box[3] + 1))
    one.save(OUT / 'city-crate-a.png')
    lit = Image.new('RGBA', one.size, (0, 0, 0, 0))
    px, lp = one.load(), lit.load()
    glyph = set()
    for y in range(one.height):
        for x in range(one.width):
            p = px[x, y]
            if p[3]:
                h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in p[:3]))
                if 0.42 < h < 0.56 and s > 0.35 and v > 0.5:
                    glyph.add((x, y))
                    lp[x, y] = (200, 255, 251, 255) if v > 0.8 else (90, 240, 236, 255)
    for x, y in list(glyph):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in glyph and 0 <= q[0] < one.width and 0 <= q[1] < one.height and px[q][3]:
                p = px[q]
                lp[q] = (round(p[0] * 0.55 + 60 * 0.45), round(p[1] * 0.55 + 230 * 0.45), round(p[2] * 0.55 + 225 * 0.45), 255)
    lit.save(OUT / 'city-crate-a-lit.png')
    w, h = one.size
    heap = Image.new('RGBA', (2 * w - 1, 2 * h - 2), (0, 0, 0, 0))
    heap.alpha_composite(one, (0, h - 2))
    heap.alpha_composite(one, (w - 1, h - 2))
    heap.alpha_composite(one, ((w - 1) // 2 + 2, 0))
    heap.save(OUT / 'city-crates.png')
    print('city-crate-a', one.size, 'glyph', len(glyph), 'city-crates', heap.size)


def cliff():
    """The forest's cliff over the heights' mist (0.72, « falaise A »), its vines swaying, drops falling, its clouds
    rolling: PixelLab's frames 1-8 (its first one is the picture as it was, drawn a little differently: left out),
    played there and back by render.gd. Each one 24 rows longer (its last rows again, upside down: to the bottom
    of the screen) and its left side fading out in a checker (it meets the forest's floor)."""
    frames = [Image.open(SRC / 'cliff' / f'f{i}.png').convert('RGBA') for i in range(1, 9)]
    w, h = frames[0].size
    strip = Image.new('RGBA', (w * len(frames), h + 24), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        a = im.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
        im.putalpha(a)
        tall = Image.new('RGBA', (w, h + 24), (0, 0, 0, 0))
        tall.alpha_composite(im, (0, 0))
        tall.alpha_composite(im.crop((0, h - 24, w, h)).transpose(Image.FLIP_TOP_BOTTOM), (0, h))
        px = tall.load()
        for y in range(18, h + 24):
            for x in range(14, 24):
                k = (x - 14) / 10                  # 0 at its left side .. 1 inside
                if px[x, y][3] and ((x + y) % 2 == 0 and k < 0.6 or (x + y) % 4 == 1 and k < 0.3 or k < 0.1):
                    px[x, y] = (0, 0, 0, 0)
        strip.alpha_composite(tall, (i * w, 0))
    strip.save(OUT / 'cliff-a.png')
    print('cliff-a', len(frames), 'x', (w, h + 24))


def sign_board():
    """The record signs' board (0.72, « panneau B »): two of its three planks (the top one, its moss and nail; the
    bottom one, its nail), 64 x 27; render.gd stretches it by its middle (columns SIGN_CAP .. width - SIGN_CAP)."""
    src = Image.open(SRC / 'sign' / 'board.png').convert('RGBA')
    a = src.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
    src.putalpha(a)
    top = src.crop((0, 0, 64, 13))
    bottom = src.crop((0, 26, 64, 40))
    board = Image.new('RGBA', (64, 27), (0, 0, 0, 0))
    board.alpha_composite(top, (0, 0))
    board.alpha_composite(bottom, (0, 13))
    board.save(OUT / 'sign-board.png')
    print('sign-board', board.size)


GIFS = [('sky-toucan', 8, 70, 3), ('sky-lily', 8, 90, 4), ('sky-lily-am', 8, 90, 4), ('rocket', 6, 80, 3),
        ('scene-rhino-run', 8, 75, 2), ('scene-rhino-snort', 9, 250, 2), ('scene-rhino-walk', 8, 110, 2), ('cliff-a', 8, 200, 2)]


def gifs():
    """(0.72) Each strip as an animated GIF, bigger (its pixels sharp), on the game's dark green, for the web site's
    dev library: ../Archives/Jungle-Loop/animations/<name>.gif (build_site.py copies them). The cliff there and back."""
    out = HERE.parent / 'Archives' / 'Jungle-Loop' / 'animations'
    out.mkdir(parents=True, exist_ok=True)
    for name, n, ms, k in GIFS:
        if not (OUT / (name + '.png')).exists():
            continue
        strip = Image.open(OUT / (name + '.png')).convert('RGBA')
        fw = strip.width // n
        order = list(range(n)) + (list(range(n - 2, 0, -1)) if name == 'cliff-a' else [])
        frames = []
        for i in order:
            f = strip.crop((i * fw, 0, (i + 1) * fw, strip.height)).resize((fw * k, strip.height * k), Image.NEAREST)
            bg = Image.new('RGBA', f.size, (29, 42, 36, 255))
            bg.alpha_composite(f)
            frames.append(bg.convert('P', palette=Image.ADAPTIVE, colors=255))
        frames[0].save(out / (name + '.gif'), save_all=True, append_images=frames[1:], duration=ms, loop=0, disposal=2)
    print('gifs ->', out)


if __name__ == '__main__':
    want = sys.argv[1:]
    if want == ['gifs']:
        gifs()
        sys.exit()
    if not want or 'city-crates' in want:
        crates()
    if not want or 'sign-board' in want:
        sign_board()
    if not want or 'cliff-a' in want:
        cliff()
    for spec in STRIPS:
        if want and spec['out'] not in want:
            continue
        if not (SRC / spec['src']).is_dir():
            print(spec['out'], ': pas encore de dessins')
            continue
        build(spec)
