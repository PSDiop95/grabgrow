--!strict
-- Inventaire du joueur (sac) : lecture, capacité, ajout de ressources.
--
-- Aucune structure de stockage propre : les quantités vivent dans
-- `profile.inventory.resources` (PlayerDataService). Toute modification
-- passe par `PlayerDataService.Update`, donc reste atomique et validée par
-- le schéma. Aucune écriture DataStore n'est déclenchée ici : la stratégie
-- de sauvegarde reste celle de T1.
--
-- Capacité = UpgradeConfig.Backpack.levels[backpackLevel].value, puis
-- amélioration sacrée `sacred_backpack` si acquise (T10.5a, D-038 : +10 %,
-- arrondi inférieur ; SacredUpgradeRules).
-- Occupation = somme de toutes les quantités, y compris les ressources
-- inconnues de ResourceConfig conservées par D-008.
--
-- T8.6 (D-022) : la première attribution d'une ressource la marque
-- découverte dans le journal (CollectionJournalRules), dans la même mutation
-- que l'ajout : jamais de ressource sans découverte, ni l'inverse. Un refus
-- (sac plein, ressource inconnue, profil absent) ne marque rien.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local ResourceConfig = require(Config.ResourceConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local CollectionJournalRules = require(ReplicatedStorage.Shared.Util.CollectionJournalRules)
local SacredUpgradeRules = require(ReplicatedStorage.Shared.Util.SacredUpgradeRules)
local PlayerDataService = require(script.Parent.PlayerDataService)

local InventoryService = {}

InventoryService.Code = table.freeze({
	NotLoaded = "NotLoaded",
	InvalidResource = "InvalidResource",
	InvalidAmount = "InvalidAmount",
	InventoryFull = "InventoryFull",
	InternalError = "InternalError",
})

-- État simplifié, sans référence vers le profil.
export type State = {
	resources: { [string]: number },
	used: number,
	capacity: number,
	free: number,
}

export type AddResult = {
	ok: boolean,
	code: string?,
	-- Quantité réellement ajoutée (0 en cas de refus).
	granted: number,
	-- État après l'ajout (nil en cas de refus).
	state: State?,
	-- T8.6 : true si cet ajout est la première découverte de la ressource
	-- par ce joueur (false en cas de refus).
	firstDiscovery: boolean,
}

-- Sous-ensemble de PlayerDataService utilisé par ce service.
export type PlayerData = {
	GetData: (userId: number) -> any?,
	Update: (userId: number, mutator: (draft: any) -> boolean?) -> PlayerDataService.Result,
}

export type Dependencies = {
	playerData: PlayerData,
}

-- Capacité du sac pour un niveau de Backpack, ou nil si le niveau n'existe pas.
function InventoryService.capacityForLevel(backpackLevel: number): number?
	local level = UpgradeConfig.Backpack.levels[backpackLevel]
	if level == nil then
		return nil
	end
	return level.value
end

-- État de l'inventaire d'un profil. Ne modifie pas `profile`.
-- nil si le niveau de sac du profil est inconnu de UpgradeConfig.
function InventoryService.describe(profile: any): State?
	local baseCapacity = InventoryService.capacityForLevel(profile.upgrades.backpackLevel)
	if baseCapacity == nil then
		return nil
	end
	local capacity = SacredUpgradeRules.capacity(profile, baseCapacity)
	local resources: { [string]: number } = {}
	local used = 0
	for resourceId, quantity in pairs(profile.inventory.resources) do
		resources[resourceId] = quantity
		used += quantity
	end
	return {
		resources = resources,
		used = used,
		capacity = capacity,
		free = math.max(capacity - used, 0),
	}
end

local function refusal(code: string): AddResult
	return { ok = false, code = code, granted = 0, state = nil, firstDiscovery = false }
end

function InventoryService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData

	local service = {}

	-- État courant, ou nil si le profil n'est pas chargé.
	function service.GetState(userId: number): State?
		local profile = playerData.GetData(userId)
		if profile == nil then
			return nil
		end
		return InventoryService.describe(profile)
	end

	function service.GetCapacity(userId: number): number?
		local state = service.GetState(userId)
		return if state then state.capacity else nil
	end

	function service.GetFreeSpace(userId: number): number?
		local state = service.GetState(userId)
		return if state then state.free else nil
	end

	-- Ajoute jusqu'à `amount` unités de `resourceId`, dans la limite de
	-- l'espace libre : `granted` peut être inférieur à `amount`.
	-- Sac plein : refus (InventoryFull), rien ne change.
	-- Lecture de l'espace libre et écriture dans la même mise à jour : deux
	-- ajouts ne peuvent pas dépasser la capacité à eux deux.
	function service.AddResource(userId: number, resourceId: string, amount: number): AddResult
		if type(resourceId) ~= "string" or ResourceConfig[resourceId] == nil then
			return refusal(InventoryService.Code.InvalidResource)
		end
		-- NaN et l'infini échouent au test du modulo.
		if type(amount) ~= "number" or amount % 1 ~= 0 or amount < 1 then
			return refusal(InventoryService.Code.InvalidAmount)
		end

		local granted = 0
		local full = false
		local firstDiscovery = false
		local after: State? = nil
		local result = playerData.Update(userId, function(draft: any): boolean?
			local before = InventoryService.describe(draft)
			if before == nil then
				return false
			end
			if before.free <= 0 then
				full = true
				return false
			end
			granted = math.min(amount, before.free)
			local resources = draft.inventory.resources
			resources[resourceId] = (resources[resourceId] or 0) + granted
			draft.stats.totalResourcesCollected += granted
			firstDiscovery = CollectionJournalRules.markDiscovered(draft, resourceId)
			after = InventoryService.describe(draft)
			return nil
		end)

		if result.ok then
			return { ok = true, code = nil, granted = granted, state = after, firstDiscovery = firstDiscovery }
		end
		if result.code == PlayerDataService.Code.NotLoaded then
			return refusal(InventoryService.Code.NotLoaded)
		end
		if full then
			return refusal(InventoryService.Code.InventoryFull)
		end
		return refusal(InventoryService.Code.InternalError)
	end

	return service
end

return InventoryService
