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
local EconomyServiceTests = require(script.Parent.EconomyServiceTests)
local UpgradeServiceTests = require(script.Parent.UpgradeServiceTests)
local HudTests = require(script.Parent.HudTests)
local FeedbackTests = require(script.Parent.FeedbackTests)
local OnboardingTests = require(script.Parent.OnboardingTests)
local LocalizationTests = require(script.Parent.LocalizationTests)
local MovementValidatorTests = require(script.Parent.MovementValidatorTests)
local SecurityTests = require(script.Parent.SecurityTests)
local PlayTimeTests = require(script.Parent.PlayTimeTests)
local AchievementTests = require(script.Parent.AchievementTests)
local WorldTravelServiceTests = require(script.Parent.WorldTravelServiceTests)
local TravelRulesTests = require(script.Parent.TravelRulesTests)
local CollectionJournalTests = require(script.Parent.CollectionJournalTests)
local AnalyticsTests = require(script.Parent.AnalyticsTests)
local ResourceFxTests = require(script.Parent.ResourceFxTests)

local GameConfig = require(Config.GameConfig)
local ResourceConfig = require(Config.ResourceConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local WorldConfig = require(Config.WorldConfig)
local ResourceVisualConfig = require(Config.ResourceVisualConfig)
local DataConfig = require(Config.DataConfig)
local DataSchema = require(ServerScriptService.Systems.DataSchema)
local MemoryDataStore = require(ServerScriptService.Systems.MemoryDataStore)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local InventoryService = require(ServerScriptService.Services.InventoryService)
local RateLimitService = require(ServerScriptService.Services.RateLimitService)
local CollectionService = require(ServerScriptService.Services.CollectionService)
local SellService = require(ServerScriptService.Services.SellService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local UpgradeService = require(ServerScriptService.Services.UpgradeService)
local WorldUnlockService = require(ServerScriptService.Services.WorldUnlockService)
local WorldTravelService = require(ServerScriptService.Services.WorldTravelService)
local ResourceSpawner = require(ServerScriptService.Systems.ResourceSpawner)
local StudioTestPresets = require(ServerScriptService.Systems.StudioTestPresets)
local MovementValidator = require(ServerScriptService.Systems.MovementValidator)
local PayloadValidator = require(ServerScriptService.Systems.PayloadValidator)
local ProfileAudit = require(ServerScriptService.Systems.ProfileAudit)
local SecurityLog = require(ServerScriptService.Services.SecurityLog)
local PlayTimeTracker = require(ServerScriptService.Systems.PlayTimeTracker)
local AchievementService = require(ServerScriptService.Services.AchievementService)
local AnalyticsService = require(ServerScriptService.Services.AnalyticsService)
local AchievementRules = require(ReplicatedStorage.Shared.Util.AchievementRules)
local AchievementConfig = require(Config.AchievementConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Localization = require(ReplicatedStorage.Shared.Util.Localization)
local SaleValue = require(ReplicatedStorage.Shared.Util.SaleValue)
local UpgradeMath = require(ReplicatedStorage.Shared.Util.UpgradeMath)
local BagDisplay = require(ReplicatedStorage.Shared.Util.BagDisplay)
local FeedbackRules = require(ReplicatedStorage.Shared.Util.FeedbackRules)
local OnboardingRules = require(ReplicatedStorage.Shared.Util.OnboardingRules)
local TravelRules = require(ReplicatedStorage.Shared.Util.TravelRules)
local CollectionJournalRules = require(ReplicatedStorage.Shared.Util.CollectionJournalRules)
local ResourceFxRules = require(ReplicatedStorage.Shared.Util.ResourceFxRules)
local ResourceVFXConfig = require(Config.ResourceVFXConfig)
local OnboardingConfig = require(Config.OnboardingConfig)
local FeedbackConfig = require(Config.FeedbackConfig)
local CollectionSecurityConfig = require(ServerStorage:WaitForChild("ServerOnlyConfig").CollectionSecurityConfig)
local SellSecurityConfig = require(ServerStorage:WaitForChild("ServerOnlyConfig").SellSecurityConfig)
local EconomySecurityConfig = require(ServerStorage:WaitForChild("ServerOnlyConfig").EconomySecurityConfig)
local MovementSecurityConfig = require(ServerStorage:WaitForChild("ServerOnlyConfig").MovementSecurityConfig)
local SecurityLogConfig = require(ServerStorage:WaitForChild("ServerOnlyConfig").SecurityLogConfig)
local TravelSecurityConfig = require(ServerStorage:WaitForChild("ServerOnlyConfig").TravelSecurityConfig)
local AnalyticsConfig = require(ServerStorage:WaitForChild("ServerOnlyConfig").AnalyticsConfig)

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
		EconomySecurityConfig = EconomySecurityConfig,
		Localization = Localization,
		ResourceVisualConfig = ResourceVisualConfig,
		TravelSecurityConfig = TravelSecurityConfig,
		MovementSecurityConfig = MovementSecurityConfig,
		Remotes = Remotes,
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

report(
	"EconomyServiceTests",
	EconomyServiceTests.run({
		EconomyService = EconomyService,
		SaleValue = SaleValue,
		DataSchema = DataSchema,
		UpgradeConfig = UpgradeConfig,
		GameConfig = GameConfig,
	})
)

report(
	"UpgradeServiceTests",
	UpgradeServiceTests.run({
		UpgradeService = UpgradeService,
		WorldUnlockService = WorldUnlockService,
		EconomyService = EconomyService,
		SellService = SellService,
		CollectionService = CollectionService,
		InventoryService = InventoryService,
		PlayerDataService = PlayerDataService,
		RateLimitService = RateLimitService,
		ResourceSpawner = ResourceSpawner,
		MemoryDataStore = MemoryDataStore,
		DataSchema = DataSchema,
		UpgradeMath = UpgradeMath,
		UpgradeConfig = UpgradeConfig,
		WorldConfig = WorldConfig,
		ResourceConfig = ResourceConfig,
		CollectionSecurityConfig = CollectionSecurityConfig,
		EconomySecurityConfig = EconomySecurityConfig,
		Remotes = Remotes,
		StudioTestPresets = StudioTestPresets,
	})
)

report(
	"HudTests",
	HudTests.run({
		BagDisplay = BagDisplay,
		InventoryService = InventoryService,
		DataSchema = DataSchema,
		UpgradeMath = UpgradeMath,
		Localization = Localization,
	})
)

report(
	"FeedbackTests",
	FeedbackTests.run({
		FeedbackRules = FeedbackRules,
		FeedbackConfig = FeedbackConfig,
		Remotes = Remotes,
		Localization = Localization,
		BagDisplay = BagDisplay,
	})
)

report(
	"OnboardingTests",
	OnboardingTests.run({
		OnboardingRules = OnboardingRules,
		OnboardingConfig = OnboardingConfig,
		Localization = Localization,
		UpgradeMath = UpgradeMath,
		UpgradeConfig = UpgradeConfig,
		DataSchema = DataSchema,
		PlayerDataService = PlayerDataService,
		InventoryService = InventoryService,
		CollectionService = CollectionService,
		SellService = SellService,
		UpgradeService = UpgradeService,
		WorldUnlockService = WorldUnlockService,
		ResourceSpawner = ResourceSpawner,
		MemoryDataStore = MemoryDataStore,
		Remotes = Remotes,
	})
)

report(
	"LocalizationTests",
	LocalizationTests.run({
		Localization = Localization,
		UpgradeConfig = UpgradeConfig,
		ResourceConfig = ResourceConfig,
		WorldConfig = WorldConfig,
		OnboardingRules = OnboardingRules,
	})
)

report(
	"MovementValidatorTests",
	MovementValidatorTests.run({
		MovementValidator = MovementValidator,
		MovementSecurityConfig = MovementSecurityConfig,
	})
)

report(
	"SecurityTests",
	SecurityTests.run({
		CollectionService = CollectionService,
		InventoryService = InventoryService,
		SellService = SellService,
		UpgradeService = UpgradeService,
		WorldUnlockService = WorldUnlockService,
		PlayerDataService = PlayerDataService,
		RateLimitService = RateLimitService,
		ResourceSpawner = ResourceSpawner,
		MemoryDataStore = MemoryDataStore,
		DataSchema = DataSchema,
		SaleValue = SaleValue,
		UpgradeMath = UpgradeMath,
		MovementValidator = MovementValidator,
		PayloadValidator = PayloadValidator,
		SecurityLog = SecurityLog,
		ProfileAudit = ProfileAudit,
		CollectionSecurityConfig = CollectionSecurityConfig,
		SellSecurityConfig = SellSecurityConfig,
		EconomySecurityConfig = EconomySecurityConfig,
		MovementSecurityConfig = MovementSecurityConfig,
		SecurityLogConfig = SecurityLogConfig,
		Remotes = Remotes,
	})
)

report(
	"PlayTimeTests",
	PlayTimeTests.run({
		PlayTimeTracker = PlayTimeTracker,
		PlayerDataService = PlayerDataService,
		MemoryDataStore = MemoryDataStore,
		DataConfig = DataConfig,
	})
)

report(
	"AchievementTests",
	AchievementTests.run({
		AchievementConfig = AchievementConfig,
		AchievementRules = AchievementRules,
		AchievementService = AchievementService,
		PlayerDataService = PlayerDataService,
		MemoryDataStore = MemoryDataStore,
		DataSchema = DataSchema,
		ProfileAudit = ProfileAudit,
		Localization = Localization,
		FeedbackRules = FeedbackRules,
		Remotes = Remotes,
	})
)

report(
	"WorldTravelServiceTests",
	WorldTravelServiceTests.run({
		WorldTravelService = WorldTravelService,
		CollectionService = CollectionService,
		InventoryService = InventoryService,
		PlayerDataService = PlayerDataService,
		RateLimitService = RateLimitService,
		ResourceSpawner = ResourceSpawner,
		MovementValidator = MovementValidator,
		MemoryDataStore = MemoryDataStore,
		DataSchema = DataSchema,
		UpgradeConfig = UpgradeConfig,
		TravelSecurityConfig = TravelSecurityConfig,
		MovementSecurityConfig = MovementSecurityConfig,
		CollectionSecurityConfig = CollectionSecurityConfig,
		SecurityLog = SecurityLog,
		Remotes = Remotes,
	})
)

report(
	"TravelRulesTests",
	TravelRulesTests.run({
		TravelRules = TravelRules,
		Localization = Localization,
		WorldConfig = WorldConfig,
		Remotes = Remotes,
	})
)

report(
	"CollectionJournalTests",
	CollectionJournalTests.run({
		CollectionJournalRules = CollectionJournalRules,
		DataSchema = DataSchema,
		DataConfig = DataConfig,
		PlayerDataService = PlayerDataService,
		MemoryDataStore = MemoryDataStore,
		InventoryService = InventoryService,
		CollectionService = CollectionService,
		SellService = SellService,
		ResourceSpawner = ResourceSpawner,
		RateLimitService = RateLimitService,
		ResourceConfig = ResourceConfig,
		WorldConfig = WorldConfig,
		UpgradeConfig = UpgradeConfig,
		CollectionSecurityConfig = CollectionSecurityConfig,
		Remotes = Remotes,
		StudioTestPresets = StudioTestPresets,
		Localization = Localization,
		FeedbackRules = FeedbackRules,
	})
)

report(
	"AnalyticsTests",
	AnalyticsTests.run({
		AnalyticsService = AnalyticsService,
		AnalyticsConfig = AnalyticsConfig,
		AchievementService = AchievementService,
		PlayerDataService = PlayerDataService,
		InventoryService = InventoryService,
		CollectionService = CollectionService,
		SellService = SellService,
		UpgradeService = UpgradeService,
		WorldUnlockService = WorldUnlockService,
		ResourceSpawner = ResourceSpawner,
		MemoryDataStore = MemoryDataStore,
		UpgradeMath = UpgradeMath,
		UpgradeConfig = UpgradeConfig,
		WorldConfig = WorldConfig,
		ResourceConfig = ResourceConfig,
		DataSchema = DataSchema,
		Remotes = Remotes,
	})
)

report(
	"ResourceFxTests",
	ResourceFxTests.run({
		ResourceFxRules = ResourceFxRules,
		ResourceVFXConfig = ResourceVFXConfig,
		ResourceConfig = ResourceConfig,
	})
)

if totalFailures == 0 then
	print("[Tests] TOUS LES TESTS : OK")
else
	warn(`[Tests] TOTAL : {totalFailures} échec(s)`)
end
