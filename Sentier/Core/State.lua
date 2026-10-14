local _, ns = ...
local L = ns.L

local State = {}
ns.State = State

-- true si toutes les quêtes sont faites, false si l'une ne l'est pas, nil si l'une est illisible.
local function allDone(questIds)
  for _, id in ipairs(questIds) do
    local done = ns.Sensors.IsQuestDone(id)
    if done == nil then return nil end
    if not done then return false end
  end
  return true
end

-- nil si les prérequis sont remplis, sinon le statut ("locked" ou "unknown") et la raison.
local function checkRequires(task)
  for _, req in ipairs(task.requires) do
    if req.renown then
      local renown = task.factions[1] and ns.Sensors.GetRenown(task.factions[1])
      if not renown then return "unknown" end
      if renown.level < req.renown then return "locked", L.REQUIRES_RENOWN:format(req.renown) end
    elseif req.quest then
      local done = ns.Sensors.IsQuestDone(req.quest)
      if done == nil then return "unknown" end
      if not done then return "locked", L.REQUIRES_QUEST:format(req.title or L.UNKNOWN_QUEST:format(req.quest)) end
    end
  end
  return nil
end

function State:TaskStatus(guide, task)
  local info = {}

  if task.type == "worldquests" then
    local maps = ns.Sensors.FindZoneMaps(task.zones or {})
    if maps and #maps == 0 then
      ns.Registry:Problem(L.PROBLEM_NO_ZONE_MAPS:format(guide.id))
      return "unknown", info
    end
    local list = maps and ns.Sensors.GetActiveWorldQuests(task.factions[1], maps)
    if not list then return "unknown", info end
    info.worldQuests = list
    return (#list > 0) and "todo" or "done", info
  end

  if task.progress then
    info.progress = ns.Sensors.GetObjectiveProgress(task.progress.questId, task.progress.objective)
  end

  local done = false
  if task.questIds and #task.questIds > 0 then done = allDone(task.questIds) end
  -- Une quête unique faite par un autre personnage du compte ne donne plus de réputation.
  if done ~= true and task.type == "quest" and task.reset == "none" and ns.Sensors.IsQuestDoneOnAccount(task.id) then
    done = true
  end
  if done == true or ns.DB:IsMarked(guide, task) then return "done", info end

  local status, reason = checkRequires(task)
  if status then
    info.reason = reason
    return status, info
  end

  if done == nil then return "unknown", info end
  return "todo", info
end

function State:Evaluate(guide)
  ns.DB:Prune(guide)
  local sources = ns.DB.account.sources
  local result = { guide = guide, entries = {}, byKey = {}, steps = {} }

  for _, task in ipairs(guide.tasks) do
    local status, info = self:TaskStatus(guide, task)
    local entry = {
      task = task,
      status = status,
      info = info,
      enabled = sources[task.source] ~= false,
      skipped = ns.DB:IsSkipped(guide, task),
    }
    result.entries[#result.entries + 1] = entry
    result.byKey[task.key] = entry
  end

  for _, task in ipairs(guide.order) do
    local entry = result.byKey[task.key]
    if entry.enabled and entry.status == "todo" and not entry.skipped then
      result.steps[#result.steps + 1] = entry
    end
  end

  if guide.faction then result.renown = ns.Sensors.GetRenown(guide.faction) end
  return result
end
