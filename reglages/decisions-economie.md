# Jungle Loop — décisions sur l'économie (22/11/2026)

Note de la session d'audit pour « Mystic Jungle ». La partie 1 est **validée par l'utilisateur** : à appliquer.
Les parties 2 et 3 ne sont que des informations et des propositions : **ne rien coder sans son accord**.

État constaté le 23/11 (version 0.54.0) : le Couteau suisse est déjà un équipement ; `progression.txt` contient
encore les plumes, les éclats, la Corne et le Couteau dans les urnes, et les Tambours.

## 1. Validé : à appliquer

### Monnaie
- **Une seule monnaie : les pièces.** Les éclats disparaissent.
- Les gemmes restent des pièces de valeur (5 / 10 / 20).

### Urnes (les boosters)
- On les **gagne** (niveaux, défis, boss, Course du jour) ; elles ne s'achètent **jamais** avec des pièces.
- Contenu à collectionner (proposé, sans objection de sa part) :
  - skins par pièce : feuilles de la tête, écharpe, sac à dos, chaussures ;
  - effets : traînée de course, hélice du Vol, éclat du saut ;
  - mise en scène : la chute (tête plantée, tombe, fleur), le panneau de record vu par les amis ;
  - social : émotes à deux, couleur du fantôme dans la course à 4 ;
  - cartes du bestiaire : un album complet débloque un skin spécial.
- **Doublon = des pièces**, environ 15 % du prix d'achat :

| Rareté | Prix d'achat direct | Doublon sorti d'une urne |
|---|---|---|
| Commun | 2 500 | 400 |
| Rare | 10 000 | 1 500 |
| Légendaire | 50 000 (ou urne) | 5 000 |

Prix validés (« c'est très bien »).

### Consommables → équipements
- Plus de stock : les consommables deviennent des **équipements** (une des 3 places, avec des niveaux),
  valables en **Run illimitée seulement** (l'Histoire reste écrite).
- **Corne du rhino** : départ sur le rhino à la sortie du temple, 300 / 500 / 800 m.
- **Couteau suisse** : évasion face aux pygmées, 1 évasion / zone plus large / 2 évasions (déjà équipement en 0.54).
- **Bouclier : abandonné.** Ce seront simplement des vies en plus (Vitalité).

### Défis
- Les plumes sont remplacées par **un défi changé gratuitement par jour** (proposé, sans objection).

### Quotidien : la Course du jour
- La même route pour tous (graine du jour, le dé de route `W` / `run.rng` existe déjà), classement entre amis
  par le serveur, une urne au premier essai du jour.
- **Sa demande en plus** : des **équipements imposés**, et parfois des **règles changées** (vitesse accélérée,
  certains obstacles seulement, etc.).

### Contenu des urnes (validé le 23/11)
- **100 % cosmétique**, trois familles seulement, plus des pièces :
  - **apparence de Pépito** : skins par pièce (feuilles, écharpe, sac, chaussures) ;
  - **effets** : traînée de course, hélice du Vol, éclat du saut, chute mise en scène (tombe, fleur, nuage) ;
  - **social** : panneau de record vu par les amis, couleur du fantôme dans la course à 4, émotes à deux ;
  - **pièces** : lot de consolation et doublons (400 / 1 500 / 5 000).
- Rien qui aide à jouer. Pas de bestiaire pour l'instant (à ajouter plus tard si la collection s'essouffle).

### Paliers de la Course du jour (validé le 23/11)
- Essais illimités ; chaque palier est payé **une fois par jour**, au premier passage.

| Palier | Repère (journée normale) | Récompense |
|---|---|---|
| Bronze | 400 m | 300 pièces |
| Argent | 1 000 m | Urne commune |
| Or | 2 000 m | Urne rare |
| Légende | 3 500 m | Urne rare + skin ou effet « du jour » |

- **Sa demande : les paliers sont adaptés à la difficulté de chaque course** (vitesse accélérée = paliers plus courts, etc.).
- Le skin ou l'effet « du jour » est **repris plus tard dans le catalogue** : pas d'exclusivité définitive.
- **Bonus de la semaine** : l'Or atteint 5 jours sur 7 donne une urne légendaire.
- Classement entre amis sans récompense ; les paliers sont visibles sur la route, comme les panneaux de record.
- **Sa demande : un fichier qui liste toutes les courses possibles** (par exemple `reglages/courses-du-jour.txt`) :
  pour chacune, les équipements imposés, les règles changées (vitesse, obstacles retenus…) et ses 4 paliers.
  En tête, **un guide en commentaire** pour qu'il puisse en créer ou en personnaliser lui-même, dans le style
  des autres fichiers de `reglages/`.

## 2. Encore à trancher par lui

- **Les Tambours** : son « on garde » visait la Course du jour. Options : supprimés, réutilisés comme mini-jeu
  de l'autel au départ (recommandé), ou gardés à côté.
- **Aimant simple et Idole dorée** (en stock aujourd'hui) : supprimés (recommandé : l'Aimant existe déjà en
  équipement) ou transformés en équipements.

## 3. Propositions de l'audit (pour information)

- **Saut > Vol** : chaque course commence à pied, et le Vol se gagne en course (jauge, la relique se charge ;
  les niveaux de Vol donnent de l'endurance). À pied, plus de suspendus dans le ciel, des pièces visibles là-haut.
- **Relique** (son idée : 5 parties, 1 volée et 1 par boss, 1 partie = 1 pouvoir). Ma proposition :
  - partie volée : la Boucle (chaque chute ramène au temple) ;
  - Vorace : Vol ; Horus : Sablier ; le Geôlier : Esquive ; le Titan d'acier : Bottes de métal ;
  - relique complète : Rembobinage ;
  - mini-jeu de départ : l'autel tournant (2-3 s) ;
  - améliorations débloquées par le butin de chaque boss ; le Sorcier pygmée tient la boutique.
- **Mesures de l'audit 0.48** : environ 0,6 danger/s dès 250 m ; vitesse sans plafond (35 m/s à 5,2 km) ;
  le rôle suspendu fait 49 à 72 % des dangers ; le double saut laisse la même route que le saut seul ;
  Vol 2 et 3 ne changent pas la route. Détail : mémoire `jungle-loop-audit-048`.
