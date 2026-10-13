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

  it("convertit les récompenses de réputation", function()
    _G.C_QuestLog = { GetQuestLogMajorFactionReputationRewards = function() return { { factionID = 2696, rewardAmount = 250 } } end }
    assert.are.same({ { factionId = 2696, amount = 250 } }, S.GetQuestRepRewards(5))
  end)
  describe("GetOfferedQuest", function()
    after_each(function() _G.GetQuestID, _G.GetTitleText = nil, nil end)

    it("renvoie l'identifiant et le titre de la quête proposée", function()
      _G.GetQuestID = function() return 42 end
      _G.GetTitleText = function() return "Une quête" end
      local id, title = S.GetOfferedQuest()
      assert.are.equal(42, id)
      assert.are.equal("Une quête", title)
    end)

    it("renvoie nil quand l'identifiant vaut 0", function()
      _G.GetQuestID = function() return 0 end
      _G.GetTitleText = function() return "" end
      assert.is_nil(S.GetOfferedQuest())
    end)

    it("renvoie nil sans erreur quand l'API manque", function()
      _G.GetQuestID, _G.GetTitleText = nil, nil
      assert.has_no.errors(function() assert.is_nil(S.GetOfferedQuest()) end)
    end)

    it("renvoie nil sans erreur quand l'API échoue", function()
      _G.GetQuestID = function() error("boom") end
      assert.has_no.errors(function() assert.is_nil(S.GetOfferedQuest()) end)
    end)
  end)
end)
