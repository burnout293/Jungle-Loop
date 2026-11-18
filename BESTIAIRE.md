# Jungle Loop — bestiaire par décor

État au 18/11/2026, version Godot 0.33.0 (le jeu à l'adresse principale ; l'ancienne version web sur `web.html`). Tout ce qui est décrit ici est dans le jeu. Les chiffres (tailles,
distances, vitesses) sont dans [EQUILIBRAGE.md](EQUILIBRAGE.md).

Deux modes : **Histoire** (avec les boss) et **Run illimitée** (sans boss).
Ordre des décors : **forêt**, puis **ruines** (en Histoire après la victoire sur Vorace, en Run illimitée à
2000 m), **donjon** à 4000 m, **cité** à 6000 m, **forêt** à 8000 m, et ainsi de suite tous les 2000 m.

## Dangers

Chaque danger est un **rôle** : il s'évite partout de la même façon, seul son dessin change avec le décor.
Tous ont un contour sombre et un bord éclairé (lisibilité 5) ; le décor de fond est assombri.

| Rôle (comment l'éviter) | Forêt | Ruines | Donjon | Cité |
|---|---|---|---|---|
| **Au sol** : sauter | hérisson violet | boule de ronces | piège à loup (se referme au passage) | robot à pointes, œil bleu clignotant |
| **Fonceur** : gros panneau rouge « ! » et klaxon au bord droit (plus à gauche avec « Signalements décalés »), à sa hauteur (avec le Vol : la tienne, et il vient si tu restes trop à la même hauteur), puis il traverse l'écran | coléoptère | vautour | flèche enflammée | missile |
| **Suspendu** : immobile dans le vide ; bas (sauter) dès 150 m, à hauteur de tête (rester au sol) dès 1500 m ; avec le Vol aussi plus haut, et en rideaux (une colonne avec un seul passage) | araignée jaune (basse, immobile), rouge (plus haut, monte et descend de 5 m) | les mêmes araignées | chauve-souris | drone |
| **Nuée** : vise un couloir (bande rouge), puis fonce ; jamais de Fonceur pendant une nuée | moustiques | guêpes | feux follets | gros drones qui tirent un laser au lieu de foncer |

Faune alcoolisée (objet) : une partie des créatures et des nuées deviennent inoffensives (pâles, bleutées).

## Boss

**Vorace**, la fleur-reine carnivore : en mode Histoire, une fois par course, vers 2000 m, seulement dans la forêt.

- Elle marche derrière le sol, en trois couches qui ne se décollent jamais (pattes épineuses, urne à l'œil orange, couronne de pétales violets à crocs).
- Attaques : flaques et boules d'acide, pluie de gouttes.
- Pendant le combat : aucun autre danger ; ses **nénuphars volants** (turquoise aux veines violettes, épines, œil orange, ils battent des ailes et clignent) servent de plateformes.
- Sa fin, au ralenti : un tronc tombe sur sa couronne, l'urne se fend, les pattes cèdent, elle s'enfonce ; ensuite seulement les récompenses (pièces, trois gemmes, ligne de gemmes bleues), puis le décor change.

Seuls les boss ont du texte à l'écran.

## Montures

| Monture | Où elle attend | Ce qu'elle fait |
|---|---|---|
| Gorille | tout en haut, suspendu à la liane | saute haut, second saut jusqu'à la liane tressée où il se balance ; sa route : dangers au sol, dans les lianes, Fonceurs aux deux hauteurs |
| Rhino | broute au sol | court deux fois plus vite que Pépito, casse le décor, rien ne le blesse ; il repart tout seul au bout de 8 s |
| Libellule | zigzague en l'air | vole : appuyé elle monte, relâché elle descend |

## Décor à casser

Inoffensif ; il se casse avec Brise-tout, la Ruée ou le rhino (4 pièces). Un peu assombri.

| Forêt | Ruines | Donjon | Cité |
|---|---|---|---|
| grosse caisse cerclée de fer | jarre | tonneau | caisses |

## Plateformes, collines, lianes

| | Forêt | Ruines | Donjon | Cité |
|---|---|---|---|---|
| **Plateforme** | bloc de sol flottant (terre et herbe) | bloc de sol flottant (dalles) | passerelle de planches pendue à deux chaînes | plateforme en lévitation sur 3 réacteurs cyan |
| **Colline** (décor sombre, jamais un obstacle) | ronde, touffue | colonnes brisées sur la crête | roche | blocs, quelques fenêtres |
| **Lianes** | pendent du haut de l'écran ici et là | idem | chaînes à crochet ou anneau | câbles à prise lumineuse, câbles tendus en arc |

Les blocs de sol flottants ne viennent qu'avec une colline derrière eux. Avec le Gorille, une liane
tressée court tout le long du haut de l'écran (une chaîne au donjon, un câble à pinces lumineuses dans la cité).

## Amis et trésors

- **Singes** dans les arbres, à saluer en passant.
- **Pièces** (et 27 dessins de pièces dans `assets/patterns.txt`, dont certains dans le ciel, à n'attraper qu'avec le Vol), **gemmes** jaune, rouge, bleue, **cœurs**.

## Retirés

Caisses à sauter (devenues décor à casser), mine (remplacée par le robot à pointes), geyser, ronces,
bloc de pilier, piqué de chauve-souris, plateformes de bois, premiers nénuphars verts (remplacés par ceux
de Vorace), voix « Danger ! », tentacules de Vorace, idole de pierre des ruines (mise de côté, remplacée par les araignées).

## D'où viennent les images

Générées avec ElevenLabs (qualité max), puis ramenées à la grille du jeu sans flou :
`tools/import_vorace.py` (Vorace), `tools/import_dangers.py` (dangers), `tools/import_lilypad.py`
(nénuphars), `tools/import_platforms.py` (passerelle, plateforme de la cité, lianes),
`tools/import_single.py` (grosse caisse, tronc). Le hérisson et le coléoptère sont du pixel art d'origine
(PixelLab).
