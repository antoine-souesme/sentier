local _, ns = ...
local L = ns.L

local Registry = { guides = {}, problems = {}, seen = {} }
ns.Registry = Registry

ns.SOURCES = { "sidequests", "weekly", "daily", "rares", "worldquests" }

function Registry:Problem(message)
  if self.seen[message] then return end
  self.seen[message] = true
  self.problems[#self.problems + 1] = message
end

local Guide = {}
Guide.__index = Guide

function Registry:NewGuide(id, opts)
  id = tostring(id)
  opts = opts or {}
  if not (opts.title and opts.category) then
    self:Problem(L.PROBLEM_GUIDE_INVALID:format(id))
  end
  if self.guides[id] then self:Problem(L.PROBLEM_GUIDE_DUPLICATE:format(id)) end
  local guide = setmetatable({
    id = id,
    title = opts.title or id,
    category = opts.category or L.DEFAULT_CATEGORY,
    faction = opts.faction,
    catalog = opts.catalog or {},
    tasks = {},
    byId = {},
    order = {},
  }, Guide)
  self.guides[id] = guide
  return guide
end

function Registry:Get(id)
  return self.guides[id]
end

function Registry:List()
  local list = {}
  for _, guide in pairs(self.guides) do list[#list + 1] = guide end
  table.sort(list, function(a, b)
    if a.category ~= b.category then return a.category < b.category end
    return a.title < b.title
  end)
  return list
end

function Registry:Resolve(id)
  return (id and self.guides[id]) or self:List()[1]
end

local function merge(base, opts)
  for k, v in pairs(opts or {}) do base[k] = v end
  return base
end

function Guide:Add(task)
  task.key = tostring(task.id)
  if self.byId[task.key] then
    Registry:Problem(L.PROBLEM_TASK_DUPLICATE:format(self.id, task.key))
    return self.byId[task.key]
  end
  task.factions = task.factions or (self.faction and { self.faction }) or {}
  task.requires = task.requires or {}
  self.tasks[#self.tasks + 1] = task
  self.byId[task.key] = task
  return task
end

function Guide:Quest(questId, opts)
  local task = merge({ id = questId, type = "quest", source = "sidequests", reset = "none", questIds = { questId } }, opts)
  local info = self.catalog[questId]
  if info then
    task.title = task.title or info.title
    task.zone = task.zone or info.zone
  end
  if not task.title then
    task.missing = true
    Registry:Problem(L.PROBLEM_QUEST_MISSING:format(questId, self.id))
  end
  return self:Add(task)
end

function Guide:Weekly(id, opts)
  return self:Add(merge({ id = id, type = "weekly", source = "weekly", reset = "weekly" }, opts))
end

function Guide:Daily(id, opts)
  return self:Add(merge({ id = id, type = "daily", source = "daily", reset = "daily" }, opts))
end

function Guide:Rare(id, opts)
  local task = merge({ id = id, type = "rare", source = "rares", reset = "daily" }, opts)
  task.questIds = task.questIds or (task.questId and { task.questId }) or nil
  return self:Add(task)
end

function Guide:WorldQuests(opts)
  local task = merge({ id = "worldquests", type = "worldquests", source = "worldquests", reset = "none", title = L.GROUP_WORLDQUESTS }, opts)
  if opts and opts.faction then task.factions = { opts.faction } end
  return self:Add(task)
end

function Guide:Order(list)
  self.order = {}
  for _, id in ipairs(list) do
    local task = self.byId[tostring(id)]
    if task then
      self.order[#self.order + 1] = task
    else
      Registry:Problem(L.PROBLEM_ORDER_UNKNOWN:format(self.id, tostring(id)))
    end
  end
end

Sentier = Sentier or {}
function Sentier:NewGuide(id, opts)
  return Registry:NewGuide(id, opts)
end
