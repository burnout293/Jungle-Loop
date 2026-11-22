# Jungle Loop — réponses préparées pour la Play Console (et Steam)

À relire avant de les donner : c'est toi qui les signes. Elles décrivent le jeu tel qu'il est en 0.48.

## Sécurité des données (Play)

**L'appli collecte-t-elle ou partage-t-elle des données ?** Oui, seulement si le joueur ouvre l'écran Amis
(le jeu ne contacte aucun serveur avant).

| Type de donnée (catégorie Google) | Collectée | Partagée | Pourquoi | Facultative |
|---|---|---|---|---|
| Nom (le pseudo choisi, 16 caractères) | Oui | Non | Fonctionnement : tes amis le voient | Oui |
| Identifiants de l'appareil ou autres (un identifiant aléatoire et un secret créés par le jeu) | Oui | Non | Fonctionnement : reconnaître le joueur | Oui |
| Activité dans l'appli : autres actions (meilleures distances par mode) | Oui | Non | Fonctionnement : tableau des amis, panneaux de record | Oui |

- **Chiffrées en transit** : oui (HTTPS vers le serveur ; WebRTC chiffre les parties à plusieurs).
- **Suppression** : oui, dans le jeu (Réglages › Sauvegarde › « Effacer mes données en ligne », 0.48) ; et par
  la page de confidentialité.
- **Pas collecté** : e-mail, localisation, contacts, photos, identifiant publicitaire. Pas de publicité,
  pas de suivi, pas de revente.
- **À savoir** : pendant une partie à deux ou une course à quatre, les téléphones se parlent directement
  (WebRTC) : chacun voit l'adresse IP des autres joueurs de la partie, comme dans tout jeu en ligne de
  pair à pair. Si la connexion directe échoue, elle passe par le relais de Cloudflare.
- **Hébergeur** : Cloudflare (Workers et base D1).

## Classification du contenu (questionnaire IARC)

| Question | Réponse | Pourquoi |
|---|---|---|
| Violence | Oui, dessin animé / fantastique, légère | des obstacles cassés, une fleur géante vaincue par un tronc, Pépito attrapé et ficelé par les gardes (sans blessure montrée) |
| Sang, contenu sexuel, langage grossier, drogue | Non | |
| **Jeux d'argent simulés** | **Oui, probablement** | la course à 4 permet de miser des pièces du jeu sur le vainqueur. Pas d'argent réel, rien à acheter, mais IARC compte en général « parier une monnaie virtuelle » comme jeu d'argent simulé : la note peut monter à 12 ans (PEGI 12). Voir le point D de mon rapport |
| Objets au hasard (urnes) | Oui, gagnés en jouant, jamais achetés | pas de « loot box » payante : rien à déclarer côté achats |
| Les joueurs interagissent | Oui | pseudos visibles par les amis, parties ensemble ; pas de messagerie, pas de texte libre hormis le pseudo |
| Partage de localisation | Non | |
| Achats numériques | Non | |

Note attendue : PEGI 7 sans les mises, sans doute PEGI 12 avec.

## Public cible (Play)

Pas destiné aux enfants de moins de 13 ans en priorité (sinon les règles « Familles » s'appliquent, plus
strictes pour le jeu en ligne). Proposition : 13 ans et plus.

## Steam (questionnaire de contenu)

Rien de « contenu mature » ; la même remarque sur les mises entre amis si la question des jeux d'argent est
posée.
