local _, ns = ...

-- Analyse du catalogue : demande au jeu la réputation de chaque quête des catalogues des guides,
-- et ajoute aux guides celles qui donnent du renom, sans que le joueur ait à les ouvrir.
local Scan = { queue = {}, waiting = {}, total = 0, found = 0 }
ns.Scan = Scan

function Scan:Start()
  self.queue, self.waiting, self.titles = {}, {}, {}
  self.total, self.found = 0, 0
  local known = ns.DB.account.collect.quests
  for _, guide in ipairs(ns.Registry:List()) do
    if guide.faction and guide.catalog then
      for questId, info in pairs(guide.catalog) do
        if not self.titles[questId] and not known[questId] and ns.Sensors.IsQuestDone(questId) ~= true then
          self.titles[questId] = info.title or false
          self.queue[#self.queue + 1] = questId
        end
      end
    end
  end
  table.sort(self.queue)
end

-- Lit une quête : vrai si le jeu connaît sa réputation, et la garde si elle donne du renom.
function Scan:Read(questId)
  local rewards = ns.Sensors.GetQuestRepRewards(questId)
  if not rewards or #rewards == 0 then return false end
  self.waiting[questId] = nil
  local title = self.titles[questId] or nil
  if ns.Collect:Store(questId, rewards, { title = title, noPosition = true }) then
    self.found = self.found + 1
  end
  return true
end

-- Traite au plus n quêtes de la file. Renvoie vrai s'il en reste.
function Scan:Step(n)
  for _ = 1, n do
    local questId = table.remove(self.queue, 1)
    if not questId then return false end
    self.total = self.total + 1
    if not self:Read(questId) then
      self.waiting[questId] = true
      ns.Sensors.RequestQuestData(questId)
    end
  end
  return #self.queue > 0
end

-- Données d'une quête arrivées (QUEST_DATA_LOAD_RESULT). Vrai si une quête attendue a été lue.
function Scan:OnLoaded(questId)
  if not self.waiting[questId] then return false end
  return self:Read(questId)
end
