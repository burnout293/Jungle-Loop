# Jungle Loop — toutes les valeurs de jeu

État au 24/11/2026, **version Godot 0.60.0** (le jeu, à l'adresse principale depuis le 18/11 ; le code est
dans la branche `godot`, `scripts/game.gd`). L'ancienne version web (0.28.1, `js/`) n'est plus en
ligne depuis la 0.51 (archivée) ; là où elle différait, c'est dit. Les noms entre accents graves sont ceux du code Godot quand ils
existent, sinon ceux de js/. Le menu de debug (5 touches sur le niveau, à l'accueil ; depuis la 0.48, un mot de passe le protège dans les versions publiées) change en direct la vitesse, l'accélération, le Sprint, les distances minimum et la venue du boss, et affiche les mesures en jeu (vitesse, hauteur…). « Hitbox » y montre les boîtes que les règles testent. Dès qu'un champ y est changé : fin bandeau rouge « DEBUG » en haut de l'écran, champs changés en rouge, aucun record enregistré ; « Stopper le débogage » remet tout à l'origine. Pour changer une valeur, dis-moi la ligne et le nouveau chiffre
(« Sprint : +30 % », « mosquitos dès 300 m »…).

**Tout se règle sans toucher au code**, dans le dossier `reglages/` du dépôt Godot : `equilibrage.txt`
(les chiffres de ce document : vitesses, sauts, Vol, objets, montures, araignées, volants, nuées, Vorace),
`progression.txt` (prix, niveaux requis, récompenses, défis) et `patterns.txt` (dessins de pièces). Le jeu
les lit à chaque lancement : changer un nombre, puis réexporter.

**Unités.** Le jeu compte en « unités » : 40 unités = 1 m, 2,25 unités = 1 pixel du dessin.
L'écran fait 720 unités de haut (18 m), le sol est à 630. Les vitesses sont données en m/s.

## 0. Modes

| Mode | Ce qui change | Où |
|---|---|---|
| Histoire | **0.49 : 2 cœurs, aucune amélioration ni consommable** : seulement les pouvoirs des morceaux de la relique gagnés (jade de Vorace : double saut ; ambre : Esquive ; lune : Sablier ; braise : Vol), gardés d'une course à l'autre ; **un dialogue par essai** (au temple et à 1000 m, `reglages/dialogues.txt`), les essais comptés depuis le dernier morceau gagné ; vitesse plafonnée à 26 m/s, et elle ne monte pas pendant les dialogues. Une scène au départ (caméra figée, les gardes et Pépito parlent, puis l'entrée du temple explose ; seul, chaque réplique attend une touche, l'explosion vient après la dernière) ; la caméra reste figée pendant qu'il sort et court jusqu'à 24 % de l'écran au-delà de sa place, les gardes sortent derrière lui 0,7 et 1,1 s après l'explosion, puis la caméra le rattrape en 1 s (0.45) ; les gardes (deux guerriers masqués, décor) reviennent alors juste derrière lui (5,2 et 7,1 m) et le poursuivent sur le bord gauche jusqu'à la réplique « DEMI-TOUR » ; des dialogues en route (`reglages/dialogues.txt`) ; avec les boss (aujourd'hui Vorace vers 1500 m, dans la forêt) ; les ruines viennent après sa défaite, puis un décor tous les 2000 m dès 4000 m | `newRun(…, 'story')` |
| Run illimitée (bouton « Jouer ») | aucun boss : un nouveau décor tous les 800 m ; la course part d'un décor tiré au hasard, déjà visible derrière l'écran d'accueil (le temple y est, immobile) | `newRun(…, 'endless')`, `endless_biome` |
| Records | un par mode (Histoire : l'ancien record ; Run illimitée : le sien) | `save.best`, `save.bestEndless` |

L'accueil a un bouton par mode ; « Rejouer » relance le dernier mode choisi.

## 1. Course

| Valeur | Aujourd'hui | Où (js/game.js) |
|---|---|---|
| Vitesse au départ | 9 m/s (360 u/s) ; en Histoire, chaque décor a la sienne (ligne « Nouveau décor ») | `SPEED_BASE` |
| Accélération | Run illimitée : +0,125 m/s chaque seconde ; Histoire : +0,18 m/s chaque seconde ; **0.49 : seul, elle s'arrête pendant les dialogues** (au temple et en route : horloge à part, `pace_t`) | `SPEED_GAIN`, `STORY_GAIN`, `pace_t` |
| Vitesse maximale | **0.49 : 30 m/s en Run illimitée** (atteinte vers 2 min 48 s, à 3,3 km) **et 26 m/s en Histoire** ; ensuite c'est l'agencement qui durcit (section 4, « Agencement ») ; les montures Gorille et Libellule aussi plafonnées, le Rhino et RedMonster restent à deux fois ta vitesse | `SPEED_CAP`, `STORY_CAP` |
| **Sprint** | départ à 11 m/s : **+57 %** (+4 m/s, gardés toute la course) | `SPEED.sprint` |
| Sortie du temple | vitesse × 1,8 jusqu'à sa place à l'écran | `update` |
| Esquive | +200 m/s pendant 0,2 s, soit 40 m d'un coup : casse tout ce qui se casse sur le chemin (créatures, décor, nuée), traverse le reste (l'acide de Vorace), ramasse les pièces traversées ; 0,3 s d'invincibilité ensuite | `DODGE_*`, `update` |
| Vol à la sortie du temple | avec le Vol, Pépito décolle tout seul à l'explosion et vole à 3,75 m jusqu'au premier appui (4 s au plus) | `CRUISE` |
| Sablier | le monde tourne à 45 % ; ses 2 dernières secondes sont annoncées (6 tics de plus en plus rapprochés, teinte qui clignote, bords de l'écran qui flashent, « 2 » puis « 1 » au-dessus de Pépito), puis le monde reprend sa vitesse en douceur sur 0,35 s | `SLOW_WARN`, `SLOW_TICKS`, `SLOW_EASE` |
| Nouveau décor (Histoire) | la vitesse repart de celle du décor : forêt 9 m/s, ruines 10, donjon 11, cité 12 (Sprint en plus), puis +0,18 m/s par seconde ; les sabliers ramassés ne comptent que pour le décor. Exemple : les ruines, de 10 m/s à environ 28,6 m/s au bout de leurs 2000 m (1 min 44) | `ZONE_SPEED`, `STORY_GAIN`, `zone_t` |
| Changement de décor | Run illimitée : un décor tous les **800 m** ; Histoire : les ruines juste après la victoire sur Vorace (après la ligne de gemmes bleues), puis tant qu'il n'y a pas d'autre boss : le donjon à 4000 m, la cité à 6000 m, la forêt à 8000 m, et ainsi de suite tous les 2000 m. Avec la **Relique altérée**, le décor ne change plus : à chaque changement, une bande de 12 m du décor suivant passe (ses deux bords en mosaïque), puis le décor revient | `boss`, `ZONE`, `strip_*`, `RELIC_STRIP` |
| Textes à l'écran | pour le boss (« Vorace ! », « Ça tombe ! », « Écrasée ! », « Vorace est vaincue ! ») et les dialogues en Histoire (`reglages/dialogues.txt` : « où | qui | réplique », le nom au-dessus, Pépito en vert ; au temple, à 1000 m ; les gardes font demi-tour à la réplique qui contient « DEMI-TOUR » ; chaque réplique tapée lettre à lettre, 40 lettres par seconde ; seul, elle reste jusqu'à une touche (une touche l'affiche entière, la suivante passe) ; à deux, de 2,2 à 4,8 s selon sa longueur ; en route, seul : la distance s'arrête à leur endroit, plus rien n'est posé, ils parlent une fois la route vide devant lui, puis la route revient depuis le bord droit ; à deux : la route est vide d'un écran avant jusqu'à la fin) ; jamais de voix | `say_*`, `talk_zones`, `road_held`, `road_clear` |
| La mort (seul) | au dernier cœur : projeté en avant (1,5 × ta vitesse, 19 m/s vers le haut), il retombe la tête la première, enfoncé jusqu'à la taille (la tête ne se voit plus) dans un petit tas du sol lui-même, les jambes qui gigotent 1,4 s (un bruit à chaque coup de pied) ; puis la fin ; la photo est prise tête plantée. En Histoire, les gardes à ses trousses (avant leur demi-tour) : ils lui sautent dessus (0,6 s), un nuage de bagarre jusqu'à 2,5 s, puis ramené vers le temple sous une broche à 6 m/s jusqu'à sortir de l'écran (7,5 s au plus) ; la caméra recule de 20 % de l'écran pendant ce temps, la distance ne bouge pas ; la photo est prise sur la broche (0.45) | `PLANT_*`, `CATCH_*`, `hit`, `_capture` |
| Ordre des décors | forêt → **pitons brumeux** (0.53, à la place des ruines) → donjon → cité, puis on reboucle sur la forêt ; les pitons : en Histoire après Vorace, en Run illimitée seulement avec le Vol porté, jamais en premier | `NEXT_BIOME`, `next_biome`, `sky_ok` |
| Pitons brumeux (0.53) | on n'y fait que voler : le Vol toujours là ; **0.54** : la brume ne fait pas mal, elle le renvoie vers le haut (15,5 m/s, 0,45 m dedans) ; sommets des pitons à 3,75 / 5,75 / 7,75 m au-dessus de la ligne du sol ; figures : rangée de 3 à 5 pitons à 0,95 s l'un de l'autre (14 m au moins), chacun un cran plus haut ou plus bas ; un deltaplane 6,25 m au-dessus d'un piton ; trois deltaplanes en biais (4,75 / 7,5 / 10,25 m) ; rideaux ; Fonceurs ; rien entre les figures ; les 150 premiers mètres, des pitons seulement ; 0.59 : en séries de 3 figures, puis une respiration (12 pièces, 17,5 m de plus) ; une flèche au bord droit au niveau du passage de la figure suivante, 1,5 s avant ; un pygmée en deltaplane au bord tire les fusées | `MIST_BOUNCE`, `MIST_SINK`, `PIN_*`, `THREAD_*`, `STAIR_HS`, `SKY_EASY`, `SKY_SERIES`, `SKY_BREATH`, `[pitons]` |
| Falaise (0.54) | entre la forêt et les pitons : le sol monte de 5 m sur 14 m, 14 m à plat, puis le bord ; il saute (8 m/s), tombe 0,5 s, puis le Vol le prend ; 42 m de pièces seulement après. Histoire, seul : les gardes reprennent la poursuite et parlent avant (« falaise »), puis le suivent 4 s en deltaplane après leurs répliques (« envol »), la caméra un quart d'écran en arrière | `CLIFF_*`, `GLIDE_*`, `lay_cliff` |

## 2. Saut et vol

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Saut bref | 3 m de haut | élan `-760`, gravité `2400` |
| Saut maintenu | 4,8 m (gravité réduite à 1500 en montée) | `update` |
| Double saut | 2,6 m de plus (4,1 m maintenu) | élan `-700` |
| Ressort | élan +10 % par niveau, soit hauteur +21 % puis +44 % | `spring` |
| Bottes de métal | il retombe 1,25 fois plus vite (la montée ne change pas : les sauts gardent leur hauteur) ; le bouton (ou S / ↓) le fait plonger à 37,5 m/s, ou secoue le sol sur place s'il y est : la secousse casse le décor et écrase les créatures au sol ou basses (jusqu'à 3,75 m) à 3 / 4,5 m autour de lui ; ce qu'il touche en plongeant est écrasé ; recharge 8 / 5 s | `BOOTS_*`, `quake` |
| Vol | chaque appui : montée à **12 m/s** tant qu'on tient (niveau 2 : 13,5 ; niveau 3 : 15) ; relâché : la montée s'arrête net, puis chute **1,2** fois plus rapide qu'un saut, jusqu'à toucher le sol | `FLAP_LV`, `VOL_STOP`, `VOL_DROP`, `flew` |
| Plafond | à 0,6 m du haut de l'écran | `CEIL` |
| Appui juste avant d'atterrir | retenu 0,12 s | `p.buf` |
| Corps du héros (collisions) | **0.49 : tout 15 % plus grand** (héros, dangers, pièces, objets ; dessins et boîtes) : 0,8 m de large, 2,3 m de haut, 0,15 m de marge sur chaque obstacle | `SIZE`, `HERO_HALF`, `HERO_H` |

## 3. Vies

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Cœurs | Run illimitée : 1, et un de plus par niveau de Vitalité (jusqu'à 4) ; le compteur est caché quand il n'y en a qu'un. **Histoire : 2** (0.49, sans Vitalité) | `HEARTS`, `STORY_HEARTS` |
| Invincible après un coup | 1,6 s | `hit` |
| Invincible après la perte d'une monture | 1,5 s | `dismount` |
| Rembobinage | 1 fois par course, rend tous les cœurs, 2 s d'invincibilité | `hit` |
| Dernier élan | lancé à 1,3 × ta vitesse (+0,15 par niveau, 10,5 m/s au moins), plus haut selon ta vitesse (20,5 à 28,75 m/s vers le haut), freiné de 12 % par seconde ; 1, 2 ou 3 rebonds, chacun à 80 % du précédent, puis la tête plantée dans le sol (ligne « La mort »). Au niveau 1 à 14 m/s : 31 m (13 m avant) ; au niveau 3 à 30 m/s : 141 m | `LEAP_*`, `hit`, `update` |

## 4. Ce qui apparaît sur la route

Un motif à la fois, tiré au sort dans une liste. Chaque ligne a la même chance, une entrée en double compte double.

| Moment | Liste | Chance de chacun |
|---|---|---|
| 70 premiers mètres | hérisson ×2, pièces, plateforme, corniche, creux (sans danger pendant ces 70 m) | 6 entrées (hérisson 33 %) |
| Après Vorace | 9 m après les gemmes bleues : pièces seulement, puis 65 m de route douce (hérisson, pièces ×2, plateforme, corniche, creux) | `DEATH.calm`, `DEATH.easy` |
| Ensuite | hérisson ×2, doublé (deux hérissons), perchoir (plateforme au-dessus d'un hérisson), saut doré (hérisson sous une arche de pièces), volant, pièces, plateforme ×2, tronc (0.54 : plus de grotte, le ponton de pierre sous lequel on ne pouvait pas sauter), galerie, escalier de plateformes, corniche ×2, creux (un hérisson au fond), colline aux plateformes ×3, chaîne de plateformes ×3, montée de plateformes ×2 | 24 entrées, près de la moitié pour grimper |
| Dès 150 m | + suspendu ×5, + file d'araignées ×5 | |
| **Ordre d'apparition (0.49)** | araignées dès **150 m**, nuées dès **300 m**, volants (Fonceurs, missiles) et leurs vagues dès **400 m** (aucun volant avant, même avec le Vol), nids d'araignées dès **900 m** ; mesuré sur 4 graines : 150, 321, 403 et ~950 m | `FROM_LOW`, `FM_FIRST`, `FROM_DARTS`, `FROM_NESTS` |
| **Plateformes en pente (0.50)** | dans la forêt, les plateformes des passages en hauteur : la moitié plates, les autres montent de 0,7 ou 1,1 m de leur bord gauche à leur bord droit ; seule la dernière d'un passage peut aussi descendre d'autant (au milieu, la suivante deviendrait trop haute pour un saut) ; ses pièces et sa gemme suivent la pente | `ISLE_FLAT`, `ISLE_UP`, `ISLE_DOWN`, `top_at` |
| **Agencement (0.49)** | une fois la vitesse plafonnée, la difficulté vient de l'agencement : de 300 m à 3300 m (en Histoire 60 % au plus), écarts entre motifs jusqu'à 25 % plus courts (le temps laissé pour retomber jusqu'à 12 % plus court), files d'araignées, nids et vagues jusqu'à deux fois plus fréquents, files jusqu'à 4 araignées (un volant de plus dans les grands écarts : réglage laissé à 0, il créait un passage impossible à deux). Mesuré (Run illimitée, 8 graines, sans monture ni sablier) : 0,81 danger/s à 2 km (0,74 sans), 0,82 à 4 km (0,71), 1,01 à 7 km (0,83) ; les bancs d'équité (à pied et au Vol, seul et à deux, 200-1700 m et 2600-6100 m) ne trouvent aucun passage impossible | `PRESS_*`, `pressure` |
| Dessins de pièces | + dessin ×2 (ceux de `assets/patterns.txt` dont le sommet est atteignable) ; sans le Vol, + dessin dans le ciel ×1 (hors d'atteinte : l'envie du Vol) | +2 ou +3 entrées |
| Avec Double saut | + volant | +1 entrée |
| Sans le Vol (à pied) | le volant seul retiré ; + hérisson, + araignée jaune ×2 (dès 150 m, une arche de pièces au-dessus) : moins de volants, plus de dangers au sol | `spawn_pattern` |
| Avec Vol | + volant, + deux volants à la suite ×2, + araignée en hauteur ×2 (7,5 ; 9,4 ou 12 m, pièces juste dessous), + rideau d'araignées ×4 : **deux** araignées rouges sur 4 hauteurs (3,2 ; 5,8 ; 8,4 ; 11 m), les deux autres places libres et voisines, 9 m après le début du motif, le passage à 2 places au plus de celui du rideau d'avant, des pièces dedans ; les araignées « suspendues » prennent aussi ces hauteurs (dès 1500 m, 1 fois sur 2) | `CURTAIN`, `SKY_HOVERS` |
| Monture en vue | jamais de grotte | |
| Libellule | trois fois plus de créatures en l'air (motifs plus fournis, écarts 2,5 fois plus courts), accélération ×2 | `spawn_ride`, `MOUNTS.dragonfly.gain` |
| Nuée annoncée ou en cours | pièces seulement, et aucun volant (les volants déjà posés plus loin sont retirés) | `followers`, `update` |
| Vorace (Histoire) | aucun danger, 4 motifs sur 5 sont ses nénuphars | |

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Écart entre deux motifs | le plus grand de 10,5 m et (vitesse × 0,72 s + 2,75 m), × hasard de 0,85 à 1,3 ; × 1,3 après des pièces. Compté en distance : la route garde sa densité quand la vitesse monte (2 dangers par 100 m vers 13-21 m/s, 3 à 4 au-delà) | `GAP` |
| Remplissage des grands écarts | écart de plus de 16 m : au milieu, un suspendu à hauteur de tête (dès 1500 m, 1 fois sur 2), sinon un volant (dès 400 m : 35 % avec le Vol, 15 % sans) | `GAP_FILL` |
| Dangers (rôles) | chacun a son dessin dans chaque décor (forêt / ruines / cité / donjon) | `ROLE`, js/render.js |
| Au sol, à sauter | hérisson / boule de ronces (verte depuis la 0.34 : elle se confondait avec les ruines) / robot à pointes à l'œil bleu clignotant (cité) / piège à loup (posé au sol, sa chaîne devant lui) ; 1,7 m × 1,35 m | `SPIKY`, `SINK` |
| Volant | coléoptère / vautour / missile / flèche : un gros panneau rouge « ! » qui pulse au bord droit (à 64 % de la largeur avec « Signalements décalés »), à sa hauteur, avec sa trajectoire en pointillés et un klaxon à deux tons joué deux fois (pas deux fois en moins de 1,6 s), pendant 2 s (0.44) ; 0.55 : à pied il reste à la hauteur où il est posé (1,15 m : sauter ; 4,25 m : rester au sol ; avec Double saut aussi 7,25 m), jamais celle du précédent, et si là où il te croisera (à 7,5 m près) cette hauteur rendait le passage impossible, il prend l'autre, ou ne vient pas ; avec le Vol, pendant ce temps il rejoint ta hauteur lentement, en retard (au plus 4 m/s ; `suivi`), se fige sa dernière seconde (0.54, `fige`), et s'il passerait à moins de 2 m de là où le précédent est passé, il est décalé de 3,2 m ; puis il traverse l'écran à 20 m/s de plus que toi, à la hauteur au-dessus du sol qu'il avait en partant ; plusieurs « ! » sur une même ligne se mettent côte à côte | `DART_*`, `warn_mark` |
| Hauteur des volants | ils arrivent à 1,15 m (sauter) ou 4,25 m (rester au sol), avec Double saut aussi 7,25 m ; depuis 0.44, tous suivent ta hauteur pendant leur « ! » (entre 1,15 et 14 m) et la gardent en partant | `DART_ALTS`, `DART_TRACK`, `DART_TOP` |
| Pas de campement (Vol) | rester 2,6 s à la même hauteur (à 1,75 m près) amène un volant visé sur toi, puis un autre 1,6 s plus tard si tu y restes ; jamais deux volants à la fois, ni quand un danger à ta hauteur (à 4 m près) arrive déjà ; sans le Vol, rien de tel (le sol est ta place) | `CAMP_*`, `camp` |
| Araignées (0.32) | bien plus nombreuses : suspendu ×8 entrées, motif « araignées » ×5 (0.42 ; 2 ou 3 à la suite : une jaune immobile, des rouges ; 1,15 s d'écart à la vitesse prévue, 11 m au moins, autant après la file) ; **nids** ×6 (0.44, comme avec la libellule) : 4 ou 5 araignées à 5 m d'écart, toutes à l'écran ensemble : une jaune basse à sauter, au-dessus de ton saut seulement des hors d'atteinte (11,65 m), ailleurs au-dessus de ta tête (6,8 ; 9,4 ou 11,65 m), dès 1500 m parfois une à hauteur de tête, loin du saut ; **jaunes immobiles, rouges qui montent et descendent de 2,5 m de chaque côté en 2,4 s**, du sol jusqu'au plafond ; une colonne bouge d'un bloc ; **jamais plus de 2 l'une au-dessus de l'autre** (0.34 : une troisième n'est pas posée ; aussi la porte et la tour de la libellule) | `SPIDER_*`, `SPIDER_COLUMN`, `add_hover` |
| Vagues de volants | 3 fois plus souvent qu'un motif simple (0.42 ; `vagues, poids`) ; 2 à 10 volants, de 0,9 s d'écart à 9 m/s jusqu'à 0,3 s à 30 m/s ; à pied 0,85 s d'écart au moins (0.55 : à pied chacun garde sa hauteur, jamais deux fois de suite la même ; chacun se saute) ; avec le Vol l'écart de la vague ; rien d'autre sur la route pendant une vague | `WAVE_*`, `_wave` |
| Objets rares | seul : un sablier ou une urne (0.47 : plus de vies volantes ; 0.55 : plus de plume, un sablier à sa place ; 85 % sablier, le reste une urne, une par course au plus, dès 600 m ; à deux : rien), qui zigzaguent entre 1,5 et 7,25 m (0,7 s par aller ; à portée de saut), un tous les 1 400 à 2 400 m environ (dès 300 m). Une fois à l'écran, ils avancent à **75 % de ta vitesse** (0.44, les deux) : ils restent longtemps en vue. Le sablier ôte **20 % de ta vitesse** du moment (pour le reste de la course ; en Histoire, du décor) | `BONUS_*`, `add_bonus`, `BRAKE_SHARE`, `BRAKE_PACE` |
| Toujours esquivable | vérifié par un banc qui essaie toutes les façons de jouer image par image : à pied (sauts tapés ou tenus de 0,1 à 0,5 s) et avec le Vol (tenu ou relâché à chaque image, montée 12 m/s, celle du niveau 1, vraie chute ×1,2), 43 200 images chacun (12 min) : aucun passage impossible ; un campeur volant prend 17 à 21 coups par minute | bancs fair_bfs, fly_tests |
| Suspendu | araignée (forêt et ruines) / drone / chauve-souris, immobile dans le vide ; bas (milieu à 1,6 m, sauter) dès 150 m, à hauteur de tête (4,1 m, rester au sol) dès 1500 m, 4 fois sur 10 | `HOVER`, `LOW`, `HEAD`, `FROM` |
| Mise en avant des dangers | façon 5 (son choix du 17/11) : contour sombre et bord éclairé en haut à gauche sur tout ce qui fait mal, décor de fond et décor du chemin assombris ; liseré rouge en plus en option (Réglages, Accessibilité) | `LOOK`, `setDangerRim` |
| Décor à casser | grosse caisse (forêt) / jarre (ruines) / tonneau (donjon) / caisses (cité) ; posé derrière 12 % des motifs dès 70 m, un peu assombri ; inoffensif, il ne se casse qu'avec Brise-tout, l'Esquive, les Bottes de métal, la TNT ou le rhino | `addDecor`, `DECOR_RATE` |
| Plateforme (6 à 6,35 m de long, à 3,4 m du sol, plus haut dans les chaînes et montées) | forêt et ruines : bloc de sol flottant, toujours devant une colline ; donjon : passerelle de planches pendue à deux chaînes qui montent jusqu'en haut ; cité : plateforme en lévitation sur 3 réacteurs (elle oscille de 0,1 m) ; pendant Vorace seulement : ses nénuphars volants (turquoise aux veines violettes, épines, œil orange), qui montent et descendent de 0,2 à 0,55 m et portent le héros | `PLAT_KIND`, `addPlatform`, `PAD` |
| Colline | décor un peu assombri, jamais un obstacle : 12,5 à 37 m de large ; des images posées côte à côte sur sa longueur (0.43, PixelLab) : forêt, rochers moussus et racines en arche ; ruines, murs de pierres carrées effondrés ; donjon, aucune (0.44 : ses murs ne se fondaient pas dans le décor) ; cité, immeubles éclairés et conteneurs ; seule en décor après 22 % des motifs | `add_hill`, `Art.HILL_SETS`, `draw_hills` |
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
| Créature détruite (Esquive, Bottes, TNT) | 1 pièce ; nuée de moustiques traversée par l'Esquive : 3 | `destroy`, `followers` |
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
| Laquelle | 1 chance sur 3 chacune, parmi celles qui sont activées (boutique, onglet Montures, sous-onglet de l'animal : case « Sur le chemin », ou Activer / Désactiver dans sa fiche) ; toutes désactivées : plus aucune monture | `run.mounts`, `save.mountsOff` |
| Améliorations | **chaque monture a les siennes** (0.34), achetées et coupées à part, dans son sous-onglet de l'onglet Montures : Gorille dompté, Aimant du gorille, Rhino dompté, Aimant du rhino, Libellule domptée, Aimant de la libellule | `<monture>Tamed`, `<monture>Magnet` |
| Dompté | niv. 1 / 2 : attrapée à 2,9 / 4 m d'elle au lieu de 1,75 m ; elle avance 30 / 60 % moins vite devant toi ; gorille atteint 1 / 2 m plus bas, rhino attrapé même en sautant (1,75 / 3,5 m au-dessus de lui), libellule à 1 / 2 m de plus de sa hauteur | `TAME_*` |
| Aimant (de la monture) | sur cette monture, les pièces viennent à toi de 4,25 / 6 m (niv. 1 / 2), ou plus si ton Aimant fait mieux | `MOUNT_MAGNET` |
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
| Apparition | en mode Histoire seulement : vers 1500 m (± 100 m), une fois par course, seulement dans la forêt ; aussi sur une monture ; la relique du sac de Pépito s'illumine ; tous les autres dangers disparaissent pendant le combat | `BOSS.at`, `bossAt` |
| Vitesse pendant le combat | 14 m/s ; ta propre vitesse continue de monter en parallèle | `BOSS.speed` |
| Après le combat | la vitesse remonte de 1,75 m/s par seconde jusqu'à la tienne (de 4 à 29 m/s : environ 14 s) | `RAMP` |
| Durée | 26 s d'attaques, puis un arbre l'écrase | `BOSS.fight` |
| Rythme | une attaque toutes les 1,65 s au début, jusqu'à 1,15 s ; la gueule s'ouvre et l'acide brille 0,45 s avant | `boss` |
| Place | 3,5 m plus à droite qu'avant la 0.33 (une partie de son corps hors de l'écran) : sa gueule est à 20,6 m de toi au lieu de 17,1 | `BOSS_BACK` |
| Gueule (départ des tirs) | 1,25 m après son bord gauche, 5,6 m du haut de l'écran ; une boule prend sa hauteur en 0,25 s (0,75 s avant) : sa hauteur se lit environ 1 s avant qu'elle t'atteigne (0,3 s avant) | `BOSS.mouthX`, `BOSS.mouthY`, `BALL_SETTLE` |
| À pied (et gorille) | flaque, double flaque, boule basse (sauter), moyenne (rester au sol), haute (pas de grand saut), deux boules (haute + basse ou moyenne), pluie de 2 gouttes (ombre au sol avant) ; suspendu aux lianes : boules à hauteur des lianes | `boss` |
| Contre le Vol et la libellule | éventail de boules sur 6 couloirs jusqu'au plafond (1,6 à 14 m), **trois** couloirs voisins libres, à 1 place au plus de l'ouverture précédente ; tirs 1,3 fois plus fréquents. Vérifié : 12 combats volés, toutes les façons de voler image par image, aucun moment sans passage | `FAN_LANES`, `FLY_PACE`, banc vorace_fly |
| Toujours esquivable | chaque danger demande d'être en l'air (flaque, goutte, boule basse) ou au sol (boule moyenne) pendant un moment ; une attaque n'est lancée que si un petit saut (0,63 s en l'air) passe encore tout, avec 0,2 s entre deux gestes (0,26 s pour décider) ; sinon elle en choisit une autre, ou attend 0,2 s. Sur 30 combats simulés : aucune paire impossible | `_threats`, `_fits`, `_attack_fits` |
| Sur le rhino | flaques, boules basses et hautes, pluie (pas de boule moyenne) ; le rhino est invulnérable, mais il part au bout de 8 s | `boss` |
| Sur la libellule | éventail sur 5 couloirs avec 2 couloirs voisins libres, pluie, boules isolées | `boss` |
| Pendant le combat | aucun autre danger, mais 4 motifs sur 5 sont des nénuphars (un seul, deux en escalier, ou une chaîne) pour monter ; des traînées de pièces entre eux | `spawnPattern` |
| Fin | au ralenti : la course tombe à 30 % (environ 4 m/s) pendant 2,9 s ; un tronc tombe à plat sur sa couronne (0,9 s), l'urne se fend, les pattes cèdent et elle s'affaisse, puis tout s'enfonce dans le sol avec le tronc, sans trou | `DEATH`, `voraceFrame` |
| Récompense | une fois l'animation finie : 24 pièces et une gemme de chaque couleur jaillissent d'où elle a disparu ; puis, pendant que la vitesse remonte, une ligne de 16 gemmes bleues à hauteur de course, à 30 m environ (il suffit de continuer tout droit) ; puis le décor change, et la route revient peu à peu | `boss` |

## 6 ter. Boss : l'Aigle, gardien des pitons (0.60)

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Quand | Histoire, seul : 700 m après le début des pitons ; le décor suivant attend qu'il soit battu ; pas à deux | `EAGLE_AT` |
| Lignes | basse, milieu, haute : leur milieu à 3,75 / 7,5 / 11,25 m au-dessus de la brume, 2,9 m de haut (Pépito en fait 2,3) | `EAGLE_LANES`, `EAGLE_BAND` |
| Phase 1 (ciel dégagé) | 6 ruées le long d'une ligne, annoncée 1,1 s avant (bande rouge, « ! »), à 37,5 m/s sur l'écran ; jamais deux fois la même ligne | `EAGLE_RUSHES`, `EAGLE_WARN`, `EAGLE_RUSH` |
| Phase 2 (nuages sombres) | 6 fois : ailes levées 1 s au-dessus du milieu et d'une autre ligne, fermées 0,35 s, puis 0,7 s de répit ; la ligne libre (basse ou haute) montrée par une flèche | `EAGLE_SLAMS`, `EAGLE_RAISE`, `EAGLE_SLAM`, `EAGLE_REST` |
| Phase 3 (orage) | il rugit sans attaquer ; 14 s de grêle, un grêlon toutes les 0,42 s, une fois en haut une fois en bas, tombant à 4,25 m/s | `EAGLE_STORM`, `EAGLE_HAIL`, `HAIL_V`, `HAIL_R` |
| La fin | la foudre, la colonne (son sommet à 8,25 m), Pépito ralentit et s'y pose ; la tête d'ambre : la Sphère ; une urne ; puis le donjon | `PILLAR_TOP`, `RELIC_POWERS` |
| Équité | `tests/eagle_060.gd` : en volant (montée 12 m/s, descente 22,5 m/s), un passage à chaque image, sur 3 graines | |

## 7. Nuées (monstres suiveurs)

Moustiques en forêt, guêpes dans les ruines, feux follets au donjon : ils visent puis foncent. Dans la cité, de gros drones visent puis tirent un laser le long de leur couloir, sans foncer ; 0.56 : trois bips (0,9, 0,6 et 0,3 s avant le tir) et un anneau qui se referme sur chaque drone, puis « SAUTE ! » au-dessus de toi dès le troisième si un couloir visé te toucherait debout ; le tir ne brûle que 0,15 s (de 0,3 à 0,45 s après la visée). La bande rouge d'alerte apparaît en fondu depuis la gauche, passe sous eux et s'efface juste derrière.

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Première nuée | entre 300 et 380 m (0.49 ; avant : 150-230) | `newRun` |
| Suivantes | 170 à 300 m après | `followers` |
| Vagues par nuée | 1 ; +1 dans 60 % des cas après 450 m ; +1 dans 50 % des cas après 900 m | `followers` |
| Temps pour viser | 1,7 s la première vague, 1,15 s les suivantes | `followers` |
| Vitesse de la charge | 28,75 m/s | `FM.rush` |
| Couloirs | 5, de 2,75 m chacun ; les bestioles et leur bande rouge n'en prennent que 65 % (0.42 : 1,05 m de haut au lieu de 1,6), au milieu du couloir | `FM_STEP`, `FM_THICK` |
| Niveau | distance ÷ 450 m, ± 0,6 de hasard, de 0 à 3 | `wave` |
| Niveau 0 / 1 / 2 / 3 | 1 couloir pris / 2 / tous sauf 2 voisins / tous sauf 1 | `wave` |
| Couloir toujours libre | parmi les 2 du bas à pied, 3 avec Double saut, 5 avec Vol | `wave` |
| Relique altérée | 6 % / 10 % / 15 % des créatures et des nuées sont inoffensives (et le décor ne change plus, § 1) | `DRUNK` |
| Laser des drones | 1 m d'épaisseur, allumé de 0,3 à 0,45 s après la visée (0.56 ; 0,25 à 0,7 avant) ; un saut simple au « SAUTE ! », ou 0,15 s après, passe | `LASER_*`, `laser_jump` |

## 8. Boutique

| Objet | Débloqué au niveau | Prix par niveau | Effet chiffré |
|---|---|---|---|
| Dernier élan | 2 | 400 / 600 / 800 | 1 / 2 / 3 rebonds |
| Ressort | 2 | 1000 / 2000 | +10 % d'élan par niveau |
| Brise-tout | 3 | 800 | casse le décor (caisses, jarres, tonneaux) : 50 pièces chacun, jetées devant toi |
| Double saut | 3 | 1600 |  |
| Aimant | 4 | 600 / 1600 / 3600 | 2,75 / 4,25 / 6 m |
| Gemmes dispersées | 4 | 1000 / 1500 / 3000 | 1,2 / 2,2 / 3,5 % |
| Fana de TNT (bouton) | 5 | 2000 / 4000 / 50000 | tout ce qui est devant toi saute (pas les boss) ; recharge 25 / 18 / 12 s |
| Relique altérée | 5 | 2600 / 3600 / 4600 | 6 / 10 / 15 % d'éthérées ; le décor ne change plus |
| Vol (pouvoir) | 5 | 4800 / 40000 / 120000 | montée 12 / 13,5 / 15 m/s |
| Sprint (pouvoir) | 5 | 4000 | +4 m/s |
| Sphère (pouvoir) | 5 | 60000 |  |
| Trèfle | 6 | 800 / 2400 | voir § 5 |
| Ami de la nature | 6 | 1200 / 2800 / 40000 | montures 1,25 / 1,5 / 1,75 fois plus tôt |
| Vitalité | 7 | 5000 / 60000 / 200000 | 2 / 3 / 4 cœurs |
| Esquive (bouton) | 8 | 1200 / 2800 / 40000 | 40 m d'un coup ; recharge 14 / 10 / 7 s |
| RedMonster (bouton) | 8 | 2500 / 30000 / 80000 | vitesse ×2 pendant 5 / 10 / 20 s ; recharge 30 / 35 / 45 s depuis la gorgée ; la route reste posée pour ta vitesse à toi ; à deux, pour les deux |
| Bottes de métal (bouton) | 10 | 2500 / 30000 | secousse à 3 / 4,5 m ; recharge 8 / 5 s |
| Sablier | 12 | 30000 / 100000 | 3 / 4,5 s, recharge 20 s |
| Rembobinage | 12 | 160000 | 1 fois par course |
| Corne de brousse (0.55) | 4 | 1500 / 4000 / 9000 | Run illimitée : sortie du temple sur le rhino, 300 / 500 / 800 m |
| Idole dorée (0.55) | 5 | 2000 / 6000 / 15000 | Run illimitée : pièces +25 / +50 / +75 % |
| Couteau suisse (0.54) | 4 | 1500 / 3500 / 8000 | capturé : 1 / 1 / 2 évasions par course sans prendre au stock ; niveau 2 et 3 : zone ×1,4, curseur et zone à 75 % ; jamais en Histoire |
| Gorille : Dompté ; Aimant (Montures) | 5 ; 5 | 1800 / 3200 ; 1000 / 2000 | voir § 6 ; aimant 4,25 / 6 m sur lui |
| Rhino : Dompté ; Aimant | 3 ; 3 | 800 / 2000 ; 1000 / 2000 | pareil |
| Libellule : Dompté ; Aimant | 7 ; 7 | 2500 / 4000 ; 1000 / 2000 | pareil |

Ses prix du 20/11 (0.46), la fin de boutique bien plus chère en 0.47 (les urnes, les défis et les Tambours, retirés en 0.55,
rapportent aussi) : tout acheter coûte 1 128 600 pièces ; le joueur moyen finit vers la course 725. Ce que
ça donne au fil des courses : `RAPPORT-ECONOMIE.md` (§ 6 pour la 0.47).

Emplacements d'équipement : 3 (`MAX_EQUIPPED`). **Prix et niveau requis se changent dans
`reglages/progression.txt`** (section `[ameliorations]`), leurs effets dans `reglages/equilibrage.txt`
(section `[objets]`) : le jeu les lit à chaque lancement, un réexport suffit. Le Gros sac à dos n'existe plus
(0.34) ; une sauvegarde qui l'avait, ou l'ancien Dompté / Aimant de monture, récupère leur prix en pièces.
Boutons en jeu, au clavier : Esquive Maj / E, Sablier A / Q, Bottes S / ↓, TNT F / T, RedMonster R.

## 9. Niveau et défis (`reglages/progression.txt`)

Tout ce tableau se règle dans **`reglages/progression.txt`** (dépôt Godot) : un fichier texte, une ligne par
élément, colonnes séparées par `|`. Le jeu le lit à chaque lancement ; une ligne absente ou mal écrite garde la
valeur d'origine. Après un changement : réexporter le jeu.

| Valeur | Aujourd'hui | Ligne du fichier |
|---|---|---|
| Expérience | 1 point tous les 20 m courus, plus celle des défis | `[niveaux] metres par point` |
| Niveau | 300, 500, 700 points pour les trois premiers (0.47), puis 1000 chaque niveau | `[niveaux] points par niveau` |
| Récompense d'un niveau | 20 pièces × le niveau atteint, et une urne (0.47) | `[niveaux] pieces par niveau` |
| Annonce | rien pendant la course ; à la fin, sur l'écran de comptage, la barre de niveau monte avec l'expérience gagnée (vite puis de plus en plus lentement, un son de plus en plus aigu ; son, confettis et « Niveau supérieur ! » à chaque niveau passé), puis un panneau : le niveau atteint, les pièces reçues, ce qui se débloque dans la boutique (retour au menu depuis la pause : le panneau seul) | `tally_play`, `show_levels` (main.gd) |
| Fin de course, l'écran | comptage d'abord, dans un seul panneau (0.44) : les mètres montent de 0, lentement puis de plus en plus vite (200 m en 0,5 s, 2300 m en 4 s, 6 s au plus), le nombre bat toutes les 0,8 s de plus en plus fort ; puis un coup (il enfle et retombe) avec les pièces gagnées et le record ; puis la barre de niveau, le panneau des niveaux passés, et « Suivant » (une touche n'importe où finit l'étape en cours) ; puis l'écran de fin : la photo arrive en tournant ; chaque défi avance de là où la course l'a trouvé à là où elle l'a laissé, un réussi brille (« RÉUSSI ! » et ce qu'il paie), s'efface, et son remplaçant apparaît | `tally_play`, `over_play` |
| Anciennes sauvegardes | expérience divisée par 20 au premier lancement de la 0.33 (1 point valait 1 m), défis en cours payés selon le fichier | `sanitize` (save.gd) |

| Défi | Objectif | Pièces | XP |
|---|---|---|---|
| Courir en une course | 800 m | 40 | 120 |
| Courir en tout | 3000 m | 60 | 200 |
| Pièces en une course | 60 | 40 | 120 |
| Pièces en tout | 300 | 60 | 200 |
| Gemmes | 4 | 50 | 150 |
| Sauts | 80 | 40 | 120 |
| Plateformes | 8 | 40 | 120 |
| Courir sans être touché | 300 m | 60 | 180 |
| Courses lancées | 5 | 30 | 100 |
| Champignons frôlés | 10 | 40 | 120 |
| Singes salués en une course | 3 | 50 | 150 |
| Décors ou créatures cassés | 10 | 50 | 150 |
| Montures | 2 | 60 | 180 |
| Nuées esquivées | 3 | 60 | 180 |
| Mètres avec le Gorille (0.46) | 2000 puis 20000 m | 60 puis 500 | 180 puis 600 |
| Mètres avec le Rhino (0.46) | 4000 puis 20000 m | 60 puis 600 | 180 puis 700 |
| Mètres avec la Libellule (0.46) | 3000 puis 15000 m | 60 puis 400 | 180 puis 500 |
| Missiles esquivés en une course (0.46) | 3 puis 15 | 20 puis 300 | 80 puis 350 |
| Missiles esquivés en tout (0.46) | 30 puis 80 | 180 puis 600 | 200 puis 800 |

Un défi absent du fichier garde l'ancienne règle des paliers (+1 palier tous les 3 défis réussis).
Plusieurs lignes du même défi dans le fichier : ses paliers (0.46). Le 1er est proposé d'abord ; une fois réussi,
ce défi revient au palier suivant ; après le dernier, le dernier revient (`questSteps` dans la sauvegarde). Les
défis de monture ne sont proposés qu'une fois ton record au-delà de 700 m (la 1re monture). Un missile compte
quand il passe derrière toi sans t'avoir touché (pas ceux de la Relique altérée, inoffensifs).

Défis longs (0.47) : la 5e colonne « long » dans le fichier ; jamais plus d'un à la fois (`longs a la fois`),
sinon ils prenaient les trois places. **0.55** : un défi peut être changé gratuitement une fois par jour (le bouton
sur chaque défi de l'accueil ; il disparaît une fois utilisé) ; les plumes de toucan n'existent plus.

## 9 ter. Course du jour (0.57, 0.58)

| Valeur | Aujourd'hui | Où |
|---|---|---|
| La course | une par jour, tirée de la date parmi celles de `reglages/courses-du-jour.txt` (la même pour tous ; une course peut avoir sa date), rejouable à volonté ; Jouer → Course du jour : sa fenêtre (règle, objets imposés, paliers, objet du jour, l'Or de la semaine), « Courir » | `daily.gd`, `_daily_panel` |
| Les courses (0.58) | 10 : Classique, Pressé (×1,3), Nuit dans la cité, Au fond du donjon, Un seul cœur, À pied, Ailé (Vol 2), Nid d'araignées (seulement elles), Ciel de volants (volants et hérissons), Grand prix (×1,15, 2 cœurs). Chacune : texte, objets imposés, quatre paliers, et ses règles (vitesse, décor, cœurs, montures, obstacles gardés, poids) | `courses-du-jour.txt` |
| Paliers (0.58) | Bronze, Argent, Or, Légende, propres à chaque course (repère : 400 / 1000 / 2000 / 3500 m ; plus courts si elle est dure, ex. Un seul cœur 250 / 600 / 1200 / 2200), en panneaux de leur couleur sur la route. Chacun une fois par jour, au passage (l'Or donne aussi le Bronze et l'Argent) | `Daily.claim`, `tier_signs` |
| Récompenses (0.58) | Bronze 300 pièces, Argent une urne commune, Or une urne rare, Légende une urne rare et l'objet du jour (un cosmétique rare ou légendaire tiré de la date ; déjà à toi : des pièces). L'Or 5 jours sur les 7 derniers : une urne légendaire | `[recompenses]` |
| Records | le meilleur du jour à part ; ne compte pas pour le record de Sans fin ni le classement des amis | `bank` |

## 9 bis. Objets, urnes, skins, évasion (0.47, 0.55)

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Monnaie (0.55) | une seule : les pièces. Plus de stock ni d'éclats ni de plumes : une sauvegarde d'avant reçoit 200 pièces par objet en stock, 25 par plume, 40 par éclat (une fois) ; Bouclier et Aimant simple supprimés ; Corne de brousse, Idole dorée et Couteau suisse sont des équipements (§ 8) | `SaveData.sanitize`, `STOCK_COINS` |
| Couteau suisse | équipement (0.54) ; 0.55 : plus en stock | `escape_start`, `SWISS_*` |
| Histoire, une chance par niveau (0.59) | niveau 1 (forêt) : l'évasion des pygmées offerte une fois sans couteau (pas pendant Vorace : il reste assommé) ; niveau 2 (pitons) : aucune, la longue chute (1 s hors de l'écran, puis du haut à 65 m/s jusqu'au sol de la forêt, 0,5 s pour s'y enfoncer, la tombe, 2,4 s, la fin) ; niveau 3 (donjon) : trois slimes derrière lui (2,75 m, puis tous les 1,75 m), l'un l'avale (0,55 s), s'extirper une fois (la même barre). Le niveau 1 n'a plus de conduits | `story_revive_ok`, `SKYFALL_*`, `SLIME_*` |
| Conduits du donjon (0.59) | ouverts à tous (roulé en boule, sans la Sphère) : propulseur (sortie à 28,75 m/s vers le haut, pièces à 9,5 m), bouche en l'air (à 3,75 / 6,25 / 8,25 m selon le saut ; descente sur 4,25 m), droits ; mur de feux follets : 35 % des nuées après 450 m, la 1re vague dans toutes les voies, un conduit dessous long de 2,8 s de course (on y entre n'importe où) | `PIPE_*`, `WISP_WALL` |
| Capture | seul, n'importe où, n'importe quel mode, hors boss : à la tête plantée, les pygmées accourent (de derrière l'écran s'ils n'étaient pas là, 0,8 s), puis le bond, la bagarre et la broche comme en 0.45 | `capture_ok`, `CATCH_*` |
| Évasion | sur la broche, avec un couteau : 5 s pour le prendre ; puis une barre où un curseur et une zone font des allers-retours ; une touche curseur dans la zone coupe une corde (3, une de plus par évasion déjà faite dans la course), à côté coûte 1,2 s ; 6 s en tout. La zone : 16 % de la barre, +1 % par lanterne allumée (40 % au plus), 15 % plus petite et curseur 25 % plus rapide par évasion déjà faite. Libre : un cœur, 2,5 s intouchable, la route devant vidée, la caméra le rattrape, les pygmées s'enfuient | `ESC_*`, `_release` |
| Lanternes | celles de la forêt, allumées en passant devant (déjà là), comptées pour l'évasion | `run.lanterns` |
| Urnes (0.58) | 100 % cosmétique : commune = 150-400 pièces (60) ou un objet commun (40) ; rare = un objet rare (50), commun (25) ou 1000-2000 pièces (25) ; légendaire = un objet légendaire, un rare et 3000-5000 pièces. Objets tirés parmi les 49 des trois familles (apparence, effets, social). Celles de la Course du jour (rareté connue) s'ouvrent d'abord | `[urnes]`, `Skins.URN_LOOKS` |
| Urnes (avant) | une par niveau, une sur la route parfois ; ouvertes dans le **Trésor** (bouton urne de l'accueil, avec leur nombre) : commune, rare 15 %, légendaire 2 % ; une rare au plus tard toutes les 10 urnes, une légendaire toutes les 50. Commune ou rare : une chose tirée au sort ; légendaire : tout. 0.55 : on les gagne (niveaux, la route, Vorace battue), jamais achetées ; commune 150-400 pièces (70) ou un skin (30), rare un skin ou 1000-2000 pièces, légendaire 3000-5000 pièces et un skin ; un skin déjà à toi : 400 pièces (commun) | `Treasure`, `[urnes]` |
| Cosmétiques (0.58) | Apparence : Feuilles (7), Chaussures, Sac à dos, Écharpe (4 chacun) ; Effets : Hélice du Vol, Traînée de course, Éclat du saut (4 chacun), Chute (pierre tombale, fleur, nuage) ; Social : Panneau de record (vu par tes amis), Fantôme (Affrontement), Émotes à deux (7, toutes disponibles). Communs 2500, rares 10 000, légendaires 50 000 pièces ; doublon 400 / 1500 / 5000 | `Skins.CATALOG`, `render.gd` |
| Skins | standards en couleurs (17 : Pépito 5, chaque monture 3, les pygmées 3), faits en code à partir des images (aucune image nouvelle) ; onglet Skins de la boutique : aperçu, « Porter », ou en pièces selon la rareté (0.55 : commun 2500, rare 10 000, légendaire 50 000) ; un doublon d'urne donne 400 / 1500 / 5000 pièces. Rares et légendaires : plus tard | `Skins`, `Treasure.cfg` |
| Tambours des pygmées (retirés en 0.55) | bouton tambour de l'accueil (point doré tant que celle du jour est à prendre) : 30 s, deux gros tambours en bas (grave à gauche, aigu à droite, ou les flèches), les coups tombent d'en haut ; parfait ±0,07 s (2 points), bien ±0,16 s (1) ; le rythme du jour est le même pour tous, de 96 à 132 battements par minute. Score en % : 30 % 300 pièces, 55 % une urne, 75 % un couteau suisse, 90 % une urne et 30 éclats de plus. Une récompense par jour, entraînement à volonté | `Drums`, `[tambours]` |

## 10 bis. Jouer à deux (coop)

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Où | navigateur seulement (WebRTC), deux téléphones, un salon sur le serveur (10 min au plus) : « Inviter » un ami de sa liste (il le voit sur n'importe quel écran hors course, 2 min au plus : Rejoindre / Pas maintenant), ou donner les 4 lettres du salon ; l'écran Amis n'apparaît qu'une fois l'adresse du serveur dans `reglages/reseau.txt` (en ligne depuis le 19/11 : https://jungle-loop.burnout293.workers.dev) ; jamais avec la sauvegarde d'essai ni pendant les bancs | `coop.gd`, `net.gd` |
| La course | une fois connectés, les deux reviennent à l'accueil (bandeau « À deux avec… ») : l'hôte lance Jouer (Run illimitée, son décor de départ) ou Histoire (Vorace comprise) ; boutons grisés chez l'invité ; une nouvelle graine à chaque course ; « Rejouer » relance pour les deux | `_coop_go`, `run.coop` |
| Équipement | celui de l'hôte (objets et pouvoirs, avec leurs niveaux) pour les deux, celui de l'invité ne s'ajoute pas ; la route est faite pour lui (à pied, Double saut ou Vol) | `kit`, `road_tier` |
| Partagé | Esquive, Sablier, RedMonster : lancés par l'un, ils partent aussi chez l'autre (au même point de l'image, le temps du message plus tard), pour toute leur durée, avec la même recharge ; le Sprint, porté par les deux, entre dans la vitesse de pose de la route | `remote_act`, `lay_speed` |
| Coupé en coop | montures, sablier ramassable, pause : ils changeraient l'allure d'un seul joueur ; Relique altérée, gemmes du Trèfle, nuées : ils changeraient la route d'un seul | `Game.coop_run` |
| Même route | la même graine pose exactement la même route sur les deux appareils, quels que soient leurs images par seconde, la largeur de l'écran, la place de chacun et ce qu'il a équipé : écarts posés pour la vitesse prévue à cet endroit, décor changé au premier motif après la borne ; en Histoire, Vorace arrive et tombe à des endroits de la route (sa fin un écran de 32 m plus loin), ses attaques sont propres à chacun ; seuls les volants envoyés à un joueur qui campe en vol lui sont propres | `lay_speed`, `coop_biome_x`, `COOP_VIEW` |
| Même allure | chaque appareil joue chaque instant du temps réel (pas de 34 ms au plus, 12 par image au plus : seul, une image lente ralentit le jeu, à deux elle laissait l'appareil lent derrière) ; chaque position reçue recale l'horloge de 4 ms au plus | `Coop.split`, `coop_owed` |
| Départ | l'hôte part 0,8 s après son choix, l'invité 0,8 s moins la moitié du ping après le message (ping mesuré toutes les 2 s) | `_coop_go`, `_coop_begin` |
| Le partenaire | Pépito aux couleurs tournées (feuilles rouges), l'invité un peu derrière l'hôte ; 20 positions par seconde, dessinées 0,1 à 0,2 s dans le passé (selon le réseau) entre les deux plus proches, prolongées à sa vitesse 0,25 s au plus si le réseau lâche | `MATE_SHADER`, `Coop.view` |
| Bulle | au dernier cœur perdu (après le Rembobinage s'il reste) : une bulle de 1,25 m de rayon, 3,75 m au-dessus du sol sous l'autre, 0,5 m derrière lui, qui ondule ; il faut sauter dedans (au sol, rien) ; ramené : 1 s d'invincibilité, un cœur | `BUBBLE_*`, `to_bubble`, `_rescue_check`, `back` |
| Fin | quand les deux sont dans une bulle (ou que l'autre est parti et qu'on flotte) ; chacun garde sa distance et ses pièces | `_float` |
| Connexion | 30 s pour se trouver ; directe si possible, sinon par le relais TURN de Cloudflare (accès de 4 h donnés par le serveur, clé posée par `server/turn.ps1`) ; sans relais, un message le dit | `LINK_TIME`, route `ice` |

## 10 ter. Affrontement (course à 4), mises et panneaux de record (0.48, 0.55)

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Où | navigateur seulement (WebRTC), comme à deux ; 0.55 : accueil › JOUER › AFFRONTEMENT (un groupe se crée s'il n'y en a pas) ; le groupe se gère dans Amis › Groupe (inviter, son code de 4 lettres, rejoindre, quitter) ; invitations reçues sur n'importe quel écran hors course | `race.gd`, `_race_invite` |
| Places | l'hôte et 3 invités ; chacun relié à l'hôte, qui fait passer à tous ce que dit chacun ; la salle du serveur dure 10 min (rouverte d'elle-même pour inviter après 9 min ; ceux qui sont reliés le restent) | `Race.SEATS`, `ROOM_LIFE` |
| Mises | 0.55 : chacun écrit combien (de 0 à 99 999 999 pièces, pas plus que ce qu'il a) ou prend 100 / 500 / 1000 / 5000, et sur qui (lui-même par défaut) ; payées au départ | `[course a 4]`, `Race.bet`, `BET_MAX` |
| Prêt (0.55) | chacun dit « Prêt ! » ; « Lancer » n'apparaît chez l'hôte que quand tous le sont ; après chaque course, chacun le redit | `all_ready`, `set_ready` |
| Gains (0.55) | qui a misé sur le vainqueur (le plus loin, égalité possible) reçoit le double de sa mise ; les autres la perdent ; rien d'autre n'est partagé | `Race.settle` |
| Écran (0.58, V1) | les places en haut (PRÊT / PAS PRÊT, la mise dessous ; place libre : « Inviter » chez l'hôte), trois panneaux égaux séparés (ta mise, l'équipement de la course, l'historique en tableau), « Prêt ! » et « Lancer » dessous | `_build_race` |
| Groupe (0.58, G1) | Amis › Groupe : quatre cartes (perso, HÔTE, lien : « connecté · 45 ms », « lent » dès 200 ms, « reconnexion… 2:42 »), « Expulser » pour l'hôte (avant une course ; l'expulsé ne revient que réinvité), « Inviter » sur une place libre ; le code, Créer, Rejoindre, Quitter dessous. Pas de changement d'hôte | `_build_group_g1`, `Race.kick`, `link_of` |
| Écran (0.55) | les places (le skin de chacun, prêt ou non, sa mise), tes pièces, l'équipement de la course (celui de l'hôte), l'historique des courses du groupe (distances, mises, gains, pièces ; 20 au plus) | `refresh_race`, `history` |
| Écran de fin (0.56) | après chaque course, pour tous : distance (★ le vainqueur), pièces ramassées (gardées par chacun), mise et sur qui, ce que la mise a donné (+ la mise, ou − la mise), bilan ; « Continuer » ramène au salon | `_race_recap`, `golds` |
| Tombé (0.57) | on regarde la course ; « Résultats » montre ou cache la course en direct, puis son résultat (qui s'ouvre seul) ; « Retour au salon » pour partir ; la chute des autres se voit chez tous ; « Lancer » est là pour tous, grisé « attente de l'hôte » | `_watch_res_fill`, `_draw_ghost` |
| La course | Run illimitée, même graine et même route pour tous, l'équipement de l'hôte pour tous, départ 3 s après « Lancer » ; chacun joue chaque instant du temps réel (comme à deux) ; pas de montures ni de capture ; qui tombe est sorti (pas de bulle) et **regarde les autres** (0.55 : la caméra suit le premier encore en course, une touche passe au suivant) jusqu'au résultat ; en course : l'équipement en haut à gauche, les mises de chacun en haut à droite, pas de pause | `_race_go`, `run.race`, `Game.spectate` |
| Fantômes | les autres, pâles (62 %), Pépito tourné à leur couleur (hôte doré, puis bleu, violet, vert ; 0.58 : la couleur qu'il a choisie, cosmétique « Fantôme »), leur nom au-dessus ; hors de vue : leur nom au bord de l'écran avec l'écart en mètres ; 12 positions par seconde, dessinées un peu dans le passé | `Race.views`, `_draw_ghost` |
| Fin | quand tous sont tombés, ou que le dernier en course a dépassé tous les autres (il continue pour son record, un bandeau le lui dit) ; écran du résultat : distances, vainqueur, ta mise et ce que tu reçois ; « Revanche » (l'hôte) ou « Changer les mises » | `_check_end`, `refresh_race` |
| Départs | 0.55 : un lien qui dit « déconnecté » a 6 s pour revenir ; perdu, la place de l'invité l'attend 180 s (0.57) et il se reconnecte seul par la salle (toutes les 12 s, 180 s au plus) ; le jeu planté, le prochain démarrage propose de rejoindre le groupe (gardé 9 min sur le téléphone), avec sa place et sa mise ; parti pour de bon : sa dernière distance compte, sa mise est perdue pour lui… sauf s'il ne reçoit jamais le résultat (l'hôte parti) : chacun récupère alors sa mise | `_lost`, `_relink`, `AWAY_KEEP`, `_fail` |
| Panneaux de record | à la distance du record de chaque ami dans le mode joué (« Record de Léo »), et du tien (« Ton record », en pierre dorée) ; plantés 70 m avant d'y arriver, pas avant 50 m, jamais à moins de 25 m l'un de l'autre (le tien l'emporte), 12 au plus ; aussi seul, hors ligne pour le tien | `Game.signs_for`, `SIGN_*` |
| Amis | 0.57 : ajouter envoie une **demande** (Liste d'amis › Demandes : Voir, Accepter ou Refuser ; une fenêtre hors course quand elle arrive) ; Liste : le pseudo et « Voir » ; « Scanner son code QR » ouvre l'appareil photo dans le jeu (0.58 : partout ; jsQR là où le navigateur n'a pas de lecteur). Retirer un ami (fiche › Retirer, après confirmation : les deux listes, et plus d'invitation entre vous) ; ajouter par code, par lien (`?ami=PEPI-XXXX`) ou par code QR ; « Effacer mes données en ligne » (Réglages › Sauvegarde) | `_remove_friend`, `qr.gd`, `player/delete` |

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
| Interface | kit v2 (pierre, lianes, gemme turquoise), chaque image à la taille exacte de sa boîte : jamais étirée ni coupée (`assets/ui-v2`, `KIT_*` dans main.gd) ; le bouton choisi prend l'état « survol » (bleu-vert). Recolorés à partir du kit (`tools/make_ui_colours.py`) : « Jouer » à cadre doré, plus haut (58 pixels au lieu de 50), « Reprendre » vert, « Abandonner » rouge orangé ; « Histoire » assombri | main.gd |
| Accueil | Jouer (la Run illimitée), Histoire, Améliorations ; survolé, ou tenu un moment au doigt (le lâcher ne lance alors rien), chaque bouton ouvre un panneau qui en dit l'esprit | `MENU_TIPS`, `_menu_tip` |
| Photo de la chute | prise sans le filtre rouge du coup | `show_dead` |
| Réglages | rien à faire défiler (0.43) : à gauche Son (musique, effets) et Image (qualité, plein écran, images par seconde) ; à droite trois onglets : Lisibilité (police pixel ; contour rouge des dangers ; signalements décalés : les alertes des Fonceurs à 64 % de la largeur au lieu du bord droit, loin du pouce), Sauvegarde (code, fichier, tout effacer ; ouverte depuis la pause, elle attend la fin de la course), Version (dans le navigateur, « Mettre à jour » : lit `version.txt`, plus récente le jeu se recharge sans ses fichiers gardés, la sauvegarde reste ; un « ! » doré sur la roue dentée de l'accueil quand une version plus récente est en ligne) | `_build_settings` |
