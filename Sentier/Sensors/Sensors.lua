local _, ns = ...
local L = ns.L

-- Seul fichier qui lit les quêtes, la réputation et les resets dans le jeu.
-- Chaque lecture est protégée : en cas d'erreur, elle renvoie nil et note un problème.
local S = {}
ns.Sensors = S

local function safe(label, fn, ...)
  local ok, result, extra = pcall(fn, ...)
  if ok then return result, extra end
  ns.Registry:Problem(L.PROBLEM_READ:format(L[label], tostring(result)))
  return nil
end

local function normalize(rewards)
  local out = {}
  for _, r in ipairs(rewards or {}) do
    if r.factionID and r.rewardAmount then out[#out + 1] = { factionId = r.factionID, amount = r.rewardAmount } end
  end
  return out
end

-- Heure du serveur quand le jeu la donne : les resets sont calés sur elle.
function S.Now()
  if type(GetServerTime) == "function" then
    local ok, now = pcall(GetServerTime)
    if ok and type(now) == "number" then return now end
  end
  return time()
end

function S.IsQuestDone(questId)
  return safe("READ_QUEST", function() return C_QuestLog.IsQuestFlaggedCompleted(questId) == true end)
end

function S.GetObjectiveProgress(questId, index)
  return safe("READ_OBJECTIVE", function()
    local objectives = C_QuestLog.GetQuestObjectives(questId)
    local o = objectives and objectives[index or 1]
    if not o or not o.numRequired or o.numRequired == 0 then return nil end
    return { have = o.numFulfilled or 0, need = o.numRequired }
  end)
end

function S.GetRenown(factionId)
  return safe("READ_RENOWN", function()
    local d = C_MajorFactions.GetMajorFactionData(factionId)
    if not d then return nil end
    return { level = d.renownLevel or 0, earned = d.renownReputationEarned or 0, threshold = d.renownLevelThreshold or 0, name = d.name }
  end)
end

-- Quêtes dont les récompenses ont déjà été demandées pendant la session :
-- on ne les redemande pas, sinon chaque réponse relancerait un recalcul puis une demande.
local preloadRequested = {}

function S.GetActiveWorldQuests(factionId, mapIds)
  return safe("READ_WORLD_QUESTS", function()
    local getQuests = C_TaskQuest.GetQuestsOnMap or C_TaskQuest.GetQuestsForPlayerByMapID
    local list, seen = {}, {}
    for _, mapId in ipairs(mapIds) do
      for _, q in ipairs(getQuests(mapId) or {}) do
        local id = q.questID or q.questId
        if id and not seen[id] and C_QuestLog.IsWorldQuest(id) then
          seen[id] = true
          local amount = 0
          for _, r in ipairs(normalize(C_QuestLog.GetQuestLogMajorFactionReputationRewards(id))) do
            if r.factionId == factionId then amount = r.amount end
          end
          if amount > 0 then
            list[#list + 1] = {
              questId = id,
              title = C_TaskQuest.GetQuestInfoByQuestID(id) or L.UNKNOWN_QUEST:format(id),
              rep = amount,
              map = q.mapID or mapId,
              x = q.x and q.x * 100,
              y = q.y and q.y * 100,
            }
          elseif not preloadRequested[id] and not HaveQuestRewardData(id) then
            preloadRequested[id] = true
            C_TaskQuest.RequestPreloadRewardData(id)
          end
        end
      end
    end
    table.sort(list, function(a, b)
      if a.rep ~= b.rep then return a.rep > b.rep end
      return a.questId < b.questId
    end)
    return list
  end)
end

local function normName(name)
  return ((name or ""):gsub("’", "'")):lower()
end

local mapCache = {}

-- Les numéros de carte de Midnight ne sont pas documentés : on les retrouve par leur nom.
function S.FindZoneMaps(names)
  local cacheKey = table.concat(names, "|")
  if mapCache[cacheKey] then return mapCache[cacheKey] end
  local found = safe("READ_MAPS", function()
    local wanted = {}
    for _, n in ipairs(names) do wanted[normName(n)] = true end
    local list = {}
    for id = 2300, 2700 do
      local info = C_Map.GetMapInfo(id)
      if info and wanted[normName(info.name)] then list[#list + 1] = id end
    end
    return list
  end)
  -- Une liste vide n'est pas gardée : les cartes peuvent ne pas être prêtes juste après la connexion.
  if found and #found > 0 then mapCache[cacheKey] = found end
  return found
end

function S.GetWeeklyResetStart()
  return safe("READ_WEEKLY_RESET", function() return C_DateAndTime.GetWeeklyResetStartTime() end)
end

function S.GetSecondsUntilDailyReset()
  return safe("READ_DAILY_RESET", function() return C_DateAndTime.GetSecondsUntilDailyReset() end)
end
