# Jungle Loop — toutes les valeurs de jeu

État au 18/11/2026, **version Godot 0.32.0** (le jeu, à l'adresse principale depuis le 18/11 ; le code est
dans la branche `godot`, `scripts/game.gd`). L'ancienne version web (0.28.1, `js/`) reste jouable sur
`web.html` ; là où elle diffère, c'est dit. Les noms entre accents graves sont ceux du code Godot quand ils
existent, sinon ceux de js/. Le menu de debug (5 touches sur le niveau, à l'accueil) change en direct la vitesse, l'accélération, le Sprint, les distances minimum et la venue du boss, et affiche les mesures en jeu (vitesse, hauteur…). « Hitbox » y montre les boîtes que les règles testent. Dès qu'un champ y est changé : fin bandeau rouge « DEBUG » en haut de l'écran, champs changés en rouge, aucun record enregistré ; « Stopper le débogage » remet tout à l'origine. Pour changer une valeur, dis-moi la ligne et le nouveau chiffre
(« Sprint : +30 % », « mosquitos dès 300 m »…).

**Unités.** Le jeu compte en « unités » : 40 unités = 1 m, 2,25 unités = 1 pixel du dessin.
L'écran fait 720 unités de haut (18 m), le sol est à 630. Les vitesses sont données en m/s.

## 0. Modes

| Mode | Ce qui change | Où |
|---|---|---|
| Histoire | avec les boss (aujourd'hui Vorace vers 2000 m, dans la forêt) ; les ruines viennent après sa défaite, puis un décor tous les 2000 m dès 4000 m | `newRun(…, 'story')` |
| Run illimitée | aucun boss : un nouveau décor à 2000, 4000, 6000, 8000 m… | `newRun(…, 'endless')` |
| Records | un par mode (Histoire : l'ancien record ; Run illimitée : le sien) | `save.best`, `save.bestEndless` |

L'accueil a un bouton par mode ; « Rejouer » relance le dernier mode choisi.

## 1. Course

| Valeur | Aujourd'hui | Où (js/game.js) |
|---|---|---|
| Vitesse au départ | 9 m/s (360 u/s) ; en Histoire, chaque nouveau décor repart de là | `SPEED_BASE` |
| Accélération | +0,125 m/s chaque seconde | `SPEED.gain` |
| Vitesse maximale | aucune : 16,5 m/s après 1 min, 24 m/s après 2 min, 39 m/s après 4 min (Run illimitée ; en Histoire elle repart de 9 m/s à chaque décor, deux fois plus vite) | |
| **Sprint** | départ à 11 m/s : **+57 %** (+4 m/s, gardés toute la course) | `SPEED.sprint` |
| Sortie du temple | vitesse × 1,8 jusqu'à sa place à l'écran | `update` |
| Ruée | vitesse × 1,7 pendant 0,55 s | `update` |
| Vol à la sortie du temple | avec le Vol, Pépito décolle tout seul à l'explosion et vole à 3,75 m jusqu'au premier appui (4 s au plus) | `CRUISE` |
| Sablier | le monde tourne à 45 % ; ses 2 dernières secondes sont annoncées (6 tics de plus en plus rapprochés, teinte qui clignote, bords de l'écran qui flashent, « 2 » puis « 1 » au-dessus de Pépito), puis le monde reprend sa vitesse en douceur sur 0,35 s | `SLOW_WARN`, `SLOW_TICKS`, `SLOW_EASE` |
| Nouveau décor (Histoire) | la vitesse repart de 9 m/s et monte deux fois plus vite (0,25 m/s par seconde) | `zone_t`, `ZONE_ACCEL` |
| Changement de décor | Run illimitée : un décor tous les **800 m** ; Histoire : les ruines juste après la victoire sur Vorace (après la ligne de gemmes bleues), puis tant qu'il n'y a pas d'autre boss : le donjon à 4000 m, la cité à 6000 m, la forêt à 8000 m, et ainsi de suite tous les 2000 m ; avec le Gros sac à dos, 1 fois sur 2 le décor reste jusqu'à la marque suivante | `boss`, `ZONE` |
| Textes à l'écran | seulement pour le boss (« Vorace ! », « Ça tombe ! », « Écrasée ! », « Vorace est vaincue ! ») ; plus de nom de décor, de monture, de nuée ni de « Cours ! » | js/main.js |
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
| Dernier élan | lancé à 1,3 × ta vitesse (+0,15 par niveau, 10,5 m/s au moins), plus haut selon ta vitesse (20,5 à 28,75 m/s vers le haut), freiné de 12 % par seconde ; 1, 2 ou 3 rebonds, chacun à 80 % du précédent. Au niveau 1 à 14 m/s : 31 m (13 m avant) ; au niveau 3 à 30 m/s : 141 m | `LEAP_*`, `hit`, `update` |

## 4. Ce qui apparaît sur la route

Un motif à la fois, tiré au sort dans une liste. Chaque ligne a la même chance, une entrée en double compte double.

| Moment | Liste | Chance de chacun |
|---|---|---|
| 70 premiers mètres | hérisson ×2, pièces, plateforme, corniche, creux (sans danger pendant ces 70 m) | 6 entrées (hérisson 33 %) |
| Après Vorace | 9 m après les gemmes bleues : pièces seulement, puis 65 m de route douce (hérisson, pièces ×2, plateforme, corniche, creux) | `DEATH.calm`, `DEATH.easy` |
| Ensuite | hérisson ×2, doublé (deux hérissons), perchoir (plateforme au-dessus d'un hérisson), saut doré (hérisson sous une arche de pièces), volant, pièces, plateforme ×2, grotte, tronc, galerie, escalier de plateformes, corniche ×2, creux (un hérisson au fond), colline aux plateformes ×3, chaîne de plateformes ×3, montée de plateformes ×2 | 24 entrées, près de la moitié pour grimper |
| Dès 150 m | + suspendu ×3 | 18 entrées |
| Dessins de pièces | + dessin ×2 (ceux de `assets/patterns.txt` dont le sommet est atteignable) ; sans le Vol, + dessin dans le ciel ×1 (hors d'atteinte : l'envie du Vol) | +2 ou +3 entrées |
| Avec Double saut | + volant | +1 entrée |
| Sans le Vol (à pied) | le volant seul retiré ; + hérisson, + araignée jaune ×2 (dès 150 m, une arche de pièces au-dessus) : moins de volants, plus de dangers au sol | `spawn_pattern` |
| Avec Vol | + volant, + deux volants à la suite ×2, + araignée en hauteur ×2 (7,5 ; 9,4 ou 12 m, pièces juste dessous), + rideau d'araignées ×3 : une colonne sur 5 hauteurs (1,6 ; 4,2 ; 6,8 ; 9,4 ; 12 m) dont deux voisines manquent, 9 m après le début du motif, le passage à 2 places au plus de celui du rideau d'avant, des pièces dedans ; les araignées « suspendues » prennent aussi ces hauteurs (dès 1500 m, 1 fois sur 2) | `CURTAIN`, `SKY_HOVERS` |
| Monture en vue | jamais de grotte | |
| Libellule | trois fois plus de créatures en l'air (motifs plus fournis, écarts 2,5 fois plus courts), accélération ×2 | `spawn_ride`, `MOUNTS.dragonfly.gain` |
| Nuée annoncée ou en cours | pièces seulement, et aucun volant (les volants déjà posés plus loin sont retirés) | `followers`, `update` |
| Vorace (Histoire) | aucun danger, 4 motifs sur 5 sont ses nénuphars | |

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Écart entre deux motifs | le plus grand de 10,5 m et (vitesse × 0,72 s + 2,75 m), × hasard de 0,85 à 1,3 ; × 1,3 après des pièces. Compté en distance : la route garde sa densité quand la vitesse monte (2 dangers par 100 m vers 13-21 m/s, 3 à 4 au-delà) | `GAP` |
| Remplissage des grands écarts | écart de plus de 16 m : au milieu, un suspendu à hauteur de tête (dès 1500 m, 1 fois sur 2), sinon un volant (dès 150 m : 35 % avec le Vol, 15 % sans) | `GAP_FILL` |
| Dangers (rôles) | chacun a son dessin dans chaque décor (forêt / ruines / cité / donjon) | `ROLE`, js/render.js |
| Au sol, à sauter | hérisson / boule de ronces / robot à pointes à l'œil bleu clignotant (cité) / piège à loup ; 1,7 m × 1,35 m | `SPIKY` |
| Volant | coléoptère / vautour / missile / flèche : un gros panneau rouge « ! » qui pulse au bord droit (à 64 % de la largeur avec « Signalements décalés »), à sa hauteur, avec sa trajectoire en pointillés et un klaxon à deux tons joué deux fois (pas deux fois en moins de 1,6 s), pendant 1 s ; puis il traverse l'écran à 20 m/s de plus que toi | `DART`, `warnMark` |
| Hauteur des volants | 1,15 m (sauter) ou 4,25 m (rester au sol) ; avec Double saut aussi 7,25 m. **Avec le Vol** : ils visent ta hauteur au moment où leur « ! » s'affiche (entre 1,15 et 14 m), puis gardent cette hauteur | `DART_ALTS`, `aim`, `DART_TOP` |
| Pas de campement (Vol) | rester 2,6 s à la même hauteur (à 1,75 m près) amène un volant visé sur toi, puis un autre 1,6 s plus tard si tu y restes ; jamais deux volants à la fois, ni quand un danger à ta hauteur (à 4 m près) arrive déjà ; sans le Vol, rien de tel (le sol est ta place) | `CAMP_*`, `camp` |
| Araignées (0.32) | bien plus nombreuses : suspendu ×8 entrées, motif « araignées » (2 ou 3 à la suite : une jaune immobile, des rouges) ; **jaunes immobiles, rouges qui montent et descendent de 2,5 m de chaque côté en 2,4 s**, du sol jusqu'au plafond ; une colonne bouge d'un bloc | `SPIDER_*`, `add_hover` |
| Vagues de volants | 2 à 10 volants, de 0,9 s d'écart à 9 m/s jusqu'à 0,3 s à 30 m/s ; à pied à hauteur de tête (rester au sol), un bas seulement en premier avec 0,8 s avant le suivant (avec Double saut aussi au-dessus d'un petit saut) ; avec le Vol chacun vise ta hauteur ; rien d'autre sur la route pendant une vague | `WAVE_*`, `_wave` |
| Objets rares | une vie ou un frein (-4 m/s pour le reste de la course), dans une bulle qui zigzague entre 2,75 et 4,5 m (à portée de saut), un tous les 1 400 à 2 400 m environ (dès 300 m) | `BONUS_*`, `add_bonus`, `BRAKE` |
| Toujours esquivable | vérifié par un banc qui essaie toutes les façons de jouer image par image : à pied (sauts tapés ou tenus de 0,1 à 0,5 s) et avec le Vol (montée 10,75 m/s), 43 200 images chacun (12 min) : aucun passage impossible ; un campeur volant prend 17 à 21 coups par minute | bancs fair_bfs, fly_tests |
| Suspendu | araignée (forêt et ruines) / drone / chauve-souris, immobile dans le vide ; bas (milieu à 1,6 m, sauter) dès 150 m, à hauteur de tête (4,1 m, rester au sol) dès 1500 m, 4 fois sur 10 | `HOVER`, `LOW`, `HEAD`, `FROM` |
| Mise en avant des dangers | façon 5 (son choix du 17/11) : contour sombre et bord éclairé en haut à gauche sur tout ce qui fait mal, décor de fond et décor du chemin assombris ; liseré rouge en plus en option (Réglages, Accessibilité) | `LOOK`, `setDangerRim` |
| Décor à casser | grosse caisse (forêt) / jarre (ruines) / tonneau (donjon) / caisses (cité) ; posé derrière 12 % des motifs dès 70 m, un peu assombri ; inoffensif, il ne se casse qu'avec Brise-tout, la Ruée ou le rhino | `addDecor`, `DECOR_RATE` |
| Plateforme (6 à 6,35 m de long, à 3,4 m du sol, plus haut dans les chaînes et montées) | forêt et ruines : bloc de sol flottant, toujours devant une colline ; donjon : passerelle de planches pendue à deux chaînes qui montent jusqu'en haut ; cité : plateforme en lévitation sur 3 réacteurs (elle oscille de 0,1 m) ; pendant Vorace seulement : ses nénuphars volants (turquoise aux veines violettes, épines, œil orange), qui montent et descendent de 0,2 à 0,55 m et portent le héros | `PLAT_KIND`, `addPlatform`, `PAD` |
| Colline | décor sombre, jamais un obstacle : 12,5 à 37 m de large, 2,5 à 13 m de haut ; sa forme suit le décor (forêt : ronde et touffue ; ruines : colonnes brisées sur la crête ; donjon : roche ; cité : blocs et rares fenêtres) ; seule en décor après 22 % des motifs | `addHill`, `hill` |
| Bloc de sol flottant | 4,25 / 6 / 8,25 m de large, la terre du décor ; dans le motif « colline » : 2 ou 3 en escalier (2,6 m d'écart à pied, 3,1 m avec le Double saut), pièces dessus, hérisson dessous 65 % des fois, gemme 30 % | `ISLE_W`, `hills` |
| Lianes | forêt et ruines : des lianes pendent du haut de l'écran ici et là (un peu sombres, décor seulement) ; donjon : des chaînes à crochet ou anneau ; cité : des câbles à prise lumineuse et des câbles tendus en arc ; avec le Gorille : une liane tressée (une chaîne au donjon, un câble à pinces dans la cité) tout le long du haut de l'écran, où il se suspend | `drawHangingVines`, `drawVines`, `hangChain`, `hangCable` |
| Corniche | +3,4 m pendant 17,5 à 27,5 m, hérisson dessus 6 fois sur 10 | `STEP` |
| Creux | −1,65 m pendant 15 à 24 m | `HOLLOW` |
| Grotte | 20 à 30 m, toit à 2,5 m | `SLAB` |
| Tronc (Sphère) | 13 m de long, 2,65 m de haut | `LOG.w`, `LOG.h` |
| Dessin de pièces : sommet atteignable | 5 rangées à pied, 9 avec Double saut, 13 avec Vol (1,1 m par rangée) | `REACH`, `CELL` |
| Galerie (Sphère) | 20 à 30 m, 1,45 m sous le sol | `GALLERY` |

## 5. Pièces, gemmes, cœurs

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Traînée de pièces après un motif | 55 % des fois (toujours après « pièces ») ; formes : ligne, arche, zigzag (sauts), petite colline, double rangée (la seconde à 2,1 m, attrapée en courant) ; avec le Vol aussi la vague haute ; sans le Vol, parfois une ligne à 10 m de haut (dès 300 m) | `spawnPattern` |
| Longueur d'une traînée | 3 à 8 pièces, une tous les 1,1 m | `spawnPattern` |
| Plateforme seule | 4 pièces ; avec Gemmes dispersées, gemme 35 % (+20 % par niveau de Trèfle) | `spawnPattern` |
| Trèfle | avec Gemmes dispersées : gemme après une traînée, 12 % par niveau | `spawnPattern` |
| Gemmes | uniquement avec Gemmes dispersées équipé ; ailleurs, une pièce à la place. Exception : la victoire sur un boss (une de chaque couleur, et la ligne de 16 gemmes bleues) | `gem` |
| Gemme jaune / rouge / bleue | 5 / 10 / 20 pièces | `GEMS` |
| Couleur d'une gemme | jaune 60 %, rouge 30 %, bleue 10 % | `gemKind` |
| Gemmes dispersées | 1,2 % / 2,2 % / 3,5 % des pièces deviennent des gemmes | `SCATTER` |
| Décor cassé | 4 pièces projetées devant Pépito | `smash` |
| Créature détruite (Ruée) | 1 pièce ; nuée de moustiques : 3 | `destroy`, `followers` |
| Endroit exigu | une pièce tous les mètres ; avec Gemmes dispersées, 1 sur 6 est une gemme ; cœur 3 % | `tight` |
| Cœur ramassé sans vie à rendre | 25 pièces | `HEART_GOLD` |
| Explosion du temple | 30 pièces projetées sur les 35 premiers mètres environ, à ramasser ; posées avant que le relief sous elles soit construit, elles le suivent ensuite (montent sur une corniche, tombent dans un creux) | `BLAST_COINS`, `Coin.blast` |
| Aimant | portée 2,75 / 4,25 / 6 m | `MAGNET` |
| Portée de ramassage | une seule boîte : 1,1 m de chaque côté, de juste sous ses pieds jusqu'à 0,75 m au-dessus de sa tête (les feuilles de sa tête attrapent les pièces : en courant, jusqu'à 2,75 m du sol) ; roulé en Sphère, jusqu'à 1,6 m de haut | `COIN_HALF`, `COIN_TOP`, `BALL_REACH` |

## 6. Montures

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Première monture | entre 700 et 1000 m | `newRun` |
| Suivantes | 1300 à 1800 m après la précédente | `spawnPattern` |
| Après en avoir perdu une | pas avant 900 à 1200 m | `dismount` |
| Ami de la nature | ces distances divisées par 1,25 / 1,5 / 1,75 | `friend` |
| Laquelle | 1 chance sur 3 chacune | `spawnPattern` |
| Comment elles attendent | gorille tout en haut des lianes, pieds à 10 m du sol, avance à 45 % de ta vitesse : il faut le Vol (ou Double saut + Ressort) ; rhino immobile qui broute : il faut le toucher au sol, un saut le fait rater ; libellule qui zigzague entre 1,75 et 5,75 m (un aller en 1,6 s) et avance à 50 % de ta vitesse | `MOUNTS.ahead`, `PERCH`, `ZIG` |
| Vitesse sur une monture | gorille et libellule : la leur, départ à 7,5 m/s (libellule 8 m/s), puis + 0,6 m/s par seconde (gorille), + 1,4 (libellule, ×2 depuis la 0.32) ; **rhino : le double de ta vitesse**, atteint en 1 à 2 secondes. Ta propre vitesse continue de monter en parallèle ; quand la monture part, la vitesse remonte de 1,75 m/s par seconde jusqu'à la tienne | `MOUNTS.speed` (`mul`, `ramp` pour le rhino), `RAMP` |
| Gorille | saut 3,5 m (5,6 m maintenu), second saut jusqu'aux lianes | `MOUNTS.gorilla` |
| Route du Gorille | au sol, dans les lianes, les deux à la suite, enchaînement sol / lianes / sol, volants le long des lianes et au ras du sol, deux hérissons (on monte), pièces en balancier au-dessus d'un hérisson, diagonales, lignes : environ 4,5 dangers par 100 m (hérissons, suspendus, volants) | `spawnRide` |
| Rhino | saut 1,6 m (2,6 m maintenu) ; ramasse sur 3,9 m de large et 3,75 m de haut ; **invulnérable** : ce qui le touche est écrasé (créatures) ou rebondit ; il s'en va tout seul au bout de **8 s** (il clignote les 1,5 dernières secondes), sans rien te coûter | `MOUNTS.rhino` (`tough`, `time`) |
| Libellule | monte à 12 m/s, descend à 11 m/s | `update` |
| Zigzag de la Libellule | chaque pente dure 1,2 s | `spawnRide` |
| Formes de la Libellule | 6 fois sur 10 un dessin de `assets/patterns.txt`, sinon losange, carré, triangle ou cercle | `spawnRide` |

## 6 bis. Boss : Vorace, la plante carnivore

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Allure | derrière le sol, 198 × 250 pixels, en trois couches tirées d'une seule image (pattes, tête, corps) : le col de feuilles cache la tige, le ventre cache le haut des pattes, aucune jointure ne peut se voir. Pattes : marche en 4 images ; tête : fermée, s'ouvre, grande ouverte (acide qui bout), crache ; mort : tête écrasée puis morte, urne fendue, pattes qui cèdent | `drawVorace`, js/render.js ; découpe : tools/import_vorace.py |
| Apparition | en mode Histoire seulement : vers 2000 m (± 100 m), une fois par course, seulement dans la forêt ; aussi sur une monture ; la relique du sac de Pépito s'illumine ; tous les autres dangers disparaissent pendant le combat | `BOSS.at`, `bossAt` |
| Vitesse pendant le combat | 14 m/s ; ta propre vitesse continue de monter en parallèle | `BOSS.speed` |
| Après le combat | la vitesse remonte de 1,75 m/s par seconde jusqu'à la tienne (de 4 à 29 m/s : environ 14 s) | `RAMP` |
| Durée | 26 s d'attaques, puis un arbre l'écrase | `BOSS.fight` |
| Rythme | une attaque toutes les 1,65 s au début, jusqu'à 1,15 s ; la gueule s'ouvre et l'acide brille 0,45 s avant | `boss` |
| Gueule (départ des tirs) | 1,25 m après son bord gauche, 5,6 m du haut de l'écran | `BOSS.mouthX`, `BOSS.mouthY` |
| À pied (et gorille) | flaque, double flaque, boule basse (sauter), moyenne (rester au sol), haute (pas de grand saut), deux boules (haute + basse ou moyenne), pluie de 2 gouttes (ombre au sol avant) ; suspendu aux lianes : boules à hauteur des lianes | `boss` |
| Contre le Vol et la libellule | éventail de boules sur 6 couloirs jusqu'au plafond (1,6 à 14 m), deux couloirs voisins libres, à 2 places au plus de l'ouverture précédente ; tirs 1,3 fois plus fréquents | `FAN_LANES`, `FLY_PACE` |
| Toujours esquivable | chaque danger demande d'être en l'air (flaque, goutte, boule basse) ou au sol (boule moyenne) pendant un moment ; une attaque n'est lancée que si un petit saut (0,63 s en l'air) passe encore tout, avec 0,2 s entre deux gestes (0,26 s pour décider) ; sinon elle en choisit une autre, ou attend 0,2 s. Sur 30 combats simulés : aucune paire impossible | `_threats`, `_fits`, `_attack_fits` |
| Sur le rhino | flaques, boules basses et hautes, pluie (pas de boule moyenne) ; le rhino est invulnérable, mais il part au bout de 8 s | `boss` |
| Sur la libellule | éventail sur 5 couloirs avec 2 couloirs voisins libres, pluie, boules isolées | `boss` |
| Pendant le combat | aucun autre danger, mais 4 motifs sur 5 sont des nénuphars (un seul, deux en escalier, ou une chaîne) pour monter ; des traînées de pièces entre eux | `spawnPattern` |
| Fin | au ralenti : la course tombe à 30 % (environ 4 m/s) pendant 2,9 s ; un tronc tombe à plat sur sa couronne (0,9 s), l'urne se fend, les pattes cèdent et elle s'affaisse, puis tout s'enfonce dans le sol avec le tronc, sans trou | `DEATH`, `voraceFrame` |
| Récompense | une fois l'animation finie : 24 pièces et une gemme de chaque couleur jaillissent d'où elle a disparu ; puis, pendant que la vitesse remonte, une ligne de 16 gemmes bleues à hauteur de course, à 30 m environ (il suffit de continuer tout droit) ; puis le décor change, et la route revient peu à peu | `boss` |

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
| Gros sac à dos | 8 | 2400 | à chaque changement de décor (après Vorace, puis à chaque marque de 2000 m), 1 fois sur 2 il n'a pas lieu |
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
| Qualité « Max » (PC par défaut) | finesse ×4 au plus (ce que l'écran montre), image adoucie ; autant d'images/s que l'écran | `fit` |
| Qualité « Perf » (téléphone par défaut) | finesse ×2 au plus, pixels francs ; tenue à 60 images/s | `fit` |
| Qualité « Éco » | comme Perf, 30 images/s, moins de petites bêtes, de feuilles et de pluie | `fit`, `Ambient.lite` |
| Volumes | 0 à 10, 7 au départ | js/save.js |
| Musique d'accueil | « Mystère » (menu-mystere.mp3) | assets/music/tracks.json |
| Musique en pause | 30 % du volume | `DUCK`, js/audio.js |
| Fin de course | la musique ralentit et s'éteint en 0,85 s ; la musique du menu entre à 0,6 s | `music('over')`, js/audio.js |
| Avant-plan | deux rangées d'ombres fixes ; au plus 22 et 30 pixels en bas, 24 et 30 en haut (sur 320) | `silhouettes`, js/render.js |
| Changement de décor | mosaïque : carreaux de 16 pixels, étalés sur 120 pixels de part et d'autre | `TILE`, `SPREAD`, js/render.js |
| Interface | kit v2 (pierre, lianes, gemme turquoise), chaque image à la taille exacte de sa boîte : jamais étirée ni coupée (`assets/ui-v2`, `KIT_*` dans main.gd) ; le kit n'a ni vert ni or : le bouton choisi prend l'état « survol » (bleu-vert) | main.gd |
| Réglages | deux onglets : Général (son, police, qualité, plein écran, images par seconde) et Accessibilité (contour rouge des dangers ; signalements décalés : les alertes des Fonceurs à 64 % de la largeur au lieu du bord droit, loin du pouce) | index.html, `setAlertShift` |
