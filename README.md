# Sentier

Addon World of Warcraft (Midnight) qui affiche des guides en jeu. Premier guide : la réputation des factions de Midnight.

## Installation pour jouer

Décompresser `Sentier-<version>.zip` dans `World of Warcraft/_retail_/Interface/AddOns/`. En jeu : `/sentier` ou le bouton des addons près de la minicarte.

## Développement

Outils : `brew install lua luarocks && luarocks install busted`, puis `python3 -m venv .venv && .venv/bin/pip install pytest`.

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
.venv/bin/pytest tests/python
```

## Outils

- `python3 tools/build_catalog.py` : régénère le catalogue des quêtes de Midnight (identifiants Blizzard dans `.env` : `BLIZZARD_CLIENT_ID`, `BLIZZARD_CLIENT_SECRET`). À relancer à chaque patch.
- `python3 tools/import_collect.py <SavedVariables/Sentier.lua>` : propose des lignes `G:Quest(...)` à partir du mode collecte. Voir `COLLECTE.md`.
- `tools/package.sh` : crée l'archive à partager.

## Commandes en jeu

`/sentier` (afficher ou masquer), `/sentier debug` (problèmes détectés et cartes trouvées), `/sentier collect on|off`.

## Documentation

- `docs/contenu.md` : ajouter des quêtes aux guides.
- `docs/controle-en-jeu.md` : liste de contrôle à faire en jeu.
