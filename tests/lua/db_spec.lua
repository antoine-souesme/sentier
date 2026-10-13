local H = dofile("tests/lua/helper.lua")

describe("Reset", function()
  local ns
  before_each(function() ns = H.load() end)

  it("donne la date du dernier reset hebdomadaire", function()
    assert.are.equal(900000, ns.Reset:LastReset("weekly"))
  end)

  it("calcule la date du dernier reset journalier", function()
    -- maintenant 1 000 000, prochain reset dans 3 600 s : dernier reset il y a 82 800 s
    assert.are.equal(917200, ns.Reset:LastReset("daily"))
  end)

  it("n'a pas de reset pour une tâche unique", function()
    assert.is_nil(ns.Reset:LastReset("none"))
  end)

  it("dit si une date est antérieure au dernier reset", function()
    assert.is_true(ns.Reset:IsStale(899999, "weekly"))
    assert.is_false(ns.Reset:IsStale(900001, "weekly"))
    assert.is_false(ns.Reset:IsStale(1, "none"))
  end)

  it("ne périme rien si le jeu ne donne pas l'heure du reset", function()
    ns.Sensors.weeklyStart = nil
    assert.is_false(ns.Reset:IsStale(1, "weekly"))
  end)
end)

describe("DB", function()
  it("complète les réglages sans écraser ceux du joueur", function()
    local ns = H.load({
      account = { nav = "tomtom", sources = { rares = false }, collect = { quests = { [5] = { title = "x" } } } },
    })
    assert.are.equal("tomtom", ns.DB.account.nav)
    assert.is_false(ns.DB.account.sources.rares)
    assert.is_true(ns.DB.account.sources.weekly)
    assert.are.equal("x", ns.DB.account.collect.quests[5].title)
    assert.is_false(ns.DB.account.collect.enabled)
    assert.are.equal("step", ns.DB.char.tab)
    assert.are.same({}, ns.DB.char.marks)
  end)

  describe("coches et étapes passées", function()
    local ns, g, weekly, once
    before_each(function()
      ns = H.load()
      g = Sentier:NewGuide("rep-a", { title = "A", category = "R" })
      weekly = g:Weekly("w", { title = "W" })
      once = g:Weekly("o", { title = "O", reset = "none" })
    end)

    it("coche et décoche une tâche", function()
      ns.DB:SetMarked(g, weekly, true)
      assert.is_true(ns.DB:IsMarked(g, weekly))
      ns.DB:SetMarked(g, weekly, false)
      assert.is_false(ns.DB:IsMarked(g, weekly))
    end)

    it("efface au reset les coches et étapes passées périmées, pas celles des tâches uniques", function()
      ns.DB:SetMarked(g, weekly, true)
      ns.DB:SetSkipped(g, weekly, true)
      ns.DB:SetMarked(g, once, true)
      ns.Sensors.weeklyStart = ns.Sensors.now + 10
      ns.DB:Prune(g)
      assert.is_false(ns.DB:IsMarked(g, weekly))
      assert.is_false(ns.DB:IsSkipped(g, weekly))
      assert.is_true(ns.DB:IsMarked(g, once))
    end)

    it("partage la coche d'une tâche commune entre les guides", function()
      local other = Sentier:NewGuide("rep-b", { title = "B", category = "R" })
      local t1 = g:Weekly("delves", { title = "Gouffres", shared = true })
      local t2 = other:Weekly("delves", { title = "Gouffres", shared = true })
      ns.DB:SetMarked(g, t1, true)
      assert.is_true(ns.DB:IsMarked(other, t2))
    end)

    it("remet les étapes passées d'un seul guide", function()
      local other = Sentier:NewGuide("rep-b", { title = "B", category = "R" })
      local t = other:Weekly("w", { title = "W" })
      ns.DB:SetSkipped(g, weekly, true)
      ns.DB:SetSkipped(other, t, true)
      ns.DB:ClearSkips(g)
      assert.is_false(ns.DB:IsSkipped(g, weekly))
      assert.is_true(ns.DB:IsSkipped(other, t))
    end)
  end)
end)

describe("DB étape courante", function()
  it("a une étape courante vide par défaut", function()
    local ns = H.load()
    assert.is_nil(ns.DB.char.step)
    assert.is_nil(ns.DB:GetStep())
  end)

  it("conserve l'étape courante du personnage", function()
    local ns = H.load({ char = { step = "rep-a:w" } })
    assert.are.equal("rep-a:w", ns.DB:GetStep())
    ns.DB:SetStep("rep-a:o")
    assert.are.equal("rep-a:o", SentierCharDB.step)
    ns.DB:SetStep(nil)
    assert.is_nil(ns.DB:GetStep())
  end)
end)
