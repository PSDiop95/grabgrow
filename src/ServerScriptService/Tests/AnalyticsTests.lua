--!strict
-- Tests de l'instrumentation analytics (T9) : AnalyticsService avec un sink
-- simulé (aucun appel à Roblox), puis branché sur les vrais services comme
-- dans Bootstrap (magasin en mémoire, aucun DataStore réel).

local AnalyticsTests = {}

export type Modules = {
	AnalyticsService: any,
	AnalyticsConfig: any,
	AchievementService: any,
	PlayerDataService: any,
	InventoryService: any,
	CollectionService: any,
	SellService: any,
	UpgradeService: any,
	WorldUnlockService: any,
	ResourceSpawner: any,
	MemoryDataStore: any,
	UpgradeMath: any,
	UpgradeConfig: any,
	WorldConfig: any,
	ResourceConfig: any,
	DataSchema: any,
	Remotes: any,
}

local USER_A = 9101
local USER_B = 9102
local LEAF = "green_leaf_001"
local ZONE = "GreenValley_Main"

local UNLIMITED = {
	Allow = function(): boolean
		return true
	end,
	Clear = function() end,
}

function AnalyticsTests.run(modules: Modules): ({ string }, number)
	local Analytics = modules.AnalyticsService
	local baseConfig = modules.AnalyticsConfig
	local PlayerDataService = modules.PlayerDataService
	local UpgradeMath = modules.UpgradeMath
	local DataSchema = modules.DataSchema
	local Code = modules.Remotes.ResultCode

	local failures: { string } = {}
	local caseCount = 0

	local function case(name: string, body: (check: (condition: boolean, message: string) -> ()) -> ())
		caseCount += 1
		local ok, err = pcall(body :: any, function(condition: boolean, message: string)
			if not condition then
				table.insert(failures, `{name} : {message}`)
			end
		end)
		if not ok then
			table.insert(failures, `{name} : erreur {tostring(err)}`)
		end
	end

	-- Configuration modifiable (la vraie est gelée).
	local function configWith(overrides: { [string]: any }?): any
		local config = {}
		for key, value in pairs(baseConfig) do
			config[key] = value
		end
		for key, value in pairs(overrides or {}) do
			config[key] = value
		end
		return config
	end

	-- Sink simulé : enregistre chaque appel ; `fail` le fait échouer.
	local function newSink()
		local sink = { calls = {} :: { any }, fail = false }
		local function record(method: string)
			return function(player: any, ...: any)
				table.insert(sink.calls, { method = method, userId = player.UserId, args = { ... } })
				if sink.fail then
					error("panne simulée")
				end
			end
		end
		sink.api = {
			custom = record("custom"),
			economy = record("economy"),
			onboarding = record("onboarding"),
			progressionComplete = record("progressionComplete"),
		}
		function sink.of(method: string, userId: number?): { any }
			local list = {}
			for _, call in ipairs(sink.calls) do
				if call.method == method and (userId == nil or call.userId == userId) then
					table.insert(list, call)
				end
			end
			return list
		end
		function sink.custom(name: string, userId: number?): { any }
			local list = {}
			for _, call in ipairs(sink.of("custom", userId)) do
				if call.args[1] == name then
					table.insert(list, call)
				end
			end
			return list
		end
		function sink.steps(userId: number?): { number }
			local steps = {}
			for _, call in ipairs(sink.of("onboarding", userId)) do
				table.insert(steps, call.args[1])
			end
			return steps
		end
		return sink
	end

	-- Service seul, profils simulés.
	local function newUnit(options: any?)
		local opts = options or {}
		local unit = {
			now = 100,
			profiles = {} :: { [number]: any },
			players = opts.players or 1,
			sink = newSink(),
			logs = {} :: { string },
		}
		unit.service = Analytics.new({
			config = configWith(opts.config),
			sink = unit.sink.api,
			clock = function(): number
				return unit.now
			end,
			getProfile = function(userId: number): any?
				return unit.profiles[userId]
			end,
			getPlayerCount = function(): number
				return unit.players
			end,
			log = function(_: string, message: string)
				table.insert(unit.logs, message)
			end,
		})
		return unit
	end

	local function player(userId: number): any
		return { UserId = userId }
	end

	local function sameList(a: { any }, b: { any }): boolean
		if #a ~= #b then
			return false
		end
		for index, value in ipairs(a) do
			if b[index] ~= value then
				return false
			end
		end
		return true
	end

	local function listText(list: { any }): string
		local parts = {}
		for _, value in ipairs(list) do
			table.insert(parts, tostring(value))
		end
		return `\{{table.concat(parts, ",")}\}`
	end

	-- 1. TESTS UNITAIRES ------------------------------------------------------

	case("événement valide : voyage", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A))
		unit.service.TravelSucceeded(player(USER_A), { ok = true, worldId = "GoldenDesert" })
		local calls = unit.sink.custom("WorldEntered")
		check(#calls == 1, `WorldEntered : {#calls}`)
		check(calls[1] and sameList(calls[1].args[3], { "GoldenDesert" }), "champ monde")
	end)

	case("paramètres invalides ignorés", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A))
		local before = #unit.sink.calls
		unit.service.TravelSucceeded(player(USER_A), { ok = true, worldId = "Atlantis" })
		unit.service.CollectSucceeded(player(USER_A), { ok = true, resourceType = "unobtainium", amount = 1 })
		unit.service.CollectSucceeded(player(USER_A), { ok = true, resourceType = "wood", amount = -2 })
		unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 0, balanceAfter = 0 })
		unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 5, balanceAfter = 0 / 0 })
		unit.service.UpgradeSucceeded(player(USER_A), { ok = true, upgradeId = "Jetpack", level = 2, coinsSpent = 5, balanceAfter = 0 })
		unit.service.AchievementGranted(player(USER_A), { achievementId = "cheat", reward = 10, balanceAfter = 10 })
		check(#unit.sink.of("economy") == 0, "aucun événement économique invalide")
		check(#unit.sink.custom("WorldEntered") == 0 and #unit.sink.custom("UpgradePurchased") == 0, "aucun custom invalide")
		check(#unit.sink.calls == before, `appels : {#unit.sink.calls - before}`)
		check(unit.service.GetCounters().invalid == 7, `invalides : {unit.service.GetCounters().invalid}`)
	end)

	case("joueur absent : rien n'est envoyé", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.TravelSucceeded(player(USER_A), { ok = true, worldId = "GoldenDesert" })
		unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 5, balanceAfter = 5 })
		unit.service.SessionEnded(player(USER_A))
		unit.service.TravelSucceeded({}, { ok = true, worldId = "GoldenDesert" })
		unit.service.SessionStarted({ UserId = "abc" })
		check(#unit.sink.calls == 0, `appels sans session : {#unit.sink.calls}`)
	end)

	case("événements dupliqués", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A))
		unit.service.SessionStarted(player(USER_A))
		check(sameList(unit.sink.steps(), { 1 }), `étapes : {listText(unit.sink.steps())}`)
		unit.service.SessionEnded(player(USER_A))
		unit.service.SessionEnded(player(USER_A))
		check(#unit.sink.custom("SessionEnded") == 1, "une seule fin de session")
	end)

	case("transaction refusée : rien n'est envoyé", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A))
		local before = #unit.sink.calls
		unit.service.SaleSucceeded(player(USER_A), { ok = false, code = Code.NothingToSell, coinsEarned = 0 })
		unit.service.UpgradeSucceeded(player(USER_A), { ok = false, code = Code.InsufficientFunds, upgradeId = "Backpack" })
		unit.service.WorldUnlocked(player(USER_A), { ok = false, code = Code.RequirementNotMet, worldId = "GoldenDesert" })
		unit.service.CollectSucceeded(player(USER_A), { ok = false, code = Code.Cooldown })
		unit.service.CollectRejected(player(USER_A), Code.Cooldown)
		unit.service.TravelSucceeded(player(USER_A), { ok = false, worldId = "GoldenDesert" })
		check(#unit.sink.calls == before, `appels : {#unit.sink.calls - before}`)
	end)

	case("transaction réussie : vente", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A))
		unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 12, balanceAfter = 30 })
		local calls = unit.sink.of("economy")
		check(#calls == 1, `économie : {#calls}`)
		local args = calls[1] and calls[1].args or {}
		check(
			sameList({ args[1], args[2], args[3], args[4], args[5], args[6] }, { "Source", "Coins", 12, 30, "Gameplay", "Sale:GreenValley" }),
			`arguments : {listText({ args[1], args[2], args[3], args[4], args[5], args[6] })}`
		)
	end)

	case("profil absent : aucune session", function(check)
		local unit = newUnit()
		unit.service.SessionStarted(player(USER_A))
		check(not unit.service.IsSessionOpen(USER_A), "session ouverte sans profil")
		unit.service.TravelSucceeded(player(USER_A), { ok = true, worldId = "GoldenDesert" })
		check(#unit.sink.calls == 0, "événement sans profil")
	end)

	case("erreur simulée de l'appel analytics", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.sink.fail = true
		local ok = pcall(function()
			unit.service.SessionStarted(player(USER_A))
			unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 3, balanceAfter = 3 })
			unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 3, balanceAfter = 6 })
		end)
		check(ok, "une panne analytics a levé une erreur")
		local counters = unit.service.GetCounters()
		check(counters.failed == #unit.sink.calls and counters.sent == 0, "échecs non comptés")
		check(#unit.sink.of("economy") == 2, `aucune nouvelle tentative attendue : {#unit.sink.of("economy")}`)
		check(#unit.logs == 2, `journal limité à une ligne par méthode : {#unit.logs}`)
	end)

	case("analytics désactivé", function(check)
		local unit = newUnit({ config = { enabled = false } })
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A))
		unit.service.CollectSucceeded(player(USER_A), { ok = true, resourceType = "wood", amount = 1, firstDiscovery = true })
		unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 3, balanceAfter = 3 })
		unit.service.Tick({ player(USER_A) })
		unit.service.SessionEnded(player(USER_A))
		check(#unit.sink.calls == 0, `appels : {#unit.sink.calls}`)
	end)

	case("session terminée : plus aucun événement", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A))
		unit.now += 42.7
		unit.service.SessionEnded(player(USER_A))
		local ended = unit.sink.custom("SessionEnded")
		check(#ended == 1 and ended[1].args[2] == 42, "durée serveur arrondie")
		local before = #unit.sink.calls
		unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 3, balanceAfter = 3 })
		check(#unit.sink.calls == before, "événement après la fin de session")
	end)

	case("reconnexion : aucune étape rétroactive ni répétée", function(check)
		local unit = newUnit()
		local profile = DataSchema.newProfile()
		profile.stats.totalResourcesCollected = 5
		profile.stats.totalSales = 1
		unit.profiles[USER_A] = profile
		unit.service.SessionStarted(player(USER_A))
		check(#unit.sink.steps() == 0, `étapes au chargement : {listText(unit.sink.steps())}`)
		unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 3, balanceAfter = 3 })
		check(#unit.sink.steps() == 0, "étape de vente répétée")
	end)

	case("onboarding dans l'ordre, même si une étape est sautée", function(check)
		local unit = newUnit()
		local profile = DataSchema.newProfile()
		unit.profiles[USER_A] = profile
		unit.service.SessionStarted(player(USER_A))
		-- Amélioration avant toute vente (Coins d'un succès) : l'étape 4
		-- attend l'étape 3, pour ne pas marquer une vente qui n'a pas eu lieu.
		profile.stats.totalResourcesCollected = 100
		profile.upgrades.backpackLevel = UpgradeMath.startLevel("Backpack") + 1
		unit.service.CollectSucceeded(player(USER_A), { ok = true, resourceType = "wood", amount = 1 })
		check(sameList(unit.sink.steps(), { 1, 2 }), `avant vente : {listText(unit.sink.steps())}`)
		profile.stats.totalSales = 1
		unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 3, balanceAfter = 3 })
		check(sameList(unit.sink.steps(), { 1, 2, 3, 4 }), `après vente : {listText(unit.sink.steps())}`)
	end)

	case("budget : priorité basse écartée d'abord", function(check)
		local unit = newUnit({ players = 1 })
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A)) -- 1 envoi (étape 1)
		local budget = baseConfig.Budget
		local soft = budget.softBasePerMinute + budget.softPerPlayerPerMinute
		local hard = budget.hardBasePerMinute + budget.hardPerPlayerPerMinute
		for _ = 1, soft + 10 do
			unit.service.TravelSucceeded(player(USER_A), { ok = true, worldId = "GoldenDesert" })
		end
		check(#unit.sink.custom("WorldEntered") == soft - 1, `custom admis : {#unit.sink.custom("WorldEntered")}`)
		for _ = 1, hard do
			unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 1, balanceAfter = 1 })
		end
		check(#unit.sink.calls == hard, `total admis : {#unit.sink.calls} / {hard}`)
		check(unit.service.GetCounters().dropped > 0, "aucun écart compté")
		unit.now += 60
		unit.service.TravelSucceeded(player(USER_A), { ok = true, worldId = "GoldenDesert" })
		check(#unit.sink.calls == hard + 1, "nouvelle fenêtre non ouverte")
	end)

	case("sac plein : un événement par épisode", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A))
		for _ = 1, 5 do
			unit.service.CollectRejected(player(USER_A), Code.InventoryFull)
		end
		check(#unit.sink.custom("BackpackFull") == 1, "épisode compté plusieurs fois")
		unit.service.SaleSucceeded(player(USER_A), { ok = true, sellZoneId = ZONE, coinsEarned = 3, balanceAfter = 3 })
		unit.service.CollectRejected(player(USER_A), Code.InventoryFull)
		check(#unit.sink.custom("BackpackFull") == 2, "épisode non réarmé par la vente")
	end)

	case("collecte agrégée par lots", function(check)
		local unit = newUnit()
		unit.profiles[USER_A] = DataSchema.newProfile()
		unit.service.SessionStarted(player(USER_A))
		for _ = 1, 5 do
			unit.service.CollectSucceeded(player(USER_A), { ok = true, resourceType = "wood", amount = 1 })
		end
		unit.service.CollectSucceeded(player(USER_A), { ok = true, resourceType = "sandstone", amount = 1 })
		check(#unit.sink.custom("ResourcesCollected") == 0, "envoi par collecte")
		unit.service.Tick({ player(USER_A) })
		check(#unit.sink.custom("ResourcesCollected") == 0, "envoi avant échéance")
		unit.now += baseConfig.Collection.flushIntervalSeconds
		unit.service.Tick({ player(USER_A) })
		local calls = unit.sink.custom("ResourcesCollected")
		local byWorld = {}
		for _, call in ipairs(calls) do
			byWorld[call.args[3][1]] = call.args[2]
		end
		check(#calls == 2 and byWorld.GreenValley == 5 and byWorld.GoldenDesert == 1, "lots par monde")
		unit.service.SessionEnded(player(USER_A))
		check(#unit.sink.custom("ResourcesCollected") == 2, "lot vide envoyé")
	end)

	case("zone de vente : monde borné par WorldConfig", function(check)
		check(Analytics.worldOfSellZone("GoldenDesert_Main", "Unknown") == "GoldenDesert", "préfixe connu")
		check(Analytics.worldOfSellZone("Hacker_Zone", "Unknown") == "Unknown", "préfixe inconnu")
		check(Analytics.worldOfSellZone(42, "Unknown") == "Unknown", "type invalide")
	end)

	-- 2. TESTS D'INTÉGRATION (services réels, câblage de Bootstrap) ---------

	local interval = modules.UpgradeConfig.Grabber.levels[1].value

	local function newEnv(options: any?)
		local opts = options or {}
		local env = {
			now = 1000,
			store = opts.store or modules.MemoryDataStore.new(),
			timers = {} :: { () -> () },
			sink = newSink(),
		}
		local function clock(): number
			return env.now
		end
		local function origin(): any
			return { X = 0, Y = 0, Z = 0 }
		end
		local function log() end
		env.playerData = PlayerDataService.new({
			store = env.store,
			serverId = "S",
			clock = function(): number
				return 1_000_000
			end,
			wait = function() end,
			spawn = function(callback: () -> ())
				callback()
			end,
			log = log,
		})
		env.spawner = modules.ResourceSpawner.new({
			schedule = function(_: number, callback: () -> ())
				table.insert(env.timers, callback)
			end,
		})
		env.spawner.Register(LEAF, "green_leaf", origin())
		env.collection = modules.CollectionService.new({
			playerData = env.playerData,
			inventory = modules.InventoryService.new({ playerData = env.playerData }),
			spawner = env.spawner,
			rateLimit = UNLIMITED,
			clock = clock,
			getCharacterPosition = origin,
			log = log,
		})
		env.sell = modules.SellService.new({
			playerData = env.playerData,
			rateLimit = UNLIMITED,
			getSellZone = function(zoneId: string): any
				return if zoneId == ZONE then { position = origin() } else nil
			end,
			getCharacterPosition = origin,
			clock = clock,
			log = log,
		})
		env.upgrade = modules.UpgradeService.new({ playerData = env.playerData, rateLimit = UNLIMITED, clock = clock, log = log })
		env.world = modules.WorldUnlockService.new({ playerData = env.playerData, rateLimit = UNLIMITED, clock = clock, log = log })
		env.achievements = modules.AchievementService.new({ playerData = env.playerData, log = log })
		env.analytics = Analytics.new({
			config = configWith(opts.config),
			sink = env.sink.api,
			clock = clock,
			getProfile = env.playerData.GetData,
			getPlayerCount = function(): number
				return 2
			end,
			log = log,
		})

		-- Même enchaînement que Bootstrap.
		function env.join(userId: number)
			assert(env.playerData.LoadPlayer(userId).ok, "chargement du joueur de test")
			env.analytics.SessionStarted(player(userId))
		end
		function env.leave(userId: number)
			env.analytics.SessionEnded(player(userId))
			assert(env.playerData.ReleasePlayer(userId).ok, "sauvegarde de sortie")
		end
		local function grant(userId: number)
			for _, entry in ipairs(env.achievements.Evaluate(userId)) do
				env.analytics.AchievementGranted(player(userId), entry)
			end
		end
		function env.collect(userId: number): any
			env.now += interval + 0.05
			local pending = env.timers
			env.timers = {}
			for _, callback in ipairs(pending) do
				callback()
			end
			local result = env.collection.HandleRequest(userId, { resourceId = LEAF })
			if result.ok then
				env.analytics.CollectSucceeded(player(userId), result)
				grant(userId)
			else
				env.analytics.CollectRejected(player(userId), result.code)
			end
			return result
		end
		function env.sellAll(userId: number): any
			env.now += 5
			local result = env.sell.HandleRequest(userId, { sellZoneId = ZONE })
			if result.ok then
				env.analytics.SaleSucceeded(player(userId), result)
				grant(userId)
			end
			return result
		end
		function env.buy(userId: number, upgradeId: string): any
			env.now += 5
			local result = env.upgrade.HandleRequest(userId, { upgradeId = upgradeId })
			if result.ok then
				env.analytics.UpgradeSucceeded(player(userId), result)
				grant(userId)
			end
			return result
		end
		function env.unlock(userId: number, worldId: string): any
			env.now += 5
			local result = env.world.HandleRequest(userId, { worldId = worldId })
			if result.ok then
				env.analytics.WorldUnlocked(player(userId), result)
				grant(userId)
			end
			return result
		end
		function env.prepare(userId: number, mutate: (draft: any) -> ())
			assert(env.playerData.Update(userId, function(draft: any): boolean?
				mutate(draft)
				return nil
			end).ok, "préparation du profil")
		end
		function env.coins(userId: number): number
			return env.playerData.GetData(userId).currencies.coins
		end
		return env
	end

	case("intégration : première collecte et découverte du journal", function(check)
		local env = newEnv()
		env.join(USER_A)
		check(env.collect(USER_A).ok, "collecte refusée")
		check(sameList(env.sink.steps(USER_A), { 1, 2 }), `étapes : {listText(env.sink.steps(USER_A))}`)
		local discovery = env.sink.custom("JournalDiscovery", USER_A)
		check(#discovery == 1 and sameList(discovery[1].args[3], { "GreenValley", "Common" }), "découverte")
		env.collect(USER_A)
		check(#env.sink.custom("JournalDiscovery", USER_A) == 1, "découverte répétée")
		check(#env.sink.steps(USER_A) == 2, "étape de collecte répétée")
	end)

	case("intégration : première vente puis ventes répétées", function(check)
		local env = newEnv()
		env.join(USER_A)
		for round = 1, 3 do
			env.collect(USER_A)
			env.collect(USER_A)
			local result = env.sellAll(USER_A)
			check(result.ok, `vente {round} refusée`)
			local calls = env.sink.of("economy", USER_A)
			local last = calls[#calls]
			check(#calls == round, `événements économiques : {#calls} pour {round} vente(s)`)
			check(last and last.args[3] == result.coinsEarned, "montant différent de la transaction")
			check(last and last.args[4] == env.coins(USER_A), "solde final différent du profil")
		end
		check(sameList(env.sink.steps(USER_A), { 1, 2, 3 }), `étapes : {listText(env.sink.steps(USER_A))}`)
		local lots = env.sink.custom("ResourcesCollected", USER_A)
		local total = 0
		for _, call in ipairs(lots) do
			total += call.args[2]
		end
		check(#lots == 3 and total == 6, `lots : {#lots}, total {total}`)
	end)

	case("intégration : vente refusée (sac vide)", function(check)
		local env = newEnv()
		env.join(USER_A)
		local result = env.sellAll(USER_A)
		check(not result.ok, "vente d'un sac vide acceptée")
		check(#env.sink.of("economy") == 0, "événement sur un refus")
	end)

	case("intégration : première amélioration et achats répétés", function(check)
		local env = newEnv()
		env.join(USER_A)
		env.collect(USER_A)
		env.sellAll(USER_A)
		env.prepare(USER_A, function(draft)
			draft.currencies.coins = 100_000
		end)
		local first = env.buy(USER_A, "Backpack")
		check(first.ok, `achat refusé : {tostring(first.code)}`)
		check(sameList(env.sink.steps(USER_A), { 1, 2, 3, 4 }), `étapes : {listText(env.sink.steps(USER_A))}`)
		check(env.buy(USER_A, "Backpack").ok and env.buy(USER_A, "Grabber").ok, "achats répétés")
		local sinks = {}
		for _, call in ipairs(env.sink.of("economy", USER_A)) do
			if call.args[1] == "Sink" then
				table.insert(sinks, call)
			end
		end
		check(#sinks == 3, `dépenses : {#sinks}`)
		check(sinks[3] and sinks[3].args[6] == "Upgrade:Grabber" and sinks[3].args[5] == "Shop", "SKU ou type")
		check(sinks[3] and sinks[3].args[4] == env.coins(USER_A), "solde final")
		check(#env.sink.custom("UpgradePurchased", USER_A) == 3, "UpgradePurchased")
		check(#env.sink.steps(USER_A) == 4, "étape d'amélioration répétée")
		env.prepare(USER_A, function(draft)
			draft.currencies.coins = 0
		end)
		local before = #env.sink.calls
		check(not env.buy(USER_A, "Magnet").ok, "achat sans solde accepté")
		check(#env.sink.calls == before, "événement sur un achat refusé")
	end)

	case("intégration : déblocage d'un monde", function(check)
		local env = newEnv()
		env.join(USER_A)
		local cost = modules.WorldConfig.GoldenDesert.unlockCost
		env.prepare(USER_A, function(draft)
			draft.currencies.coins = cost + 7
			draft.upgrades.backpackLevel = modules.WorldConfig.GoldenDesert.requiredBackpackLevel
		end)
		check(not env.unlock(USER_A, "FrozenPeaks").ok, "monde verrouillé accepté")
		check(#env.sink.of("progressionComplete") == 0, "progression sur un refus")
		local result = env.unlock(USER_A, "GoldenDesert")
		check(result.ok, `déblocage refusé : {tostring(result.code)}`)
		local unlock
		for _, call in ipairs(env.sink.of("economy", USER_A)) do
			if call.args[6] == "World:GoldenDesert" then
				unlock = call
			end
		end
		check(unlock ~= nil and unlock.args[1] == "Sink" and unlock.args[3] == cost, "dépense du déblocage")
		-- Le succès world_2 crédite ensuite des Coins : le solde du déblocage
		-- est celui juste après le débit.
		check(unlock ~= nil and unlock.args[4] == 7, `solde après débit : {tostring(unlock and unlock.args[4])}`)
		local progression = env.sink.of("progressionComplete", USER_A)
		check(#progression == 1 and progression[1].args[2] == 2 and progression[1].args[3] == "GoldenDesert", "progression")
		local steps = env.sink.steps(USER_A)
		check(steps[#steps] ~= 5, "étape 5 envoyée sans les étapes précédentes")
	end)

	case("intégration : parcours complet, étapes 1 à 5 une seule fois", function(check)
		local env = newEnv()
		env.join(USER_A)
		env.collect(USER_A)
		env.sellAll(USER_A)
		local world = modules.WorldConfig.GoldenDesert
		env.prepare(USER_A, function(draft)
			draft.currencies.coins = 100_000
		end)
		for _ = 1, world.requiredBackpackLevel - UpgradeMath.startLevel("Backpack") do
			check(env.buy(USER_A, "Backpack").ok, "achat du Backpack")
		end
		check(env.unlock(USER_A, "GoldenDesert").ok, "déblocage")
		check(sameList(env.sink.steps(USER_A), { 1, 2, 3, 4, 5 }), `étapes : {listText(env.sink.steps(USER_A))}`)
		env.collect(USER_A)
		check(#env.sink.steps(USER_A) == 5, "étape répétée")
	end)

	case("intégration : succès = source de Coins", function(check)
		local env = newEnv()
		env.join(USER_A)
		env.prepare(USER_A, function(draft)
			draft.stats.totalResourcesCollected = 99
		end)
		env.collect(USER_A)
		local found
		for _, call in ipairs(env.sink.of("economy", USER_A)) do
			if call.args[6] == "Achievement:collect_100" then
				found = call
			end
		end
		check(found ~= nil and found.args[1] == "Source", "succès non mesuré")
		check(found ~= nil and found.args[4] == env.coins(USER_A), "solde final du succès")
	end)

	case("intégration : panne analytics sans effet sur le jeu", function(check)
		local normal = newEnv()
		local broken = newEnv()
		broken.sink.fail = true
		for _, env in ipairs({ normal, broken }) do
			env.join(USER_A)
			env.collect(USER_A)
			env.collect(USER_A)
			env.sellAll(USER_A)
			env.prepare(USER_A, function(draft)
				draft.currencies.coins += 100
			end)
			env.buy(USER_A, "Backpack")
		end
		local a, b = normal.playerData.GetData(USER_A), broken.playerData.GetData(USER_A)
		check(a.currencies.coins == b.currencies.coins, "solde différent")
		check(a.stats.totalSales == b.stats.totalSales and a.upgrades.backpackLevel == b.upgrades.backpackLevel, "progression différente")
		check(broken.analytics.GetCounters().sent == 0 and broken.analytics.GetCounters().failed > 0, "échecs non isolés")
	end)

	case("intégration : analytics désactivé, jeu identique", function(check)
		local env = newEnv({ config = { enabled = false } })
		env.join(USER_A)
		check(env.collect(USER_A).ok and env.sellAll(USER_A).ok, "boucle interrompue")
		check(#env.sink.calls == 0, "appel avec analytics désactivé")
	end)

	case("intégration : reconnexion", function(check)
		local env = newEnv()
		env.join(USER_A)
		env.collect(USER_A)
		env.leave(USER_A)
		local after = newEnv({ store = env.store })
		after.join(USER_A)
		check(#after.sink.steps(USER_A) == 0, `étapes répétées : {listText(after.sink.steps(USER_A))}`)
		after.collect(USER_A)
		after.sellAll(USER_A)
		check(sameList(after.sink.steps(USER_A), { 3 }), `reprise : {listText(after.sink.steps(USER_A))}`)
		check(#env.sink.custom("SessionEnded", USER_A) == 1, "fin de session")
	end)

	case("intégration : deux joueurs simultanés", function(check)
		local env = newEnv()
		env.join(USER_A)
		env.join(USER_B)
		env.collect(USER_A)
		env.collect(USER_B)
		env.collect(USER_A)
		env.sellAll(USER_B)
		env.sellAll(USER_A)
		check(sameList(env.sink.steps(USER_A), { 1, 2, 3 }), "étapes du joueur A")
		check(sameList(env.sink.steps(USER_B), { 1, 2, 3 }), "étapes du joueur B")
		local a = env.sink.of("economy", USER_A)
		local b = env.sink.of("economy", USER_B)
		check(#a == 1 and #b == 1, "une vente chacun")
		check(a[1] and a[1].args[4] == env.coins(USER_A) and b[1] and b[1].args[4] == env.coins(USER_B), "soldes croisés")
	end)

	case("aucune donnée personnelle dans les champs", function(check)
		local env = newEnv()
		env.join(USER_A)
		env.prepare(USER_A, function(draft)
			draft.currencies.coins = 100_000
			draft.upgrades.backpackLevel = 5
		end)
		env.collect(USER_A)
		env.sellAll(USER_A)
		env.buy(USER_A, "Grabber")
		env.unlock(USER_A, "GoldenDesert")
		env.leave(USER_A)
		local allowed: { [string]: boolean } = { Unknown = true }
		for worldId in pairs(modules.WorldConfig) do
			allowed[worldId] = true
		end
		for _, definition in pairs(modules.ResourceConfig) do
			allowed[definition.rarity] = true
		end
		for _, upgradeId in ipairs(UpgradeMath.ids()) do
			allowed[upgradeId] = true
		end
		for _, call in ipairs(env.sink.calls) do
			for _, value in ipairs(call.args) do
				if type(value) == "table" then
					for _, field in ipairs(value) do
						check(allowed[field] == true or string.match(field, "^%d+$") ~= nil, `champ non borné : {field}`)
						check(field ~= tostring(USER_A), "UserId dans un champ")
					end
				elseif type(value) == "string" then
					check(not string.find(value, tostring(USER_A), 1, true), `UserId dans {value}`)
				end
			end
		end
	end)

	return failures, caseCount
end

return AnalyticsTests
