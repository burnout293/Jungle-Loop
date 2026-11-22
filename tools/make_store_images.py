# Jungle Loop — the stores' pictures, made from the game's own (0.48).
#
#   python tools/make_store_images.py <dossier des captures> [<autre dossier> ...]
#
# The captures are the ones the picture tours take (Godot --path . -- --bac --test --tour48 --shots=<dir>, and
# --tour47): the forest without any interface (48-m02-menu-bare.png), a run (48-m04-run-bare.png) and the
# screens shown as screenshots. Out: store/images/ (Play, Steam, the screenshots) and assets/store/ (the
# Android launcher icons, which the Android export takes).
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'store', 'images')
ICONS = os.path.join(ROOT, 'assets', 'store')
IMG = os.path.join(ROOT, 'assets', 'img')
FONT = os.path.join(ROOT, 'assets', 'fonts', 'Silkscreen-Bold.ttf')
BG = (10, 15, 20)
SHOTS = [  # (what, the capture's name): the order they are shown in the stores
    ('accueil', '48-m01-menu.png'), ('course', '47-11-shield.png'), ('panneau', '48-08-panneau-ami.png'),
    ('fantomes', '48-10-fantomes.png'), ('course-a-4', '48-05-course-salon.png'), ('amis', '48-02-amis-fiche.png'),
    ('tresor', '47-04-urn-legendary.png'), ('tambours', '47-19-drums-play.png'), ('skins', '47-06-skin-pepito.png'),
    ('evasion', '47-15-escape.png'),
]

def find(name, dirs):
    for d in dirs:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
    return None

def cover(im, w, h, scale=None):
    """The picture scaled (pixel by pixel when it grows by a whole number) to cover w x h, centred."""
    k = scale or max(w / im.width, h / im.height)
    nw, nh = round(im.width * k), round(im.height * k)
    big = im.resize((nw, nh), Image.NEAREST if k >= 1 else Image.LANCZOS)
    x, y = (nw - w) // 2, (nh - h) // 2
    return big.crop((x, y, x + w, y + h))

def title(width):
    """The stone plaque of the title with « JUNGLE LOOP » on it, `width` pixels wide, on transparency."""
    plaque = Image.open(os.path.join(IMG, 'ui-title.png')).convert('RGBA')
    k = max(1, round(width / plaque.width))
    p = plaque.resize((plaque.width * k, plaque.height * k), Image.NEAREST)
    d = ImageDraw.Draw(p)
    size = 29 * k
    f = ImageFont.truetype(FONT, size)
    text = 'JUNGLE LOOP'
    tw = sum(d.textlength(c, font=f) for c in text)
    x = (p.width - tw) / 2
    y = (p.height - size) / 2 - 3 * k
    for i, c in enumerate(text):
        col = (255, 233, 160) if i % 2 == 0 else (255, 211, 92)
        for dx, dy in [(-k, 0), (k, 0), (0, -k), (0, k)]:
            d.text((x + dx, y + dy + 2 * k), c, font=f, fill=(26, 16, 36))
        d.text((x, y + 2 * k), c, font=f, fill=(184, 128, 28))
        d.text((x, y), c, font=f, fill=col)
        x += d.textlength(c, font=f)
    if p.width != width:
        p = p.resize((width, round(p.height * width / p.width)), Image.NEAREST if width > p.width else Image.LANCZOS)
    return p

def shade(im, k=0.55):
    dark = Image.new('RGB', im.size, BG)
    return Image.blend(im.convert('RGB'), dark, k)

def put_title(im, width, y=None):
    t = title(width)
    im = im.convert('RGBA')
    im.alpha_composite(t, ((im.width - t.width) // 2, (im.height - t.height) // 2 if y is None else y))
    return im.convert('RGB')

def main():
    dirs = sys.argv[1:]
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(ICONS, exist_ok=True)
    forest = Image.open(find('48-m02-menu-bare.png', dirs)).convert('RGB')
    run = Image.open(find('48-m04-run-bare.png', dirs)).convert('RGB')
    made = []
    def save(im, name):
        im.save(os.path.join(OUT, name))
        made.append(name)
    # Steam capsules and the Play banner: the run behind, the title over it
    save(put_title(cover(run, 920, 430), 560, 40), 'steam-entete-920x430.png')
    save(put_title(shade(cover(forest, 462, 174), 0.35), 400), 'steam-petite-462x174.png')
    save(put_title(cover(run, 1232, 706), 750, 60), 'steam-principale-1232x706.png')
    save(put_title(cover(forest, 748, 896), 660, 70), 'steam-verticale-748x896.png')
    save(put_title(cover(forest, 600, 900), 540, 80), 'steam-bibliotheque-600x900.png')
    save(cover(forest, 3840, 1240, scale=3.0), 'steam-heros-3840x1240.png')
    logo = Image.new('RGBA', (1280, 720), (0, 0, 0, 0))
    t = title(1000)
    logo.alpha_composite(t, ((1280 - t.width) // 2, (720 - t.height) // 2))
    logo.save(os.path.join(OUT, 'steam-logo-1280x720.png'))
    made.append('steam-logo-1280x720.png')
    save(put_title(cover(run, 1024, 500), 620, 50), 'play-presentation-1024x500.png')
    # the icon: the game's own (assets/pwa), and Android's launcher icons from it
    icon = Image.open(os.path.join(ROOT, 'assets', 'pwa', 'icon-512.png')).convert('RGBA')
    icon.save(os.path.join(OUT, 'play-icone-512.png'))
    made.append('play-icone-512.png')
    icon.resize((192, 192), Image.LANCZOS).save(os.path.join(ICONS, 'android-192.png'))
    fg = Image.new('RGBA', (432, 432), (0, 0, 0, 0))                  # (the middle 66 % is always shown)
    small = icon.resize((288, 288), Image.LANCZOS)
    fg.alpha_composite(small, (72, 72))
    fg.save(os.path.join(ICONS, 'android-avant-432.png'))
    corner = icon.getpixel((4, 4))
    Image.new('RGBA', (432, 432), corner if corner[3] > 0 else BG + (255,)).save(os.path.join(ICONS, 'android-fond-432.png'))
    # the screenshots
    n = 0
    for what, name in SHOTS:
        p = find(name, dirs)
        if p is None:
            continue
        n += 1
        Image.open(p).convert('RGB').resize((1280, 720), Image.LANCZOS).save(os.path.join(OUT, 'capture-%02d-%s.png' % (n, what)))
        made.append('capture-%02d-%s.png' % (n, what))
    print('%d images dans store/images, 3 icônes Android dans assets/store' % len(made))

if __name__ == '__main__':
    main()
