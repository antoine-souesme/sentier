local _, ns = ...

local DB = {}
ns.DB = DB

local ACCOUNT_DEFAULTS = {
  sources = { sidequests = true, weekly = true, daily = true, rares = true, worldquests = true },
  nav = "auto",
  hideDone = false,
  locked = false,
  collect = { enabled = false, quests = {} },
}

local CHAR_DEFAULTS = {
  tab = "step",
  hidden = false,
  marks = {},
  skips = {},
  step = nil, -- clé de l'étape courante, par personnage
}

local function fill(target, defaults)
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      if type(target[k]) ~= "table" then target[k] = {} end
      fill(target[k], v)
    elseif target[k] == nil then
      target[k] = v
    end
  end
  return target
end

function DB:Init()
  SentierDB = fill(type(SentierDB) == "table" and SentierDB or {}, ACCOUNT_DEFAULTS)
  SentierCharDB = fill(type(SentierCharDB) == "table" and SentierCharDB or {}, CHAR_DEFAULTS)
  self.account, self.char = SentierDB, SentierCharDB
end

-- Une tâche « shared » a la même coche dans tous les guides (ex. gouffres généreux).
local function key(guide, task)
  return (task.shared and "shared" or guide.id) .. ":" .. task.key
end

function DB:IsMarked(guide, task) return self.char.marks[key(guide, task)] ~= nil end
function DB:SetMarked(guide, task, on) self.char.marks[key(guide, task)] = on and ns.Sensors.Now() or nil end
function DB:IsSkipped(guide, task) return self.char.skips[key(guide, task)] ~= nil end
function DB:SetSkipped(guide, task, on) self.char.skips[key(guide, task)] = on and ns.Sensors.Now() or nil end

function DB:ClearSkips(guide)
  for _, task in ipairs(guide.tasks) do self.char.skips[key(guide, task)] = nil end
end

function DB:Prune(guide)
  for _, task in ipairs(guide.tasks) do
    local k = key(guide, task)
    for _, store in ipairs({ self.char.marks, self.char.skips }) do
      local stamp = store[k]
      if stamp and ns.Reset:IsStale(stamp, task.reset) then store[k] = nil end
    end
  end
end

function DB:GetStep() return self.char.step end
function DB:SetStep(stepKey) self.char.step = stepKey end

