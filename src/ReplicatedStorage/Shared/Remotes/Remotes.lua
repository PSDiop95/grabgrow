--!strict
-- Point unique de création et d'accès aux RemoteEvents, et codes de
-- résultat partagés client/serveur (architecture 6.1 et 6.3).
--
-- Les instances sont créées par le serveur au démarrage, dans
-- ReplicatedStorage.Remotes. Le client les attend avec `waitFor`.
-- Aucun RemoteEvent par ressource : un seul par action.

local Remotes = {}

Remotes.FOLDER_NAME = "Remotes"

Remotes.Name = table.freeze({
	-- Client -> Serveur. Payload : { resourceId = "green_leaf_001" }.
	RequestCollect = "RequestCollect",
	-- Client -> Serveur. Payload : { sellZoneId = "GreenValley_Main" } (T3).
	RequestSell = "RequestSell",
	-- Client -> Serveur. Payload : { upgradeId = "Backpack" } (T4). Jamais
	-- de prix, de niveau ni d'effet : tout est recalculé par le serveur.
	RequestUpgrade = "RequestUpgrade",
	-- Client -> Serveur. Payload : { worldId = "GoldenDesert" } (T4).
	RequestUnlockWorld = "RequestUnlockWorld",
	-- Client -> Serveur. Payload : { worldId = "GoldenDesert" } (T8, D-021).
	-- Le serveur choisit la destination (point d'arrivée de la carte) et
	-- déplace lui-même le personnage ; jamais de position du client.
	TravelToWorld = "TravelToWorld",
	-- Serveur -> Client. Payload : { action, ok, code, ... }.
	--   Collect : resourceId?, resourceType?, amount?
	--   Sell    : sellZoneId?, coinsEarned, quantitySold
	--   Upgrade : upgradeId?, level?, coinsSpent
	--   UnlockWorld : worldId?, coinsSpent
	--   Travel  : worldId? (T8)
	--   Achievement : achievementId, coinsEarned (T7, envoyé par le serveur
	--                 seul, après une action validée ; aucune demande client)
	ActionResult = "ActionResult",
	-- Serveur -> Client. Payload : état public du joueur (voir
	-- CollectionService.GetClientState).
	StateUpdated = "StateUpdated",
})

Remotes.Action = table.freeze({
	Collect = "Collect",
	Sell = "Sell",
	Upgrade = "Upgrade",
	UnlockWorld = "UnlockWorld",
	Achievement = "Achievement",
	Travel = "Travel",
})

Remotes.ResultCode = table.freeze({
	Success = "SUCCESS",
	InvalidTarget = "INVALID_TARGET", -- payload invalide ou ressource inconnue
	TooFar = "TOO_FAR",
	Cooldown = "COOLDOWN",
	InventoryFull = "INVENTORY_FULL",
	ResourceUnavailable = "RESOURCE_UNAVAILABLE", -- déjà collectée, en réapparition
	ProfileNotLoaded = "PROFILE_NOT_LOADED",
	NoCharacter = "NO_CHARACTER", -- personnage absent ou mort
	NothingToSell = "NOTHING_TO_SELL", -- sac vide ou sans ressource vendable (T3)
	InsufficientFunds = "INSUFFICIENT_FUNDS", -- solde insuffisant (T4)
	MaxLevel = "MAX_LEVEL", -- amélioration déjà au niveau maximum (T4)
	AlreadyUnlocked = "ALREADY_UNLOCKED", -- monde déjà débloqué (T4)
	RequirementNotMet = "REQUIREMENT_NOT_MET", -- monde précédent ou niveau de Backpack manquant (T4)
	WorldLocked = "WORLD_LOCKED", -- monde de la ressource ou destination non débloqué (T8)
	WorldUnavailable = "WORLD_UNAVAILABLE", -- monde débloqué mais sans point d'arrivée sur la carte (T8)
	RateLimited = "RATE_LIMITED",
	InternalError = "INTERNAL_ERROR",
})

-- Serveur uniquement : crée le dossier et tous les RemoteEvents.
function Remotes.createAll(): { [string]: RemoteEvent }
	local replicatedStorage = game:GetService("ReplicatedStorage")
	assert(game:GetService("RunService"):IsServer(), "Remotes.createAll : serveur uniquement")
	assert(replicatedStorage:FindFirstChild(Remotes.FOLDER_NAME) == nil, "Remotes.createAll appelé deux fois")

	local folder = Instance.new("Folder")
	folder.Name = Remotes.FOLDER_NAME
	local events: { [string]: RemoteEvent } = {}
	for _, name in pairs(Remotes.Name) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		events[name] = event
	end
	folder.Parent = replicatedStorage
	return events
end

-- Client : attend un RemoteEvent créé par le serveur.
function Remotes.waitFor(name: string): RemoteEvent
	local folder = game:GetService("ReplicatedStorage"):WaitForChild(Remotes.FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
