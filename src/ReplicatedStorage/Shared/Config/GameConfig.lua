--!strict
-- Paramètres globaux du MVP.
-- Source : Bible économique v1.0, section 2 (hypothèses de départ, à tester).
--
-- Ne pas dupliquer ici ce qui est défini ailleurs :
--   * capacité initiale du sac      -> UpgradeConfig.Backpack.levels[1]
--   * intervalle de collecte de base -> UpgradeConfig.Grabber.levels[1]
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

	Collection = {
		-- Portée de collecte sans Magnet (studs), soit magnetLevel = 0.
		-- Valeur de la Bible, section 2. L'amélioration Magnet est hors MVP.
		baseRangeStuds = 12,
	},

	Movement = {
		-- Vitesse de référence (studs/s). Correspond aux Boots niveau 1 ;
		-- l'amélioration Boots est hors MVP.
		baseWalkSpeed = 16,
	},
}

return TableUtil.deepFreeze(GameConfig)
