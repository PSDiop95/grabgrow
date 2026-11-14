--!strict
-- Tests des succès permanents (T7, D-020) : configuration, règles pures,
-- AchievementService (attribution unique, atomicité, refus), migration
-- v1 -> v2 et cohérence avec l'audit T6. Magasin en mémoire, aucun
-- DataStore réel.

local AchievementTests = {}

export type Modules = {
	AchievementConfig: any,
	AchievementRules: any,
	AchievementService: any,
	PlayerDataService: any,
	MemoryDataStore: any,
	DataSchema: any,
	ProfileAudit: any,
	Localization: any,
	FeedbackRules: any,
	Remotes: any,
}

local USER_A = 3001
local USER_B = 3002

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function AchievementTests.run(modules: Modules): ({ string }, number)
	local Config = modules.AchievementConfig
	local Rules = modules.AchievementRules
	local AchievementService = modules.AchievementService
	local PlayerDataService = modules.PlayerDataService
	local MemoryDataStore = modules.MemoryDataStore
	local DataSchema = modules.DataSchema
	local Localization = modules.Localization

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

	local function newEnv(userIds: { number }, seeds: { [number]: any }?)
		local store = MemoryDataStore.new()
		for userId, profile in pairs(seeds or {}) do
			store.seed(`Player_{userId}`, { profile = profile })
		end
		local now = 1_000_000
		local logs: { string } = {}
		local playerData = PlayerDataService.new({
			store = store,
			serverId = "T",
			clock = function(): number
				return now
			end,
			wait = function(seconds: number)
				now += seconds
			end,
			spawn = function(callback: () -> ())
				callback()
			end,
			log = function() end,
		})
		for _, userId in ipairs(userIds) do
			assert(playerData.LoadPlayer(userId).ok, "chargement impossible")
		end
		local service = AchievementService.new({
			playerData = playerData,
			log = function(level: string, message: string)
				table.insert(logs, `{level} {message}`)
			end,
		})
		local env = { playerData = playerData, service = service, logs = logs }
		function env.set(userId: number, stats: { [string]: number })
			assert(
				playerData.Update(userId, function(draft: any): boolean?
					for statId, value in pairs(stats) do
						draft.stats[statId] = value
					end
					return nil
				end).ok,
				"Update refusé"
			)
		end
		function env.profile(userId: number): any
			return playerData.GetData(userId)
		end
		return env
	end

	local function sumRewards(ids: { string }): number
		local total = 0
		for _, id in ipairs(ids) do
			total += Config[id].reward
		end
		return total
	end

	-- CONFIGURATION -----------------------------------------------------------

	case("configuration : identifiants, objectifs, récompenses, ordre, textes", function(check)
		local orders: { [number]: string } = {}
		local metrics: { [string]: boolean } = {}
		for _, metric in pairs(Rules.Metric) do
			metrics[metric] = true
		end
		local count = 0
		for id, definition in pairs(Config) do
			count += 1
			check(type(id) == "string" and #id >= 1 and #id <= 64, `{id} : identifiant invalide`)
			check(metrics[definition.metric] == true, `{id} : métrique inconnue {tostring(definition.metric)}`)
			check(definition.goal >= 1 and definition.goal % 1 == 0, `{id} : objectif invalide`)
			check(definition.reward >= 1 and definition.reward % 1 == 0, `{id} : récompense invalide`)
			check(orders[definition.order] == nil, `{id} : ordre {definition.order} en double`)
			orders[definition.order] = id
			check(
				Localization.has(definition.nameKey, "en") and Localization.has(definition.nameKey, "fr"),
				`{id} : texte absent`
			)
		end
		check(count == 12, `12 succès attendus (D-020), trouvé {count}`)
		check(Localization.has("achievement.unlocked", "en") and Localization.has("achievement.unlocked", "fr"), "bandeau absent")
		check(#Rules.ids() == count, "Rules.ids incomplet")
	end)

	-- RÈGLES PURES ------------------------------------------------------------

	case("règles : métriques lues dans le profil", function(check)
		local profile = DataSchema.newProfile()
		profile.stats.totalResourcesCollected = 120
		profile.stats.totalSales = 4
		profile.stats.totalCoinsEarned = 900
		profile.upgrades.backpackLevel = 3 -- 2 achats
		profile.upgrades.magnetLevel = 2 -- 2 achats (départ 0)
		profile.worlds.GoldenDesert = true
		check(Rules.metricValue(profile, "resourcesCollected") == 120, "resourcesCollected")
		check(Rules.metricValue(profile, "sales") == 4, "sales")
		check(Rules.metricValue(profile, "coinsEarned") == 900, "coinsEarned")
		check(Rules.metricValue(profile, "upgradesBought") == 4, `upgradesBought : {tostring(Rules.metricValue(profile, "upgradesBought"))}`)
		check(Rules.metricValue(profile, "worldsUnlocked") == 2, "worldsUnlocked")
		check(Rules.metricValue(profile, "inconnue") == nil, "métrique inconnue lue")
		check(Rules.metricValue(nil, "sales") == nil, "profil nil lu")
	end)

	case("règles : succès atteints, non obtenus, dans l'ordre", function(check)
		local profile = DataSchema.newProfile()
		check(#Rules.pending(profile) == 0, "nouveau profil : succès atteints")
		profile.stats.totalResourcesCollected = 1_000
		profile.stats.totalSales = 10
		local pending = Rules.pending(profile)
		check(deepEqual(pending, { "collect_100", "sales_10", "collect_1000" }), `liste : {table.concat(pending, ",")}`)
		profile.achievements.sales_10 = true
		check(deepEqual(Rules.pending(profile), { "collect_100", "collect_1000" }), "succès obtenu proposé de nouveau")
		profile.achievements = nil
		check(#Rules.pending(profile) == 0, "profil sans section : succès proposés")
	end)

	case("règles : valeurs illisibles sans succès", function(check)
		local profile = DataSchema.newProfile()
		profile.stats.totalResourcesCollected = 0 / 0
		profile.stats.totalSales = -5
		check(#Rules.pending(profile) == 0, "NaN ou négatif accepté")
	end)

	-- SERVICE ---------------------------------------------------------------

	case("service : rien d'atteint, profil inchangé", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { totalResourcesCollected = 99 })
		local before = env.profile(USER_A)
		check(#env.service.Evaluate(USER_A) == 0, "succès attribué à 99")
		check(deepEqual(env.profile(USER_A), before), "profil modifié sans succès")
	end)

	case("service : succès attribué une seule fois", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { totalResourcesCollected = 100 })
		local granted = env.service.Evaluate(USER_A)
		check(#granted == 1 and granted[1].achievementId == "collect_100" and granted[1].reward == 50, "attribution incorrecte")
		local profile = env.profile(USER_A)
		check(profile.achievements.collect_100 == true, "succès non enregistré")
		check(profile.currencies.coins == 50 and profile.stats.totalCoinsEarned == 50, "récompense incorrecte")
		check(#env.service.Evaluate(USER_A) == 0, "succès attribué deux fois")
		env.set(USER_A, { totalResourcesCollected = 150 })
		check(#env.service.Evaluate(USER_A) == 0, "succès réattribué après une nouvelle collecte")
		check(env.profile(USER_A).currencies.coins == 50, "Coins crédités deux fois")
	end)

	case("service : évaluations répétées, aucun doublon", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { totalResourcesCollected = 5_000, totalSales = 60 })
		local total = 0
		for _ = 1, 5 do
			for _, grant in ipairs(env.service.Evaluate(USER_A)) do
				total += grant.reward
			end
		end
		local expected = sumRewards({ "collect_100", "sales_10", "collect_1000", "sales_50", "collect_5000" })
		check(total == expected, `total {total}, attendu {expected}`)
		check(env.profile(USER_A).currencies.coins == expected, "solde incorrect")
	end)

	case("service : récompense qui débloque « Coins gagnés » dans la même opération", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { totalResourcesCollected = 100, totalCoinsEarned = 9_960 })
		local granted = env.service.Evaluate(USER_A)
		local ids = {}
		for _, grant in ipairs(granted) do
			table.insert(ids, grant.achievementId)
		end
		check(deepEqual(ids, { "collect_100", "earned_10000" }), `liste : {table.concat(ids, ",")}`)
		local profile = env.profile(USER_A)
		check(profile.stats.totalCoinsEarned == 9_960 + 50 + 1_000, "totalCoinsEarned incorrect")
		check(profile.currencies.coins == 1_050, "solde incorrect")
	end)

	case("service : crédit impossible, rien n'est attribué", function(check)
		local env = newEnv({ USER_A })
		local max = DataSchema.MAX_SAFE_INTEGER
		assert(env.playerData.Update(USER_A, function(draft: any): boolean?
			draft.currencies.coins = max - 10
			draft.stats.totalCoinsEarned = max - 10
			draft.stats.totalResourcesCollected = 100
			return nil
		end).ok)
		local before = env.profile(USER_A)
		check(#env.service.Evaluate(USER_A) == 0, "succès attribué malgré un dépassement")
		check(deepEqual(env.profile(USER_A), before), "profil partiellement modifié")
		local logged = false
		for _, line in ipairs(env.logs) do
			if string.find(line, "error", 1, true) == 1 then
				logged = true
			end
		end
		check(logged, "refus non journalisé")
	end)

	case("service : profil non chargé", function(check)
		local env = newEnv({ USER_A })
		check(#env.service.Evaluate(USER_B) == 0, "succès pour un profil absent")
		env.playerData.ReleasePlayer(USER_A)
		check(#env.service.Evaluate(USER_A) == 0, "succès après la libération")
	end)

	case("service : deux joueurs isolés", function(check)
		local env = newEnv({ USER_A, USER_B })
		env.set(USER_A, { totalSales = 10 })
		check(#env.service.Evaluate(USER_A) == 1, "joueur A")
		check(#env.service.Evaluate(USER_B) == 0, "joueur B a reçu le succès de A")
		check(env.profile(USER_B).currencies.coins == 0, "Coins de B modifiés")
	end)

	case("service : succès inconnus conservés", function(check)
		local seed = DataSchema.newProfile()
		seed.achievements.ancien_succes = true
		seed.stats.totalResourcesCollected = 100
		local env = newEnv({ USER_A }, { [USER_A] = seed })
		check(#env.service.Evaluate(USER_A) == 1, "succès non attribué")
		check(env.profile(USER_A).achievements.ancien_succes == true, "succès inconnu supprimé")
	end)

	case("service : journal par succès avec motif", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { totalSales = 10 })
		env.service.Evaluate(USER_A)
		local found = false
		for _, line in ipairs(env.logs) do
			if string.find(line, "motif Achievement:sales_10", 1, true) then
				found = true
			end
		end
		check(found, "ligne de journal absente")
	end)

	case("audit T6 : aucune incohérence après des récompenses", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { totalResourcesCollected = 1_000, totalSales = 10 })
		env.service.Evaluate(USER_A)
		local issues = modules.ProfileAudit.run(env.profile(USER_A))
		for _, issue in ipairs(issues) do
			check(issue.check ~= "coins_unexplained" and issue.check ~= "coins_missing", `constat {issue.check}`)
		end
	end)

	-- MIGRATION ET COMPATIBILITÉ ---------------------------------------------

	case("profil v1 existant : migré, puis succès déjà atteints attribués", function(check)
		local seed = DataSchema.newProfile()
		seed.schemaVersion = 1
		seed.achievements = nil
		seed.currencies.coins = 700
		seed.stats.totalResourcesCollected = 1_200
		seed.stats.totalCoinsEarned = 700
		local env = newEnv({ USER_A }, { [USER_A] = seed })
		local loaded = env.profile(USER_A)
		check(loaded.schemaVersion == 2 and next(loaded.achievements) == nil, "migration non appliquée")
		check(loaded.currencies.coins == 700, "Coins perdus à la migration")
		local granted = env.service.Evaluate(USER_A)
		check(#granted == 2, `2 succès attendus, trouvé {#granted}`)
		check(env.profile(USER_A).currencies.coins == 700 + 50 + 300, "récompenses incorrectes")
	end)

	-- CLIENT (règles partagées) ---------------------------------------------

	case("retour client : son seulement pour une réponse cohérente", function(check)
		local Action = modules.Remotes.Action
		local Code = modules.Remotes.ResultCode
		local cues = modules.FeedbackRules.fromResult({
			action = Action.Achievement,
			ok = true,
			code = Code.Success,
			achievementId = "collect_100",
			coinsEarned = 50,
		})
		check(#cues == 1 and cues[1].sound == "coins" and cues[1].visual == nil, "retour incorrect")
		check(
			#modules.FeedbackRules.fromResult({ action = Action.Achievement, ok = true, achievementId = "faux", coinsEarned = 50 }) == 0,
			"succès inconnu accepté"
		)
		check(
			#modules.FeedbackRules.fromResult({ action = Action.Achievement, ok = true, achievementId = "collect_100", coinsEarned = -1 })
				== 0,
			"montant négatif accepté"
		)
	end)

	return failures, caseCount
end

return AchievementTests
