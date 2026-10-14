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
