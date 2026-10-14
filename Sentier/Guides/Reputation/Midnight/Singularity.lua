local _, ns = ...

local G = Sentier:NewGuide("rep-midnight-singularity", {
  title = "La Singularité", category = "Réputation", faction = 2699,
  fromGrail = true, zones = ns.MidnightZones,
})

ns.MidnightShared.Standard(G)
