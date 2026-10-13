local H = dofile("tests/lua/helper.lua")

local DIR = "Sentier/Guides/Reputation/Midnight/"
local FILES = { "Catalog.lua", "Zones.lua", "Amani.lua", "SilvermoonCourt.lua", "Harati.lua", "Singularity.lua", "ZuljarraForces.lua" }

describe("Guides de Midnight", function()
  local ns

  before_each(function()
    ns = H.load()
    for _, file in ipairs(FILES) do assert(loadfile(DIR .. file))("Sentier", ns) end
  end)

  it("se chargent sans problème", function()
    assert.are.same({}, ns.Registry.problems)
  end)

  it("couvrent les cinq factions avec leur identifiant", function()
    local found = {}
    for _, g in ipairs(ns.Registry:List()) do found[#found + 1] = g.title .. "=" .. g.faction end
    assert.are.same({
      "Cour de Lune-d’Argent=2710",
      "Forces de Zul’jarra=2772",
      "Hara’ti=2704",
      "La Singularité=2699",
      "Tribu des Amani=2696",
    }, found)
  end)

  it("donnent au moins une étape à chaque guide", function()
    for _, g in ipairs(ns.Registry:List()) do assert.is_true(#g.order > 0, g.id) end
  end)

  it("ont un catalogue qui couvre les six zones", function()
    local zones = {}
    for _, q in pairs(ns.MidnightCatalog) do zones[q.zone] = true end
    for _, zone in ipairs({ "Harandar", "Zul’Aman", "Bois des Chants éternels", "Lune-d’Argent", "La flèche du Vide", "Tempête du Vide" }) do
      assert.is_true(zones[zone] == true, zone)
    end
  end)
end)
