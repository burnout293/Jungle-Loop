# Jungle Loop — rapport d'économie (0.46, 20/11/2026)

Question : avec tes prix du 20/11, est-ce que **20 courses = le tout début, 200 = le milieu, 800 = la fin
(les dernières améliorations)** ?

**Réponse courte : le début est bon, mais la fin arrive trop tôt.** Un joueur moyen a tout acheté vers la
**course 300**, pas 800. Un joueur rapide finit vers la course 210, un joueur prudent vers la course 465.

## 1. D'où viennent les chiffres

| Mesuré dans le jeu (Histoire, 4 graines) | Valeur |
|---|---|
| Pièces posées sur la route | 341 à 1000 m, 1044 à 2000 m (Vorace comprise), 1578 à 4000 m |
| Avec Aimant 3, Trèfle 2 et Gemmes 3 | +35 à 50 % |
| Missiles lancés | 4,3 par km |
| Montures | la 1re vers 700-1000 m, puis une tous les 1300-1800 m ; le Rhino dure 8 s |

| Supposé (à corriger si tu as mieux) | Valeur |
|---|---|
| Distance d'une course | 300 m (1re course), 700 m (course 20), 1600 m (course 200), 2600 m (course 800), ± 50 % d'une course à l'autre |
| Pièces ramassées | 70 % de ce qui est posé, 90 % avec l'Aimant 3 |
| Une chevauchée | Gorille 350 m, Libellule 400 m, Rhino 230 m ; 80 % des montures attrapées |
| Achats | dès qu'il peut, le moins cher d'abord |

Le modèle : `tools/eco_model.py` (dépôt Godot) ; 30 joueurs simulés par cas.

## 2. Tes prix, joueur moyen

Tout acheter coûte **211 700 pièces** (55 achats).

| Course | Niveau | Achats | Dépensé |
|---|---|---|---|
| 20 | 2 | 3 sur 55 (Dernier élan 1-3, Ressort 1) | 1 % |
| 50 | 4 | 11 | 5 % |
| 100 | 9 | 25 | 16 % |
| 200 | 20 | 45 | 52 % |
| ~300 | ~30 | **55 : tout** | 100 % |

- **Course 20** : bon pour « le tout début ».
- **Course 200** : 45 achats sur 55, c'est déjà presque la fin.
- **Courses 300 à 800** : plus rien à acheter, les pièces s'entassent.

## 3. Ce qui pèse

| Source de pièces (à la course 200) | Part |
|---|---|
| Ramassées sur la route | 94 % |
| Niveaux (20 × le niveau) | 4 % |
| Défis | 2 % |

- **Le revenu grimpe vite**, parce que les courses s'allongent : environ 300 pièces par course au début,
  1300 vers la fin. Les derniers achats doivent donc coûter beaucoup plus que les premiers.
- **Les niveaux ne bloquent plus rien après le niveau 12**, atteint vers la course 120. Ensuite, ils ne font
  que donner des pièces : 20 × le niveau, donc de plus en plus.
- **Le 1er niveau arrive tard** : il faut 1000 points, et une course de 300 m en donne 15, plus les défis.
  Résultat : le niveau 2 tombe vers la course 15. C'est long pour un débutant.

## 4. Les défis : un vrai problème

Les défis longs **bouchent les 3 places** :
- les mètres sur une monture ;
- les 15 missiles en une course (il faut environ 4,4 km d'un coup).

Les courts sont réussis et remplacés, les longs restent. À la course 200, chez presque tous les joueurs
simulés, les 3 places sont prises par des défis longs, et les défis ne rapportent presque plus rien.

| Défi | Courses qu'il faut (joueur du milieu) | Paie | Paie par course d'effort |
|---|---|---|---|
| Gorille 2000 m | ~14 | 60 | 4 |
| Gorille 20000 m | ~145 | 500 | 3 |
| Rhino 4000 m | ~45 | 60 | 1 |
| Rhino 20000 m | ~220 | 600 | 3 |
| Libellule 3000 m | ~19 | 60 | 3 |
| Libellule 15000 m | ~95 | 400 | 4 |
| 3 missiles en une course | 1 (dès ~1 km) | 20 | 20 |
| 15 missiles en une course | une course de ~4,4 km | 300 | (un exploit) |
| 30 missiles en tout | ~6 | 180 | 30 |
| 80 missiles en tout | ~17 | 600 | 35 |
| (pour comparer) Lance 5 courses | 5 | 30 | 6 |

Les missiles paient 10 fois plus par course que les montures.

**Si un seul défi long à la fois est permis**, voici combien de défis sont réussis :

| Course | Aujourd'hui | Un seul défi long à la fois |
|---|---|---|
| 200 | 40 | 76 |
| 800 | 117 | 458 |

## 5. Ce que je propose

**Prix (proposition A, sans skins)** : je garde tes prix du début et du milieu, et je monte seulement les
achats de fin.

| Amélioration | Tes prix | Proposés |
|---|---|---|
| Vitalité | 5000 / 12000 / 25000 | 5000 / **30000 / 100000** |
| Rembobinage | 10000 | **80000** |
| Vol | 4800 / 7000 / 10000 | 4800 / **20000 / 60000** |
| Sablier | 5000 / 10000 | **15000 / 50000** |
| RedMonster | 2500 / 5000 / 10000 | 2500 / **15000 / 40000** |
| Sphère | 6000 | **30000** |
| Fana de TNT, Ami de la nature, Esquive : 3e niveau | 6000 / 6000 / 5600 | **25000 / 20000 / 20000** |
| Bottes de métal | 2500 / 5500 | 2500 / **15000** |

Avec ces prix, la boutique coûte 608 600 pièces :

| Joueur | Achats à la course 200 | Dernier achat |
|---|---|---|
| Moyen | 42 sur 55 | vers la course 600 (Vitalité 3) |
| Rapide | — | vers la course 440 |
| Prudent | — | 53 sur 55 à la course 800 |

Il reste un trou entre la course 600 et la course 800. Il vaut mieux le remplir avec des skins
(`RAPPORT-SKINS.md`) qu'en montant encore la Vitalité.

**Défis** :
- un seul défi long à la fois ;
- payer selon l'effort : Gorille 150 / 2000, Rhino 300 / 2500, Libellule 150 / 1500, 15 missiles en une course
  1000, missiles en tout 100 / 250.

**Niveaux** : les premiers niveaux plus courts, par exemple 300, 500, 700 points, puis 1000. Le niveau 2
arriverait ainsi vers la course 5. Il faut une petite modification du code.
