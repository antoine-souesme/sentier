# Collecter les quêtes de réputation de Midnight

L'API de Blizzard ne dit pas combien de réputation donne chaque quête de Midnight. Sentier la relève donc en jeu, pendant que tu joues, puis un script transforme ce relevé en lignes à coller dans les guides. Ce guide explique chaque étape.

À refaire seulement quand un patch ajoute de nouvelles quêtes. Le script ignore les quêtes déjà présentes dans les guides, donc relancer une collecte ne crée pas de doublons.

## 1. Le fichier de sauvegarde du compte

World of Warcraft enregistre les données de chaque addon dans des fichiers appelés « SavedVariables ». Sentier en a deux :

- un fichier **du compte**, partagé par tous tes personnages : il contient les réglages et les données de collecte ;
- un fichier **par personnage** : guide choisi, étape en cours, coches manuelles.

La collecte est dans le fichier du compte, à cet endroit :

```
<dossier de WoW>/_retail_/WTF/Account/<COMPTE>/SavedVariables/Sentier.lua
```

Sur Mac, le dossier de WoW est en général `/Applications/World of Warcraft`. Sur Windows, c'est en général `C:\Program Files (x86)\World of Warcraft`.

`<COMPTE>` est un dossier dont le nom ressemble souvent à un numéro suivi de `#1` (par exemple `123456789#1`). Si tu en vois plusieurs, prends celui qui contient un `SavedVariables/Sentier.lua` modifié récemment.

Attention à ne pas confondre avec le fichier par personnage, rangé plus loin dans `Account/<COMPTE>/<Royaume>/<Personnage>/SavedVariables/Sentier.lua`. Celui-là ne contient pas la collecte.

Le jeu n'écrit ce fichier qu'à trois moments : `/reload`, la déconnexion, ou la fermeture du jeu. Tant que tu n'as pas fait l'un des trois, le fichier ne contient pas ta dernière collecte.

## 2. Collecter en jeu

1. Connecte-toi avec un personnage qui a accès aux zones de Midnight.
2. Tape `/sentier collect on`. Le message « Sentier : collecte activée. » s'affiche.
3. Joue normalement dans les zones de Midnight. Sentier note une quête à deux moments :
   - quand un personnage te la propose (la fenêtre de la quête s'ouvre) ;
   - quand tu l'acceptes.

   Il garde le numéro de la quête, son titre, la réputation annoncée pour chacune des cinq factions de Midnight, et ta position. Une quête qui ne donne de réputation à aucune de ces factions est ignorée. Il n'est pas nécessaire de finir la quête : il suffit d'ouvrir sa fenêtre.
4. Pour aller vite, parcours les centres des zones et parle aux personnages qui ont un point d'exclamation. Tu peux ouvrir la fenêtre d'une quête puis la refuser : elle est quand même notée.
5. Quand tu as fini, tape `/sentier collect off`. Le message indique combien de quêtes ont été enregistrées, par exemple « Sentier : collecte désactivée (42 quêtes enregistrées). »
6. Tape `/reload` pour que le jeu écrive le fichier de sauvegarde.

Les quêtes mondiales sont aussi notées, mais le script ne les propose pas : les guides les lisent déjà en direct dans le jeu.

La collecte reste en mémoire d'une session à l'autre. Tu peux collecter en plusieurs fois, avec plusieurs personnages du même compte, puis lancer le script une seule fois à la fin.

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

Si le script affiche « Rien de nouveau à ajouter. », soit la collecte est vide (as-tu fait `/reload` ?), soit toutes les quêtes collectées sont déjà dans les guides.

## 5. Coller les lignes dans les guides

Les guides sont dans `Sentier/Guides/Reputation/Midnight/`. Les fichiers correspondent aux factions ainsi :

| Fichier | Faction |
|---|---|
| `Amani.lua` | Tribu des Amani |
| `SilvermoonCourt.lua` | Cour de Lune-d’Argent |
| `Harati.lua` | Hara’ti |
| `Singularity.lua` | La Singularité |
| `ZuljarraForces.lua` | Forces de Zul’jarra |

Pour `Amani.lua`, `SilvermoonCourt.lua`, `Harati.lua` et `Singularity.lua`, le fichier se termine par la ligne `ns.MidnightShared.Standard(G)`. Colle les lignes `G:Quest(...)` juste en dessous. Les quêtes apparaissent alors dans l'onglet Liste, dans le groupe « Quêtes secondaires ».

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

- **Le message de collecte indique 0 quête** : vérifie que tu as bien ouvert la fenêtre de quêtes qui donnent de la réputation de Midnight, et que la collecte était activée à ce moment-là.
- **Le script ne trouve pas le fichier** : vérifie le chemin et les guillemets. Sur Mac, tu peux glisser le fichier dans le terminal pour écrire son chemin.
- **Le script s'arrête avec une erreur de lecture** : le fichier a peut-être été copié pendant que le jeu l'écrivait. Ferme le jeu, puis copie-le de nouveau.
- **Après un patch** : relance aussi `python3 tools/build_catalog.py` pour mettre à jour le catalogue des quêtes (noms et zones).
