# Ajouter du contenu aux guides

1. En jeu, taper `/sentier collect on`.
2. Jouer normalement dans les zones de Midnight : chaque quête proposée ou acceptée qui donne de la réputation à une faction suivie est notée, avec la position. Les quêtes mondiales sont notées aussi, mais restent lues en direct par le guide.
3. Taper `/sentier collect off`, puis `/reload` pour que WoW écrive le fichier de sauvegarde.
4. Lancer `python3 tools/import_collect.py "<WoW>/_retail_/WTF/Account/<COMPTE>/SavedVariables/Sentier.lua"`.
5. Coller les lignes proposées dans le bon fichier de `Sentier/Guides/Reputation/Midnight/`, avant `G:Order`, puis ajouter leurs numéros dans `G:Order` à l'endroit voulu.
6. Ajouter si besoin une note (`note = "..."`) ou un prérequis (`requires = { { renown = 8 } }` ou `requires = { { quest = 12345, title = "Nom" } }`).
7. Lancer `busted`, puis `/reload` en jeu.

Pour un rare ou une activité hebdomadaire, trouver son numéro de quête caché (commentaires Wowhead, ou `/dump C_QuestLog.IsQuestFlaggedCompleted(<numéro>)` avant et après l'avoir fait), puis écrire par exemple :

```lua
G:Rare("rare-nom", { questId = 12345, rep = 75, map = 2437, x = 30.5, y = 22.8 })
G:Weekly("nom-activite", { title = "Nom", questIds = { 12345 }, rep = 1000 })
```

Une activité sans numéro de quête se coche à la main (clic droit dans la liste). Avec `shared = true`, la coche vaut pour tous les guides.
