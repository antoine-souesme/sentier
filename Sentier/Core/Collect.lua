local _, ns = ...

-- Mode collecte : note la réputation annoncée par les quêtes, pour remplir les guides.
local Collect = {}
ns.Collect = Collect

function Collect:SetEnabled(on)
  ns.DB.account.collect.enabled = on and true or false
end

function Collect:TrackedFactions()
  local set = {}
  for _, guide in ipairs(ns.Registry:List()) do
    if guide.faction then set[guide.faction] = true end
  end
  return set
end

function Collect:Record(questId, rewards, extra)
  if not ns.DB.account.collect.enabled then return false end
  return self:Store(questId, rewards, extra)
end

-- Garde la réputation d'une quête, sans tenir compte du réglage de collecte.
-- extra.noPosition : ne pas noter la position du joueur (quête lue à distance).
function Collect:Store(questId, rewards, extra)
  local store = ns.DB.account.collect
  if not questId or type(rewards) ~= "table" then return false end

  local tracked = self:TrackedFactions()
  local kept = {}
  for _, r in ipairs(rewards) do
    if type(r) == "table" and tracked[r.factionId] and (r.amount or 0) > 0 then
      kept[#kept + 1] = { factionId = r.factionId, amount = r.amount }
    end
  end
  if #kept == 0 then return false end

  extra = extra or {}
  local pos = (extra.map and extra) or (not extra.noPosition and ns.Sensors.GetPlayerPosition()) or {}
  store.quests[questId] = {
    title = extra.title,
    worldQuest = extra.worldQuest == true,
    rewards = kept,
    map = pos.map,
    x = pos.x,
    y = pos.y,
    seen = ns.Sensors.Now(),
  }
  if not store.quests[questId].worldQuest then self:ApplyToGuides() end
  return true
end

-- Place une tâche avant les quêtes mondiales dans l'ordre du guide, sinon à la fin.
local function insertInOrder(guide, task)
  for i, t in ipairs(guide.order) do
    if t.type == "worldquests" then
      table.insert(guide.order, i, task)
      return
    end
  end
  guide.order[#guide.order + 1] = task
end

-- Ajoute aux guides les quêtes collectées qu'ils ne déclarent pas encore.
function Collect:ApplyToGuides()
  local byFaction = {}
  for _, guide in ipairs(ns.Registry:List()) do
    if guide.faction then
      byFaction[guide.faction] = byFaction[guide.faction] or {}
      table.insert(byFaction[guide.faction], guide)
    end
  end
  for questId, q in pairs(ns.DB.account.collect.quests) do
    if type(q) == "table" and not q.worldQuest and type(q.rewards) == "table" then
      for _, r in ipairs(q.rewards) do
        for _, guide in ipairs(type(r) == "table" and byFaction[r.factionId] or {}) do
          if not guide.byId[tostring(questId)] then
            local task = guide:Quest(questId, { rep = r.amount, title = q.title, map = q.map, x = q.x, y = q.y })
            insertInOrder(guide, task)
          end
        end
      end
    end
  end
end
