local _, ns = ...

local G = Sentier:NewGuide("rep-midnight-amani", {
  title = "Tribu des Amani", category = "Réputation", faction = 2696,
  fromGrail = true, zones = ns.MidnightZones,
})

ns.MidnightShared.Standard(G)
