# Le serveur de Jungle Loop

Un petit serveur Cloudflare Workers avec une base D1. Il garde :
- les joueurs : un pseudo et un code ami (PEPI-XXXX), sans e-mail ;
- leurs meilleures distances, de tous les temps et de la semaine, par mode ;
- qui est ami avec qui ;
- les salons où deux téléphones se retrouvent avant une course en coop (les messages de leur poignée de
  main WebRTC, dix minutes au plus). Ensuite les deux téléphones se parlent directement : la partie ne
  passe pas par le serveur.

Rien de tout ça n'est nécessaire pour jouer : tant que l'adresse est vide dans `reglages/reseau.txt`, le
jeu n'envoie rien et le bouton « Amis » n'apparaît pas.

## Fichiers

| Fichier | Rôle |
|---|---|
| `worker.js` | le serveur : une requête POST JSON par action (liste en tête du fichier) |
| `schema.sql` | les tables |
| `wrangler.toml` | les réglages Cloudflare (l'identifiant de la base y est noté par `deploy.ps1`) |
| `deploy.ps1` | **la mise en ligne en une commande** (voir plus bas) |
| `dev.mjs` | le même serveur sur ce PC, sans Cloudflare (Node 22+, base en mémoire) : `node server/dev.mjs` |
| `test.mjs` | chaque action vérifiée contre la base en mémoire : `node server/test.mjs` (11 vérifications) |

Le côté jeu : `scripts/net.gd` (les requêtes) et `scripts/coop.gd` (le salon, la connexion WebRTC, les
messages de la course à deux).

## Le mettre en ligne (à faire par toi, une fois)

1. Créer un compte gratuit sur https://dash.cloudflare.com (e-mail et mot de passe, rien à payer).
2. Dans ce dossier, lancer :

   ```
   powershell -ExecutionPolicy Bypass -File deploy.ps1
   ```

   Une page Cloudflare s'ouvre pour autoriser l'outil (accepter). Au premier déploiement, Cloudflare peut
   demander de choisir un sous-domaine `workers.dev` (le nom qui sera dans l'adresse). Le script crée la
   base, ses tables, publie le serveur et **écrit son adresse dans `reglages/reseau.txt`**.
3. Me dire « réexporte » : je réexporte le jeu et je le publie. Le bouton « Amis » apparaît alors à
   l'accueil.

À la main, sans le script : `npx wrangler login`, `npx wrangler d1 create jungle-loop` (identifiant dans
`wrangler.toml`), `npx wrangler d1 execute jungle-loop --remote --file=schema.sql`, `npx wrangler deploy`,
puis l'adresse donnée dans `reglages/reseau.txt`.

Gratuit jusqu'à 100 000 requêtes par jour ; il ne se met jamais en veille. Seule la page du jeu
(`https://burnout293.github.io`, `ORIGIN` dans `wrangler.toml`) peut l'appeler depuis un navigateur.

## L'essayer sur ce PC

1. `node server/dev.mjs` (port 8787).
2. Le jeu exporté servi en local (`export/web`), ouvert avec `?net=http://127.0.0.1:8787` dans l'adresse.
3. Deux navigateurs (deux profils) : l'un crée un salon dans Amis → Jouer à deux, l'autre le rejoint avec
   ses 4 lettres. Le banc le fait tout seul : `?test&net=…&coop=host`, puis `?test&net=…&coop=join&room=XXXX`.

## Où en est le multijoueur

Fait et essayé de bout en bout entre deux navigateurs (serveur local) : identité et code ami, pseudo,
ajout d'un ami, classement de la semaine, salon à 4 lettres, connexion WebRTC directe, course à deux sur
la même route (même graine, même décor, route faite pour le moins équipé des deux), partenaire recoloré,
bulle de sauvetage, fin quand les deux sont dans une bulle.

Reste :
- un **relais TURN** pour les réseaux qui bloquent la connexion directe (certaines 4G) : il se règle dans
  `reglages/reseau.txt` (Cloudflare en propose un, payant au-delà d'un quota gratuit) ;
- l'essai sur deux vrais téléphones, sur deux réseaux différents ;
- plus tard : Android sur le même Wi-Fi sans serveur, Steam.
