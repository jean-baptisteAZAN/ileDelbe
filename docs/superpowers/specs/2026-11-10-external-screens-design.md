# ileDelbe — écrans externes

Date : 2026-11-10
Statut : brouillon, à valider
Base : 0.3.0 publiée (spec `2026-11-10-styles-and-settings-0.3-design.md`)
Version visée : 0.4.0. Le style Rail, prévu pour la 0.4, passe à la version suivante.

## Intention

Aujourd'hui, ileDelbe ne s'affiche que sur un écran à encoche (l'écran intégré du MacBook) et disparaît sans lui, par exemple MacBook fermé sur un écran externe. L'utilisateur travaille souvent sur des écrans externes, qui sont plus grands et n'ont pas d'encoche. Il veut retrouver l'encoche sur ces écrans : sur tous, ou sur un seul qu'il choisit.

## Objectifs

1. **Encoche virtuelle** sur les écrans sans encoche matérielle, en haut au centre :
   - **Au repos** (rien ne joue, pas de minuteur), une **fine barre discrète** : environ 120 pt de large et 4 pt de haut, noire, collée au bord haut, coins bas arrondis.
   - **Quand une activité tourne** (lecture, minuteur, alerte), la barre grandit en pilule avec les mêmes ailes que sur l'encoche matérielle : pochette et égaliseur, titre, minuteur, bulle, alerte. Elle a la hauteur de la barre de menus de cet écran. La pilule a un centre noir d'environ 180 pt (la largeur d'une encoche) entre les deux ailes, pour garder le même rendu partout.
   - **Survol** : comme sur l'encoche matérielle, mais la zone de déclenchement au repos est la barre, avec quelques points de tolérance vers le bas pour qu'on puisse l'atteindre en poussant le pointeur contre le bord haut.
   - Le **panneau ouvert** est le même (styles, tailles, réglages). Sa bande du haut a la hauteur de la barre de menus de l'écran, au lieu de celle de l'encoche matérielle.
2. **Choix des écrans** dans Réglages, nouvelle ligne « Écrans » :
   - **Écran intégré** (défaut) : le comportement actuel. Si l'écran intégré n'est pas disponible (MacBook fermé), l'encoche passe sur l'écran principal.
   - **Écran principal** : celui qui porte la barre de menus principale dans macOS. Elle suit les changements faits dans Réglages Système › Moniteurs.
   - **Un écran au choix** : une liste des écrans branchés, par nom. Si cet écran est débranché, l'encoche passe sur l'écran intégré, sinon sur le principal, et revient dès que l'écran choisi est rebranché.
   - **Tous les écrans** : une encoche sur chaque écran. L'écran intégré garde l'encoche matérielle, les autres ont une encoche virtuelle.
3. **Plusieurs encoches** (mode Tous les écrans) :
   - Chaque encoche s'ouvre et se ferme indépendamment, au survol de son écran. Une seule peut être ouverte à la fois, puisqu'il n'y a qu'un pointeur.
   - L'activité de l'encoche fermée (ailes, bulle, **alerte du minuteur**) s'affiche **sur toutes** les encoches en même temps.
   - Module affiché, « Tout voir » et dernier module vu : ce qu'on fait dans une encoche vaut pour les autres à la prochaine ouverture (un seul état partagé). Le dernier module vu est déjà partagé.
4. **Branchement à chaud** : brancher, débrancher, changer la résolution ou l'écran principal met à jour les encoches sans relancer l'app.

## Non-objectifs

- Afficher une encoche différente par écran (style, modules) : les réglages restent globaux.
- Réglages de taille ou de position de l'encoche virtuelle (toujours en haut au centre).
- Masquer l'encoche virtuelle en plein écran au-delà de ce que fait déjà l'encoche matérielle.
- Le style Rail (version suivante).

## Anti-objectifs (repris)

- Ne jamais voler le focus.
- Ne jamais gêner la barre de menus hors de la forme dessinée. Au repos, l'encoche virtuelle ne prend que la fine barre. Les éléments de barre de menus placés au centre d'un écran externe restent cliquables tant qu'aucune activité ne tourne.
- Pas d'ouvertures intempestives : la zone de déclenchement au repos reste petite.
- CPU ~0 % au repos, quel que soit le nombre d'écrans. Pas de minuteur par écran : les animations (égaliseur, défilement du titre) suivent les mêmes règles qu'aujourd'hui, et le réglage « Animer l'encoche fermée » vaut pour toutes les encoches.

## Contraintes

- macOS 15.4+, Swift 6, SwiftPM, même découpage : logique pure dans `IleDelbeCore`, testée ; vues et fenêtres dans `IleDelbe`.
- **Choix des écrans en logique pure**, testée : à partir de la liste des écrans branchés (identifiant stable, nom, intégré ou non, principal ou non, encoche ou non) et du réglage, la fonction renvoie la liste des écrans où afficher une encoche, avec repli.
- **Identifiant d'écran stable** entre deux lancements et deux branchements : l'UUID d'écran de CoreGraphics (`CGDisplayCreateUUIDFromDisplayID`), pas l'index dans `NSScreen.screens` ni le nom. Le nom sert uniquement à l'affichage dans la liste.
- **Géométrie de l'encoche virtuelle en logique pure**, testée : à partir du cadre de l'écran et de la hauteur de sa barre de menus, elle donne une encoche « centrale » virtuelle. Cette encoche de 180 pt au centre sert à placer les ailes ; la barre de repos et les zones de déclenchement en découlent. Le calcul de fenêtre et de survol existant (`NotchGeometry`, `PanelSizing`, `windowFrame`) doit fonctionner tel quel avec elle.
- Une **fenêtre par écran affiché**, avec les mêmes règles qu'aujourd'hui : non activante, au-dessus de la barre de menus, sur tous les Spaces, et clics transparents hors de la forme.
- Réglage stocké dans les réglages existants (`settings.v1`), avec un repli champ par champ. Un ancien fichier sans ce champ donne « Écran intégré ».
- Licence MIT, pas de code copié de projets GPL.

## Décisions (prises avec l'utilisateur)

- Aspect au repos sur écran externe : **fine barre discrète** qui grandit en pilule pendant une activité.
- Modes proposés : **Écran intégré** (ajouté pour garder le comportement actuel par défaut), **Écran principal**, **Un écran au choix**, **Tous les écrans**.
- Défaut : **Écran intégré** ; MacBook fermé, l'encoche passe sur l'écran principal.
- Alerte et bulle du minuteur : **sur toutes les encoches**.

## Décisions (mes choix)

- Une seule encoche ouverte à la fois, l'état d'ouverture reste par écran ; module affiché et « Tout voir » partagés.
- La hauteur de la pilule et de la bande du panneau sur un écran externe est celle de sa barre de menus (cadre de l'écran moins le haut de sa zone visible). Si l'écran n'a pas de barre de menus visible (Spaces partagés et écran secondaire), on prend la hauteur de la barre de menus système.
- Repli du mode « Un écran au choix » : écran intégré, puis principal. L'écran choisi est retrouvé par son UUID quand il revient.

## Précisions (mes choix, après relecture)

- **Écran intégré sans encoche** (ancien MacBook) : il reçoit l'encoche virtuelle comme n'importe quel écran sans encoche. « Écran intégré » désigne l'écran intégré, qu'il ait une encoche ou non, détecté par `CGDisplayIsBuiltin`, et plus par le nom de l'écran. Il y a toujours au moins un écran affiché : le chemin « aucun écran à encoche, panneau caché » disparaît.
- **Repos ou activité** : la barre fine correspond à la mise en page fermée « nue » (`.plain`), la pilule à toute autre mise en page fermée. En pratique, avec « Rien » pendant la lecture, un minuteur masqué ou une lecture en pause, on garde la barre. Les règles de mise en page fermée ne changent pas.
- **Une encoche ouverte, les autres** : les encoches fermées des autres écrans continuent d'afficher l'activité (ailes, bulle, alerte). L'état d'ouverture est un seul « écran ouvert » (aucun ou un). Voir l'alerte dans une encoche ouverte l'acquitte partout, puisque le minuteur est unique.
- **Tailles par écran** : chaque fenêtre calcule sa taille ouverte, sa taille maximale et sa taille « Tout voir » avec la hauteur de barre de menus de **son** écran. Il n'y a pas de hauteur commune.
- **Plein écran et barre de menus masquée** : même niveau de fenêtre et même comportement de Spaces que l'encoche matérielle, pas de logique de masquage en plus. Si la barre de menus d'un écran a une hauteur nulle, on prend la hauteur de la barre de menus système. La barre fine reste visible au-dessus d'une vidéo plein écran, c'est accepté.

## Laissé au builder

- Dimensions exactes de la barre de repos et de la tolérance de survol (viser 120 × 4 pt et 6 pt de tolérance).
- Architecture du modèle : séparer l'état propre à un écran (ouvert, géométrie, glisser de fichier) de l'état partagé (services, réglages, module, « Tout voir »), par exemple avec un contrôleur de fenêtre par écran et un état partagé. Le découpage exact est libre.
- Présentation de la ligne « Écrans » dans Réglages.
- Tests : au minimum le choix des écrans (chaque mode, repli, écran choisi absent puis revenu, MacBook fermé, un seul écran) et la géométrie virtuelle (barre, pilule, ailes, bulle, fenêtre).
- README (section écrans externes, une image d'écran externe générée), CHANGELOG, version 0.4.0.
