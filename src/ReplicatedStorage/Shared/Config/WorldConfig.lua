--!strict
-- Mondes connus du MVP.
-- Source : Bible économique v1.0, section 6.
--
-- GreenValley est le seul monde jouable du MVP.
-- GoldenDesert est déclaré UNIQUEMENT pour tester le verrouillage et le
-- déblocage côté serveur : il n'a ni carte, ni ressources, ni contenu.
-- Frozen Peaks et Mystic World restent reportés et ne sont pas configurés.
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
}

return TableUtil.deepFreeze(WorldConfig)
