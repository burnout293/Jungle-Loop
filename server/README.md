# Le serveur de Jungle Loop

Un petit serveur Cloudflare Workers avec une base D1. Il garde :
- les joueurs : un pseudo et un code ami (PEPI-XXXX), sans e-mail ;
- leurs meilleures distances, de tous les temps et de la semaine, par mode ;
- qui est ami avec qui ;
- les salons où deux téléphones se retrouvent avant une course en coop (les messages de leur poignée de
  main WebRTC, dix minutes au plus).

Rien de tout ça n'est nécessaire pour jouer : tant que `SERVER` est vide dans `scripts/net.gd`, le jeu
n'envoie rien.

## Fichiers

| Fichier | Rôle |
|---|---|
| `worker.js` | le serveur : une requête POST JSON par action (liste en tête du fichier) |
| `schema.sql` | les tables |
| `wrangler.toml` | les réglages Cloudflare (l'identifiant de la base est à remplir) |
| `dev.mjs` | le même serveur sur ce PC, sans Cloudflare (Node 22+, base en mémoire) : `node server/dev.mjs` |
| `test.mjs` | chaque action vérifiée contre la base en mémoire : `node server/test.mjs` |

Le côté jeu est `scripts/net.gd`. Pour l'essayer contre le serveur local : lancer `node server/dev.mjs`, puis
le jeu avec `-- --net=http://127.0.0.1:8787`.

## Le mettre en ligne (à faire par toi, une fois)

1. Créer un compte gratuit sur https://dash.cloudflare.com (il te faut le faire toi-même).
2. Dans ce dossier, se connecter : `npx wrangler login` (une page s'ouvre pour accepter).
3. Créer la base : `npx wrangler d1 create jungle-loop`, puis copier l'identifiant donné dans
   `wrangler.toml` (`database_id`).
4. Créer les tables : `npx wrangler d1 execute jungle-loop --remote --file=schema.sql`.
5. Publier : `npx wrangler deploy`. L'adresse donnée (`https://jungle-loop.<ton-compte>.workers.dev`) va dans
   `SERVER`, en tête de `scripts/net.gd`, puis on réexporte le jeu.

Gratuit jusqu'à 100 000 requêtes par jour ; il ne se met jamais en veille.

## Ce qui reste pour le multijoueur

- L'écran « Amis » (ton code, ajouter un code, le classement de la semaine) : le serveur et `net.gd` sont
  prêts, l'écran n'est pas fait.
- La coop : le salon et la poignée de main passent déjà par le serveur ; restent la connexion WebRTC entre
  les deux téléphones, l'hôte qui fait foi, le second héros (Pépito recoloré), la bulle de sauvetage. Le
  parcours est déjà le même pour une même graine (vérifié : 1 119 éléments identiques sur 150 s).
