local _, ns = ...

local Navigation = {}
ns.Navigation = Navigation

local function tomtomAvailable()
  return type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function"
end

function Navigation:UseTomTom()
  return ns.DB.account.nav ~= "blizzard" and tomtomAvailable()
end

function Navigation:Clear()
  if self.tomtomUid and tomtomAvailable() and TomTom.RemoveWaypoint then
    pcall(TomTom.RemoveWaypoint, TomTom, self.tomtomUid)
  end
  self.tomtomUid = nil
  if self.blizzard then
    pcall(C_Map.ClearUserWaypoint)
    self.blizzard = nil
  end
  self.target = nil
end

-- x et y en pourcentage (0 à 100), comme dans les guides.
function Navigation:SetTarget(map, x, y, title)
  self:Clear()
  if not (map and x and y) then return false end
  if self:UseTomTom() then
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, map, x / 100, y / 100, { title = title, from = "Sentier", persistent = false })
    if not ok or uid == nil then
      ns.Registry:Problem(ns.L.PROBLEM_WAYPOINT:format(tostring(map)))
      return false
    end
    self.tomtomUid = uid
  else
    local ok = pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
      -- Noté avant le suivi : Clear() doit pouvoir l'enlever même si le suivi échoue.
      self.blizzard = true
      C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end)
    if not ok then
      ns.Registry:Problem(ns.L.PROBLEM_WAYPOINT:format(tostring(map)))
      return false
    end
  end
  self.target = { map = map, x = x, y = y, title = title }
  return true
end
