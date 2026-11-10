--!strict
-- Améliorations du MVP : Backpack (capacité) et Grabber (cadence).
-- Source : Bible économique v1.0, sections 5.2 et 5.3 (hypothèses à tester).
--
-- Magnet, Boots et Multiplier (Bible 5.4 à 5.6) sont hors MVP et ne sont
-- pas configurés ici.
--
-- levels[n] décrit l'état AU niveau n :
--   cost  = Coins à payer pour passer du niveau n-1 au niveau n
--   value = statistique effective au niveau n
-- Le niveau 1 est le niveau de départ (gratuit).

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type UpgradeLevel = {
	cost: number,
	value: number,
}

export type UpgradeDefinition = {
	displayNameKey: string,
	currency: string, -- clé de GameConfig.Currencies
	stat: string, -- statistique modifiée
	levels: { UpgradeLevel },
}

local UpgradeConfig: { [string]: UpgradeDefinition } = {
	Backpack = {
		displayNameKey = "upgrade.backpack",
		currency = "Coins",
		stat = "capacity", -- unités de ressources
		levels = {
			{ cost = 0, value = 50 },
			{ cost = 100, value = 75 },
			{ cost = 250, value = 100 },
			{ cost = 600, value = 140 },
			{ cost = 1_200, value = 180 },
			{ cost = 2_500, value = 240 },
			{ cost = 5_000, value = 320 },
			{ cost = 10_000, value = 420 },
			{ cost = 20_000, value = 550 },
			{ cost = 40_000, value = 700 },
			{ cost = 75_000, value = 850 },
			{ cost = 130_000, value = 1_000 },
			{ cost = 220_000, value = 1_200 },
			{ cost = 360_000, value = 1_400 },
			{ cost = 600_000, value = 1_650 },
			{ cost = 1_000_000, value = 2_000 },
		},
	},

	Grabber = {
		displayNameKey = "upgrade.grabber",
		currency = "Coins",
		stat = "collectIntervalSeconds", -- délai minimal entre deux collectes
		levels = {
			{ cost = 0, value = 0.75 },
			{ cost = 150, value = 0.70 },
			{ cost = 400, value = 0.65 },
			{ cost = 900, value = 0.60 },
			{ cost = 2_000, value = 0.55 },
			{ cost = 5_000, value = 0.50 },
			{ cost = 12_000, value = 0.46 },
			{ cost = 30_000, value = 0.42 },
			{ cost = 70_000, value = 0.39 },
			{ cost = 150_000, value = 0.36 },
		},
	},
}

return TableUtil.deepFreeze(UpgradeConfig)
