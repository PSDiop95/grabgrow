--!strict
-- Tests du journal de collection et de la migration v2 -> v3 (T8.6, D-022).
-- Vrais services (PlayerDataService, InventoryService, CollectionService,
-- SellService, ResourceSpawner), magasin en mémoire, horloges simulées,
-- positions fixées par le test. Aucune API Roblox, aucun DataStore réel.

local CollectionJournalTests = {}

export type Modules = {
	CollectionJournalRules: any,
	DataSchema: any,
	DataConfig: any,
	PlayerDataService: any,
	MemoryDataStore: any,
	InventoryService: any,
	CollectionService: any,
	SellService: any,
	ResourceSpawner: any,
	RateLimitService: any,
	ResourceConfig: any,
	WorldConfig: any,
	UpgradeConfig: any,
	CollectionSecurityConfig: any,
	Remotes: any,
	StudioTestPresets: any,
	Localization: any,
	FeedbackRules: any,
}

local USER_A = 8601
local USER_B = 8602
local KEY_A = "Player_8601"
local ZONE = "Journal_Zone"

local LEAF = "j_leaf_1"
local LEAF_2 = "j_leaf_2"
local WOOD = "j_wood_1"
local STONE_FAR = "j_stone_far"
local SANDSTONE = "j_sandstone_1"

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

local function countKeys(t: any): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function CollectionJournalTests.run(modules: Modules): ({ string }, number)
	local Rules = modules.CollectionJournalRules
	local DataSchema = modules.DataSchema
	local DataConfig = modules.DataConfig
	local PlayerDataService = modules.PlayerDataService
	local MemoryDataStore = modules.MemoryDataStore
	local InventoryService = modules.InventoryService
	local CollectionService = modules.CollectionService
	local SellService = modules.SellService
	local ResourceSpawner = modules.ResourceSpawner
	local RateLimitService = modules.RateLimitService
	local ResourceConfig = modules.ResourceConfig
	local WorldConfig = modules.WorldConfig
	local Security = modules.CollectionSecurityConfig
	local ResultCode = modules.Remotes.ResultCode
	local Code = PlayerDataService.Code

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

	-- Profil tel qu'écrit par un serveur v2 (T7 à T8.5) : sans journal.
	local function v2Profile(): any
		local profile = DataSchema.newProfile()
		profile.schemaVersion = 2
		profile.collection = nil
		return profile
	end

	-- Profil v2 « riche » : données économiques et ressources des quatre mondes.
	local function richV2Profile(): any
		local profile = v2Profile()
		profile.currencies.coins = 123_456
		profile.currencies.gems = 3
		profile.inventory.resources = {
			green_leaf = 4,
			sandstone = 3,
			ice_shard = 2,
			mystic_core = 1,
			ancienne_ressource = 5,
		}
		profile.upgrades.backpackLevel = 10
		profile.upgrades.grabberLevel = 4
		profile.upgrades.magnetLevel = 2
		profile.worlds.GoldenDesert = true
		profile.worlds.FrozenPeaks = true
		profile.worlds.MysticWorld = true
		profile.stats.totalResourcesCollected = 9_000
		profile.stats.totalCoinsEarned = 400_000
		profile.stats.totalCoinsSpent = 276_544
		profile.stats.totalSales = 120
		profile.stats.playTimeSeconds = 36_000
		profile.achievements = { collect_100 = true, world_2 = true }
		profile.settings.musicEnabled = false
		profile.lastSaveAt = 1_790_000_000
		profile.champFutur = { valeur = 1 }
		return profile
	end

	-- ENVIRONNEMENT DE COLLECTE ----------------------------------------------

	local function newEnv(
		userIds: { number },
		options: { prepare: ((profile: any) -> ())?, store: any?, unlimited: boolean? }?
	)
		local env = {
			now = 500,
			store = (if options then options.store else nil) or MemoryDataStore.new(),
			positions = {} :: { [number]: any },
			timers = {} :: { { at: number, callback: () -> () } },
		}
		local function clock(): number
			return env.now
		end
		local prepare = if options then options.prepare else nil
		if prepare then
			local profile = DataSchema.newProfile()
			prepare(profile)
			env.store.seed(KEY_A, { profile = profile })
		end
		local unlimited = {
			Allow = function(): boolean
				return true
			end,
			Clear = function() end,
		}
		env.playerData = PlayerDataService.new({
			store = env.store,
			serverId = "J",
			clock = function(): number
				return 1_000_000
			end,
			wait = function() end,
			spawn = function(callback: () -> ())
				callback()
			end,
			log = function() end,
		})
		env.inventory = InventoryService.new({ playerData = env.playerData })
		env.spawner = ResourceSpawner.new({
			schedule = function(delaySeconds: number, callback: () -> ())
				table.insert(env.timers, { at = env.now + delaySeconds, callback = callback })
			end,
		})
		env.rateLimit = RateLimitService.new({
			clock = clock,
			limits = Security.RateLimits,
			logEveryRejections = Security.RateLimitFeedback.logEveryRejections,
			log = function() end,
		})
		local function getPosition(userId: number): any
			return env.positions[userId]
		end
		env.collection = CollectionService.new({
			playerData = env.playerData,
			inventory = env.inventory,
			spawner = env.spawner,
			rateLimit = if options and options.unlimited then unlimited else env.rateLimit,
			clock = clock,
			getCharacterPosition = getPosition,
			log = function() end,
		})
		env.sell = SellService.new({
			playerData = env.playerData,
			rateLimit = unlimited,
			getSellZone = function(zoneId: string): any
				if zoneId == ZONE then
					return { position = { X = 0, Y = 0, Z = 0 } }
				end
				return nil
			end,
			getCharacterPosition = getPosition,
			clock = clock,
			log = function() end,
		})

		env.spawner.Register(LEAF, "green_leaf", { X = 0, Y = 0, Z = 0 })
		env.spawner.Register(LEAF_2, "green_leaf", { X = 4, Y = 0, Z = 0 })
		env.spawner.Register(WOOD, "wood", { X = 0, Y = 0, Z = 5 })
		env.spawner.Register(STONE_FAR, "stone", { X = 300, Y = 0, Z = 0 })
		env.spawner.Register(SANDSTONE, "sandstone", { X = 2, Y = 0, Z = 2 })

		for _, userId in ipairs(userIds) do
			assert(env.playerData.LoadPlayer(userId).ok, "chargement du joueur de test")
			env.positions[userId] = { X = 1, Y = 0, Z = 1 }
		end

		function env.advance(seconds: number)
			env.now += seconds
			local remaining, due = {}, {}
			for _, timer in ipairs(env.timers) do
				table.insert(if timer.at <= env.now + 1e-9 then due else remaining, timer)
			end
			env.timers = remaining
			for _, timer in ipairs(due) do
				timer.callback()
			end
		end

		function env.collect(userId: number, nodeId: string): any
			local result = env.collection.HandleRequest(userId, { resourceId = nodeId }, 0)
			env.advance(5)
			return result
		end

		function env.discovered(userId: number): { [string]: boolean }
			return env.playerData.GetData(userId).collection.discoveredResources
		end

		return env
	end

	-- PERSISTANCE : plusieurs « serveurs » sur un même magasin -------------

	local function newWorld()
		return { store = MemoryDataStore.new(), now = 1_000_000 }
	end

	local function newServer(world: any, serverId: string)
		local server = { logs = {} :: { string } }
		server.service = PlayerDataService.new({
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
			log = function(level: string, message: string)
				table.insert(server.logs, `{level} {message}`)
			end,
		})
		return server
	end

	local function recoveryKeys(world: any): { string }
		local list = {}
		local prefix = DataConfig.Store.recoveryKeyPrefix
		for _, key in ipairs(world.store.keys()) do
			if string.sub(key, 1, #prefix) == prefix then
				table.insert(list, key)
			end
		end
		return list
	end

	-- CATALOGUE ET RÉSUMÉ -----------------------------------------------------

	case("catalogue : 20 ressources, 5 par monde, ordre des mondes", function(check)
		local catalog = Rules.catalog()
		check(#catalog == 4, `4 mondes attendus, trouvé {#catalog}`)
		local seen: { [string]: boolean } = {}
		local total = 0
		for index, world in ipairs(catalog) do
			check(WorldConfig[world.worldId] ~= nil, `monde {world.worldId} absent de WorldConfig`)
			check(WorldConfig[world.worldId].order == index, `{world.worldId} hors ordre`)
			check(#world.resourceIds == 5, `{world.worldId} : {#world.resourceIds} ressources`)
			for _, resourceId in ipairs(world.resourceIds) do
				check(not seen[resourceId], `{resourceId} en double`)
				seen[resourceId] = true
				total += 1
				check(ResourceConfig[resourceId].worldId == world.worldId, `{resourceId} dans le mauvais monde`)
			end
		end
		check(total == 20 and total == countKeys(ResourceConfig), `catalogue {total} ≠ ResourceConfig`)
		local expected = {
			GreenValley = { "green_leaf", "wood", "stone", "wild_fruit", "green_crystal" },
			GoldenDesert = { "sandstone", "copper_ore", "fossil", "gold_nugget", "sun_crystal" },
			FrozenPeaks = { "ice_shard", "silver_ore", "frozen_stone", "blue_crystal", "ice_diamond" },
			MysticWorld = { "mystic_dust", "star_fragment", "spectral_ore", "purple_crystal", "mystic_core" },
		}
		for _, world in ipairs(catalog) do
			check(deepEqual(world.resourceIds, expected[world.worldId]), `{world.worldId} : ordre ou contenu inattendu`)
		end
		check(table.isfrozen(catalog), "catalogue modifiable")
	end)

	case("résumé : vide, partiel, complet, identifiants ignorés", function(check)
		local empty = Rules.summarize({})
		check(empty.discovered == 0 and empty.total == 20 and empty.percent == 0, "journal vide incorrect")
		check(Rules.summarize(nil).discovered == 0, "journal illisible compté")

		local partial = Rules.summarize({
			green_leaf = true,
			wood = true,
			stone = true,
			sandstone = true,
			mystic_core = true,
			inconnue = true, -- ignorée
			fossil = false, -- ignorée
			copper_ore = 1, -- ignorée
		})
		check(partial.discovered == 5 and partial.total == 20 and partial.percent == 25, "global partiel incorrect")
		local byWorld: { [string]: any } = {}
		for _, world in ipairs(partial.worlds) do
			byWorld[world.worldId] = world
		end
		check(byWorld.GreenValley.discovered == 3 and byWorld.GreenValley.percent == 60, "Green Valley 3/5 ≠ 60 %")
		check(byWorld.GoldenDesert.discovered == 1 and byWorld.GoldenDesert.percent == 20, "Golden Desert 1/5")
		check(byWorld.FrozenPeaks.discovered == 0 and byWorld.FrozenPeaks.percent == 0, "Frozen Peaks 0/5")
		check(byWorld.MysticWorld.discovered == 1 and byWorld.MysticWorld.total == 5, "Mystic World 1/5")

		local all = {}
		for resourceId in pairs(ResourceConfig) do
			all[resourceId] = true
		end
		local full = Rules.summarize(all)
		check(full.discovered == 20 and full.percent == 100, "journal complet ≠ 100 %")
		all.green_leaf = nil
		check(Rules.summarize(all).percent == 95, "19/20 ≠ 95 %")
		check(Rules.percentOf(1, 3) == 33 and Rules.percentOf(0, 0) == 0, "arrondi du pourcentage")
	end)

	case("vue client : identifiants du catalogue seulement, copie", function(check)
		local source: any = { wood = true, inconnue = true, stone = false }
		local view = Rules.publicView(source)
		check(view.wood == true and view.inconnue == nil and view.stone == nil, "vue non filtrée")
		view.green_leaf = true
		check(source.green_leaf == nil, "la vue partage la table du profil")
		check(next(Rules.publicView(nil)) == nil, "vue d'un journal illisible non vide")
	end)

	-- DÉCOUVERTE ---------------------------------------------------------------

	case("première collecte : découverte enregistrée avec la ressource", function(check)
		local env = newEnv({ USER_A })
		local result = env.collect(USER_A, LEAF)
		check(result.ok and result.firstDiscovery == true, `collecte {result.code}, firstDiscovery {tostring(result.firstDiscovery)}`)
		local profile = env.playerData.GetData(USER_A)
		check(profile.inventory.resources.green_leaf == 1, "ressource non attribuée")
		check(profile.collection.discoveredResources.green_leaf == true, "découverte absente")
		check(countKeys(profile.collection.discoveredResources) == 1, "autres découvertes inattendues")
		local state = env.collection.GetClientState(USER_A)
		check(state.discovered.green_leaf == true and countKeys(state.discovered) == 1, "état client sans découverte")
	end)

	case("deuxième collecte : aucune duplication", function(check)
		local env = newEnv({ USER_A })
		env.collect(USER_A, LEAF)
		local second = env.collect(USER_A, LEAF_2)
		check(second.ok and second.firstDiscovery == false, "seconde collecte marquée comme découverte")
		check(env.playerData.GetData(USER_A).inventory.resources.green_leaf == 2, "quantité incorrecte")
		check(countKeys(env.discovered(USER_A)) == 1, "entrée dupliquée")
		local other = env.collect(USER_A, WOOD)
		check(other.firstDiscovery == true and countKeys(env.discovered(USER_A)) == 2, "nouvelle ressource non découverte")
	end)

	case("ressource vendue : découverte conservée", function(check)
		local env = newEnv({ USER_A })
		env.collect(USER_A, LEAF)
		env.collect(USER_A, WOOD)
		local sold = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE }, 0)
		check(sold.ok, `vente refusée : {tostring(sold.code)}`)
		local profile = env.playerData.GetData(USER_A)
		check(next(profile.inventory.resources) == nil or (profile.inventory.resources.green_leaf or 0) == 0, "sac non vidé")
		check(profile.collection.discoveredResources.green_leaf == true, "découverte perdue à la vente")
		check(profile.collection.discoveredResources.wood == true, "découverte perdue à la vente (bois)")
		check(Rules.summarize(profile.collection.discoveredResources).discovered == 2, "progression modifiée par la vente")
	end)

	case("ressource non possédée : découverte conservée", function(check)
		local env = newEnv({ USER_A })
		env.collect(USER_A, WOOD)
		env.playerData.Update(USER_A, function(draft: any): boolean?
			draft.inventory.resources.wood = nil
			return nil
		end)
		check(env.playerData.GetData(USER_A).inventory.resources.wood == nil, "préparation")
		check(env.discovered(USER_A).wood == true, "découverte liée au stock")
	end)

	case("collectes refusées : aucune découverte", function(check)
		local env = newEnv({ USER_A })
		-- Trop loin.
		check(env.collect(USER_A, STONE_FAR).code == ResultCode.TooFar, "distance")
		-- Nœud inconnu, payload falsifié, arguments en trop.
		check(env.collect(USER_A, "noeud_inconnu").code == ResultCode.InvalidTarget, "nœud inconnu")
		local forged = env.collection.HandleRequest(USER_A, { resourceId = LEAF, discovered = true }, 0)
		check(forged.code == ResultCode.InvalidTarget and forged.firstDiscovery == false, "champ discovered accepté")
		local forged2 = env.collection.HandleRequest(USER_A, { resourceId = LEAF, firstDiscovery = true }, 0)
		check(forged2.code == ResultCode.InvalidTarget, "champ firstDiscovery accepté")
		local extra = env.collection.HandleRequest(USER_A, { resourceId = LEAF }, 1)
		check(extra.code == ResultCode.InvalidTarget, "argument supplémentaire accepté")
		check(next(env.discovered(USER_A)) == nil, "découverte après des refus")
		-- Cadence : une collecte valide puis une immédiate.
		check(env.collection.HandleRequest(USER_A, { resourceId = LEAF }, 0).ok, "collecte valide")
		local tooFast = env.collection.HandleRequest(USER_A, { resourceId = WOOD }, 0)
		check(tooFast.code == ResultCode.Cooldown and tooFast.firstDiscovery == false, "cadence")
		check(env.discovered(USER_A).wood == nil, "bois découvert malgré la cadence")
		-- Nœud déjà collecté.
		env.advance(1)
		local unavailable = env.collection.HandleRequest(USER_A, { resourceId = LEAF }, 0)
		check(unavailable.code == ResultCode.ResourceUnavailable, `nœud indisponible : {unavailable.code}`)
	end)

	case("sac plein : aucune découverte, ressource restée disponible", function(check)
		local capacity = modules.UpgradeConfig.Backpack.levels[1].value
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.inventory.resources.stone = capacity
			end,
		})
		local result = env.collect(USER_A, LEAF)
		check(result.code == ResultCode.InventoryFull, `code {result.code}`)
		check(result.firstDiscovery == false, "firstDiscovery sur un sac plein")
		check(env.discovered(USER_A).green_leaf == nil, "découverte avec un sac plein")
		check(env.spawner.GetNode(LEAF).state == ResourceSpawner.State.Active, "nœud consommé")
	end)

	case("monde verrouillé : aucune découverte", function(check)
		local env = newEnv({ USER_A })
		local result = env.collect(USER_A, SANDSTONE)
		check(result.code == ResultCode.WorldLocked, `code {result.code}`)
		check(env.discovered(USER_A).sandstone == nil, "découverte dans un monde verrouillé")
		check(env.playerData.GetData(USER_A).inventory.resources.sandstone == nil, "ressource attribuée")
		-- Une fois le monde débloqué (profil serveur), la découverte a lieu.
		env.playerData.Update(USER_A, function(draft: any): boolean?
			draft.worlds.GoldenDesert = true
			return nil
		end)
		local unlocked = env.collect(USER_A, SANDSTONE)
		check(unlocked.ok and unlocked.firstDiscovery == true, "découverte refusée après déblocage")
	end)

	case("ressource inconnue : aucune entrée ajoutée", function(check)
		local env = newEnv({ USER_A })
		local added = env.inventory.AddResource(USER_A, "unobtainium", 1)
		check(not added.ok and added.code == InventoryService.Code.InvalidResource, "ressource inconnue acceptée")
		check(added.firstDiscovery == false, "firstDiscovery pour une ressource inconnue")
		check(next(env.discovered(USER_A)) == nil, "entrée inconnue ajoutée")
		local draft = { collection = { discoveredResources = {} } }
		check(Rules.markDiscovered(draft, "unobtainium") == false, "markDiscovered accepte un inconnu")
		check(next(draft.collection.discoveredResources) == nil, "markDiscovered écrit un inconnu")
	end)

	case("atomicité : mutation annulée = ni ressource ni découverte", function(check)
		-- PlayerData simulé : applique la mutation à une copie et ne la
		-- retient que si elle s'achève sans erreur (comme Update).
		local stored = DataSchema.newProfile()
		stored.collection = nil -- section illisible : markDiscovered échoue
		local fake = {
			GetData = function(): any
				return stored
			end,
			Update = function(_userId: number, mutator: (draft: any) -> boolean?): any
				local draft = table.clone(stored)
				draft.inventory = { resources = table.clone(stored.inventory.resources) }
				draft.stats = table.clone(stored.stats)
				local ok, returned = pcall(mutator, draft)
				if not ok or returned == false then
					return { ok = false, code = "Rejected" }
				end
				stored = draft
				return { ok = true }
			end,
		}
		local inventory = InventoryService.new({ playerData = fake :: any })
		local result = inventory.AddResource(USER_A, "wood", 1)
		check(not result.ok and result.firstDiscovery == false, "ajout accepté sans journal")
		check(stored.inventory.resources.wood == nil, "ressource attribuée sans découverte")
		check(stored.stats.totalResourcesCollected == 0, "statistique modifiée")
	end)

	case("Update strict : journal invalide refusé en mémoire", function(check)
		local env = newEnv({ USER_A })
		local before = env.playerData.GetData(USER_A)
		local result = env.playerData.Update(USER_A, function(draft: any): boolean?
			draft.collection.discoveredResources.wood = false
			return nil
		end)
		check(not result.ok, "valeur false acceptée")
		local result2 = env.playerData.Update(USER_A, function(draft: any): boolean?
			draft.collection = nil
			return nil
		end)
		check(not result2.ok, "suppression du journal acceptée")
		check(deepEqual(env.playerData.GetData(USER_A), before), "profil modifié par une mutation refusée")
	end)

	-- MULTIJOUEUR ------------------------------------------------------------

	case("deux joueurs : journaux indépendants, découverte non partagée", function(check)
		local env = newEnv({ USER_A, USER_B })
		check(env.collect(USER_A, LEAF).firstDiscovery == true, "A : première feuille")
		check(env.discovered(USER_B).green_leaf == nil, "découverte de A partagée avec B")
		check(env.collect(USER_B, LEAF_2).firstDiscovery == true, "B : sa propre première feuille")
		check(env.collect(USER_B, WOOD).firstDiscovery == true, "B : bois")
		check(env.discovered(USER_A).wood == nil, "découverte de B partagée avec A")
		check(countKeys(env.discovered(USER_A)) == 1 and countKeys(env.discovered(USER_B)) == 2, "comptes")
		local stateA = env.collection.GetClientState(USER_A)
		local stateB = env.collection.GetClientState(USER_B)
		check(stateA.discovered.wood == nil and stateB.discovered.wood == true, "états clients mélangés")
	end)

	case("deux joueurs, même ressource, même nœud : un seul l'obtient", function(check)
		local env = newEnv({ USER_A, USER_B }, { unlimited = true })
		local a = env.collection.HandleRequest(USER_A, { resourceId = LEAF }, 0)
		local b = env.collection.HandleRequest(USER_B, { resourceId = LEAF }, 0)
		check(a.ok and a.firstDiscovery, "A")
		check(b.code == ResultCode.ResourceUnavailable and not b.firstDiscovery, "B découvre un nœud déjà pris")
		check(env.discovered(USER_B).green_leaf == nil, "découverte sans ressource pour B")
	end)

	case("sécurité : profil absent, spam, aucune requête de modification", function(check)
		local env = newEnv({ USER_A })
		local absent = env.collection.HandleRequest(USER_B, { resourceId = LEAF }, 0)
		check(absent.code == ResultCode.ProfileNotLoaded and not absent.firstDiscovery, "profil absent")
		check(env.collection.GetClientState(USER_B) == nil, "état d'un profil absent")
		local limited = 0
		for _ = 1, 40 do
			local result = env.collection.HandleRequest(USER_A, { resourceId = STONE_FAR }, 0)
			if result.code == ResultCode.RateLimited then
				limited += 1
			end
		end
		check(limited > 0, "rafale non limitée")
		check(next(env.discovered(USER_A)) == nil, "découverte pendant une rafale")
		-- Aucun RemoteEvent client -> serveur ne concerne le journal.
		for name in pairs(modules.Remotes.Name) do
			check(string.find(string.lower(name), "journal") == nil, `RemoteEvent {name} dédié au journal`)
			check(string.find(string.lower(name), "discover") == nil, `RemoteEvent {name} dédié aux découvertes`)
		end
		-- L'état client est une copie : le modifier ne change pas le profil.
		local state = env.collection.GetClientState(USER_A)
		state.discovered.mystic_core = true
		check(env.discovered(USER_A).mystic_core == nil, "état client relié au profil")
	end)

	-- MIGRATION v2 -> v3 (DataSchema) ---------------------------------------

	case("v2 valide : journal vide, toutes les données conservées", function(check)
		local raw = richV2Profile()
		local profile, code, message, repairs = DataSchema.normalize(raw)
		check(profile ~= nil, `refusé : {tostring(code)} {tostring(message)}`)
		if profile == nil then
			return
		end
		check(profile.schemaVersion == 3, "version finale ≠ 3")
		check(deepEqual(profile.collection, { discoveredResources = {} }), "journal non vide (D-022 D3)")
		check(#repairs == 0, `réparations inattendues : {table.concat(repairs, " ; ")}`)
		check(raw.schemaVersion == 2 and raw.collection == nil, "entrée modifiée")
		for key, value in pairs(raw) do
			if key ~= "schemaVersion" then
				check(deepEqual(profile[key], value), `section {key} modifiée par la migration`)
			end
		end
		check(profile.inventory.resources.ancienne_ressource == 5, "ressource inconnue perdue")
		check(DataSchema.validate(profile), "profil migré invalide")
	end)

	case("v3 valide : inchangé", function(check)
		local raw = DataSchema.newProfile()
		raw.collection.discoveredResources = { green_leaf = true, ice_diamond = true }
		raw.currencies.coins = 50
		local profile, _, _, repairs = DataSchema.normalize(raw)
		check(profile ~= nil and #repairs == 0, "v3 conforme réparé ou refusé")
		check(deepEqual(profile, raw), "v3 modifié")
	end)

	case("profil neuf : v3 directement", function(check)
		local profile = DataSchema.newProfile()
		check(profile.schemaVersion == DataConfig.SchemaVersion and DataConfig.SchemaVersion == 3, "version")
		check(deepEqual(profile.collection, { discoveredResources = {} }), "journal du profil neuf")
		local other = DataSchema.newProfile()
		profile.collection.discoveredResources.wood = true
		check(other.collection.discoveredResources.wood == nil, "journal partagé entre profils")
	end)

	case("migration répétée : idempotente", function(check)
		local step = DataSchema.Migrations[2]
		local once = step(richV2Profile())
		once.collection.discoveredResources.wood = true
		once.schemaVersion = 2 -- rejoue l'étape sur un profil déjà migré
		local twice = step(once)
		check(twice.schemaVersion == 3, "version")
		check(twice.collection.discoveredResources.wood == true, "découverte effacée par une seconde migration")
		local first = DataSchema.normalize(richV2Profile())
		local again = DataSchema.normalize(first)
		check(deepEqual(first, again), "normalize(normalize(v2)) ≠ normalize(v2)")
	end)

	case("v2 avec section collection existante : conservée", function(check)
		local raw = v2Profile()
		raw.collection = { discoveredResources = { wood = true }, extra = "garde" }
		local profile = DataSchema.normalize(raw)
		check(profile ~= nil and profile.collection.discoveredResources.wood == true, "découverte existante perdue")
		check(profile ~= nil and profile.collection.extra == "garde", "clé inconnue perdue")
		local raw2 = v2Profile()
		raw2.collection = {}
		local profile2 = DataSchema.normalize(raw2)
		check(profile2 ~= nil and type(profile2.collection.discoveredResources) == "table", "sous-section non ajoutée")
	end)

	case("D-022 D3 : inventaire v2 non converti en découvertes", function(check)
		local profile = DataSchema.normalize(richV2Profile())
		check(profile ~= nil and next(profile.collection.discoveredResources) == nil, "historique reconstitué")
		check(profile ~= nil and profile.inventory.resources.green_leaf == 4, "quantités modifiées")
	end)

	case("profil corrompu : refusé, jamais réparé", function(check)
		local samples: { [string]: () -> any } = {
			["v2 collection texte"] = function()
				local p = v2Profile()
				p.collection = "x"
				return p
			end,
			["v2 discoveredResources nombre"] = function()
				local p = v2Profile()
				p.collection = { discoveredResources = 5 }
				return p
			end,
			["v3 valeur false"] = function()
				local p = DataSchema.newProfile()
				p.collection.discoveredResources.wood = false
				return p
			end,
			["v3 valeur nombre"] = function()
				local p = DataSchema.newProfile()
				p.collection.discoveredResources.wood = 1
				return p
			end,
			["v3 clé numérique"] = function()
				local p = DataSchema.newProfile()
				p.collection.discoveredResources[1] = true
				return p
			end,
			["v3 clé vide"] = function()
				local p = DataSchema.newProfile()
				p.collection.discoveredResources[""] = true
				return p
			end,
			["v3 clé trop longue"] = function()
				local p = DataSchema.newProfile()
				p.collection.discoveredResources[string.rep("a", 65)] = true
				return p
			end,
			["v3 collection booléen"] = function()
				local p = DataSchema.newProfile()
				p.collection = true
				return p
			end,
			["v2 monnaie corrompue"] = function()
				local p = v2Profile()
				p.currencies.coins = "beaucoup"
				return p
			end,
		}
		for name, build in pairs(samples) do
			local raw = build()
			local before = DataSchema.normalize(raw) -- ne doit pas modifier raw
			check(before == nil, `{name} : accepté`)
			local _, code = DataSchema.normalize(raw)
			check(code == DataSchema.ErrorCode.CorruptData, `{name} : code {tostring(code)}`)
		end
	end)

	case("profil incomplet : sections du journal ajoutées et signalées", function(check)
		local missing = DataSchema.newProfile()
		missing.collection = nil
		local p1, _, _, r1 = DataSchema.normalize(missing)
		check(p1 ~= nil and type(p1.collection.discoveredResources) == "table", "collection non ajoutée")
		check(#r1 >= 1, "ajout non signalé")
		check(not DataSchema.validate(missing), "validate accepte un v3 sans journal")
		local partial = DataSchema.newProfile()
		partial.collection = {}
		local p2, _, _, r2 = DataSchema.normalize(partial)
		check(p2 ~= nil and type(p2.collection.discoveredResources) == "table" and #r2 == 1, "sous-section")
		local unknown = DataSchema.newProfile()
		unknown.collection.discoveredResources.ancienne = true
		local p3 = DataSchema.normalize(unknown)
		check(p3 ~= nil and p3.collection.discoveredResources.ancienne == true, "identifiant inconnu supprimé")
		check(Rules.summarize(p3.collection.discoveredResources).discovered == 0, "identifiant inconnu compté")
	end)

	case("version future (v4) refusée", function(check)
		local raw = DataSchema.newProfile()
		raw.schemaVersion = 4
		local profile, code = DataSchema.normalize(raw)
		check(profile == nil and code == DataSchema.ErrorCode.UnsupportedVersion, `code {tostring(code)}`)
	end)

	-- MIGRATION v2 -> v3 (PlayerDataService, magasin en mémoire) ------------

	case("chargement v2 : migré en mémoire, original intact jusqu'à la sauvegarde", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = richV2Profile() })
		local server = newServer(world, "A")
		check(server.service.LoadPlayer(USER_A).ok, "chargement refusé")
		local loaded = server.service.GetData(USER_A)
		check(loaded.schemaVersion == 3 and next(loaded.collection.discoveredResources) == nil, "non migré")
		check(deepEqual(world.store.peek(KEY_A).profile, richV2Profile()), "original réécrit au chargement")
		check(#recoveryKeys(world) == 0, "copie écrite dès le chargement")
	end)

	case("sauvegarde après migration : copie Recovery_, puis v3 écrit", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = richV2Profile() })
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		local loadTime = world.now
		world.now += 30
		check(server.service.SavePlayer(USER_A).ok, "sauvegarde refusée")
		local keys = recoveryKeys(world)
		check(#keys == 1 and keys[1] == `Recovery_{USER_A}_{loadTime}`, `copie : {table.concat(keys, ", ")}`)
		local record = world.store.peek(keys[1] or "")
		check(record ~= nil and deepEqual(record.originalProfile, richV2Profile()), "copie ≠ original v2")
		local stored = world.store.peek(KEY_A).profile
		check(stored.schemaVersion == 3 and DataSchema.validate(stored), "profil sauvegardé non v3")
		check(stored.currencies.coins == 123_456 and stored.upgrades.backpackLevel == 10, "économie perdue")
		check(stored.inventory.resources.mystic_core == 1, "inventaire perdu")
		check(stored.worlds.MysticWorld == true and stored.stats.totalSales == 120, "mondes ou stats perdus")
		check(stored.achievements.world_2 == true and stored.settings.musicEnabled == false, "succès ou réglages perdus")
	end)

	case("conflit Recovery_ : copie existante jamais écrasée, original v2 intact", function(check)
		local world = newWorld()
		local existingKey = `Recovery_{USER_A}_{world.now}`
		world.store.seed(KEY_A, { profile = richV2Profile() })
		world.store.seed(existingKey, { kind = "PreNormalizationBackup", originalProfile = { autre = true } })
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		local result = server.service.SavePlayer(USER_A)
		check(result.code == Code.BackupFailed, `code {tostring(result.code)}`)
		check(world.store.peek(existingKey).originalProfile.autre == true, "copie valide écrasée")
		check(deepEqual(world.store.peek(KEY_A).profile, richV2Profile()), "original v2 écrasé")
		local released = server.service.ReleasePlayer(USER_A)
		check(released.code == Code.BackupFailed, "sortie : copie ignorée")
		check(deepEqual(world.store.peek(KEY_A).profile, richV2Profile()), "original v2 écrasé à la sortie")
		check(world.store.peek(KEY_A).session == nil, "verrou non libéré")
	end)

	case("copie Recovery_ impossible : sauvegarde bloquée, original v2 intact", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = richV2Profile() })
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		world.store.setFailingKeys(function(key: string): boolean
			return string.sub(key, 1, #DataConfig.Store.recoveryKeyPrefix) == DataConfig.Store.recoveryKeyPrefix
		end)
		check(server.service.SavePlayer(USER_A).code == Code.BackupFailed, "sauvegarde sans copie")
		check(deepEqual(world.store.peek(KEY_A).profile, richV2Profile()), "original écrasé")
		world.store.setFailingKeys(nil)
		check(server.service.SavePlayer(USER_A).ok, "reprise impossible")
		check(world.store.peek(KEY_A).profile.schemaVersion == 3, "v3 non écrit après reprise")
	end)

	case("profil v2 corrompu : chargement refusé, rien écrit", function(check)
		local world = newWorld()
		local corrupt = v2Profile()
		corrupt.collection = 42
		world.store.seed(KEY_A, { profile = corrupt })
		local server = newServer(world, "A")
		local result = server.service.LoadPlayer(USER_A)
		check(not result.ok and result.code == Code.CorruptData, `code {tostring(result.code)}`)
		check(deepEqual(world.store.peek(KEY_A).profile, corrupt), "profil corrompu modifié")
		check(world.store.peek(KEY_A).session == nil, "verrou posé sur un profil refusé")
		check(#recoveryKeys(world) == 0, "copie écrite")
	end)

	case("verrou de session actif : profil v2 non migré, non écrit", function(check)
		local world = newWorld()
		local value = { profile = richV2Profile(), session = { id = "autre:1", expiresAt = world.now + 10_000 } }
		world.store.seed(KEY_A, value)
		local server = newServer(world, "A")
		local result = server.service.LoadPlayer(USER_A)
		check(result.code == Code.SessionLocked, `code {tostring(result.code)}`)
		local stored = world.store.peek(KEY_A)
		check(deepEqual(stored.profile, richV2Profile()), "profil verrouillé modifié")
		check(stored.session.id == "autre:1", "verrou d'une autre session remplacé")
	end)

	case("reconnexion après migration : découvertes et données conservées", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = richV2Profile() })
		local serverA = newServer(world, "A")
		serverA.service.LoadPlayer(USER_A)
		local inventory = InventoryService.new({ playerData = serverA.service })
		check(inventory.AddResource(USER_A, "ice_shard", 1).firstDiscovery == true, "découverte après migration")
		check(serverA.service.ReleasePlayer(USER_A).ok, "sortie refusée")

		local serverB = newServer(world, "B")
		check(serverB.service.LoadPlayer(USER_A).ok, "reconnexion refusée")
		local profile = serverB.service.GetData(USER_A)
		check(profile.schemaVersion == 3, "version après reconnexion")
		check(profile.collection.discoveredResources.ice_shard == true, "découverte perdue à la reconnexion")
		check(profile.inventory.resources.ice_shard == 3, "inventaire incorrect")
		check(profile.currencies.coins == 123_456, "Coins modifiés")
		check(#recoveryKeys(world) == 1, "seconde copie à la reconnexion")
		local again = InventoryService.new({ playerData = serverB.service })
		check(again.AddResource(USER_A, "ice_shard", 1).firstDiscovery == false, "redécouverte après reconnexion")
	end)

	-- OUTILS ET AFFICHAGE --------------------------------------------------

	case("préréglages J_* : journal de test valide, inchangé sinon", function(check)
		local env = newEnv({ USER_A })
		local Presets = modules.StudioTestPresets
		check(Presets.apply(env.playerData, USER_A, "J_partial"), "J_partial refusé")
		local summary = Rules.summarize(env.discovered(USER_A))
		check(summary.discovered == 4 and summary.worlds[1].discovered == 3, "J_partial : progression")
		check(Presets.apply(env.playerData, USER_A, "J_full"), "J_full refusé")
		check(Rules.summarize(env.discovered(USER_A)).percent == 100, "J_full ≠ 100 %")
		check(Presets.apply(env.playerData, USER_A, "U1"), "U1 refusé")
		check(Rules.summarize(env.discovered(USER_A)).discovered == 20, "un préréglage sans journal l'a modifié")
		check(Presets.apply(env.playerData, USER_A, "reset"), "reset refusé")
		check(next(env.discovered(USER_A)) == nil, "reset ne vide pas le journal")
		for name, preset in pairs(Presets.Presets) do
			for _, resourceId in ipairs(preset.discovered or {}) do
				check(ResourceConfig[resourceId] ~= nil, `{name} : {resourceId} inconnu`)
			end
		end
	end)

	case("localisation : textes du journal et raretés en anglais et français", function(check)
		local Localization = modules.Localization
		local keys = {
			"journal.title",
			"journal.open",
			"journal.total",
			"journal.world_progress",
			"journal.unknown",
			"journal.locked",
			"journal.back",
			"journal.value",
			"journal.new_discovery",
		}
		for _, rarity in ipairs(Rules.RARITY_ORDER) do
			table.insert(keys, `rarity.{string.lower(rarity)}`)
		end
		for _, key in ipairs(keys) do
			for _, language in ipairs({ "en", "fr" }) do
				local text = Localization.get(key, language)
				check(type(text) == "string" and text ~= key and text ~= "", `{key} ({language}) absent`)
			end
		end
		local fr = Localization.fill("journal.total", "fr", { discovered = "3", total = "20", percent = "15" })
		check(string.find(fr, "3", 1, true) ~= nil and string.find(fr, "20", 1, true) ~= nil, `format fr : {fr}`)
	end)

	case("feedback : découverte sans nouvel effet sonore", function(check)
		local Remotes = modules.Remotes
		local normal = modules.FeedbackRules.fromResult({
			action = Remotes.Action.Collect,
			ok = true,
			code = Remotes.ResultCode.Success,
			amount = 1,
			firstDiscovery = false,
		})
		local first = modules.FeedbackRules.fromResult({
			action = Remotes.Action.Collect,
			ok = true,
			code = Remotes.ResultCode.Success,
			amount = 1,
			firstDiscovery = true,
		})
		check(deepEqual(normal, first), "firstDiscovery change les sons de collecte")
	end)

	return failures, caseCount
end

return CollectionJournalTests
