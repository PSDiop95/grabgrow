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
	-- Serveur -> Client. Payload : { action, ok, code, ... }.
	--   Collect : resourceId?, resourceType?, amount?
	--   Sell    : sellZoneId?, coinsEarned, quantitySold
	ActionResult = "ActionResult",
	-- Serveur -> Client. Payload : état public du joueur (voir
	-- CollectionService.GetClientState).
	StateUpdated = "StateUpdated",
})

Remotes.Action = table.freeze({
	Collect = "Collect",
	Sell = "Sell",
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
