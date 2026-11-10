# ileDelbe 0.3 — modules, styles au choix et réglages

Date : 2026-11-10
Statut : brouillon, à valider
Base : 0.2.0 publiée (spec `2026-11-09-notch-stack-v2-design.md`)
Maquette de référence : https://claude.ai/artifact/PE44snMiTuL5rvj9RE7hqw (pistes A · Bento, B · Morph, C · Rail, et le panneau Réglages)

## Intention

La 0.2 a une seule présentation : un panneau à onglets de 548×236. La 0.3 ne change aucune fonction, mais laisse l'utilisateur choisir comment l'encoche range ses modules, et régler les détails qui comptent pour lui (couleur, modules visibles, délai, durées du minuteur…).

Le code est découpé par **module** (Musique, Minuteur, Agenda, Fichiers). Chaque module sait s'afficher en plusieurs **tailles**. Un **style** se contente de placer ces vues. Ajouter un style plus tard doit coûter une vue de disposition et une règle de taille, sans toucher à la gestion de la fenêtre ni au survol.

Livraison en deux temps (décidé avec l'utilisateur) : la 0.3 apporte le découpage, deux nouveaux styles et les réglages ; la 0.4 ajoute le style Rail.

## Objectifs 0.3

1. **Découpage par module.** Chaque module expose ses vues en trois tailles :
   - **compacte** : une seule ligne d'environ 70 pt de haut (style Île) ;
   - **carte** : une carte pour une grille (style Grille) ;
   - **pleine** : le volet actuel de la 0.2 (style Onglets, et plus tard le contenu du Rail).
   Les vues d'une même taille reçoivent les mêmes services et actions que les volets actuels. Pas de nouvelle fonction.
2. **Trois styles au choix** dans les réglages :
   - **Île** (piste B, **style par défaut**) : une activité à la fois, dans un panneau étroit. Détails plus bas.
   - **Grille** (piste A) : tous les modules visibles d'un coup, sans onglets. Détails plus bas.
   - **Onglets** : la présentation 0.2 telle quelle (barre d'onglets, volets pleins), qui se limite aux modules visibles, dans l'ordre choisi.
3. **Réglages** dans une fenêtre dédiée. Liste plus bas. Les changements s'appliquent tout de suite, sans relancer.
4. **Encoche fermée réglable** : pochette et égaliseur (0.2), titre qui défile, ou rien.

## Style Île (détails)

- Panneau de **460 pt de large**. La hauteur couvre la bande de l'encoche matérielle, une ligne compacte et une rangée de points de pagination. Même taille pour toutes les pages en 0.3 (pas de hauteur par module).
- Une page par module visible, dans l'ordre des réglages. Page affichée à l'ouverture : même règle qu'en 0.2 (minuteur qui a sonné, sinon musique en cours, sinon la dernière vue), ou le module forcé par le réglage « À l'ouverture ». Ouvrir depuis la bulle affiche la page Minuteur.
- **Changer de page :**
  - défilement horizontal à deux doigts sur le trackpad, une page par geste (pas de défilement continu) ;
  - clic sur un point de pagination.
  Les pages glissent avec une animation ressort. Pas de bouclage : au bout, rien ne se passe.
- **Vue « Tout voir »** : un bouton grille à droite des points ouvre la disposition Grille dans le même panneau, à la taille de la Grille. On revient aux pages par le même bouton. Fermer le panneau ramène toujours aux pages au prochain survol.
- Les contrôles de chaque page sont les plus utiles du module :
  - **Musique** : pochette, titre, artiste, progression cliquable, précédent, lecture/pause, suivant. Pas de volume ni d'historique, qui restent dans « Tout voir ».
  - **Minuteur** : en cours, anneau + temps restant + heure de fin + « +1 min », Pause/Reprendre, Arrêter ; au repos, les trois durées ; quand il sonne, « OK ».
  - **Agenda** : le prochain événement, son heure de début et le bouton « Rejoindre » s'il y a un lien visio. Sans autorisation, le même message et le même bouton qu'en 0.2.
  - **Fichiers** : 3 vignettes au plus (icône, nom, heure relative), cliquables et glissables comme en 0.2, plus « +2 » quand le réglage en demande 5.

## Style Grille (détails)

- Panneau d'environ **640 pt de large**.
- À gauche, la carte Musique : pochette, titre, artiste, progression, contrôles, volume, et les 3 derniers morceaux en vignettes.
- À droite, les autres modules visibles en cartes empilées, dans l'ordre des réglages.
- Sans Musique, les cartes passent sur deux colonnes et le panneau rétrécit.
- La hauteur est fixée par style et par taille du panneau : pas de panneau qui change de taille selon le contenu.

## Réglages

Fenêtre « Réglages ileDelbe ». On l'ouvre :
- par un bouton engrenage dans le panneau ouvert (Île : au bout de la rangée de points ; Grille : coin bas droit ; Onglets : à droite de la barre d'onglets) ;
- par « Réglages… » dans le menu contextuel de l'encoche (clic droit), à côté de « Quitter ».

C'est le seul cas, avec « Rejoindre » et l'ouverture d'un fichier, où ileDelbe prend le focus. À la fermeture de la fenêtre, l'app redevient un agent sans fenêtre active.

| Réglage | Valeurs | Défaut |
|---|---|---|
| Style | Île, Grille, Onglets | Île |
| Couleur | Pochette, Fixe (5 teintes proposées), Aucune | Pochette |
| Intensité du halo | 0 à 100 % | 60 % (rendu actuel de la 0.2 à 100 %) |
| Modules | afficher/masquer chacun des 4, et les réordonner | les 4, ordre Musique, Minuteur, Agenda, Fichiers |
| À l'ouverture | Automatique, ou toujours un module visible | Automatique |
| Encoche fermée pendant la lecture | Pochette + égaliseur, Titre, Rien | Pochette + égaliseur |
| Délai d'ouverture au survol | 0,05 à 0,60 s, par pas de 0,05 | 0,15 s |
| Durées du minuteur | trois durées, 1 à 180 min chacune | 5, 10, 25 |
| Taille du panneau | Normale, Compacte | Normale |
| Fichiers récents | 3 ou 5 | 3 |
| Lancer à l'ouverture de session | oui / non | non |

Précisions :
- **Couleur** : elle s'applique au halo, au remplissage de la progression et à l'égaliseur. Le minuteur et son alerte restent orange. « Aucune » donne le rendu sans pochette de la 0.2 (barre blanche, pas de halo).
- **Modules masqués** : un module masqué disparaît du panneau, quel que soit le style, et de l'encoche fermée. Exceptions et conséquences :
  - Un minuteur qui tourne continue, et l'**alerte de fin s'affiche toujours** (avec le son), même si le module Minuteur est masqué. Ailes et bulle du minuteur, elles, n'apparaissent pas.
  - Musique masquée : plus d'ailes musique ni de halo. La lecture n'est pas touchée.
  - Agenda masqué : pas de ligne « dans N min », et la demande d'accès au calendrier n'arrive jamais tant qu'il reste masqué.
  - Les quatre masqués : le panneau ouvert affiche « Aucun module affiché » et l'engrenage.
- **À l'ouverture** : si le module forcé est masqué ensuite, le réglage repasse à Automatique. Le minuteur qui a sonné passe toujours avant le module forcé.
- **Encoche fermée « Titre »** : aile gauche avec la pochette, aile droite plus large (environ 120 pt) avec « titre · artiste » qui défile lentement. Le défilement ne tourne que si le texte dépasse, et en reste à 15 images/s au plus, comme l'égaliseur. « Rien » : encoche nue pendant la lecture, sans halo. Un minuteur en cours s'affiche alors dans les ailes, comme sans musique (pas de bulle).
- **Délai d'ouverture** : seul le délai d'ouverture est réglable. La fermeture reste à 0,30 s.
- **Taille Compacte** : panneau et contenu réduits à environ 88 %, pour les trois styles.
- **Fichiers 5** : Onglets et Grille montrent 5 fichiers ; Île en montre 3 et « +2 ».
- **Lancement à l'ouverture de session** : `SMAppService.mainApp`. Si macOS refuse ou demande une approbation, la case reflète l'état réel et une ligne explique où l'approuver (Réglages Système, Général, Ouverture).
- Stockage dans `UserDefaults`, une seule clé versionnée. Une valeur invalide ou illisible retombe sur le défaut de ce réglage, sans casser les autres. Les clés 0.2 existantes (dernier onglet, minuteur, historique) sont conservées.

## Non-objectifs 0.3

- Le style Rail (0.4).
- Nouvelles fonctions de modules, ou réglages propres à un module au-delà de la liste (choix des calendriers, dossiers exclus, son du minuteur : plus tard).
- Thèmes complets, police, couleur libre (sélecteur de couleur), hauteur de page Île variable par module.
- Raccourcis clavier, écrans externes, Macs sans encoche.
- Aperçu en direct dans la fenêtre Réglages : on voit le résultat au prochain survol.

## Anti-objectifs (repris, toujours valables)

- Ne jamais voler le focus, sauf les trois cas listés.
- Ne pas gêner la barre de menus hors de la forme visible : la zone de survol et les clics suivent la forme **réellement dessinée** du style courant (Île, Grille, « Tout voir », bulle, ailes asymétriques en mode Titre).
- Pas d'ouvertures intempestives : un défilement à deux doigts ne doit jamais ouvrir le panneau fermé ni changer de page quand il est fermé.
- CPU ~0 % au repos. Le geste de défilement est piloté par les événements, sans boucle.
- Pas de rendu bricolé : transitions ressort entre pages, entre styles « pages » et « Tout voir », et à l'ouverture.

## Contraintes

- macOS 15.4+, Swift 6, SwiftPM, même structure qu'avant : la logique pure dans `IleDelbeCore` est testée ; services et vues dans `IleDelbe`.
- **La taille du panneau ouvert ne doit plus être une constante.** Le calcul (style, taille Normale ou Compacte, modules visibles, Musique visible ou non, « Tout voir » ou non) est une fonction pure dans `IleDelbeCore`, testée. La fenêtre, la zone de survol et le passage des clics en découlent.
- Ailes fermées gauche et droite indépendantes (mode Titre), l'encoche matérielle restant centrée.
- Le défilement à deux doigts passe par les événements de défilement du panneau, uniquement quand il est ouvert et sous le pointeur.
- Licence MIT, pas de code copié de projets GPL.
- README : une image par style (Île, Grille, Onglets) et une de la fenêtre Réglages, générées par le moteur d'images existant. CHANGELOG : le style par défaut change à la mise à jour, et on retrouve l'ancien aspect avec le style Onglets.

## Décisions (mes choix)

- **Onglets conservé comme troisième style** : c'est le code 0.2 déjà testé, ceux qui préfèrent l'ancien aspect le gardent, et il valide le découpage avec trois styles dès la 0.3.
- **Île par défaut, y compris à la mise à jour** : c'est la direction retenue. Le CHANGELOG le dit.
- **Île à taille fixe en 0.3** : une seule hauteur pour toutes les pages, pour éviter un panneau qui saute en changeant de page. Une hauteur par module reste possible plus tard.
- **« Tout voir » = la Grille**, pas une quatrième vue.
- **Teintes fixes** : bleu `#5B8CFF`, vert `#3ECF8E`, violet `#C06BFF`, jaune `#F5C542`, blanc. Pas de sélecteur libre.
- **Défilement** : un geste = une page, avec un seuil et un verrou jusqu'à la fin du geste (phase terminée), pour que l'inertie ne fasse pas sauter plusieurs pages.
- **Alerte du minuteur prioritaire** sur le masquage du module : une alarme ne doit pas passer inaperçue.

## Précisions (mes choix, après relecture)

- **Engrenage cliqué** : le panneau se ferme tout de suite, et la fenêtre Réglages s'ouvre et prend le focus. Le survol de l'encoche continue de marcher normalement pendant que la fenêtre est ouverte. Pour rouvrir, le pointeur doit sortir de la zone puis revenir. Pas d'état « suspendu ».
- **Dimensions cibles** (taille Normale ; `h` = hauteur de l'encoche matérielle). Ce sont des constantes par cas, ajustables au rendu, mais jamais calculées d'après le contenu :
  - Onglets : 548 × 236, comme en 0.2.
  - Île : 460 × (h + 96).
  - Grille avec Musique : 640 × (h + 236).
  - Grille avec Musique seule : 380 × (h + 236).
  - Grille sans Musique : 520 de large ; hauteur h + 32 + n·96 + (n − 1)·10, avec n = nombre de rangées de 2 cartes.
  - Aucun module visible : 300 × (h + 80), quel que soit le style.
- **Un seul module visible** : Île n'affiche pas de points, mais garde les boutons « Tout voir » et engrenage ; Onglets garde sa barre avec un seul onglet et l'engrenage.
- **« Tout voir »** n'affiche que les modules visibles, avec les mêmes règles de taille que la Grille.
- **Minuteur masqué qui sonne** : l'encoche fermée montre l'alerte comme en 0.2. À l'ouverture, le panneau affiche le Minuteur avec « OK » quel que soit le style, comme si le module était visible, jusqu'à ce qu'on valide. Il redevient masqué ensuite.
- **Dernier module vu** : la clé 0.2 du dernier onglet est reprise telle quelle, partagée par tous les styles. Si ce module est masqué, on prend le premier module visible.
- **Taille Compacte** : la fonction de taille multiplie la largeur du panneau, et sa hauteur **sous la bande de l'encoche matérielle**, par 0,88, arrondies au point. La bande elle-même ne rétrécit pas : sinon le contenu passerait sous l'encoche. Le contenu suit avec une mise à l'échelle. La zone de survol et les clics suivent la taille réduite. Les ailes et la bulle de l'encoche fermée ne changent pas.
- **Ailes en mode Titre** : 36 pt à gauche, 120 pt à droite. La bulle se place à droite de l'aile réellement dessinée. L'alerte du minuteur (110 pt de chaque côté) remplace le mode Titre tant qu'elle dure.
- **Défilement** : il est reçu par la vue du panneau, qui est sous le pointeur et accepte les clics à ce moment-là. Le panneau ne devient jamais fenêtre principale. Si un écouteur local s'avère nécessaire, il est accepté. Pas d'écouteur global pour le défilement.
- **Lancement à l'ouverture de session** : il se teste à la main sur la version signée installée dans `/Applications`. Avec un build ad hoc, la case peut refuser ou afficher « approbation requise », et c'est accepté.
- **Images du README** : le moteur est `Sources/IleDelbe/App/ReadmeAssets.swift` (`--render-readme-assets`). Il doit rendre les nouveaux styles et la fenêtre Réglages.

## Laissé au builder

- Dimensions exactes, rayons, typographie et timings (viser la maquette).
- Seuil exact du geste de défilement.
- Forme exacte du type « module » (protocole, enum, registre) et des styles, du moment qu'un style se résume à une disposition et à une règle de taille.
- Fenêtre Réglages : SwiftUI dans une `NSWindow`, mise en page libre, sans aperçu.
- Tests : au minimum la logique pure : calcul des tailles pour chaque style et chaque cas de modules visibles, lecture et validation des réglages (valeurs hors bornes, clé absente ou illisible), choix de la page à l'ouverture avec module forcé ou masqué, navigation entre pages (bornes), ailes asymétriques, et règles de l'encoche fermée avec modules masqués (dont l'alerte toujours visible).

## 0.4 (prévu)

Style **Rail** (piste C) : colonne d'icônes avec l'état en direct de chaque module, contenu en taille pleine à côté, changement de module au survol d'une icône. Il doit s'ajouter sans modifier la gestion de la fenêtre ni le survol.
