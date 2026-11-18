# Jungle Loop — version Godot

Portage du jeu web (branche `main` du dépôt `Jungle-Loop`, dossier `js/`) vers **Godot 4.7.2**. Version
**0.34.0** (18/11/2026) : **c'est le jeu** depuis le 18/11 (la conversion est déclarée finie) ; à parité avec la
version web 0.28, puis ses propres changements (plus bas, « Depuis la parité »). Le jeu
tourne : courses automatiques sans erreur (départ, Vorace jusqu'à sa chute, les trois montures, Run
illimitée, changements de décor), écrans vérifiés en capture, export web mesuré dans Edge (une image coûte
environ 1 ms de calcul, 60 images/s). Pas encore essayé à la main sur téléphone.

Publiée à l'adresse principale, https://burnout293.github.io/Jungle-Loop/ (installable sur l'écran d'accueil) :
l'export web est copié à la racine de la branche `main`. L'ancienne version web y reste jouable sur
`web.html` ; `godot/` (l'essai) renvoie à la racine. Au premier lancement dans un navigateur, la partie de
l'ancienne version web (localStorage `jungle-loop-save-v1`, même adresse) est reprise si elle est plus
avancée (plus d'expérience) ; celle d'avant est gardée dans `user://jungle-loop-save-before-web.json`.

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
| `scripts/progress.gd` | niveau et défis, lecture de `reglages/progression.txt` | `js/progress.js` |
| `scripts/tune.gd` | lecture de `reglages/equilibrage.txt` : chaque ligne y règle un `static var` de `game.gd`, en mètres, secondes, m/s et % | — |
| `reglages/` | **à régler soi-même**, lus à chaque lancement : `equilibrage.txt` (vitesses, sauts, Vol, objets, montures, araignées, volants, nuées, Vorace), `progression.txt` (points par mètre et par niveau, pièces d'un niveau, niveau requis et prix de chaque amélioration, défis), `patterns.txt` (dessins de pièces) | — |
| `scripts/main.gd` | écrans, HUD, commandes, boucle, qualité d'image | `js/main.js`, `index.html`, `style.css` |
| `scripts/demo.gd` | aperçus animés de la boutique : une vraie petite course scriptée | `js/demo.js` |
| `assets/` | images, `meta.json`, les deux musiques utilisées | `assets/` |
| `tools/make_ui_colours.py` | les boutons dorés, verts et rouges, recolorés à partir de ceux du kit | — |

Les unités sont celles de la version web : 1 pixel d'art = 2,25 unités, écran de 1280 × 720 unités
(569 × 320 pixels d'art), en 16:9 avec des bandes noires autour.

Le jeu se dessine dans une image de q × q pixels par pixel d'art (`SubViewport`), ajustée ensuite à
l'écran, comme le canevas de la version web. Réglage « Qualité » (il remplace « Lissage ») :

| Qualité | Image | Images/s | Détails |
|---|---|---|---|
| Max (défaut sur PC) | ce que l'écran peut montrer (q jusqu'à 4), adoucie | celles de l'écran (120 sur certains téléphones) | tout |
| Perf (défaut sur téléphone) | q = 2 au plus, carrés nets | tenue à 60 : régulière, là où un écran 120 Hz oscillait entre 45 et 65 | tout |
| Éco | q = 2 au plus | 30 | moins de petites bêtes, de feuilles et de pluie (`Ambient.lite`) |

Les cordes, chaînes et câbles dessinés au pixel sont cuits une fois en images (`_bake`, classe `Baker`
dans `render.gd`) puis dessinés par bandes d'égal balancement (`hang_bands`) ; le sol saute les longueurs
plates de son tracé. Mesuré sur PC : dessin du décor du fond 0,9 → 0,5 ms par image.

Tactile : chaque doigt compte (le saut reste tenu tant qu'un doigt est posé) et un second doigt peut
toucher Pause, Ruée ou Sablier, ce que les boutons de Godot ne voient pas seuls.

Polices : Silkscreen et Fredoka (Google Fonts, licence OFL, dans `assets/fonts/`). Les symboles qu'aucune
des deux n'a (◈ ● ○ ★ ↻ −) sont dans `JungleSymbols.ttf`, dessinée sur la grille de Silkscreen par
`tools/make_symbols.py` : un navigateur ou un téléphone n'a pas de police système où les trouver. La
police pixel est gardée à des tailles multiples de sa grille, recalculées quand la fenêtre change.

Le menu de debug (`scripts/debug.gd`) s'ouvre comme dans la version web : cinq touches sur le badge de
niveau de l'accueil. Ses réglages sont gardés dans `user://jungle-loop-debug.json`.

## Depuis la parité (0.30.0)

- **Boutique en liste** : une ligne par objet (image, nom, prix avec la pièce ou état) ; nom, aperçu,
  description, prix et boutons à droite. Les objets pas encore débloqués portent un bandeau bleu en biais
  « NIV. 3 ». La pièce remplace le losange partout (prix, défis, gains).
- **Dernier élan** : lancé à 1,3 × sa vitesse (+0,15 par niveau), plus haut selon la vitesse, freiné
  doucement, un rebond par niveau (`LEAP_*` dans `game.gd`). Au niveau 1 à 14 m/s : 31 m au lieu de 13.
- **Photo de la chute** : prise l'image où il tombe (le héros encore dessiné, `Render.show_dead`), montrée
  à l'écran de fin ; une touche l'affiche en grand.
- **Pièces de l'explosion du temple** : elles suivent le sol posé après leur atterrissage (corniches et
  creux), au lieu de rester dedans.
- **Vorace équitable** : chaque danger demande d'être en l'air (flaque, boule basse) ou au sol (boule à
  hauteur de tête) pendant un moment ; une attaque n'est lancée que si un petit saut passe encore tout,
  avec 0,2 s entre deux gestes (`_threats`, `_fits`, `_attack_fits` dans `game.gd`). Sur 30 combats
  simulés : aucune paire impossible.

## 0.34.0

- Dossier `reglages/` : `equilibrage.txt` (nouveau, lu par `tune.gd`), `progression.txt` et `patterns.txt`
  (venus d'`assets/`). Les nombres de `game.gd` qu'il règle sont des `static var`.
- Histoire : +0,18 m/s par seconde (`STORY_GAIN` 7,2) ; `ZONE_SPEED` remplace `ZONE_EXTRA`.
- Vol : montée 12 m/s au niveau 1, 13,5 et 15 aux niveaux 2 et 3 (`FLAP_LV`, `flap()`), chute ×1,2.
- Araignées : jamais plus de 2 dans une colonne (`SPIDER_COLUMN`, `add_hover` refuse la troisième) ; rideau à
  deux araignées et deux places libres ; porte et tour de la libellule à deux.
- Montures : Dompté et Aimant pour chacune (`gorillaTamed`, `rhinoMagnet`…, champ `mount`), listés sous elle
  dans l'onglet (`_up_row`) ; l'ancien Dompté / Aimant de monture et le Gros sac à dos sont remboursés
  (`SaveData.REMOVED`).
- Objets : Bottes de métal (`boots`, `quake`, plongeon `p.diving`), Fana de TNT (`tnt`, `Shot`, `blast`),
  Esquive (`dash` : +200 m/s 0,2 s, balayage de tout le chemin parcouru, `px0`), Relique altérée (`drunk` :
  éthérées + décor bloqué, bande de l'autre décor `strip_*`, dessinée par `ghost_mosaic`), Vitalité
  (`heart`, 3 niveaux). Icônes `ico-boots`, `ico-tnt`, `ico-relic` (PixelLab).
- Sablier ramassé : −20 % de la vitesse, plus gros, sans bulle, avance à 90 % de la vitesse une fois à l'écran.
- Boule de ronces recolorée en vert (`thornball.png`) ; piège à loup posé au sol (`SINK`).
- Accueil : Jouer (Run illimitée, cadre doré, 58 px), Histoire assombri, panneaux d'explication au survol ou
  à l'appui long (`MENU_TIPS`) ; la Run illimitée part d'un décor au hasard, déjà derrière l'accueil
  (`endless_biome`, `_roll_biome`). Pause : Reprendre vert, Abandonner rouge orangé.
- HUD : jusqu'à quatre boutons (`ACTS`) ; clavier S / ↓ Bottes, F / T TNT.
- Photo de la chute sans le filtre rouge (`show_dead` dans `_draw_over`).
- Même graine, même parcours : la limite des colonnes compte ce que la route a posé (`spider_xs`), pas ce
  qui reste, et l'espacement suit la vitesse sans sablier (`road_speed`). Comme une monture, un sablier
  ramassé change la vitesse du joueur : en coop, les deux sont à couper. Vérifié : 993 éléments identiques.

## 0.33.0

- Histoire : chaque décor a sa vitesse de départ (forêt 9 m/s, ruines 10, donjon 11, cité 12 : `ZONE_EXTRA`)
  et l'accélération est de 0,25 m/s par seconde (`STORY_GAIN`) ; la Run illimitée garde 9 m/s et 0,125.
- Montures : chacune s'active ou se désactive dans l'onglet Montures (`save.mountsOff`, `run.mounts`) ; deux
  améliorations de la famille « mount » : Dompté (attrapée de plus loin, même en sautant ; elle t'attend) et
  Aimant de monture (`tamed`, `mountMagnet`, aperçus dans `demo.gd`).
- Vol plus réactif : montée 600 u/s (430), arrêt net au relâché, puis chute ×1,4 (`FLAP`, `VOL_DROP`, `flew`).
- Vorace 140 u plus à droite (`BOSS_BACK`), boules à leur hauteur en 0,25 s (`BALL_SETTLE`), éventail à trois
  couloirs libres, à une place au plus du précédent. Banc : 12 combats en vol, toutes les façons de voler
  (tenu / relâché à chaque image, vraie gravité) : aucun moment sans passage.
- Niveaux : 1 point tous les 20 m, 1000 points par niveau, plus de paliers ; défis réglés un par un ; tout
  dans `assets/progression.txt` (`Progress.load_config`). Anciennes sauvegardes : expérience ÷ 20 (`xpv`).
- Plus d'annonce de niveau pendant la course : un panneau à la fin (`show_levels`) avec le niveau, les pièces
  et ce qui se débloque.
- Écran de fin gardé quand le téléphone tourne (`over_info`, `over_view`).
- iPhone : page épinglée (fixe, sans défilement) et remise à 0,0 après chaque rotation ou changement de la
  zone visible, puis le jeu remesuré (`html/head_include` de l'export web).
- Boutique : lignes sans case creusée (l'icône posée sur la pierre, `tools/import_ui_v2_godot.py`,
  `plain_rows`) ; emplacements du menu en carré de pierre du kit (`sq-blank-42`).

## 0.32.1

- Boutique : Retour, onglets des familles et lignes d'objets avec les boutons du kit (`assets/img/ui-v2/shop`,
  faits par la session Assets à la taille exacte de leurs cases, posés tels quels, `_shop_skin`) ; l'objet
  ou la famille choisis gardent l'image « enfoncée » ; l'image de l'objet dans la case creusée de sa ligne.

## 0.32.0

- Vitesse de départ 9 m/s (`SPEED_BASE` 360). Histoire : chaque nouveau décor repart de cette vitesse et
  accélère deux fois plus vite (`zone_t`, `zone_k`, `ZONE_ACCEL`). Run illimitée : un décor tous les 800 m
  (`ZONE_ENDLESS`).
- Araignées bien plus nombreuses (suspendu ×8 entrées, motif « spiders »). Jaunes immobiles ; rouges qui
  montent et descendent de 2,5 m de chaque côté en 2,4 s (`SPIDER_*`), du sol au plafond ; les colonnes
  (rideaux, portes de la libellule) bougent d'un bloc (`add_hover(…, ph)`).
- Vagues de volants : 2 à 10, de 0,9 à 0,3 s d'écart selon la vitesse (`WAVE_*`, `_wave`) ; à pied à
  hauteur de tête, un bas seulement en premier avec 0,8 s avant le suivant ; avec le Vol visés ; rien
  d'autre sur la route pendant une vague.
- Vorace contre le Vol (et la libellule) : éventail de boules jusqu'au plafond (`FAN_LANES`), ouverture à 2
  places au plus de la précédente, tirs 1,3 fois plus fréquents (`FLY_PACE`).
- Libellule : trois fois plus de créatures en l'air, accélération ×2.
- Donjon : flèches enflammées (`_flames` dans render.gd).
- Objets rares qui flottent en zigzag, à portée de saut (`add_bonus`, `BONUS_*`) : une vie, ou un frein
  (-4 m/s pour le reste de la course, `brake`). Un tous les 1 400 à 2 400 m environ.
- Photo de la chute prise au coup fatal (événement `fatal`), avant les rebonds du Dernier élan.
- Toujours esquivable, vérifié par un banc qui essaie toutes les façons de jouer image par image (fair_bfs) :
  à pied (vrais sauts, tap ou tenu) et avec le Vol (montée 430 u/s), 43 200 images chacun, aucun passage
  impossible ; Vorace : 30 combats, aucune paire impossible.
- Multijoueur préparé : le parcours a son propre dé (`W`, `wrnd`, `wpick`, `wshuffle` ; `run.rng` semé par
  `new_run(…, seed)`) : même graine, même parcours (vérifié : 1 119 éléments identiques, joueur immobile
  contre joueur qui saute). Serveur prêt dans `server/` (scores entre amis, salons de coop, testé), côté jeu
  `scripts/net.gd` (inactif tant que `SERVER` est vide).

## 0.31.0

- **Le Vol ne campe plus** : araignées à toutes les hauteurs (`SKY_HOVERS`), rideaux d'araignées à un seul
  passage (`CURTAIN`, passage à 2 places au plus du précédent, `CURTAIN_LEAD` pour le voir venir), volants
  qui visent ta hauteur quand leur « ! » s'affiche (`Obs.aim`), et un volant pour qui garde la même hauteur
  2,6 s (`camp`). À pied sans le Vol : moins de volants, plus de hérissons et d'araignées jaunes.
  Vérifié (banc fly_tests) : sur 8 parcours de 150 s, un passage atteignable partout ; un campeur volant prend
  17 à 21 coups par minute (2 à 3 avant).
- **Une seule zone de ramassage** des pièces (une boîte, `COIN_HALF` 44 de chaque côté) au lieu d'une boîte
  et d'un cercle ; roulé en Sphère, une boîte à sa taille (`BALL_REACH`).
- **Kit d'interface v2** (pierre, lianes, gemme) : boutons, carrés (engrenage, pause, − et +), barres et
  panneaux, chacun à la taille exacte de sa boîte, jamais étiré ni coupé. Les images viennent du dépôt web
  (`assets/ui-v2`, fait par `tools/import_ui_v2.py`) ; `tools/import_ui_v2_godot.py` les copie dans
  `assets/img/ui-v2` et fabrique avec les mêmes fonctions les panneaux aux tailles propres à cette version
  (Réglages 262 × 262 et 265 × 262, aperçu de la boutique 253 × 282). Le contenu d'un panneau fixe défile
  plutôt que de le faire grandir (`_fixed`). Le kit n'a ni vert ni or : le bouton choisi prend l'état survol.
- Reprise de la partie de l'ancienne version web (`_adopt_web_save`).

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
