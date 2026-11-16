--!strict
-- Journal de collection (T8.6, D-022). Logique pure, partagée :
--   * le serveur marque une découverte dans le brouillon du profil, DANS la
--     mutation qui attribue la ressource (InventoryService.AddResource) ;
--   * le client calcule l'affichage (progression par monde, globale) à
--     partir de l'ensemble `discovered` envoyé par le serveur (StateUpdated).
--
-- Catalogue : dérivé de ResourceConfig (champ worldId) et de WorldConfig
-- (ordre des mondes). Aucune liste de ressources ici ni ailleurs.
-- Totaux et pourcentages : toujours recalculés, jamais sauvegardés.
-- Un identifiant absent de ResourceConfig n'est jamais compté.
-- Aucune récompense : le journal est strictement informatif (D-022).

local ResourceConfig = require(script.Parent.Parent.Config.ResourceConfig)
local WorldConfig = require(script.Parent.Parent.Config.WorldConfig)

local CollectionJournalRules = {}

-- Ordre d'affichage des raretés (ResourceConfig.rarity).
CollectionJournalRules.RARITY_ORDER = table.freeze({ "Common", "Uncommon", "Rare", "Epic" })

local RARITY_RANK: { [string]: number } = {}
for rank, rarity in ipairs(CollectionJournalRules.RARITY_ORDER) do
	RARITY_RANK[rarity] = rank
end

export type CatalogWorld = {
	worldId: string,
	resourceIds: { string },
}

export type WorldSummary = {
	worldId: string,
	discovered: number,
	total: number,
	percent: number,
}

export type Summary = {
	worlds: { WorldSummary },
	discovered: number,
	total: number,
	percent: number,
}

local function rankOf(rarity: string): number
	return RARITY_RANK[rarity] or #CollectionJournalRules.RARITY_ORDER + 1
end

-- Construit une fois : mondes par WorldConfig.order, ressources par rareté,
-- puis valeur, puis identifiant (ordre stable).
local CATALOG: { CatalogWorld } = {}
do
	local byWorld: { [string]: { string } } = {}
	for resourceId, definition in pairs(ResourceConfig) do
		local list = byWorld[definition.worldId]
		if list == nil then
			list = {}
			byWorld[definition.worldId] = list
		end
		table.insert(list, resourceId)
	end
	local worldIds: { string } = {}
	for worldId in pairs(WorldConfig) do
		table.insert(worldIds, worldId)
	end
	table.sort(worldIds, function(a: string, b: string): boolean
		return WorldConfig[a].order < WorldConfig[b].order
	end)
	for _, worldId in ipairs(worldIds) do
		local resourceIds = byWorld[worldId] or {}
		table.sort(resourceIds, function(a: string, b: string): boolean
			local left, right = ResourceConfig[a], ResourceConfig[b]
			local rankA, rankB = rankOf(left.rarity), rankOf(right.rarity)
			if rankA ~= rankB then
				return rankA < rankB
			end
			if left.sellValue ~= right.sellValue then
				return left.sellValue < right.sellValue
			end
			return a < b
		end)
		table.insert(CATALOG, { worldId = worldId, resourceIds = table.freeze(resourceIds) })
	end
	for _, world in ipairs(CATALOG) do
		table.freeze(world)
	end
	table.freeze(CATALOG)
end

-- Mondes (ordre de WorldConfig) et leurs ressources (lecture seule).
function CollectionJournalRules.catalog(): { CatalogWorld }
	return CATALOG
end

-- Pourcentage entier arrondi à l'unité inférieure : 100 seulement si
-- tout est découvert.
local function percentOf(discovered: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.floor(discovered * 100 / total)
end
CollectionJournalRules.percentOf = percentOf

-- Une ressource du catalogue est-elle découverte ? `discovered` peut venir
-- du profil ou de l'état client ; toute valeur autre que `true` compte comme
-- non découverte.
function CollectionJournalRules.isDiscovered(discovered: any, resourceId: string): boolean
	return type(discovered) == "table" and ResourceConfig[resourceId] ~= nil and discovered[resourceId] == true
end

-- Résumé par monde et global. Les identifiants inconnus de ResourceConfig
-- sont ignorés ; `discovered` illisible = rien de découvert.
function CollectionJournalRules.summarize(discovered: any): Summary
	local worlds: { WorldSummary } = {}
	local totalDiscovered, total = 0, 0
	for _, world in ipairs(CATALOG) do
		local count = 0
		for _, resourceId in ipairs(world.resourceIds) do
			if CollectionJournalRules.isDiscovered(discovered, resourceId) then
				count += 1
			end
		end
		local worldTotal = #world.resourceIds
		table.insert(worlds, {
			worldId = world.worldId,
			discovered = count,
			total = worldTotal,
			percent = percentOf(count, worldTotal),
		})
		totalDiscovered += count
		total += worldTotal
	end
	return {
		worlds = worlds,
		discovered = totalDiscovered,
		total = total,
		percent = percentOf(totalDiscovered, total),
	}
end

-- SERVEUR : à appeler uniquement dans un mutateur de
-- PlayerDataService.Update, après l'attribution réussie de `resourceId`.
-- Retourne true s'il s'agit d'une première découverte. Ressource inconnue :
-- rien n'est ajouté (false). Section absente ou illisible : erreur, la
-- mutation entière est annulée (jamais de ressource sans découverte).
function CollectionJournalRules.markDiscovered(draft: any, resourceId: string): boolean
	if ResourceConfig[resourceId] == nil then
		return false
	end
	local discovered = draft.collection.discoveredResources
	if discovered[resourceId] == true then
		return false
	end
	discovered[resourceId] = true
	return true
end

-- Copie filtrée pour le client : seulement les identifiants du catalogue.
function CollectionJournalRules.publicView(discovered: any): { [string]: boolean }
	local view: { [string]: boolean } = {}
	if type(discovered) ~= "table" then
		return view
	end
	for resourceId in pairs(ResourceConfig) do
		if discovered[resourceId] == true then
			view[resourceId] = true
		end
	end
	return view
end

return CollectionJournalRules
