# Dette

Décisions mises de côté pour plus tard.

## Renom des quêtes non ouvertes (2026-10-13)

Les quêtes secondaires sont trouvées en demandant au jeu, à la connexion, le renom de chaque quête du catalogue (`C_QuestLog.RequestLoadQuestByID` puis `C_QuestLog.GetQuestLogMajorFactionReputationRewards`). Il n'a pas été possible de vérifier sans le jeu que cette fonction répond pour une quête absente du journal. Si elle ne répond pas, seul le relevé des quêtes ouvertes en jeu remplit les guides, et il faudra trouver une autre source de données.

## Valeurs à confirmer en jeu (2026-10-13)

Les titres et la réputation des hebdomadaires des Forces de Zul'jarra sont provisoires, comme la liste des cartes à quêtes mondiales de `Zones.lua` et le numéro d'interface `120100`. La liste `docs/controle-en-jeu.md` indique comment les vérifier.
