local H = dofile("tests/lua/helper.lua")

-- Grail simulé : un code de 4 caractères est décodé d'après sa première lettre.
local function fakeGrail()
  local codes = { a = { "A88", 250 }, b = { "A96", 75 }, c = { "A88", -10 }, d = { "04C", 250 } }
  return {
    timings = { AddonLoaded = 12 },
    loads = 0,
    questReputations = {
      [101] = "aaaa",
      [102] = "aaaabbbb",
      [103] = "cccc",
      [104] = "dddd",
      [105] = { "A88250" }, -- format avant chargement : ignoré
    },
    LoadReputations = function(self) self.loads = self.loads + 1 end,
    ReputationDecode = function(_, code)
      local c = codes[code:sub(1, 1)]
      return c[1], c[2]
    end,
    QuestName = function(_, id) return ({ [101] = "Ami ou adversaire" })[id] end,
    IsWorldQuest = function(_, id) return id == 103 end,
    IsDaily = function(_, id) return id == 104 end,
    IsWeekly = function() return false end,
    QuestPrerequisites = function(_, id)
      return ({ [102] = { 101 }, [104] = { { 101, "PF175" } }, [105] = { 101, 102 } })[id]
    end,
    QuestLocationsAccept = function(_, id)
      if id == 101 then return { { mapArea = 2437, x = 33.5, y = 48.6, name = "Zerella" } } end
    end,
  }
end

describe("GrailSource", function()
  local ns, GS

  before_each(function()
    ns = H.load()
    assert(loadfile("Sentier/Sensors/Grail.lua"))("Sentier", ns)
    GS = ns.GrailSource
    _G.Grail = fakeGrail()
  end)

  after_each(function() _G.Grail = nil end)

  it("sait si Grail est installé et prêt", function()
    assert.is_true(GS.Available())
    assert.is_true(GS.Ready())
    _G.Grail.timings = {}
    assert.is_false(GS.Ready())
    _G.Grail = nil
    assert.is_false(GS.Available())
    assert.is_false(GS.Ready())
  end)

  it("liste les quêtes qui donnent de la réputation à chaque faction demandée", function()
    local out = GS.QuestsByFaction({ 2696, 2710 })
    assert.are.same({ { questId = 101, rep = 250 }, { questId = 102, rep = 250 } }, out[2696])
    assert.are.same({ { questId = 102, rep = 75 } }, out[2710])
  end)

  it("ne charge la réputation de Grail qu'une fois", function()
    GS.QuestsByFaction({ 2696 })
    GS.QuestsByFaction({ 2696 })
    assert.are.equal(1, _G.Grail.loads)
  end)

  it("renvoie nil sans Grail, et nil avec un problème si Grail échoue", function()
    _G.Grail = nil
    assert.is_nil(GS.QuestsByFaction({ 2696 }))
    _G.Grail = fakeGrail()
    _G.Grail.ReputationDecode = function() error("boom") end
    assert.has_no.errors(function() assert.is_nil(GS.QuestsByFaction({ 2696 })) end)
    assert.is_true(H.hasProblem(ns, "Lecture de Grail impossible"))
  end)

  it("donne le nom, la position et les prérequis d'une quête", function()
    assert.are.same({
      title = "Ami ou adversaire", worldQuest = false, daily = false, weekly = false,
      requires = {}, map = 2437, x = 33.5, y = 48.6,
    }, GS.QuestInfo(101))
    assert.are.same({ 101 }, GS.QuestInfo(102).requires)
    assert.is_nil(GS.QuestInfo(102).map)
  end)

  it("ne garde que les prérequis simples", function()
    assert.are.same({ 101 }, GS.QuestInfo(104).requires) -- 101 et une condition de métier
    assert.are.same({}, GS.QuestInfo(105).requires)     -- 101 ou 102 : ignoré
  end)

  it("reconnaît les quêtes mondiales et journalières", function()
    assert.is_true(GS.QuestInfo(103).worldQuest)
    assert.is_true(GS.QuestInfo(104).daily)
  end)

  it("renvoie nil sans erreur quand Grail échoue sur une quête", function()
    _G.Grail.QuestName = function() error("boom") end
    assert.has_no.errors(function() assert.is_nil(GS.QuestInfo(101)) end)
    assert.has_no.errors(function() assert.is_nil(GS.QuestTitle(101)) end)
  end)

  it("donne le nom d'une quête", function()
    assert.are.equal("Ami ou adversaire", GS.QuestTitle(101))
    assert.is_nil(GS.QuestTitle(999))
  end)
end)
