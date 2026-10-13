local H = dofile("tests/lua/helper.lua")

describe("Collect", function()
  local ns

  before_each(function()
    ns = H.load()
    Sentier:NewGuide("rep-amani", { title = "Amani", category = "Réputation", faction = 2696 })
    ns.Sensors.position = { map = 2437, x = 45.2, y = 60.1 }
    ns.Sensors.now = 1234
  end)

  it("est active par défaut", function()
    assert.is_true(ns.DB.account.collect.enabled)
  end)

  it("n'enregistre rien quand la collecte est coupée", function()
    ns.Collect:SetEnabled(false)
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

  describe("quêtes collectées dans les guides", function()
    local g

    before_each(function()
      g = ns.Registry:Get("rep-amani")
      g:WorldQuests({})
      g:Order({ "worldquests" })
    end)

    it("ajoute une quête collectée au guide de sa faction, avant les quêtes mondiales", function()
      ns.Collect:Record(91234, { { factionId = 2696, amount = 250 } }, { title = "Les esprits" })
      local t = g.byId["91234"]
      assert.are.same({ "quest", "sidequests", 250, "Les esprits", 2437, 45.2, 60.1 },
        { t.type, t.source, t.rep, t.title, t.map, t.x, t.y })
      assert.is_nil(t.missing)
      assert.are.same({ "91234", "worldquests" }, { g.order[1].key, g.order[2].key })
    end)

    it("reprend la collecte sauvegardée au chargement, sans doublon", function()
      ns.DB.account.collect.quests[7] = { title = "Ancienne", rewards = { { factionId = 2696, amount = 75 } } }
      ns.Collect:ApplyToGuides()
      ns.Collect:ApplyToGuides()
      assert.are.equal(75, g.byId["7"].rep)
      assert.are.equal(2, #g.order)
    end)

    it("ne touche pas une quête déjà écrite dans le guide", function()
      g:Quest(8, { title = "Écrite", rep = 500 })
      ns.DB.account.collect.quests[8] = { title = "Collectée", rewards = { { factionId = 2696, amount = 75 } } }
      ns.Collect:ApplyToGuides()
      assert.are.equal(500, g.byId["8"].rep)
    end)

    it("n'ajoute pas les quêtes mondiales ni les factions sans guide", function()
      ns.DB.account.collect.quests[9] = { title = "QM", worldQuest = true, rewards = { { factionId = 2696, amount = 75 } } }
      ns.DB.account.collect.quests[10] = { title = "Autre", rewards = { { factionId = 9999, amount = 75 } } }
      ns.Collect:ApplyToGuides()
      assert.is_nil(g.byId["9"])
      assert.is_nil(g.byId["10"])
    end)
  end)
end)
