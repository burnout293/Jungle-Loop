# Jungle Loop — toutes les valeurs de jeu

État au 17/11/2026, version 0.22.0. Le menu de debug (5 touches sur le niveau, à l'accueil) change en direct la vitesse, l'accélération, le Sprint, les distances minimum et la venue du boss, et affiche les mesures en jeu (vitesse, hauteur…). Pour changer une valeur, dis-moi la ligne et le nouveau chiffre
(« Sprint : +30 % », « mosquitos dès 300 m »…).

**Unités.** Le jeu compte en « unités » : 40 unités = 1 m, 2,25 unités = 1 pixel du dessin.
L'écran fait 720 unités de haut (18 m), le sol est à 630. Les vitesses sont données en m/s.

## 1. Course

| Valeur | Aujourd'hui | Où (js/game.js) |
|---|---|---|
| Vitesse au départ | 7 m/s (280 u/s) | `SPEED.base` |
| Accélération | +0,125 m/s chaque seconde | `SPEED.gain` |
| Vitesse maximale | aucune : 14,5 m/s après 1 min, 22 m/s après 2 min, 37 m/s après 4 min | |
| **Sprint** | départ à 11 m/s : **+57 %** (+4 m/s, gardés toute la course) | `SPEED.sprint` |
| Sortie du temple | vitesse × 1,8 jusqu'à sa place à l'écran | `update` |
| Ruée | vitesse × 1,7 pendant 0,55 s | `update` |
| Sablier | le monde tourne à 45 % | `update` |
| Changement de décor | seulement après avoir vaincu un boss (aujourd'hui Vorace, une fois) ; avec le Gros sac à dos, 1 fois sur 2 le décor reste | `boss` |
| Ordre des décors | toujours forêt → ruines → donjon → cité, puis on reboucle sur la forêt | `NEXT_BIOME` |

## 2. Saut et vol

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Saut bref | 3 m de haut | élan `-760`, gravité `2400` |
| Saut maintenu | 4,8 m (gravité réduite à 1500 en montée) | `update` |
| Double saut | 2,6 m de plus (4,1 m maintenu) | élan `-700` |
| Ressort | élan +10 % par niveau, soit hauteur +21 % puis +44 % | `spring` |
| Vol | chaque appui : montée à 10,75 m/s tant qu'on tient | `FLAP` |
| Plafond | à 0,6 m du haut de l'écran | `CEIL` |
| Appui juste avant d'atterrir | retenu 0,12 s | `p.buf` |
| Corps du héros (collisions) | 0,7 m de large, 2 m de haut, 0,15 m de marge sur chaque obstacle | `HERO_HALF`, `HERO_H` |

## 3. Vies

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Cœurs | 1 (2 avec Cœur en plus) ; le compteur est caché quand il n'y en a qu'un | `HEARTS` |
| Invincible après un coup | 1,6 s | `hit` |
| Invincible après la perte d'une monture | 1,5 s | `dismount` |
| Rembobinage | 1 fois par course, rend tous les cœurs, 2 s d'invincibilité | `hit` |
| Dernier élan | 1, 2 ou 3 rebonds ; vitesse de départ ≥ 10,5 m/s, perd 4,25 m/s par seconde | `hit`, `update` |

## 4. Ce qui apparaît sur la route

Un motif à la fois, tiré au sort dans une liste. Chaque ligne a la même chance, une entrée en double compte double.

| Moment | Liste | Chance de chacun |
|---|---|---|
| 70 premiers mètres | hérisson ×2, pièces, plateforme | 25 % (hérisson 50 %) |
| Ensuite | hérisson ×3, doublé (deux hérissons), volant, pièces, plateforme, grotte, tronc, galerie, escalier, corniche ×2, creux (un hérisson au fond) | 14 entrées |
| Dès 500 m | + suspendu ×3 | 17 entrées |
| Dessins de pièces | + dessin ×2 (ceux de `assets/patterns.txt` dont le sommet est atteignable) | +2 entrées |
| Avec Double saut | + volant | +1 entrée |
| Avec Vol | + deux volants à la suite ×2 | +2 entrées |
| Monture en vue | jamais de grotte | |
| Nuée annoncée, ou Vorace | pièces seulement | |

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Écart entre deux motifs | le plus grand de 10,5 m et (vitesse × 0,72 s + 2,75 m), × hasard de 0,85 à 1,3 ; × 1,3 après des pièces. Compté en distance : la route garde sa densité quand la vitesse monte (2 dangers par 100 m vers 13-21 m/s, 3 à 4 au-delà) | `GAP` |
| Remplissage des grands écarts | écart de plus de 16 m : au milieu, un suspendu à hauteur de tête (dès 1500 m, 1 fois sur 2), sinon un volant bas (dès 300 m, 35 %) | `GAP.fill` |
| Dangers (rôles) | chacun a son dessin dans chaque décor (forêt / ruines / cité / donjon) | `ROLE`, js/render.js |
| Au sol, à sauter | hérisson / boule de ronces / robot à pointes à l'œil bleu clignotant (cité) / piège à loup ; 1,7 m × 1,35 m | `SPIKY` |
| Volant | coléoptère / vautour / missile / flèche : un « ! » au bord droit à sa hauteur pendant 1 s, puis il traverse l'écran à 20 m/s de plus que toi | `DART` |
| Hauteur des volants | 1,15 m (sauter) ou 4,25 m (rester au sol) ; avec Double saut aussi 7,25 m ; avec Vol aussi 10 et 12,75 m | `DART_ALTS` |
| Suspendu | araignée / idole de pierre / drone / chauve-souris, immobile dans le vide ; bas (milieu à 1,6 m, sauter) dès 500 m, à hauteur de tête (4,1 m, rester au sol) dès 1500 m, 4 fois sur 10 | `HOVER`, `LOW`, `HEAD`, `FROM` |
| Mise en avant des dangers | façon 5 (son choix du 17/11) : contour sombre et bord éclairé en haut à gauche sur tout ce qui fait mal, décor de fond et décor du chemin assombris ; liseré rouge en plus en option (Réglages, Affichage) | `LOOK`, `setDangerRim` |
| Décor à casser | grosse caisse (forêt) / jarre (ruines) / tonneau (donjon) / caisses (cité) ; posé derrière 30 % des motifs dès 70 m ; inoffensif, il ne se casse qu'avec Brise-tout, la Ruée ou le rhino | `addDecor`, `DECOR_RATE` |
| Plateforme | 6,35 m de long, à 3,4 m du sol | `PLAT_W` |
| Corniche | +3,4 m pendant 17,5 à 27,5 m, hérisson dessus 6 fois sur 10 | `STEP` |
| Creux | −1,65 m pendant 15 à 24 m | `HOLLOW` |
| Grotte | 20 à 30 m, toit à 2,5 m | `SLAB` |
| Tronc (Sphère) | 13 m de long, 2,65 m de haut | `LOG.w`, `LOG.h` |
| Dessin de pièces : sommet atteignable | 5 rangées à pied, 9 avec Double saut, 13 avec Vol (1,1 m par rangée) | `REACH`, `CELL` |
| Galerie (Sphère) | 20 à 30 m, 1,45 m sous le sol | `GALLERY` |

## 5. Pièces, gemmes, cœurs

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Traînée de pièces après un motif | 55 % des fois (toujours après « pièces ») | `spawnPattern` |
| Longueur d'une traînée | 3 à 8 pièces, une tous les 1,1 m | `spawnPattern` |
| Plateforme | 4 pièces ; avec Gemmes dispersées, gemme 35 % (+20 % par niveau de Trèfle) | `spawnPattern` |
| Trèfle | avec Gemmes dispersées : gemme après une traînée, 12 % par niveau | `spawnPattern` |
| Gemmes | uniquement avec Gemmes dispersées équipé ; ailleurs, une pièce à la place. Exception : la victoire sur un boss (une de chaque couleur, et l'arche bleue au-dessus du trou) | `gem` |
| Gemme jaune / rouge / bleue | 5 / 10 / 20 pièces | `GEMS` |
| Couleur d'une gemme | jaune 60 %, rouge 30 %, bleue 10 % | `gemKind` |
| Gemmes dispersées | 1,2 % / 2,2 % / 3,5 % des pièces deviennent des gemmes | `SCATTER` |
| Décor cassé | 4 pièces projetées devant Pépito | `smash` |
| Créature détruite (Ruée) | 1 pièce ; nuée de moustiques : 3 | `destroy`, `followers` |
| Endroit exigu | une pièce tous les mètres ; avec Gemmes dispersées, 1 sur 6 est une gemme ; cœur 3 % | `tight` |
| Cœur ramassé sans vie à rendre | 25 pièces | `HEART_GOLD` |
| Explosion du temple | 30 pièces projetées sur les 35 premiers mètres environ, à ramasser | `BLAST_COINS` |
| Aimant | portée 2,75 / 4,25 / 6 m | `MAGNET` |
| Portée de ramassage | 1,1 m | `update` |

## 6. Montures

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Première monture | entre 700 et 1000 m | `newRun` |
| Suivantes | 1300 à 1800 m après la précédente | `spawnPattern` |
| Après en avoir perdu une | pas avant 900 à 1200 m | `dismount` |
| Ami de la nature | ces distances divisées par 1,25 / 1,5 / 1,75 | `friend` |
| Laquelle | 1 chance sur 3 chacune | `spawnPattern` |
| Comment elles attendent | gorille tout en haut des lianes, pieds à 10 m du sol, avance à 45 % de ta vitesse : il faut le Vol (ou Double saut + Ressort) ; rhino immobile qui broute : il faut le toucher au sol, un saut le fait rater ; libellule qui zigzague entre 1,75 et 5,75 m (un aller en 1,6 s) et avance à 50 % de ta vitesse | `MOUNTS.ahead`, `PERCH`, `ZIG` |
| Vitesse sur une monture | la sienne : départ à 7,5 m/s (libellule 8 m/s), puis + 0,6 m/s par seconde (gorille), + 1,1 (rhino), + 0,7 (libellule). Ta propre vitesse continue de monter en parallèle ; quand la monture part, la vitesse remonte de 1,75 m/s par seconde jusqu'à la tienne | `MOUNTS.speed`, `RAMP` |
| Gorille | saut 3,5 m (5,6 m maintenu), second saut jusqu'aux lianes | `MOUNTS.gorilla` |
| Rhino | saut 1,6 m (2,6 m maintenu) ; ramasse sur 3,9 m de large et 3,75 m de haut | `MOUNTS.rhino` |
| Libellule | monte à 12 m/s, descend à 11 m/s | `update` |
| Zigzag de la Libellule | chaque pente dure 1,2 s | `spawnRide` |
| Formes de la Libellule | 6 fois sur 10 un dessin de `assets/patterns.txt`, sinon losange, carré, triangle ou cercle | `spawnRide` |

## 6 bis. Boss : Vorace, la plante carnivore

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Allure | derrière le sol, 198 × 250 pixels, en trois couches tirées d'une seule image (pattes, tête, corps) : le col de feuilles cache la tige, le ventre cache le haut des pattes, aucune jointure ne peut se voir. Pattes : marche en 4 images ; tête : fermée, s'ouvre, grande ouverte (acide qui bout), crache ; mort : tête écrasée puis morte, urne fendue, pattes qui cèdent | `drawVorace`, js/render.js ; découpe : tools/import_vorace.py |
| Apparition | vers 2000 m (± 100 m), une fois par course, seulement dans la forêt ; aussi sur une monture ; la relique du sac de Pépito s'illumine ; tous les autres dangers disparaissent pendant le combat | `BOSS.at`, `bossAt` |
| Vitesse pendant le combat | 14 m/s ; ta propre vitesse continue de monter en parallèle | `BOSS.speed` |
| Après le combat | la vitesse remonte de 1,75 m/s par seconde jusqu'à la tienne (de 14 à 29 m/s : environ 9 s) | `RAMP` |
| Durée | 26 s d'attaques, puis un arbre l'écrase | `BOSS.fight` |
| Rythme | une attaque toutes les 1,65 s au début, jusqu'à 1,15 s ; la gueule s'ouvre et l'acide brille 0,45 s avant | `boss` |
| Gueule (départ des tirs) | 1,25 m après son bord gauche, 5,6 m du haut de l'écran | `BOSS.mouthX`, `BOSS.mouthY` |
| À pied (et gorille) | flaque, double flaque, boule basse (sauter), moyenne (rester au sol), haute (pas de grand saut), deux boules (haute + basse ou moyenne), pluie de 2 gouttes (ombre au sol avant), tentacule rampante (sauter) ; suspendu aux lianes : boules à hauteur des lianes | `boss` |
| Sur le rhino | flaques, boules basses et hautes, pluie, tentacule (pas de boule moyenne) | `boss` |
| Sur la libellule | éventail sur 5 couloirs avec 2 couloirs voisins libres, pluie, boules isolées | `boss` |
| Pièces | des traînées continuent d'apparaître pendant le combat | `spawnPattern` |
| Fin | un tronc tombe à plat sur sa couronne (0,9 s), l'urne se fend, les pattes cèdent et elle s'affaisse, puis tout s'enfonce dans le sol avec le tronc, sans trou : une ligne de 16 gemmes bleues à hauteur de course, il suffit de continuer tout droit | `boss`, `voraceFrame` |
| Récompense | 24 pièces et une gemme de chaque couleur, puis le décor change | `boss` |

## 7. Nuées (monstres suiveurs)

Moustiques en forêt, guêpes dans les ruines, feux follets au donjon : ils visent puis foncent. Dans la cité, de gros drones visent puis tirent un laser le long de leur couloir (de 0,25 à 0,7 s après la visée), sans foncer. La bande rouge d'alerte apparaît en fondu depuis la gauche, passe sous eux et s'efface juste derrière.

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Première nuée | entre 150 et 230 m | `newRun` |
| Suivantes | 170 à 300 m après | `followers` |
| Vagues par nuée | 1 ; +1 dans 60 % des cas après 450 m ; +1 dans 50 % des cas après 900 m | `followers` |
| Temps pour viser | 1,7 s la première vague, 1,15 s les suivantes | `followers` |
| Vitesse de la charge | 28,75 m/s | `FM.rush` |
| Couloirs | 5, de 2,75 m chacun | `FM.lanes`, `FM.step` |
| Niveau | distance ÷ 450 m, ± 0,6 de hasard, de 0 à 3 | `wave` |
| Niveau 0 / 1 / 2 / 3 | 1 couloir pris / 2 / tous sauf 2 voisins / tous sauf 1 | `wave` |
| Couloir toujours libre | parmi les 2 du bas à pied, 3 avec Double saut, 5 avec Vol | `wave` |
| Faune alcoolisée | 6 % / 10 % / 15 % des créatures et des nuées sont inoffensives | `DRUNK` |
| Laser des drones | 1 m d'épaisseur, allumé de 0,25 à 0,7 s | `LASER` |

## 8. Boutique

| Objet | Débloqué au niveau | Prix par niveau | Effet chiffré |
|---|---|---|---|
| Double saut | 2 | 480 |  |
| Ressort | 3 | 1000 / 2400 | +10 % d'élan par niveau |
| Aimant | 2 | 600 / 1600 / 3600 | 2,75 / 4,25 / 6 m |
| Trèfle | 4 | 1200 / 3200 | voir § 5 |
| Gemmes dispersées | 6 | 2000 / 4800 / 10000 | 1,2 / 2,2 / 3,5 % |
| Brise-tout | 3 | 1400 | casse le décor (caisses, jarres, tonneaux) : 4 pièces chacun |
| Cœur en plus | 7 | 3600 | 2 cœurs |
| Faune alcoolisée | 5 | 1600 / 3600 / 7200 | 6 / 10 / 15 % |
| Ami de la nature | 4 | 1200 / 2800 / 6000 | montures 1,25 / 1,5 / 1,75 fois plus tôt |
| Gros sac à dos | 8 | 2400 | après un boss, 1 fois sur 2 le décor ne change pas |
| Ruée | 5 | 1200 / 2800 / 5600 | recharge 14 / 10 / 7 s |
| Sablier | 7 | 1800 / 4000 | 3 / 4,5 s, recharge 20 s |
| Dernier élan | 6 | 1600 / 3600 / 7200 | 1 / 2 / 3 rebonds |
| Vol (pouvoir) | 10 | 4800 |  |
| Sprint (pouvoir) | 8 | 4000 | +4 m/s |
| Sphère (pouvoir) | 10 | 6000 |  |
| Rembobinage | 12 | 10000 | 1 fois par course |

Emplacements d'équipement : 3 (`MAX_EQUIPPED`, js/save.js). Les prix sont dans `UPGRADES`.

## 9. Niveau et défis (js/progress.js)

| Valeur | Aujourd'hui |
|---|---|
| Expérience | 1 point par mètre, plus celle des défis |
| Niveau 1 → 2 | 200 points, puis 150 de plus à chaque niveau |
| Récompense d'un niveau | 20 pièces × le niveau atteint |
| Défi | 30 pièces et 40 XP, +15 pièces et +20 XP par palier |
| Palier | +1 tous les 3 défis réussis, 12 au plus |

| Défi | Objectif de départ | Par palier |
|---|---|---|
| Courir en une course | 150 m | +75 m |
| Courir en tout | 400 m | +250 m |
| Pièces en une course | 25 | +15 |
| Pièces en tout | 80 | +50 |
| Gemmes | 2 | +1 |
| Sauts | 30 | +20 |
| Plateformes | 3 | +2 |
| Courir sans être touché | 80 m | +50 m |
| Courses lancées | 3 | +1 |
| Champignons frôlés | 5 | +3 |
| Singes salués en une course | 2 | +1 |
| Décors ou créatures cassés | 4 | +3 |
| Montures | 1 | +1 |
| Nuées esquivées | 2 | +1 |

## 10. Affichage et son

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Image | 569 × 320 pixels de dessin, 16:9 | js/main.js |
| Lissage « Auto » | finesse de départ ×4 sur PC, ×3 sur téléphone ; baisse d'un cran sous 54 images/s | `watch` |
| Lissage « Net » | finesse ×2 au plus, pixels francs | `resize` |
| Volumes | 0 à 10, 7 au départ | js/save.js |
| Musique d'accueil | « Mystère » (menu-mystere.mp3) | assets/music/tracks.json |
| Musique en pause | 30 % du volume | `DUCK`, js/audio.js |
| Fin de course | la musique ralentit et s'éteint en 0,85 s ; la musique du menu entre à 0,6 s | `music('over')`, js/audio.js |
| Avant-plan | deux rangées d'ombres fixes ; au plus 22 et 30 pixels en bas, 24 et 30 en haut (sur 320) | `silhouettes`, js/render.js |
| Changement de décor | mosaïque : carreaux de 16 pixels, étalés sur 120 pixels de part et d'autre | `TILE`, `SPREAD`, js/render.js |
