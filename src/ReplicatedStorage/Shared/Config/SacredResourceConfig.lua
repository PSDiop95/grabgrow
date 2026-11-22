--!strict
-- Ressources sacrées (T10.3, T10-D03, D-035) : configuration DÉDIÉE, hors de
-- ResourceConfig.
--
-- Conséquences voulues (D-035) :
--   * le Journal (CollectionJournalRules) ne les compte pas : 20/20 inchangé ;
--   * la règle d'accès aux sites (ressources ordinaires du monde) est
--     inchangée ;
--   * SellService ne les vend jamais avec le sac (identifiants inconnus de
--     ResourceConfig, D-012, D-014) : vente et consommation dédiées dans un
--     lot ultérieur.
--
-- Récompense : `rewardUnits` unités, une seule fois par profil, réclamées à
-- la terrasse du site après la première victoire (régime R1). Chaque unité
-- occupe `bagSlotsPerUnit` place(s) de sac (règle actuelle : 1).
--
-- Vente et améliorations spéciales (T10.5a, D-037, D-038) :
--   * `sellValue` : Coins par unité, hypothèse S2 (k = 2) validée pour test
--     le 2026-11-22 ; Multiplier NON appliqué ; stats.totalSales inchangé ;
--   * `Upgrades` : régime R-1, une amélioration à un seul niveau par monde,
--     coût = `cost` unités de la ressource du monde ; acquisition persistée
--     dans achievements["sacred_upgrade_<id>"] (U-A, schéma v3).
-- Valeurs = HYPOTHÈSES de départ, à confirmer en test réel.
--
-- Les identifiants sont persistés dans profile.inventory.resources : ne pas
-- les renommer sans migration.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

-- Catégorie distincte de Common à Epic (D-035) : pas de spawnWeight, pas de
-- nœud ordinaire, hors du Journal.
local RARITY = "Sacred"

export type Definition = {
	siteId: string,
	worldId: string,
	rarity: string,
	nameKey: string,
	rewardUnits: number,
	bagSlotsPerUnit: number,
	sellValue: number,
}

-- Effet d'une amélioration spéciale (lu par SacredUpgradeRules) :
--   add      : ajouté à la statistique ;
--   multiply : facteur appliqué à la statistique ;
--   display  : aucun effet de jeu côté serveur (affichage client).
export type UpgradeDefinition = {
	resourceId: string,
	cost: number,
	stat: string,
	add: number?,
	multiply: number?,
	nameKey: string,
	order: number,
}

local Resources: { [string]: Definition } = {
	sacred_heartwood_seed = {
		siteId = "RootSanctuary",
		worldId = "GreenValley",
		rarity = RARITY,
		nameKey = "sacred.heartwood_seed",
		rewardUnits = 3,
		bagSlotsPerUnit = 1,
		sellValue = 198,
	},
	sacred_sun_relic = {
		siteId = "SunTemple",
		worldId = "GoldenDesert",
		rarity = RARITY,
		nameKey = "sacred.sun_relic",
		rewardUnits = 3,
		bagSlotsPerUnit = 1,
		sellValue = 868,
	},
	sacred_frost_heart = {
		siteId = "FrostAltar",
		worldId = "FrozenPeaks",
		rarity = RARITY,
		nameKey = "sacred.frost_heart",
		rewardUnits = 3,
		bagSlotsPerUnit = 1,
		sellValue = 5840,
	},
	sacred_astral_essence = {
		siteId = "AstralSanctuary",
		worldId = "MysticWorld",
		rarity = RARITY,
		nameKey = "sacred.astral_essence",
		rewardUnits = 3,
		bagSlotsPerUnit = 1,
		sellValue = 27992,
	},
}

-- Index site -> identifiant, dérivé (aucune seconde table à maintenir).
local BySite: { [string]: string } = {}
for resourceId, definition in pairs(Resources) do
	BySite[definition.siteId] = resourceId
end

-- Ordre d'affichage stable (ordre des mondes).
local Order = {
	"sacred_heartwood_seed",
	"sacred_sun_relic",
	"sacred_frost_heart",
	"sacred_astral_essence",
}

-- Préfixe des clés d'acquisition dans profile.achievements (U-A, D-037).
-- Ne pas renommer : clés persistées.
local UPGRADE_PREFIX = "sacred_upgrade_"

-- Statistiques reconnues par SacredUpgradeRules.
local Stat = {
	CollectRange = "collectRangeStuds",
	CollectInterval = "collectIntervalSeconds",
	Capacity = "capacity",
	Compass = "compass",
}

local Upgrades: { [string]: UpgradeDefinition } = {
	sacred_magnet = {
		resourceId = "sacred_heartwood_seed",
		cost = 3,
		stat = Stat.CollectRange,
		add = 2, -- studs, cumulable avec Magnet
		nameKey = "sacred_upgrade.magnet",
		order = 1,
	},
	sacred_grabber = {
		resourceId = "sacred_sun_relic",
		cost = 3,
		stat = Stat.CollectInterval,
		multiply = 0.95, -- −5 % d'intervalle
		nameKey = "sacred_upgrade.grabber",
		order = 2,
	},
	sacred_backpack = {
		resourceId = "sacred_frost_heart",
		cost = 3,
		stat = Stat.Capacity,
		multiply = 1.10, -- +10 % de la capacité courante, arrondi inférieur
		nameKey = "sacred_upgrade.backpack",
		order = 3,
	},
	sacred_compass = {
		resourceId = "sacred_astral_essence",
		cost = 3,
		stat = Stat.Compass, -- ressources Rare/Epic proches signalées (client)
		nameKey = "sacred_upgrade.compass",
		order = 4,
	},
}

local UpgradeOrder = { "sacred_magnet", "sacred_grabber", "sacred_backpack", "sacred_compass" }

-- Boussole des sanctuaires (T10.5b) : affichage client seulement, aucun effet
-- serveur. HYPOTHÈSES de départ, à vérifier sur mobile (lisibilité, coût).
local Compass = {
	radiusStuds = 150, -- nœuds signalés dans ce rayon
	maxMarkers = 3, -- marqueurs affichés au plus
	refreshSeconds = 0.5, -- recherche périodique, jamais à chaque image
	rarities = { Rare = true, Epic = true },
}

return TableUtil.deepFreeze({
	Rarity = RARITY,
	Resources = Resources,
	BySite = BySite,
	Order = Order,
	UpgradePrefix = UPGRADE_PREFIX,
	Stat = Stat,
	Upgrades = Upgrades,
	UpgradeOrder = UpgradeOrder,
	Compass = Compass,
})
