local _, ns = ...

local DB = {}
ns.DB = DB

local VERSION = 2

local ACCOUNT_DEFAULTS = {
  sources = { sidequests = true, weekly = true, daily = true, rares = true, worldquests = true },
  nav = "auto",
  hideDone = true,
  locked = false,
  minimap = { angle = 225, hidden = false },
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
  local account = type(SentierDB) == "table" and SentierDB or {}
  -- Version 2 : les guides viennent de Grail. La collecte disparaît et les quêtes faites
  -- sont cachées une fois pour tous ; le joueur peut ensuite les réafficher.
  if (account.version or 1) < VERSION then
    account.collect = nil
    account.hideDone = true
  end
  account.version = VERSION
  SentierDB = fill(account, ACCOUNT_DEFAULTS)
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

