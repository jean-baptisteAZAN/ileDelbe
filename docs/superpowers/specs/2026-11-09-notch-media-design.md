# ileDelbe — l'encoche du Mac en Dynamic Island (v1 : médias)

Date : 2026-11-09
Statut : brouillon, à valider

## Intention

Sur un MacBook à encoche, pouvoir piloter le média en cours (Spotify, YouTube dans le navigateur, etc.) depuis n'importe quelle app, sans changer de fenêtre. L'encoche devient le point d'accès : on survole, elle s'agrandit en panneau média, comme la Dynamic Island de l'iPhone.

Projet perso d'abord (outil utile au quotidien), pensé pour être open-sourcé ensuite.

## Objectifs v1

1. **Survol de l'encoche → panneau média.** Le pointeur entre dans la zone de l'encoche : elle s'agrandit avec une animation fluide en un panneau. Le pointeur sort du panneau : il se referme après un court délai.
2. **Contenu du panneau ouvert :**
   - pochette, titre, artiste ;
   - précédent / play-pause / suivant ;
   - barre de progression avec temps écoulé / durée, cliquable et glissable pour sauter à un moment ;
   - slider de volume (volume de sortie système).
3. **État fermé quand un média joue :** l'encoche s'élargit légèrement et affiche une mini pochette à gauche et un petit égaliseur animé à droite. En pause ou sans média : encoche noire normale, invisible.
4. **Source = le « Now Playing » système.** Ce qui apparaît dans le Centre de contrôle macOS (Spotify, Apple Music, YouTube dans Chrome/Safari/Arc…) est ce que l'app pilote. Pas d'intégration spécifique par app.

## Non-objectifs v1

- Raccourci clavier global (choix explicite : survol seul).
- Écrans externes et Macs sans encoche.
- Autres widgets (calendrier, batterie, notifications, AirDrop, fichiers…).
- Choisir entre plusieurs lecteurs actifs : on suit celui que macOS considère comme « Now Playing ».
- Préférences, réglages, onboarding.
- Distribution signée/notarisée, Homebrew, mises à jour auto.

## Anti-objectifs (échec même si ça « marche »)

- **Voler le focus.** Survoler ou cliquer le panneau ne doit jamais activer ileDelbe ni sortir l'app courante du premier plan ; la saisie clavier en cours ne doit pas être interrompue.
- **Gêner la barre de menus.** En dehors de l'encoche (et du panneau quand il est ouvert), les clics passent normalement aux menus et icônes.
- **Ouvertures intempestives.** Aller chercher un menu près de l'encoche ne doit pas déclencher le panneau à chaque passage (petit délai de survol).
- **Consommer en idle.** Pas de polling agressif ni d'animation qui tourne quand rien ne joue. CPU ~0 % en idle.
- **Avoir l'air bricolé.** Le panneau doit se fondre dans l'encoche (noir, coins arrondis, aligné pile sur l'encoche), animations type ressort.

## Contraintes

- Machine cible : MacBook à encoche, **macOS 15.4+**.
- **Accès « Now Playing » sur macOS 15.4+ :** Apple a fermé le framework privé `MediaRemote` aux apps tierces (refus côté `mediaremoted`). Le contournement connu et utilisé par d'autres projets open source est [`mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter) (BSD-3) : un script lancé via `/usr/bin/perl` (binaire Apple, donc autorisé) charge un petit framework qui parle à `MediaRemote` et renvoie un flux JSON (métadonnées, pochette, état, position) et accepte des commandes (play/pause, next, prev, seek). C'est la voie retenue. Risque assumé : Apple peut casser ça dans une future version ; l'architecture isole cette couche pour pouvoir la remplacer.
- Open source : licence **MIT** (mon choix). Ne pas copier de code depuis des projets GPL (ex. boring.notch) ; on peut s'en inspirer conceptuellement.

## Décisions de construction (mes choix, l'utilisateur me les a délégués)

- **Swift + SwiftUI**, projet Xcode, app native. Pas d'Electron/Tauri.
- **App agent** (`LSUIElement = YES`) : pas d'icône dans le Dock, pas de barre de menus propre. Pour quitter v1 : clic droit sur le panneau → « Quitter » (minimal).
- **Fenêtre :** un `NSPanel` sans bordure, non activant, transparent, au-dessus de la barre de menus, présent sur tous les Spaces et par-dessus les apps en plein écran. Taille / position de l'encoche calculées depuis `NSScreen` (`safeAreaInsets.top`, `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`) sur l'écran intégré.
- **Clics hors zone :** la fenêtre ignore les événements souris en dehors de la forme visible (encoche ou panneau), pour ne pas bloquer la barre de menus.
- **Volume :** CoreAudio sur le périphérique de sortie par défaut (lecture + écriture + suivi des changements externes).
- **Structure en couches :**
  - `NowPlayingService` : encapsule `mediaremote-adapter` (processus long, lecture du flux JSON, envoi des commandes), expose un état observable (titre, artiste, pochette, durée, position, en lecture ou non, app source).
  - `VolumeService` : CoreAudio.
  - `NotchWindowController` : fenêtre, géométrie de l'encoche, détection de survol, ouverture/fermeture.
  - Vues SwiftUI : état fermé (pochette + égaliseur) et état ouvert (panneau complet).
- La position de lecture est interpolée localement entre deux mises à jour (position + horodatage + vitesse), pas de polling.

## Cas limites (mes choix)

- Le survol ouvre le panneau même en pause, pour pouvoir relancer la lecture.
- Capot fermé ou pas d'écran intégré : rien ne s'affiche.
- Sortie audio sans contrôle de volume : slider désactivé. Source sans seek ou sans durée : barre de progression désactivée (affichage seul ou masquée).
- Apps en plein écran : le panneau ne gêne pas la barre de menus quand elle redescend.

## Laissé au builder

- Dimensions exactes du panneau ouvert, rayons, timings et courbes d'animation (viser la sensation iPhone).
- Délais de survol (ouverture / fermeture) — point de départ suggéré : ~150 ms à l'ouverture, ~300 ms à la fermeture.
- Comment embarquer `mediaremote-adapter` (sous-module git, Swift Package, copie vendorisée avec licence).
- Rendu de l'égaliseur (fausse animation, pas d'analyse audio réelle).
- Comportement si aucun média n'a jamais joué depuis le lancement (panneau vide élégant ou pas d'ouverture).
- Organisation des tests ; au minimum tests unitaires sur le parsing du flux de l'adapter et l'interpolation de position.

## Après la v1 (idées, pas engagées)

Raccourci clavier global, écrans externes / Macs sans encoche, sélection du lecteur, autres widgets, release signée + Homebrew cask.
