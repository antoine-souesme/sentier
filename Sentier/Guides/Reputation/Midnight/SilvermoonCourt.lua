local _, ns = ...

local G = Sentier:NewGuide("rep-midnight-silvermoon", {
  title = "Cour de Lune-d’Argent", category = "Réputation", faction = 2710,
  fromGrail = true, zones = ns.MidnightZones,
})

ns.MidnightShared.Standard(G)
