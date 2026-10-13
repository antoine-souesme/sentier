local H = dofile("tests/lua/helper.lua")

describe("Collect", function()
  local ns

  before_each(function()
    ns = H.load()
    Sentier:NewGuide("rep-amani", { title = "Amani", category = "Réputation", faction = 2696 })
    ns.Sensors.position = { map = 2437, x = 45.2, y = 60.1 }
    ns.Sensors.now = 1234
  end)

  it("n'enregistre rien quand la collecte est coupée", function()
    assert.is_false(ns.Collect:Record(91234, { { factionId = 2696, amount = 250 } }, { title = "A" }))
    assert.is_nil(ns.DB.account.collect.quests[91234])
  end)

  it("garde seulement la réputation des factions suivies, avec la position du joueur", function()
    ns.Collect:SetEnabled(true)
    assert.is_true(ns.Collect:Record(91234, { { factionId = 2696, amount = 250 }, { factionId = 9999, amount = 10 } }, { title = "A" }))
    assert.are.same({
      title = "A", worldQuest = false, rewards = { { factionId = 2696, amount = 250 } },
      map = 2437, x = 45.2, y = 60.1, seen = 1234,
    }, ns.DB.account.collect.quests[91234])
  end)

  it("ignore une quête qui ne donne rien aux factions suivies", function()
    ns.Collect:SetEnabled(true)
    assert.is_false(ns.Collect:Record(5, { { factionId = 9999, amount = 10 } }, {}))
    assert.is_nil(ns.DB.account.collect.quests[5])
  end)

  it("garde les coordonnées d'une quête mondiale plutôt que celles du joueur", function()
    ns.Collect:SetEnabled(true)
    ns.Collect:Record(50, { { factionId = 2696, amount = 150 } }, { title = "Raid", worldQuest = true, map = 2413, x = 10, y = 20 })
    local q = ns.DB.account.collect.quests[50]
    assert.are.same({ 2413, 10, 20, true }, { q.map, q.x, q.y, q.worldQuest })
  end)

  it("ignore des récompenses illisibles", function()
    ns.Collect:SetEnabled(true)
    assert.is_false(ns.Collect:Record(1, nil))
  end)
end)
