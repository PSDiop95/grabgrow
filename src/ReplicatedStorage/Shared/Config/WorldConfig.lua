--!strict
-- Mondes connus du MVP.
-- Source : Bible économique v1.0, section 6.
--
-- GreenValley est le seul monde jouable du MVP.
-- GoldenDesert, FrozenPeaks et MysticWorld sont déclarés UNIQUEMENT pour
-- le verrouillage et le déblocage côté serveur (T4, D-015) : ni carte, ni
-- ressources, ni contenu. Débloquer un monde n'y donne pas encore accès.
--
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
