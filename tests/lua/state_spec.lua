local H = dofile("tests/lua/helper.lua")

describe("State", function()
  local ns, g

  before_each(function()
    ns = H.load()
    g = Sentier:NewGuide("rep-a", {
      title = "A", category = "Réputation", faction = 2696,
    })
  end)

  local function status(task)
    return (ns.State:TaskStatus(g, task))
  end

  local function stepKeys()
    local keys = {}
    for _, e in ipairs(ns.State:Evaluate(g).steps) do keys[#keys + 1] = e.task.key end
    return keys
  end

  it("donne l'état d'une quête : à faire, faite, illisible", function()
    local t = g:Quest(1, {})
    assert.are.equal("todo", status(t))
    ns.Sensors.done[1] = true
    assert.are.equal("done", status(t))
    ns.Sensors.done[1] = "error"
    assert.are.equal("unknown", status(t))
  end)

  it("suit normalement une quête sans titre", function()
    local t = g:Quest(99, {})
    assert.are.equal("todo", status(t))
    ns.Sensors.done[99] = true
    assert.are.equal("done", status(t))
  end)


  it("bloque une tâche tant que le renom requis n'est pas atteint", function()
    local t = g:Quest(1, { requires = { { renown = 8 } } })
    ns.Sensors.renown[2696] = { level = 5, earned = 0, threshold = 2500 }
    local st, info = ns.State:TaskStatus(g, t)
    assert.are.equal("locked", st)
    assert.are.equal("Renom 8 requis", info.reason)
    ns.Sensors.renown[2696].level = 8
    assert.are.equal("todo", status(t))
  end)

  it("bloque une tâche tant qu'une quête requise n'est pas faite", function()
    local t = g:Quest(1, { requires = { { quest = 2, title = "Q2" } } })
    local st, info = ns.State:TaskStatus(g, t)
    assert.are.equal("locked", st)
    assert.are.equal("Quête requise : Q2", info.reason)
  end)

  it("une quête faite reste faite même si les prérequis sont illisibles", function()
    local t = g:Quest(1, { requires = { { renown = 8 } } })
    ns.Sensors.done[1] = true
    assert.are.equal("done", status(t))
  end)

  it("une activité sans numéro de quête se coche à la main", function()
    local t = g:Weekly("delves", { title = "Gouffres" })
    assert.are.equal("todo", status(t))
    ns.DB:SetMarked(g, t, true)
    assert.are.equal("done", status(t))
  end)

  it("donne la progression d'une activité", function()
    local t = g:Weekly("delves", { title = "Gouffres", progress = { questId = 7, objective = 1 } })
    ns.Sensors.objectives[7] = { have = 2, need = 4 }
    local _, info = ns.State:TaskStatus(g, t)
    assert.are.same({ have = 2, need = 4 }, info.progress)
  end)

  it("donne l'état des quêtes mondiales", function()
    local t = g:WorldQuests({ zones = { "Harandar" } })
    assert.are.equal("unknown", status(t))
    ns.Sensors.worldQuests[2696] = {}
    assert.are.equal("done", status(t))
    ns.Sensors.worldQuests[2696] = { { questId = 50, title = "Raid", rep = 150 } }
    local st, info = ns.State:TaskStatus(g, t)
    assert.are.equal("todo", st)
    assert.are.equal(50, info.worldQuests[1].questId)
  end)

  it("les quêtes mondiales sont inconnues quand aucune carte n'est trouvée", function()
    local t = g:WorldQuests({ zones = { "Harandar" } })
    ns.Sensors.zoneMaps = {}
    ns.Sensors.worldQuests[2696] = {}
    assert.are.equal("unknown", status(t))
    assert.is_true(H.hasProblem(ns, "Aucune carte trouvée pour les quêtes mondiales de rep-a"))
  end)

  describe("Evaluate", function()
    it("suit l'ordre et saute les tâches faites, passées ou dont la source est coupée", function()
      g:Quest(1, {})
      g:Quest(2, {})
      g:Quest(3, {})
      g:Weekly("w", { title = "W" })
      g:Order({ "w", 1, 2, 3 })
      ns.Sensors.done[1] = true
      ns.DB:SetSkipped(g, g.byId["2"], true)
      assert.are.same({ "w", "3" }, stepKeys())
      ns.DB.account.sources.weekly = false
      assert.are.same({ "3" }, stepKeys())
    end)

    it("n'a aucune étape quand toutes les sources sont coupées", function()
      g:Quest(1, {})
      g:Order({ 1 })
      for _, source in ipairs(ns.SOURCES) do ns.DB.account.sources[source] = false end
      local result = ns.State:Evaluate(g)
      assert.are.equal(0, #result.steps)
      assert.is_false(result.byKey["1"].enabled)
    end)

    it("oublie une coche manuelle après le reset hebdomadaire", function()
      local t = g:Weekly("w", { title = "W" })
      g:Order({ "w" })
      ns.DB:SetMarked(g, t, true)
      assert.are.equal(0, #ns.State:Evaluate(g).steps)
      ns.Sensors.weeklyStart = 1000500
      ns.Sensors.now = 1000600
      assert.are.equal(1, #ns.State:Evaluate(g).steps)
      assert.is_false(ns.DB:IsMarked(g, t))
    end)

    it("donne le renom de la faction du guide", function()
      ns.Sensors.renown[2696] = { level = 12, earned = 1550, threshold = 2500 }
      assert.are.equal(12, ns.State:Evaluate(g).renown.level)
    end)
  end)
  it("n'a aucune étape quand tout est fait", function()
    g:Quest(1, {})
    g:Quest(2, {})
    g:Order({ 1, 2 })
    ns.Sensors.done[1] = true
    ns.Sensors.done[2] = true
    assert.are.equal(0, #ns.State:Evaluate(g).steps)
  end)

  it("une tâche partagée cochée dans un guide est faite dans un autre", function()
    local g2 = Sentier:NewGuide("rep-b", { title = "B", category = "Réputation", faction = 2699 })
    local t1 = g:Weekly("delves", { title = "Gouffres", shared = true })
    local t2 = g2:Weekly("delves", { title = "Gouffres", shared = true })
    ns.DB:SetMarked(g, t1, true)
    assert.are.equal("done", (ns.State:TaskStatus(g2, t2)))
  end)
end)
