# Le serveur de Jungle Loop

Un petit serveur Cloudflare Workers avec une base D1. Il garde :
- les joueurs : un pseudo et un code ami (PEPI-XXXX), sans e-mail ;
- leurs meilleures distances, de tous les temps et de la semaine, par mode ;
- qui est ami avec qui, et les demandes d'amis en attente (0.57 : ajouter quelqu'un lui demande d'abord) ;
- les salons où deux téléphones se retrouvent avant une course en coop (les messages de leur poignée de
  main WebRTC, dix minutes au plus). Ensuite les deux téléphones se parlent directement : la partie ne
  passe pas par le serveur ;
- les invitations dans un salon, envoyées à un ami de sa liste (deux minutes au plus ; le jeu de l'ami
  regarde toutes les 5 s, hors course).

Rien de tout ça n'est nécessaire pour jouer : tant que l'adresse est vide dans `reglages/reseau.txt`, le
jeu n'envoie rien et le bouton « Amis » n'apparaît pas.

## Fichiers

| Fichier | Rôle |
|---|---|
| `worker.js` | le serveur : une requête POST JSON par action (liste en tête du fichier) |
| `schema.sql` | les tables |
| `wrangler.toml` | les réglages Cloudflare (l'identifiant de la base y est noté par `deploy.ps1`) |
| `deploy.ps1` | **la mise en ligne en une commande** (voir plus bas) |
| `turn.ps1` | **le relais TURN** pour jouer à deux en 4G / 5G : range la clé de relais dans les secrets du serveur (voir plus bas) |
| `dev.mjs` | le même serveur sur ce PC, sans Cloudflare (Node 22+, base en mémoire) : `node server/dev.mjs` |
| `test.mjs` | chaque action vérifiée contre la base en mémoire : `node server/test.mjs` (12 vérifications) |

Le côté jeu : `scripts/net.gd` (les requêtes) et `scripts/coop.gd` (le salon, la connexion WebRTC, les
messages de la course à deux).

## Le mettre en ligne (à faire par toi, une fois)

1. Créer un compte gratuit sur https://dash.cloudflare.com (e-mail et mot de passe, rien à payer).
2. Dans ce dossier, lancer :

   ```
   powershell -ExecutionPolicy Bypass -File deploy.ps1
   ```

   Une page Cloudflare s'ouvre pour autoriser l'outil (accepter). Au premier déploiement, wrangler demande
   de choisir ton sous-domaine `workers.dev` (le nom qui sera dans l'adresse), en anglais : « Would you like
   to register a workers.dev subdomain now? » → `y` ; « What would you like your workers.dev subdomain to
   be? » → un nom en minuscules ; « Ok to proceed? » → `y`. Le script crée la base, ses tables, publie le
   serveur et **écrit son adresse dans `reglages/reseau.txt`**. Relancé après une erreur, il reprend où il
   en était (la base déjà créée est gardée).
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
3. Deux navigateurs (deux profils) : l'un invite l'autre depuis sa liste d'amis (ou crée un salon dans
   Amis → Jouer à deux, l'autre le rejoint avec ses 4 lettres). Le banc le fait tout seul :
   `?test&net=…&coop=guest` (affiche son code ami, attend l'invitation), puis
   `?test&net=…&coop=host&friend=PEPI-XXXX` ; ou `coop=host`, puis `coop=join&room=XXXX`.

## Où en est le multijoueur

**En ligne depuis le 19/11/2026** : https://jungle-loop.burnout293.workers.dev (base D1 « jungle-loop »).
Les essais automatiques et la sauvegarde d'essai (`--bac`, `?bac`) ne l'appellent jamais, sauf adresse
donnée exprès (`--net=`, `?net=`).

Fait et essayé de bout en bout entre deux navigateurs (serveur local) : identité et code ami, pseudo,
ajout d'un ami, classement de la semaine, invitation depuis la liste (acceptée ou refusée), salon à 4
lettres, connexion WebRTC directe, retour à l'accueil à deux, Histoire puis Jouer lancées par l'hôte avec
son équipement pour les deux, course sur la même route, partenaire recoloré et lissé, bulle de
sauvetage, fin quand les deux sont dans une bulle.

## Le relais (TURN), pour jouer à deux en 4G / 5G

Deux téléphones se parlent directement quand leurs réseaux le permettent. En 4G / 5G c'est souvent bloqué :
la partie passe alors par le relais TURN de Cloudflare (gratuit jusqu'à 1 000 Go par mois, une course à
deux en utilise très peu). Le serveur donne à chaque partie des accès valables 4 h (route `ice`), faits avec
une clé de relais rangée dans ses secrets. Pour la poser, une fois :

1. Sur https://dash.cloudflare.com/?to=/:account/calls (menu « Realtime », parfois « Calls » → « TURN
   Server » → « Create », nom : jungle-loop), noter le « Turn Token ID » et l'« API Token ».
2. Dans ce dossier : `powershell -ExecutionPolicy Bypass -File turn.ps1`, coller les deux valeurs. Le script
   vérifie la clé auprès de Cloudflare puis la range (secrets `TURN_KEY_ID`, `TURN_KEY_TOKEN`). Rien à
   réexporter.

Sans clé, le jeu essaie la connexion directe seule et le dit quand elle échoue. Un autre relais peut aussi
se mettre dans `reglages/reseau.txt` (lignes `turn`). Pour l'essayer : `?relay` dans l'adresse du jeu (par
le relais ou pas du tout).

Reste :
- l'essai sur deux vrais téléphones, sur deux réseaux différents ;
- plus tard : Android sur le même Wi-Fi sans serveur, Steam.
