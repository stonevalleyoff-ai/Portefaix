# Portefaix

*Videz la maison avant l'aube. Ne réveillez pas ce qui y dort.*

Un prototype en Godot 4.3, en 3D, à la première personne, pour 1 à 6 joueurs. Il se joue au clavier et à la souris, ou au doigt, et dans un navigateur (seul). Des déménageurs de nuit vident une maison hantée : il faut charger pour un quota d'euros dans la zone du camion avant 6 h. Les meubles sont lourds et fragiles, la chose qui dort au fond de la maison entend tout, et le public du stream vote les sabotages.

C'est un prototype : il sert à savoir si la boucle de jeu est drôle, pas à être beau. Tout y est fait de boîtes et de sons fabriqués par le code ; il n'y a aucun fichier d'image ni de son.

**Jouer tout de suite** : https://stonevalleyoff-ai.github.io/Portefaix/ (une fois GitHub Pages allumé sur ce dépôt : Settings › Pages › Source : GitHub Actions).

## L'application

Le jeu est une application web installable (PWA). Depuis la page du jeu :
- **sur Android** (Chrome) : le menu ⋮ › « Installer l'application » (ou « Ajouter à l'écran d'accueil ») ;
- **sur iPhone et iPad** (Safari) : le bouton Partager › « Sur l'écran d'accueil » ;
- **sur un ordinateur** (Chrome, Edge) : l'icône d'installation dans la barre d'adresse.

Installée, elle s'ouvre en plein écran, couchée, sans barre de navigateur. Le jeu entier (35 Mo) est gardé sur l'appareil à la première visite : ensuite il se lance **sans réseau**, pour jouer seul. Se connecter, le salon en ligne et le chat de Twitch demandent le réseau. Une nouvelle version est prise en arrière-plan à une visite, et servie à la suivante.

## Jouer

Dans un navigateur : l'adresse ci-dessus. Pour la version de bureau, il faut [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (la version standard) : ouvrir `project.godot`, puis F5. Ou, sous Linux :

```
outils/godot.sh --path .
```

- **Dans un navigateur** : on y joue seul, ou en ligne avec un salon ; un navigateur ne peut pas héberger en réseau local. Le micro y est éteint au départ ; la case du menu le rallume, si le navigateur l'accorde.
- **Le compte** : le jeu s'ouvre sur une page de connexion. On s'y connecte avec son **compte Stone Valley** (le même e-mail, le même mot de passe : les comptes du projet Supabase « Vallée de pierre »), ou l'on joue sans compte. Connecté, on se choisit un pseudo, que les autres voient au salon et au-dessus de sa tête ; sans pseudo choisi ici, c'est celui de sa sauvegarde Stone Valley. On reste connecté d'une fois sur l'autre.
- **Jouer seul** : on est son propre hôte. Le piano et l'armoire ne se soulèvent pas seul ; le quota en tient compte.
- **En ligne, avec un salon et son code** (dans un navigateur, connecté à son compte) : l'un clique « Ouvrir un salon en ligne » ; le jeu lui donne un **code de cinq lettres ou chiffres**. Les autres le tapent dans « le code d'un salon » et entrent. Le salon dit qui est là et qui est déjà relié ; l'hôte lance la nuit. De 2 à 6 porteurs ; on n'entre pas dans une nuit commencée. Rien à ouvrir sur sa box.
- **À plusieurs en réseau local** (la version de bureau) : l'un clique « Héberger », puis « Commencer la nuit » quand tout le monde est au salon. Les autres tapent son adresse et « Rejoindre ». Sur le même réseau local, c'est l'adresse que le salon affiche. Par Internet, l'hôte doit ouvrir le port **24680 en UDP** sur sa box, ou tout le monde passe par un réseau privé (Tailscale, ZeroTier, Hamachi). On n'entre pas dans une nuit commencée.
- **Avec son chat Twitch** : l'hôte tape le nom de sa chaîne dans le menu. Le jeu lit le chat en lecture seule, sans compte ni mot de passe. Sans chaîne, des spectateurs de paille votent au hasard.

| | |
| --- | --- |
| marcher | ZQSD (ou WASD : ce sont les touches physiques), ou les flèches |
| courir (bruyant) | Maj |
| s'accroupir (discret, et moins visible) | Ctrl |
| sauter | Espace |
| prendre, poser, klaxonner | E, ou le clic gauche |
| lancer ce qu'on tient | le clic droit |
| la torche | F |
| crier (pour qui n'a pas de micro) | V |
| libérer la souris | Échap |

**Au doigt** (un téléphone tenu à l'horizontale, une tablette) : le pouce gauche marche, avec un joystick qui naît où il se pose, dans la moitié gauche de l'écran. Le pouce droit regarde, en glissant, et presse les boutons : **Agir** (prendre, poser, klaxonner ; mort, pousser), **Lancer**, **Saut**, **Courir** et **Bas** (s'accroupir), qui restent enfoncés jusqu'à ce qu'on les retouche, **Torche** et **Crier** en haut à gauche. Le jeu passe au doigt tout seul sur un écran tactile, ou au premier toucher.

## Les règles

- **Le quota** : 30 % de la valeur de la maison pour un porteur seul, 6 % de plus par porteur, 60 % au plus. Ce qui compte est ce qui est **posé** dans la zone jaune, à sa valeur du moment.
- **Porter** : chaque porteur donne une force limitée. Seul, on soulève jusqu'à 45 kg ; à deux, 90 ; à trois, 135. Ce qui pèse plus se traîne. Ce qu'on porte ralentit, et échappe des mains si l'on s'en éloigne de 4 m (un canapé coincé dans une porte, par exemple).
- **La casse** : un choc coûte à un meuble une part de sa valeur, selon sa fragilité. Un vase perd presque tout, un canapé presque rien.
- **Le bruit** : les pas, la course, les cris, les chocs et le **vrai micro** du joueur ont une portée en mètres. La jauge en bas à gauche la montre.
- **La chose** : elle dort une minute, puis rôde. Elle va voir tout bruit qui porte jusqu'à elle. Elle ne tue pas d'office, et on a de quoi lui échapper :
  - elle ne voit que **devant elle**, à 9 m (moitié moins si l'on est accroupi), et sent ce qui est à moins de 2,5 m : on passe dans son dos ;
  - quand elle voit un porteur, elle **crie près de deux secondes** avant de s'élancer : c'est le moment de fuir ;
  - elle va plus vite qu'on ne marche et moins vite qu'on ne court, ne chasse pas plus de 10 secondes d'une traite, et renonce si elle ne voit plus sa proie pendant 2,5 secondes ;
  - elle **ne sort pas de la maison** : la cour est sûre ;
  - son **premier coup blesse** sans tuer, puis elle rentre à sa tanière. La blessure guérit en 45 secondes ; blessé, le coup suivant tue.
  Elle traverse les meubles et les portes claquées, pas les murs.
- **Les morts** hantent la maison : ils volent, et poussent les objets de moins de 12 kg. Pour aider, ou non.
- **Le chat** : toutes les 40 secondes, trois sabotages sont proposés. Le public vote `1`, `2` ou `3` pendant 15 secondes, une voix par personne. Les cinq sabotages : couper le courant, claquer une porte, faire du vacarme sur un porteur, griller les torches, mettre les meubles en apesanteur.
- **La fin** : gagné si le quota est dans la zone à 6 h, ou si l'on klaxonne le camion une fois le quota atteint. Perdu si l'aube se lève sur un camion trop vide, ou si plus personne n'est en vie. Klaxonner sans le quota ne fait que prévenir la chose.

Tous les réglages sont dans `scripts/regles.gd`.

## Comment c'est fait

| fichier | ce qu'il fait |
| --- | --- |
| `scripts/regles.gd` | tous les nombres du jeu, et le catalogue des meubles |
| `scripts/principal.gd` | le menu, le réseau, la partie : ce que l'hôte décide et redit aux autres |
| `scripts/maison.gd` | le plan en lettres d'où sortent les murs, les portes, les lampes, la cour, le camion, et la grille où marche la chose |
| `scripts/objet.gd` | un meuble : son dessin, le portage, la casse |
| `scripts/joueur.gd` | un porteur, vivant ou mort |
| `scripts/creature.gd` | la chose : entendre, voir, chasser |
| `scripts/chat.gd` | les votes, les spectateurs de paille, la lecture du chat de Twitch |
| `scripts/micro.gd` | le niveau du micro (rien n'est enregistré ni envoyé) |
| `scripts/sons.gd` | les sons, fabriqués au lancement |
| `scripts/interface.gd` | ce qui s'écrit à l'écran |
| `scripts/compte.gd` | le compte : se connecter, rester connecté, le pseudo |
| `scripts/salon.gd` | le salon en ligne : son code, qui y est, relier les joueurs |
| `supabase.sql` | les tables et les fonctions du salon, dans le Supabase de Stone Valley |
| `outils/faux-service.js` | un faux service de comptes et de salons, pour les essais |
| `outils/essai-en-ligne.js` | l'essai en ligne : trois navigateurs, un salon |
| `outils/construire.sh`, `outils/pwa.js` | construire l'application web installable, dans `site/` |
| `outils/essai-pwa.js` | l'essai de l'application : le manifeste, le service worker, jouer sans réseau |
| `outils/banc.js` | ce qui se vérifie sans Godot |
| `outils/godot.sh` | lancer Godot 4.3, la version officielle, téléchargée et vérifiée |
| `.github/workflows/site.yml` | à chaque envoi : les essais, puis la publication sur GitHub Pages |
| `scripts/tactile.gd` | jouer du doigt : le joystick, le regard, les boutons |
| `scripts/essai.gd` | les essais sans écran |

**Le compte** : la connexion passe par le service de comptes de Supabase, avec la clé publique du projet (faite pour être dans le jeu). Le jeu ne lit que qui l'on est et le pseudo de sa sauvegarde ; il **n'écrit jamais** dans la sauvegarde de Stone Valley (`vp_comptes`), et n'a rien changé à la base. Le pseudo choisi ici est gardé sur le compte lui-même (ses métadonnées). Le mot de passe n'est pas gardé : seul un jeton de reprise l'est, sur l'appareil (`user://compte.json`), effacé quand on se déconnecte. Un compte se crée dans Stone Valley, pas ici. Pour l'instant le pseudo qu'un invité annonce à l'hôte est cru sur parole : la preuve (le jeton du compte, `compte.jeton`) servira au jeu en ligne.

**Le salon en ligne** (`scripts/salon.gd`, `supabase.sql`) : Supabase ne porte que le salon. Trois tables (`pf_salons`, `pf_membres`, `pf_signaux`) et six fonctions (`pf_salon_creer`, `_rejoindre`, `_etat`, `_signal`, `_partir`, `_quitter`), dans le projet « Vallée de pierre », à côté de celles de Stone Valley et sans y toucher. Les tables sont fermées : on n'y accède que par les fonctions, réservées aux comptes connectés, et chacun n'y voit que son salon. Le salon sert à se trouver : pendant qu'on attend, le jeu lui demande une fois par seconde qui est là et ce qu'on lui a laissé, et les navigateurs s'y échangent de quoi se relier (WebRTC). Puis la partie passe **directement d'un joueur à l'autre**, chaque invité relié à l'hôte : la base ne voit rien de la nuit. Un salon que son hôte quitte est effacé ; un salon oublié l'est au bout d'un quart d'heure.

Deux limites, connues : sur un ordinateur, hors d'un navigateur, Godot demande une extension pour WebRTC (webrtc-native) que le projet ne porte pas, donc **le jeu en ligne se joue dans un navigateur** ; et les joueurs se trouvent à travers leurs box avec un serveur STUN public, sans relais : derrière certains réseaux (des réseaux mobiles, des réseaux d'entreprise), deux joueurs peuvent ne pas réussir à se relier.

**Le réseau** : l'hôte fait foi. Il fait seul tomber les meubles, penser la chose, compter le chargement et dépouiller les votes, et le redit aux autres vingt fois par seconde. Chaque joueur ne mène que son porteur, et demande le reste à l'hôte (prendre, lâcher, pousser, klaxonner). Tout le monde bâtit la même maison d'après une graine donnée au départ.

## Les essais

```
outils/godot.sh --headless --path . --import            # la première fois
outils/godot.sh --headless --path . -- --essai          # une partie seul, jouée par le programme
outils/godot.sh --headless --path . -- --essai-reseau   # un hôte et un invité sur la même machine
outils/godot.sh --headless --path . -- --essai-compte   # la connexion, contre un faux service de comptes local
```

Chacun sort avec le code 0 si tout passe. Sans écran, Godot écrit des lignes `Parameter "m" is null` : c'est son rendu factice qui ne connaît pas les maillages, sans effet sur le jeu.

L'essai en ligne joue dans trois navigateurs (il lui faut Playwright et son Chromium) : trois comptes se connectent, l'un ouvre un salon, les deux autres y entrent par son code, la nuit commence et ils se voient bouger. Les comptes et le salon passent par un faux service ; la partie passe pour de bon d'un navigateur à l'autre.

```
outils/construire.sh
node outils/essai-en-ligne.js site
```

Construire l'application web, dans `site/`, et l'essayer (le manifeste, le service worker, le jeu relancé et joué sans réseau) :

```
outils/construire.sh
node outils/essai-pwa.js site
```

À chaque envoi sur `main`, GitHub refait tout cela (`.github/workflows/site.yml`) : la syntaxe, le banc, les trois essais sans écran, la construction, l'essai de l'application, puis la publication sur GitHub Pages.

`--essai` joue toujours la même maison (la graine 7) ; `--essai --graine=12` en essaie une autre.

## Où en est le prototype

- **Vérifié dans Godot 4.3, sans écran** : les deux essais passent (67 vérifications seul, 15 en réseau, 20 pour la connexion ; avec `--en-ligne`, le vrai service refuse bien un compte qui n'existe pas).
- **Vérifié dans Chromium, l'application installable** : l'essai passe (11 vérifications) : le manifeste et ses icônes, le service worker qui s'installe et garde le jeu entier, le jeu relancé et joué seul réseau coupé.
- **Vérifié dans Chromium** (WebGL 2, un téléphone émulé de 844 sur 390, de vrais touchers) : l'export web se charge, le menu passe au doigt, une partie commence, le joystick fait marcher jusque dans le salon, le pouce droit tourne le regard pendant qu'on marche, « Courir » reste enfoncé, « Torche » éteint la lampe. Deux pouces à la fois : le gauche tenant le joystick, le droit glisse et revient sans que la vue saute, puis glisse et la vue tourne.
- **Vérifié dans trois Chromium à la fois** : l'essai en ligne passe (28 vérifications). Et les fonctions du salon, dans un Postgres local : les codes, six porteurs au plus, la nuit commencée fermée aux nouveaux, le ménage des vieux salons, tout refusé sans compte.
- **Dans la base** (le 11 novembre 2026) : le schéma `supabase.sql` est appliqué à « Vallée de pierre ». Les trois tables sont fermées, les six fonctions du salon sont réservées aux comptes connectés (sans compte, le service répond 401), et rien de Stone Valley n'a changé.
- **Pas encore vérifié** : l'installation sur un vrai téléphone (Android, iPhone) ; la publication sur GitHub Pages ; le salon en ligne entre deux vraies maisons, à travers deux box ; une connexion réussie avec un vrai compte Stone Valley (l'essai joue contre un faux service qui répond comme le vrai) ; le clavier du téléphone dans les champs de la page de connexion ; une partie jouée par une personne ; le jeu sur un vrai téléphone (la vitesse du rendu, la taille des boutons sous de vrais pouces) ; le micro ; le vrai chat de Twitch (seule la lecture de ses lignes est essayée) ; le réseau entre deux machines.
