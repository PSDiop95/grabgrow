--!strict
-- Point d'entrée du serveur : construit les services et les démarre.
-- T1 : profils joueurs uniquement.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local MemoryDataStore = require(script.Parent.Systems.MemoryDataStore)
local PlayerSession = require(script.Parent.Systems.PlayerSession)

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

PlayerSession.start(playerDataService)
print("[Bootstrap] PlayerDataService démarré")
