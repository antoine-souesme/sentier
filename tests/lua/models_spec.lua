local H = dofile("tests/lua/helper.lua")

describe("Models", function()
  local ns, g

  before_each(function()
    ns = H.load()
    g = Sentier:NewGuide("rep-a", {
      title = "Tribu des Amani", category = "Réputation", faction = 2696,
      catalog = { [1] = { title = "Quête A" }, [2] = { title = "Quête B" }, [3] = { title = "Quête C" } },
    })
    ns.Sensors.renown[2696] = { level = 12, earned = 1550, threshold = 2500 }
  end)

  local function step(viewIndex)
    return ns.Models.Step(ns.State:Evaluate(g), viewIndex)
  end

  local function listTexts(hideDone)
    local texts = {}
    for _, r in ipairs(ns.Models.List(ns.State:Evaluate(g), hideDone)) do texts[#texts + 1] = r.kind .. ":" .. r.text end
    return texts
  end

  it("affiche « rien à faire » quand aucune étape ne reste", function()
    g:Order({})
    local m = step(1)
    assert.is_true(m.empty)
    assert.are.equal("Rien à faire pour l'instant.", m.title)
    assert.are.equal("Renom 12 · 1550 / 2500", m.renownText)
    assert.are.equal(1550, m.renownValue)
    assert.are.equal(2500, m.renownMax)
  end)

  it("décrit l'étape en cours et annonce la suivante", function()
    g:Quest(1, { rep = 250, map = 2437, x = 45.2, y = 60.1, note = "Parle à Zerella" })
    g:Quest(2, {})
    g:Order({ 1, 2 })
    local m = step(1)
    assert.are.equal("Quête A", m.title)
    assert.are.equal("quête", m.kind)
    assert.are.equal("Parle à Zerella", m.detail)
    assert.are.equal("+250 rep", m.rep)
    assert.are.equal("Ensuite : Quête B", m.nextText)
    assert.are.same({ map = 2437, x = 45.2, y = 60.1, title = "Quête A" }, m.target)
    assert.are.equal(1, m.index)
    assert.are.equal(2, m.count)
  end)

  it("garde l'index de navigation dans les bornes", function()
    g:Quest(1, {})
    g:Quest(2, {})
    g:Order({ 1, 2 })
    assert.are.equal(2, step(9).index)
    assert.are.equal(1, step(0).index)
  end)

  it("n'a pas de cible quand la tâche n'a pas de coordonnées", function()
    g:Quest(2, {})
    g:Order({ 2 })
    assert.is_nil(step(1).target)
  end)

  it("vise la meilleure quête mondiale", function()
    g:WorldQuests({ zones = {} })
    g:Order({ "worldquests" })
    ns.Sensors.worldQuests[2696] = { { questId = 50, title = "Raid de la tribu", rep = 150, map = 2437, x = 10, y = 20 } }
    local m = step(1)
    assert.are.same({ map = 2437, x = 10, y = 20, title = "Raid de la tribu" }, m.target)
    assert.are.equal("Raid de la tribu +150 rep", m.detail)
  end)

  it("est vide quand toutes les sources sont coupées", function()
    g:Weekly("delves", { title = "Gouffres" })
    g:Quest(1, {})
    g:WorldQuests({ zones = {} })
    g:Order({ 1, "delves", "worldquests" })
    for _, src in ipairs({ "sidequests", "weekly", "daily", "rares", "worldquests" }) do
      ns.DB.account.sources[src] = false
    end
    local m = step(1)
    assert.is_true(m.empty)
    assert.are.equal(ns.L.NO_STEP, m.title)
    assert.are.same({}, ns.Models.List(ns.State:Evaluate(g), false))
  end)

  it("est vide quand toutes les tâches sont faites", function()
    g:Quest(1, {})
    g:Quest(2, {})
    g:Order({ 1, 2 })
    ns.Sensors.done[1] = true
    ns.Sensors.done[2] = true
    local m = step(1)
    assert.is_true(m.empty)
    assert.are.equal(ns.L.NO_STEP, m.title)
    assert.has_no.errors(function() ns.Models.List(ns.State:Evaluate(g), true) end)
    assert.has_no.errors(function() ns.Models.List(ns.State:Evaluate(g), false) end)
  end)

  it("résiste à une quête mondiale sans titre", function()
    g:WorldQuests({ zones = {} })
    g:Order({ "worldquests" })
    ns.Sensors.worldQuests[2696] = { { questId = 77, rep = 0, map = 2437, x = 1, y = 2 } }
    local m
    assert.has_no.errors(function() m = step(1) end)
    assert.are.equal(ns.L.UNKNOWN_QUEST:format(77), m.detail)
    assert.are.equal(ns.L.UNKNOWN_QUEST:format(77), m.target.title)
    local rows = ns.Models.List(ns.State:Evaluate(g), false)
    assert.are.equal(ns.L.UNKNOWN_QUEST:format(77), rows[2].text)
  end)

  describe("liste", function()
    before_each(function()
      g:Weekly("delves", { title = "Gouffres généreux", rep = 1000 })
      g:Quest(1, { rep = 250 })
      g:Quest(2, { rep = 100 })
      g:Quest(3, { rep = 50, requires = { { renown = 14 } } })
      g:WorldQuests({ zones = {} })
      ns.Sensors.done[1] = true
      ns.Sensors.worldQuests[2696] = { { questId = 50, title = "Raid de la tribu", rep = 150, map = 2437, x = 10, y = 20 } }
    end)

    it("groupe les tâches et compte les quêtes secondaires restantes", function()
      assert.are.same({
        "header:Cette semaine",
        "task:Gouffres généreux",
        "header:Quêtes mondiales actives",
        "worldquest:Raid de la tribu",
        "header:Quêtes secondaires (2 restantes)",
        "task:Quête A",
        "task:Quête B",
        "task:Quête C",
      }, listTexts(false))
      local rows = ns.Models.List(ns.State:Evaluate(g), false)
      assert.are.equal("locked", rows[8].status)
      assert.are.equal("Renom 14 requis", rows[8].reason)
      assert.are.equal("+150 rep", rows[4].rep)
    end)

    it("masque les tâches faites sans changer le compte", function()
      assert.are.same({
        "header:Cette semaine",
        "task:Gouffres généreux",
        "header:Quêtes mondiales actives",
        "worldquest:Raid de la tribu",
        "header:Quêtes secondaires (2 restantes)",
        "task:Quête B",
        "task:Quête C",
      }, listTexts(true))
    end)

    it("omet les sources coupées", function()
      ns.DB.account.sources.weekly = false
      ns.DB.account.sources.worldquests = false
      assert.are.equal("header:Quêtes secondaires (2 restantes)", listTexts(false)[1])
    end)
  end)
end)
