# Jungle Loop — version Godot

Portage du jeu web (branche `main` du dépôt `Jungle-Loop`, dossier `js/`) vers **Godot 4.7.2**. Version
**0.29.0** (17/11/2026) : à parité avec la version web 0.28, aperçus de la boutique et menus compris. Le jeu
tourne : courses automatiques sans erreur (départ, Vorace jusqu'à sa chute, les trois montures, Run
illimitée, changements de décor), écrans vérifiés en capture, export web mesuré dans Edge (une image coûte
environ 1 ms de calcul, 60 images/s). Pas encore essayé à la main sur téléphone.

Publiée à l'essai sur https://burnout293.github.io/Jungle-Loop/godot/ (installable sur l'écran d'accueil).

## Ouvrir le projet

1. Installer Godot 4.7 (version standard, pas .NET).
2. Ouvrir Godot, « Importer », choisir `project.godot` dans ce dossier.
3. Au premier import, Godot crée le dossier `.godot/` (cache, jamais committé) et un fichier `.import`
   à côté de chaque image et musique (eux se committent).
4. F5 lance le jeu.

Pour essayer sans toucher à sa sauvegarde : lancer avec `-- --bac` (sauvegarde séparée, comme `?bac`
dans la version web).

Banc d'essai (`scripts/bench.gd`), toujours avec `--bac` : un robot joue, la course s'affiche chaque seconde,
une capture toutes les 2 s (pas en `--headless`) :

```
Godot --path . -- --bac --test --seconds=30 --god --start=1950 --shots=captures
Godot --path . -- --bac --test --biome=3 --ride=gorilla --still --shots=captures
Godot --path . -- --bac --test --screen=shop --seconds=3 --shots=captures
```

Options : `--start=<m>`, `--god`, `--up=flight,dash`, `--mode=endless`, `--mount=<monture qui attend>`,
`--ride=<monture déjà montée>`, `--biome=0..3`, `--still` (le robot n'appuie pas), `--screen=<écran>`,
`--tour` (tous les écrans, captures pendant leurs glissements, doigts simulés).

Dans un navigateur, sur ce PC seulement (`localhost`), les mêmes options passent par l'adresse :
`index.html?test&seconds=30&god&start=1950`. La course s'écrit dans la console du navigateur.
`?fps` affiche les images par seconde et ce que coûte une image (« jeu » : les règles, « dessin »).

## Organisation

| Fichier | Rôle | Port de |
|---|---|---|
| `scripts/game.gd` | règles : course, sauts, montures, Vorace, nuées, pièces (aucun dessin) | `js/game.js` |
| `scripts/art.gd` | chargement des images et tout ce qui en est fabriqué (contours, collines, îlots, silhouettes) | moitié « chargement » de `js/render.js` |
| `scripts/render.gd` | le dessin d'une course, en quatre calques | moitié « dessin » de `js/render.js` |
| `scripts/ambient.gd` | oiseaux, papillons, lucioles, vent, pluie | `js/ambient.js` |
| `scripts/audio.gd` | musiques et bruitages (le même petit synthétiseur, rendu en échantillons au démarrage) | `js/audio.js` |
| `scripts/save.gd` | sauvegarde, boutique, codes d'export (compatibles avec la version web) | `js/save.js` |
| `scripts/progress.gd` | niveau et défis | `js/progress.js` |
| `scripts/main.gd` | écrans, HUD, commandes, boucle, qualité d'image | `js/main.js`, `index.html`, `style.css` |
| `scripts/demo.gd` | aperçus animés de la boutique : une vraie petite course scriptée | `js/demo.js` |
| `assets/` | images, `meta.json`, `patterns.txt`, les deux musiques utilisées | `assets/` |

Les unités sont celles de la version web : 1 pixel d'art = 2,25 unités, écran de 1280 × 720 unités
(569 × 320 pixels d'art), en 16:9 avec des bandes noires autour.

Le jeu se dessine dans une image de q × q pixels par pixel d'art (`SubViewport`), ajustée ensuite à
l'écran, comme le canevas de la version web. Réglage « Lissage » : « Auto » commence à 4 sur PC et 3 sur
téléphone et descend d'un cran si les images ralentissent (ce qu'il a trouvé est gardé dans
`user://jungle-loop-cap.txt`), « Maximum » prend ce que l'écran peut montrer, « Net » s'arrête à 2.

Tactile : chaque doigt compte (le saut reste tenu tant qu'un doigt est posé) et un second doigt peut
toucher Pause, Ruée ou Sablier, ce que les boutons de Godot ne voient pas seuls.

Polices : Silkscreen et Fredoka (Google Fonts, licence OFL, dans `assets/fonts/`). Les symboles qu'aucune
des deux n'a (◈ ● ○ ★ ↻ −) sont dans `JungleSymbols.ttf`, dessinée sur la grille de Silkscreen par
`tools/make_symbols.py` : un navigateur ou un téléphone n'a pas de police système où les trouver. La
police pixel est gardée à des tailles multiples de sa grille, recalculées quand la fenêtre change.

Le menu de debug (`scripts/debug.gd`) s'ouvre comme dans la version web : cinq touches sur le badge de
niveau de l'accueil. Ses réglages sont gardés dans `user://jungle-loop-debug.json`.

## Export

`export_presets.cfg` a un préréglage « Web » sans fils d'exécution (il marche sur GitHub Pages, qui ne
peut pas envoyer les en-têtes qu'exigent les fils), qui inclut `*.json, *.txt` (meta.json, patterns.txt,
tracks.json). Il faut les modèles d'export de Godot 4.7.2 (seuls ceux du web sont installés sur ce PC) :

```
Godot --headless --path . --export-release "Web" export/web/index.html
```

Résultat : 44 Mo dans `export/web` (moteur `index.wasm` 39,5 Mo, jeu `index.pck` 6,5 Mo), jamais committé.
L'export est une appli installable (PWA) : plein écran, couchée, icônes `assets/pwa/`, écran de chargement
`assets/pwa/splash.png`, en-tête pour l'iPhone dans `html/head_include`. Le fichier de cache hors ligne se
renouvelle à chaque export.

Dans un navigateur, un vrai ou faux venu de JavaScript n'est pas toujours un booléen côté Godot : le
comparer à `true` arrête le script (et en export « release », sans un mot). D'où `_js_yes()` dans
`main.gd`, qui fait renvoyer 1 ou 0. Pour voir les erreurs d'un export web : `--export-debug`.
