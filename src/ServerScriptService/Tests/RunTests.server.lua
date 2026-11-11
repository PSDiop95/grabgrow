--!strict
-- Lance les tests automatisés au démarrage du serveur, dans Studio uniquement.
-- Résultats dans la fenêtre Output. N'exécute rien en production.
-- Aucun test ne touche le DataStore réel : PlayerDataServiceTests injecte
-- un magasin en mémoire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if not RunService:IsStudio() then
	return
end

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ConfigTests = require(script.Parent.ConfigTests)
local DataSchemaTests = require(script.Parent.DataSchemaTests)
local PlayerDataServiceTests = require(script.Parent.PlayerDataServiceTests)

local GameConfig = require(Config.GameConfig)
local ResourceConfig = require(Config.ResourceConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local WorldConfig = require(Config.WorldConfig)
local DataConfig = require(Config.DataConfig)
local DataSchema = require(ServerScriptService.Systems.DataSchema)
local MemoryDataStore = require(ServerScriptService.Systems.MemoryDataStore)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

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

if totalFailures == 0 then
	print("[Tests] TOUS LES TESTS : OK")
else
	warn(`[Tests] TOTAL : {totalFailures} échec(s)`)
end
