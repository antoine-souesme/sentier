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
    TomTom:RemoveWaypoint(self.tomtomUid)
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
    self.tomtomUid = TomTom:AddWaypoint(map, x / 100, y / 100, { title = title, from = "Sentier", persistent = false })
  else
    local ok = pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
      C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end)
    if not ok then
      ns.Registry:Problem(ns.L.PROBLEM_WAYPOINT:format(map))
      return false
    end
    self.blizzard = true
  end
  self.target = { map = map, x = x, y = y, title = title }
  return true
end
