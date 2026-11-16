--!strict
-- Point d'entrée du serveur : construit les services et les démarre.
-- T1 : profils joueurs. T2 : collecte et inventaire. T3 : vente et Coins.
-- T4 : améliorations et déblocage des mondes.
-- T6 : validation des déplacements, payloads communs, journal de sécurité,
-- contrôle de cohérence au chargement (D-019).
-- T7 : temps de jeu (A-21) et succès permanents (D-020).
-- T8 : voyage entre mondes fait par le serveur (D-021).

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
local MovementSecurityConfig = require(ServerStorage.ServerOnlyConfig.MovementSecurityConfig)
local SecurityLogConfig = require(ServerStorage.ServerOnlyConfig.SecurityLogConfig)
local TravelSecurityConfig = require(ServerStorage.ServerOnlyConfig.TravelSecurityConfig)
local AchievementService = require(script.Parent.Services.AchievementService)
local CollectionService = require(script.Parent.Services.CollectionService)
local InventoryService = require(script.Parent.Services.InventoryService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local RateLimitService = require(script.Parent.Services.RateLimitService)
local SecurityLog = require(script.Parent.Services.SecurityLog)
local SellService = require(script.Parent.Services.SellService)
local UpgradeService = require(script.Parent.Services.UpgradeService)
local WorldTravelService = require(script.Parent.Services.WorldTravelService)
local WorldUnlockService = require(script.Parent.Services.WorldUnlockService)
local MemoryDataStore = require(script.Parent.Systems.MemoryDataStore)
local MovementValidator = require(script.Parent.Systems.MovementValidator)
local ProfileAudit = require(script.Parent.Systems.ProfileAudit)
local PlayerSession = require(script.Parent.Systems.PlayerSession)
local ResourceNodes = require(script.Parent.Systems.ResourceNodes)
local ResourceSpawner = require(script.Parent.Systems.ResourceSpawner)
local SellZones = require(script.Parent.Systems.SellZones)
local StudioTestPresets = require(script.Parent.Systems.StudioTestPresets)
local WorldArrivals = require(script.Parent.Systems.WorldArrivals)

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
	-- T7 (A-21) : temps de jeu compté avec une horloge monotone.
	playClock = os.clock,
})

-- Sécurité (T6) -------------------------------------------------------------

local securityLog = SecurityLog.new({ clock = os.clock, config = SecurityLogConfig })
local movementValidator = MovementValidator.new(MovementSecurityConfig)

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
-- Les valeurs NaN ou infinies sont transmises telles quelles : services et
-- MovementValidator les refusent explicitement (T6).
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
	movement = movementValidator,
	security = securityLog,
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
	movement = movementValidator,
	security = securityLog,
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
	-- Référence du contrôle des déplacements : profil serveur (A-37).
	movementValidator.SetSpeed(player.UserId, speed)
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
	security = securityLog,
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
	security = securityLog,
})

-- Voyage entre mondes (T8, D-021) -----------------------------------------

-- Déplacement décidé par le SERVEUR : position d'arrivée lue sur la carte,
-- jamais envoyée par le client. Les références de déplacement repartent du
-- point d'arrivée, avec une courte grâce d'observation (positions encore
-- en transit) ; suspension et historique T6 conservés (Reset).
local function teleportCharacter(userId: number, target: WorldTravelService.Position): boolean
	local player = Players:GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local root = humanoid.RootPart
	if root == nil then
		return false
	end
	humanoid.Sit = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(target.X, target.Y, target.Z) * root.CFrame.Rotation
	movementValidator.Reset(userId, target, os.clock(), MovementSecurityConfig.ServerTeleport.graceSeconds)
	collectionService.ResetTravelReference(userId, target)
	return true
end

local worldTravelService = WorldTravelService.new({
	playerData = playerDataService,
	rateLimit = RateLimitService.new({
		clock = os.clock,
		limits = TravelSecurityConfig.RateLimits,
		logEveryRejections = TravelSecurityConfig.RateLimitFeedback.logEveryRejections,
	}),
	clock = os.clock,
	getArrival = function(worldId: string): WorldTravelService.Position?
		return WorldArrivals.find(worldId, TravelSecurityConfig.Arrival.heightStuds)
	end,
	teleport = teleportCharacter,
	security = securityLog,
})

-- Succès (T7, D-020) -------------------------------------------------------

local achievementService = AchievementService.new({ playerData = playerDataService })

-- Attribue les succès atteints et prévient le client. Appelé uniquement
-- après une action validée par le serveur, avant l'envoi de l'état (le
-- solde transmis inclut donc les récompenses).
local function grantAchievements(player: Player)
	for _, grant in ipairs(achievementService.Evaluate(player.UserId)) do
		actionResult:FireClient(player, {
			action = Remotes.Action.Achievement,
			ok = true,
			code = Remotes.ResultCode.Success,
			achievementId = grant.achievementId,
			coinsEarned = grant.reward,
		})
	end
end

local function sendState(player: Player)
	local state = collectionService.GetClientState(player.UserId)
	if state then
		stateUpdated:FireClient(player, state)
	end
end

-- Un seul argument attendu (le payload) ; les arguments supplémentaires
-- font refuser la demande (T6). Tout ce qui vient du client est validé
-- par CollectionService.
remotes[Remotes.Name.RequestCollect].OnServerEvent:Connect(function(player: Player, payload: any, ...: any)
	local result = collectionService.HandleRequest(player.UserId, payload, select("#", ...))
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
		-- T8.6 (D-022) : première découverte (journal), calculée par le serveur.
		firstDiscovery = result.firstDiscovery,
	})
	if result.ok then
		grantAchievements(player)
		sendState(player)
	end
end)

-- Seul le premier argument est lu ; montant et quantités sont calculés par
-- SellService à partir du profil serveur.
remotes[Remotes.Name.RequestSell].OnServerEvent:Connect(function(player: Player, payload: any, ...: any)
	local result = sellService.HandleRequest(player.UserId, payload, select("#", ...))
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
		grantAchievements(player)
		sendState(player)
	end
end)

-- Seul le premier argument est lu ; prix, niveau et effet sont calculés
-- par UpgradeService à partir du profil serveur et d'UpgradeConfig.
remotes[Remotes.Name.RequestUpgrade].OnServerEvent:Connect(function(player: Player, payload: any, ...: any)
	local result = upgradeService.HandleRequest(player.UserId, payload, select("#", ...))
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
		grantAchievements(player)
		sendState(player)
		-- T8.7 (D-023) : opération importante, sauvegarde différée et regroupée.
		playerDataService.RequestSave(player.UserId, "amélioration")
	end
end)

-- Seul le premier argument est lu ; conditions et coût viennent de WorldConfig.
remotes[Remotes.Name.RequestUnlockWorld].OnServerEvent:Connect(function(player: Player, payload: any, ...: any)
	local result = worldUnlockService.HandleRequest(player.UserId, payload, select("#", ...))
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
		grantAchievements(player)
		sendState(player)
		-- T8.7 (D-023) : opération importante, sauvegarde différée et regroupée.
		playerDataService.RequestSave(player.UserId, "déblocage de monde")
	end
end)

-- Seul le premier argument est lu ; destination et position viennent du
-- serveur (WorldConfig, profil, carte).
remotes[Remotes.Name.TravelToWorld].OnServerEvent:Connect(function(player: Player, payload: any, ...: any)
	local result = worldTravelService.HandleRequest(player.UserId, payload, select("#", ...))
	if result.silent then
		return
	end
	actionResult:FireClient(player, {
		action = Remotes.Action.Travel,
		ok = result.ok,
		code = result.code,
		worldId = result.worldId,
	})
end)

local function onPlayerAdded(player: Player)
	-- Réapparition : le personnage change de place légitimement, et sa
	-- vitesse repart de la valeur par défaut de Roblox.
	-- T6 : la nouvelle référence est le point d'apparition, placé par le
	-- SERVEUR, lu dès l'arrivée du personnage (avant que le client ne le
	-- déplace). Un « Reset » volontaire ne donne plus de collecte libre.
	player.CharacterAdded:Connect(function(character: Model)
		local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
		local spawnPosition: CollectionService.Position? = nil
		if root ~= nil and root:IsA("BasePart") then
			local position = root.Position
			spawnPosition = { X = position.X, Y = position.Y, Z = position.Z }
		end
		collectionService.ResetTravelReference(player.UserId, spawnPosition)
		movementValidator.Reset(player.UserId, spawnPosition, os.clock())
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

-- Échantillonnage des déplacements (T6) -----------------------------------
-- Une seule boucle pour tous les joueurs, à MovementSecurityConfig.Sampling
-- (4 Hz) : une lecture de position et quelques opérations par joueur.

-- Remet le personnage à une position validée par le serveur (R1). La
-- rotation est conservée, la vitesse annulée.
local function correctPosition(player: Player, target: MovementValidator.Position)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(target.X, target.Y, target.Z) * root.CFrame.Rotation
	collectionService.ResetTravelReference(player.UserId, target)
end

local function sampleMovement(player: Player, now: number)
	local position = getCharacterPosition(player.UserId)
	if position == nil then
		return
	end
	local verdict = movementValidator.Observe(player.UserId, position, now)
	if verdict.status == "anomaly" and verdict.newEpisode then
		securityLog.Record(player.UserId, SecurityLog.Type.MovementAnomaly, {
			kind = verdict.kind,
			excess = verdict.excess,
			episodes = verdict.recentEpisodes,
		})
	elseif verdict.status == "correct" and verdict.correctionPosition ~= nil then
		correctPosition(player, verdict.correctionPosition)
		securityLog.Record(player.UserId, SecurityLog.Type.MovementCorrection, {
			kind = verdict.kind,
			excess = verdict.excess,
			suspension = MovementSecurityConfig.Escalation.suspensionSeconds,
		})
	end
end

task.spawn(function()
	while true do
		task.wait(MovementSecurityConfig.Sampling.intervalSeconds)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, err = pcall(function()
				sampleMovement(player, now)
			end)
			if not ok then
				warn(`[Movement] échantillon du joueur {player.UserId} : {tostring(err)}`)
			end
		end
	end
end)

PlayerSession.start(playerDataService, {
	onProfileLoaded = function(player: Player)
		applyWalkSpeed(player)
		-- T7 : succès déjà atteints (profil v1 migré, par exemple).
		grantAchievements(player)
		sendState(player)
		-- T6 : contrôle de cohérence, journal seulement (aucune correction).
		local ok, issues = pcall(ProfileAudit.run, playerDataService.GetData(player.UserId))
		if ok then
			for _, issue in ipairs(issues) do
				securityLog.Record(player.UserId, SecurityLog.Type.DataInconsistency, issue)
			end
		else
			warn(`[Security] audit du profil {player.UserId} impossible : {tostring(issues)}`)
		end
	end,
	onPlayerRemoving = function(player: Player)
		collectionService.RemovePlayer(player.UserId)
		sellService.RemovePlayer(player.UserId)
		upgradeService.RemovePlayer(player.UserId)
		worldUnlockService.RemovePlayer(player.UserId)
		worldTravelService.RemovePlayer(player.UserId)
		movementValidator.Remove(player.UserId)
		securityLog.Remove(player.UserId)
	end,
})
print(`[Bootstrap] PlayerDataService démarré ; collecte : {nodeCount} ressource(s) ; vente : {sellZoneCount} zone(s)`)
