# Jungle Loop

Course infinie en pixel art : Pépito a volé la relique du temple, et la jungle ne le laissera pas partir.
Deux modes : Histoire (avec les boss) et Run illimitée (sans boss).

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

**Depuis le 18/11/2026, le jeu est la version Godot** (0.41.0) : son code est dans la branche `godot`
(dossier `Projects/Jungle-Loop-Godot`), son export web est à la racine de cette branche `main` (`index.html`,
`index.js`, `index.wasm`, `index.pck`… avec son propre cache hors ligne, `index.service.worker.js`).
Au premier lancement dans le navigateur, la partie de l'ancienne version (même adresse) est reprise si elle
est plus avancée.

L'ancienne version web (0.28.1, `js/`, `style.css`) reste jouable sur `web.html`, en ligne seulement :
`sw.js` n'est plus qu'un nettoyeur qui efface son ancien cache hors ligne et recharge la page vers le jeu
Godot. `godot/` (l'essai) renvoie à l'adresse principale. Les règles et chiffres du jeu sont dans
[EQUILIBRAGE.md](EQUILIBRAGE.md) et [BESTIAIRE.md](BESTIAIRE.md).
