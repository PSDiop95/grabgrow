--!strict
-- Ressources collectables des quatre mondes (T8, D-021).
--
-- sellValue, rarity, spawnWeight : Bible économique 1.1, sections 3.2 à 3.5
--   (mondes 2 à 4 : « option B », D-021 D3 ; Wild Fruit et Green Crystal :
--   valeurs de la Bible, D-021 D4). HYPOTHÈSES DE DÉPART, à mesurer.
-- respawnSeconds : HYPOTHÈSES (Bible 3.6, D-021 D8) : 2 / 3 / 4 s pour
--   Green Valley ; 3 et 4 s pour les communes des mondes 2 à 4 ; 8 s
--   (Peu commune), 20 s (Rare), 60 s (Épique). À ajuster sur mesures.
-- collectAmount : 1 unité par collecte (hypothèse T2, inchangée).
--
-- Une ressource n'est collectable que dans un monde débloqué par le joueur
-- (CollectionService, D-021) et seulement si la carte possède des points de
-- spawn pour elle (Systems/ResourceNodes). Apparence : ResourceVisualConfig.
--
-- Les identifiants (clés) sont persistés dans l'inventaire sauvegardé :
-- ne pas les renommer sans migration. Ajouter une clé ne demande pas de
-- migration (D-008 : clés inconnues conservées par un serveur ancien).

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

	wood = {
		displayNameKey = "resource.wood",
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

	-- Green Valley, zone avancée (T8, D-021 D4).
	wild_fruit = {
		displayNameKey = "resource.wild_fruit",
		worldId = "GreenValley",
		rarity = "Uncommon",
		sellValue = 5,
		spawnWeight = 8,
		collectAmount = 1,
		respawnSeconds = 8,
	},

	green_crystal = {
		displayNameKey = "resource.green_crystal",
		worldId = "GreenValley",
		rarity = "Rare",
		sellValue = 12,
		spawnWeight = 2,
		collectAmount = 1,
		respawnSeconds = 20,
	},

	-- Golden Desert (Bible 1.1, D-021 D3).
	sandstone = {
		displayNameKey = "resource.sandstone",
		worldId = "GoldenDesert",
		rarity = "Common",
		sellValue = 5,
		spawnWeight = 40,
		collectAmount = 1,
		respawnSeconds = 3,
	},

	copper_ore = {
		displayNameKey = "resource.copper_ore",
		worldId = "GoldenDesert",
		rarity = "Common",
		sellValue = 6,
		spawnWeight = 30,
		collectAmount = 1,
		respawnSeconds = 4,
	},

	fossil = {
		displayNameKey = "resource.fossil",
		worldId = "GoldenDesert",
		rarity = "Uncommon",
		sellValue = 9,
		spawnWeight = 18,
		collectAmount = 1,
		respawnSeconds = 8,
	},

	gold_nugget = {
		displayNameKey = "resource.gold_nugget",
		worldId = "GoldenDesert",
		rarity = "Rare",
		sellValue = 17,
		spawnWeight = 10,
		collectAmount = 1,
		respawnSeconds = 20,
	},

	sun_crystal = {
		displayNameKey = "resource.sun_crystal",
		worldId = "GoldenDesert",
		rarity = "Epic",
		sellValue = 38,
		spawnWeight = 2,
		collectAmount = 1,
		respawnSeconds = 60,
	},

	-- Frozen Peaks (Bible 1.1, D-021 D3).
	ice_shard = {
		displayNameKey = "resource.ice_shard",
		worldId = "FrozenPeaks",
		rarity = "Common",
		sellValue = 18,
		spawnWeight = 40,
		collectAmount = 1,
		respawnSeconds = 3,
	},

	silver_ore = {
		displayNameKey = "resource.silver_ore",
		worldId = "FrozenPeaks",
		rarity = "Common",
		sellValue = 24,
		spawnWeight = 30,
		collectAmount = 1,
		respawnSeconds = 4,
	},

	frozen_stone = {
		displayNameKey = "resource.frozen_stone",
		worldId = "FrozenPeaks",
		rarity = "Uncommon",
		sellValue = 34,
		spawnWeight = 18,
		collectAmount = 1,
		respawnSeconds = 8,
	},

	blue_crystal = {
		displayNameKey = "resource.blue_crystal",
		worldId = "FrozenPeaks",
		rarity = "Rare",
		sellValue = 62,
		spawnWeight = 10,
		collectAmount = 1,
		respawnSeconds = 20,
	},

	ice_diamond = {
		displayNameKey = "resource.ice_diamond",
		worldId = "FrozenPeaks",
		rarity = "Epic",
		sellValue = 140,
		spawnWeight = 2,
		collectAmount = 1,
		respawnSeconds = 60,
	},

	-- Mystic World (Bible 1.1, D-021 D3).
	mystic_dust = {
		displayNameKey = "resource.mystic_dust",
		worldId = "MysticWorld",
		rarity = "Common",
		sellValue = 68,
		spawnWeight = 40,
		collectAmount = 1,
		respawnSeconds = 3,
	},

	star_fragment = {
		displayNameKey = "resource.star_fragment",
		worldId = "MysticWorld",
		rarity = "Common",
		sellValue = 87,
		spawnWeight = 30,
		collectAmount = 1,
		respawnSeconds = 4,
	},

	spectral_ore = {
		displayNameKey = "resource.spectral_ore",
		worldId = "MysticWorld",
		rarity = "Uncommon",
		sellValue = 125,
		spawnWeight = 18,
		collectAmount = 1,
		respawnSeconds = 8,
	},

	purple_crystal = {
		displayNameKey = "resource.purple_crystal",
		worldId = "MysticWorld",
		rarity = "Rare",
		sellValue = 230,
		spawnWeight = 10,
		collectAmount = 1,
		respawnSeconds = 20,
	},

	mystic_core = {
		displayNameKey = "resource.mystic_core",
		worldId = "MysticWorld",
		rarity = "Epic",
		sellValue = 480,
		spawnWeight = 2,
		collectAmount = 1,
		respawnSeconds = 60,
	},
}

return TableUtil.deepFreeze(ResourceConfig)
