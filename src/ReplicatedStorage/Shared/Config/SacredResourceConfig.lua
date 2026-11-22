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
-- AUCUNE valeur de vente ni coût d'amélioration ici : hypothèse S2 (k = 2)
-- pour les tests seulement, non validée (T10_3_SACRED_ECONOMY_SIMULATION.md).
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
}

local Resources: { [string]: Definition } = {
	sacred_heartwood_seed = {
		siteId = "RootSanctuary",
		worldId = "GreenValley",
		rarity = RARITY,
		nameKey = "sacred.heartwood_seed",
		rewardUnits = 3,
		bagSlotsPerUnit = 1,
	},
	sacred_sun_relic = {
		siteId = "SunTemple",
		worldId = "GoldenDesert",
		rarity = RARITY,
		nameKey = "sacred.sun_relic",
		rewardUnits = 3,
		bagSlotsPerUnit = 1,
	},
	sacred_frost_heart = {
		siteId = "FrostAltar",
		worldId = "FrozenPeaks",
		rarity = RARITY,
		nameKey = "sacred.frost_heart",
		rewardUnits = 3,
		bagSlotsPerUnit = 1,
	},
	sacred_astral_essence = {
		siteId = "AstralSanctuary",
		worldId = "MysticWorld",
		rarity = RARITY,
		nameKey = "sacred.astral_essence",
		rewardUnits = 3,
		bagSlotsPerUnit = 1,
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

return TableUtil.deepFreeze({
	Rarity = RARITY,
	Resources = Resources,
	BySite = BySite,
	Order = Order,
})
