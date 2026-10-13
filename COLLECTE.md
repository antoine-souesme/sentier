# Collecter les quêtes de réputation de Midnight

L'API de Blizzard ne dit pas combien de réputation donne chaque quête de Midnight. Sentier la relève donc en jeu, pendant que tu joues.

## Ce qui se fait tout seul

La collecte est active par défaut. Dès qu'un personnage te propose une quête de Midnight (la fenêtre de la quête s'ouvre), ou dès que tu en acceptes une, Sentier note :

- le numéro et le titre de la quête ;
- la réputation annoncée pour chacune des cinq factions de Midnight ;
- ta position.

Une quête qui ne donne de réputation à aucune de ces factions est ignorée. Il n'est pas nécessaire de finir la quête : ouvrir sa fenêtre suffit, même si tu la refuses ensuite.

La quête apparaît aussitôt dans le guide de sa faction, dans le groupe « Quêtes secondaires » de l'onglet Liste, et en mode étape juste avant les quêtes mondiales. Une quête qui donne de la réputation à deux factions apparaît dans les deux guides. Rien d'autre à faire.

La collecte est partagée par tous les personnages du même compte, et elle est gardée d'une session à l'autre.

Pour la couper : `/sentier collect off`. Pour la relancer : `/sentier collect on`. Le message de `/sentier collect off` indique combien de quêtes ont été enregistrées.

Pour aller vite, parcours les centres des zones et ouvre la fenêtre des quêtes proposées par les personnages qui ont un point d'exclamation.

## Partager ta collecte avec tes amis

Ce que tu collectes ne sert qu'à toi. Pour que tes amis en profitent, il faut écrire ces quêtes dans les fichiers des guides, puis leur redonner l'addon. Les étapes ci-dessous expliquent comment faire.

C'est à refaire seulement quand tu as collecté de nouvelles quêtes, en général après un patch. Le script ignore les quêtes déjà écrites dans les guides, donc le relancer ne crée pas de doublons.

## 1. Le fichier de sauvegarde du compte

World of Warcraft enregistre les données de chaque addon dans des fichiers appelés « SavedVariables ». Sentier en a deux :

- un fichier **du compte**, partagé par tous tes personnages : il contient les réglages et la collecte ;
- un fichier **par personnage** : guide choisi, étape en cours, coches manuelles.

La collecte est dans le fichier du compte, à cet endroit :

```
<dossier de WoW>/_retail_/WTF/Account/<COMPTE>/SavedVariables/Sentier.lua
```

Sur Mac, le dossier de WoW est en général `/Applications/World of Warcraft`. Sur Windows, c'est en général `C:\Program Files (x86)\World of Warcraft`.

`<COMPTE>` est un dossier dont le nom ressemble souvent à un numéro suivi de `#1` (par exemple `123456789#1`). Si tu en vois plusieurs, prends celui qui contient un `SavedVariables/Sentier.lua` modifié récemment.

Attention à ne pas confondre avec le fichier par personnage, rangé plus loin dans `Account/<COMPTE>/<Royaume>/<Personnage>/SavedVariables/Sentier.lua`. Celui-là ne contient pas la collecte.

Le jeu n'écrit ce fichier qu'à trois moments : `/reload`, la déconnexion, ou la fermeture du jeu. Tant que tu n'as pas fait l'un des trois, le fichier ne contient pas tes dernières quêtes collectées.

## 2. Faire écrire le fichier par le jeu

Le jeu n'écrit le fichier de sauvegarde qu'à un `/reload`, à la déconnexion ou à la fermeture du jeu. Avant d'aller plus loin, tape `/reload` ou quitte le jeu.

## 3. Récupérer le fichier

Si le jeu est installé sur la même machine que le dépôt, passe directement à l'étape 4.

Sinon, copie le fichier `Sentier.lua` du compte (voir l'étape 1) sur la machine du dépôt, par exemple dans ton dossier Téléchargements. Ne le mets pas dans le dépôt : il n'a pas à être versionné.

## 4. Lancer le script d'import

Depuis la racine du dépôt :

```bash
python3 tools/import_collect.py "/chemin/vers/Sentier.lua"
```

Mets le chemin entre guillemets : il contient souvent des espaces et un `#`.

Le script affiche les quêtes nouvelles, regroupées par fichier de guide :

```
-- Amani.lua
G:Quest(91234, { rep = 250, title = "Les esprits de la jungle", map = 2437, x = 45.2, y = 61.8 }) -- Les esprits de la jungle

-- Harati.lua
G:Quest(91877, { rep = 150, title = "Racines profondes", map = 2413, x = 30.1, y = 72.4 }) -- Racines profondes
```

Une quête qui donne de la réputation à deux factions apparaît dans les deux fichiers.

Si le script affiche « Rien de nouveau à ajouter. », soit le fichier n'a pas encore été écrit (as-tu fait `/reload` ?), soit toutes les quêtes collectées sont déjà dans les guides.

## 5. Coller les lignes dans les guides

Les guides sont dans `Sentier/Guides/Reputation/Midnight/`. Les fichiers correspondent aux factions ainsi :

| Fichier | Faction |
|---|---|
| `Amani.lua` | Tribu des Amani |
| `SilvermoonCourt.lua` | Cour de Lune-d’Argent |
| `Harati.lua` | Hara’ti |
| `Singularity.lua` | La Singularité |
| `ZuljarraForces.lua` | Forces de Zul’jarra |

Pour `Amani.lua`, `SilvermoonCourt.lua`, `Harati.lua` et `Singularity.lua`, le fichier se termine par la ligne `ns.MidnightShared.Standard(G)`. Colle les lignes `G:Quest(...)` juste en dessous. Les quêtes apparaissent alors dans l'onglet Liste, dans le groupe « Quêtes secondaires », chez tous ceux qui ont l'addon.

Pour qu'elles apparaissent aussi en mode étape, ajoute ensuite une ligne `G:Order` qui reprend l'ordre complet, avec les numéros des quêtes à l'endroit voulu :

```lua
ns.MidnightShared.Standard(G)

G:Quest(91234, { rep = 250, title = "Les esprits de la jungle", map = 2437, x = 45.2, y = 61.8 })
G:Quest(91240, { rep = 250, title = "Le tambour du chef", map = 2437, x = 47.0, y = 58.3 })

G:Order({ "silvermoon-weekly", "bountiful-delves", 91234, 91240, "worldquests" })
```

Pour `ZuljarraForces.lua`, colle les lignes avant la ligne `G:Order` déjà présente, puis ajoute les numéros dans cette ligne.

Tu peux compléter une ligne avec une note ou un prérequis :

```lua
G:Quest(91240, { rep = 250, title = "Le tambour du chef", map = 2437, x = 47.0, y = 58.3,
  note = "Parle d'abord au gardien près du pont.",
  requires = { { renown = 8 } },
})
```

Un prérequis peut aussi être une autre quête : `requires = { { quest = 91234, title = "Les esprits de la jungle" } }`.

## 6. Vérifier et mettre à jour l'addon

1. Lance les tests depuis la racine du dépôt :

   ```bash
   busted
   ```

   Ils doivent tous passer. Une erreur ici veut souvent dire une virgule ou une accolade oubliée dans une ligne collée.
2. En jeu, tape `/reload`. Si le dossier `Sentier/` est relié au dossier des addons du jeu, les changements sont pris en compte tout de suite. Sinon, recrée l'archive avec `tools/package.sh` et réinstalle-la.
3. Tape `/sentier debug` : aucun problème ne doit concerner les quêtes ajoutées.
4. Commite les guides modifiés.

## En cas de souci

- **Une quête ouverte n'apparaît pas dans le guide** : vérifie qu'elle donne bien de la réputation à une faction de Midnight, que la collecte n'a pas été coupée avec `/sentier collect off`, et que la source « quêtes secondaires » est cochée dans les réglages.
- **Le script ne trouve pas le fichier** : vérifie le chemin et les guillemets. Sur Mac, tu peux glisser le fichier dans le terminal pour écrire son chemin.
- **Le script s'arrête avec une erreur de lecture** : le fichier a peut-être été copié pendant que le jeu l'écrivait. Ferme le jeu, puis copie-le de nouveau.
- **Après un patch** : relance aussi `python3 tools/build_catalog.py` pour mettre à jour le catalogue des quêtes (noms et zones).
