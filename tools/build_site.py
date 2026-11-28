"""(0.70) Jungle Loop's web site, next to the game on GitHub Pages (the site\\ folder, branch main):
  infos.html             the portal: play, give your opinion, the changelog, the roadmap, the stores, the dev library
  journal.html           the full changelog (reglages/changements.txt)
  feuille-de-route.html  the roadmap (reglages/feuille-de-route.txt)
  dev/index.html         the dev library: every proposal, mock-up and picture of the game, by folder
  site.css               their look (retours.html, the feedback form, shares it)
Run from the game's folder:   python tools/build_site.py
The dev library copies: ../Archives/Jungle-Loop/propositions/*, ../Archives/Jungle-Loop/boss2, the game's own
pictures (assets/img, top level). Never a password file, a .psd or a text file of the archive."""
import html
import pathlib
import shutil

HERE = pathlib.Path(__file__).resolve().parent.parent
SITE = HERE / 'site'
ARCH = HERE.parent / 'Archives' / 'Jungle-Loop'
VERSION = next(l.split('"')[1] for l in (HERE / 'scripts' / 'main.gd').read_text(encoding='utf-8').splitlines() if l.startswith('const VERSION'))

CSS = '''@font-face { font-family: "Silkscreen"; src: url("fonts/Silkscreen-Regular.ttf") format("truetype"); font-display: swap; }
@font-face { font-family: "Silkscreen"; src: url("fonts/Silkscreen-Bold.ttf") format("truetype"); font-weight: 700; font-display: swap; }
:root { --bg: #0a0f14; --panel: #16201c; --panel2: #1d2a24; --ink: #fff8e6; --dim: #c9d6c3; --gold: #ffd35c;
  --leaf: #6cc22e; --relic: #5cf2e0; --edge: #2b3b2f; }
* { box-sizing: border-box; }
body { margin: 0; color: var(--ink); font: 16px/1.55 system-ui, -apple-system, "Segoe UI", sans-serif;
  background: radial-gradient(ellipse at 50% -10%, #1f3a2a 0%, var(--bg) 60%) fixed, var(--bg); min-height: 100vh; }
a { color: var(--gold); }
nav { display: flex; flex-wrap: wrap; gap: 6px; justify-content: center; padding: 12px 12px 0; }
nav a { font: 700 13px "Silkscreen", monospace; text-decoration: none; color: var(--dim); padding: 8px 10px;
  border: 2px solid #1a1024; border-radius: 6px; background: var(--panel); box-shadow: 0 0 0 1px var(--edge) inset; }
nav a.on, nav a:hover { color: #2a1a08; background: var(--gold); }
main { max-width: 860px; margin: 0 auto; padding: 22px 16px 56px; }
h1 { font: 700 30px/1.1 "Silkscreen", monospace; color: var(--gold); margin: 8px 0 6px; text-shadow: 0 3px 0 #1a1024; }
h2 { font: 700 19px "Silkscreen", monospace; color: var(--gold); margin: 30px 0 10px; }
h3 { font: 700 15px "Silkscreen", monospace; color: var(--relic); margin: 18px 0 6px; }
.sub { color: var(--dim); margin: 0 0 18px; }
.cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 12px; }
.card { display: block; text-decoration: none; color: var(--ink); background: var(--panel); border: 2px solid #1a1024;
  border-radius: 8px; padding: 14px; box-shadow: 0 0 0 2px var(--edge) inset, 0 5px 0 #05070a; }
.card b { display: block; font: 700 15px "Silkscreen", monospace; color: var(--gold); margin-bottom: 4px; }
.card:hover { transform: translateY(-2px); }
.play { display: inline-block; margin: 6px 0 4px; padding: 14px 26px; border: 2px solid #1a1024; border-radius: 8px;
  background: linear-gradient(#ffe48a, var(--gold) 55%, #d9a92c); color: #2a1a08; text-decoration: none;
  font: 700 20px "Silkscreen", monospace; box-shadow: 0 4px 0 #8a6516; }
.soon { color: var(--dim); font-size: 13px; }
ul.notes { padding-left: 20px; margin: 6px 0; } ul.notes li { margin: 3px 0; }
.ver { background: var(--panel); border: 2px solid #1a1024; border-radius: 8px; padding: 10px 16px; margin: 12px 0;
  box-shadow: 0 0 0 2px var(--edge) inset; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 10px; }
.grid a { display: flex; flex-direction: column; align-items: center; gap: 4px; text-decoration: none; color: var(--dim);
  font-size: 11px; background: var(--panel2); border-radius: 6px; padding: 8px 6px; border: 1px solid var(--edge); word-break: break-all; }
.grid img { max-width: 100%; height: 90px; object-fit: contain; image-rendering: pixelated; }
footer { color: var(--dim); font-size: 13px; text-align: center; margin-top: 30px; }
'''

NAV = [('infos.html', 'Accueil'), ('./', 'Jouer'), ('retours.html', 'Ton avis'), ('journal.html', 'Journal'),
       ('feuille-de-route.html', 'Feuille de route'), ('dev/index.html', 'Dev-library')]


def page(name, title, body, depth=0):
    up = '../' * depth
    nav = ''.join(f'<a href="{up}{h}"{" class=on" if h == name else ""}>{t}</a>' for h, t in NAV)
    return f'''<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Jungle Loop — {html.escape(title)}</title><link rel="icon" href="{up}index.icon.png"><link rel="stylesheet" href="{up}site.css"></head>
<body><nav>{nav}</nav><main>
{body}
<footer>Jungle Loop {VERSION} · <a href="{up}confidentialite.html">confidentialité</a></footer>
</main></body></html>
'''


def sections(path, opener):
    out = []
    for raw in path.read_text(encoding='utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if opener(line):
            out.append([line, []])
        elif out:
            out[-1][1].append(line)
    return out


def build():
    (SITE / 'site.css').write_text(CSS, encoding='utf-8')
    # the portal
    body = f'''<h1>Jungle Loop</h1>
<p class="sub">Une course infinie en pixel art : Pépito a volé la relique du temple, et toute la jungle lui court après.</p>
<a class="play" href="./">JOUER</a>
<h2>Le jeu</h2>
<div class="cards">
<a class="card" href="retours.html"><b>Ton avis</b>Un bug, une idée : écris-le, l'auteur le reçoit tout de suite.</a>
<a class="card" href="journal.html"><b>Journal</b>Tous les changements, version par version (aujourd'hui {VERSION}).</a>
<a class="card" href="feuille-de-route.html"><b>Feuille de route</b>Ce qui est en cours, ce qui est prévu, les idées.</a>
<a class="card" href="dev/index.html"><b>Dev-library</b>Toutes les propositions, maquettes et images du jeu.</a>
</div>
<h2>Magasins</h2>
<div class="cards">
<div class="card"><b>Steam</b><span class="soon">Bientôt.</span></div>
<div class="card"><b>Google Play</b><span class="soon">Bientôt.</span></div>
</div>'''
    (SITE / 'infos.html').write_text(page('infos.html', 'le portail', body), encoding='utf-8')
    # the changelog
    parts = sections(HERE / 'reglages' / 'changements.txt', lambda l: l.startswith('='))
    body = '<h1>Journal</h1><p class="sub">Tous les changements, la version la plus récente en premier.</p>'
    for head, lines in parts:
        items = ''.join(f'<li>{html.escape(l)}</li>' for l in lines)
        body += f'<div class="ver"><h3>Version {html.escape(head[1:].strip())}</h3><ul class="notes">{items}</ul></div>'
    (SITE / 'journal.html').write_text(page('journal.html', 'journal', body), encoding='utf-8')
    # the roadmap
    parts = sections(HERE / 'reglages' / 'feuille-de-route.txt', lambda l: l.startswith('[') and l.endswith(']'))
    body = '<h1>Feuille de route</h1><p class="sub">Où va le jeu. Tes idées comptent : <a href="retours.html">donne ton avis</a>.</p>'
    for head, lines in parts:
        items = ''.join(f'<li>{html.escape(l)}</li>' for l in lines)
        body += f'<div class="ver"><h3>{html.escape(head[1:-1])}</h3><ul class="notes">{items}</ul></div>'
    (SITE / 'feuille-de-route.html').write_text(page('feuille-de-route.html', 'feuille de route', body), encoding='utf-8')
    # the dev library
    dev = SITE / 'dev'
    galleries = []
    sources = []
    if (ARCH / 'propositions').is_dir():
        for d in sorted((ARCH / 'propositions').iterdir(), reverse=True):
            if d.is_dir():
                sources.append((f'Propositions {d.name}', d, f'propositions/{d.name}'))
    if (ARCH / 'boss2').is_dir():
        sources.append(("L'Aigle (boss 2) : ébauches", ARCH / 'boss2', 'boss2'))
    sources.append(('Images du jeu (assets/img)', HERE / 'assets' / 'img', 'assets'))
    for title, src, rel in sources:
        files = [f for f in sorted(src.iterdir()) if f.is_file() and f.suffix.lower() in ('.png', '.gif', '.jpg', '.html')
                 and 'mot-de-passe' not in f.name]
        if not files:
            continue
        out = dev / rel
        out.mkdir(parents=True, exist_ok=True)
        cells = ''
        for f in files:
            if not (out / f.name).exists() or (out / f.name).stat().st_size != f.stat().st_size:
                shutil.copy2(f, out / f.name)
            name = html.escape(f.name)
            thumb = f'<img src="{rel}/{name}" alt="" loading="lazy">' if f.suffix.lower() != '.html' else '<b>page</b>'
            cells += f'<a href="{rel}/{name}">{thumb}{name}</a>'
        galleries.append(f'<h2>{html.escape(title)}</h2><div class="grid">{cells}</div>')
    mq = dev / 'maquettes'                         # the mock-ups, written straight into the site (pages)
    if mq.is_dir():
        cells = ''.join(f'<a href="maquettes/{html.escape(f.name)}"><b>maquette</b>{html.escape(f.stem)}</a>'
                        for f in sorted(mq.iterdir()) if f.suffix == '.html')
        if cells:
            galleries.insert(0, f'<h2>Maquettes</h2><div class="grid">{cells}</div>')
    body = ('<h1>Dev-library</h1><p class="sub">Les propositions, maquettes et images du jeu, gardées ici pour les retrouver. '
            'Touche une image pour la voir en grand.</p>' + ''.join(galleries))
    (dev / 'index.html').write_text(page('dev/index.html', 'dev-library', body, depth=1), encoding='utf-8')
    print('site :', VERSION, '·', len(galleries), 'galeries dans dev/')


if __name__ == '__main__':
    build()
