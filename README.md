# Jungle Loop

Course infinie en pixel art : Pépito a volé la relique du temple, et la jungle ne le laissera pas partir.

Le jeu est un site statique, sans compilation : ouvrir `index.html` derrière n'importe quel serveur web suffit.
Il est publié sur GitHub Pages : https://burnout293.github.io/Jungle-Loop/. Sur téléphone, il se joue en
paysage et peut s'installer sur l'écran d'accueil.

- `js/` : règles (`game.js`), dessin (`render.js`), écrans (`main.js`), son (`audio.js`), boutique et
  sauvegarde (`save.js`), défis (`progress.js`), aperçus de la boutique (`demo.js`), menu de debug (`debug.js`)
- `assets/` : images, musiques, et `patterns.txt` (les dessins de pièces, modifiables à la main)
- `tools/` : scripts qui ramènent les images générées à la grille du jeu (`pixelgrid.py`, `pixeldown.py`) et
  les découpent (`import_*.py`)
- `mockups/` : maquettes (à ouvrir servies, pas en fichier)
- [EQUILIBRAGE.md](EQUILIBRAGE.md) : toutes les valeurs de jeu
- [BESTIAIRE.md](BESTIAIRE.md) : dangers, boss, montures, plateformes, par décor

Pour essayer sans toucher à sa sauvegarde : ajouter `?bac` à l'adresse.
