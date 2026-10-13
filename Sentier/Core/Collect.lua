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
  local store = ns.DB.account.collect
  if not store.enabled or not questId or not rewards then return false end

  local tracked = self:TrackedFactions()
  local kept = {}
  for _, r in ipairs(rewards) do
    if tracked[r.factionId] and (r.amount or 0) > 0 then
      kept[#kept + 1] = { factionId = r.factionId, amount = r.amount }
    end
  end
  if #kept == 0 then return false end

  extra = extra or {}
  local pos = (extra.map and extra) or ns.Sensors.GetPlayerPosition() or {}
  store.quests[questId] = {
    title = extra.title,
    worldQuest = extra.worldQuest == true,
    rewards = kept,
    map = pos.map,
    x = pos.x,
    y = pos.y,
    seen = ns.Sensors.Now(),
  }
  return true
end
