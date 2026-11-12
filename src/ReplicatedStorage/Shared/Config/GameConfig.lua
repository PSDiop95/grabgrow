--!strict
-- Paramètres globaux du MVP.
-- Source : Bible économique v1.0, section 2 (hypothèses de départ, à tester).
--
-- Ne pas dupliquer ici ce qui est défini ailleurs :
--   * capacité initiale du sac      -> UpgradeConfig.Backpack.levels[1]
--   * intervalle de collecte de base -> UpgradeConfig.Grabber.levels[1]
--   * portée de collecte de base     -> UpgradeConfig.Magnet.levels[1] (12 studs)
--   * vitesse de déplacement de base -> UpgradeConfig.Boots.levels[1] (16 studs/s)
--   * valeurs des ressources         -> ResourceConfig
--   * conditions des mondes          -> WorldConfig

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local GameConfig = {
	-- Monde de départ du joueur (doit exister dans WorldConfig).
	StartingWorldId = "GreenValley",

	-- Monnaies actives dans le MVP. Gems et Stars sont reportées.
	Currencies = {
		Coins = { startingBalance = 0 },
	},

	Selling = {
		-- Distance d'interaction avec une station de vente (studs), mesurée
		-- du personnage au centre de la zone. HYPOTHÈSE DE DÉPART (T3),
		-- absente de la Bible : à ajuster en T7. Aucune valeur économique :
		-- les prix restent dans ResourceConfig.
		interactRangeStuds = 10,
		-- Plafond du multiplicateur total de vente (Bible 2 et 10.2 : x5,00).
		-- En T4, seul l'équipement Multiplier (max x1,50) y contribue.
		maxSellMultiplier = 5,
	},
}

return TableUtil.deepFreeze(GameConfig)
