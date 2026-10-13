local _, ns = ...

-- Zones de Midnight dont on lit les quêtes mondiales. Les numéros de carte
-- sont retrouvés en jeu par leur nom (Sensors.FindZoneMaps).
-- Liste des cartes où apparaissent les quêtes mondiales, à confirmer en jeu avec /sentier debug.
ns.MidnightZones = {
  "Bois des Chants éternels",
  "Lune-d’Argent",
  "Zul’Aman",
  "Harandar",
  "Tempête du Vide",
  "Île de Quel’Danas",
}

-- Blocs partagés entre les guides de Midnight, définis une seule fois.
ns.MidnightShared = {}

function ns.MidnightShared.WorldQuests(G)
  G:WorldQuests({ zones = ns.MidnightZones })
end

-- Hebdomadaires cochées à la main, communes à plusieurs factions.
function ns.MidnightShared.Weeklies(G)
  G:Weekly("silvermoon-weekly", {
    title = "Quête hebdomadaire de Lune-d'Argent", shared = true,
    note = "Prends une quête de Lady Liadrin, Halduron Brightwing ou Aethas Sunreaver à Lune-d'Argent.",
  })
  G:Weekly("bountiful-delves", {
    title = "Gouffres généreux", shared = true,
    note = "Termine 4 gouffres généreux. La faction qui reçoit la réputation est tirée au hasard.",
  })
end

-- Guide type : hebdomadaires partagées, quêtes mondiales, puis ordre des étapes.
function ns.MidnightShared.Standard(G)
  ns.MidnightShared.Weeklies(G)
  ns.MidnightShared.WorldQuests(G)
  G:Order({ "silvermoon-weekly", "bountiful-delves", "worldquests" })
end
