local addonName, ns = ...
local L = ns.L

local Core = CreateFrame("Frame")
ns.Core = Core

local REFRESH_EVENTS = {
  "QUEST_TURNED_IN",
  "QUEST_LOG_UPDATE",
  "QUEST_ACCEPTED",
  "QUEST_REMOVED",
  "UPDATE_FACTION",
  "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
  "MAJOR_FACTION_UNLOCKED",
  "QUEST_DATA_LOAD_RESULT",
  "ZONE_CHANGED_NEW_AREA",
}

function Core:CurrentGuide()
  local guide = ns.Registry:Resolve(ns.DB.char.guide)
  if guide then ns.DB.char.guide = guide.id end
  return guide
end

function Core:SetGuide(id)
  ns.DB.char.guide = id
  ns.DB:SetStep(nil)
  ns.Navigation:Clear()
  self:Refresh()
end

function Core:CollectWorldQuests(result)
  if not ns.DB.account.collect.enabled or not result.guide.faction then return end
  for _, entry in ipairs(result.entries) do
    for _, wq in ipairs(entry.info.worldQuests or {}) do
      ns.Collect:Record(wq.questId, { { factionId = result.guide.faction, amount = wq.rep } },
        { title = wq.title, worldQuest = true, map = wq.map, x = wq.x, y = wq.y })
    end
  end
end

function Core:Refresh()
  local guide = self:CurrentGuide()
  if not guide then return end
  local result = ns.State:Evaluate(guide)
  self.result = result
  self:CollectWorldQuests(result)

  -- Quand l'étape en cours change, on revient dessus et on déplace le repère.
  -- La clé est gardée par personnage ; on replace aussi le repère quand rien n'est
  -- ciblé dans cette session (après connexion ou /reload, TomTom ne garde pas le sien).
  local current = result.steps[1]
  local key = current and (guide.id .. ":" .. current.task.key)
  local changed = key ~= ns.DB:GetStep()
  if changed or not ns.Navigation.target then
    if changed then
      ns.DB:SetStep(key)
      ns.UI.viewIndex = 1
    end
    local target = current and ns.Models.Target(current)
    if target then
      ns.Navigation:SetTarget(target.map, target.x, target.y, target.title)
    else
      ns.Navigation:Clear()
    end
  end

  ns.UI:Render(result)
end

-- Regroupe les événements rapprochés en un seul recalcul.
function Core:RequestRefresh()
  if self.pending then return end
  self.pending = true
  C_Timer.After(0.5, function()
    self.pending = false
    self:Refresh()
  end)
end

function Core:ScheduleReset()
  local seconds = ns.Sensors.GetSecondsUntilDailyReset()
  if not seconds then return end
  if self.resetTimer then self.resetTimer:Cancel() end
  self.resetTimer = C_Timer.NewTimer(seconds + 5, function()
    self:RequestRefresh()
    self:ScheduleReset()
  end)
end

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
  elseif event == "QUEST_DETAIL" then
    if ns.DB.account.collect.enabled then
      local questId, title = ns.Sensors.GetOfferedQuest()
      if questId then
        ns.Collect:Record(questId, ns.Sensors.GetOfferedQuestRepRewards(), { title = title })
      end
    end
  else
    if event == "QUEST_ACCEPTED" and ns.DB.account.collect.enabled then
      local questId = ...
      ns.Collect:Record(questId, ns.Sensors.GetQuestRepRewards(questId), { title = ns.Sensors.GetQuestTitle(questId) })
    end
    self:RequestRefresh()
  end
end)
Core:RegisterEvent("ADDON_LOADED")
Core:RegisterEvent("PLAYER_LOGIN")
Core:RegisterEvent("QUEST_DETAIL")

-- Zones lues par les tâches de quêtes mondiales de tous les guides enregistrés.
local function worldQuestZones()
  local names, seen = {}, {}
  for _, guide in ipairs(ns.Registry:List()) do
    for _, task in ipairs(guide.tasks) do
      if task.type == "worldquests" then
        for _, zone in ipairs(task.zones or {}) do
          if not seen[zone] then
            seen[zone] = true
            names[#names + 1] = zone
          end
        end
      end
    end
  end
  return names
end

local function printDebug()
  if #ns.Registry.problems == 0 then
    print(L.DEBUG_NONE)
  else
    print(L.DEBUG_HEADER)
    for _, p in ipairs(ns.Registry.problems) do print(L.DEBUG_PROBLEM:format(p)) end
  end
  local maps = ns.Sensors.FindZoneMaps(worldQuestZones())
  local text = (maps and #maps > 0) and table.concat(maps, L.SEP_LIST) or L.DEBUG_NO_MAPS
  print(L.DEBUG_MAPS:format(text))
end

local function countCollected()
  local n = 0
  for _ in pairs(ns.DB.account.collect.quests) do n = n + 1 end
  return n
end

SLASH_SENTIER1 = "/sentier"
SlashCmdList.SENTIER = function(msg)
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  if cmd == "" then
    ns.UI:Toggle()
  elseif cmd == "debug" then
    printDebug()
  elseif cmd == "collect" and arg == "on" then
    ns.Collect:SetEnabled(true)
    print(L.COLLECT_ON)
    Core:Refresh()
  elseif cmd == "collect" and arg == "off" then
    ns.Collect:SetEnabled(false)
    print(L.COLLECT_OFF:format(countCollected()))
  else
    print(L.HELP)
  end
end
