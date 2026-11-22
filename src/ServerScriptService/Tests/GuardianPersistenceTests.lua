--!strict
-- Persistance des victoires et récompense sacrée (T10.3, option A en v3,
-- D-035) : tests P1 à P15 (docs/phases/T10_3_PERSISTENCE_OPTION_A.md §4).
--
-- Vrai PlayerDataService sur MemoryDataStore (aucun DataStore réel, aucune
-- donnée de production), horloge simulée. Les victoires sont enregistrées
-- par SacredSiteService.RecordVictory, appelée en jeu par
-- GuardianCombatService.onVictory (le combat lui-même est couvert par
-- GuardianTests).

local GuardianPersistenceTests = {}

export type Modules = {
	PlayerDataService: any,
	MemoryDataStore: any,
	DataSchema: any,
	DataConfig: any,
	SacredSiteService: any,
	SacredResourceService: any,
	GuardianConfig: any,
	GuardianRules: any,
	SacredResourceConfig: any,
	AchievementService: any,
	ProfileAudit: any,
	StudioTestPresets: any,
	InventoryService: any,
	Remotes: any,
}

local USER_A = 2001
local USER_B = 2002
local ROOT = "RootSanctuary"
local SUN = "SunTemple"

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

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = deepCopy(item)
	end
	return copy
end

function GuardianPersistenceTests.run(modules: Modules): ({ string }, number)
	local PlayerDataService = modules.PlayerDataService
	local MemoryDataStore = modules.MemoryDataStore
	local DataSchema = modules.DataSchema
	local SacredSiteService = modules.SacredSiteService
	local SacredResourceService = modules.SacredResourceService
	local GuardianConfig = modules.GuardianConfig
	local GuardianRules = modules.GuardianRules
	local SacredResourceConfig = modules.SacredResourceConfig
	local AchievementService = modules.AchievementService
	local ProfileAudit = modules.ProfileAudit
	local StudioTestPresets = modules.StudioTestPresets
	local InventoryService = modules.InventoryService
	local Code = modules.Remotes.ResultCode
	local Access = GuardianRules.Access

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

	local V = GuardianRules.victoryKey
	local R = GuardianRules.rewardKey
	local function resourceOf(siteId: string): string
		return SacredResourceConfig.BySite[siteId]
	end
	local function storeKey(userId: number): string
		return `Player_{userId}`
	end

	local allow = {
		Allow = function(): boolean
			return true
		end,
		Clear = function() end,
	}

	local function newWorld(): any
		return { store = MemoryDataStore.new(), now = 1_000_000, combatCount = 0 }
	end

	-- Un « serveur » : PlayerDataService réel + services sacrés, avec un
	-- mandataire qui peut forcer l'échec de Update et note les sauvegardes.
	local function newServer(world: any, serverId: string): any
		local server: any = {
			saves = {} :: { { userId: number, reason: string } },
			logs = {} :: { string },
			failUpdate = false,
			messages = {} :: { any },
		}
		local function log(level: string, message: string)
			table.insert(server.logs, `{level} {message}`)
		end
		server.data = PlayerDataService.new({
			store = world.store,
			serverId = serverId,
			clock = function(): number
				return world.now
			end,
			wait = function(seconds: number)
				world.now += seconds
			end,
			spawn = function(callback: () -> ())
				callback()
			end,
			onSessionLost = function() end,
			log = log,
		})
		local proxy = {
			GetData = function(userId: number): any?
				return server.data.GetData(userId)
			end,
			Update = function(userId: number, mutator: (draft: any) -> boolean?): any
				if server.failUpdate then
					return { ok = false, code = "Forced", message = "échec simulé" }
				end
				return server.data.Update(userId, mutator)
			end,
			RequestSave = function(userId: number, reason: string?): any
				table.insert(server.saves, { userId = userId, reason = tostring(reason) })
				return server.data.RequestSave(userId, reason)
			end,
		}
		server.proxy = proxy
		local origin = { X = 0, Y = 0, Z = 0 }
		server.position = { X = 2, Y = 0, Z = 0 }
		server.sites = SacredSiteService.new({
			playerData = proxy,
			combat = {
				Start = function(): (boolean, string)
					return true, Code.Success
				end,
				GetRespawnRemaining = function(): number
					return 0
				end,
				IsInCombat = function(): boolean
					return false
				end,
			},
			getSite = function(siteId: string): any
				local definition = GuardianConfig.Sites[siteId]
				if definition == nil then
					return nil
				end
				return { siteId = siteId, guardianId = definition.guardianId, center = origin, altar = origin }
			end,
			getCharacterPosition = function(): any
				return server.position
			end,
			send = function(userId: number, message: any)
				table.insert(server.messages, { userId = userId, message = message })
			end,
			rateLimit = allow,
			clock = function(): number
				return world.now
			end,
			victoryStore = SacredSiteService.profileVictoryStore(proxy, log),
			log = log,
		})
		server.claims = SacredResourceService.new({
			playerData = proxy,
			sites = server.sites,
			getNode = function(nodeId: string): any
				local siteId = string.match(nodeId, "^(%a+)_Sacred_%d$")
				if siteId == nil or GuardianConfig.Sites[siteId] == nil then
					return nil
				end
				return { nodeId = nodeId, siteId = siteId, resourceId = resourceOf(siteId), position = origin }
			end,
			getCharacterPosition = function(): any
				return server.position
			end,
			rateLimit = allow,
			clock = function(): number
				return world.now
			end,
			log = log,
		})

		function server.load(userId: number): any
			return server.data.LoadPlayer(userId)
		end
		function server.win(userId: number, siteId: string, guardianId: string?): boolean
			world.combatCount += 1
			local definition = GuardianConfig.Sites[siteId]
			return server.sites.RecordVictory(userId, {
				combatId = `{serverId}-c{world.combatCount}`,
				siteId = siteId,
				guardianId = guardianId or (if definition then definition.guardianId else "Unknown"),
				durationSeconds = 60,
				strikes = 24,
				hitsTaken = 0,
			})
		end
		function server.claim(userId: number, siteId: string, payload: any?, extra: number?): any
			return server.claims.HandleCollect(userId, payload or { nodeId = `{siteId}_Sacred_1` }, extra or 0)
		end
		function server.profile(userId: number): any
			return server.data.GetData(userId)
		end
		function server.setBag(userId: number, used: number)
			server.data.Update(userId, function(draft: any): boolean?
				draft.inventory.resources.green_leaf = if used > 0 then used else nil
				return true
			end)
		end
		function server.saveCount(reason: string, userId: number?): number
			local count = 0
			for _, entry in ipairs(server.saves) do
				if entry.reason == reason and (userId == nil or entry.userId == userId) then
					count += 1
				end
			end
			return count
		end
		function server.hasLog(fragment: string): boolean
			for _, line in ipairs(server.logs) do
				if string.find(line, fragment, 1, true) then
					return true
				end
			end
			return false
		end
		function server.siteView(userId: number, siteId: string): any
			local view = server.sites.GetView(userId)
			return if view then view.sites[siteId] else nil
		end
		return server
	end

	-- Profil sans les champs que toute sauvegarde met à jour.
	local function stable(profile: any): any
		local copy = deepCopy(profile)
		copy.lastSaveAt = nil
		if type(copy.stats) == "table" then
			copy.stats.playTimeSeconds = nil
		end
		return copy
	end

	-- Victoire et accès ---------------------------------------------------------------

	case("P1 : première victoire, clé posée une fois", function(check)
		local server = newServer(newWorld(), "S1")
		check(server.load(USER_A).ok, "chargement")
		local before = stable(server.profile(USER_A))
		check(server.win(USER_A, ROOT), "victoire attribuée")
		local after = server.profile(USER_A)
		check(after.achievements[V(ROOT)] == true, "clé de victoire absente")
		check(after.achievements[R(ROOT)] == nil, "récompense posée trop tôt")
		check(after.inventory.resources[resourceOf(ROOT)] == nil, "unités ajoutées sans réclamation")
		check(server.saveCount("guardian_victory") == 1, `1 sauvegarde attendue, {server.saveCount("guardian_victory")}`)
		local view = server.siteView(USER_A, ROOT)
		check(view.access == Access.Unlocked and view.rewardClaimed == false, "vue : débloqué, récompense due")
		local expected = deepCopy(before)
		expected.achievements[V(ROOT)] = true
		check(deepEqual(stable(after), expected), "autre champ modifié")
		local last = server.messages[#server.messages - 1]
		check(last ~= nil and last.message.type == "victory" and last.message.firstVictory == true, "message de première victoire")
		check(last ~= nil and last.message.persistent == true, "magasin persistant attendu")
	end)

	case("P2 : victoire répétée sans écriture", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.win(USER_A, ROOT)
		local before = server.profile(USER_A)
		local saves = #server.saves
		check(server.win(USER_A, ROOT), "2e victoire attribuée")
		check(#server.saves == saves, "sauvegarde de trop")
		check(deepEqual(server.profile(USER_A), before), "profil modifié")
		local victory = server.messages[#server.messages - 1]
		check(victory.message.firstVictory == false, "first=false attendu")
		check(server.profile(USER_A).inventory.resources[resourceOf(ROOT)] == nil, "unités ajoutées")
	end)

	case("P3 : reconnexion sur un nouveau serveur", function(check)
		local world = newWorld()
		local first = newServer(world, "S1")
		first.load(USER_A)
		first.win(USER_A, ROOT)
		check(first.data.ReleasePlayer(USER_A).ok, "sortie")
		local second = newServer(world, "S2")
		check(second.load(USER_A).ok, "rechargement")
		check(second.sites.HasVictory(USER_A, ROOT), "victoire perdue")
		local view = second.siteView(USER_A, ROOT)
		check(view.access == Access.Unlocked and view.rewardClaimed == false, "débloqué, récompense due")
		local result = second.sites.HandleActivate(USER_A, { siteId = ROOT }, 0)
		check(result.ok, `activation refusée : {result.code}`)
	end)

	case("P4 : défaite ou départ après déblocage", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.win(USER_A, ROOT)
		local saves = #server.saves
		-- Défaite et abandon : aucun appel à RecordVictory (GuardianTests) ;
		-- départ : la copie de session est effacée, pas le profil.
		server.sites.RemovePlayer(USER_A)
		check(server.profile(USER_A).achievements[V(ROOT)] == true, "clé retirée")
		check(server.sites.HasVictory(USER_A, ROOT), "accès perdu")
		check(#server.saves == saves, "écriture inattendue")
	end)

	-- Préservation des données -------------------------------------------------------

	case("P5 : migrations v1 et v2 conservent clés et unités", function(check)
		local world = newWorld()
		local v1 = DataSchema.newProfile()
		v1.schemaVersion = 1
		v1.achievements = nil
		v1.collection = nil
		v1.inventory.resources[resourceOf(SUN)] = 3
		world.store.seed(storeKey(USER_A), { profile = deepCopy(v1) })
		local v2 = DataSchema.newProfile()
		v2.schemaVersion = 2
		v2.collection = nil
		v2.achievements = { collect_100 = true, [V(SUN)] = true, [R(SUN)] = true }
		v2.inventory.resources[resourceOf(SUN)] = 3
		world.store.seed(storeKey(USER_B), { profile = deepCopy(v2) })
		local server = newServer(world, "S1")
		check(server.load(USER_A).ok and server.load(USER_B).ok, "chargement")
		local a, b = server.profile(USER_A), server.profile(USER_B)
		check(a.schemaVersion == 3 and b.schemaVersion == 3, "version 3 attendue")
		check(a.inventory.resources[resourceOf(SUN)] == 3, "v1 : unités perdues")
		check(b.achievements.collect_100 == true, "v2 : succès perdu")
		check(b.achievements[V(SUN)] == true and b.achievements[R(SUN)] == true, "v2 : clés perdues")
		check(b.inventory.resources[resourceOf(SUN)] == 3, "v2 : unités perdues")
		check(server.sites.HasVictory(USER_B, SUN), "v2 : accès perdu")
		check(server.claim(USER_B, SUN).code == Code.AlreadyClaimed, "v2 : récompense attribuée deux fois")
		check(deepEqual(world.store.peek(storeKey(USER_A)).profile, v1), "v1 : entrée stockée modifiée au chargement")
		check(deepEqual(world.store.peek(storeKey(USER_B)).profile, v2), "v2 : entrée stockée modifiée au chargement")
	end)

	case("P6 : aller-retour J_full et J_partial", function(check)
		for _, preset in ipairs({ "J_full", "J_partial" }) do
			local world = newWorld()
			local first = newServer(world, "S1")
			first.load(USER_A)
			local applied, reason = StudioTestPresets.apply(first.data, USER_A, preset)
			check(applied, `{preset} : {tostring(reason)}`)
			local before = stable(first.profile(USER_A))
			first.win(USER_A, ROOT)
			local claim = first.claim(USER_A, ROOT)
			check(claim.ok, `{preset} : réclamation {claim.code}`)
			check(first.data.ReleasePlayer(USER_A).ok, `{preset} : sortie`)
			local second = newServer(world, "S2")
			second.load(USER_A)
			local expected = deepCopy(before)
			expected.achievements[V(ROOT)] = true
			expected.achievements[R(ROOT)] = true
			expected.inventory.resources[resourceOf(ROOT)] = 3
			local after = stable(second.profile(USER_A))
			check(deepEqual(after, expected), `{preset} : profil différent après aller-retour`)
			check(deepEqual(after.collection, before.collection), `{preset} : Journal modifié`)
		end
	end)

	case("P7 : valeurs corrompues refusées, sauvegarde intacte", function(check)
		local corruptions: { (profile: any) -> () } = {
			function(profile: any)
				profile.achievements[V(ROOT)] = false
			end,
			function(profile: any)
				profile.achievements[R(ROOT)] = 1
			end,
		}
		for index, corrupt in ipairs(corruptions) do
			local world = newWorld()
			local profile = DataSchema.newProfile()
			corrupt(profile)
			local seeded = { profile = profile }
			world.store.seed(storeKey(USER_A), deepCopy(seeded))
			local server = newServer(world, "S1")
			local result = server.load(USER_A)
			check(not result.ok, `cas {index} : profil corrompu accepté`)
			check(not server.data.IsLoaded(USER_A), `cas {index} : session ouverte`)
			check(deepEqual(world.store.peek(storeKey(USER_A)).profile, profile), `cas {index} : sauvegarde écrasée`)
			check(server.claim(USER_A, ROOT).code == Code.ProfileNotLoaded, `cas {index} : réclamation sans profil`)
		end
		-- Quantité négative : réparée à 0 au chargement (règle existante du
		-- schéma pour toutes les quantités), entrée stockée intacte.
		local world = newWorld()
		local profile = DataSchema.newProfile()
		profile.inventory.resources[resourceOf(ROOT)] = -3
		world.store.seed(storeKey(USER_A), { profile = deepCopy(profile) })
		local server = newServer(world, "S1")
		check(server.load(USER_A).ok, "quantité négative : chargement")
		check(server.profile(USER_A).inventory.resources[resourceOf(ROOT)] == 0, "quantité négative non réparée à 0")
		check(deepEqual(world.store.peek(storeKey(USER_A)).profile, profile), "quantité négative : entrée stockée modifiée")
		server.win(USER_A, ROOT)
		check(server.claim(USER_A, ROOT).ok, "quantité négative : réclamation")
		check(server.profile(USER_A).inventory.resources[resourceOf(ROOT)] == 3, "quantité négative : 3 unités attendues")
	end)

	case("P8 : profil non chargé ou écriture en échec", function(check)
		local server = newServer(newWorld(), "S1")
		-- Profil non chargé : victoire de session seulement.
		check(server.win(USER_B, ROOT), "victoire attribuée")
		check(server.sites.HasVictory(USER_B, ROOT), "victoire de session absente")
		check(server.hasLog("non enregistrée"), "échec non journalisé")
		-- Profil chargé, Update en échec puis rétabli.
		server.load(USER_A)
		server.failUpdate = true
		server.win(USER_A, ROOT)
		check(server.profile(USER_A).achievements[V(ROOT)] == nil, "clé écrite malgré l'échec")
		check(server.sites.HasVictory(USER_A, ROOT), "victoire de session absente")
		check(server.saveCount("guardian_victory", USER_A) == 0, "sauvegarde sans écriture")
		server.failUpdate = false
		server.win(USER_A, ROOT)
		check(server.profile(USER_A).achievements[V(ROOT)] == true, "clé non réécrite")
		check(server.saveCount("guardian_victory", USER_A) == 1, "sauvegarde attendue")
	end)

	case("P9 : échecs de sauvegarde, rien de partiel", function(check)
		local world = newWorld()
		world.store.seed(storeKey(USER_A), { profile = DataSchema.newProfile() })
		local server = newServer(world, "S1")
		server.load(USER_A)
		local stored = deepCopy(world.store.peek(storeKey(USER_A)).profile)
		world.store.setAlwaysFail(true)
		server.win(USER_A, ROOT)
		check(server.claim(USER_A, ROOT).ok, "réclamation en mémoire")
		local memory = server.profile(USER_A)
		check(memory.achievements[V(ROOT)] and memory.achievements[R(ROOT)], "clés absentes en mémoire")
		check(memory.inventory.resources[resourceOf(ROOT)] == 3, "unités absentes en mémoire")
		check(deepEqual(world.store.peek(storeKey(USER_A)).profile, stored), "sauvegarde partielle ou écrasée")
		world.store.setAlwaysFail(false)
		world.store.failNext(2)
		check(server.data.SavePlayer(USER_A).ok, "reprise de sauvegarde")
		local saved = world.store.peek(storeKey(USER_A)).profile
		check(saved.achievements[V(ROOT)] and saved.achievements[R(ROOT)], "clés non sauvegardées")
		check(saved.inventory.resources[resourceOf(ROOT)] == 3, "unités non sauvegardées")
	end)

	case("P10 : succès, analytics et audit non affectés", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.load(USER_B)
		-- A : 4 victoires, 4 récompenses, 12 unités. B : témoin sans clé.
		-- Mêmes statistiques (12 collectes : le sac reste explicable).
		for _, userId in ipairs({ USER_A, USER_B }) do
			server.data.Update(userId, function(draft: any): boolean?
				draft.stats.totalResourcesCollected = 12
				if userId == USER_A then
					for siteId in pairs(GuardianConfig.Sites) do
						draft.achievements[V(siteId)] = true
						draft.achievements[R(siteId)] = true
						draft.inventory.resources[resourceOf(siteId)] = 3
					end
				end
				return true
			end)
		end
		local achievements = AchievementService.new({ playerData = server.data })
		local grantsA = achievements.Evaluate(USER_A)
		local grantsB = achievements.Evaluate(USER_B)
		check(#grantsA == #grantsB, `succès différents avec les clés : {#grantsA} contre {#grantsB}`)
		local a, b = server.profile(USER_A), server.profile(USER_B)
		check(a.currencies.coins == b.currencies.coins, "Coins différents avec les clés")
		for siteId in pairs(GuardianConfig.Sites) do
			check(a.achievements[V(siteId)] == true and a.achievements[R(siteId)] == true, `{siteId} : clés retirées par Evaluate`)
		end
		local issues = ProfileAudit.run(server.profile(USER_A))
		check(#issues == 0, `aucun constat attendu, {#issues} ({issues[1] and issues[1].check or ""})`)
		local state = InventoryService.describe(server.profile(USER_A))
		check(state.used == 12, `12 places attendues, {state.used}`)
	end)

	case("P11 : deux joueurs isolés", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.load(USER_B)
		server.win(USER_A, ROOT)
		server.win(USER_B, SUN)
		check(server.claim(USER_A, ROOT).ok and server.claim(USER_B, SUN).ok, "réclamations")
		local a, b = server.profile(USER_A), server.profile(USER_B)
		check(a.achievements[V(ROOT)] and a.achievements[R(ROOT)] and not a.achievements[V(SUN)], "A : clés")
		check(b.achievements[V(SUN)] and b.achievements[R(SUN)] and not b.achievements[V(ROOT)], "B : clés")
		check(a.inventory.resources[resourceOf(ROOT)] == 3 and a.inventory.resources[resourceOf(SUN)] == nil, "A : unités")
		check(b.inventory.resources[resourceOf(SUN)] == 3 and b.inventory.resources[resourceOf(ROOT)] == nil, "B : unités")
		check(server.saveCount("sacred_reward", USER_A) == 1 and server.saveCount("sacred_reward", USER_B) == 1, "sauvegardes")
		check(server.claim(USER_B, ROOT).code == Code.RequirementNotMet, "B réclame le site de A")
	end)

	case("P12 : site, nœud ou gardien inconnus", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		local before = server.profile(USER_A)
		check(not server.win(USER_A, "Nowhere"), "site inconnu attribué")
		check(not server.win(USER_A, ROOT, "SandGuardian"), "gardien incohérent attribué")
		check(server.hasLog("gardien incohérent"), "gardien incohérent non journalisé")
		check(server.claim(USER_A, ROOT, { nodeId = "Fake_1" }).code == Code.InvalidTarget, "nœud inconnu")
		check(deepEqual(server.profile(USER_A), before), "profil modifié")
		check(#server.saves == 0, "sauvegarde inattendue")
	end)

	-- Réclamation de la récompense ---------------------------------------------------

	case("P13 : réclamation unique", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.win(USER_A, ROOT)
		local result = server.claim(USER_A, ROOT)
		check(result.ok and result.amount == 3 and result.resourceId == resourceOf(ROOT), `réclamation {result.code}`)
		local profile = server.profile(USER_A)
		check(profile.inventory.resources[resourceOf(ROOT)] == 3, "3 unités attendues")
		check(profile.achievements[R(ROOT)] == true, "clé de récompense absente")
		check(server.saveCount("sacred_reward") == 1, "sauvegarde attendue")
		check(server.hasLog("SacredReward:" .. resourceOf(ROOT)), "attribution non journalisée")
		check(server.siteView(USER_A, ROOT).rewardClaimed == true, "vue non mise à jour")
		local again = server.claim(USER_A, ROOT, { nodeId = `{ROOT}_Sacred_2` })
		check(again.code == Code.AlreadyClaimed, `ALREADY_CLAIMED attendu, {again.code}`)
		check(deepEqual(server.profile(USER_A), profile), "profil modifié par la 2e réclamation")
	end)

	case("P13b : sans victoire personnelle", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.load(USER_B)
		server.win(USER_A, ROOT)
		local a = server.profile(USER_A)
		check(server.claim(USER_B, ROOT).code == Code.RequirementNotMet, "B sans victoire")
		check(server.profile(USER_B).inventory.resources[resourceOf(ROOT)] == nil, "B : unités ajoutées")
		check(deepEqual(server.profile(USER_A), a), "profil de A modifié par B")
	end)

	case("P13c : victoire de session seule, clés posées ensemble", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.failUpdate = true
		server.win(USER_A, ROOT)
		server.failUpdate = false
		check(server.profile(USER_A).achievements[V(ROOT)] == nil, "préparation : clé déjà écrite")
		check(server.claim(USER_A, ROOT).ok, "réclamation")
		local profile = server.profile(USER_A)
		check(profile.achievements[V(ROOT)] == true and profile.achievements[R(ROOT)] == true, "clés non posées ensemble")
		check(profile.inventory.resources[resourceOf(ROOT)] == 3, "unités")
	end)

	case("P14 : sac sans assez de place, droit conservé", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.win(USER_A, ROOT)
		local capacity = InventoryService.describe(server.profile(USER_A)).capacity
		for free = 0, 2 do
			server.setBag(USER_A, capacity - free)
			local before = server.profile(USER_A)
			local result = server.claim(USER_A, ROOT)
			check(result.code == Code.InventoryFull, `{free} place(s) : INVENTORY_FULL attendu, {result.code}`)
			check(deepEqual(server.profile(USER_A), before), `{free} place(s) : profil modifié`)
			check(server.siteView(USER_A, ROOT).rewardClaimed == false, `{free} place(s) : droit perdu`)
		end
		check(server.saveCount("sacred_reward") == 0, "sauvegarde sans attribution")
	end)

	case("P14b : réclamation différée après avoir vidé le sac", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.win(USER_A, ROOT)
		local capacity = InventoryService.describe(server.profile(USER_A)).capacity
		server.setBag(USER_A, capacity - 2)
		check(server.claim(USER_A, ROOT).code == Code.InventoryFull, "préparation : sac plein")
		server.setBag(USER_A, 0)
		local result = server.claim(USER_A, ROOT)
		check(result.ok, `réclamation différée {result.code}`)
		check(server.profile(USER_A).inventory.resources[resourceOf(ROOT)] == 3, "3 unités attendues")
	end)

	case("P14c : droit conservé après reconnexion", function(check)
		local world = newWorld()
		local first = newServer(world, "S1")
		first.load(USER_A)
		first.win(USER_A, ROOT)
		first.setBag(USER_A, InventoryService.describe(first.profile(USER_A)).capacity)
		check(first.claim(USER_A, ROOT).code == Code.InventoryFull, "préparation : sac plein")
		first.data.ReleasePlayer(USER_A)
		local second = newServer(world, "S2")
		second.load(USER_A)
		second.setBag(USER_A, 0)
		check(second.claim(USER_A, ROOT).ok, "réclamation sur le nouveau serveur")
		check(second.profile(USER_A).inventory.resources[resourceOf(ROOT)] == 3, "3 unités attendues")
	end)

	case("P14d : exactement 3 places libres", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.win(USER_A, ROOT)
		local capacity = InventoryService.describe(server.profile(USER_A)).capacity
		server.setBag(USER_A, capacity - 3)
		check(server.claim(USER_A, ROOT).ok, "réclamation")
		local state = InventoryService.describe(server.profile(USER_A))
		check(state.used == state.capacity, `sac plein attendu, {state.used}/{state.capacity}`)
	end)

	case("P15 : deux demandes dans la même frame", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.win(USER_A, ROOT)
		local first = server.claim(USER_A, ROOT, { nodeId = `{ROOT}_Sacred_1` })
		local second = server.claim(USER_A, ROOT, { nodeId = `{ROOT}_Sacred_2` })
		check(first.ok, `1re demande {first.code}`)
		check(second.code == Code.AlreadyClaimed, `2e demande : ALREADY_CLAIMED attendu, {second.code}`)
		check(server.profile(USER_A).inventory.resources[resourceOf(ROOT)] == 3, "3 unités exactement")
		check(server.saveCount("sacred_reward") == 1, "une seule sauvegarde")
	end)

	case("P15b : pas de seconde attribution sur un autre serveur", function(check)
		local world = newWorld()
		local first = newServer(world, "S1")
		first.load(USER_A)
		first.win(USER_A, ROOT)
		check(first.claim(USER_A, ROOT).ok, "réclamation")
		check(first.data.ReleasePlayer(USER_A).ok, "sortie")
		local second = newServer(world, "S2")
		second.load(USER_A)
		check(second.claim(USER_A, ROOT).code == Code.AlreadyClaimed, "ALREADY_CLAIMED attendu")
		check(second.profile(USER_A).inventory.resources[resourceOf(ROOT)] == 3, "jamais 6 unités")
	end)

	case("P15c : sauvegarde perdue, état cohérent", function(check)
		local world = newWorld()
		local first = newServer(world, "S1")
		first.load(USER_A)
		first.win(USER_A, ROOT)
		world.store.setAlwaysFail(true)
		check(first.claim(USER_A, ROOT).ok, "réclamation en mémoire")
		first.data.ReleasePlayer(USER_A)
		world.store.setAlwaysFail(false)
		-- Verrou du premier serveur expiré.
		world.now += modules.DataConfig.SessionLock.timeoutSeconds + 60
		local second = newServer(world, "S2")
		check(second.load(USER_A).ok, "rechargement")
		local profile = second.profile(USER_A)
		local claimed = profile.achievements[R(ROOT)] == true
		local units = profile.inventory.resources[resourceOf(ROOT)]
		check((claimed and units == 3) or (not claimed and units == nil), "état incohérent")
		local retry = second.claim(USER_A, ROOT)
		if claimed then
			check(retry.code == Code.AlreadyClaimed, "ALREADY_CLAIMED attendu")
		else
			check(retry.ok, `réclamation attendue, {retry.code}`)
		end
		check(second.profile(USER_A).inventory.resources[resourceOf(ROOT)] == 3, "3 unités exactement")
	end)

	case("P15d : payload falsifié", function(check)
		local server = newServer(newWorld(), "S1")
		server.load(USER_A)
		server.win(USER_A, ROOT)
		local before = server.profile(USER_A)
		local forged: { any } = {
			{ nodeId = `{ROOT}_Sacred_1`, amount = 99 },
			{ resourceId = resourceOf(ROOT) },
			{ nodeId = `{ROOT}_Sacred_1`, resourceId = "wood" },
		}
		for index, payload in ipairs(forged) do
			check(server.claim(USER_A, ROOT, payload).code == Code.InvalidTarget, `payload {index} accepté`)
		end
		check(server.claim(USER_A, ROOT, nil, 1).code == Code.InvalidTarget, "argument en trop accepté")
		check(deepEqual(server.profile(USER_A), before), "profil modifié")
		local result = server.claim(USER_A, ROOT)
		check(result.ok and result.amount == 3, "quantité fixée par le serveur")
	end)

	return failures, caseCount
end

return GuardianPersistenceTests
