# Jungle Loop — rapport d'économie avec des skins (0.46, 20/11/2026)

Même modèle que `RAPPORT-ECONOMIE.md`, avec en plus une boutique de skins imaginée : montures, Pépito, temple,
pygmées, menu, musiques. Les skins ne changent que l'apparence. Ils servent à dépenser les pièces de fin de
partie, là où les améliorations n'ont plus rien à vendre.

## 1. Le catalogue imaginé (27 skins, 382 000 pièces)

| Pour | Skins (niveau requis : prix) | Total |
|---|---|---|
| Pépito | Safari (3 : 1500), Pirate (6 : 4000), Ninja (10 : 10000), Momie (15 : 20000), Doré (30 : 60000) | 95 500 |
| Montures | par monture : un skin à 3000, un à 9000, un à 25000. Gorille : argenté, Yéti, de lave. Rhino : cuirassé, Tricératops, de cristal. Libellule : Papillon, néon, Phénix | 111 000 |
| Temple | Jade (8 : 5000), Englouti (16 : 15000), Or (25 : 40000) | 60 000 |
| Pygmées | Masques de fête (7 : 4000), Squelettes (14 : 12000), Garde royale (22 : 30000) | 46 000 |
| Menu | Nuit (4 : 2000), Coucher de soleil (9 : 6000), Ruines dorées (18 : 18000) | 26 000 |
| Musiques | Tambours (2 : 1500), Flûtes (8 : 5000), Orage (15 : 12000), Épopée (25 : 25000) | 43 500 |

Chaque famille a un skin pas cher (moins de 5000), un moyen (6000 à 20000) et un de prestige (25000 à 60000).

## 2. Résultats (joueur moyen, 20 joueurs simulés par cas)

| Cas | Boutique entière | Achats à la course 20 / 200 / 400 / 800 | Dernière amélioration | Tout acheté |
|---|---|---|---|---|
| Tes prix + skins | 593 700 | 3 / 48 / 73 / 82 sur 82 | course ~430 | course ~590 |
| **Proposition B + skins** | 734 600 | 3 / 48 / 69 / 82 | course ~640 | **course ~680** |
| Proposition A + skins | 990 600 | 3 / 48 / 66 / 81 | course ~770 | pas avant 800 |

Proposition B pour les joueurs prudents et rapides :

| Joueur | Achats à la course 200 / 800 | Dernière amélioration | Tout acheté |
|---|---|---|---|
| Prudent | 34 / 76 sur 82 | course ~710 | pas tout à 800 |
| Rapide | 59 / 82 | course ~470 | course ~500 |

**Avec des skins, je recommande la proposition B.** Elle monte la fin moins fort que la proposition A, parce que
les skins prennent déjà une partie des pièces.

| Amélioration | Tes prix | Proposition B |
|---|---|---|
| Vitalité | 5000 / 12000 / 25000 | 5000 / **20000 / 50000** |
| Rembobinage | 10000 | **40000** |
| Vol | 4800 / 7000 / 10000 | 4800 / **12000 / 25000** |
| Sablier | 5000 / 10000 | **8000 / 20000** |
| RedMonster | 2500 / 5000 / 10000 | 2500 / **8000 / 20000** |
| Sphère | 6000 | **15000** |
| TNT, Nature, Esquive : 3e niveau | 6000 / 6000 / 5600 | **12000** chacun |
| Bottes de métal | 2500 / 5500 | 2500 / **10000** |

Avec la proposition B, les améliorations coûtent 352 600 pièces, et 734 600 avec les skins.

## 3. Le déroulé (proposition B + skins, joueur moyen)

| Courses | Ce qui s'achète |
|---|---|
| 1-20 | Dernier élan, Ressort, la musique Tambours |
| 20-100 | Brise-tout, Aimant, Gemmes, Double saut, les montures, Pépito Safari, le menu Nuit |
| 100-200 | Esquive, TNT, Bottes, Relique, Sprint, Vol 1, Vitalité 1 ; les premiers skins de montures, Pépito Pirate, les Masques de fête, le temple Jade |
| 200-400 | le gros des améliorations de fin (Sphère, Vitalité 2, RedMonster 3, Sablier 2), les skins moyens |
| 400-680 | Vol 3, Rembobinage, Vitalité 3 ; les skins de prestige : montures de lave, de cristal et Phénix, Garde royale, temple d'Or, Pépito Doré en dernier |

## 4. Idées pour que les skins ne soient pas qu'un prix

- **Des skins gagnés, pas achetés** :
  - Pygmées squelettes : être capturé 25 fois ;
  - temple Englouti : battre Vorace 10 fois ;
  - Phénix : 15 000 m avec la Libellule.
  Ça donne un vrai but aux défis longs.
- **Une 2e monnaie** possible, les gemmes, gardées à part au lieu d'être changées en pièces. Les skins ne
  ralentiraient plus les améliorations. En contrepartie, il faudrait refaire l'équilibrage des gemmes.
- **Les musiques** se débloqueraient bien avec les biomes atteints, pour récompenser la distance.

## 5. Le coût de fabrication

Ce n'est pas le même travail selon la famille.

| Famille | Images à refaire | Charge |
|---|---|---|
| Pépito | toutes ses animations (course, saut, vol, Sphère, tête plantée, broche…) | lourde : beaucoup de générations PixelLab par skin |
| Montures | leurs animations (course, saut, attente) | moyenne |
| Pygmées | 2 guerriers × course et broche | moyenne |
| Temple | l'entrée et l'explosion | légère |
| Menu | couleurs et fond | légère, presque tout en code |
| Musiques | une piste chacune | PixelLab a un outil de musique, à essayer |

Avec 5 générations PixelLab par nuit (compte d'essai), un skin de Pépito prend plusieurs jours. Je conseille de
commencer par le menu, le temple et les musiques.
