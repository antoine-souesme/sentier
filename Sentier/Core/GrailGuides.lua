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
