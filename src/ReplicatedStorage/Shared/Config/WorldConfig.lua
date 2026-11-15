--!strict
-- Les quatre mondes du jeu.
-- Source : Bible économique 1.1, section 6 (conditions inchangées, D-021 D10).
--
-- T8 (D-021) : un seul place, une île par monde. Un monde est ACCESSIBLE
-- quand il est débloqué dans le profil serveur ET qu'un point d'arrivée
-- existe sur la carte (Workspace.WorldArrivals, attribut `ArrivalWorldId`,
-- lu par Systems/WorldArrivals). Le voyage est fait par le serveur
-- (Services/WorldTravelService) ; la collecte d'une ressource exige le
-- déblocage de son monde (Services/CollectionService). Aucune condition
-- propre à un monde dans les services : tout se déduit de cette table, de
-- ResourceConfig.worldId et de la carte.

-- Règle de déblocage (D-015) : monde d'ordre n débloqué seulement si le
-- monde d'ordre n - 1 l'est, si backpackLevel >= requiredBackpackLevel et
-- si le solde couvre unlockCost, débité une seule fois (WorldUnlockService).
--
-- Les ressources d'un monde se déduisent de ResourceConfig (champ worldId) :
-- ne pas les lister ici pour éviter une double source.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type WorldDefinition = {
	displayNameKey: string,
	order: number,
	unlockedByDefault: boolean,
	unlockCost: number, -- Coins, payés une seule fois
	requiredBackpackLevel: number,
}

local WorldConfig: { [string]: WorldDefinition } = {
	GreenValley = {
		displayNameKey = "world.green_valley",
		order = 1,
		unlockedByDefault = true,
		unlockCost = 0,
		requiredBackpackLevel = 1,
	},

	GoldenDesert = {
		displayNameKey = "world.golden_desert",
		order = 2,
		unlockedByDefault = false,
		unlockCost = 1_500,
		requiredBackpackLevel = 5,
	},

	FrozenPeaks = {
		displayNameKey = "world.frozen_peaks",
		order = 3,
		unlockedByDefault = false,
		unlockCost = 35_000,
		requiredBackpackLevel = 8,
	},

	MysticWorld = {
		displayNameKey = "world.mystic_world",
		order = 4,
		unlockedByDefault = false,
		unlockCost = 250_000,
		requiredBackpackLevel = 10,
	},
}

return TableUtil.deepFreeze(WorldConfig)
