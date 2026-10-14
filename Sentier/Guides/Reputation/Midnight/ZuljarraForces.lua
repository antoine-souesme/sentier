local _, ns = ...

local G = Sentier:NewGuide("rep-midnight-zuljarra", {
  title = "Forces de Zul’jarra", category = "Réputation", faction = 2772,
})

-- Titres provisoires (source : guide Method 12.1), à corriger en jeu avec les noms exacts.
G:Weekly("zuljarra-spark", {
  title = "Quête hebdomadaire de l'étincelle", rep = 1000,
})
G:Weekly("atal-utek", {
  title = "Hebdomadaire des caveaux d'Atal'Utek",
})
ns.MidnightShared.WorldQuests(G)

G:Order({ "zuljarra-spark", "atal-utek", "worldquests" })
