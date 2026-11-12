--!strict
-- Les cinq améliorations (T4, décision D-015).
-- Source : Bible économique v1.0, sections 5.2 à 5.6 (hypothèses à tester).
-- Aucune valeur de coût ou d'effet n'a été modifiée par rapport à la Bible.
--
-- Lecture d'une table `levels` :
--   levels[i] décrit le niveau (startLevel + i - 1) ;
--   cost  = Coins à payer pour atteindre ce niveau depuis le précédent ;
--   value = statistique effective à ce niveau.
-- levels[1] est le niveau de départ, gratuit. Niveau max =
-- startLevel + #levels - 1. Calculs : Shared/Util/UpgradeMath.
--
-- Magnet (D-006, D-015) : le profil démarre à magnetLevel = 0 (« non
-- acquis »). Le niveau 0 correspond à la ligne 1 de la Bible (12 studs,
-- gratuit) et le niveau k à la ligne k + 1 : niveau maximum 9 (30 studs).
--
-- Multiplier : valeurs au centième près (calcul entier, voir SaleValue).

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type UpgradeLevel = {
	cost: number,
	value: number,
}

export type UpgradeDefinition = {
	displayNameKey: string,
	-- Ordre d'affichage dans la boutique.
	order: number,
	currency: string, -- clé de GameConfig.Currencies
	-- Champ du profil (profile.upgrades) qui porte le niveau.
	profileKey: string,
	-- Niveau d'un nouveau profil (DataSchema).
	startLevel: number,
	stat: string, -- statistique modifiée
	levels: { UpgradeLevel },
}

local UpgradeConfig: { [string]: UpgradeDefinition } = {
	Backpack = {
		displayNameKey = "upgrade.backpack",
		order = 1,
		currency = "Coins",
		profileKey = "backpackLevel",
		startLevel = 1,
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
		order = 2,
		currency = "Coins",
		profileKey = "grabberLevel",
		startLevel = 1,
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

	Magnet = {
		displayNameKey = "upgrade.magnet",
		order = 3,
		currency = "Coins",
		profileKey = "magnetLevel",
		startLevel = 0,
		stat = "collectRangeStuds", -- portée nominale de collecte
		levels = {
			{ cost = 0, value = 12 }, -- niveau 0 (Bible : niveau 1)
			{ cost = 200, value = 14 },
			{ cost = 500, value = 16 },
			{ cost = 1_200, value = 18 },
			{ cost = 3_000, value = 20 },
			{ cost = 7_500, value = 22 },
			{ cost = 18_000, value = 24 },
			{ cost = 45_000, value = 26 },
			{ cost = 100_000, value = 28 },
			{ cost = 220_000, value = 30 }, -- niveau 9 (Bible : niveau 10)
		},
	},

	Boots = {
		displayNameKey = "upgrade.boots",
		order = 4,
		currency = "Coins",
		profileKey = "bootsLevel",
		startLevel = 1,
		stat = "walkSpeed", -- studs/s (Humanoid.WalkSpeed, fixé par le serveur)
		levels = {
			{ cost = 0, value = 16 },
			{ cost = 250, value = 16.5 },
			{ cost = 650, value = 17 },
			{ cost = 1_500, value = 17.5 },
			{ cost = 3_500, value = 18 },
			{ cost = 8_000, value = 18.5 },
			{ cost = 20_000, value = 19 },
			{ cost = 50_000, value = 19.5 },
			{ cost = 110_000, value = 20 },
			{ cost = 250_000, value = 20.5 },
		},
	},

	Multiplier = {
		displayNameKey = "upgrade.multiplier",
		order = 5,
		currency = "Coins",
		profileKey = "multiplierLevel",
		startLevel = 1,
		stat = "sellMultiplier", -- appliqué au total de chaque vente
		levels = {
			{ cost = 0, value = 1.00 },
			{ cost = 300, value = 1.05 },
			{ cost = 800, value = 1.10 },
			{ cost = 1_800, value = 1.15 },
			{ cost = 4_000, value = 1.20 },
			{ cost = 9_000, value = 1.25 },
			{ cost = 22_000, value = 1.30 },
			{ cost = 55_000, value = 1.35 },
			{ cost = 130_000, value = 1.40 },
			{ cost = 300_000, value = 1.50 },
		},
	},
}

return TableUtil.deepFreeze(UpgradeConfig)
