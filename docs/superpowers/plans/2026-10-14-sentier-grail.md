# Sentier : guides remplis par Grail — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplir les guides de réputation de Midnight avec les données de l'addon Grail lues en jeu, retirer le remplissage à la main, et améliorer la fenêtre (barre de titre, retour sur les clics, icône de minicarte, quêtes faites cachées par défaut).

**Architecture:** Un seul fichier, `Sensors/Grail.lua` (`ns.GrailSource`), lit Grail. `Core/GrailGuides.lua` (`ns.GrailGuides`) transforme ses réponses en tâches `G:Quest` et les ordonne (zone, puis prérequis, puis numéro). `Core/Core.lua` attend que Grail soit prêt après la connexion, puis remplit les guides. L'interface gagne une barre de titre, une ligne de message, et `UI/MinimapButton.lua`.

**Tech Stack:** Lua (WoW 12.1, Lua 5.1 en jeu), busted (tests, Lua 5.5 sur la machine), addon Grail 127 (`smaitch/Grail`).

**Spec:** `docs/superpowers/specs/2026-10-14-sentier-grail-design.md` (complète `docs/superpowers/specs/2026-10-13-sentier-design.md`).

## Global Constraints

- Branche : rester sur `feature/sentier-v1`. Ne pas créer de branche. Ne pas committer la modification en cours de `.gitignore` (elle appartient à l'utilisateur) : toujours `git add` des fichiers nommés, jamais `git add -A` ni `git add .`.
- Messages de commit en français, à l'impératif présent comme l'historique (« Ajoute… », « Retire… »), terminés par la ligne `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- `Sentier.toc` garde `## Interface: 120100` et gagne `## Dependencies: Grail`.
- Tout texte affiché au joueur va dans `Sentier/Locales/fr.lua`, en français avec les accents.
- Seuls les fichiers de `Sentier/Sensors/` appellent le jeu pour les quêtes, la réputation et les cartes ; seul `Sentier/Sensors/Grail.lua` touche à la variable globale `Grail`.
- Aucune donnée ne doit provoquer d'erreur Lua : les lectures sont protégées par `pcall`, et les problèmes sont notés par `ns.Registry:Problem(...)` (visibles avec `/sentier debug`).
- Le code tourne en Lua 5.1 dans WoW : pas d'opérateur `//`, pas de `goto`, pas de `math.atan(y, x)` à deux arguments sans repli sur `math.atan2`.
- Tests : `busted` depuis la racine du dépôt. Tous les tests doivent passer à la fin de chaque tâche.
- Le fichier de test `tests/lua/toc_spec.lua` vérifie que chaque fichier `.lua` de `Sentier/` est listé dans `Sentier.toc` : toute tâche qui crée ou supprime un fichier `.lua` met le `.toc` à jour dans la même tâche.

## Review Focus

1. Une quête qui donne de la réputation à deux factions suivies doit apparaître dans les deux guides (tests en tâches 3 et 4).
2. Une quête Grail dont le prérequis n'est pas fait doit être grisée avec le nom de la quête requise, ou « Quête #<numéro> » si Grail ne connaît pas encore ce nom (test en tâche 4).
3. Si Grail est absent, ou si sa lecture échoue, Sentier ne doit lever aucune erreur et doit garder ses tâches écrites à la main (tests en tâches 3 et 4).
4. Un joueur qui avait gardé l'ancien réglage « masquer les tâches terminées » décoché voit les quêtes faites cachées une fois après la mise à jour, puis son nouveau choix est respecté (tests en tâche 2).
5. Glisser l'icône de minicarte sous son centre doit donner un angle entre 0 et 360, jamais négatif (test en tâche 8).

---

### Task 1: Retirer la collecte, la recherche à la connexion et le catalogue

**Files:**
- Delete: `Sentier/Core/Collect.lua`, `Sentier/Core/Scan.lua`, `Sentier/Guides/Reputation/Midnight/Catalog.lua`
- Delete: `tools/build_catalog.py`, `tools/blizzard.py`, `tools/check_blizzard_quests.py`, `tools/import_collect.py`, dossier `tests/python/`
- Delete: `tests/lua/collect_spec.lua`, `tests/lua/scan_spec.lua`
- Modify: `Sentier/Core/Registry.lua`, `Sentier/Core/State.lua`, `Sentier/Core/Core.lua`, `Sentier/Sensors/Sensors.lua`, `Sentier/Locales/fr.lua`, `Sentier/Sentier.toc`
- Modify: les cinq guides `Sentier/Guides/Reputation/Midnight/{Amani,SilvermoonCourt,Harati,Singularity,ZuljarraForces}.lua`
- Modify (tests): `tests/lua/helper.lua`, `tests/lua/registry_spec.lua`, `tests/lua/state_spec.lua`, `tests/lua/models_spec.lua`, `tests/lua/sensors_spec.lua`, `tests/lua/guides_spec.lua`

**Interfaces:**
- Consumes: rien.
- Produces: `Guide:Quest(questId, opts)` n'utilise plus de catalogue : le titre vient seulement de `opts.title`. Une quête sans titre n'est plus « manquante » ni « inconnue » ; elle s'affiche « Quête #<numéro> » (déjà géré par `Models.TaskTitle`). Le champ `task.missing` et la clé de texte `PROBLEM_QUEST_MISSING` disparaissent. `Sentier:NewGuide` n'accepte plus `catalog`.

- [ ] **Step 1: Adapter les tests au nouveau comportement**

Dans `tests/lua/registry_spec.lua` :

Remplacer le test « complète une quête avec le catalogue et la faction du guide » par :

```lua
  it("complète une quête avec la faction du guide", function()
    local g = Sentier:NewGuide("rep-a", { title = "A", category = "R", faction = 2696 })
    local t = g:Quest(100, { rep = 250, title = "La chasse attend" })
    assert.are.equal("La chasse attend", t.title)
    assert.are.same({ 2696 }, t.factions)
    assert.are.same({ 100 }, t.questIds)
    assert.are.equal("sidequests", t.source)
    assert.are.equal("none", t.reset)
    assert.are.equal("100", t.key)
    assert.are.equal(250, t.rep)
  end)
```

Remplacer les deux tests « signale une quête absente du catalogue » et « marque manquante une quête absente du catalogue » par :

```lua
  it("garde une quête sans titre sans noter de problème", function()
    local g = Sentier:NewGuide("rep-a", { title = "A", category = "R" })
    local t = g:Quest(999, {})
    assert.is_nil(t.title)
    assert.is_nil(t.missing)
    assert.are.same({}, ns.Registry.problems)
  end)
```

Dans « construit l'ordre et ignore les tâches inconnues », remplacer la ligne `local g = Sentier:NewGuide("rep-a", { title = "A", category = "R", catalog = { [1] = { title = "Q" } } })` par :

```lua
    local g = Sentier:NewGuide("rep-a", { title = "A", category = "R" })
```

Remplacer le test « ne lève pas d'erreur pour une quête absente au numéro non numérique » par :

```lua
  it("ne lève pas d'erreur pour une quête au numéro non numérique", function()
    local g = Sentier:NewGuide("rep-a", { title = "A", category = "R" })
    local t
    assert.has_no.errors(function() t = g:Quest("abc", {}) end)
    assert.are.equal("abc", t.key)
  end)
```

Dans `tests/lua/state_spec.lua`, dans le `before_each`, supprimer la ligne `catalog = { [1] = { title = "Q1" }, [2] = { title = "Q2" }, [3] = { title = "Q3" } },`. Remplacer le test « une quête absente du catalogue est inconnue » par :

```lua
  it("suit normalement une quête sans titre", function()
    local t = g:Quest(99, {})
    assert.are.equal("todo", status(t))
    ns.Sensors.done[99] = true
    assert.are.equal("done", status(t))
  end)
```

Dans `tests/lua/models_spec.lua`, dans le `before_each`, supprimer la ligne `catalog = { [1] = { title = "Quête A" }, [2] = { title = "Quête B" }, [3] = { title = "Quête C" } },`. Puis donner les titres directement :
- ligne `g:Quest(1, { rep = 250, map = 2437, x = 45.2, y = 60.1, note = "Parle à Zerella" })` → `g:Quest(1, { title = "Quête A", rep = 250, map = 2437, x = 45.2, y = 60.1, note = "Parle à Zerella" })`
- la ligne `g:Quest(2, {})` qui la suit (test « décrit l'étape en cours et annonce la suivante ») → `g:Quest(2, { title = "Quête B" })`
- dans le `before_each` du `describe("liste")` : `g:Quest(1, { title = "Quête A", rep = 250 })`, `g:Quest(2, { title = "Quête B", rep = 100 })`, `g:Quest(3, { title = "Quête C", rep = 50, requires = { { renown = 14 } } })`

Dans `tests/lua/sensors_spec.lua`, supprimer les tests qui visent des fonctions retirées : « convertit les récompenses de réputation », « demande au jeu de charger une quête et ses récompenses », « ne lève pas d'erreur si le chargement d'une quête est impossible », et tout le bloc `describe("GetOfferedQuest", ...)`.

Dans `tests/lua/guides_spec.lua`, remplacer la ligne `FILES` par :

```lua
local FILES = { "Zones.lua", "Amani.lua", "SilvermoonCourt.lua", "Harati.lua", "Singularity.lua", "ZuljarraForces.lua" }
```

et supprimer le test « ont un catalogue qui couvre les six zones ».

Dans `tests/lua/helper.lua`, retirer `"Sentier/Core/Collect.lua"` et `"Sentier/Core/Scan.lua"` de `H.FILES`, et retirer de `H.fakeSensors` le champ `position = nil,` et la ligne `f.GetPlayerPosition = function() return f.position end`.

Supprimer `tests/lua/collect_spec.lua` et `tests/lua/scan_spec.lua` :

```bash
git rm -q tests/lua/collect_spec.lua tests/lua/scan_spec.lua
```

- [ ] **Step 2: Lancer les tests pour voir les échecs**

Run: `busted`
Expected: FAIL, notamment « garde une quête sans titre sans noter de problème » (le code actuel note « Quête absente du catalogue ») et « suit normalement une quête sans titre » (le code actuel renvoie `unknown`).

- [ ] **Step 3: Simplifier le registre et l'état**

Dans `Sentier/Core/Registry.lua`, dans `Registry:NewGuide`, supprimer la ligne `catalog = opts.catalog or {},`. Remplacer toute la fonction `Guide:Quest` par :

```lua
function Guide:Quest(questId, opts)
  return self:Add(merge({ id = questId, type = "quest", source = "sidequests", reset = "none", questIds = { questId } }, opts))
end
```

Dans `Sentier/Core/State.lua`, dans `State:TaskStatus`, supprimer la ligne `if task.missing then return "unknown", info end` et la ligne vide qui la suit.

- [ ] **Step 4: Retirer la collecte et la recherche du cœur**

Dans `Sentier/Core/Core.lua` :

Supprimer toute la fonction `Core:CollectWorldQuests` et, dans `Core:Refresh`, la ligne `self:CollectWorldQuests(result)`.

Remplacer tout le bloc `Core:SetScript("OnEvent", ...)` et les trois `Core:RegisterEvent(...)` qui le suivent par :

```lua
Core:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    if ... == addonName then
      ns.DB:Init()
      self:UnregisterEvent("ADDON_LOADED")
    end
  elseif event == "PLAYER_LOGIN" then
    ns.UI:Create()
    if ns.DB.char.hidden then ns.UI.frame:Hide() end
    for _, e in ipairs(REFRESH_EVENTS) do
      if not pcall(self.RegisterEvent, self, e) then ns.Registry:Problem(L.PROBLEM_EVENT:format(e)) end
    end
    self:Refresh()
    self:ScheduleReset()
  else
    self:RequestRefresh()
  end
end)
Core:RegisterEvent("ADDON_LOADED")
Core:RegisterEvent("PLAYER_LOGIN")
```

Dans `printDebug`, supprimer la ligne `print(L.DEBUG_SCAN:format(ns.Scan.total, ns.Scan.found, #ns.Scan.queue))`. Supprimer la fonction locale `countCollected`. Dans `SlashCmdList.SENTIER`, supprimer les deux branches `elseif cmd == "collect" ...` (de `elseif cmd == "collect" and arg == "on" then` jusqu'à la ligne `print(L.COLLECT_OFF:format(countCollected()))` incluse).

- [ ] **Step 5: Retirer les capteurs devenus inutiles**

Dans `Sentier/Sensors/Sensors.lua`, supprimer entièrement les fonctions `S.GetQuestRepRewards`, `S.RequestQuestData` (avec son commentaire), `S.GetOfferedQuestRepRewards`, `S.GetQuestTitle`, `S.GetPlayerPosition` et `S.GetOfferedQuest`. Garder la fonction locale `normalize` (utilisée par `S.GetActiveWorldQuests`).

Dans `Sentier/Locales/fr.lua`, supprimer les clés `DEBUG_SCAN`, `COLLECT_ON`, `COLLECT_OFF`, `PROBLEM_QUEST_MISSING`, `READ_REPUTATION`, `READ_OFFERED_REPUTATION`, `READ_OFFERED_QUEST`, `READ_TITLE`, `READ_POSITION`, et remplacer `HELP` par :

```lua
  HELP = "Sentier : /sentier (afficher ou masquer), /sentier debug",
```

- [ ] **Step 6: Retirer le catalogue des guides et du .toc**

Dans chacun des cinq guides de `Sentier/Guides/Reputation/Midnight/`, retirer `, catalog = ns.MidnightCatalog` de l'appel à `Sentier:NewGuide`. Par exemple `Amani.lua` devient :

```lua
local G = Sentier:NewGuide("rep-midnight-amani", {
  title = "Tribu des Amani", category = "Réputation", faction = 2696,
})
```

Dans `Sentier/Sentier.toc`, supprimer les lignes `Core\Collect.lua`, `Core\Scan.lua` et `Guides\Reputation\Midnight\Catalog.lua`.

Supprimer les fichiers :

```bash
git rm -q Sentier/Core/Collect.lua Sentier/Core/Scan.lua Sentier/Guides/Reputation/Midnight/Catalog.lua \
  tools/build_catalog.py tools/blizzard.py tools/check_blizzard_quests.py tools/import_collect.py
git rm -rq tests/python
```

- [ ] **Step 7: Vérifier qu'il ne reste aucune référence**

Run: `grep -rn "Collect\|Scan\|catalog\|Catalog\|missing\|GetQuestRepRewards\|RequestQuestData\|GetOfferedQuest\|GetQuestTitle\|GetPlayerPosition" Sentier tests/lua`
Expected: aucune ligne (le mot « collect » ne doit plus apparaître dans le code ; `DB.lua` garde encore `collect` jusqu'à la tâche 2, c'est normal s'il apparaît seul dans `Sentier/Core/DB.lua` et `tests/lua/db_spec.lua`).

- [ ] **Step 8: Lancer les tests**

Run: `busted`
Expected: PASS, 0 failures, 0 errors.

- [ ] **Step 9: Commit**

```bash
git add Sentier tests/lua
git commit -m "Retire la collecte, la recherche à la connexion et le catalogue

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Cacher les quêtes faites par défaut et effacer les données de collecte

**Files:**
- Modify: `Sentier/Core/DB.lua`
- Modify: `Sentier/UI/ListTab.lua`
- Modify: `Sentier/Locales/fr.lua`
- Test: `tests/lua/db_spec.lua`

**Interfaces:**
- Consumes: rien.
- Produces: `SentierDB.version` vaut `2`. `ns.DB.account.hideDone` vaut `true` par défaut. `ns.DB.account.minimap = { angle = 225, hidden = false }` (utilisé par la tâche 8). `ns.DB.account.collect` n'existe plus. Clé de texte `L.SHOW_DONE`.

- [ ] **Step 1: Écrire les tests**

Dans `tests/lua/db_spec.lua`, remplacer le test « complète les réglages sans écraser ceux du joueur » par :

```lua
  it("complète les réglages sans écraser ceux du joueur", function()
    local ns = H.load({ account = { version = 2, nav = "tomtom", sources = { rares = false } } })
    assert.are.equal("tomtom", ns.DB.account.nav)
    assert.is_false(ns.DB.account.sources.rares)
    assert.is_true(ns.DB.account.sources.weekly)
    assert.is_true(ns.DB.account.hideDone)
    assert.are.same({ angle = 225, hidden = false }, ns.DB.account.minimap)
    assert.are.equal("step", ns.DB.char.tab)
    assert.are.same({}, ns.DB.char.marks)
  end)

  it("efface la collecte et cache les quêtes faites lors de la mise à jour", function()
    local ns = H.load({ account = { hideDone = false, collect = { enabled = true, quests = { [5] = { title = "x" } } } } })
    assert.is_nil(ns.DB.account.collect)
    assert.is_true(ns.DB.account.hideDone)
    assert.are.equal(2, ns.DB.account.version)
  end)

  it("respecte ensuite le choix d'afficher les quêtes faites", function()
    local ns = H.load({ account = { version = 2, hideDone = false } })
    assert.is_false(ns.DB.account.hideDone)
  end)

  it("cache les quêtes faites pour un nouveau joueur", function()
    local ns = H.load()
    assert.is_true(ns.DB.account.hideDone)
    assert.are.equal(2, ns.DB.account.version)
  end)
```

- [ ] **Step 2: Lancer les tests pour voir les échecs**

Run: `busted tests/lua/db_spec.lua`
Expected: FAIL (`hideDone` vaut `false`, `minimap` et `version` n'existent pas, `collect` existe).

- [ ] **Step 3: Mettre à jour la sauvegarde**

Dans `Sentier/Core/DB.lua`, remplacer `ACCOUNT_DEFAULTS` par :

```lua
local VERSION = 2

local ACCOUNT_DEFAULTS = {
  sources = { sidequests = true, weekly = true, daily = true, rares = true, worldquests = true },
  nav = "auto",
  hideDone = true,
  locked = false,
  minimap = { angle = 225, hidden = false },
}
```

et remplacer `DB:Init` par :

```lua
function DB:Init()
  local account = type(SentierDB) == "table" and SentierDB or {}
  -- Version 2 : les guides viennent de Grail. La collecte disparaît et les quêtes faites
  -- sont cachées une fois pour tous ; le joueur peut ensuite les réafficher.
  if (account.version or 1) < VERSION then
    account.collect = nil
    account.hideDone = true
  end
  account.version = VERSION
  SentierDB = fill(account, ACCOUNT_DEFAULTS)
  SentierCharDB = fill(type(SentierCharDB) == "table" and SentierCharDB or {}, CHAR_DEFAULTS)
  self.account, self.char = SentierDB, SentierCharDB
end
```

- [ ] **Step 4: Lancer les tests**

Run: `busted`
Expected: PASS.

- [ ] **Step 5: Ajouter la case « Afficher les quêtes faites » dans l'onglet Liste**

Dans `Sentier/Locales/fr.lua`, ajouter après `SETTINGS_HIDE_DONE` :

```lua
  SHOW_DONE = "Afficher les quêtes faites",
```

Dans `Sentier/UI/ListTab.lua`, dans `ListTab:Create`, remplacer :

```lua
  local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT")
```

par :

```lua
  -- Même réglage que « Masquer les tâches terminées » dans les réglages, en sens inverse.
  local showDone = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
  showDone:SetPoint("TOPLEFT", -2, 2)
  showDone:SetSize(22, 22)
  showDone.label = showDone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  showDone.label:SetPoint("LEFT", showDone, "RIGHT", 2, 0)
  showDone.label:SetText(L.SHOW_DONE)
  showDone:SetScript("OnClick", function(self)
    ns.DB.account.hideDone = not self:GetChecked()
    ns.Core:Refresh()
  end)
  p.showDone = showDone

  local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -24)
```

Dans `p:Render`, ajouter en première ligne :

```lua
    self.showDone:SetChecked(not ns.DB.account.hideDone)
```

- [ ] **Step 6: Lancer les tests**

Run: `busted`
Expected: PASS (l'interface n'est pas chargée par les tests ; `toc_spec` vérifie que `ListTab.lua` compile).

- [ ] **Step 7: Commit**

```bash
git add Sentier/Core/DB.lua Sentier/UI/ListTab.lua Sentier/Locales/fr.lua tests/lua/db_spec.lua
git commit -m "Cache les quêtes faites par défaut et efface les données de collecte

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Lire Grail (`Sensors/Grail.lua`)

**Files:**
- Create: `Sentier/Sensors/Grail.lua`
- Modify: `Sentier/Sentier.toc` (ajouter `Sensors\Grail.lua` juste après `Sensors\Sensors.lua`)
- Modify: `Sentier/Locales/fr.lua`
- Test: `tests/lua/grail_source_spec.lua`

**Interfaces:**
- Consumes: `ns.Registry:Problem(message)`, `ns.L`.
- Produces: `ns.GrailSource` avec :
  - `GrailSource.Available() -> boolean` : la variable globale `Grail` existe.
  - `GrailSource.Ready() -> boolean` : Grail a fini son chargement de connexion.
  - `GrailSource.QuestsByFaction(factionIds: {number}) -> { [factionId] = { { questId = number, rep = number }, ... } } | nil` : listes triées par `questId` ; `nil` sans Grail ou en cas d'erreur.
  - `GrailSource.QuestInfo(questId) -> { title = string|nil, worldQuest = boolean, daily = boolean, weekly = boolean, requires = {number}, map = number|nil, x = number|nil, y = number|nil } | nil` : coordonnées entre 0 et 100.
  - `GrailSource.QuestTitle(questId) -> string|nil`.
  - Clé de texte `L.PROBLEM_GRAIL` (« Lecture de Grail impossible : %s »).

Ce qu'il faut savoir de Grail 127 (lu dans `Grail/Grail.lua` du dépôt `smaitch/Grail`) :
- À la fin de son traitement de `PLAYER_LOGIN`, Grail écrit `Grail.timings.AddonLoaded`. C'est le signe qu'il est prêt.
- `Grail:LoadReputations()` charge l'addon `Grail-Reputations` (chargé à la demande). Ensuite, `Grail.questReputations[questId]` est une **chaîne** faite de codes de 4 octets mis bout à bout (une par faction récompensée). Avant ce chargement, les valeurs sont des tables ou absentes : on ignore tout ce qui n'est pas une chaîne.
- `Grail:ReputationDecode(code4)` renvoie `hexFaction, valeur` : `hexFaction` est l'identifiant de faction en hexadécimal sur 3 caractères (`"A88"` = 2696), `valeur` la réputation gagnée (négative pour une perte).
- `Grail:QuestPrerequisites(questId)` renvoie une table « OU » : `{ A, B }` veut dire A ou B ; un élément table `{ A, B }` veut dire A et B ; les éléments sont des nombres (numéros de quête) ou des chaînes (autres conditions, comme `"PF175"`). On ne garde que le cas simple : une seule possibilité, dont on retient les numéros de quête.
- `Grail:QuestLocationsAccept(questId)` renvoie une liste d'enregistrements `{ mapArea, x, y, name, ... }` (coordonnées 0-100) ou `nil`.
- `Grail:QuestName(questId)`, `Grail:IsWorldQuest(questId)`, `Grail:IsDaily(questId)`, `Grail:IsWeekly(questId)`.

- [ ] **Step 1: Écrire les tests**

Créer `tests/lua/grail_source_spec.lua` :

```lua
local H = dofile("tests/lua/helper.lua")

-- Grail simulé : un code de 4 caractères est décodé d'après sa première lettre.
local function fakeGrail()
  local codes = { a = { "A88", 250 }, b = { "A96", 75 }, c = { "A88", -10 }, d = { "04C", 250 } }
  return {
    timings = { AddonLoaded = 12 },
    loads = 0,
    questReputations = {
      [101] = "aaaa",
      [102] = "aaaabbbb",
      [103] = "cccc",
      [104] = "dddd",
      [105] = { "A88250" }, -- format avant chargement : ignoré
    },
    LoadReputations = function(self) self.loads = self.loads + 1 end,
    ReputationDecode = function(_, code)
      local c = codes[code:sub(1, 1)]
      return c[1], c[2]
    end,
    QuestName = function(_, id) return ({ [101] = "Ami ou adversaire" })[id] end,
    IsWorldQuest = function(_, id) return id == 103 end,
    IsDaily = function(_, id) return id == 104 end,
    IsWeekly = function() return false end,
    QuestPrerequisites = function(_, id)
      return ({ [102] = { 101 }, [104] = { { 101, "PF175" } }, [105] = { 101, 102 } })[id]
    end,
    QuestLocationsAccept = function(_, id)
      if id == 101 then return { { mapArea = 2437, x = 33.5, y = 48.6, name = "Zerella" } } end
    end,
  }
end

describe("GrailSource", function()
  local ns, GS

  before_each(function()
    ns = H.load()
    assert(loadfile("Sentier/Sensors/Grail.lua"))("Sentier", ns)
    GS = ns.GrailSource
    _G.Grail = fakeGrail()
  end)

  after_each(function() _G.Grail = nil end)

  it("sait si Grail est installé et prêt", function()
    assert.is_true(GS.Available())
    assert.is_true(GS.Ready())
    _G.Grail.timings = {}
    assert.is_false(GS.Ready())
    _G.Grail = nil
    assert.is_false(GS.Available())
    assert.is_false(GS.Ready())
  end)

  it("liste les quêtes qui donnent de la réputation à chaque faction demandée", function()
    local out = GS.QuestsByFaction({ 2696, 2710 })
    assert.are.same({ { questId = 101, rep = 250 }, { questId = 102, rep = 250 } }, out[2696])
    assert.are.same({ { questId = 102, rep = 75 } }, out[2710])
  end)

  it("ne charge la réputation de Grail qu'une fois", function()
    GS.QuestsByFaction({ 2696 })
    GS.QuestsByFaction({ 2696 })
    assert.are.equal(1, _G.Grail.loads)
  end)

  it("renvoie nil sans Grail, et nil avec un problème si Grail échoue", function()
    _G.Grail = nil
    assert.is_nil(GS.QuestsByFaction({ 2696 }))
    _G.Grail = fakeGrail()
    _G.Grail.ReputationDecode = function() error("boom") end
    assert.has_no.errors(function() assert.is_nil(GS.QuestsByFaction({ 2696 })) end)
    assert.is_true(H.hasProblem(ns, "Lecture de Grail impossible"))
  end)

  it("donne le nom, la position et les prérequis d'une quête", function()
    assert.are.same({
      title = "Ami ou adversaire", worldQuest = false, daily = false, weekly = false,
      requires = {}, map = 2437, x = 33.5, y = 48.6,
    }, GS.QuestInfo(101))
    assert.are.same({ 101 }, GS.QuestInfo(102).requires)
    assert.is_nil(GS.QuestInfo(102).map)
  end)

  it("ne garde que les prérequis simples", function()
    assert.are.same({ 101 }, GS.QuestInfo(104).requires) -- 101 et une condition de métier
    assert.are.same({}, GS.QuestInfo(105).requires)     -- 101 ou 102 : ignoré
  end)

  it("reconnaît les quêtes mondiales et journalières", function()
    assert.is_true(GS.QuestInfo(103).worldQuest)
    assert.is_true(GS.QuestInfo(104).daily)
  end)

  it("renvoie nil sans erreur quand Grail échoue sur une quête", function()
    _G.Grail.QuestName = function() error("boom") end
    assert.has_no.errors(function() assert.is_nil(GS.QuestInfo(101)) end)
    assert.has_no.errors(function() assert.is_nil(GS.QuestTitle(101)) end)
  end)

  it("donne le nom d'une quête", function()
    assert.are.equal("Ami ou adversaire", GS.QuestTitle(101))
    assert.is_nil(GS.QuestTitle(999))
  end)
end)
```

- [ ] **Step 2: Lancer les tests pour voir les échecs**

Run: `busted tests/lua/grail_source_spec.lua`
Expected: FAIL (fichier `Sentier/Sensors/Grail.lua` introuvable).

- [ ] **Step 3: Écrire `Sentier/Sensors/Grail.lua`**

```lua
local _, ns = ...
local L = ns.L

-- Seul fichier qui lit Grail, la base de données des quêtes dont Sentier dépend.
-- Chaque lecture est protégée : en cas d'erreur, elle renvoie nil et note un problème.
local GS = {}
ns.GrailSource = GS

local function grail()
  return type(_G.Grail) == "table" and _G.Grail or nil
end

local function safe(fn)
  local ok, result = pcall(fn)
  if ok then return result end
  ns.Registry:Problem(L.PROBLEM_GRAIL:format(tostring(result)))
  return nil
end

function GS.Available()
  return grail() ~= nil
end

-- Grail écrit timings.AddonLoaded à la fin de son chargement de connexion.
function GS.Ready()
  local G = grail()
  return G ~= nil and type(G.timings) == "table" and G.timings.AddonLoaded ~= nil
end

local reputationsLoaded = false

-- Une fois Grail-Reputations chargé, questReputations[questId] est une chaîne de codes de 4 octets.
function GS.QuestsByFaction(factionIds)
  local G = grail()
  if not G then return nil end
  return safe(function()
    if not reputationsLoaded then
      G:LoadReputations()
      reputationsLoaded = true
    end
    local out = {}
    for _, id in ipairs(factionIds) do out[id] = {} end
    for questId, codes in pairs(G.questReputations or {}) do
      if type(codes) == "string" then
        for i = 1, #codes - 3, 4 do
          local hex, value = G:ReputationDecode(codes:sub(i, i + 3))
          local list = out[tonumber(hex, 16)]
          if list and value and value > 0 then
            list[#list + 1] = { questId = questId, rep = value }
          end
        end
      end
    end
    for _, list in pairs(out) do
      table.sort(list, function(a, b) return a.questId < b.questId end)
    end
    return out
  end)
end

-- Prérequis de Grail : { A, B } = A ou B ; { { A, B } } = A et B ; une chaîne = autre condition.
-- On ne garde que le cas d'une seule possibilité, et seulement ses numéros de quête.
local function simpleRequires(list)
  if type(list) ~= "table" or #list ~= 1 then return {} end
  local only = list[1]
  local items = type(only) == "table" and only or { only }
  local out = {}
  for _, id in ipairs(items) do
    if type(id) == "number" then out[#out + 1] = id end
  end
  return out
end

function GS.QuestInfo(questId)
  local G = grail()
  if not G then return nil end
  return safe(function()
    local info = {
      title = G:QuestName(questId),
      worldQuest = G:IsWorldQuest(questId) == true,
      daily = G:IsDaily(questId) == true,
      weekly = G:IsWeekly(questId) == true,
      requires = simpleRequires(G:QuestPrerequisites(questId)),
    }
    for _, loc in ipairs(G:QuestLocationsAccept(questId) or {}) do
      if loc.mapArea and loc.x and loc.y then
        info.map, info.x, info.y = loc.mapArea, loc.x, loc.y
        break
      end
    end
    return info
  end)
end

function GS.QuestTitle(questId)
  local G = grail()
  if not G then return nil end
  return safe(function() return G:QuestName(questId) end)
end
```

Dans `Sentier/Locales/fr.lua`, ajouter après `PROBLEM_WAYPOINT` :

```lua
  PROBLEM_GRAIL = "Lecture de Grail impossible : %s",
```

Dans `Sentier/Sentier.toc`, ajouter la ligne `Sensors\Grail.lua` juste après `Sensors\Sensors.lua`.

- [ ] **Step 4: Lancer les tests**

Run: `busted`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sentier/Sensors/Grail.lua Sentier/Sentier.toc Sentier/Locales/fr.lua tests/lua/grail_source_spec.lua
git commit -m "Ajoute la lecture des quêtes et de la réputation dans Grail

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Remplir et ordonner les guides avec Grail (`Core/GrailGuides.lua`)

**Files:**
- Create: `Sentier/Core/GrailGuides.lua`
- Modify: `Sentier/Core/Registry.lua` (options `fromGrail` et `zones` de `NewGuide`)
- Modify: `Sentier/Sensors/Sensors.lua` (ajouter `S.GetMapName`)
- Modify: `Sentier/Sentier.toc` (ajouter `Core\GrailGuides.lua` juste après `Core\Models.lua`)
- Modify (tests): `tests/lua/helper.lua`, `tests/lua/registry_spec.lua`, `tests/lua/sensors_spec.lua`
- Test: `tests/lua/grail_guides_spec.lua`

**Interfaces:**
- Consumes: `ns.GrailSource.QuestsByFaction`, `ns.GrailSource.QuestInfo`, `ns.GrailSource.QuestTitle` (tâche 3) ; `Guide:Quest(questId, opts)` (tâche 1).
- Produces:
  - `Sentier:NewGuide(id, { ..., fromGrail = true, zones = { "Nom de zone", ... } })` : `guide.fromGrail` (booléen, `false` par défaut) et `guide.zones` (liste de noms, `{}` par défaut).
  - `ns.Sensors.GetMapName(mapId) -> string|nil`.
  - `ns.GrailGuides:Fill() -> number` : ajoute les quêtes de Grail aux guides `fromGrail`, renvoie le nombre de tâches ajoutées et le garde dans `ns.GrailGuides.added`.
  - `ns.GrailGuides:Sort(guide, tasks) -> tasks` : ordre conseillé.
  - `ns.GrailGuides:RefreshTitles(guide)` : complète les titres manquants (tâches et prérequis) des tâches venues de Grail.
  - Les tâches ajoutées ont `fromGrail = true`.

- [ ] **Step 1: Préparer le harnais de test**

Dans `tests/lua/helper.lua` :
- ajouter `"Sentier/Core/GrailGuides.lua",` dans `H.FILES`, juste après `"Sentier/Core/Models.lua",` ;
- dans `H.fakeSensors`, ajouter le champ `mapNames = {},` et la ligne `f.GetMapName = function(id) return f.mapNames[id] end` ;
- ajouter, avant `function H.load(saved)` :

```lua
-- Grail simulé au niveau de GrailSource : les tests remplissent byFaction, infos et titles.
function H.fakeGrailSource()
  local f = { ready = true, available = true, byFaction = {}, infos = {}, titles = {}, broken = false }
  f.Available = function() return f.available end
  f.Ready = function() return f.ready end
  f.QuestsByFaction = function(ids)
    if f.broken then return nil end
    local out = {}
    for _, id in ipairs(ids) do out[id] = f.byFaction[id] or {} end
    return out
  end
  f.QuestInfo = function(id) return f.infos[id] end
  f.QuestTitle = function(id) return f.titles[id] end
  return f
end
```

- dans `H.load`, ajouter `ns.GrailSource = H.fakeGrailSource()` juste après `ns.Sensors = H.fakeSensors()`.

- [ ] **Step 2: Écrire les tests**

Dans `tests/lua/registry_spec.lua`, ajouter avant le dernier `end)` :

```lua
  it("retient qu'un guide se remplit avec Grail et l'ordre de ses zones", function()
    local g = Sentier:NewGuide("rep-a", { title = "A", category = "R", fromGrail = true, zones = { "Harandar" } })
    assert.is_true(g.fromGrail)
    assert.are.same({ "Harandar" }, g.zones)
    local h = Sentier:NewGuide("rep-b", { title = "B", category = "R" })
    assert.is_false(h.fromGrail)
    assert.are.same({}, h.zones)
  end)
```

Dans `tests/lua/sensors_spec.lua`, ajouter avant le dernier `end)` :

```lua
  it("donne le nom d'une carte", function()
    _G.C_Map = { GetMapInfo = function(id) if id == 2413 then return { name = "Harandar" } end end }
    assert.are.equal("Harandar", S.GetMapName(2413))
    assert.is_nil(S.GetMapName(1))
  end)
```

Créer `tests/lua/grail_guides_spec.lua` :

```lua
local H = dofile("tests/lua/helper.lua")

describe("GrailGuides", function()
  local ns, GS, amani, court

  before_each(function()
    ns = H.load()
    GS = ns.GrailSource
    amani = Sentier:NewGuide("amani", { title = "Amani", category = "R", faction = 2696, fromGrail = true })
    court = Sentier:NewGuide("court", { title = "Cour", category = "R", faction = 2710, fromGrail = true })
    Sentier:NewGuide("seul", { title = "Seul", category = "R", faction = 2699 })
  end)

  local function keys(list)
    local out = {}
    for _, t in ipairs(list) do out[#out + 1] = t.key end
    return out
  end

  it("ajoute à chaque guide les quêtes de sa faction, avec réputation, titre et position", function()
    GS.byFaction[2696] = { { questId = 1, rep = 250 } }
    GS.byFaction[2710] = { { questId = 2, rep = 75 } }
    GS.byFaction[2699] = { { questId = 3, rep = 50 } }
    GS.infos[1] = { title = "Q1", map = 2437, x = 10, y = 20, requires = {} }
    assert.are.equal(2, ns.GrailGuides:Fill())
    local t = amani.byId["1"]
    assert.are.same({ 250, "Q1", 2437, 10, 20, "none", true }, { t.rep, t.title, t.map, t.x, t.y, t.reset, t.fromGrail })
    assert.is_not_nil(court.byId["2"])
    assert.are.equal(0, #ns.Registry:Get("seul").tasks)
  end)

  it("met une quête qui récompense deux factions dans les deux guides", function()
    GS.byFaction[2696] = { { questId = 7, rep = 250 } }
    GS.byFaction[2710] = { { questId = 7, rep = 75 } }
    ns.GrailGuides:Fill()
    assert.are.equal(250, amani.byId["7"].rep)
    assert.are.equal(75, court.byId["7"].rep)
  end)

  it("laisse de côté les quêtes mondiales", function()
    GS.byFaction[2696] = { { questId = 3, rep = 100 } }
    GS.infos[3] = { worldQuest = true, requires = {} }
    assert.are.equal(0, ns.GrailGuides:Fill())
    assert.is_nil(amani.byId["3"])
  end)

  it("garde une quête déjà écrite à la main", function()
    amani:Quest(1, { title = "À la main", rep = 999 })
    GS.byFaction[2696] = { { questId = 1, rep = 250 } }
    assert.are.equal(0, ns.GrailGuides:Fill())
    assert.are.equal(999, amani.byId["1"].rep)
  end)

  it("ne remplit pas deux fois", function()
    GS.byFaction[2696] = { { questId = 1, rep = 250 } }
    ns.GrailGuides:Fill()
    assert.are.equal(0, ns.GrailGuides:Fill())
    assert.are.equal(1, #amani.tasks)
  end)

  it("remet à zéro chaque jour ou chaque semaine les quêtes répétables", function()
    GS.byFaction[2696] = { { questId = 4, rep = 10 }, { questId = 5, rep = 10 } }
    GS.infos[4] = { daily = true, requires = {} }
    GS.infos[5] = { weekly = true, requires = {} }
    ns.GrailGuides:Fill()
    assert.are.equal("daily", amani.byId["4"].reset)
    assert.are.equal("weekly", amani.byId["5"].reset)
  end)

  it("ajoute une quête dont Grail ne sait rien d'autre que la réputation", function()
    GS.byFaction[2696] = { { questId = 6, rep = 40 } }
    ns.GrailGuides:Fill()
    local t = amani.byId["6"]
    assert.are.same({ 40, "none" }, { t.rep, t.reset })
    assert.is_nil(t.title)
    assert.is_nil(t.map)
  end)

  it("bloque une quête tant que son prérequis n'est pas fait, avec le nom du prérequis", function()
    GS.byFaction[2696] = { { questId = 9, rep = 10 }, { questId = 10, rep = 10 } }
    GS.infos[9] = { requires = { 4 } }
    GS.infos[10] = { requires = { 5 } }
    GS.titles[4] = "Avant tout"
    ns.GrailGuides:Fill()
    assert.are.same({ { quest = 4, title = "Avant tout" } }, amani.byId["9"].requires)
    local status, info = ns.State:TaskStatus(amani, amani.byId["9"])
    assert.are.same({ "locked", "Quête requise : Avant tout" }, { status, info.reason })
    local _, info10 = ns.State:TaskStatus(amani, amani.byId["10"])
    assert.are.equal("Quête requise : Quête #5", info10.reason)
  end)

  it("place les quêtes de Grail après les tâches écrites à la main et avant les quêtes mondiales", function()
    amani:Weekly("w", { title = "W" })
    amani:WorldQuests({ zones = {} })
    amani:Order({ "w", "worldquests" })
    GS.byFaction[2696] = { { questId = 1, rep = 1 }, { questId = 2, rep = 1 } }
    ns.GrailGuides:Fill()
    assert.are.same({ "w", "1", "2", "worldquests" }, keys(amani.order))
  end)

  it("ajoute les quêtes à la fin de l'ordre quand le guide n'a pas de quêtes mondiales", function()
    amani:Weekly("w", { title = "W" })
    amani:Order({ "w" })
    GS.byFaction[2696] = { { questId = 1, rep = 1 } }
    ns.GrailGuides:Fill()
    assert.are.same({ "w", "1" }, keys(amani.order))
  end)

  it("range par zone, puis chaque quête après ses prérequis, et les quêtes sans zone à la fin", function()
    amani.zones = { "Zul’Aman", "Harandar" }
    ns.Sensors.mapNames[2437] = "Zul'Aman"
    ns.Sensors.mapNames[2413] = "Harandar"
    local tasks = {
      amani:Quest(10, { map = 2413 }),
      amani:Quest(11, { map = 2437, requires = { { quest = 13 } } }),
      amani:Quest(12, {}),
      amani:Quest(13, { map = 2437 }),
    }
    assert.are.same({ "13", "11", "10", "12" }, keys(ns.GrailGuides:Sort(amani, tasks)))
  end)

  it("range une zone inconnue du guide après les zones connues", function()
    amani.zones = { "Harandar" }
    ns.Sensors.mapNames[2413] = "Harandar"
    ns.Sensors.mapNames[2500] = "Ailleurs"
    local tasks = { amani:Quest(1, { map = 2500 }), amani:Quest(2, { map = 2413 }) }
    assert.are.same({ "2", "1" }, keys(ns.GrailGuides:Sort(amani, tasks)))
  end)

  it("ne boucle pas sur des prérequis croisés", function()
    local tasks = {
      amani:Quest(20, { requires = { { quest = 21 } } }),
      amani:Quest(21, { requires = { { quest = 20 } } }),
    }
    assert.are.same({ "20", "21" }, keys(ns.GrailGuides:Sort(amani, tasks)))
  end)

  it("complète plus tard les titres que Grail ne connaissait pas encore", function()
    GS.byFaction[2696] = { { questId = 1, rep = 1 } }
    GS.infos[1] = { requires = { 4 } }
    ns.GrailGuides:Fill()
    assert.is_nil(amani.byId["1"].title)
    GS.titles[1] = "Arrivé"
    GS.titles[4] = "Prérequis"
    ns.GrailGuides:RefreshTitles(amani)
    assert.are.equal("Arrivé", amani.byId["1"].title)
    assert.are.equal("Prérequis", amani.byId["1"].requires[1].title)
  end)

  it("ne fait rien sans erreur quand Grail ne répond pas", function()
    GS.broken = true
    assert.has_no.errors(function() assert.are.equal(0, ns.GrailGuides:Fill()) end)
    assert.are.equal(0, #amani.tasks)
  end)
end)
```

- [ ] **Step 3: Lancer les tests pour voir les échecs**

Run: `busted`
Expected: FAIL (`ns.GrailGuides` est nil, `GetMapName` n'existe pas, `fromGrail`/`zones` absents).

- [ ] **Step 4: Ajouter les options du guide et le nom de carte**

Dans `Sentier/Core/Registry.lua`, dans la table créée par `Registry:NewGuide`, ajouter après `faction = opts.faction,` :

```lua
    fromGrail = opts.fromGrail == true,
    zones = opts.zones or {},
```

Dans `Sentier/Sensors/Sensors.lua`, ajouter après `S.FindZoneMaps` :

```lua
function S.GetMapName(mapId)
  return safe("READ_MAPS", function()
    local info = C_Map.GetMapInfo(mapId)
    return info and info.name
  end)
end
```

- [ ] **Step 5: Écrire `Sentier/Core/GrailGuides.lua`**

```lua
local _, ns = ...

-- Remplit les guides « fromGrail » avec les quêtes que Grail connaît pour leur faction,
-- puis les range : par zone, chaque quête après ses prérequis, sinon par numéro.
local GrailGuides = { added = 0 }
ns.GrailGuides = GrailGuides

local function normName(name)
  return ((name or ""):gsub("’", "'")):lower()
end

local function requiresFrom(ids)
  local out = {}
  for _, id in ipairs(ids or {}) do
    out[#out + 1] = { quest = id, title = ns.GrailSource.QuestTitle(id) }
  end
  return out
end

-- Les quêtes de Grail passent après les tâches écrites à la main et avant les quêtes mondiales.
local function insertBeforeWorldQuests(guide, tasks)
  local at = #guide.order + 1
  for i, t in ipairs(guide.order) do
    if t.type == "worldquests" then
      at = i
      break
    end
  end
  for i, task in ipairs(tasks) do
    table.insert(guide.order, at + i - 1, task)
  end
end

function GrailGuides:Fill()
  local guides, factions = {}, {}
  for _, guide in ipairs(ns.Registry:List()) do
    if guide.fromGrail and guide.faction then
      guides[#guides + 1] = guide
      factions[#factions + 1] = guide.faction
    end
  end
  if #guides == 0 then return 0 end
  local byFaction = ns.GrailSource.QuestsByFaction(factions)
  if not byFaction then return 0 end

  local added = 0
  for _, guide in ipairs(guides) do
    local tasks = {}
    for _, q in ipairs(byFaction[guide.faction] or {}) do
      if not guide.byId[tostring(q.questId)] then
        local info = ns.GrailSource.QuestInfo(q.questId) or {}
        if not info.worldQuest then
          tasks[#tasks + 1] = guide:Quest(q.questId, {
            rep = q.rep,
            title = info.title,
            map = info.map, x = info.x, y = info.y,
            requires = requiresFrom(info.requires),
            reset = (info.daily and "daily") or (info.weekly and "weekly") or "none",
            fromGrail = true,
          })
        end
      end
    end
    insertBeforeWorldQuests(guide, self:Sort(guide, tasks))
    added = added + #tasks
  end
  self.added = self.added + added
  return added
end

function GrailGuides:Sort(guide, tasks)
  local zoneIndex = {}
  for i, name in ipairs(guide.zones) do zoneIndex[normName(name)] = i end
  local mapRank = {}
  local function rank(task)
    if not task.map then return math.huge end
    if not mapRank[task.map] then
      mapRank[task.map] = zoneIndex[normName(ns.Sensors.GetMapName(task.map))] or (#guide.zones + 1)
    end
    return mapRank[task.map]
  end
  local function before(a, b)
    local ra, rb = rank(a), rank(b)
    if ra ~= rb then return ra < rb end
    if (a.map or 0) ~= (b.map or 0) then return (a.map or 0) < (b.map or 0) end
    return a.id < b.id
  end

  local remaining = {}
  local present, placed, result = {}, {}, {}
  for _, t in ipairs(tasks) do
    remaining[#remaining + 1] = t
    present[t.id] = true
  end
  table.sort(remaining, before)

  -- On prend à chaque fois la première quête dont les prérequis présents sont déjà placés.
  -- Si aucune ne l'est (prérequis croisés), on prend la première pour ne pas boucler.
  while #remaining > 0 do
    local pick = 1
    for i, t in ipairs(remaining) do
      local ready = true
      for _, req in ipairs(t.requires) do
        if req.quest and present[req.quest] and not placed[req.quest] then
          ready = false
          break
        end
      end
      if ready then
        pick = i
        break
      end
    end
    local t = table.remove(remaining, pick)
    placed[t.id] = true
    result[#result + 1] = t
  end
  return result
end

-- Grail ne connaît le nom d'une quête qu'une fois que le jeu l'a chargé : on réessaie à chaque recalcul.
function GrailGuides:RefreshTitles(guide)
  for _, task in ipairs(guide.tasks) do
    if task.fromGrail then
      if not task.title then task.title = ns.GrailSource.QuestTitle(task.id) end
      for _, req in ipairs(task.requires) do
        if req.quest and not req.title then req.title = ns.GrailSource.QuestTitle(req.quest) end
      end
    end
  end
end
```

Dans `Sentier/Sentier.toc`, ajouter la ligne `Core\GrailGuides.lua` juste après `Core\Models.lua`.

- [ ] **Step 6: Lancer les tests**

Run: `busted`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sentier/Core/GrailGuides.lua Sentier/Core/Registry.lua Sentier/Sensors/Sensors.lua Sentier/Sentier.toc \
  tests/lua/helper.lua tests/lua/registry_spec.lua tests/lua/sensors_spec.lua tests/lua/grail_guides_spec.lua
git commit -m "Remplit et ordonne les guides avec les quêtes de Grail

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Brancher Grail au démarrage et déclarer la dépendance

**Files:**
- Modify: `Sentier/Core/Core.lua`
- Modify: `Sentier/Sentier.toc`
- Modify: `Sentier/Locales/fr.lua`
- Modify: les cinq guides `Sentier/Guides/Reputation/Midnight/{Amani,SilvermoonCourt,Harati,Singularity,ZuljarraForces}.lua`
- Test: `tests/lua/toc_spec.lua`, `tests/lua/guides_spec.lua`

**Interfaces:**
- Consumes: `ns.GrailSource.Available()`, `ns.GrailSource.Ready()` (tâche 3) ; `ns.GrailGuides:Fill()`, `ns.GrailGuides:RefreshTitles(guide)`, `ns.GrailGuides.added` (tâche 4) ; `ns.MidnightZones` (`Zones.lua`, déjà présent).
- Produces: `Core:WaitForGrail()`. Clés de texte `PROBLEM_NO_GRAIL`, `PROBLEM_GRAIL_NOT_READY`, `DEBUG_GRAIL`.

- [ ] **Step 1: Écrire les tests**

Dans `tests/lua/toc_spec.lua`, dans la liste du test « déclare l'interface 12.1, les sauvegardes et le bouton de la minicarte », ajouter `"## Dependencies: Grail",`.

Dans `tests/lua/guides_spec.lua`, ajouter avant le dernier `end)` :

```lua
  it("se remplissent avec Grail en suivant l'ordre des zones de Midnight", function()
    for _, g in ipairs(ns.Registry:List()) do
      assert.is_true(g.fromGrail, g.id)
      assert.are.equal(ns.MidnightZones, g.zones, g.id)
    end
  end)
```

- [ ] **Step 2: Lancer les tests pour voir les échecs**

Run: `busted tests/lua/toc_spec.lua tests/lua/guides_spec.lua`
Expected: FAIL (dépendance absente du `.toc`, guides sans `fromGrail`).

- [ ] **Step 3: Déclarer la dépendance et activer Grail dans les guides**

Dans `Sentier/Sentier.toc`, ajouter `## Dependencies: Grail` juste avant `## OptionalDeps: TomTom`.

Dans chacun des cinq guides, ajouter `fromGrail = true, zones = ns.MidnightZones,` dans les options de `Sentier:NewGuide`. Par exemple `Amani.lua` :

```lua
local G = Sentier:NewGuide("rep-midnight-amani", {
  title = "Tribu des Amani", category = "Réputation", faction = 2696,
  fromGrail = true, zones = ns.MidnightZones,
})
```

(`Zones.lua` est chargé avant les guides dans le `.toc`, donc `ns.MidnightZones` existe déjà.)

- [ ] **Step 4: Attendre Grail au démarrage**

Dans `Sentier/Locales/fr.lua`, ajouter après `PROBLEM_GRAIL` :

```lua
  PROBLEM_NO_GRAIL = "Grail n'est pas chargé : les guides n'ont que leurs tâches écrites à la main.",
  PROBLEM_GRAIL_NOT_READY = "Grail n'a pas fini de charger après 30 secondes.",
```

et après `DEBUG_NO_MAPS` :

```lua
  DEBUG_GRAIL = "Sentier : quêtes ajoutées depuis Grail : %d",
```

Dans `Sentier/Core/Core.lua`, ajouter après `Core:ScheduleReset` :

```lua
-- Grail finit de charger ses données pendant la connexion : on vérifie chaque seconde, 30 fois au plus.
function Core:WaitForGrail()
  if not ns.GrailSource.Available() then
    ns.Registry:Problem(L.PROBLEM_NO_GRAIL)
    return
  end
  local tries = 0
  local ticker
  ticker = C_Timer.NewTicker(1, function()
    tries = tries + 1
    if ns.GrailSource.Ready() then
      ticker:Cancel()
      ns.GrailGuides:Fill()
      self:RequestRefresh()
    elseif tries >= 30 then
      ticker:Cancel()
      ns.Registry:Problem(L.PROBLEM_GRAIL_NOT_READY)
    end
  end)
end
```

Dans `Core:Refresh`, remplacer :

```lua
  local result = ns.State:Evaluate(guide)
```

par :

```lua
  ns.GrailGuides:RefreshTitles(guide)
  local result = ns.State:Evaluate(guide)
```

Dans le gestionnaire `PLAYER_LOGIN`, ajouter `self:WaitForGrail()` juste après `self:ScheduleReset()`.

Dans `printDebug`, ajouter à la fin :

```lua
  print(L.DEBUG_GRAIL:format(ns.GrailGuides.added))
```

- [ ] **Step 5: Lancer les tests**

Run: `busted`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sentier/Core/Core.lua Sentier/Sentier.toc Sentier/Locales/fr.lua Sentier/Guides/Reputation/Midnight \
  tests/lua/toc_spec.lua tests/lua/guides_spec.lua
git commit -m "Remplit les guides de Midnight avec Grail à la connexion

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Barre de titre pour déplacer la fenêtre

**Files:**
- Modify: `Sentier/UI/MainFrame.lua`
- Modify: `Sentier/Locales/fr.lua`

**Interfaces:**
- Consumes: `ns.DB.account.locked`, `UI:OpenGuideMenu(owner)`, `ns.Settings:Toggle(anchor)`.
- Produces: `UI.title` devient une `FontString` (et non plus un bouton) : `UI:Render` appelle `self.title:SetText(...)`. Clé de texte `L.MENU_GUIDES`.

Pas de test automatique : l'interface n'est pas chargée par busted. La vérification est faite par `toc_spec` (compilation) et par le contrôle en jeu (tâche 9).

- [ ] **Step 1: Remplacer le titre et l'engrenage par une barre**

Dans `Sentier/Locales/fr.lua`, ajouter après `TAB_LIST` :

```lua
  MENU_GUIDES = "Changer de guide",
```

Dans `Sentier/UI/MainFrame.lua`, dans `UI:Create`, remplacer tout le bloc qui va de `local title = CreateFrame("Button", nil, f)` jusqu'à `gear:SetScript("OnClick", function() ns.Settings:Toggle(f) end)` inclus par :

```lua
  -- Barre de titre : toute sa largeur sert de poignée pour déplacer la fenêtre.
  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("TOPLEFT", 4, -4)
  bar:SetPoint("TOPRIGHT", -4, -4)
  bar:SetHeight(24)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() if not ns.DB.account.locked then f:StartMoving() end end)
  bar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
  bar.hover = bar:CreateTexture(nil, "BACKGROUND")
  bar.hover:SetAllPoints()
  bar.hover:SetColorTexture(1, 1, 1, 0.06)
  bar.hover:Hide()
  bar:SetScript("OnEnter", function() bar.hover:Show() end)
  bar:SetScript("OnLeave", function() bar.hover:Hide() end)

  local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", 6, 0)
  title:SetPoint("RIGHT", -52, 0)
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  self.title = title

  local gear = CreateFrame("Button", nil, bar)
  gear:SetSize(20, 20)
  gear:SetPoint("RIGHT", -2, 0)
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  gear:SetScript("OnClick", function() ns.Settings:Toggle(f) end)

  local menu = CreateFrame("Button", nil, bar)
  menu:SetSize(22, 22)
  menu:SetPoint("RIGHT", gear, "LEFT", -4, 0)
  menu:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
  menu:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
  menu:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight", "ADD")
  menu:SetScript("OnClick", function(btn) UI:OpenGuideMenu(btn) end)
  menu:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.MENU_GUIDES)
    GameTooltip:Show()
  end)
  menu:SetScript("OnLeave", function() GameTooltip:Hide() end)
```

Remplacer `b:SetPoint("TOPLEFT", 10 + (i - 1) * 74, -30)` (boutons des onglets) par `b:SetPoint("TOPLEFT", 10 + (i - 1) * 74, -32)`, et `body:SetPoint("TOPLEFT", 8, -54)` par `body:SetPoint("TOPLEFT", 8, -56)`.

Dans `UI:Render`, remplacer `self.title.text:SetText(result.guide.title)` par `self.title:SetText(result.guide.title)`.

- [ ] **Step 2: Lancer les tests**

Run: `busted`
Expected: PASS (`toc_spec` compile `MainFrame.lua`).

- [ ] **Step 3: Vérifier qu'il ne reste pas d'ancien appel**

Run: `grep -n "title.text" Sentier/UI/MainFrame.lua`
Expected: aucune ligne.

- [ ] **Step 4: Commit**

```bash
git add Sentier/UI/MainFrame.lua Sentier/Locales/fr.lua
git commit -m "Ajoute une barre de titre pour déplacer la fenêtre

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Retour visible sur les clics

**Files:**
- Modify: `Sentier/UI/MainFrame.lua`
- Modify: `Sentier/UI/StepTab.lua`
- Modify: `Sentier/UI/ListTab.lua`
- Modify: `Sentier/UI/Settings.lua`
- Modify: `Sentier/Locales/fr.lua`

**Interfaces:**
- Consumes: `UI.title`, la barre de la tâche 6 ; `ns.Navigation:SetTarget(map, x, y, title)`.
- Produces: `ns.UI:Click()` (son de clic), `ns.UI:Notify(text)` (son + message 3 secondes en bas de la fenêtre), `ns.UI:GoTo(target)` (pose le repère et confirme, ou dit qu'il n'y a pas de position). Clés `FEEDBACK_WAYPOINT`, `FEEDBACK_NO_POSITION`, `FEEDBACK_MARKED`, `FEEDBACK_UNMARKED`, `FEEDBACK_SKIPPED`, `FEEDBACK_SKIPS_CLEARED`.

Pas de test automatique (interface). Vérification en jeu (tâche 9).

- [ ] **Step 1: Ajouter les textes**

Dans `Sentier/Locales/fr.lua`, ajouter après `MANUAL_HINT` :

```lua
  FEEDBACK_WAYPOINT = "Repère posé : %s",
  FEEDBACK_NO_POSITION = "Pas de position pour cette tâche",
  FEEDBACK_MARKED = "Tâche cochée",
  FEEDBACK_UNMARKED = "Tâche décochée",
  FEEDBACK_SKIPPED = "Étape passée",
  FEEDBACK_SKIPS_CLEARED = "Étapes passées remises",
```

- [ ] **Step 2: Ligne de message et fonctions communes**

Dans `Sentier/UI/MainFrame.lua`, dans `UI:Create`, remplacer `body:SetPoint("BOTTOMRIGHT", -8, 8)` par `body:SetPoint("BOTTOMRIGHT", -8, 24)`, puis ajouter juste avant `local grip = CreateFrame("Button", nil, f)` :

```lua
  local message = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  message:SetPoint("BOTTOMLEFT", 10, 8)
  message:SetPoint("BOTTOMRIGHT", -20, 8)
  message:SetJustifyH("LEFT")
  message:SetTextColor(0.94, 0.78, 0.37)
  self.message = message
```

Dans la même fonction, ajouter `UI:Click()` au début des gestionnaires `OnClick` de l'engrenage (`function() UI:Click(); ns.Settings:Toggle(f) end`), de la flèche du menu (`function(btn) UI:Click(); UI:OpenGuideMenu(btn) end`) et des boutons d'onglet (`function() UI:Click(); UI:SetTab(key) end`).

Ajouter à la fin du fichier, avant `function Sentier_OnAddonCompartmentClick()` :

```lua
-- Son de clic du jeu. Protégé : les noms de sons changent parfois d'une version à l'autre.
function UI:Click()
  if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
    pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  end
end

-- Confirme une action : son de clic, puis message en bas de la fenêtre pendant 3 secondes.
function UI:Notify(text)
  self:Click()
  if not self.message then return end
  self.message:SetText(text)
  if self.messageTimer then self.messageTimer:Cancel() end
  self.messageTimer = C_Timer.NewTimer(3, function() self.message:SetText("") end)
end

function UI:GoTo(target)
  if target then
    ns.Navigation:SetTarget(target.map, target.x, target.y, target.title)
    self:Notify(L.FEEDBACK_WAYPOINT:format(target.title))
  else
    self:Notify(L.FEEDBACK_NO_POSITION)
  end
end
```

- [ ] **Step 3: Onglet Étape**

Dans `Sentier/UI/StepTab.lua`, remplacer le gestionnaire :

```lua
  step:SetScript("OnClick", function()
    local target = p.model and p.model.target
    if target then ns.Navigation:SetTarget(target.map, target.x, target.y, target.title) end
  end)
```

par :

```lua
  local highlight = step:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 0.08)
  step:SetScript("OnMouseDown", function() step.bg:SetColorTexture(0.07, 0.065, 0.05) end)
  step:SetScript("OnMouseUp", function() step.bg:SetColorTexture(0.12, 0.11, 0.08) end)
  step:SetScript("OnClick", function()
    if p.model and p.model.entry then ns.UI:GoTo(p.model.target) end
  end)
```

Remplacer les trois boutons par :

```lua
  p.prev = button(L.BTN_PREV, 28, 2, function()
    ns.UI:Click()
    ns.UI.viewIndex = math.max(1, ns.UI.viewIndex - 1)
    ns.UI:Render(ns.Core.result)
  end)
  p.skip = button(L.BTN_SKIP, 70, 34, function()
    if p.model and p.model.entry then
      ns.DB:SetSkipped(ns.Core.result.guide, p.model.entry.task, true)
      ns.UI:Notify(L.FEEDBACK_SKIPPED)
      ns.Core:Refresh()
    end
  end)
  p.next = button(L.BTN_NEXT, 28, 108, function()
    ns.UI:Click()
    ns.UI.viewIndex = ns.UI.viewIndex + 1
    ns.UI:Render(ns.Core.result)
  end)
```

- [ ] **Step 4: Onglet Liste**

Dans `Sentier/UI/ListTab.lua`, remplacer la fonction locale `onClick` par :

```lua
  local function onClick(row, button)
    local data = row.data
    if not data or data.kind == "header" then return end
    if button == "RightButton" and data.kind == "task" then
      local guide = ns.Core.result.guide
      local task = data.entry.task
      local marked = not ns.DB:IsMarked(guide, task)
      ns.DB:SetMarked(guide, task, marked)
      ns.UI:Notify(marked and L.FEEDBACK_MARKED or L.FEEDBACK_UNMARKED)
      ns.Core:Refresh()
    else
      ns.UI:GoTo(data.target)
    end
  end
```

Dans `getRow`, ajouter juste avant `row:SetScript("OnClick", onClick)` :

```lua
    row.pressed = row:CreateTexture(nil, "BACKGROUND")
    row.pressed:SetAllPoints()
    row.pressed:SetColorTexture(1, 1, 1, 0.12)
    row.pressed:Hide()
    row:SetScript("OnMouseDown", function(self) self.pressed:Show() end)
    row:SetScript("OnMouseUp", function(self) self.pressed:Hide() end)
```

Dans `p:Render`, juste après `row.data = data`, ajouter :

```lua
      -- Les titres de groupe ne sont pas cliquables : pas de surbrillance ni d'enfoncement.
      row:EnableMouse(data.kind ~= "header")
```

Dans la case « Afficher les quêtes faites » (tâche 2), ajouter `ns.UI:Click()` en première ligne de son `OnClick`.

- [ ] **Step 5: Réglages**

Dans `Sentier/UI/Settings.lua`, dans la fonction locale `checkbox`, ajouter `ns.UI:Click()` en première ligne du `OnClick`. Dans le `OnClick` du bouton de navigation, ajouter `ns.UI:Click()` en première ligne. Remplacer le `OnClick` du bouton « Remettre les étapes passées » par :

```lua
  clear:SetScript("OnClick", function()
    local guide = ns.Core.result and ns.Core.result.guide
    if guide then
      ns.DB:ClearSkips(guide)
      ns.UI:Notify(L.FEEDBACK_SKIPS_CLEARED)
      ns.Core:Refresh()
    end
  end)
```

- [ ] **Step 6: Lancer les tests**

Run: `busted`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sentier/UI Sentier/Locales/fr.lua
git commit -m "Ajoute un retour visible et sonore sur les clics de la fenêtre

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Icône sur la minicarte

**Files:**
- Create: `Sentier/UI/MinimapButton.lua`
- Modify: `Sentier/Sentier.toc` (ajouter `UI\MinimapButton.lua` juste après `UI\Settings.lua`)
- Modify: `Sentier/UI/Settings.lua`
- Modify: `Sentier/Core/Core.lua`
- Modify: `Sentier/Locales/fr.lua`
- Test: `tests/lua/minimap_spec.lua`

**Interfaces:**
- Consumes: `ns.DB.account.minimap = { angle, hidden }` (tâche 2) ; `ns.UI:Click()` (tâche 7) ; `ns.UI:Toggle()`, `ns.UI:Create()`, `ns.Settings:Toggle(anchor)`.
- Produces: `ns.MinimapButton` avec `MinimapButton.AngleFrom(cx, cy, x, y) -> number` (degrés, 0 ≤ angle < 360), `MinimapButton.Offset(angle, radius) -> x, y`, `MinimapButton:Create()`, `MinimapButton:Place()`, `MinimapButton:Refresh()`.

- [ ] **Step 1: Écrire les tests des calculs d'angle**

Créer `tests/lua/minimap_spec.lua` :

```lua
local H = dofile("tests/lua/helper.lua")

describe("MinimapButton", function()
  local M

  before_each(function()
    local ns = H.load()
    assert(loadfile("Sentier/UI/MinimapButton.lua"))("Sentier", ns)
    M = ns.MinimapButton
  end)

  local function near(a, b) return math.abs(a - b) < 1e-6 end

  it("donne l'angle du curseur vu depuis le centre de la minicarte", function()
    assert.is_true(near(0, M.AngleFrom(100, 100, 150, 100)))
    assert.is_true(near(90, M.AngleFrom(100, 100, 100, 150)))
    assert.is_true(near(180, M.AngleFrom(100, 100, 50, 100)))
  end)

  it("ne donne jamais d'angle négatif sous le centre", function()
    assert.is_true(near(270, M.AngleFrom(100, 100, 100, 50)))
    assert.is_true(near(315, M.AngleFrom(0, 0, 1, -1)))
  end)

  it("place le bouton sur le cercle à partir de l'angle", function()
    local x, y = M.Offset(0, 80)
    assert.is_true(near(80, x) and near(0, y))
    x, y = M.Offset(90, 80)
    assert.is_true(near(0, x) and near(80, y))
  end)

  it("retrouve l'angle d'une position calculée", function()
    local x, y = M.Offset(225, 80)
    assert.is_true(near(225, M.AngleFrom(0, 0, x, y)))
  end)
end)
```

- [ ] **Step 2: Lancer les tests pour voir les échecs**

Run: `busted tests/lua/minimap_spec.lua`
Expected: FAIL (fichier introuvable).

- [ ] **Step 3: Écrire `Sentier/UI/MinimapButton.lua`**

```lua
local _, ns = ...
local L = ns.L

-- Bouton rond au bord de la minicarte : clic gauche ouvre ou ferme le guide, clic droit les réglages.
-- On le fait glisser autour de la minicarte ; son angle est gardé dans SentierDB.minimap.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

-- WoW est en Lua 5.1 (math.atan2) ; les tests tournent en Lua 5.3 ou plus (math.atan à deux arguments).
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

function MinimapButton.AngleFrom(cx, cy, x, y)
  return math.deg(atan2(y - cy, x - cx)) % 360
end

function MinimapButton.Offset(angle, radius)
  local rad = math.rad(angle)
  return math.cos(rad) * radius, math.sin(rad) * radius
end

function MinimapButton:Place()
  if not self.button then return end
  local x, y = MinimapButton.Offset(ns.DB.account.minimap.angle, Minimap:GetWidth() / 2 + 10)
  self.button:ClearAllPoints()
  self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:Refresh()
  if self.button then self.button:SetShown(not ns.DB.account.minimap.hidden) end
end

function MinimapButton:Create()
  if self.button or not Minimap then return self.button end
  local b = CreateFrame("Button", "SentierMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  icon:SetPoint("TOPLEFT", 7, -6)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  b:SetScript("OnMouseDown", function() icon:SetVertexColor(0.6, 0.6, 0.6) end)
  b:SetScript("OnMouseUp", function() icon:SetVertexColor(1, 1, 1) end)
  b:SetScript("OnClick", function(_, button)
    ns.UI:Click()
    if button == "RightButton" then
      local f = ns.UI:Create()
      f:Show()
      ns.DB.char.hidden = false
      ns.Settings:Toggle(f)
    else
      ns.UI:Toggle()
    end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(L.ADDON_NAME)
    GameTooltip:AddLine(L.MINIMAP_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_RIGHT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_DRAG, 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      ns.DB.account.minimap.angle = MinimapButton.AngleFrom(mx, my, cx / scale, cy / scale)
      MinimapButton:Place()
    end)
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    icon:SetVertexColor(1, 1, 1)
  end)

  self.button = b
  self:Place()
  self:Refresh()
  return b
end
```

- [ ] **Step 4: Textes, réglage et démarrage**

Dans `Sentier/Locales/fr.lua`, ajouter en tête de la table (avant `TAB_STEP`) :

```lua
  ADDON_NAME = "Sentier",
  MINIMAP_LEFT = "Clic gauche : ouvrir ou fermer le guide",
  MINIMAP_RIGHT = "Clic droit : réglages",
  MINIMAP_DRAG = "Glisser : déplacer l'icône",
```

et après `SETTINGS_LOCK` :

```lua
  SETTINGS_MINIMAP = "Afficher l'icône sur la minicarte",
```

Dans `Sentier/UI/Settings.lua`, remplacer `f:SetSize(240, 300)` par `f:SetSize(240, 324)`, puis ajouter juste après la ligne de la case `SETTINGS_LOCK` (et avant `y = y - 30`) :

```lua
  y = y - 22
  checkbox(f, L.SETTINGS_MINIMAP, y, function() return not ns.DB.account.minimap.hidden end, function(v)
    ns.DB.account.minimap.hidden = not v
    ns.MinimapButton:Refresh()
  end)
```

Dans `Sentier/Core/Core.lua`, dans le gestionnaire `PLAYER_LOGIN`, ajouter `ns.MinimapButton:Create()` juste après `if ns.DB.char.hidden then ns.UI.frame:Hide() end`.

Dans `Sentier/Sentier.toc`, ajouter `UI\MinimapButton.lua` juste après `UI\Settings.lua`.

- [ ] **Step 5: Lancer les tests**

Run: `busted`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sentier/UI/MinimapButton.lua Sentier/UI/Settings.lua Sentier/Core/Core.lua Sentier/Sentier.toc \
  Sentier/Locales/fr.lua tests/lua/minimap_spec.lua
git commit -m "Ajoute l'icône de Sentier sur la minicarte

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Documentation et contrôle en jeu

**Files:**
- Modify: `README.md`
- Modify: `docs/contenu.md`
- Modify: `docs/controle-en-jeu.md`
- Modify: `docs/suivi/DETTE.md`

**Interfaces:**
- Consumes: le comportement final des tâches 1 à 8.
- Produces: documentation à jour.

- [ ] **Step 1: README**

Dans `README.md` :
- remplacer la section « Installation pour jouer » par :

```markdown
## Installation pour jouer

Sentier a besoin de l'addon **Grail** (base de données des quêtes) : l'installer depuis CurseForge (https://www.curseforge.com/wow/addons/grail) ou depuis https://github.com/smaitch/Grail (copier les dossiers `Grail` et `Grail-Reputations` dans `AddOns`).

Décompresser ensuite `Sentier-<version>.zip` dans `World of Warcraft/_retail_/Interface/AddOns/`. En jeu : `/sentier`, l'icône de Sentier sur la minicarte, ou le bouton des addons près de la minicarte.

Si Grail est indiqué « périmé » dans la liste des addons, cocher « Charger les addons périmés ».
```

- dans « Développement », remplacer la ligne des outils par : `Outils : `brew install lua luarocks && luarocks install busted`.`
- dans « Tests », supprimer la ligne `.venv/bin/pytest tests/python`.
- remplacer toute la section « Outils » par :

```markdown
## Outils

- `tools/package.sh` : crée l'archive à partager.
```

- dans « Commandes en jeu », remplacer la ligne par : `` `/sentier` (afficher ou masquer), `/sentier debug` (problèmes détectés, cartes trouvées et nombre de quêtes venues de Grail). ``

- [ ] **Step 2: Guide d'ajout de contenu**

Remplacer tout le contenu de `docs/contenu.md` par :

````markdown
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
````

- [ ] **Step 3: Contrôle en jeu**

Dans `docs/controle-en-jeu.md` :
- ajouter en tête de liste : `- [ ] Grail est installé et chargé (liste des addons) ; s'il est « périmé », la case « Charger les addons périmés » est cochée.`
- remplacer la ligne « La fenêtre s'ouvre avec `/sentier` et avec le bouton des addons… » par : `- [ ] La fenêtre s'ouvre avec `/sentier`, avec l'icône de la minicarte et avec le bouton des addons ; elle se déplace en la prenant par toute la barre de titre, se redimensionne, se verrouille, et garde sa place après `/reload`.`
- remplacer « Le menu du titre liste les cinq guides… » par : `- [ ] La flèche à droite du titre ouvre le menu des cinq guides sous « Réputation » et change de guide ; cliquer ou glisser le titre ne l'ouvre pas.`
- remplacer les deux lignes « Une minute après la connexion, `/sentier debug` indique plus de 0 « nouvelles avec du renom »… » et « Sans rien taper, ouvrir une quête de Midnight… » par :

```markdown
- [ ] Quelques secondes après la connexion, `/sentier debug` indique plus de 0 « quêtes ajoutées depuis Grail », et le groupe « Quêtes secondaires » des guides Amani, Singularité, Hara'ti et Cour de Lune-d'Argent est rempli.
- [ ] Les quêtes de Grail ont un nom en français (sinon « Quête #<numéro> » qui se corrige après quelques secondes), une réputation, et un clic pose le repère au bon endroit.
- [ ] Une quête dont le prérequis n'est pas fait est grisée avec « Quête requise : <nom> ».
- [ ] Les quêtes déjà faites sont cachées ; la case « Afficher les quêtes faites » en haut de la liste les montre et les cache.
- [ ] Chaque clic (étape, ligne de liste, boutons, cases, réglages) fait le son de clic ; poser un repère, cocher, décocher et passer une étape affichent un message en bas de la fenêtre pendant 3 secondes ; une tâche sans position affiche « Pas de position pour cette tâche ».
- [ ] Icône de la minicarte : clic gauche ouvre et ferme, clic droit ouvre les réglages, la bulle d'aide s'affiche, on la fait glisser autour de la minicarte et elle garde sa place après `/reload` ; la case des réglages la cache et la remontre.
```

- [ ] **Step 4: Dette**

Dans `docs/suivi/DETTE.md`, remplacer la section « Renom des quêtes non ouvertes (2026-10-13) » par :

```markdown
## Couverture de Grail (2026-10-14)

Grail 127 vise l'interface 12.0.7 : il ne connaît aucune quête des Forces de Zul'jarra et peut manquer des quêtes ajoutées en 12.1. Le guide des Forces de Zul'jarra garde ses hebdomadaires écrites à la main. À revoir à chaque mise à jour de Grail.
```

- [ ] **Step 5: Vérifier**

Run: `grep -rn "collect\|import_collect\|build_catalog\|pytest\|Catalog" README.md docs/contenu.md docs/controle-en-jeu.md docs/suivi/DETTE.md`
Expected: aucune ligne.

Run: `busted`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/contenu.md docs/controle-en-jeu.md docs/suivi/DETTE.md
git commit -m "Met à jour la documentation pour les guides remplis par Grail

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```
