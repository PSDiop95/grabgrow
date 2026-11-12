--!strict
-- Point d'entrée du serveur : construit les services et les démarre.
-- T1 : profils joueurs. T2 : collecte et inventaire. T3 : vente et Coins.
-- T4 : améliorations et déblocage des mondes.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local CollectionSecurityConfig = require(ServerStorage.ServerOnlyConfig.CollectionSecurityConfig)
local SellSecurityConfig = require(ServerStorage.ServerOnlyConfig.SellSecurityConfig)
local EconomySecurityConfig = require(ServerStorage.ServerOnlyConfig.EconomySecurityConfig)
local CollectionService = require(script.Parent.Services.CollectionService)
local InventoryService = require(script.Parent.Services.InventoryService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local RateLimitService = require(script.Parent.Services.RateLimitService)
local SellService = require(script.Parent.Services.SellService)
local UpgradeService = require(script.Parent.Services.UpgradeService)
local WorldUnlockService = require(script.Parent.Services.WorldUnlockService)
local MemoryDataStore = require(script.Parent.Systems.MemoryDataStore)
local PlayerSession = require(script.Parent.Systems.PlayerSession)
local ResourceNodes = require(script.Parent.Systems.ResourceNodes)
local ResourceSpawner = require(script.Parent.Systems.ResourceSpawner)
local SellZones = require(script.Parent.Systems.SellZones)
local StudioTestPresets = require(script.Parent.Systems.StudioTestPresets)

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

-- Vente (T3) ---------------------------------------------------------------

local getSellZone, sellZoneCount = SellZones.start()
local sellService = SellService.new({
	playerData = playerDataService,
	rateLimit = RateLimitService.new({
		clock = os.clock,
		limits = SellSecurityConfig.RateLimits,
		logEveryRejections = SellSecurityConfig.RateLimitFeedback.logEveryRejections,
	}),
	getSellZone = getSellZone,
	getCharacterPosition = getCharacterPosition,
	clock = os.clock,
})

-- Améliorations et mondes (T4) -------------------------------------------

local economyRateLimit = RateLimitService.new({
	clock = os.clock,
	limits = EconomySecurityConfig.RateLimits,
	logEveryRejections = EconomySecurityConfig.RateLimitFeedback.logEveryRejections,
})

local upgradeService: any

-- Boots : la vitesse est fixée par le serveur à partir du profil, jamais
-- par le client. Appelé au chargement du profil, à chaque apparition et
-- après un achat de Boots.
local function applyWalkSpeed(player: Player)
	local speed = upgradeService.GetWalkSpeed(player.UserId)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if speed ~= nil and humanoid ~= nil then
		humanoid.WalkSpeed = speed
	end
end

upgradeService = UpgradeService.new({
	playerData = playerDataService,
	rateLimit = economyRateLimit,
	clock = os.clock,
	onUpgraded = function(userId: number, upgradeId: string)
		if upgradeId == "Boots" then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				applyWalkSpeed(player)
			end
		end
	end,
})

local worldUnlockService = WorldUnlockService.new({
	playerData = playerDataService,
	rateLimit = economyRateLimit,
	clock = os.clock,
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

-- Seul le premier argument est lu ; montant et quantités sont calculés par
-- SellService à partir du profil serveur.
remotes[Remotes.Name.RequestSell].OnServerEvent:Connect(function(player: Player, payload: any)
	local result = sellService.HandleRequest(player.UserId, payload)
	if result.silent then
		return
	end
	actionResult:FireClient(player, {
		action = Remotes.Action.Sell,
		ok = result.ok,
		code = result.code,
		sellZoneId = result.sellZoneId,
		coinsEarned = result.coinsEarned,
		quantitySold = result.quantitySold,
	})
	if result.ok then
		sendState(player)
	end
end)

-- Seul le premier argument est lu ; prix, niveau et effet sont calculés
-- par UpgradeService à partir du profil serveur et d'UpgradeConfig.
remotes[Remotes.Name.RequestUpgrade].OnServerEvent:Connect(function(player: Player, payload: any)
	local result = upgradeService.HandleRequest(player.UserId, payload)
	if result.silent then
		return
	end
	actionResult:FireClient(player, {
		action = Remotes.Action.Upgrade,
		ok = result.ok,
		code = result.code,
		upgradeId = result.upgradeId,
		level = result.level,
		coinsSpent = result.coinsSpent,
	})
	if result.ok then
		sendState(player)
	end
end)

-- Seul le premier argument est lu ; conditions et coût viennent de WorldConfig.
remotes[Remotes.Name.RequestUnlockWorld].OnServerEvent:Connect(function(player: Player, payload: any)
	local result = worldUnlockService.HandleRequest(player.UserId, payload)
	if result.silent then
		return
	end
	actionResult:FireClient(player, {
		action = Remotes.Action.UnlockWorld,
		ok = result.ok,
		code = result.code,
		worldId = result.worldId,
		coinsSpent = result.coinsSpent,
	})
	if result.ok then
		sendState(player)
	end
end)

local function onPlayerAdded(player: Player)
	-- Réapparition : le personnage change de place légitimement, et sa
	-- vitesse repart de la valeur par défaut de Roblox.
	player.CharacterAdded:Connect(function(character: Model)
		collectionService.ResetTravelReference(player.UserId)
		character:WaitForChild("Humanoid", 10)
		applyWalkSpeed(player)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Outil de test manuel T4, STUDIO UNIQUEMENT ------------------------------
-- BindableFunction dans ServerStorage (jamais répliquée au client). Usage,
-- barre de commande de Studio en contexte Serveur pendant Play :
--   game.ServerStorage.StudioTestHooks.ApplyPreset:Invoke("U1")
-- Liste : docs/tests/TEST_STRATEGY.md (préréglages T4).
if RunService:IsStudio() then
	local folder = Instance.new("Folder")
	folder.Name = "StudioTestHooks"
	local applyPreset = Instance.new("BindableFunction")
	applyPreset.Name = "ApplyPreset"
	applyPreset.OnInvoke = function(name: any, target: any): string
		local player: Player? = if typeof(target) == "Instance" and target:IsA("Player")
			then target
			else Players:GetPlayers()[1]
		if player == nil then
			return "aucun joueur"
		end
		local ok, reason = StudioTestPresets.apply(playerDataService, player.UserId, tostring(name))
		if not ok then
			warn(`[StudioTest] {player.Name} : préréglage {tostring(name)} refusé ({tostring(reason)})`)
			return `refusé : {tostring(reason)}`
		end
		local description = StudioTestPresets.Presets[tostring(name)].description
		warn(`[StudioTest] {player.Name} : préréglage {tostring(name)} appliqué ({description})`)
		applyWalkSpeed(player)
		sendState(player)
		return `OK : {description}`
	end
	applyPreset.Parent = folder
	folder.Parent = ServerStorage
	print(`[StudioTest] préréglages disponibles : {table.concat(StudioTestPresets.names(), ", ")}`)
end

PlayerSession.start(playerDataService, {
	onProfileLoaded = function(player: Player)
		applyWalkSpeed(player)
		sendState(player)
	end,
	onPlayerRemoving = function(player: Player)
		collectionService.RemovePlayer(player.UserId)
		sellService.RemovePlayer(player.UserId)
		upgradeService.RemovePlayer(player.UserId)
		worldUnlockService.RemovePlayer(player.UserId)
	end,
})
print(`[Bootstrap] PlayerDataService démarré ; collecte : {nodeCount} ressource(s) ; vente : {sellZoneCount} zone(s)`)
