"""The web page of the game (0.50): html/shell.src.html with its pictures put inside it (data: addresses),
written to html/shell.html, for the Web export (export_presets.cfg html/custom_html_shell, to set).

    python html/make_shell.py      (after tools/make_loading_sprites.gd if Pépito's run has changed)
"""
import base64
import io
import pathlib

from PIL import Image

here = pathlib.Path(__file__).resolve().parent
root = here.parent
img = root / 'assets' / 'img'


def png(im, colours):
    im = im.convert('RGBA').quantize(colours, method=Image.Quantize.FASTOCTREE)
    buf = io.BytesIO()
    im.save(buf, 'PNG', optimize=True)
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode('ascii')


hero = Image.open(root / 'assets' / 'src' / 'loading' / 'hero-run.png').convert('RGBA')
box = hero.getbbox()
hero = hero.crop((0, box[1], hero.width, box[3]))
values = {
    'HERO': png(hero, 160), 'HERO_W': str(hero.width // 8), 'HERO_H': str(hero.height),
    'SPEAR': png(Image.open(img / 'guard-spear.png'), 96), 'CLUB': png(Image.open(img / 'guard-club.png'), 96),
    'GORILLA': png(Image.open(img / 'mount-gorilla.png'), 96), 'RHINO': png(Image.open(img / 'mount-rhino.png'), 96),
    'MISSILE': png(Image.open(img / 'missile.png'), 32), 'BG': png(Image.open(img / 'bg-far.png'), 48),
    'GROUND': png(Image.open(img / 'ground.png'), 64),
    'FONT': 'data:font/ttf;base64,' + base64.b64encode((root / 'assets' / 'fonts' / 'Silkscreen-Bold.ttf').read_bytes()).decode('ascii'),
}
page = (here / 'shell.src.html').read_text(encoding='utf-8')
for k, v in values.items():
    page = page.replace('{{' + k + '}}', v)
assert '{{' not in page, 'a picture is missing'
(here / 'shell.html').write_text(page, encoding='utf-8', newline='\n')
print(f'html/shell.html : {len(page) // 1024} Kio')
