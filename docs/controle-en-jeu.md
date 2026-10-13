# Contrôle en jeu

À faire après chaque changement d'interface et à chaque patch. Cocher au fur et à mesure.

- [ ] `/dump select(4, GetBuildInfo())` donne la même valeur que `## Interface` dans `Sentier.toc` (sinon corriger le `.toc`).
- [ ] L'addon se charge sans erreur Lua (installer BugSack pour les voir).
- [ ] `/sentier debug` : aucun problème, et les cartes de Midnight trouvées ne sont pas « aucune ». Sinon, aller dans chaque zone, faire `/dump C_Map.GetBestMapForUnit("player")` et ajuster la plage de recherche de `Sensors.FindZoneMaps`.
- [ ] La liste des cartes de quêtes mondiales (`Zones.lua`) est confirmée avec `/sentier debug` : toutes les zones où apparaissent des quêtes mondiales y figurent.
- [ ] Les quêtes mondiales qui changent en cours de journée apparaissent dans la liste (aucun événement direct : ouvrir la fenêtre ou `/reload` si besoin).
- [ ] Pour chaque faction, `/dump C_MajorFactions.GetMajorFactionData(<id>).name` donne le bon nom (2696, 2699, 2704, 2710, 2772).
- [ ] La fenêtre s'ouvre avec `/sentier` et avec le bouton des addons de la minicarte, se déplace en la faisant glisser, se redimensionne, se verrouille, et garde sa place après `/reload`.
- [ ] Le menu du titre liste les cinq guides sous « Réputation » et change de guide.
- [ ] Onglet Étape : le titre, le détail et la ligne « Ensuite » sont tous visibles, sans texte coupé ; la barre de renom correspond à la fenêtre de renom du jeu ; « Passer », « < » et « > » fonctionnent ; un clic sur l'étape pose le repère.
- [ ] Onglet Liste : groupes corrects, quêtes mondiales actives de la faction avec leur réputation, clic gauche = repère, clic droit = coche manuelle.
- [ ] Avec TomTom : la flèche TomTom apparaît. Sans TomTom (ou réglage « Repère du jeu ») : le repère officiel apparaît.
- [ ] Les valeurs de renom affichées (niveau, points) sont les vraies valeurs du jeu pour chaque faction.
- [ ] Réglages : couper une source la retire des deux onglets ; « Masquer les tâches terminées » fonctionne ; « Remettre les étapes passées » fonctionne.
- [ ] Une minute après la connexion, `/sentier debug` indique plus de 0 « nouvelles avec du renom », et le groupe « Quêtes secondaires » de chaque guide se remplit sans avoir ouvert de quête.
- [ ] Sans rien taper, ouvrir une quête de Midnight qui donne de la réputation : elle apparaît aussitôt dans « Quêtes secondaires » du guide de sa faction. `/sentier collect off` indique au moins 1 quête enregistrée.
- [ ] Après un reset (ou le lendemain) : les coches manuelles hebdomadaires ou journalières ont disparu comme prévu.
