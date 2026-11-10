--!strict
-- Ressources collectables du MVP (Green Valley, 3 ressources de test).
--
-- sellValue, rarity, spawnWeight : Bible économique v1.0, section 3.2.
-- respawnSeconds, collectAmount  : HYPOTHÈSES issues de l'exemple de
--   l'architecture technique (section 8.1). La Bible ne les définit pas.
--
-- Wild Fruit et Green Crystal (Bible 3.2) sont volontairement absents :
-- le MVP est limité à trois ressources.
--
-- Les identifiants (clés) seront persistés dans l'inventaire sauvegardé :
-- ne pas les renommer sans migration.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type ResourceDefinition = {
	displayNameKey: string,
	worldId: string,
	rarity: string,
	sellValue: number, -- Coins par unité (entier)
	spawnWeight: number, -- poids relatif d'apparition
	collectAmount: number, -- unités ajoutées au sac par collecte
	respawnSeconds: number,
}

local ResourceConfig: { [string]: ResourceDefinition } = {
	green_leaf = {
		displayNameKey = "resource.green_leaf",
		worldId = "GreenValley",
		rarity = "Common",
		sellValue = 1,
		spawnWeight = 40,
		collectAmount = 1,
		respawnSeconds = 2,
	},

	wood_chunk = {
		displayNameKey = "resource.wood_chunk",
		worldId = "GreenValley",
		rarity = "Common",
		sellValue = 2,
		spawnWeight = 30,
		collectAmount = 1,
		respawnSeconds = 3,
	},

	stone = {
		displayNameKey = "resource.stone",
		worldId = "GreenValley",
		rarity = "Common",
		sellValue = 3,
		spawnWeight = 20,
		collectAmount = 1,
		respawnSeconds = 4,
	},
}

return TableUtil.deepFreeze(ResourceConfig)
