# Sentier : guides remplis par Grail, et confort de la fenêtre

Date : 2026-10-14. Statut : en attente de validation.

Cette spec complète `2026-10-13-sentier-design.md`. Ce qui n'est pas écrit ici reste valable.

## 1. But

Aujourd'hui les guides de réputation sont presque vides : il faut jouer pour que le mode collecte trouve les quêtes, puis les recopier à la main. Le joueur veut des guides remplis dès l'installation.

Grail (addon de Scott M Harrison, dépôt `smaitch/Grail`, version 127) est une base de données des quêtes. Pour chaque quête, il connaît la réputation gagnée, les quêtes à faire avant, et les personnages qui la donnent et la reprennent avec leur position. Vérifié le 2026-10-14 sur la version 127 : environ 100 quêtes chacune pour la Tribu des Amani (2696), la Singularité (2699), les Hara'ti (2704) et la Cour de Lune-d'Argent (2710). Aucune pour les Forces de Zul'jarra (2772).

Le joueur a aussi demandé trois améliorations de la fenêtre : plus de retour visuel sur les clics, une zone plus grande pour la déplacer, et une icône sur la minicarte.

### Critères de réussite

- Avec Grail installé, chacun des quatre guides couverts par Grail liste dès la connexion les quêtes qui donnent de la réputation à sa faction, avec la réputation, le lieu de départ et les prérequis.
- Les quêtes déjà faites sont cachées par défaut, et une case permet de les afficher.
- La fenêtre se déplace en la prenant par toute sa barre de titre.
- Chaque clic dans la fenêtre donne un retour visible (survol, enfoncement, son, message de confirmation).
- Une icône sur la minicarte ouvre et ferme le guide.

### Hors périmètre

- Recopier les données de Grail dans Sentier : Grail n'a pas de licence, Sentier lit ses données en jeu sans les copier.
- Compléter Grail pour les Forces de Zul'jarra ou les quêtes ajoutées en 12.1.
- Bibliothèque LibDBIcon : l'icône de minicarte est faite par Sentier.

## 2. Grail comme dépendance

`Sentier.toc` déclare `## Dependencies: Grail`. Sans Grail, WoW ne charge pas Sentier ; le README l'explique et donne le lien de Grail.

Grail est marqué pour les interfaces jusqu'à `120007`, Sentier vise `120100`. Si le jeu considère Grail comme périmé, le joueur coche « Charger les addons périmés » dans la liste des addons. Le README et `docs/controle-en-jeu.md` le mentionnent.

Un seul fichier de Sentier parle à Grail : `Sensors/Grail.lua`. Il expose des fonctions simples, remplaçables dans les tests :

- `GrailSource.Ready()` : vrai quand Grail a fini de charger ses données.
- `GrailSource.QuestsForFaction(factionId)` : liste de `{ questId, rep }` pour les quêtes qui donnent de la réputation à cette faction. S'appuie sur `Grail:LoadReputations()`, la table `Grail.questReputations` et `Grail:ReputationDecode()`.
- `GrailSource.QuestInfo(questId)` : nom (`Grail:QuestName`), position de départ (premier résultat de `Grail:QuestLocationsAccept`, en carte et coordonnées 0-100), prérequis (`Grail:QuestPrerequisites`), et indicateurs quête mondiale, journalière, hebdomadaire (`Grail:IsWorldQuest`, `IsDaily`, `IsWeekly`).

Le format exact de ces tables internes de Grail (codes de réputation, format des positions et des prérequis) est à confirmer pendant le plan en lisant le code de Grail 127. Chaque lecture est protégée : une donnée illisible donne une quête sans position ou sans prérequis, jamais une erreur Lua, et le problème est listé par `/sentier debug`.

## 3. Remplissage des guides

Un guide de faction déclare `fromGrail = true` dans `Sentier:NewGuide`. Les quatre guides couverts l'activent ; celui des Forces de Zul'jarra aussi, sans effet tant que Grail ne connaît rien pour cette faction.

Quand Grail est prêt (connexion ou `/reload`), `Core/GrailGuides.lua` parcourt les guides `fromGrail` et, pour chaque quête renvoyée par `QuestsForFaction` :

- ignore les quêtes mondiales (lues en direct par la tâche « Quêtes mondiales ») ;
- ignore une quête déjà déclarée à la main dans le guide ;
- ajoute une tâche `G:Quest(questId, { rep, title, map, x, y, requires })`. Une quête journalière ou hebdomadaire selon Grail reçoit `reset = "daily"` ou `"weekly"`.

Les prérequis de Grail deviennent des `requires = { { quest = id, title = nom } }`. Seuls les prérequis simples (« cette quête doit être faite ») sont repris ; les conditions plus rares de Grail (classe, métier, choix entre plusieurs quêtes…) sont ignorées dans cette version.

### Ordre conseillé

Les quêtes ajoutées sont placées avant la tâche « Quêtes mondiales », triées :

1. par zone (carte de départ), dans l'ordre de `ns.MidnightZones` ; les quêtes sans zone connue viennent en dernier ;
2. dans une zone, chaque quête après ses prérequis présents dans le guide ;
3. sinon par numéro de quête.

Les tâches écrites à la main (hebdomadaires, rares) gardent leur place en tête de l'ordre.

### Ce qui est retiré

Le remplissage à la main n'a plus de raison d'être :

- mode collecte (`Core/Collect.lua`, commande `/sentier collect`, données `SentierDB.collect`) ;
- recherche à la connexion (`Core/Scan.lua`) et les fonctions de `Sensors` qui ne servaient qu'à elle ;
- `tools/import_collect.py`, `tools/build_catalog.py`, `tools/blizzard.py`, `tools/check_blizzard_quests.py` et leurs tests ;
- le catalogue `Guides/Reputation/Midnight/Catalog.lua` : le nom des quêtes vient de Grail. Le champ `catalog` de `NewGuide` disparaît ;
- `docs/contenu.md` est réécrit : il explique comment ajouter une hebdomadaire ou un rare à la main, et que les quêtes viennent de Grail ;
- l'entrée « Renom des quêtes non ouvertes » de `docs/suivi/DETTE.md`, devenue sans objet.

Les anciennes données `SentierDB.collect` sont effacées au chargement.

## 4. Quêtes déjà faites

Le réglage existant `hideDone` passe à `true` par défaut. Le mode étape ne change pas : il ne montre déjà que les tâches à faire. Une case « Afficher les quêtes faites » est ajoutée en haut de l'onglet Liste ; elle modifie le même réglage que la case des réglages. Le compteur « Quêtes secondaires (n restantes) » ne compte que les quêtes à faire, qu'elles soient affichées ou non.

## 5. Fenêtre

### Barre de titre

Une barre de 24 pixels sur toute la largeur du haut de la fenêtre sert de poignée de déplacement (si la fenêtre n'est pas verrouillée). Elle contient le titre du guide, une flèche qui ouvre le menu des guides, et l'engrenage des réglages. Cliquer sur le titre ne fait plus rien : seul le glisser déplace la fenêtre, seule la flèche ouvre le menu. Au survol, la barre s'éclaire légèrement.

### Retour sur les clics

- Les lignes de la liste et l'étape en cours s'éclairent au survol et s'enfoncent légèrement au clic.
- Chaque clic joue le son de clic standard du jeu (`PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)` ou équivalent).
- Une ligne de message en bas de la fenêtre confirme l'action pendant 3 secondes : « Repère posé : <nom> », « Pas de position pour cette tâche », « Tâche cochée », « Tâche décochée », « Étape passée ». Les textes sont dans `Locales/fr.lua`.

### Icône sur la minicarte

`UI/MinimapButton.lua` crée un bouton rond de 31 pixels au bord de la minicarte, avec l'icône de Sentier. On peut le faire glisser autour de la minicarte ; son angle est retenu dans `SentierDB.minimap = { angle, hidden }`. Clic gauche : ouvrir ou fermer le guide. Clic droit : ouvrir les réglages. Au survol, une bulle d'aide rappelle ces deux clics. Une case « Afficher l'icône sur la minicarte » dans les réglages le cache ou le montre. Le bouton du menu des addons (`AddonCompartmentFunc`) est gardé.

## 6. Tests

- **busted** : `GrailSource` est simulé. Tests du remplissage (quêtes ajoutées au bon guide, quêtes mondiales ignorées, quête déjà déclarée gardée, reset journalier ou hebdomadaire, prérequis convertis), de l'ordre (zones, prérequis avant, sans zone en dernier), de `hideDone` par défaut et du compteur, de la sauvegarde de l'angle du bouton de minicarte. Les tests de la collecte et de la recherche sont supprimés.
- **busted, lecture de Grail** : `Sensors/Grail.lua` est testé contre une petite copie à la main du format des tables de Grail (quelques lignes écrites dans le test, pas le fichier de Grail).
- **pytest** : supprimé avec les outils Python.
- **Contrôle en jeu** (`docs/controle-en-jeu.md`) : Grail chargé (ou case des addons périmés), guides remplis pour les quatre factions, prérequis grisés, case « Afficher les quêtes faites », déplacement par la barre de titre, messages de confirmation, bouton de minicarte (glisser, clics, position retenue après `/reload`).
