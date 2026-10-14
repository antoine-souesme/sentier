local H = dofile("tests/lua/helper.lua")

describe("Sensors", function()
  local ns, S, requested

  before_each(function()
    ns = H.load()
    assert(loadfile("Sentier/Sensors/Sensors.lua"))("Sentier", ns)
    S = ns.Sensors
    requested = {}
  end)

  after_each(function()
    _G.C_QuestLog, _G.C_TaskQuest, _G.C_Map, _G.HaveQuestRewardData, _G.C_MajorFactions = nil, nil, nil, nil, nil
  end)

  it("lit l'état d'une quête", function()
    _G.C_QuestLog = { IsQuestFlaggedCompleted = function(id) return id == 1 end }
    assert.is_true(S.IsQuestDone(1))
    assert.is_false(S.IsQuestDone(2))
  end)

  it("renvoie nil et note un problème quand une fonction du jeu manque", function()
    _G.C_QuestLog = nil
    assert.is_nil(S.IsQuestDone(1))
    assert.is_true(H.hasProblem(ns, "Lecture impossible (quête)"))
  end)

  it("lit le renom d'une faction", function()
    _G.C_MajorFactions = {
      GetMajorFactionData = function(id)
        if id == 2696 then return { renownLevel = 12, renownReputationEarned = 1550, renownLevelThreshold = 2500, name = "Tribu des Amani" } end
      end,
    }
    assert.are.same({ level = 12, earned = 1550, threshold = 2500, name = "Tribu des Amani" }, S.GetRenown(2696))
    assert.is_nil(S.GetRenown(1))
  end)

  it("lit la progression d'un objectif", function()
    _G.C_QuestLog = { GetQuestObjectives = function() return { { numFulfilled = 2, numRequired = 4 } } end }
    assert.are.same({ have = 2, need = 4 }, S.GetObjectiveProgress(7, 1))
  end)

  local function fakeWorldQuests(questsByMap)
    _G.C_TaskQuest = {
      GetQuestsOnMap = function(map) return questsByMap[map] end,
      GetQuestInfoByQuestID = function(id) return "WQ " .. id end,
      RequestPreloadRewardData = function(id) requested[#requested + 1] = id end,
    }
    _G.C_QuestLog = {
      IsWorldQuest = function() return true end,
      GetQuestLogMajorFactionReputationRewards = function(id)
        if id == 10 then return { { factionID = 2696, rewardAmount = 75 } } end
        if id == 11 then return { { factionID = 2696, rewardAmount = 150 }, { factionID = 2704, rewardAmount = 50 } } end
        return {}
      end,
    }
    _G.HaveQuestRewardData = function(id) return id ~= 12 end
  end

  it("liste les quêtes mondiales de la faction, triées par réputation, et demande les récompenses manquantes", function()
    fakeWorldQuests({ [2437] = { { questID = 10, x = 0.5, y = 0.25, mapID = 2437 }, { questID = 11, x = 0.1, y = 0.1 }, { questID = 12 } } })
    local list = S.GetActiveWorldQuests(2696, { 2437 })
    assert.are.equal(2, #list)
    assert.are.equal(11, list[1].questId)
    assert.are.equal(150, list[1].rep)
    assert.are.equal(10, list[2].questId)
    assert.are.equal("WQ 10", list[2].title)
    assert.are.equal(2437, list[2].map)
    assert.are.equal(50, list[2].x)
    assert.are.equal(25, list[2].y)
    assert.are.same({ 12 }, requested)
  end)

  it("ne compte qu'une fois une quête mondiale visible sur deux cartes", function()
    fakeWorldQuests({ [1] = { { questID = 10 } }, [2] = { { questID = 10 } } })
    assert.are.equal(1, #S.GetActiveWorldQuests(2696, { 1, 2 }))
  end)

  it("renvoie nil si l'API des quêtes mondiales a disparu", function()
    _G.C_TaskQuest = {}
    assert.is_nil(S.GetActiveWorldQuests(2696, { 2437 }))
    assert.is_true(H.hasProblem(ns, "Lecture impossible (quêtes mondiales)"))
  end)

  it("retrouve les cartes par leur nom, quelle que soit l'apostrophe", function()
    _G.C_Map = {
      GetMapInfo = function(id)
        if id == 2437 then return { name = "Zul'Aman" } end
        if id == 2413 then return { name = "Harandar" } end
      end,
    }
    assert.are.same({ 2413, 2437 }, S.FindZoneMaps({ "Zul’Aman", "Harandar" }))
  end)

  it("ne redemande pas les récompenses d'une quête déjà demandée pendant la session", function()
    fakeWorldQuests({ [2437] = { { questID = 12 } } })
    S.GetActiveWorldQuests(2696, { 2437 })
    S.GetActiveWorldQuests(2696, { 2437 })
    assert.are.same({ 12 }, requested)
  end)

  it("ne garde pas en mémoire une recherche de cartes vide", function()
    local ready = false
    _G.C_Map = { GetMapInfo = function(id) if ready and id == 2413 then return { name = "Harandar" } end end }
    assert.are.same({}, S.FindZoneMaps({ "Harandar" }))
    ready = true
    assert.are.same({ 2413 }, S.FindZoneMaps({ "Harandar" }))
  end)

  describe("Now", function()
    after_each(function() _G.GetServerTime, _G.time = nil, nil end)

    it("utilise l'heure du serveur quand elle existe", function()
      _G.GetServerTime = function() return 123456 end
      assert.are.equal(123456, S.Now())
    end)

    it("se rabat sur l'heure locale sans heure du serveur", function()
      _G.GetServerTime = nil
      _G.time = function() return 777 end
      assert.are.equal(777, S.Now())
    end)
  end)
end)
