local _, ns = ...

local G = Sentier:NewGuide("rep-midnight-harati", {
  title = "Hara’ti", category = "Réputation", faction = 2704,
  fromGrail = true, zones = ns.MidnightZones,
})

ns.MidnightShared.Standard(G)
