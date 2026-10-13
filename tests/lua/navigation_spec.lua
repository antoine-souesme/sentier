local H = dofile("tests/lua/helper.lua")

describe("Navigation", function()
  local ns, calls

  before_each(function()
    ns = H.load()
    calls = {}
    _G.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
    _G.C_Map = {
      SetUserWaypoint = function(point) calls[#calls + 1] = { "blizzard", point } end,
      ClearUserWaypoint = function() calls[#calls + 1] = { "clear" } end,
    }
    _G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
    _G.TomTom = nil
  end)

  after_each(function()
    _G.UiMapPoint, _G.C_Map, _G.C_SuperTrack, _G.TomTom = nil, nil, nil, nil
  end)

  local function installTomTom()
    _G.TomTom = {
      AddWaypoint = function(_, map, x, y, opts)
        calls[#calls + 1] = { "tomtom", map, x, y, opts.title }
        return "uid" .. #calls
      end,
      RemoveWaypoint = function(_, uid) calls[#calls + 1] = { "remove", uid } end,
    }
  end

  it("utilise TomTom quand il est installé", function()
    installTomTom()
    assert.is_true(ns.Navigation:SetTarget(2437, 45, 60, "Quête A"))
    assert.are.same({ "tomtom", 2437, 0.45, 0.6, "Quête A" }, calls[1])
  end)

  it("remplace l'ancien point TomTom", function()
    installTomTom()
    ns.Navigation:SetTarget(2437, 45, 60, "A")
    ns.Navigation:SetTarget(2437, 10, 20, "B")
    assert.are.same({ "remove", "uid1" }, calls[2])
    assert.are.equal("tomtom", calls[3][1])
  end)

  it("se rabat sur le repère du jeu quand TomTom manque, même réglé sur TomTom", function()
    ns.DB.account.nav = "tomtom"
    assert.is_true(ns.Navigation:SetTarget(2437, 45, 60, "A"))
    assert.are.same({ "blizzard", { map = 2437, x = 0.45, y = 0.6 } }, calls[1])
  end)

  it("respecte le réglage « repère du jeu » même avec TomTom", function()
    installTomTom()
    ns.DB.account.nav = "blizzard"
    ns.Navigation:SetTarget(2437, 45, 60, "A")
    assert.are.equal("blizzard", calls[1][1])
  end)

  it("efface le repère du jeu avant d'en poser un autre", function()
    ns.Navigation:SetTarget(2437, 45, 60, "A")
    ns.Navigation:SetTarget(2437, 10, 20, "B")
    assert.are.same({ "clear" }, calls[2])
  end)

  it("ne pose rien sans coordonnées", function()
    assert.is_false(ns.Navigation:SetTarget(nil, nil, nil, "A"))
    assert.are.equal(0, #calls)
    assert.is_nil(ns.Navigation.target)
  end)

  it("signale un problème quand le repère du jeu échoue", function()
    _G.C_Map.SetUserWaypoint = function() error("boom") end
    assert.is_false(ns.Navigation:SetTarget(2437, 45, 60, "A"))
    assert.is_true(H.hasProblem(ns, "Repère impossible sur la carte 2437"))
  end)
end)
