# Sentier : conception

Date : 2026-10-13. Statut : en attente de validation.

## 1. But

Sentier est un addon World of Warcraft (Midnight, patch 12.1) qui affiche des guides en jeu, inspirés de Zygor. Le premier guide aide à farmer la réputation des factions de Midnight. Il montre au joueur ce qu'il lui reste à faire pour la faction choisie, en tenant compte des remises à zéro journalières et hebdomadaires.

Sentier est conçu comme un moteur de guides. La réputation est une catégorie de guides parmi d'autres, et un guide des montures viendra plus tard sans modification du moteur.

Public : Antoine et ses amis. L'interface est en français, avec ses textes regroupés dans un seul fichier pour une traduction ultérieure. Pas de publication sur CurseForge pour l'instant.

### Critères de réussite

- Le joueur choisit une faction de Midnight et voit, en mode étape ou en mode liste, ce qu'il lui reste à faire pour cette faction.
- Après un reset hebdomadaire ou journalier, les tâches concernées redeviennent « à faire » sans action du joueur.
- Les quêtes secondaires qui donnent de la réputation et que le personnage n'a pas encore faites sont listées.
- Chaque source de réputation peut être activée ou désactivée.
- Ajouter un guide revient à ajouter des fichiers dans `Guides/`, sans toucher à `Core/`.

### Hors périmètre (première version)

- Suivi des autres personnages (seul le personnage connecté est suivi).
- Flèche de navigation dessinée par Sentier.
- Traduction anglaise.
- Guide des montures (seule l'architecture doit le permettre).
- Reprise de contenu Zygor : interdit, leurs guides sont protégés par le droit d'auteur.

## 2. Sources de données

Ce que l'on sait, vérifié le 2026-10-13 :

- **API web de Blizzard** (Game Data, namespace `static-eu`, build `12.1.0_68914`) : elle donne la liste des quêtes par zone (`/data/wow/quest/area/{id}`) et le détail de chaque quête (titre, description, niveaux, expérience, or, objets). Elle **ne renvoie aucune réputation** pour les 862 quêtes des zones de Midnight (Harandar 15355, Zul'Aman 15947, Bois des Chants éternels 15968, Lune-d'Argent 15969, La flèche du Vide 16340, Tempête du Vide 16648). Elle en renvoie pour les anciennes quêtes de Burning Crusade (champ `rewards.reputations`), donc le champ existe mais n'est pas rempli pour le renom de Midnight.
- **API du jeu** (Lua) : quêtes terminées (`C_QuestLog.IsQuestFlaggedCompleted`), renom (`C_MajorFactions.GetMajorFactionIDs`, `GetMajorFactionData`), quêtes mondiales actives (`C_TaskQuest`), réputation annoncée par une quête du journal ou une quête mondiale (`C_QuestLog.GetQuestLogMajorFactionReputationRewards` et équivalents), heure des resets (`C_DateAndTime.GetWeeklyResetStartTime`, `GetSecondsUntilWeeklyReset`, `GetSecondsUntilDailyReset`). Les restrictions de Midnight (« secret values ») portent sur le combat et ne concernent pas ces fonctions.
- **Saisie à la main** : ordre des étapes, coordonnées, notes, valeurs de réputation, numéros de quêtes cachées (rares, hebdomadaires). Sources de lecture : guides publics Icy Veins, Method, Wowhead (consultation, pas d'aspiration automatique).

Les identifiants des factions de Midnight (Cour de Lune-d'Argent, Tribu Amani, Hara'ti, Singularité, Forces de Zul'jarra) seront relevés en jeu avec `C_MajorFactions.GetMajorFactionIDs`.

## 3. Organisation

```
Sentier/
  Sentier.toc
  Locales/fr.lua      tous les textes affichés
  Core/               moteur : registre des guides, état des tâches, resets, sauvegarde, réglages, événements
  Sensors/            seuls fichiers qui interrogent le jeu
  Navigation/         TomTom s'il est installé, sinon repère officiel du jeu
  UI/                 fenêtre principale (onglets Étape / Liste), réglages, bouton de minicarte
  Guides/
    Reputation/Midnight/
      Catalog.lua     généré par tools/, ne pas modifier à la main
      Amani.lua, SilvermoonCourt.lua, Harati.lua, Singularity.lua, ZuljarraForces.lua
tools/                scripts Python (catalogue, collecte)
tests/                tests busted (Lua) et pytest (Python)
```

Règles de dépendance : `Guides` n'utilise que l'API publique de `Core`. `UI` lit l'état calculé par `Core` et ne lit jamais le jeu directement. Seul `Sensors` appelle les fonctions `C_*` liées aux quêtes et à la réputation, ce qui permet de le simuler dans les tests.

## 4. Modèle des guides

Un guide est créé par `Sentier:NewGuide(id, { title, category })`. Il déclare des tâches, puis un ordre conseillé.

Champs communs d'une tâche : `id`, `type`, `factions`, `rep` (estimation), `reset` (`"none"`, `"daily"`, `"weekly"`), `map`, `x`, `y`, `requires` (liste de prérequis : quête terminée ou niveau de renom), `note`, `source` (clé de la source de réputation, pour l'activation dans les réglages).

Types de tâches de la première version :

| Type | Déclaration | Terminée quand | Source |
|---|---|---|---|
| Quête secondaire | `G:Quest(questId, {...})` | la quête est terminée | `sidequests` |
| Activité hebdomadaire | `G:Weekly(id, { questIds, ... })` | toutes les quêtes de `questIds` sont terminées ; sinon coche manuelle | `weekly` |
| Journalière | `G:Daily(id, { questIds, ... })` | idem, remise à zéro chaque jour | `daily` |
| Rare | `G:Rare(id, { questId, ... })` | la quête cachée du rare est terminée | `rares` |
| Quêtes mondiales | `G:WorldQuests({ faction })` | jamais terminée : affiche les quêtes mondiales actives qui donnent de la réputation à la faction | `worldquests` |

Une activité découpée en plusieurs fois (par exemple 4 gouffres) peut donner sa progression avec `progress = { questId, objective }` ; elle s'affiche alors « 2/4 ».

Le nom et la zone d'une quête viennent de `Catalog.lua` quand la tâche ne les précise pas.

`G:Order({ ... })` donne l'ordre du mode étape. Il ne fait que référencer des tâches déjà déclarées. Une tâche absente de l'ordre apparaît dans la liste mais pas en mode étape. Une référence à une tâche inconnue est signalée en mode débogage.

## 5. État, sauvegarde et resets

L'état d'une tâche (`done`, `todo`, `locked`, `unknown`) est recalculé à partir du jeu, il n'est pas stocké. Les resets de Blizzard effacent les quêtes hebdomadaires et journalières, donc la remise à zéro suit naturellement.

Sauvegarde par personnage (`SentierCharDB`) : guide choisi, onglet affiché, étape en cours, tâches passées à la main, coches manuelles avec leur date. Sauvegarde du compte (`SentierDB`) : réglages (sources activées, navigation, masquer les tâches terminées, position et taille de la fenêtre, verrouillage) et données de collecte.

Une coche manuelle, comme une tâche passée à la main, est ignorée, puis effacée, si elle date d'avant le dernier reset correspondant à la tâche (`GetWeeklyResetStartTime` pour l'hebdomadaire, dernier reset journalier calculé avec `GetSecondsUntilDailyReset`).

Recalcul déclenché par : connexion et `/reload`, quête rendue, journal de quêtes modifié, réputation ou renom modifiés, changement des quêtes mondiales, minuteur programmé à l'heure du prochain reset. Les recalculs rapprochés sont regroupés (un seul par demi-seconde).

Étape en cours : la première tâche de l'ordre qui est `todo`, dont la source est activée, et que le joueur n'a pas passée à la main. Quand elle se termine, Sentier avance et déplace le repère.

`locked` : un prérequis n'est pas rempli ; la raison est affichée (« Renom 8 requis »). `unknown` : quête absente du catalogue, fonction du jeu indisponible ou erreur de lecture. L'addon ne doit jamais lever d'erreur Lua à cause des données ; `/sentier debug` liste les problèmes rencontrés.

## 6. Interface

Une seule fenêtre, déplaçable, redimensionnable et verrouillable, dont la position est retenue. Ouverture et fermeture par `/sentier` ou par un bouton près de la minicarte.

- **En-tête** : titre du guide (un clic ouvre un menu déroulant des guides, rangés par catégorie) et engrenage des réglages.
- **Onglet Étape** : barre de renom (niveau et points), étape en cours (nom, type, progression, réputation, note), aperçu de l'étape suivante, boutons précédent, passer, suivant. Un clic sur l'étape pose le repère.
- **Onglet Liste** : tâches groupées en « Cette semaine », « Aujourd'hui », « Quêtes mondiales actives », « Quêtes secondaires (n restantes) » et « Rares », avec la réputation de chacune. Les tâches bloquées sont grisées avec leur raison. Un clic pose le repère, un clic droit coche ou décoche à la main.
- **Réglages** : une case par source (`sidequests`, `weekly`, `daily`, `rares`, `worldquests`), choix de navigation (automatique, TomTom, repère du jeu), masquer les tâches terminées.

Maquette validée : option A (une fenêtre, deux onglets).

## 7. Navigation

`Navigation:SetTarget(map, x, y, title)` et `Navigation:Clear()`. Si TomTom est chargé et que le réglage le permet, Sentier utilise TomTom et supprime son ancien point quand la cible change. Sinon, il pose le repère du jeu (`C_Map.SetUserWaypoint`, puis suivi avec `C_SuperTrack`). Une tâche sans coordonnées ne pose pas de repère.

## 8. Outils

- `tools/build_catalog.py` : lit les identifiants dans `.env`, interroge l'API pour les zones de Midnight et écrit `Guides/Reputation/Midnight/Catalog.lua` (numéro, titre en français, zone, niveaux), trié par numéro pour des différences git lisibles. À relancer à chaque patch.
- **Mode collecte** (`/sentier collect on|off`) : quand une quête de Midnight entre dans le journal ou qu'une quête mondiale est visible, Sentier enregistre dans `SentierDB.collect` le numéro de la quête, la faction, la réputation annoncée et la position du joueur.
- `tools/import_collect.py` : lit le fichier SavedVariables du compte et produit des lignes `G:Quest(...)` prêtes à coller, en ignorant les quêtes déjà présentes dans les guides.
- `tools/check_blizzard_quests.py` : script de vérification déjà écrit, gardé pour le diagnostic.

## 9. Tests

- **busted** (Lua, hors du jeu) : état des tâches, prérequis, choix de l'étape, coches manuelles et leur expiration aux resets, activation des sources, enregistrement des guides et validation de l'ordre. `Sensors` et les fonctions de date sont remplacés par des simulations.
- **pytest** : génération du catalogue à partir de réponses d'API enregistrées, import des données de collecte.
- **Contrôle en jeu** (liste à cocher dans `docs/`) : affichage des deux onglets, menu des guides, TomTom présent ou absent, repère du jeu, valeurs réelles de renom, comportement après un reset.

## 10. Développement et diffusion

Le dossier `Sentier/` est relié par un lien symbolique au dossier `_retail_/Interface/AddOns/` de WoW ; `/reload` charge les changements. Le `.toc` vise l'interface 12.1 (`## Interface: 120100`, à confirmer en jeu avec `/dump select(4, GetBuildInfo())`). La diffusion aux amis se fait par une archive zip ou une release GitHub.
