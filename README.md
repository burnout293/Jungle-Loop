# Jungle Loop — version Godot

Portage du jeu web (dépôt `Jungle-Loop`, dossier `js/`) vers **Godot 4.7**. État au 17/11/2026 : le
code est entièrement écrit à partir de la version web 0.26.0. **Il n'a encore jamais été lancé** :
Godot n'était pas installé sur ce PC. Il faut s'attendre à quelques erreurs au premier lancement.

## Ouvrir le projet

1. Installer Godot 4.7 (version standard, pas .NET).
2. Ouvrir Godot, « Importer », choisir `project.godot` dans ce dossier.
3. Au premier import, Godot crée le dossier `.godot/` (cache, jamais committé) et un fichier `.import`
   à côté de chaque image et musique (eux se committent).
4. F5 lance le jeu.

Pour essayer sans toucher à sa sauvegarde : lancer avec `-- --bac` (sauvegarde séparée, comme `?bac`
dans la version web).

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

- Le menu de debug (`js/debug.js`) et les aperçus animés de la boutique (`js/demo.js`) : la boutique
  montre l'icône à la place.
- Les confettis, le glissement des écrans, le changement de police sans relancer.
- Les polices Silkscreen et Fredoka : à déposer dans `assets/fonts/` (`Silkscreen-Regular.ttf`,
  `Fredoka-Medium.ttf`) ; sans elles, la police de Godot.

## Export

Pour exporter (Windows, Android, Web), il faut les modèles d'export de Godot 4.7, et ajouter
`*.json, *.txt` aux fichiers non-ressources à inclure (meta.json, patterns.txt, tracks.json).
