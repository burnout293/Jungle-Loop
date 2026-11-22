# Jungle Loop — préparer le Play Store et Steam (0.48)

Ce dossier rassemble tout ce qui peut être prêt avant la publication. Ce qui reste demande **ton compte**,
**un paiement**, **une clé de signature à toi** ou **un téléchargement à accepter** : c'est en bas, dans
« À faire par toi ».

## Ce qui est prêt

| Quoi | Où |
|---|---|
| Préréglages d'export **Windows**, **Linux** (Steam, Steam Deck) et **Android** (Play Store, format AAB) | `export_presets.cfg` |
| Modèles d'export Godot 4.7.2 Windows, Linux et Android installés (tirés de l'archive officielle déjà téléchargée le 17/11, empreinte SHA-512 vérifiée) | `%APPDATA%\Godot\export_templates\4.7.2.stable` |
| Version Windows exportée et lancée sur ce PC | `export/windows/` (non commitée) |
| Fiches des magasins en français et en anglais (titre, descriptions courte et longue, mots-clés) | `play/fiche.md`, `steam/fiche.md` |
| Réponses préparées pour la « Sécurité des données » (Play) et le questionnaire d'âge | `play/questionnaires.md` |
| Politique de confidentialité (obligatoire avec le jeu en ligne), en français et en anglais | `Jungle-Loop/confidentialite.html` → https://burnout293.github.io/Jungle-Loop/confidentialite.html |
| Scripts SteamPipe (envoi des builds Windows et Linux) avec des emplacements pour tes numéros | `steam/app_build.vdf`, `steam/depot_windows.vdf`, `steam/depot_linux.vdf` |
| Images des magasins faites à partir du jeu : icône 512, bannière Play 1024×500, capsules Steam (en-tête, petite, principale, verticale, bibliothèque, héros, logo) et captures 1280×720 | `images/` |
| Manette : saut, Esquive, Sablier, TNT, Bottes, RedMonster et pause (Steam Deck, manette sur PC et Android) | `scripts/main.gd` |
| Bouton Retour d'Android : ferme la fenêtre ouverte, revient à l'accueil, ou met la course en pause | `scripts/main.gd` |
| Menu de debug verrouillé par mot de passe, banc d'essai coupé dans les versions publiées | `scripts/lock.gd`, `scripts/main.gd` |

## Ce que les versions natives (Windows, Linux, Android) ne savent pas encore faire

**Jouer à deux et la course à 4** passent par WebRTC : dans un navigateur c'est intégré, mais Godot natif a
besoin de l'extension officielle **webrtc-native** (godotengine/webrtc-native, version 1.1.0, environ 30 Mo
pour toutes les plateformes). Sans elle, ces versions ont les amis, les records et les panneaux, mais
« À deux » et « Course à 4 » y disent de passer par le navigateur. Son téléchargement attend ton accord
(point D de mon rapport).

## À faire par toi

### Google Play
1. **Compte développeur** Google Play Console : 25 $ une fois, pièce d'identité demandée par Google.
2. **Le nom du paquet**, définitif une fois publié : je propose `io.github.burnout293.jungleloop` (déjà mis
   dans le préréglage Android). À changer avant le premier envoi si tu préfères autre chose.
3. **Outils Android** (téléchargements à accepter) : JDK 17 (≈ 190 Mo, Eclipse Temurin) et le SDK Android en
   ligne de commande (≈ 150 Mo, puis ≈ 1 Go de composants : platform-tools, build-tools 35, platform 35).
   Ensuite, dans Godot : Éditeur › Paramètres › Export › Android, les deux chemins.
4. **Clé de signature** : `powershell -File store/play/cle-android.ps1` la crée **hors du dépôt**
   (le script demande les mots de passe ; ne les donne à personne, moi compris). Google garde ensuite la clé
   finale (« Signature d'application par Google Play ») : la tienne ne sert qu'à envoyer.
5. Dans la Play Console : créer l'appli, coller les fiches (`play/fiche.md`), les images (`images/`),
   l'adresse de la politique de confidentialité, répondre aux questionnaires (`play/questionnaires.md`), puis
   envoyer l'AAB en **test interne** d'abord (obligatoire : 12 testeurs pendant 14 jours pour un nouveau
   compte personnel avant la production).

### Steam
1. **Steamworks** : compte partenaire, 100 $ par jeu (Steam Direct), formulaires fiscaux et bancaires.
2. Noter l'**AppID** et les **DepotID** donnés par Steam dans `steam/app_build.vdf` et les deux `depot_*.vdf`.
3. **SteamCMD** (téléchargement à accepter, ≈ 3 Mo puis mise à jour) pour envoyer :
   `steamcmd +login <ton compte> +run_app_build <chemin>\store\steam\app_build.vdf +quit`
   (le mot de passe et le code Steam Guard, c'est toi qui les tapes).
4. Facultatif : **GodotSteam** (extension, téléchargement à accepter) pour les succès Steam et l'overlay ; je
   peux brancher les défis du jeu sur des succès.
5. Prix, date de sortie, page « Bientôt disponible » (au moins deux semaines avant la sortie) : à décider.

## Vérifications faites

- Export Windows : le jeu démarre, l'accueil s'affiche (capture `images/windows-accueil.png`).
- Android et Linux : préréglages relus, pas d'export possible ici sans le SDK Android (Linux : export fait,
  pas lancé, pas de Linux sur ce PC).
