# Jungle Loop — bestiaire par décor

État au 18/11/2026, version Godot 0.47.0 (le jeu à l'adresse principale ; l'ancienne version web sur `web.html`). Tout ce qui est décrit ici est dans le jeu. Les chiffres (tailles,
distances, vitesses) sont dans [EQUILIBRAGE.md](EQUILIBRAGE.md).

Deux modes : **Histoire** (avec les boss) et **Run illimitée** (sans boss).
Ordre des décors : **forêt**, puis **ruines** (en Histoire après la victoire sur Vorace, en Run illimitée à
2000 m), **donjon** à 4000 m, **cité** à 6000 m, **forêt** à 8000 m, et ainsi de suite tous les 2000 m.

## Dangers

Chaque danger est un **rôle** : il s'évite partout de la même façon, seul son dessin change avec le décor.
Tous ont un contour sombre et un bord éclairé (lisibilité 5) ; le décor de fond est assombri.

| Rôle (comment l'éviter) | Forêt | Ruines | Donjon | Cité |
|---|---|---|---|---|
| **Au sol** : sauter | hérisson violet | boule de ronces verte | piège à loup (se referme au passage) | robot à pointes, œil bleu clignotant |
| **Fonceur** : gros panneau rouge « ! » et klaxon au bord droit (plus à gauche avec « Signalements décalés »), à sa hauteur (avec le Vol : la tienne, et il vient si tu restes trop à la même hauteur), puis il traverse l'écran | coléoptère | vautour | flèche enflammée | missile |
| **Suspendu** : immobile dans le vide ; bas (sauter) dès 150 m (nids dès 900 m), à hauteur de tête (rester au sol) dès 1500 m ; avec le Vol aussi plus haut, et en rideaux (une colonne avec un seul passage) | araignée jaune (basse, immobile), rouge (plus haut, monte et descend de 5 m) | les mêmes araignées | chauve-souris | drone |
| **Nuée** : vise un couloir (bande rouge), puis fonce ; jamais de Fonceur pendant une nuée | moustiques | guêpes | feux follets | gros drones qui tirent un laser au lieu de foncer |

0.49 : tous les dangers, le héros, les pièces et les objets sont dessinés 15 % plus grands. Ordre d'apparition :
araignées 150 m, nuées 300 m, Fonceurs (missiles) 400 m, nids 900 m.

Relique altérée (objet) : une partie des créatures et des nuées deviennent inoffensives (pâles, bleutées).

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

Inoffensif ; il se casse avec Brise-tout, l'Esquive, les Bottes de métal, la TNT ou le rhino (4 pièces). Un peu assombri.

| Forêt | Ruines | Donjon | Cité |
|---|---|---|---|
| grosse caisse cerclée de fer | jarre | tonneau | caisses |

## Plateformes, collines, lianes

| | Forêt | Ruines | Donjon | Cité |
|---|---|---|---|---|
| **Plateforme** | 0.49 : morceau de colline flottant, mousse dessus, pierres gravées et racines dessous (PixelLab, deux tailles) ; toujours devant le monticule dont il semble tiré ; 0.50 : une sur deux en pente fixe (elle monte, et la dernière d'un passage peut descendre) | bloc de sol flottant (dalles) | passerelle de planches pendue à deux chaînes | plateforme en lévitation sur 3 réacteurs cyan |
| **Colline** (décor un peu assombri, jamais un obstacle ; 0.43) | rochers moussus, racines en arche ; 0.49 : monticule de pierres gravées et de racines (PixelLab), toujours derrière les plateformes ; 0.50 : assombri, et trois autres (pierres gravées, souche creuse, tronc couché) | murs de pierres carrées effondrés | aucune (0.44) | immeubles éclairés, conteneurs rouillés |
| **Lianes** | pendent du haut de l'écran ici et là | idem | chaînes à crochet ou anneau | câbles à prise lumineuse, câbles tendus en arc |

Derrière le sol de la forêt (0.44) : fougères, fleurs, champignons et lanterne (ils s'allument quand il les frôle),
tête de pierre, bannière, bloc de lianes ; plus de grand arbre ni de panneau.

Les blocs de sol flottants ne viennent qu'avec une colline derrière eux. Avec le Gorille, une liane
tressée court tout le long du haut de l'écran (une chaîne au donjon, un câble à pinces lumineuses dans la cité).

## Les gardes du temple (Histoire, décor)

Deux guerriers masqués de feuilles (PixelLab, 0.44) : **Pointu**, au masque de bois et à la lance, et **Chef
Massue**, au masque rouge à plumes et à la massue. Ils se sont enfermés avec Pépito en faisant s'écrouler
l'entrée. Après l'explosion, ils sortent du temple derrière lui, à distance, pendant que la caméra reste
figée ; quand elle le rattrape, ils reviennent très vite juste derrière lui (bord gauche) sans jamais
l'atteindre ; à leur « DEMI-TOUR » (1000 m, Vorace n'est plus loin) ils s'enfuient. Ils ne font pas mal,
mais si Pépito se plante (dernier cœur) avant leur demi-tour, ils lui sautent dessus : un nuage de bagarre,
puis il est ramené vers le temple, attaché sous une broche posée sur leurs têtes (0.45). Depuis la 0.47, ils
reviennent le chercher où qu'il tombe (seul, hors boss), même après leur demi-tour et en Run illimitée ; avec
un couteau suisse il peut s'évader (couper les cordes au bon moment), et ils s'enfuient. Leurs skins (0.47) :
Feuilles d'automne, Nuit, Feu.

## Amis et trésors

- **Singes** dans les arbres, à saluer en passant.
- **Plumes de toucan** et **urnes** (0.47, PixelLab), qui flottent comme le sablier.
- **Pièces** (et 27 dessins de pièces dans `assets/patterns.txt`, dont certains dans le ciel, à n'attraper qu'avec le Vol), **gemmes** jaune, rouge, bleue, **cœurs**.

## Sur la route avec les amis (0.48)

- **Panneaux de record** : une planche de bois sur un poteau, « Record de Léo », à la distance de son record ;
  le tien en pierre grise, écrit en or.
- **Fantômes** de la course à 4 : les autres Pépito, pâles, chacun à sa couleur, avec son nom.

## Le temple (0.50)

Une pyramide de pierre verte moussue, son sanctuaire au sommet coiffé d'un cristal turquoise ; devant, un porche
gravé de cristaux dont la porte est bloquée de rochers tenus par des lianes ; aux deux coins, des piliers à tête de
jaguar. Trois couches (PixelLab) : la pyramide derrière le sol, le porche sur le sol, les piliers devant Pépito.

## La relique (0.49)

Cinq morceaux : le **cœur** (cyan, volé par Pépito au temple, aucun pouvoir) et quatre gemmes dans le ventre
des gardiens de la jungle, chacune avec un pouvoir en Histoire : le **jade** (Vorace, forêt : double saut ; dans
le jeu), l'**ambre** (ruines : Esquive), la **lune** (cité : Sablier), la **braise** (donjon : Vol). Complète : un
disque-soleil doré, un masque de pierre au centre avec le cœur au front, les quatre gemmes en croix (PixelLab,
4 essais dans `propositions/0.49/` du dépôt Godot). Vorace repousse (c'est une fleur) tant que le gardien
suivant n'existe pas. Ce sont les pygmées, non plus la relique, qui ramènent Pépito au temple à chaque chute.

**0.50 : un masque de jaguar** (proposition B3, sans son treillis doré ni ses lianes), coupé en cinq pièces qui
s'emboîtent : le **cœur** au front (cyan), la **couronne** de feuilles (jade, Vorace), la **tête gauche** (ambre),
la **mâchoire** (lune, violette) et la **tête droite** (braise, rouge). Les images sont prêtes
(`assets/img/relic/` du dépôt Godot), pas encore montrées dans le jeu.

## Boss à l'étude (0.48, sans dessins)

Idées présentées sur la toile des maquettes (https://claude.ai/artifact/WrgYidBBFJyPb4DYx81pcH) : Horus,
gardien solaire (ruines, ses 4 dessins existent) ; le Geôlier aux chaînes (donjon) ; le Titan d'acier (cité) ;
le Grand Totem des pygmées (rythme, filet et couteau) ; la Reine des nuées (lanternes) ; le Double (la boucle du
temps, avec les fantômes de la course). Rien n'est dans le jeu.

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
