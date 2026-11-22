"""Puts the web export on the site: copies export/web/* into ../Jungle-Loop (the GitHub Pages repository)
and writes version.txt beside it, the version of scripts/main.gd, and copies reglages/nouveautes.txt (what
the window offering the update says, 0.49.1). The game reads version.txt for
« Mettre à jour » (Réglages) and for the « ! » on the gear when a newer version is online.

    python tools/publish_web.py          (after the export, see README « Export »)

It stops if the export is older than the scripts (a forgotten export would publish the old game under the
new number).
"""
import pathlib
import re
import shutil
import sys

here = pathlib.Path(__file__).resolve().parent.parent
site = here.parent / 'Jungle-Loop'
web = here / 'export' / 'web'

version = re.search(r'const VERSION := "([\d.]+)"', (here / 'scripts' / 'main.gd').read_text(encoding='utf-8')).group(1)
pck = web / 'index.pck'
newest_script = max(p.stat().st_mtime for p in (here / 'scripts').glob('*.gd'))
if not pck.exists() or pck.stat().st_mtime < newest_script:
    sys.exit('export/web/index.pck est plus ancien que les scripts : refais l\'export d\'abord.')
if not (site / '.git').exists():
    sys.exit(f'Pas de dépôt du site ici : {site}')

for f in web.iterdir():
    if f.is_file():
        shutil.copy2(f, site / f.name)
(site / 'version.txt').write_text(version + '\n', encoding='utf-8', newline='\n')
notes = here / 'reglages' / 'nouveautes.txt'           # 0.49.1: shown in the window that offers the update
if notes.exists():
    shutil.copy2(notes, site / 'nouveautes.txt')
print(f'{version} copiée dans {site} (version.txt et nouveautes.txt écrits)')
