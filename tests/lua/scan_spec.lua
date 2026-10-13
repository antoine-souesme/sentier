local H = dofile("tests/lua/helper.lua")

describe("Scan", function()
  local ns, g, rewards, requested

  before_each(function()
    ns = H.load()
    local catalog = {
      [101] = { title = "Les esprits", zone = "Zul’Aman" },
      [102] = { title = "Le tambour", zone = "Zul’Aman" },
      [103] = { title = "Sans renom", zone = "Harandar" },
    }
    g = Sentier:NewGuide("rep-amani", { title = "Amani", category = "Réputation", faction = 2696, catalog = catalog })
    g:WorldQuests({})
    g:Order({ "worldquests" })
    rewards, requested = {}, {}
    ns.Sensors.GetQuestRepRewards = function(id) return rewards[id] end
    ns.Sensors.RequestQuestData = function(id) requested[#requested + 1] = id end
  end)

  it("ajoute au guide les quêtes du catalogue qui donnent du renom à sa faction", function()
    rewards[101] = { { factionId = 2696, amount = 250 } }
    rewards[103] = {}
    ns.Scan:Start()
    while ns.Scan:Step(2) do end
    local t = g.byId["101"]
    assert.are.same({ "Les esprits", "Zul’Aman", 250 }, { t.title, t.zone, t.rep })
    assert.is_nil(t.map)
    assert.is_nil(g.byId["103"])
    assert.are.equal("101", g.order[1].key)
  end)

  it("demande au jeu les données manquantes, puis lit la quête quand elles arrivent", function()
    ns.Scan:Start()
    while ns.Scan:Step(10) do end
    table.sort(requested)
    assert.are.same({ 101, 102, 103 }, requested)
    rewards[102] = { { factionId = 2696, amount = 75 } }
    assert.is_true(ns.Scan:OnLoaded(102))
    assert.are.equal(75, g.byId["102"].rep)
    assert.is_false(ns.Scan:OnLoaded(999))
  end)

  it("ignore les quêtes déjà faites ou déjà connues", function()
    ns.Sensors.done[101] = true
    ns.DB.account.collect.quests[102] = { title = "Le tambour", rewards = { { factionId = 2696, amount = 75 } } }
    ns.Scan:Start()
    while ns.Scan:Step(10) do end
    assert.are.same({ 103 }, requested)
  end)

  it("fonctionne même quand la collecte est coupée", function()
    ns.Collect:SetEnabled(false)
    rewards[101] = { { factionId = 2696, amount = 250 } }
    ns.Scan:Start()
    while ns.Scan:Step(10) do end
    assert.is_not_nil(g.byId["101"])
  end)

  it("compte les quêtes lues et celles qui donnent du renom", function()
    rewards[101] = { { factionId = 2696, amount = 250 } }
    rewards[103] = {}
    ns.Scan:Start()
    while ns.Scan:Step(10) do end
    assert.are.same({ 3, 1 }, { ns.Scan.total, ns.Scan.found })
  end)
end)
