# Jungle Loop

Course infinie en pixel art : Pépito a volé la relique du temple, et la jungle ne le laissera pas partir.
Modes : Histoire (avec les boss), Sans fin, Affrontement (course à plusieurs).

Cette branche `main` est **ce qui est en ligne** sur GitHub Pages : https://burnout293.github.io/Jungle-Loop/
(sur téléphone, il se joue en paysage et peut s'installer sur l'écran d'accueil). Le jeu est fait avec Godot :
son code est dans la branche `godot`, sur le PC dans le dossier `Projects/Jungle-Loop`, dont ce dépôt est le
sous-dossier `site/` (0.53.0). On n'y écrit pas à la main : `python tools/publish_web.py` (du dossier du jeu)
y copie l'export web (`index.html`, `index.js`, `index.wasm`, `index.pck`… avec son cache hors ligne,
`index.service.worker.js`), `version.txt` et `nouveautes.txt`.

- [EQUILIBRAGE.md](EQUILIBRAGE.md) : toutes les valeurs de jeu
- [BESTIAIRE.md](BESTIAIRE.md) : dangers, boss, montures, plateformes, par décor
- [confidentialite.html](confidentialite.html) : la politique de confidentialité (exigée par les magasins)
- `sw.js` : nettoyeur de l'ancien cache hors ligne de la version web d'avant Godot (recharge vers le jeu)
- `godot/` : l'adresse de l'essai Godot, qui renvoie à l'adresse principale

Pour essayer sans toucher à sa sauvegarde : ajouter `?bac` à l'adresse. Pour voir une poursuite de l'écran de
chargement : `?chase=1` à `4`, et `&lent=5` pour qu'elle dure 5 secondes au moins.

L'ancienne version web (0.28.1, en JavaScript : `js/`, `web.html`, ses images et musiques, ses maquettes et
outils) n'est plus en ligne depuis la 0.51.0 : elle est archivée sur le PC (`Projects/Archives/Jungle-Loop`)
et reste dans l'historique de cette branche. Au premier lancement, la partie de cette ancienne version (même
adresse) est reprise si elle est plus avancée.
