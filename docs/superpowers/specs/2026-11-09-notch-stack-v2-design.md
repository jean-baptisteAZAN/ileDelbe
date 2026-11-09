# ileDelbe v2 — « Stack » : l'encoche devient un hub d'activités

Date : 2026-11-09
Statut : brouillon, à valider
Base : v1 mergée dans `main` (spec `2026-11-09-notch-media-design.md`)
Maquette de référence : https://claude.ai/artifact/GNrrJyn1E7SWrgvnoVALik (direction **B · Stack**, avec le halo de **A · Halo**)

## Intention

La v1 pilote le média depuis l'encoche. La v2 garde ce cœur et fait de l'encoche un petit hub, comme les activités en direct de l'iPhone : musique, minuteur, prochain rendez-vous, fichiers récents. Deux activités peuvent coexister : l'encoche principale et une bulle détachée à sa droite. Le rendu reprend le halo coloré de la direction A.

Toujours un outil perso d'abord, publié en open source.

## Objectifs v2

1. **Halo coloré.** La couleur moyenne de la pochette en cours colore :
   - une lueur douce autour de l'encoche fermée pendant la lecture ;
   - une lueur plus marquée sous le panneau ouvert ;
   - l'ombre de la grande pochette et le remplissage de la barre de progression.
   Sans pochette, ou si la couleur est trop sombre ou trop grise pour se voir, pas de lueur (barre blanche comme en v1).
2. **Panneau à onglets** : Musique, Minuteur, Agenda, Fichiers, dans une barre segmentée en haut du panneau. Un point orange sur l'onglet Minuteur quand un minuteur tourne. À droite de la barre, une ligne d'info : « <titre> dans N min » quand un rendez-vous commence dans moins de 60 minutes.
3. **Onglet affiché à l'ouverture (automatique) :**
   - Minuteur s'il a sonné et n'a pas encore été vu ;
   - sinon Musique si un média joue ;
   - sinon le dernier onglet utilisé.
4. **Musique** : tout ce que fait la v1 (pochette, titre, artiste, précédent/play-pause/suivant, progression cliquable, volume), plus une colonne « Écoutés récemment » avec les 3 derniers morceaux (pochette, titre, heure).
5. **Minuteur** :
   - lancement uniquement depuis le panneau, avec des durées toutes prêtes de 5, 10 et 25 min ;
   - en cours : +1 min, Pause/Reprendre, Arrêter ;
   - un seul minuteur à la fois ;
   - à la fin : son système et encoche en alerte orange, jusqu'à ce qu'on la survole ou qu'on clique, avec effacement automatique après 60 s.
6. **Bulle détachée.** Quand un minuteur tourne **et** qu'un média joue, le minuteur s'affiche dans une bulle à droite de l'encoche (anneau orange + mm:ss). Quand seul le minuteur tourne, il s'affiche dans les ailes de l'encoche, sans bulle. La bulle se fond dans le panneau quand il s'ouvre.
7. **Agenda :**
   - les 2 prochains événements des prochaines 24 h, tous calendriers macOS confondus, sans les événements « journée entière » ;
   - un bouton « Rejoindre » quand l'événement contient un lien Google Meet, Zoom ou Microsoft Teams (dans l'URL, le lieu ou les notes), qui ouvre ce lien.
8. **Fichiers :**
   - les 3 derniers fichiers utilisés, comme dans « Récents » du Finder, avec icône réelle, nom, dossier parent et heure relative ;
   - un clic ouvre le fichier avec l'app par défaut ;
   - on peut glisser un fichier depuis le panneau vers une autre app ;
   - la liste se met à jour toute seule.

## Non-objectifs v2

- File d'attente « À suivre » : Now Playing ne la fournit pas.
- Plusieurs minuteurs, minuteurs nommés, raccourci clavier global.
- Choix des calendriers, création ou modification d'événements.
- Déposer des fichiers sur l'encoche (direction C), AirDrop.
- Remplacer le HUD volume système (direction A), onde audio.
- Écrans externes, Macs sans encoche, réglages, onboarding.

## Anti-objectifs (repris de v1, toujours valables)

- Ne jamais voler le focus. Seules exceptions : « Rejoindre » et l'ouverture d'un fichier, qui activent volontairement l'app cible.
- Ne pas gêner la barre de menus hors de la forme visible, y compris la bulle.
- Pas d'ouvertures intempestives.
- CPU ~0 % au repos. Le minuteur et le compte à rebours de l'agenda tournent à 1 Hz maximum, seulement quand ils sont visibles ou actifs. Pas de requête en boucle.
- Ne pas avoir l'air bricolé : animations type ressort, la bulle sort de l'encoche et y rentre.

## Contraintes

- macOS 15.4+, MacBook à encoche, Swift 6, SwiftPM (même structure que v1 : logique pure dans `IleDelbeCore`, testée ; services et vues dans `IleDelbe`).
- **Permission Calendrier** (EventKit, accès complet) demandée la première fois qu'on ouvre l'onglet Agenda, pas au lancement. Refusée : l'onglet affiche « Accès au calendrier refusé » et un bouton qui ouvre la page Confidentialité de Réglages Système. Ajouter `NSCalendarsFullAccessUsageDescription` à `Info.plist`.
- **Fichiers récents** via une requête Spotlight (`NSMetadataQuery`) sur le dossier personnel, triée par date de dernière utilisation (`kMDItemLastUsedDate`). Exclure les dossiers, les apps, les fichiers cachés et `~/Library`. macOS peut afficher une demande d'accès aux fichiers pour Bureau, Documents et Téléchargements : c'est accepté.
- **Couleur du halo** : calculée une fois par pochette, hors du thread principal (moyenne de l'image). La luminosité et la saturation sont relevées pour que la lueur reste visible sur fond noir.
- Taille du panneau ouvert : passe de 440×170 (v1) à environ 548×236, comme dans la maquette.
- L'historique « Écoutés récemment » est gardé entre deux lancements (20 derniers au maximum, sans doublon consécutif).
- Licence MIT, pas de code copié depuis des projets GPL.

## Décisions (mes choix)

- Un minuteur seul (sans média) va dans les ailes de l'encoche, pas dans une bulle : une bulle seule n'a pas de sens visuel.
- Fin de minuteur : son système « Glass », effacement après 60 s.
- Agenda : fenêtre de 24 h, 2 événements, sans les journées entières.
- L'historique est stocké dans `UserDefaults`.
- Vers une autre app, le glisser transporte l'URL du fichier ; le fichier n'est pas copié.
- **« Un média joue »** = lecture en cours (`isPlaying`), pas en pause. Si le média passe en pause alors que la bulle est affichée, elle rentre dans l'encoche (animation ressort) et le minuteur passe dans les ailes. Au retour de la lecture, la bulle ressort.
- **Bulle = même fenêtre** que l'encoche (fenêtre élargie à l'union des formes). Les clics restent transparents hors des formes dessinées. Survoler la bulle ouvre le panneau directement sur l'onglet Minuteur.
- **Ligne « dans N min » avant la permission Calendrier** : absente tant que l'accès n'est pas accordé. Pas de demande anticipée. Une fois l'accès donné, le service Agenda tourne indépendamment de l'onglet : il se rafraîchit à chaque changement de calendrier, plus une mise à jour par minute seulement quand un événement commence dans moins de 60 min.
- **Permissions et empaquetage** : on reste sur l'app agent signée ad hoc produite par `make app` (`LSUIElement`). Les fenêtres de permission de macOS ont le droit de prendre le focus, c'est le système qui les affiche. Avec une signature ad hoc, macOS peut redemander les autorisations après chaque rebuild. Accepté en dev, à noter dans le Readme.
- **Glisser un fichier hors du panneau** : le panneau reste ouvert pendant tout le glisser, puis se referme avec le délai normal (0,30 s) une fois le glisser terminé, si le pointeur est dehors.
- **Minuteur** : il est stocké comme une date de fin absolue, donc juste après une veille du Mac. Cette date est sauvegardée et restaurée au relancement. S'il a expiré pendant que l'app était fermée, il n'y a pas d'alerte et il est effacé. Pendant l'alerte, seul « OK » est proposé (ferme l'alerte).
- **Écoutés récemment** : exclut le morceau en cours. L'heure affichée est celle du début d'écoute. Un même morceau mis en pause puis repris ne crée pas de nouvelle entrée. Les lignes ne sont pas cliquables (Now Playing ne permet pas de lancer un morceau précis).

## Laissé au builder

- Dimensions exactes, rayons, timings d'animation (viser la maquette).
- Algorithme exact de couleur (moyenne, couleur dominante) et seuils de visibilité.
- Détection des liens visio (expressions régulières).
- Structure des fichiers et des services, dans l'esprit de la v1.
- Tests : au minimum la logique pure (onglet par défaut, état du minuteur, détection des liens visio, filtrage et tri des fichiers récents, historique, choix de la couleur du halo).

## Après la v2 (idées)

Raccourci clavier pour le minuteur, choix des calendriers, étagère de fichiers (C), HUD volume (A).
