# Ajouter du contenu aux guides

Les quêtes qui donnent de la réputation viennent de l'addon Grail : rien à écrire pour elles. Sentier les ajoute à la connexion dans les guides marqués `fromGrail = true`, avec la réputation, le lieu de départ et les prérequis simples, rangées par zone (ordre de `ns.MidnightZones` dans `Guides/Reputation/Midnight/Zones.lua`).

Une quête écrite à la main dans un guide garde la priorité sur celle de Grail (même numéro).

Pour un rare ou une activité hebdomadaire, trouver son numéro de quête caché (commentaires Wowhead, ou `/dump C_QuestLog.IsQuestFlaggedCompleted(<numéro>)` avant et après l'avoir fait), puis écrire par exemple :

```lua
G:Rare("rare-nom", { questId = 12345, rep = 75, map = 2437, x = 30.5, y = 22.8 })
G:Weekly("nom-activite", { title = "Nom", questIds = { 12345 }, rep = 1000 })
```

et ajouter son identifiant dans `G:Order` à l'endroit voulu. Une activité sans numéro de quête se coche à la main (clic droit dans la liste). Avec `shared = true`, la coche vaut pour tous les guides.

Lancer ensuite `busted`, puis `/reload` en jeu.
