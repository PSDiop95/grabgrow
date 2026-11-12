--!strict
-- Lance les tests automatisés au démarrage du serveur, dans Studio uniquement.
-- Résultats dans la fenêtre Output. N'exécute rien en production.
-- Aucun test ne touche le DataStore réel : les suites injectent un magasin
-- en mémoire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ConfigTests = require(script.Parent.ConfigTests)
local DataSchemaTests = require(script.Parent.DataSchemaTests)
local PlayerDataServiceTests = require(script.Parent.PlayerDataServiceTests)
local InventoryServiceTests = require(script.Parent.InventoryServiceTests)
local ResourceSpawnerTests = require(script.Parent.ResourceSpawnerTests)
local CollectionServiceTests = require(script.Parent.CollectionServiceTests)
local SellServiceTests = require(script.Parent.SellServiceTests)

local GameConfig = require(Config.GameConfig)
local ResourceConfig = require(Config.ResourceConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local WorldConfig = require(Config.WorldConfig)
local DataConfig = require(Config.DataConfig)
local DataSchema = require(ServerScriptService.Systems.DataSchema)
local MemoryDataStore = require(ServerScriptService.Systems.MemoryDataStore)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local InventoryService = require(ServerScriptService.Services.InventoryService)
local RateLimitService = require(ServerScriptService.Services.RateLimitService)
local CollectionService = require(ServerScriptService.Services.CollectionService)
local SellService = require(ServerScriptService.Services.SellService)
local ResourceSpawner = require(ServerScriptService.Systems.ResourceSpawner)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Localization = require(ReplicatedStorage.Shared.Util.Localization)
local SaleValue = require(ReplicatedStorage.Shared.Util.SaleValue)
local CollectionSecurityConfig = require(ServerStorage:WaitForChild("ServerOnlyConfig").CollectionSecurityConfig)
local SellSecurityConfig = require(ServerStorage:WaitForChild("ServerOnlyConfig").SellSecurityConfig)

local totalFailures = 0

local function report(suiteName: string, failures: { string }, caseCount: number?)
	if #failures == 0 then
		local detail = if caseCount then ` ({caseCount} cas)` else ""
		print(`[Tests] {suiteName} : OK{detail}`)
		return
	end
	totalFailures += #failures
	for _, message in ipairs(failures) do
		warn(`[Tests] {suiteName} ÉCHEC : {message}`)
	end
	warn(`[Tests] {suiteName} : {#failures} échec(s)`)
end

report(
	"ConfigTests",
	ConfigTests.run({
		GameConfig = GameConfig,
		ResourceConfig = ResourceConfig,
		UpgradeConfig = UpgradeConfig,
		WorldConfig = WorldConfig,
		CollectionSecurityConfig = CollectionSecurityConfig,
		SellSecurityConfig = SellSecurityConfig,
		Localization = Localization,
	})
)

report(
	"DataSchemaTests",
	DataSchemaTests.run({
		DataSchema = DataSchema,
		DataConfig = DataConfig,
		GameConfig = GameConfig,
		UpgradeConfig = UpgradeConfig,
		WorldConfig = WorldConfig,
	})
)

report(
	"PlayerDataServiceTests",
	PlayerDataServiceTests.run({
		PlayerDataService = PlayerDataService,
		MemoryDataStore = MemoryDataStore,
		DataSchema = DataSchema,
		DataConfig = DataConfig,
	})
)

report(
	"InventoryServiceTests",
	InventoryServiceTests.run({
		InventoryService = InventoryService,
		PlayerDataService = PlayerDataService,
		MemoryDataStore = MemoryDataStore,
		DataSchema = DataSchema,
		ResourceConfig = ResourceConfig,
		UpgradeConfig = UpgradeConfig,
	})
)

report(
	"ResourceSpawnerTests",
	ResourceSpawnerTests.run({
		ResourceSpawner = ResourceSpawner,
		RateLimitService = RateLimitService,
		ResourceConfig = ResourceConfig,
	})
)

report(
	"CollectionServiceTests",
	CollectionServiceTests.run({
		CollectionService = CollectionService,
		InventoryService = InventoryService,
		PlayerDataService = PlayerDataService,
		RateLimitService = RateLimitService,
		ResourceSpawner = ResourceSpawner,
		MemoryDataStore = MemoryDataStore,
		DataSchema = DataSchema,
		GameConfig = GameConfig,
		ResourceConfig = ResourceConfig,
		UpgradeConfig = UpgradeConfig,
		CollectionSecurityConfig = CollectionSecurityConfig,
		Remotes = Remotes,
	})
)

report(
	"SellServiceTests",
	SellServiceTests.run({
		SellService = SellService,
		SaleValue = SaleValue,
		CollectionService = CollectionService,
		InventoryService = InventoryService,
		PlayerDataService = PlayerDataService,
		RateLimitService = RateLimitService,
		ResourceSpawner = ResourceSpawner,
		MemoryDataStore = MemoryDataStore,
		DataSchema = DataSchema,
		GameConfig = GameConfig,
		ResourceConfig = ResourceConfig,
		UpgradeConfig = UpgradeConfig,
		CollectionSecurityConfig = CollectionSecurityConfig,
		SellSecurityConfig = SellSecurityConfig,
		Remotes = Remotes,
	})
)

if totalFailures == 0 then
	print("[Tests] TOUS LES TESTS : OK")
else
	warn(`[Tests] TOTAL : {totalFailures} échec(s)`)
end
