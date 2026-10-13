local _, ns = ...
local L = ns.L

-- Transforme le résultat de State:Evaluate en données prêtes à afficher. Aucune API du jeu ici.
local Models = {}
ns.Models = Models

function Models.TaskTitle(task)
  if task.title then return task.title end
  if type(task.id) == "number" then return L.UNKNOWN_QUEST:format(task.id) end
  return tostring(task.id)
end

function Models.RepText(rep)
  if rep and rep > 0 then return L.REP_FMT:format(rep) end
  return ""
end

function Models.Target(entry)
  local task = entry.task
  if task.type == "worldquests" then
    local wq = entry.info.worldQuests and entry.info.worldQuests[1]
    if wq and wq.map and wq.x and wq.y then return { map = wq.map, x = wq.x, y = wq.y, title = wq.title } end
    return nil
  end
  if task.map and task.x and task.y then
    return { map = task.map, x = task.x, y = task.y, title = Models.TaskTitle(task) }
  end
  return nil
end

function Models.Step(result, viewIndex)
  local m = {}
  local renown = result.renown
  if renown then
    m.renownText = L.RENOWN_FMT:format(renown.level, renown.earned, renown.threshold)
    m.renownValue = renown.earned
    m.renownMax = renown.threshold
  end

  local steps = result.steps
  if #steps == 0 then
    m.empty = true
    m.title = L.NO_STEP
    return m
  end

  local i = math.max(1, math.min(viewIndex or 1, #steps))
  local entry = steps[i]
  m.index, m.count, m.entry = i, #steps, entry
  m.title = Models.TaskTitle(entry.task)
  m.kind = L["TYPE_" .. entry.task.type]

  local detail = {}
  if entry.task.note then detail[#detail + 1] = entry.task.note end
  if entry.info.progress then
    detail[#detail + 1] = L.PROGRESS_FMT:format(entry.info.progress.have, entry.info.progress.need)
  end
  if entry.info.worldQuests then
    for k = 1, math.min(3, #entry.info.worldQuests) do
      local wq = entry.info.worldQuests[k]
      detail[#detail + 1] = wq.title .. " " .. Models.RepText(wq.rep)
    end
  end
  m.detail = table.concat(detail, "\n")
  m.rep = Models.RepText(entry.task.rep)
  if steps[i + 1] then m.nextText = L.NEXT_FMT:format(Models.TaskTitle(steps[i + 1].task)) end
  m.target = Models.Target(entry)
  return m
end

local GROUPS = {
  { type = "weekly", label = "GROUP_WEEKLY" },
  { type = "daily", label = "GROUP_DAILY" },
  { type = "worldquests", label = "GROUP_WORLDQUESTS" },
  { type = "quest", label = "GROUP_SIDEQUESTS" },
  { type = "rare", label = "GROUP_RARES" },
}

function Models.List(result, hideDone)
  local rows = {}
  for _, group in ipairs(GROUPS) do
    local items, remaining = {}, 0
    for _, entry in ipairs(result.entries) do
      if entry.task.type == group.type and entry.enabled then
        if group.type == "worldquests" then
          for _, wq in ipairs(entry.info.worldQuests or {}) do
            remaining = remaining + 1
            items[#items + 1] = {
              kind = "worldquest", status = "todo", text = wq.title, rep = Models.RepText(wq.rep),
              target = (wq.map and wq.x and wq.y) and { map = wq.map, x = wq.x, y = wq.y, title = wq.title } or nil,
            }
          end
        else
          if entry.status ~= "done" then remaining = remaining + 1 end
          if not (hideDone and entry.status == "done") then
            local text = Models.TaskTitle(entry.task)
            if entry.info.progress then
              text = text .. " " .. L.PROGRESS_FMT:format(entry.info.progress.have, entry.info.progress.need)
            end
            items[#items + 1] = {
              kind = "task", entry = entry, status = entry.status, text = text, reason = entry.info.reason,
              rep = Models.RepText(entry.task.rep), target = Models.Target(entry),
            }
          end
        end
      end
    end
    if #items > 0 then
      local label = L[group.label]
      if group.type == "quest" then label = label:format(remaining) end
      rows[#rows + 1] = { kind = "header", text = label }
      for _, item in ipairs(items) do rows[#rows + 1] = item end
    end
  end
  return rows
end
