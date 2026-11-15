--!strict
-- Préréglages de profil pour les tests manuels T4 (U1 à U10) et T5.3 (O_*).
-- OUTIL DE TEST, STUDIO UNIQUEMENT : Bootstrap ne le branche que si
-- RunService:IsStudio() est vrai, via une BindableFunction placée dans
-- ServerStorage (jamais répliquée, inaccessible au client). Aucun effet sur
-- un serveur publié.
--
-- Un préréglage fixe l'état d'un profil chargé (solde, niveaux, mondes,
-- sac) par PlayerDataService.Update : le schéma valide chaque valeur.
-- Il ne modifie AUCUNE configuration économique (prix, coûts, effets) et
-- ne passe pas par EconomyService : ce n'est pas une transaction de jeu.
-- Dans Studio, les profils vivent en mémoire ou dans le DataStore de test
-- (`DataConfig.Store.studioName`), jamais dans le DataStore de production.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local PlayerDataService = require(script.Parent.Parent.Services.PlayerDataService)
local DataSchema = require(script.Parent.DataSchema)

local StudioTestPresets = {}

export type Preset = {
	description: string,
	coins: number,
	-- Niveaux par amélioration (clés de UpgradeConfig) ; absents = départ.
	upgrades: { [string]: number }?,
	-- Mondes débloqués en plus du monde de départ.
	worlds: { string }?,
	-- Contenu du sac ; absent = sac vide.
	resources: { [string]: number }?,
	-- T5.3 : statistiques (clés de profile.stats) ; absentes = 0.
	stats: { [string]: number }?,
}

-- Chaque préréglage remet d'abord le profil à l'état d'un nouveau joueur
-- (statistiques comprises), puis applique ses valeurs.
-- Profils de test uniquement : la remise à zéro vide aussi le sac, y compris
-- d'éventuelles ressources inconnues (règle D-008 non applicable ici).
StudioTestPresets.Presets = table.freeze({
	reset = { description = "Nouveau joueur", coins = 0 },
	U1 = { description = "Backpack 2 tout juste payable", coins = 75 },
	U2 = { description = "Grabber 2 tout juste payable", coins = 150 },
	U3 = { description = "Magnet 1 tout juste payable", coins = 200 },
	U4 = { description = "Boots 2 tout juste payable", coins = 250 },
	U5 = {
		description = "Multiplier 2 payable, sac de 60 Coins de base",
		coins = 300,
		resources = { green_leaf = 10, wood = 10, stone = 10 },
	},
	U6 = { description = "Aucune amélioration payable", coins = 50 },
	U7_locked = {
		description = "Golden Desert : Coins suffisants, Backpack 4 insuffisant",
		coins = 1_500,
		upgrades = { Backpack = 4 },
	},
	U7_ready = {
		description = "Golden Desert débloquable (Backpack 5, 1 500 Coins)",
		coins = 1_500,
		upgrades = { Backpack = 5 },
	},
	-- T8.4 : déblocage de Frozen Peaks (Backpack 8, 35 000 Coins).
	U7_peaks_locked = {
		description = "Frozen Peaks : Coins suffisants, Backpack 7 insuffisant",
		coins = 35_000,
		upgrades = { Backpack = 7 },
		worlds = { "GoldenDesert" },
	},
	U7_peaks_ready = {
		description = "Frozen Peaks débloquable (Backpack 8, 35 000 Coins)",
		coins = 35_000,
		upgrades = { Backpack = 8 },
		worlds = { "GoldenDesert" },
	},
	-- T8.5 : déblocage de Mystic World (Backpack 10, 250 000 Coins).
	U7_mystic_locked = {
		description = "Mystic World : Coins suffisants, Backpack 9 insuffisant",
		coins = 250_000,
		upgrades = { Backpack = 9 },
		worlds = { "GoldenDesert", "FrozenPeaks" },
	},
	U7_mystic_ready = {
		description = "Mystic World débloquable (Backpack 10, 250 000 Coins)",
		coins = 250_000,
		upgrades = { Backpack = 10 },
		worlds = { "GoldenDesert", "FrozenPeaks" },
	},
	U8 = {
		description = "État varié à sauvegarder puis restaurer",
		coins = 1_000,
		upgrades = { Backpack = 5, Grabber = 2, Magnet = 1, Boots = 2, Multiplier = 2 },
		worlds = { "GoldenDesert" },
		resources = { green_leaf = 3, wood = 2 },
	},
	U9 = {
		description = "Tous les états de bouton : payable, Manque, MAX",
		coins = 500,
		upgrades = { Backpack = 3, Grabber = 10 },
	},
	-- T5.3 : parcours B du guidage (joueurs déjà avancés).
	O_collected = {
		description = "Guidage : collecte déjà faite (étape Vendre)",
		coins = 0,
		resources = { green_leaf = 6, wood = 4 },
		stats = { totalResourcesCollected = 10 },
	},
	O_sold = {
		description = "Guidage : vente déjà faite, 60 Coins (étape Améliorer)",
		coins = 60,
		stats = { totalResourcesCollected = 30, totalSales = 1, totalCoinsEarned = 60 },
	},
	O_sold_rich = {
		description = "Guidage : vente faite, 120 Coins (Backpack payable)",
		coins = 120,
		stats = { totalResourcesCollected = 60, totalSales = 2, totalCoinsEarned = 120 },
	},
	O_upgraded = {
		description = "Guidage : amélioration déjà achetée (terminé)",
		coins = 20,
		upgrades = { Backpack = 2 },
		stats = { totalResourcesCollected = 60, totalSales = 2, totalCoinsEarned = 120, totalCoinsSpent = 100 },
	},
})

-- Applique le préréglage `name` au profil chargé de `userId`.
-- Retourne (true, nil) ou (false, raison).
function StudioTestPresets.apply(
	playerData: { Update: (userId: number, mutator: (draft: any) -> boolean?) -> PlayerDataService.Result },
	userId: number,
	name: string
): (boolean, string?)
	local preset = StudioTestPresets.Presets[name]
	if preset == nil then
		return false, `préréglage inconnu : {tostring(name)}`
	end
	local fresh = DataSchema.newProfile()
	local result = playerData.Update(userId, function(draft: any): boolean?
		draft.currencies = fresh.currencies
		draft.upgrades = fresh.upgrades
		draft.worlds = fresh.worlds
		draft.inventory = fresh.inventory
		draft.stats = fresh.stats
		draft.currencies.coins = preset.coins
		for upgradeId, level in pairs(preset.upgrades or {}) do
			local definition = UpgradeConfig[upgradeId]
			if definition == nil then
				return false
			end
			draft.upgrades[definition.profileKey] = level
		end
		for _, worldId in ipairs(preset.worlds or {}) do
			draft.worlds[worldId] = true
		end
		for resourceId, quantity in pairs(preset.resources or {}) do
			draft.inventory.resources[resourceId] = quantity
		end
		for statId, value in pairs(preset.stats or {}) do
			if draft.stats[statId] == nil then
				return false
			end
			draft.stats[statId] = value
		end
		return nil
	end)
	if not result.ok then
		return false, `{tostring(result.code)} {tostring(result.message or "")}`
	end
	return true, nil
end

-- Noms triés (aide affichée dans Output).
function StudioTestPresets.names(): { string }
	local names = {}
	for name in pairs(StudioTestPresets.Presets) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return StudioTestPresets
