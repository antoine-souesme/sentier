# Contrôle en jeu

À faire après chaque changement d'interface et à chaque patch. Cocher au fur et à mesure.

- [ ] Grail est installé et chargé (liste des addons) ; s'il est « périmé », la case « Charger les addons périmés » est cochée.
- [ ] `/dump select(4, GetBuildInfo())` donne la même valeur que `## Interface` dans `Sentier.toc` (sinon corriger le `.toc`).
- [ ] L'addon se charge sans erreur Lua (installer BugSack pour les voir).
- [ ] `/sentier debug` : aucun problème, et les cartes de Midnight trouvées ne sont pas « aucune ». Sinon, aller dans chaque zone, faire `/dump C_Map.GetBestMapForUnit("player")` et ajuster la plage de recherche de `Sensors.FindZoneMaps`.
- [ ] La liste des cartes de quêtes mondiales (`Zones.lua`) est confirmée avec `/sentier debug` : toutes les zones où apparaissent des quêtes mondiales y figurent.
- [ ] Les quêtes mondiales qui changent en cours de journée apparaissent dans la liste (aucun événement direct : ouvrir la fenêtre ou `/reload` si besoin).
- [ ] Pour chaque faction, `/dump C_MajorFactions.GetMajorFactionData(<id>).name` donne le bon nom (2696, 2699, 2704, 2710, 2772).
- [ ] La fenêtre s'ouvre avec `/sentier`, avec l'icône de la minicarte et avec le bouton des addons ; elle se déplace en la prenant par toute la barre de titre, se redimensionne, se verrouille, et garde sa place après `/reload`.
- [ ] La flèche à droite du titre ouvre le menu des cinq guides sous « Réputation » et change de guide ; cliquer ou glisser le titre ne l'ouvre pas.
- [ ] Onglet Étape : le titre, le détail et la ligne « Ensuite » sont tous visibles, sans texte coupé ; la barre de renom correspond à la fenêtre de renom du jeu ; « Passer », « < » et « > » fonctionnent ; un clic sur l'étape pose le repère.
- [ ] Onglet Liste : groupes corrects, quêtes mondiales actives de la faction avec leur réputation, clic gauche = repère, clic droit = coche manuelle.
- [ ] Avec TomTom : la flèche TomTom apparaît. Sans TomTom (ou réglage « Repère du jeu ») : le repère officiel apparaît.
- [ ] Les valeurs de renom affichées (niveau, points) sont les vraies valeurs du jeu pour chaque faction.
- [ ] Réglages : couper une source la retire des deux onglets ; « Masquer les tâches terminées » fonctionne ; « Remettre les étapes passées » fonctionne.
- [ ] Quelques secondes après la connexion, `/sentier debug` indique plus de 0 « quêtes ajoutées depuis Grail », et le groupe « Quêtes secondaires » des guides Amani, Singularité, Hara'ti et Cour de Lune-d'Argent est rempli.
- [ ] Les quêtes de Grail ont un nom en français (sinon « Quête #<numéro> » qui se corrige après quelques secondes), une réputation, et un clic pose le repère au bon endroit.
- [ ] Une quête dont le prérequis n'est pas fait est grisée avec « Quête requise : <nom> ».
- [ ] Les quêtes déjà faites sont cachées ; la case « Afficher les quêtes faites » en haut de la liste les montre et les cache.
- [ ] Chaque clic (étape, ligne de liste, boutons, cases, réglages) fait le son de clic ; poser un repère, cocher, décocher et passer une étape affichent un message en bas de la fenêtre pendant 3 secondes ; une tâche sans position affiche « Pas de position pour cette tâche ».
- [ ] Icône de la minicarte : clic gauche ouvre et ferme, clic droit ouvre les réglages, la bulle d'aide s'affiche, on la fait glisser autour de la minicarte et elle garde sa place après `/reload` ; la case des réglages la cache et la remontre.
- [ ] Après un reset (ou le lendemain) : les coches manuelles hebdomadaires ou journalières ont disparu comme prévu.
