-- Charge les fichiers de l'addon hors du jeu, comme WoW le fait : chaque fichier reçoit (nom, ns).
local H = {}

H.FILES = {
  "Sentier/Locales/fr.lua",
  "Sentier/Core/Registry.lua",
  "Sentier/Core/Reset.lua",
  "Sentier/Core/DB.lua",
  "Sentier/Core/State.lua",
  "Sentier/Core/Models.lua",
  "Sentier/Core/Collect.lua",
  "Sentier/Navigation/Navigation.lua",
}

local function exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

-- Capteurs simulés : les tests modifient directement les champs (done, renown, now...).
function H.fakeSensors()
  local f = {
    now = 1000000,
    weeklyStart = 900000,
    dailyUntil = 3600,
    done = {},
    renown = {},
    worldQuests = {},
    objectives = {},
    position = nil,
  }
  f.Now = function() return f.now end
  f.IsQuestDone = function(id)
    local v = f.done[id]
    if v == "error" then return nil end
    return v == true
  end
  f.GetRenown = function(faction) return f.renown[faction] end
  f.GetActiveWorldQuests = function(faction) return f.worldQuests[faction] end
  f.FindZoneMaps = function() return {} end
  f.GetWeeklyResetStart = function() return f.weeklyStart end
  f.GetSecondsUntilDailyReset = function() return f.dailyUntil end
  f.GetObjectiveProgress = function(questId) return f.objectives[questId] end
  f.GetPlayerPosition = function() return f.position end
  return f
end

function H.load(saved)
  saved = saved or {}
  _G.Sentier = nil
  _G.SentierDB = saved.account
  _G.SentierCharDB = saved.char
  local ns = {}
  for _, path in ipairs(H.FILES) do
    if exists(path) then assert(loadfile(path))("Sentier", ns) end
  end
  ns.Sensors = H.fakeSensors()
  if ns.DB then ns.DB:Init() end
  return ns
end

function H.hasProblem(ns, needle)
  for _, p in ipairs(ns.Registry.problems) do
    if p:find(needle, 1, true) then return true end
  end
  return false
end

return H
