# Jungle Loop — version Godot

Portage du jeu web (branche `main` du dépôt `Jungle-Loop`, dossier `js/`) vers **Godot 4.7.2**. Version
**0.55.0** (23/11/2026) : **c'est le jeu** depuis le 18/11 (la conversion est déclarée finie) ; à parité avec la
version web 0.28, puis ses propres changements (plus bas, « Depuis la parité »). Le jeu
tourne : courses automatiques sans erreur (départ, Vorace jusqu'à sa chute, les trois montures, Run
illimitée, changements de décor), écrans vérifiés en capture, export web mesuré dans Edge (une image coûte
environ 1 ms de calcul, 60 images/s). Pas encore essayé à la main sur téléphone.

Publiée à l'adresse principale, https://burnout293.github.io/Jungle-Loop/ (installable sur l'écran d'accueil) :
l'export web est copié à la racine de la branche `main`, dont le dépôt est le dossier `site/` d'ici (0.51 :
un seul dossier pour le jeu, `Projects/Jungle-Loop` ; ce qui ne sert plus va dans `Projects/Archives/Jungle-Loop`,
dont l'ancienne version web 0.28, retirée du site). `godot/` (l'essai) renvoie à la racine. Au premier lancement dans un navigateur, la partie de
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
| `scripts/net.gd` | le serveur (amis, scores, salons) : rien n'est envoyé tant que l'adresse est vide | — |
| `scripts/coop.gd` | jouer à deux : le salon, la connexion WebRTC, les messages de la course | — |
| `reglages/` | **à régler soi-même**, lus à chaque lancement : `reseau.txt` (l'adresse du serveur, STUN / TURN), `equilibrage.txt` (vitesses, sauts, Vol, objets, montures, araignées, volants, nuées, Vorace), `progression.txt` (points par mètre et par niveau, pièces d'un niveau, niveau requis et prix de chaque amélioration, défis), `patterns.txt` (dessins de pièces) | — |
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

## 0.55.0

- **Une seule monnaie** (`reglages/decisions-economie.md`, partie 1 validée) : plus d'éclats, de plumes de toucan,
  de Tambours ni de consommables en stock (Bouclier, Aimant simple, Couteau suisse en stock). Une sauvegarde
  d'avant reçoit des pièces à la place (`STOCK_COINS` 200 par objet, `FEATHER_COINS` 25, `SHARD_COINS` 40 ; une
  fois : ces champs ne sont plus gardés). **Équipements** à trois niveaux, en Run illimitée : Corne de brousse
  (`horn` : sortie du temple sur le rhino, 300 / 500 / 800 m, `HORN_M`, `Mount.until`), Idole dorée (`idol` : +25 /
  50 / 75 % de pièces, `IDOL_MUL`), Couteau suisse (0.54). **Skins en pièces** selon leur rareté (commun 2500,
  rare 10 000, légendaire 50 000 ; doublon d'urne 400 / 1500 / 5000 pièces : `Treasure.cfg`, `[urnes]`). Urnes :
  pièces ou skins ; une de plus pour Vorace battue. Les plumes deviennent **un défi changé gratuit par jour**
  (`Progress.reroll_free`, `rerollDay`). Sur la route, la plume devient un sablier (le dé de la route inchangé).
- **Missiles** : à pied, ils gardent la hauteur où ils sont posés (au ras du sol : sauter ; plus haut : rester
  au sol) et jamais deux fois de suite la même (`dart_alt`) ; seuls ceux du Vol suivent ta hauteur, et un missile
  qui passerait où le précédent est passé est décalé (`DART_SPREAD`). À pied, en se figeant, un missile regarde ce
  qui l'attend là où il te croisera (`_dart_lane`, `_asks`) : si sa hauteur y rendait le passage impossible (haut
  alors qu'il faut sauter, bas alors qu'on ne peut pas sauter), il prend l'autre, ou ne vient pas ; la route posée
  ensuite dans cette zone est vérifiée aussi (`_darts_vs_new`). fair_bfs et fair_bfs_coop : 0 passage impossible.
- **Affrontement** (`race.gd`) : accès Jouer → Affrontement (un groupe se crée s'il n'y en a pas) ; « Prêt ! »
  pour chacun, « Lancer » pour l'hôte quand tous le sont (`all_ready`, `set_ready`) ; mise libre de 0 à 99 999 999
  (champ + 100 / 500 / 1000 / 5000) ; qui a misé sur le plus loin reçoit le double de sa mise, rien d'autre
  (`settle`) ; l'écran montre les places (le skin de chacun), tes pièces, l'équipement de la course (celui de
  l'hôte), l'historique des courses du groupe (mises et distances, `history`). En course : l'équipement en haut
  à gauche, les mises de chacun en haut à droite (`board`), plus de pause ; tombé, tu **regardes** les autres
  (`Game.spectate`, la route continue d'être posée devant celui que tu suis ; une touche : un autre) jusqu'au
  résultat.
- **Liens qui tombent** (rotation, autre appli) : « déconnecté » n'est plus la fin avant 6 s (`DOWN_GRACE`, aussi à
  deux) ; la place d'un invité attend 90 s (`AWAY_KEEP`), il se reconnecte seul par la salle (`_relink`, toutes les
  12 s, 80 s au plus) et retrouve sa place, sa mise ; l'hôte rouvre la salle avant que le serveur l'oublie et le
  dit à tous. Après une rotation, chaque écran est reconstruit **avec ses infos** (Affrontement, Amis compris), les
  fenêtres ouvertes sont fermées, l'image du jeu est recalculée aussitôt (`fit`).
- **Accueil** : le groupe (le skin et le nom de chacun) à droite de JOUER ; plus de bouton Tambours. **Amis →
  Groupe** : seulement le groupe (ses places, inviter des amis, son code, le quitter) ; jouer à deux se lance depuis
  la fiche d'un ami.
- Tests : `tests/eco_055.gd` (24 vérifications), `tests/race_logic.gd` (29 : Prêt, double, historique,
  reconnexion). Banc `--tour55` (avec une rotation). Le banc `--tour47` est retiré.

## 0.54.0

- **La falaise** entre la forêt et les pitons (`lay_cliff`, `_cliff_begin`, `CLIFF_*`) : quand les pitons viennent
  après la forêt, le sol monte (`CLIFF_H` sur `CLIFF_RISE`), court à plat jusqu'au bord, puis tombe dans la brume ;
  les pitons commencent au bord (`run.cliff_x`). Posée au motif suivant, hors de l'écran, seul comme à deux (là,
  au changement de décor de `spawn_pattern` : la même sur les deux téléphones). Image PixelLab : la fin du sol de
  la forêt repeinte en paroi (inpaint sur le sol lui-même, `assets/src/falaise`, `assets/img/cliff.png`).
- **Le saut et l'envol** : au bord il saute (`CLIFF_LEAP`), tombe `CLIFF_FALL` s quoi qu'on appuie (`run.soar`),
  puis le Vol le prend (gerbe verte, son « soar »). En Histoire, c'est là que la couronne de Vorace donne le Vol
  (avant, dès sa mort) ; « Le Vol ! » à l'écran.
- **Histoire, seul : la cinématique** : après Vorace, les gardes reprennent la poursuite (ils reviennent en
  courant), parlent (`falaise` dans `dialogues.txt`), puis la falaise est posée ; une fois sauté, ils crient
  (`envol`) et sautent derrière lui en deltaplane de feuilles à la réplique qui dit « deltaplane » (`glide_go`),
  le suivent `GLIDE_ESCORT` s (la caméra recule un peu pour les montrer, `GLIDE_SHIFT`), puis restent derrière.
- **Pitons** : la brume ne fait plus mal (elle le renvoie vers le haut, `MIST_BOUNCE`, `MIST_SINK`) ; route
  refaite en figures lisibles (`pinrow` : rangée de pitons qui montent et descendent d'un cran, pièces en arc
  au-dessus ; `pinthread` : un deltaplane au-dessus d'un piton, passer entre ; `glidestair` : trois deltaplanes en
  biais, dessous ou dessus selon les pièces ; rideaux, Fonceurs) ; plus rien de semé au hasard entre les figures ;
  les `SKY_EASY` premiers mètres, des rangées de pitons seulement.
- **Missiles** : le « ! » suit ta hauteur, puis se fige sa dernière seconde (`DART_FREEZE`, `fige`).
- **Monticules** : posés sur le sol sous eux (le plus bas), ils descendent dans un creux au lieu de flotter.
- **Plus de ponton en pierre** (le motif « grotte » : on ne pouvait pas sauter dessous).
- **Couteau suisse, équipement** (`swiss`, 3 niveaux, niveau 4) : une évasion par course sans prendre au stock,
  niveau 2 plus facile (zone ×1,4, curseur et zone à 75 %), niveau 3 deux évasions ; le couteau en stock reste
  utilisable après. Jamais en Histoire.
- Tests : `tests/cliff_054.gd` (33 vérifications) ; `sky_053` (la brume sans dégâts), `story_049` (quatre
  dialogues par essai). Banc : `--tour54`.

## 0.53.0

- **Les pitons brumeux** remplacent les ruines (même place, `Game.SKY` = 1 ; les images des ruines rangées dans
  l'archive, `godot/ruines`) : des pitons couverts de jungle sortent d'une mer de brume (PixelLab : fond lointain,
  couche du milieu, bande de brume derrière et devant Pépito, `assets/src/pitons`). **On n'y fait que voler** :
  le Vol y est toujours là (`Run.lvl("flight")` vaut au moins 1 quand `run.sky`), à leur lisière il s'envole tout
  seul (en croisière jusqu'au premier appui ; un animal qui ne vole pas reste derrière), la brume ne porte
  personne : y tomber (`MIST_FALL` sous la ligne du sol ; 0.54 : plus de dégâts) coûte un cœur (le dernier : le moment fatal) et il est
  remonté dans les airs. La route n'y a que ce qui vole : pitons (`pinnacle`, `pinpair` : passer par-dessus ;
  `PIN_HS`), Fonceurs (fusées en bambou des pygmées ou toucans qui piquent), suspendus (pygmées en deltaplane de
  feuilles, en rideaux comme avec le Vol), nuées (frelons), pièces en l'air ; ni danger au sol, ni trou, ni
  plateforme, ni décor à casser, ni colline. Leur décor moins assombri que les autres (il est déjà pâle).
- **Quand ils viennent** (`next_biome`, `Run.sky_ok`) : en Histoire après Vorace ; en Run illimitée seulement si
  le Vol est porté (cela changera), jamais en premier (la course part du temple, à pied).
- **Histoire** : Pépito vole la **mâchoire** de la relique au temple ; Vorace donne en mourant la **couronne**
  (le jade), qui confère le **Vol** (`RELIC_PIECES` jade, ambre, braise ; `RELIC_POWERS` Vol, Esquive, Sablier) ;
  « %d/4 MORCEAUX » compte la mâchoire. Dialogues mis à jour (la mâchoire, la couronne, les pitons après la fleur).
- **Le moteur web sans la 3D** (le jeu n'en a pas : `tools/build_web_template.ps1`, Godot 4.7.2 compilé avec
  Emscripten 4.0.20 dans `C:\Users\Buly\godot-build`, sans 3D ni physique, navigation, XR, et sans les modules
  inutilisés), essayé en deux versions : optimisé pour la taille, 25,6 Mo au lieu de 39,5 ; pour la vitesse, 37,3 Mo.
  **Pas utilisé pour l'instant** : mesurés dans le navigateur (cache chaud), les deux démarrent en ~4 s là où le
  moteur officiel met ~1,5 s (cause à trouver : sans doute les réglages de production de la compilation officielle).
  Les modèles sont dans `export/templates` (non commités) ; le préréglage Web garde le modèle officiel.
- Tests : `tests/sky_053.gd` (13 vérifications : l'ordre des décors, le Vol, l'envol, la brume, la route) ;
  `tests/coop_road.gd` : le cas « Sprint sur les deux » porte aussi le Vol (il change la route : les pitons).
  Bancs : `--tour53` (la lisière, l'envol, les pitons, les volants, la brume).

## 0.52.0

- **Temple de profil** (PixelLab, son porche repeint en couloir vu de côté ; `tools/split_temple.py`) : la pyramide
  et son escalier en diagonale derrière le sol, les rochers qui bouchent le bout du couloir sur le sol (ils
  disparaissent à l'explosion : l'intérieur sombre est peint derrière, quelques éclats restent dehors), le mur du
  couloir et le pilier de droite devant Pépito. Sa porte reste au même endroit du monde (`TEMPLE_X` -185). **La
  caméra part sur le temple entier** (`Game.TEMPLE_PAN`, 416 : l'accueil le montre aussi, `still.cam`) et glisse
  jusqu'à la porte pendant le grondement (adoucie au début et à la fin ; en Histoire, pendant que les gardes
  parlent) ; Pépito ne bouge pas dans le monde pendant ce temps. Le grondement dure 1,2 s au lieu de 0,75.
  L'ancien temple (de face) est rangé dans l'archive (`godot/temple-0.50`).
- **Relique** : ses quatre pièces redessinées par lui (sa source `relique-v51.psd` dans l'archive,
  `assets/src/relique/relique-v51-*.png`), remises à leur place dans le masque entier par `tools/place_relic.py`.
  L'outil de découpe automatique de la 0.51 est rangé dans l'archive (`godot/relique-0.51-auto`).
- **Réglages** : plus d'onglet Son ; les volumes en tête de Jeu, les images par seconde dans Affichage.
- **Écran de chargement qui ne se fige jamais** : tout ce qui bouge est une animation CSS de `transform` ou
  d'`opacity` (les jambes : chaque planche glisse derrière une fenêtre, `steps()` choisit l'image ; le groupe :
  `jl-in` puis `jl-out`), que le navigateur joue à part du JavaScript de la page : pendant que le moteur se
  compile et démarre, ils courent toujours (essayé : 4 s de JavaScript bloquant, trois poses différentes). La
  poursuite est en place avant même que le script du moteur soit lu.
- **Décor de vol « Les pitons brumeux »** (il remplacera les ruines ; choisi : B) : ses images sont prêtes
  (archive, `propositions/0.52` : fond lointain, couche du milieu, le piton-obstacle, les quatre volants découpés
  de la planche : pygmée en deltaplane, frelons, toucan, fusée en bambou). Le jeu en vol seul viendra ensuite.
- Bancs : `--tour52` (accueil sur le temple, Réglages, la caméra qui glisse, l'explosion, la sortie). t046 : le
  missile seul sur la route pendant sa vérification (le reste de la route le touchait parfois).

## 0.51.0

- **Un seul dossier** : le jeu est `Projects/Jungle-Loop` (ce dépôt, branche `godot`), le site publié son
  sous-dossier `site/` (le dépôt de la branche `main`, ignoré ici, avec un `.gdignore`) ; `tools/publish_web.py`
  y copie l'export. Ce qui ne sert plus est rangé dans `Projects/Archives/Jungle-Loop` (son `LISEZMOI.md`) :
  l'ancienne version web (retirée du site), les propositions tranchées, les pistes des ruines, les images que le
  jeu ne charge plus (anciens boutons et panneaux), l'outil du kit de pierre.
- **Réglages** rangés comme les Améliorations : la colonne de gauche (Retour, **Jeu**, **Affichage**, **Son**,
  **Sauvegarde** : `SET_TABS`, `_side_tabs`, `_paint_side_tabs`, le nom de chaque onglet aussi grand que sa
  pierre le permet), l'onglet ouvert dans un panneau de pierre au milieu. Jeu : contours des dangers,
  signalements décalés, images par seconde, version (« Mettre à jour »). Affichage : qualité, plein écran,
  police. Son : musique, effets (pas dans sa liste, gardé dans son onglet).
- **Trois parties** (`SaveData.SLOTS`, `current_slot`, `set_slot`, `path(n)`) : la partie 1 est le fichier
  d'avant, les autres `-p2`, `-p3` ; celle qu'on joue est retenue (`user://jungle-loop-slot.txt`). Chacune :
  son niveau, ses pièces, son record, **Jouer** (on passe à elle : `_switch_slot`, les réglages de l'appareil
  la suivent, `SaveData.DEVICE`), **Exporter** (copier le code ou un fichier), **Importer** (coller un code ou
  ouvrir un fichier), **Réinitialiser** (après un oui). Chaque partie est son propre joueur en ligne.
- **Amis en trois onglets** (en haut, à côté de Retour : `FR_TABS`) : **Liste d'amis** (la liste ; la fiche
  d'un ami : inviter dans le groupe, à deux, retirer ; sinon la mienne : code, QR, partage, ajouter, pseudo),
  **Groupe** (ses 4 places, créer, rejoindre par 4 lettres, quitter ; à droite, jouer à deux), **Scores**
  (Histoire ou Sans fin, cette semaine ou toujours ; à droite mon record, ma place, celui à battre). Les mises
  ne sont plus dans Amis : JOUER → **Affrontement** ouvre le salon de la course, où chacun mise avant le départ.
- **Relique** refaite (`tools/cut_relic.py`) : **quatre pièces**, le cœur serti dans la couronne ; la tête sous
  la couronne repeinte par PixelLab (`assets/src/relique/tete-nue.png`), coupée droit au milieu ; la mâchoire
  toute en violet (ses crocs dans les violets les plus pâles) ; chaque pièce une dalle avec son épaisseur (son
  flanc sombre dessous, ses bords éclairés en haut à gauche). Toujours pas montrée dans le jeu.
- **Donjon** : quatre monticules (PixelLab : éboulis et colonne couchée, cage rouillée, gargouille tombée,
  lustre écrasé sur des tonneaux), `tools/prep_mounds.py`, `hill-dungeon-1` à `4`, de nouveau derrière la route.
- **Écran de chargement** allégé : fond noir, rien que les coureurs (66 Kio au lieu de 187).
- Bancs : `--tour51` (Réglages, parties, Amis, donjon).

## 0.50.0

- **Accueil B3** : à gauche Réglages, Amis, Trésor, Tambours ; à droite Améliorations, Skins, Défis, chacun son nom
  dessous ; en bas au milieu **JOUER**, qui déroule ses modes depuis le bas, dans l'ordre Histoire, Sans fin,
  **Affrontement** (seulement quand une course a au moins deux joueurs ; l'hôte la lance d'ici). Défis arrive par
  le bord droit ; chaque écran ou panneau arrive du côté de son bouton (`go_from`, `_slide`). Un toucher ailleurs,
  ou Retour, range la liste et les défis.
- **Boutons en bois** (les dessins PixelLab du 22/11, `assets/src/ui-bois`) : `tools/make_wood_ui.py` en tire tout
  le jeu de boutons (hauteurs 30, 38, 50, 58, carrés 28, 36, 42, quatre états, vert, rouge, or) dans
  `assets/img/ui-v2/wood/`, rangées entières ajoutées ou ôtées au milieu, jamais étirées. Les boutons de pierre
  deviennent le skin **« Pierre du temple »** (cible « Boutons » de l'onglet Skins : urnes ou éclats) ; le porter
  ou l'ôter reconstruit l'interface à l'écran suivant.
- **Temple en 3 couches** (PixelLab, sommet complété par retouche, `tools/split_temple.py`) : derrière le sol (la
  pyramide et son sanctuaire), sur le sol (le porche, sa porte bloquée de rochers, les marches), devant Pépito
  (deux piliers-jaguars : il passe derrière celui de droite). Sa porte reste au même endroit du monde.
- **Monticules** : celui de la 0.49 assombri et trois nouveaux (pierres gravées, souche creuse, tronc couché),
  tous ramenés à la même clarté (`tools/prep_mounds.py`), en alternance derrière les plateformes.
- **Plateformes en pente** (fixe) dans les passages en hauteur de la forêt : la moitié reste plate, les autres
  montent de 0,7 ou 1,1 m, seule la dernière d'un passage peut descendre ; ses pièces et sa gemme suivent la
  pente ; dessinée colonne par colonne (`render._sloped`). Réglages : `[plateformes]` d'`equilibrage.txt`.
  `tests/slopes_050.gd` (21 vérifications).
- **Écran de chargement** (navigateur) : `html/shell.src.html`, avec ses images intégrées par `html/make_shell.py`
  dans `html/shell.html` (le gabarit de l'export web). Une des quatre poursuites au hasard (pygmées après Pépito,
  un missile après tout le monde, un pygmée après le gorille, le rhino après deux pygmées) : ils arrivent par la
  gauche, courent sur place pendant le chargement, repartent à droite quand l'accueil est prêt
  (`window.jlReady`), puis fondu. Pépito est dessiné par le jeu lui-même (`tools/make_loading_sprites.gd`).
  Pour l'essayer : `?chase=1` à `4` choisit la poursuite, `?lent=5` les laisse courir 5 s au moins.
- **Relique jaguar** (proposition B3) : sans son treillis ni ses lianes, coupée en cinq (`tools/cut_relic.py`,
  `assets/img/relic/`) : cœur, couronne (jade), tête gauche (ambre), mâchoire (lune), tête droite (braise). Pas
  encore montrée dans le jeu.
- Bancs : t047 (la Corne de brousse) ne compte plus le gorille, qui perche à 400 et demande un double saut.

## 0.49.1

- **Fenêtre « Nouvelle version disponible »** au démarrage (navigateur) : quand `version.txt` en ligne est plus
  récent, l'accueil propose « Mettre à jour » (le jeu se recharge sans ses fichiers gardés, la partie reste) ou
  « Plus tard » (le « ! » de l'engrenage et le bouton de Réglages restent) ; une fois par session, et à l'arrivée
  à l'accueil si la réponse arrive pendant une course. Elle affiche aussi `nouveautes.txt` (copié à côté du jeu
  par `tools/publish_web.py` depuis `reglages/nouveautes.txt` : 4 lignes au plus, à réécrire à chaque version).
  Essayé dans le navigateur avec une fausse version 9.9.9 à côté du jeu.

## 0.49.0

Sa liste du 22/11 :
- **Histoire pour débuter** : **2 cœurs** ; **aucune amélioration** ni consommable ni couteau : l'Histoire donne
  son propre équipement, les **pouvoirs des morceaux de la relique** gagnés (`Game.story_kit`). La vitesse **ne
  monte plus pendant les dialogues** (horloge à part `run.pace_t`, arrêtée tant qu'ils parlent, seul ; à deux,
  inchangé) et s'arrête à **26 m/s**. **Un dialogue par essai** (`reglages/dialogues.txt` : « départ 2 »,
  « 1000 3 »…, puis à tour de rôle à partir du 2e ; « départ jade » une fois le jade gagné ; à deux, toujours le
  1er) : ils l'ont rattrapé, ramené sur la broche, et il recommence. Plus de boucle du temps : ce sont les
  **pygmées** qui le ramènent au temple (intro, messages de chute).
- **La relique en 5 morceaux** : le **cœur** (volé par Pépito, aucun pouvoir) et 4 morceaux dans le ventre des
  gardiens, chacun avec un pouvoir (`Game.RELIC_POWERS`) : **jade** (Vorace, double saut, dans le jeu), ambre
  (ruines, Esquive), lune (cité, Sablier), braise (donjon, Vol) : boss à faire. Vorace vaincue en Histoire :
  le jade est gardé (`save.relic`), son pouvoir sert aussitôt (`Game.grant`). Vorace repousse (c'est une fleur)
  tant que le gardien suivant n'existe pas. Image de la relique complète : `propositions/0.49/` (4 essais).
- **Ordre des dangers** : araignées dès 150 m, nuées dès 300 m, volants (Fonceurs, missiles, vagues) dès 400 m
  (`FROM_DARTS`), nids dès 900 m (`FROM_NESTS`). Mesuré : 150 / 321 / 403 / ~950 m (`tests/story_049.gd`).
- **Tout 15 % plus grand** : le héros, les dangers, les pièces et ce qui se ramasse (`Game.SIZE` : dessin
  `Render.big`, et leurs boîtes). Le décor, les montures et les boss gardent leur taille.
- **Vitesse plafonnée** à **30 m/s** en Run illimitée, la difficulté vient de l'**agencement** (`Game.pressure`,
  de 300 à 3300 m, 60 % en Histoire) : écarts plus courts (jamais moins qu'un atterrissage), plus de files
  d'araignées, de nids et de vagues, files jusqu'à 4. Mesuré (Run illimitée, 8 graines) : 0,81 danger/s à
  2 km (0,74 sans), 0,82 à 4 km (0,71), 1,01 à 7 km (0,83). Un volant de plus dans les grands écarts créait un
  passage impossible à deux : laissé à 0 (`volants dans les grands ecarts en plus`). Réglages :
  `reglages/equilibrage.txt` (`[course]`, `[vies]`, `[araignees]`, `[volants]`, `[nuees]`, `[agencement]`).
- **Décor forêt (PixelLab)** : un **monticule** (`hill-forest-3.png`) et **2 plateformes** (`isle-forest-1/2`,
  107 et 133 pixels à marcher, `ISLE_W` 240 / 300) taillées dans le même monticule, qui est toujours posé
  derrière elles (`Hill.isles`) : elles semblent sortir de la colline.
- **Maquettes** (toile https://claude.ai/artifact/WrgYidBBFJyPb4DYx81pcH) : accueil B avec un seul JOUER (B1 à
  B5), groupe à partir d'Amis A (A1 à A4), relique, décor, boutons en bois moussu (`propositions/0.49/`).
- Vérifié : bancs t045/t046/t047/t047b, équité à pied et au Vol, seul et à deux (200-1700 m et 2600-6100 m :
  0 passage impossible), Vorace équitable, même route et même allure à deux, `tests/story_049.gd` (69 vérifications),
  `tests/race_logic.gd`, serveur.

## 0.48.0

Sa liste du 21/11 (faite sans lui, il était absent : ses choix restent à faire, voir plus bas) :
- **Amis refait** (organisation A des maquettes) : la liste à gauche (un toucher ouvre la fiche), à droite ma
  fiche (code, **code QR**, **Partager** le lien, ajouter un ami, pseudo) ou celle de l'ami choisi (records,
  **Inviter à deux**, **Inviter à la course**, **Retirer** après confirmation). Onglets Amis / À deux /
  Course à 4. Le **lien d'ami** est la page du jeu avec `?ami=PEPI-XXXX` : ouvert (ou scanné avec l'appareil
  photo d'un téléphone), le jeu propose d'ajouter l'ami, puis retire le code de l'adresse. Le code QR est
  dessiné par le jeu (`scripts/qr.gd`, norme ISO 18004, niveau M) et relu par un décodeur écrit à part
  (versions 1 à 8 : 8 codes sur 8).
- **Course à 4** (`scripts/race.gd`) : l'hôte ouvre une course (4 lettres) et invite jusqu'à 3 amis ; chaque
  invité se relie à l'hôte (WebRTC, l'hôte fait passer ce que chacun dit aux autres). Au salon, chacun
  **mise** des pièces (`reglages/progression.txt`, `[course a 4]` : 0 / 50 / 100 / 250 / 500 / 1000) sur
  celui qui ira le plus loin, lui-même par défaut. Même route pour tous (`Game.coop_run`, l'équipement de
  l'hôte), les autres en **fantômes** pâles à leur couleur, avec leur nom (au bord de l'écran quand ils sont
  hors de vue, avec l'écart en mètres). Qui tombe est sorti ; la course est jouée quand tous sont tombés ou
  que le dernier ne peut plus être rattrapé (il continue pour son record). La **cagnotte** va à ceux qui ont
  misé sur le vainqueur, en proportion de leur mise ; personne : au vainqueur. Un joueur qui part : sa
  dernière distance compte ; l'hôte qui part : chacun récupère sa mise. Écran « Course à 4 » : places,
  mises, cagnotte, puis l'attente, puis le résultat (« Revanche », « Changer les mises »).
- **Panneaux de record** sur la route : « Record de Léo, 2 340 m » (bois) et « Ton record » (pierre dorée) à
  la distance de chacun, dans le mode joué ; plantés 70 m avant (`Game.place_signs`), 50 m minimum, 25 m
  entre deux, 12 au plus. Les records des amis sont relus au lancement (rien n'est créé sur le serveur pour
  qui n'y est jamais allé).
- **Menu de debug verrouillé** (`scripts/lock.gd`) : 5 touches sur le niveau demandent un mot de passe ; le
  jeu n'en garde que le sel et l'empreinte d'une clé PBKDF2-HMAC-SHA256 à 300 000 tours (≈ 0,5 s sur PC) :
  un décompilateur ne le donne pas. Bon mot de passe : l'appareil garde la clé (jamais le mot de passe), plus
  de question ; « Verrouiller cet appareil » dans le menu. 5 erreurs : 30 s d'attente. Les versions de
  débogage (éditeur, bancs) ne sont pas verrouillées ; les versions publiées ignorent `--test` (le banc
  donnait des améliorations) et les réglages de debug d'un appareil verrouillé. Nouveau mot de passe :
  `python tools/debug_password.py` ; l'actuel est **hors du dépôt**, dans
  `Projects/Archives/Jungle-Loop/mot-de-passe-debug.txt`.
- **Fiabilité** : la sauvegarde est écrite deux fois (`.new` puis la vraie) et relue sur l'autre copie si la
  première est coupée (avant, un arrêt pendant l'écriture effaçait toute la progression) ; `Coop.supported()`
  n'essaie plus WebRTC à chaque affichage ; **bouton Retour d'Android** (ferme ce qui est ouvert, met la
  course en pause, revient à l'accueil ; avant, Godot quittait le jeu en pleine course) ; **manette** (A saut,
  B Esquive, X Sablier, Y TNT, RB RedMonster, LB ou bas Bottes, Start pause) ; « Effacer mes données en
  ligne » (Réglages › Sauvegarde, demandé par les magasins).
- **Magasins** : préréglages Windows, Linux et Android, modèles d'export installés, dossier `store/` (fiches,
  questionnaires, images, scripts Steam, clé Android), politique de confidentialité sur le site
  (`confidentialite.html`). Voir `store/README.md`.
- **Serveur** : `friends/remove`, `race`, `room/join` (salon pour deux ou course), `room/leave`, `signal` avec
  destinataire, `player/delete` ; tables `members`, colonnes `rooms.kind`, `signals.dest`
  (`server/migrate-048.sql` pour la base en ligne) ; `node server/test.mjs` : 21 vérifications.
- Essais : `tests/race_logic.gd` (la course sans réseau : 19 vérifications), `-- --bac --test --tour48
  --shots=<dossier>` (Amis, QR, retirer, course, panneaux, fantômes, mot de passe ; `--mock` : seulement les
  fonds des maquettes), course réelle dans 4 navigateurs (`race=host|guest`, `friends=`, `bet=`, `on=`,
  `die=`).
- Maquettes (accueil, amis, course, idées de boss) : https://claude.ai/artifact/WrgYidBBFJyPb4DYx81pcH .

## 0.47.0

Ses choix du 21/11 (l'équilibrage complet, la suite du jeu) :
- **Objets sur la route** : plus de vies volantes ; une plume de toucan (change un défi, 3 au plus), une urne
  (une par course au plus) ; les lanternes de la forêt allumées sont comptées.
- **Consommables** en stock : Bouclier, Aimant simple, Idole dorée (+50 % de pièces), Corne de brousse (une
  monture à la sortie) ; proposés 3 s à la sortie du temple, on en prend un. Le Couteau suisse sert à l'évasion.
- **Capture partout** (seul, hors boss) : les pygmées reviennent le chercher, même après leur demi-tour, même en
  Run illimitée. **Évasion** avec un couteau : un curseur, une zone, des cordes ; la zone grandit avec les
  lanternes, l'évasion durcit à chaque fois dans la même course.
- **Urnes** : une par niveau (en plus des pièces), ouvertes dans le Trésor (bouton de l'accueil) ; commune, rare,
  légendaire ; garanties (rare /10, légendaire /50) ; les doublons donnent des éclats.
- **Skins** standards en couleurs, faits en code (17) ; onglet Skins de la boutique (aperçu, porter, éclats).
- **Tambours des pygmées** : un mini-jeu de rythme quotidien (deux gros tambours, les coups tombent d'en haut),
  récompense selon le score.
- **Rééquilibrage** : premiers niveaux à 300, 500, 700 points ; défis longs payés selon l'effort, un seul à la
  fois ; la fin de boutique bien plus chère (le joueur moyen finit vers la course 725). Modèle :
  `tools/eco_model.py`.
- Icônes des nouveaux objets et du tambour : PixelLab (`assets/src/items-046.png`, `drum-047.png`).
- Essai : `-- --bac --test --tour47 --shots=<dossier>` (urnes, skins, offre, évasion, Tambours en images).

## 0.46.0

Ses retours du 20/11, 3e lot (l'équilibrage) :
- **Ses prix et niveaux** pour toutes les améliorations et celles des montures (`reglages/progression.txt`) ;
  RedMonster, absent de sa liste, garde les siens.
- **Défis nouveaux** : les mètres avec le Gorille, le Rhino, la Libellule (proposés une fois le record au-delà
  de 700 m), les missiles esquivés en une course et en tout. Un missile compte quand il passe derrière lui sans
  l'avoir touché (`missile`). Le même défi sur plusieurs lignes = ses paliers (`questSteps` dans la sauvegarde).
- **Deux rapports** dans le dépôt du site : `RAPPORT-ECONOMIE.md` (ce que donnent ses prix sur 800 courses) et
  `RAPPORT-SKINS.md` (la même chose avec des skins).

## 0.45.0

Ses retours du 20/11, 2e lot :
- **Missiles (volants)** : leur « ! » rejoint ta hauteur lentement, en retard (au plus 4 m/s, de moins en moins
  vite en approchant ; réglage `suivi`).
- **Sortie du temple (Histoire)** : après l'explosion, la caméra reste figée ; Pépito sort et court jusqu'au
  tiers de l'écran, les deux gardes sortent derrière lui à distance (0,7 s puis 1,1 s après l'explosion) ;
  puis la caméra le rattrape en 1 s (en douceur) et la course commence ; les gardes reviennent alors très vite
  juste derrière lui (environ 0,6 s) et le poursuivent. Leur position est maintenant tenue par le jeu
  (`Game._guards`), le dessin ne fait que les montrer.
- **Capturé** : seul, si Pépito se plante (dernier cœur) avec les gardes à ses trousses (avant leur
  demi-tour), ils lui sautent dessus ; un nuage de poussière de bagarre (des coups, des étoiles, sa chaussure,
  son poing, la lance, la massue qui en dépassent) ; puis il repart attaché sous une broche posée sur leurs
  têtes, ramené vers le temple, jusqu'à sortir de l'écran ; c'est la fin. La caméra recule un peu pour que la
  scène soit au milieu ; la photo est prise sur la broche. Composé avec les images existantes (PixelLab à 0
  génération ce jour-là). Après leur demi-tour, la mort reste la tête plantée.
- **Dialogues réécrits** (`reglages/dialogues.txt`) : au temple, Chef Massue, Pointu et Pépito (enfermés
  ensemble par leur propre éboulement, jusqu'au bâton rouge) ; à 1000 m, les os sous les fleurs, Vorace,
  « DEMI-TOUR, les chefs d'abord ! », et Pépito qui veut la mettre dans un vase. Format : « où | qui |
  réplique » ; le nom s'affiche au-dessus (Pépito en vert) ; les gardes font demi-tour à la réplique qui
  contient « DEMI-TOUR ».

## 0.44.0

Ses retours du 20/11 :
- **Histoire** : chaque réplique des gardes attend une touche (une touche affiche la réplique entière, la
  suivante passe ; « Touche pour continuer ») ; au temple, l'entrée explose après la dernière. À 1000 m, la
  distance s'arrête, la route n'est plus posée ; ils ne parlent qu'une fois la route vide devant lui (plus
  rien : ni créature, ni volant, ni nuée, ni objet, ni animal) ; une fois finis, la route revient depuis le
  bord droit et la distance repart. Plus de bâtons de TNT au temple. **Les gardes** (PixelLab : deux
  guerriers masqués de feuilles, une lance, une massue, chacun avec sa course en 8 images) sortent de
  l'entrée après l'explosion et le poursuivent sur le bord gauche, sans jamais l'atteindre ; à leur
  « DEMI-TOUR !! » ils font demi-tour et s'enfuient. Pur décor. À deux, rien ne change (répliques à leur
  temps, même route).
- **La fin, le comptage refait** : un seul panneau ; les mètres montent de 0 (lentement puis de plus en plus
  vite : 200 m en 0,5 s, 2300 m en 4 s, 6 s au plus), le nombre bat toutes les 0,8 s, de plus en plus fort ;
  puis un coup : il enfle et retombe, les pièces gagnées arrivent avec ; puis la barre de niveau (vite, puis
  de plus en plus lentement), le panneau des niveaux passés, et « Suivant ». Une touche n'importe où finit
  l'étape en cours. Un son pour les barres qui montent (niveau et défis), de plus en plus aigu.
- **Missiles (volants)** : leur « ! » dure 2 s (au lieu de 1) et suit ta hauteur pendant ce temps ; parti, il
  garde sa hauteur au-dessus du sol. Plusieurs « ! » sur une même ligne se mettent côte à côte. À pied, deux
  volants d'une vague ont 0,85 s d'écart au moins (chacun se saute).
- **Les nids d'araignées** (comme avec la libellule) : 4 ou 5 araignées à l'écran en même temps, 5 m
  d'écart : une basse à sauter ; au-dessus de ton saut, seulement des hors d'atteinte ; ailleurs au-dessus de
  ta tête, et dès 1500 m parfois une à hauteur de tête, loin du saut. ×6 parmi les motifs (`nids, poids`).
- **Objets volants** (vie, sablier) : une fois à l'écran, ils filent à 75 % de ta vitesse et zigzaguent
  bien plus (de 1,5 à 7,25 m, 0,7 s par aller).
- **La mort** : enfoncé plus profond (la tête ne se voit plus), un petit tas du sol lui-même autour de lui
  (il se fond dans le sol de chaque décor), un bruit plus fort, et ses jambes qui gigotent s'entendent.
- **Décor** : dans la forêt, plus de grand arbre ni de panneau juste derrière le sol ; la lanterne et les
  champignons s'allument par leurs propres pixels (plus de carré bleu) ; la lanterne frôlée s'allume
  franchement (un halo) et le reste 1,5 s. Au donjon, plus de murs en collines.
- **Cœurs** : une vie ramassée montrait un cœur perdu (les anciens cœurs comptaient encore) : corrigé.

## 0.43.0

Ses retours du 19/11, 2e lot :
- **La fin, animée** : d'abord un écran de comptage (« tally ») : les mètres défilent vite (avec un tic), les
  pièces, puis l'expérience gagnée et la barre de niveau qui monte ; à chaque niveau passé, un son, des
  confettis et « Niveau supérieur ! », puis le panneau du niveau et de ses récompenses (à fermer). « Suivant »
  (ou la touche de saut) passe à l'écran de fin : la photo de la chute arrive en tournant, chaque défi part
  de là où la course l'a trouvé et avance jusqu'à là où elle l'a laissé ; un défi réussi brille
  (« RÉUSSI ! +60 pièces +80 XP »), s'efface, et celui qui le remplace apparaît à sa place.
- **Réglages refaits, sans rien à faire défiler** : à gauche Son (musique, effets) et Image (qualité, plein
  écran, images par seconde) ; à droite trois onglets : Lisibilité (police pixel, contour rouge des dangers,
  signalements décalés), Sauvegarde (son code, son fichier, tout effacer ; pendant une course, elle attend
  la fin), Version (« Mettre à jour »). Tout tient aussi avec la police ronde.
- **Les collines redessinées** (PixelLab, 10 images gratuites du jour) : forêt, rochers moussus et racines en
  arche ; ruines, murs de pierres carrées effondrés ; donjon, murs avec une porte en bois cloutée ou une
  fenêtre à barreaux ; ville, immeubles éclairés et conteneurs rouillés. Posées côte à côte sur la longueur
  de la colline, un peu assombries. Originaux dans `assets/src/hills`, préparées par `tools/prep_hills.py`
  (rognées, sol des conteneurs ôté, mur entier des ruines cassé bloc par bloc). La route ne change pas.
- La pastille « ! » de la roue dentée et l'œil de la pause ont leur cadre de pierre.

## 0.42.0

Ses retours du 19/11 (1er lot ; l'écran de fin animé, les réglages et les collines suivent) :
- **Histoire : la scène du temple** : caméra figée, les gardes parlent (« Il a la relique ! CHOPEZ-LE !! », …,
  « pourquoi il nous lance des bâtons rouges ? ... » pendant que des bâtons de TNT volent hors du temple),
  puis l'entrée explose. Seul, un toucher passe la scène (après 1,2 s : pas un réflexe). **Dialogues en
  route** : à 1000 m, « Oh non Vorace ! DEMI-TOUR !! » puis « Mais il est fou il s'arrête pas ! » ; Pépito
  court toujours, la route est vide (ni obstacle, ni pièce, ni objet, ni nuée) d'un écran avant jusqu'à la
  fin du dialogue. Tout est dans **`reglages/dialogues.txt`** (« départ » ou une distance, une réplique par
  ligne). Texte seulement, pas de voix. À deux : mêmes endroits, même route.
- **Vorace arrive à 1500 m** (au lieu de 2000).
- **La mort** (seul) : projeté en avant en sifflant, il retombe la tête la première, plantée dans le sol, les
  jambes qui gigotent 1,4 s (un « boing »), puis la fin ; la photo est prise tête plantée. Avec le Dernier
  élan, ses rebonds finissent pareil.
- **Moustiques (nuées) plus fins** : mêmes couloirs, bestioles et bande rouge à 65 % du couloir (hitbox
  42 au lieu de 64) : plus de place dans le couloir libre (`nuees, epaisseur`).
- **Araignées en file plus espacées** : 1,15 s entre deux (au lieu de 0,9), 11 m au moins (au lieu de 8),
  autant après la file ; **et plus souvent** : files d'araignées ×5 (au lieu de ×3), vagues de volants
  (missiles en ville) ×3 (au lieu de ×1). Réglages `araignees` et `volants` (« poids »).
- **Caisses** : 50 pièces jetées devant Pépito (au lieu de 4), qui retombent et l'attendent
  (`caisse, pieces`).
- **Pause** : un œil en haut à droite cache le menu pour regarder le jeu (toujours en pause), un 2e appui le
  remet ; les réglages ouverts depuis la pause gardent la musique basse ; le panneau des défis ne déborde
  plus à droite (la barre de niveau passe sous le nom) ; sur l'accueil, une marge à droite.
- **Boutique** : les équipements rangés par niveau de déblocage.

## 0.41.0

- **Mettre à jour le jeu** (Réglages, Général, dans le navigateur) : le jeu lit `version.txt` à côté de lui
  (écrit par `tools/publish_web.py`) ; plus récente, il se recharge sans les fichiers gardés par le
  navigateur (service worker, caches, puis le jeu redemandé au serveur), la sauvegarde ne bouge pas. Déjà à
  jour, un 2e appui recharge quand même. Au lancement, un « ! » doré sur la roue dentée quand une version
  plus récente est en ligne. Le moteur (`index.wasm`) n'est pas retéléchargé.
- **À deux, les améliorations qui changent la vitesse s'appliquent aux deux en même temps** : Esquive,
  Sablier et RedMonster lancés par l'un partent aussi chez l'autre (message `act`, `Game.remote_act`), au
  même point de l'image, pour toute leur durée, avec la même recharge ; le Sprint, porté par les deux
  (équipement de l'hôte), entre dans la vitesse de pose de la route (`lay_speed`, `run.base`). Banc
  `coop_sync` : 0,1 m d'écart une fois les effets finis (16 m au plus fort pendant l'Esquive, le temps du
  message) ; `coop_road` : même route avec les actifs partagés, décalés de 0,1 s, et avec le Sprint.
  Restent coupés à deux : montures, sablier ramassable, pause, Relique altérée, gemmes du Trèfle, nuées.

## 0.40.0

- **Coop : le joueur 2 allait plus vite.** Cause : seul, une image plus longue que 34 ms ne compte que pour
  34 ms (le jeu ralentit au lieu de sauter) ; à deux, l'appareil le plus lent prenait donc du retard pour de
  bon. Banc `tests/coop_sync.gd` : 60 images/s contre 24 avec un à-coup toutes les 3 s, 304 m d'écart en
  75 s avant, 0,1 m maintenant. À deux, la course joue chaque instant du temps réel (`Coop.split` : pas de
  34 ms au plus, 12 par image au plus), et chaque message de position recale doucement les deux horloges.
  Essayé entre deux navigateurs, l'un ralenti exprès (45 ms perdues par image) : l'écart reste fixe.
- **Coop : le partenaire n'est plus saccadé.** 20 positions par seconde (au lieu de 15), datées du temps de
  sa course ; il est dessiné un peu dans le passé (0,1 à 0,2 s selon le réseau, `Coop.view`), entre ses
  deux positions les plus proches, et prolongé à sa vitesse si le réseau lâche. Le retard suit le réseau à
  10 % au plus (jamais d'à-coup). Banc : 0 à-coup sur 1 621 images (contre un à chaque image avant).
- **Inviter un ami** depuis la liste (bouton « Inviter ») : le jeu ouvre le salon et l'ami voit, sur
  n'importe quel écran hors course, « Pseudo t'invite à jouer à deux ! » (Rejoindre / Pas maintenant ;
  refusée, l'hôte le lit). Le salon à 4 lettres reste possible. Serveur : routes `invite`, `invites`,
  `invite/no`, `room/close`, table `invites` (2 min).
- **À deux, on lance depuis l'accueil** : une fois connectés, les deux reviennent à l'accueil (bandeau
  « À deux avec Pseudo », Quitter) ; l'hôte lance Jouer ou **Histoire**, l'invité voit ses boutons grisés.
  « Rejouer » relance pour les deux (chez l'invité : retour à l'accueil). Une nouvelle route à chaque course.
- **L'hôte choisit l'équipement** : ses objets et pouvoirs (avec leurs niveaux) vont aux deux, ceux de
  l'invité ne s'ajoutent pas ; l'accueil de l'invité montre les objets de l'hôte.
- **Histoire à deux** : Vorace est posée sur la route (`coop_xb`, `coop_xf`, `COOP_VIEW`) au lieu de
  l'écran, avec ses propres dés (elle vise chacun à part) ; ses nénuphars, ses gemmes bleues et les décors
  suivants tombent au même endroit sur les deux appareils. `tests/coop_road.gd` vérifie l'Histoire jusqu'à
  4,3 km (Vorace comprise) dans les mêmes cas que la Run illimitée.
- Rembobinage à deux : plus de drone laser ensuite (il aurait changé la route d'un seul).

## 0.39.0

- **Coop : la même route sur les deux appareils.** Son premier essai (téléphone 5G et PC, par le relais) :
  même décor, mais relief, plateformes, monstres et pièces différents. Causes trouvées par un banc qui joue
  la même graine comme deux appareils différents (`tests/coop_road.gd`) : l'écart entre deux motifs suivait la vitesse
  du moment où la route était posée (donc les images par seconde, la largeur de l'écran, la place de
  l'invité) ; le changement de décor était placé par rapport à l'écran ; l'or du temple et les nuées tiraient
  au dé de la route à un moment propre à chacun ; Sprint, Relique altérée et les gemmes du Trèfle changeaient
  la route d'un seul. Pour deux (`Game.coop_run`) : route posée pour la vitesse prévue à cet endroit
  (`lay_speed`), décor changé au premier motif après la borne (`coop_biome_x`), or du temple et volants
  « anti-campement » à leurs propres dés, sans nuées, ni Sprint, Relique altérée, RedMonster, ni gemmes du
  Trèfle sur la route. Le banc : même route dans tous les cas (120 i/s, i/s irrégulières, écran large,
  invité, sauts au hasard, chaque objet, tout à la fois) ; en solo rien ne change (même graine 993/993,
  passages équitables à pied et au Vol, et pour deux).
- Lettres du salon, pseudos, code ami et champs de saisie dans la police de Godot (`plain`, `tp`, `_plain`) :
  lisibles lettre par lettre.
- Nouvel objet **RedMonster** (bouton, niveau 8, 2500 / 5000 / 10000) : sa vitesse ×2 pendant 5 / 10 / 20 s,
  recharge 30 / 35 / 45 s depuis la gorgée ; la route reste posée pour sa vitesse à lui ; une traînée
  rouge derrière lui, la canette qui s'ouvre (son) ; touche R ; pas en coop (partagé depuis 0.41). Réglages dans
  `reglages/equilibrage.txt` (`redmonster, …`) et `progression.txt`. Icône `ico-monster` (PixelLab). La
  rangée de boutons en jeu a la place pour cinq.

## 0.38.0

- Champs de texte sur téléphone (pseudo, code d'un ami, lettres d'un salon) : le champ de Godot, sous le
  clavier du téléphone, n'écrivait parfois rien et le clavier le cachait ; un toucher ouvre maintenant la
  boîte du navigateur (`window.prompt`, lisible au-dessus du clavier), puis l'action part toute seule
  (comme OK). Sur PC, rien ne change ; Entrée valide aussi (`_field`, `_ask_text`, `_phone_web`).
- Coop : relais **TURN** de Cloudflare pour les réseaux qui bloquent la connexion directe (sa 5G contre
  son Wi-Fi : « réseau trop fermé » en boucle). Le serveur donne des accès de 4 h (route `ice`, fabriqués
  avec deux secrets posés une fois par `server/turn.ps1`, port 53 écarté) ; `coop.gd` les demande avant
  la poignée de main. Sans clé, liste vide et message clair (« le serveur n'a pas encore de relais »).
  `?relay` / `--relay` : par le relais ou pas du tout, pour l'essayer. Serveur publié (route `ice` en
  ligne), 12 vérifications.

## 0.37.0

- **Le serveur est en ligne** (https://jungle-loop.burnout293.workers.dev, noté dans `reglages/reseau.txt`
  par `server/deploy.ps1`) : le bouton **Amis** apparaît à l'accueil, la coop marche entre deux navigateurs
  (essayée en local seulement, pas encore entre deux téléphones).
- Accueil : les objets équipés sont affichés seuls, sans cadre ni case vide (plus de « + » pointillé) ;
  celui dont la note est ouverte est un peu plus grand et plus clair.
- Les bancs (`--test`, `?test` sur ce PC) et la sauvegarde d'essai (`--bac`, `?bac`) ne parlent jamais au vrai
  serveur, sauf adresse donnée exprès (`--net=`, `?net=`) : sinon chaque essai lui créait un joueur et ses
  scores (`Net.set_from_args`).

## 0.36.0

- Onglet **Montures** en sous-onglets (la maquette C, choisie parmi les quatre de `mockups/montures.html`) : en
  haut un onglet par animal (Gorille, Rhino, Libellule ; celui qui est ouvert en or, un animal désactivé
  grisé), puis trois lignes : « Sur le chemin » (sa case coche ou décoche tout de suite ; la ligne, elle,
  montre l'animal dans la fiche), Dompté, Aimant ; dessous, l'animal en grand, animé, sur une lueur chaude
  (grisé s'il est désactivé, la libellule flotte : `MountStage`). La fiche de droite décrit la ligne
  choisie, comme dans Équipements ; celle d'un animal ne dit plus que sa description (et « Désactivée »).
- Fiches de la boutique : elles ne grandissent plus quand le texte est long (le bas du cadre sortait de
  l'écran et les boutons n'étaient jamais au même endroit) ; l'aperçu se fait plus petit à la place, de
  ce qui manque, de moitié au plus (`_card_size`).
- Coop : « chacun son héros » confirmé (chaque téléphone fait courir le sien sur la même route).
- Serveur : `deploy.ps1` demande le sous-domaine workers.dev d'un compte tout neuf (wrangler ne le demande
  que s'il peut parler dans la fenêtre : le script le relance sans garder sa réponse, puis republie pour
  lire l'adresse) ; les avertissements de wrangler (sur stderr) ne l'arrêtent plus (PowerShell 5.1 en
  faisait une erreur fatale) ; il réessaie (5 fois, 20 s) quand Cloudflare ne « voit » pas encore un serveur
  tout juste reçu (« This Worker does not exist », 10007), refait toujours les tables (sans rien effacer) et
  vérifie à la fin que le serveur répond et que sa base a ses tables ; essayé de bout en bout avec un faux wrangler.

## 0.35.0

- Boutique : les fiches ne disent plus que la description (plus d'explication en dessous) ; avec deux
  boutons, celui du niveau suivant raccourcit son texte (`_fit_actions`) ; les anciens boutons sont retirés
  tout de suite (sinon, libérés plus tard, ils élargissaient la fiche pour de bon : le bouton Équiper sortait
  de l'écran) et la fiche reprend sa taille (`_card_size`).
- Multijoueur, prêt sauf le serveur en ligne :
  - `reglages/reseau.txt` : l'adresse du serveur (vide : rien n'est envoyé, pas de bouton Amis), les STUN,
    un TURN éventuel ; `?net=` dans l'adresse ou `--net=` pour un autre serveur (les essais) ;
  - écran **Amis** (bouton à côté de l'engrenage, icône `ico-friends`) : code ami, pseudo (route serveur
    `player/name`), ajout d'un ami, classement de la semaine ; onglet **Jouer à deux** : créer un salon (4
    lettres) ou le rejoindre, puis « Partir ! » chez l'hôte ;
  - `coop.gd` : poignée de main WebRTC par le salon (offre, réponse, candidats ICE), deux canaux (`ctl`
    fiable, `pos` sans renvoi), ping ; l'hôte envoie graine, décor de départ et niveau de route (le moins
    équipé des deux), les deux partent ensemble (délai moins la moitié du ping) ;
  - la course à deux (`run.coop`) : même route, ni monture, ni sablier, ni Esquive, ni Sablier (ils
    changeraient l'allure d'un seul) ; chacun envoie où il est 15 fois par seconde ; le partenaire est
    Pépito aux couleurs tournées (`MATE_SHADER`), l'invité court 1,75 m derrière l'hôte (`run.home`) ;
  - bulle : le dernier cœur perdu met dans une bulle qui suit l'autre au-dessus de lui ; il saute dedans pour
    le ramener (1 s d'invincibilité, un cœur) ; quand les deux flottent, la course s'arrête ; pas de pause ;
  - essayé de bout en bout entre deux navigateurs sur ce PC (serveur local, banc `coop=host|join`) : salon,
    connexion, départ ensemble (écart d'environ 3 m), bulles, sauvetages dans les deux sens, fin des deux côtés.
- Serveur : réponse vide aux questions préalables des navigateurs (CORS : un 204 avec un corps faisait
  planter le serveur, en local comme sur Cloudflare) ; `deploy.ps1` le met en ligne en une commande et écrit
  son adresse dans `reglages/reseau.txt`.

## 0.34.0

- Dossier `reglages/` : `equilibrage.txt` (nouveau, lu par `tune.gd`), `progression.txt` et `patterns.txt`
  (venus d'`assets/`). Les nombres de `game.gd` qu'il règle sont des `static var`.
- Histoire : +0,18 m/s par seconde (`STORY_GAIN` 7,2) ; `ZONE_SPEED` remplace `ZONE_EXTRA`.
- Vol : montée 12 m/s au niveau 1, 13,5 et 15 aux niveaux 2 et 3 (`FLAP_LV`, `flap()`), chute ×1,2.
- Araignées : jamais plus de 2 dans une colonne (`SPIDER_COLUMN`, `add_hover` refuse la troisième) ; rideau à
  deux araignées et deux places libres ; porte et tour de la libellule à deux.
- Montures : Dompté et Aimant pour chacune (`gorillaTamed`, `rhinoMagnet`…, champ `mount`), listés sous elle (dans son sous-onglet depuis 0.36)
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
tracks.json). Depuis la 0.48, aussi « Windows » et « Linux » (Steam, `export/windows`, `export/linux`, le
.pck dans l'exécutable) et « Android » (Play Store : AAB par Gradle, paquet `io.github.burnout293.jungleloop`,
couché, icônes `assets/store/`) ; leurs modèles d'export sont installés (Windows, Linux, Android). L'export
Android demande encore le JDK 17 et le SDK Android (`store/README.md`). Le web :

```
Godot --headless --path . --export-release "Web" export/web/index.html
```

Résultat : 44 Mo dans `export/web` (moteur `index.wasm` 39,5 Mo, jeu `index.pck` 6,5 Mo), jamais committé.
Puis `python tools/publish_web.py` : copie l'export dans le dépôt du site (`site/`) et y écrit
`version.txt` (la version de `main.gd`), que le jeu lit pour « Mettre à jour » (Réglages) et le « ! » sur la
roue dentée ; il refuse un export plus ancien que les scripts.
L'export est une appli installable (PWA) : plein écran, couchée, icônes `assets/pwa/`, écran de chargement
`assets/pwa/splash.png`, en-tête pour l'iPhone dans `html/head_include`. Le fichier de cache hors ligne se
renouvelle à chaque export.

Dans un navigateur, un vrai ou faux venu de JavaScript n'est pas toujours un booléen côté Godot : le
comparer à `true` arrête le script (et en export « release », sans un mot). D'où `_js_yes()` dans
`main.gd`, qui fait renvoyer 1 ou 0. Pour voir les erreurs d'un export web : `--export-debug`.
