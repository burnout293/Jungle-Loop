# Jungle Loop — toutes les valeurs de jeu

État au 15/11/2026, version 0.11. Pour changer une valeur, dis-moi la ligne et le nouveau chiffre
(« Sprint : +30 % », « mosquitos dès 300 m »…).

**Unités.** Le jeu compte en « unités » : 40 unités = 1 m, 2,25 unités = 1 pixel du dessin.
L'écran fait 720 unités de haut (18 m), le sol est à 630. Les vitesses sont données en m/s.

## 1. Course

| Valeur | Aujourd'hui | Où (js/game.js) |
|---|---|---|
| Vitesse au départ | 9 m/s (360 u/s) | `SPEED.base` |
| Accélération | +0,125 m/s chaque seconde | `SPEED.gain` |
| Vitesse maximale | 22,5 m/s (900 u/s), atteinte après 108 s | `SPEED.max` |
| **Sprint** | départ à 13 m/s : **+44 %** (+160 u/s). Le maximum ne change pas, il est atteint après 76 s | `SPEED.sprint` |
| Sortie du temple | vitesse × 1,8 jusqu'à sa place à l'écran | `update` |
| Ruée | vitesse × 1,7 pendant 0,55 s | `update` |
| Sablier | le monde tourne à 45 % | `update` |
| Changement de décor | tous les 400 m, tiré au sort parmi les 3 autres | `BIOME_LEN` |

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
| Cœurs | 3 (4 avec Cœur en plus) | `HEARTS` |
| Invincible après un coup | 1,6 s | `hit` |
| Invincible après la perte d'une monture | 1,5 s | `dismount` |
| Rembobinage | 1 fois par course, rend 2 cœurs, 2 s d'invincibilité | `hit` |
| Dernier élan | 1, 2 ou 3 rebonds ; vitesse de départ ≥ 10,5 m/s, perd 4,25 m/s par seconde | `hit`, `update` |

## 4. Ce qui apparaît sur la route

Un motif à la fois, tiré au sort dans une liste. Chaque ligne a la même chance, une entrée en double compte double.

| Moment | Liste | Chance de chacun |
|---|---|---|
| 70 premiers mètres | caisse, hérisson, pièces, plateforme | 25 % |
| Ensuite | caisse, hérisson ×2, doublé, volant, pièces, plateforme, grotte, tronc, galerie, escalier, corniche ×2, creux | 7,1 % (14,3 % pour hérisson et corniche) |
| Avec Double saut | + pile de 2 caisses, + volant | 16 entrées : 6,25 % |
| Avec Vol | + mur de 4 caisses, + essaim ×2 | 19 entrées : 5,3 % |
| Monture en vue | jamais de grotte | |
| Moustiques annoncés | pièces seulement | |

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Écart entre deux motifs | (vitesse × 0,8 s + 4,25 m) × hasard de 0,85 à 1,4 ; × 1,3 après des pièces | `spawnPattern` |
| Caisse | 1,6 m × 1,3 m | `CRATE` |
| Hérisson | 1,7 m × 1,35 m | `SPIKY` |
| Volant | 1,6 m × 1,35 m, avance vers toi à 3 m/s | `FLY` |
| Hauteur des volants | 4,4 m ; 4,4 ou 7,25 m avec Double saut ; 4,4 / 7,25 / 10 / 12,75 m avec Vol | `spawnPattern` |
| Plateforme | 6,35 m de long, à 3,4 m du sol | `PLAT_W` |
| Corniche | +3,4 m pendant 17,5 à 27,5 m, hérisson dessus 6 fois sur 10 | `STEP` |
| Creux | −1,65 m pendant 15 à 24 m | `HOLLOW` |
| Grotte | 20 à 30 m, toit à 2,5 m | `SLAB` |
| Tronc (Sphère) | 13 m | `LOG.w` |
| Galerie (Sphère) | 20 à 30 m, 1,45 m sous le sol | `GALLERY` |

## 5. Pièces, gemmes, cœurs

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Traînée de pièces après un motif | 55 % des fois (toujours après « pièces ») | `spawnPattern` |
| Longueur d'une traînée | 3 à 8 pièces, une tous les 1,1 m | `spawnPattern` |
| Plateforme | 4 pièces ; gemme 35 % (+20 % par niveau de Trèfle) | `spawnPattern` |
| Trèfle | en plus : gemme après une traînée, 12 % par niveau | `spawnPattern` |
| Gemme jaune / rouge / bleue | 5 / 10 / 20 pièces | `GEMS` |
| Couleur d'une gemme | jaune 60 %, rouge 30 %, bleue 10 % | `gemKind` |
| Gemmes dispersées | 1,2 % / 2,2 % / 3,5 % des pièces deviennent des gemmes | `SCATTER` |
| Caisse détruite | 2 pièces par caisse | `destroy` |
| Créature détruite (Ruée) | 1 pièce ; nuée de moustiques : 3 | `destroy`, `followers` |
| Endroit exigu | une pièce tous les mètres, 1 sur 6 est une gemme, cœur 3 % | `tight` |
| Explosion du temple | 44 pièces projetées (décor : elles ne se ramassent pas) | `update` |
| Aimant | portée 2,75 / 4,25 / 6 m | `MAGNET` |
| Portée de ramassage | 1,1 m | `update` |

## 6. Montures

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Première monture | entre 300 et 480 m | `newRun` |
| Suivantes | 650 à 950 m après la précédente | `spawnPattern` |
| Après en avoir perdu une | pas avant 350 à 550 m | `dismount` |
| Ami de la nature | ces distances divisées par 1,25 / 1,5 / 1,75 | `friend` |
| Laquelle | 1 chance sur 3 chacune | `spawnPattern` |
| Gorille | saut 3,5 m (5,6 m maintenu), second saut jusqu'aux lianes | `MOUNTS.gorilla` |
| Rhino | saut 1,6 m (2,6 m maintenu) ; +0,5 m/s chaque seconde, jusqu'à +10,5 m/s ; ramasse sur 3,9 m de large et 3,75 m de haut | `MOUNTS.rhino` |
| Moskito | monte à 12 m/s, descend à 11 m/s | `update` |
| Zigzag du Moskito | chaque pente dure 1,2 s | `spawnRide` |

## 7. Moustiques (monstres suiveurs)

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

## 8. Boutique

| Objet | Prix par niveau | Effet chiffré |
|---|---|---|
| Double saut | 120 | |
| Ressort | 250 / 600 | +10 % d'élan par niveau |
| Aimant | 150 / 400 / 900 | 2,75 / 4,25 / 6 m |
| Trèfle | 300 / 800 | voir § 5 |
| Gemmes dispersées | 500 / 1200 / 2500 | 1,2 / 2,2 / 3,5 % |
| Brise-obstacle | 350 | traverse les caisses |
| Cœur en plus | 900 | 4 cœurs |
| Faune alcoolisée | 400 / 900 / 1800 | 6 / 10 / 15 % |
| Ami de la nature | 300 / 700 / 1500 | montures 1,25 / 1,5 / 1,75 fois plus tôt |
| Ruée | 300 / 700 / 1400 | recharge 14 / 10 / 7 s |
| Sablier | 450 / 1000 | 3 / 4,5 s, recharge 20 s |
| Dernier élan | 400 / 900 / 1800 | 1 / 2 / 3 rebonds |
| Rembobinage | 2500 | 1 fois par course |
| Vol (pouvoir) | 1200 | |
| Sprint (pouvoir) | 1000 | +44 % au départ |
| Sphère (pouvoir) | 1500 | |

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
| Obstacles cassés | 4 | +3 |
| Montures | 1 | +1 |
| Nuées esquivées | 2 | +1 |

## 10. Affichage et son

| Valeur | Aujourd'hui | Où |
|---|---|---|
| Image | 569 × 320 pixels de dessin, 16:9 | js/main.js |
| Lissage « Auto » | finesse de départ ×4 sur PC, ×3 sur téléphone ; baisse d'un cran sous 48 images/s | `watch` |
| Lissage « Net » | finesse ×2 au plus, pixels francs | `resize` |
| Volumes | 0 à 10, 7 au départ | js/save.js |
