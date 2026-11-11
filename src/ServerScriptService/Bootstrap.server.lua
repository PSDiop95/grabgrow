--!strict
-- Point d'entrée du serveur : construit les services et les démarre.
-- T1 : profils joueurs. T2 : collecte et inventaire.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local CollectionSecurityConfig = require(ServerStorage.ServerOnlyConfig.CollectionSecurityConfig)
local CollectionService = require(script.Parent.Services.CollectionService)
local InventoryService = require(script.Parent.Services.InventoryService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local RateLimitService = require(script.Parent.Services.RateLimitService)
local MemoryDataStore = require(script.Parent.Systems.MemoryDataStore)
local PlayerSession = require(script.Parent.Systems.PlayerSession)
local ResourceNodes = require(script.Parent.Systems.ResourceNodes)
local ResourceSpawner = require(script.Parent.Systems.ResourceSpawner)

-- Choix du magasin. Le magasin en mémoire exige Studio ET le réglage
-- explicite : il ne peut pas s'activer sur un serveur publié.
local function createStore(): PlayerDataService.Store
	local isStudio = RunService:IsStudio()
	if isStudio and DataConfig.Studio.useMemoryStore then
		warn("[Bootstrap] Studio : profils en mémoire, perdus à l'arrêt (DataConfig.Studio.useMemoryStore)")
		return MemoryDataStore.new()
	end

	local storeName = if isStudio then DataConfig.Store.studioName else DataConfig.Store.name
	local ok, result = pcall(function(): any
		return DataStoreService:GetDataStore(storeName)
	end)
	if ok then
		print(`[Bootstrap] DataStore : {storeName}`)
		return result
	end

	-- Sans magasin, tout chargement échoue et les joueurs sont refusés :
	-- préférable à un profil vide qui écraserait une sauvegarde.
	warn(`[Bootstrap] DataStore {storeName} indisponible : {tostring(result)}`)
	return {
		UpdateAsync = function()
			error(`DataStore {storeName} indisponible`)
		end,
	}
end

-- game.JobId est vide dans Studio.
local serverId = if game.JobId ~= "" then game.JobId else `studio-{HttpService:GenerateGUID(false)}`

local playerDataService = PlayerDataService.new({
	store = createStore(),
	serverId = serverId,
	clock = os.time,
	wait = function(seconds: number)
		task.wait(seconds)
	end,
	spawn = function(callback: () -> ())
		task.spawn(callback)
	end,
	onSessionLost = PlayerSession.kickSessionLost,
})

-- Collecte et inventaire (T2) ---------------------------------------------

local remotes = Remotes.createAll()
local stateUpdated = remotes[Remotes.Name.StateUpdated]
local actionResult = remotes[Remotes.Name.ActionResult]

local spawner = ResourceSpawner.new({
	schedule = function(delaySeconds: number, callback: () -> ())
		task.delay(delaySeconds, callback)
	end,
	onStateChanged = ResourceNodes.applyState,
})
local nodeCount = ResourceNodes.start(spawner)

-- Position répliquée au serveur ; nil si le personnage est absent ou mort.
local function getCharacterPosition(userId: number): CollectionService.Position?
	local player = Players:GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = humanoid.RootPart
	if root == nil then
		return nil
	end
	local position = root.Position
	return { X = position.X, Y = position.Y, Z = position.Z }
end

local collectionService = CollectionService.new({
	playerData = playerDataService,
	inventory = InventoryService.new({ playerData = playerDataService }),
	spawner = spawner,
	rateLimit = RateLimitService.new({
		clock = os.clock,
		limits = CollectionSecurityConfig.RateLimits,
		logEveryRejections = CollectionSecurityConfig.RateLimitFeedback.logEveryRejections,
	}),
	clock = os.clock,
	getCharacterPosition = getCharacterPosition,
})

local function sendState(player: Player)
	local state = collectionService.GetClientState(player.UserId)
	if state then
		stateUpdated:FireClient(player, state)
	end
end

-- Seul le premier argument est lu ; tout ce qui vient du client est validé
-- par CollectionService.
remotes[Remotes.Name.RequestCollect].OnServerEvent:Connect(function(player: Player, payload: any)
	local result = collectionService.HandleRequest(player.UserId, payload)
	if result.silent then
		return
	end
	actionResult:FireClient(player, {
		action = Remotes.Action.Collect,
		ok = result.ok,
		code = result.code,
		resourceId = result.resourceId,
		resourceType = result.resourceType,
		amount = result.amount,
	})
	if result.ok then
		sendState(player)
	end
end)

local function onPlayerAdded(player: Player)
	-- Réapparition : le personnage change de place légitimement.
	player.CharacterAdded:Connect(function()
		collectionService.ResetTravelReference(player.UserId)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

PlayerSession.start(playerDataService, {
	onProfileLoaded = sendState,
	onPlayerRemoving = function(player: Player)
		collectionService.RemovePlayer(player.UserId)
	end,
})
print(`[Bootstrap] PlayerDataService démarré ; collecte : {nodeCount} ressource(s)`)
