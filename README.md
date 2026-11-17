# Jungle Loop — version Godot

Portage du jeu web (branche `main` du dépôt `Jungle-Loop`, dossier `js/`) vers **Godot 4.7.2**. État au
17/11/2026 : au niveau de la version web 0.27.0, sauf ce qui est listé plus bas. Le jeu tourne : courses
automatiques sans erreur (départ, Vorace jusqu'à sa chute, les trois montures, Run illimitée, changements de
décor), écrans vérifiés en capture (accueil, boutique, réglages, course, boss, donjon, cité). Pas encore
essayé à la main ni sur téléphone.

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
`--ride=<monture déjà montée>`, `--biome=0..3`, `--still` (le robot n'appuie pas), `--screen=<écran>`.

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
| `scripts/main.gd` | écrans, HUD, commandes, boucle | `js/main.js`, `index.html`, `style.css` |
| `assets/` | images, `meta.json`, `patterns.txt`, les deux musiques utilisées | `assets/` |

Les unités sont celles de la version web : 1 pixel d'art = 2,25 unités, écran de 1280 × 720 unités
(569 × 320 pixels d'art), en 16:9 avec des bandes noires autour.

## Pas encore porté

- Le menu de debug (`js/debug.js`, avec son bandeau rouge et l'arrêt des records) et les aperçus animés
  de la boutique (`js/demo.js`) : la boutique montre l'icône à la place.
- Les confettis, le glissement des écrans, le changement de police sans relancer.

Polices : Silkscreen et Fredoka (Google Fonts, licence OFL, dans `assets/fonts/`).

## Export

Pour exporter (Windows, Android, Web), il faut les modèles d'export de Godot 4.7, et ajouter
`*.json, *.txt` aux fichiers non-ressources à inclure (meta.json, patterns.txt, tracks.json).
