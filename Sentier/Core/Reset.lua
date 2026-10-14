local _, ns = ...

local Reset = {}
ns.Reset = Reset

local DAY = 86400

-- Date (secondes Unix) du dernier reset de ce type, ou nil si inconnue ou sans objet.
function Reset:LastReset(kind)
  local S = ns.Sensors
  if kind == "weekly" then return S.GetWeeklyResetStart() end
  if kind == "daily" then
    local untilNext = S.GetSecondsUntilDailyReset()
    if not untilNext then return nil end
    return S.Now() + untilNext - DAY
  end
  return nil
end

function Reset:IsStale(stamp, kind)
  local last = self:LastReset(kind)
  return last ~= nil and stamp < last
end
