local H = dofile("tests/lua/helper.lua")

describe("GrailGuides", function()
  local ns, GS, amani, court

  before_each(function()
    ns = H.load()
    GS = ns.GrailSource
    amani = Sentier:NewGuide("amani", { title = "Amani", category = "R", faction = 2696, fromGrail = true })
    court = Sentier:NewGuide("court", { title = "Cour", category = "R", faction = 2710, fromGrail = true })
    Sentier:NewGuide("seul", { title = "Seul", category = "R", faction = 2699 })
  end)

  local function keys(list)
    local out = {}
    for _, t in ipairs(list) do out[#out + 1] = t.key end
    return out
  end

  it("ajoute à chaque guide les quêtes de sa faction, avec réputation, titre et position", function()
    GS.byFaction[2696] = { { questId = 1, rep = 250 } }
    GS.byFaction[2710] = { { questId = 2, rep = 75 } }
    GS.byFaction[2699] = { { questId = 3, rep = 50 } }
    GS.infos[1] = { title = "Q1", map = 2437, x = 10, y = 20, requires = {} }
    assert.are.equal(2, ns.GrailGuides:Fill())
    local t = amani.byId["1"]
    assert.are.same({ 250, "Q1", 2437, 10, 20, "none", true }, { t.rep, t.title, t.map, t.x, t.y, t.reset, t.fromGrail })
    assert.is_not_nil(court.byId["2"])
    assert.are.equal(0, #ns.Registry:Get("seul").tasks)
  end)

  it("met une quête qui récompense deux factions dans les deux guides", function()
    GS.byFaction[2696] = { { questId = 7, rep = 250 } }
    GS.byFaction[2710] = { { questId = 7, rep = 75 } }
    ns.GrailGuides:Fill()
    assert.are.equal(250, amani.byId["7"].rep)
    assert.are.equal(75, court.byId["7"].rep)
  end)

  it("laisse de côté les quêtes mondiales", function()
    GS.byFaction[2696] = { { questId = 3, rep = 100 } }
    GS.infos[3] = { worldQuest = true, requires = {} }
    assert.are.equal(0, ns.GrailGuides:Fill())
    assert.is_nil(amani.byId["3"])
  end)

  it("garde une quête déjà écrite à la main", function()
    amani:Quest(1, { title = "À la main", rep = 999 })
    GS.byFaction[2696] = { { questId = 1, rep = 250 } }
    assert.are.equal(0, ns.GrailGuides:Fill())
    assert.are.equal(999, amani.byId["1"].rep)
  end)

  it("ne remplit pas deux fois", function()
    GS.byFaction[2696] = { { questId = 1, rep = 250 } }
    ns.GrailGuides:Fill()
    assert.are.equal(0, ns.GrailGuides:Fill())
    assert.are.equal(1, #amani.tasks)
  end)

  it("remet à zéro chaque jour ou chaque semaine les quêtes répétables", function()
    GS.byFaction[2696] = { { questId = 4, rep = 10 }, { questId = 5, rep = 10 } }
    GS.infos[4] = { daily = true, requires = {} }
    GS.infos[5] = { weekly = true, requires = {} }
    ns.GrailGuides:Fill()
    assert.are.equal("daily", amani.byId["4"].reset)
    assert.are.equal("weekly", amani.byId["5"].reset)
  end)

  it("ajoute une quête dont Grail ne sait rien d'autre que la réputation", function()
    GS.byFaction[2696] = { { questId = 6, rep = 40 } }
    ns.GrailGuides:Fill()
    local t = amani.byId["6"]
    assert.are.same({ 40, "none" }, { t.rep, t.reset })
    assert.is_nil(t.title)
    assert.is_nil(t.map)
  end)

  it("bloque une quête tant que son prérequis n'est pas fait, avec le nom du prérequis", function()
    GS.byFaction[2696] = { { questId = 9, rep = 10 }, { questId = 10, rep = 10 } }
    GS.infos[9] = { requires = { 4 } }
    GS.infos[10] = { requires = { 5 } }
    GS.titles[4] = "Avant tout"
    ns.GrailGuides:Fill()
    assert.are.same({ { quest = 4, title = "Avant tout" } }, amani.byId["9"].requires)
    local status, info = ns.State:TaskStatus(amani, amani.byId["9"])
    assert.are.same({ "locked", "Quête requise : Avant tout" }, { status, info.reason })
    local _, info10 = ns.State:TaskStatus(amani, amani.byId["10"])
    assert.are.equal("Quête requise : Quête #5", info10.reason)
  end)

  it("place les quêtes de Grail après les tâches écrites à la main et avant les quêtes mondiales", function()
    amani:Weekly("w", { title = "W" })
    amani:WorldQuests({ zones = {} })
    amani:Order({ "w", "worldquests" })
    GS.byFaction[2696] = { { questId = 1, rep = 1 }, { questId = 2, rep = 1 } }
    ns.GrailGuides:Fill()
    assert.are.same({ "w", "1", "2", "worldquests" }, keys(amani.order))
  end)

  it("ajoute les quêtes à la fin de l'ordre quand le guide n'a pas de quêtes mondiales", function()
    amani:Weekly("w", { title = "W" })
    amani:Order({ "w" })
    GS.byFaction[2696] = { { questId = 1, rep = 1 } }
    ns.GrailGuides:Fill()
    assert.are.same({ "w", "1" }, keys(amani.order))
  end)

  it("range par zone, puis chaque quête après ses prérequis, et les quêtes sans zone à la fin", function()
    amani.zones = { "Zul’Aman", "Harandar" }
    ns.Sensors.mapNames[2437] = "Zul'Aman"
    ns.Sensors.mapNames[2413] = "Harandar"
    local tasks = {
      amani:Quest(10, { map = 2413 }),
      amani:Quest(11, { map = 2437, requires = { { quest = 13 } } }),
      amani:Quest(12, {}),
      amani:Quest(13, { map = 2437 }),
    }
    assert.are.same({ "13", "11", "10", "12" }, keys(ns.GrailGuides:Sort(amani, tasks)))
  end)

  it("range une zone inconnue du guide après les zones connues", function()
    amani.zones = { "Harandar" }
    ns.Sensors.mapNames[2413] = "Harandar"
    ns.Sensors.mapNames[2500] = "Ailleurs"
    local tasks = { amani:Quest(1, { map = 2500 }), amani:Quest(2, { map = 2413 }) }
    assert.are.same({ "2", "1" }, keys(ns.GrailGuides:Sort(amani, tasks)))
  end)

  it("ne boucle pas sur des prérequis croisés", function()
    local tasks = {
      amani:Quest(20, { requires = { { quest = 21 } } }),
      amani:Quest(21, { requires = { { quest = 20 } } }),
    }
    assert.are.same({ "20", "21" }, keys(ns.GrailGuides:Sort(amani, tasks)))
  end)

  it("complète plus tard les titres que Grail ne connaissait pas encore", function()
    GS.byFaction[2696] = { { questId = 1, rep = 1 } }
    GS.infos[1] = { requires = { 4 } }
    ns.GrailGuides:Fill()
    assert.is_nil(amani.byId["1"].title)
    GS.titles[1] = "Arrivé"
    GS.titles[4] = "Prérequis"
    ns.GrailGuides:RefreshTitles(amani)
    assert.are.equal("Arrivé", amani.byId["1"].title)
    assert.are.equal("Prérequis", amani.byId["1"].requires[1].title)
  end)

  it("ne fait rien sans erreur quand Grail ne répond pas", function()
    GS.broken = true
    assert.has_no.errors(function() assert.are.equal(0, ns.GrailGuides:Fill()) end)
    assert.are.equal(0, #amani.tasks)
  end)
end)
