"""(0.70) A sheet of the proposals waiting for a choice, by family (A / B / C), from
../Archives/Jungle-Loop/propositions/<version>: pictures enlarged x3, pixels sharp, names written under them.
python tools/make_planche.py 0.70  ->  ../Archives/Jungle-Loop/propositions/0.70/planche.png"""
import sys
import pathlib
from PIL import Image, ImageDraw, ImageFont

ver = sys.argv[1] if len(sys.argv) > 1 else '0.70'
D = pathlib.Path(__file__).resolve().parent.parent.parent / 'Archives' / 'Jungle-Loop' / 'propositions' / ver
FAMILIES = [('Nuée de toucans', ['toucan-A1', 'toucan-B', 'toucan-C']),
            ('Pygmée en deltaplane (fonceur)', ['deltaplane-A', 'deltaplane-B', 'deltaplane-C']),
            ('Petits nénuphars volants (AF ; AM en rouge)', ['nenuphar-A', 'nenuphar-B', 'nenuphar-C']),
            ('Falaises (début ; la fin = la même retournée)', ['falaise-A', 'falaise-B', 'falaise-C']),
            ('Panneaux de record (le pseudo seul)', ['panneau-A', 'panneau-B', 'panneau-C']),
            ('Caisses de la ville', ['caisse-A', 'caisse-B', 'caisse-C']),
            ('Rhino sérieux / énervé', ['rhino-A', 'rhino-B', 'rhino-C']),
            ('Pygmées : poses (feu, rire, peur, fuite)', ['pygmees-poses'])]
font_path = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'fonts' / 'Silkscreen-Regular.ttf'
big = ImageFont.truetype(str(font_path), 22)
small = ImageFont.truetype(str(font_path), 16)
K = 3
rows = []
for title, names in FAMILIES:
    ims = [(n, Image.open(D / (n + '.png')).convert('RGBA')) for n in names if (D / (n + '.png')).exists()]
    if ims:
        rows.append((title, ims))
W = 1500
H = sum(60 + max(im.height for _, im in ims) * K + 40 for _, ims in rows) + 20
sheet = Image.new('RGBA', (W, H), (16, 22, 20, 255))
d = ImageDraw.Draw(sheet)
y = 14
for title, ims in rows:
    d.text((20, y), title.upper(), font=big, fill=(255, 211, 92))
    y += 44
    x = 20
    hmax = max(im.height for _, im in ims) * K
    for i, (n, im) in enumerate(ims):
        big_im = im.resize((im.width * K, im.height * K), Image.NEAREST)
        d.rectangle([x - 6, y - 6, x + big_im.width + 6, y + hmax + 6], fill=(29, 42, 36, 255), outline=(43, 59, 47, 255))
        sheet.alpha_composite(big_im, (x, y + hmax - big_im.height))
        d.text((x, y + hmax + 10), chr(65 + i) if len(ims) > 1 else '', font=small, fill=(201, 214, 195))
        x += big_im.width + 40
    y += hmax + 40
sheet.convert('RGB').save(D / 'planche.png')
print(D / 'planche.png', sheet.size)
