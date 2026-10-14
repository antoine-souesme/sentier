# Sentier

Addon World of Warcraft (Midnight) qui affiche des guides en jeu. Premier guide : la réputation des factions de Midnight.

## Installation pour jouer

Sentier a besoin de l'addon **Grail** (base de données des quêtes) : l'installer depuis CurseForge (https://www.curseforge.com/wow/addons/grail) ou depuis https://github.com/smaitch/Grail (copier les dossiers `Grail` et `Grail-Reputations` dans `AddOns`).

Décompresser ensuite `Sentier-<version>.zip` dans `World of Warcraft/_retail_/Interface/AddOns/`. En jeu : `/sentier`, l'icône de Sentier sur la minicarte, ou le bouton des addons près de la minicarte.

Si Grail est indiqué « périmé » dans la liste des addons, cocher « Charger les addons périmés ».

## Développement

Outils : `brew install lua luarocks && luarocks install busted`.

Relier l'addon au jeu (une seule fois) :

```bash
# macOS
ln -s "$PWD/Sentier" "/Applications/World of Warcraft/_retail_/Interface/AddOns/Sentier"
# Windows (invite de commandes, depuis le dossier du projet)
mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Sentier" Sentier
```

En jeu, `/reload` recharge les changements.

## Tests

```bash
busted                       # tests Lua
```

## Outils

- `tools/package.sh` : crée l'archive à partager.

## Commandes en jeu

`/sentier` (afficher ou masquer), `/sentier debug` (problèmes détectés, cartes trouvées et nombre de quêtes venues de Grail).

## Documentation

- `docs/contenu.md` : ajouter des quêtes aux guides.
- `docs/controle-en-jeu.md` : liste de contrôle à faire en jeu.
