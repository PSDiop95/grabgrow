--!strict
-- Tests de la vente (T3) avec de vrais services (PlayerDataService,
-- InventoryService, CollectionService, RateLimitService, SellService), un
-- magasin en mémoire, une horloge simulée et des positions fixées par le
-- test. Aucune API Roblox.
--
-- Invariants vérifiés après chaque vente :
--   * Coins gagnés = somme(quantité vendue × sellValue) ;
--   * une même ressource n'est jamais vendue deux fois ;
--   * les ressources inconnues restent intactes ;
--   * totalCoinsSpent n'est jamais modifié par une vente ;
--   * un refus ne modifie rien.

local SellServiceTests = {}

export type Modules = {
	SellService: any,
	SaleValue: any,
	CollectionService: any,
	InventoryService: any,
	PlayerDataService: any,
	RateLimitService: any,
	ResourceSpawner: any,
	MemoryDataStore: any,
	DataSchema: any,
	GameConfig: any,
	ResourceConfig: any,
	UpgradeConfig: any,
	CollectionSecurityConfig: any,
	SellSecurityConfig: any,
	Remotes: any,
}

local USER_A = 4001
local USER_B = 4002
local KEY_A = "Player_4001"
local ZONE = "GreenValley_Main"
local LEAF = "green_leaf_001"
local UNKNOWN = "mystery_gem"

-- Retourne (liste des échecs, nombre de cas exécutés).
function SellServiceTests.run(modules: Modules): ({ string }, number)
	local SellService = modules.SellService
	local SaleValue = modules.SaleValue
	local CollectionService = modules.CollectionService
	local InventoryService = modules.InventoryService
	local PlayerDataService = modules.PlayerDataService
	local RateLimitService = modules.RateLimitService
	local ResourceSpawner = modules.ResourceSpawner
	local MemoryDataStore = modules.MemoryDataStore
	local DataSchema = modules.DataSchema
	local GameConfig = modules.GameConfig
	local ResourceConfig = modules.ResourceConfig
	local UpgradeConfig = modules.UpgradeConfig
	local CollectionSecurity = modules.CollectionSecurityConfig
	local Security = modules.SellSecurityConfig
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

	local MAX = DataSchema.MAX_SAFE_INTEGER
	local maxDistance = GameConfig.Selling.interactRangeStuds + Security.Distance.toleranceStuds
	local baseCapacity = UpgradeConfig.Backpack.levels[1].value
	local sellBurst = Security.RateLimits.Sell.burst
	local price = {
		green_leaf = ResourceConfig.green_leaf.sellValue,
		wood = ResourceConfig.wood.sellValue,
		stone = ResourceConfig.stone.sellValue,
	}

	-- Un serveur : zone ZONE en (0, 0, 0), nœud LEAF en (100, 0, 0).
	-- Options : `prepare` modifie le profil stocké du joueur A avant son
	-- chargement ; `store` réutilise un magasin ; `wrapPlayerData` remplace
	-- le service de profils vu par SellService ; `unlimited` retire la
	-- limite de fréquence de la vente.
	local function newEnv(
		userIds: { number },
		options: {
			prepare: ((profile: any) -> ())?,
			store: any?,
			wrapPlayerData: ((playerData: any) -> any)?,
			unlimited: boolean?,
		}?
	)
		local opts: any = options or {}
		local env = {
			now = 1000,
			store = opts.store or MemoryDataStore.new(),
			positions = {} :: { [number]: any },
			timers = {} :: { { at: number, callback: () -> () } },
			logs = {} :: { string },
		}
		local function log(level: string, message: string)
			table.insert(env.logs, `{level} {message}`)
		end
		local function clock(): number
			return env.now
		end

		if opts.prepare then
			local profile = DataSchema.newProfile()
			opts.prepare(profile)
			env.store.seed(KEY_A, { profile = profile })
		end

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
			log = function() end,
		})
		env.inventory = InventoryService.new({ playerData = env.playerData })
		env.spawner = ResourceSpawner.new({
			schedule = function(delaySeconds: number, callback: () -> ())
				table.insert(env.timers, { at = env.now + delaySeconds, callback = callback })
			end,
		})
		env.spawner.Register(LEAF, "green_leaf", { X = 100, Y = 0, Z = 0 })
		local function getPosition(userId: number): any
			return env.positions[userId]
		end
		env.collection = CollectionService.new({
			playerData = env.playerData,
			inventory = env.inventory,
			spawner = env.spawner,
			rateLimit = RateLimitService.new({
				clock = clock,
				limits = CollectionSecurity.RateLimits,
				logEveryRejections = CollectionSecurity.RateLimitFeedback.logEveryRejections,
				log = log,
			}),
			clock = clock,
			getCharacterPosition = getPosition,
			log = log,
		})
		env.rateLimit = RateLimitService.new({
			clock = clock,
			limits = Security.RateLimits,
			logEveryRejections = Security.RateLimitFeedback.logEveryRejections,
			log = log,
		})
		env.sell = SellService.new({
			playerData = if opts.wrapPlayerData then opts.wrapPlayerData(env.playerData) else env.playerData,
			rateLimit = if opts.unlimited
				then {
					Allow = function(): boolean
						return true
					end,
					Clear = function() end,
				}
				else env.rateLimit,
			getSellZone = function(zoneId: string): any
				if zoneId == ZONE then
					return { position = { X = 0, Y = 0, Z = 0 } }
				end
				return nil
			end,
			getCharacterPosition = getPosition,
			clock = clock,
			log = log,
		})

		for _, userId in ipairs(userIds) do
			assert(env.playerData.LoadPlayer(userId).ok, "chargement du joueur de test")
			env.positions[userId] = { X = 2, Y = 3, Z = 2 }
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

		function env.sellAt(userId: number): any
			return env.sell.HandleRequest(userId, { sellZoneId = ZONE })
		end

		function env.profile(userId: number): any
			return env.playerData.GetData(userId)
		end

		-- Place des ressources dans le sac d'un joueur chargé.
		function env.give(userId: number, resources: { [string]: number })
			local result = env.playerData.Update(userId, function(draft: any): boolean?
				for resourceId, quantity in pairs(resources) do
					draft.inventory.resources[resourceId] = quantity
				end
				return nil
			end)
			assert(result.ok, `préparation du sac : {tostring(result.code)} {tostring(result.message)}`)
		end

		return env
	end

	local function valueOf(items: { [string]: number }): number
		local total = 0
		for resourceId, quantity in pairs(items) do
			total += quantity * price[resourceId]
		end
		return total
	end

	-- Vérifie qu'un refus n'a rien modifié.
	local function checkUnchanged(check: any, before: any, after: any, label: string)
		check(after.currencies.coins == before.currencies.coins, `{label} : Coins modifiés`)
		check(after.stats.totalCoinsEarned == before.stats.totalCoinsEarned, `{label} : totalCoinsEarned modifié`)
		check(after.stats.totalSales == before.stats.totalSales, `{label} : totalSales modifié`)
		check(after.stats.totalCoinsSpent == before.stats.totalCoinsSpent, `{label} : totalCoinsSpent modifié`)
		for resourceId, quantity in pairs(before.inventory.resources) do
			check(after.inventory.resources[resourceId] == quantity, `{label} : {resourceId} modifié`)
		end
		for resourceId in pairs(after.inventory.resources) do
			check(before.inventory.resources[resourceId] ~= nil, `{label} : {resourceId} ajouté`)
		end
	end

	local function loggedOverflow(env: any): boolean
		for _, line in ipairs(env.logs) do
			if string.find(line, "dépassement numérique", 1, true) then
				return true
			end
		end
		return false
	end

	-- 1. VENTE D'UNE RESSOURCE ---------------------------------------------

	case("vente d'une ressource connue", function(check)
		local env = newEnv({ USER_A })
		env.give(USER_A, { green_leaf = 7 })
		local result = env.sellAt(USER_A)
		check(result.ok and result.code == Code.Success, `code {tostring(result.code)}`)
		check(result.coinsEarned == 7 * price.green_leaf, `coinsEarned = {result.coinsEarned}`)
		check(result.quantitySold == 7, `quantitySold = {result.quantitySold}`)
		check(result.sellZoneId == ZONE and not result.silent, "zone ou silence incorrect")
		local profile = env.profile(USER_A)
		check(profile.currencies.coins == 7 * price.green_leaf, "Coins non crédités")
		check(profile.inventory.resources.green_leaf == nil, "feuilles non retirées")
		check(env.inventory.GetState(USER_A).used == 0, "sac non libéré")
		check(env.store.getWriteCount() == 1, "une vente a déclenché une écriture DataStore")
	end)

	-- 2 et 6. PLUSIEURS RESSOURCES, CALCUL EXACT ----------------------------

	case("vente de plusieurs ressources, calcul exact", function(check)
		local env = newEnv({ USER_A })
		local items = { green_leaf = 12, wood = 5, stone = 3 }
		env.give(USER_A, items)
		local expected = 12 * 1 + 5 * 2 + 3 * 3
		check(valueOf(items) == expected, "prix de ResourceConfig différents de la Bible (1 / 2 / 3)")
		local result = env.sellAt(USER_A)
		check(result.ok, `code {tostring(result.code)}`)
		check(result.coinsEarned == expected, `coinsEarned = {result.coinsEarned}, attendu {expected}`)
		check(result.quantitySold == 20, `quantitySold = {result.quantitySold}`)
		check(result.items.green_leaf == 12 and result.items.wood == 5 and result.items.stone == 3, "détail vendu incorrect")
		local profile = env.profile(USER_A)
		check(profile.currencies.coins == expected, `solde {profile.currencies.coins}`)
		check(next(profile.inventory.resources) == nil, "sac non vidé")
	end)

	case("le solde existant est conservé et augmenté", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.currencies.coins = 250
				profile.stats.totalCoinsEarned = 400
				profile.stats.totalCoinsSpent = 150
				profile.stats.totalSales = 9
			end,
		})
		env.give(USER_A, { wood = 4 })
		check(env.sellAt(USER_A).ok, "vente refusée")
		local profile = env.profile(USER_A)
		check(profile.currencies.coins == 258, `solde {profile.currencies.coins}`)
		check(profile.stats.totalCoinsEarned == 408, "totalCoinsEarned incorrect")
		check(profile.stats.totalCoinsSpent == 150, "totalCoinsSpent modifié")
		check(profile.stats.totalSales == 10, "totalSales incorrect")
	end)

	-- 3, 4, 5. SAC VIDE, INCONNUES, MIXTE ----------------------------------

	case("sac vide", function(check)
		local env = newEnv({ USER_A })
		local before = env.profile(USER_A)
		local result = env.sellAt(USER_A)
		check(not result.ok and result.code == Code.NothingToSell, `code {tostring(result.code)}`)
		check(result.coinsEarned == 0 and result.quantitySold == 0, "montant non nul")
		checkUnchanged(check, before, env.profile(USER_A), "sac vide")
	end)

	case("sac avec quantités à zéro uniquement", function(check)
		local env = newEnv({ USER_A })
		env.give(USER_A, { green_leaf = 0, stone = 0 })
		local before = env.profile(USER_A)
		check(env.sellAt(USER_A).code == Code.NothingToSell, "vente acceptée")
		checkUnchanged(check, before, env.profile(USER_A), "zéros")
	end)

	case("sac contenant uniquement des ressources inconnues", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.inventory.resources[UNKNOWN] = 6
			end,
		})
		local before = env.profile(USER_A)
		check(before.inventory.resources[UNKNOWN] == 6, "ressource inconnue non chargée (D-008)")
		local result = env.sellAt(USER_A)
		check(not result.ok and result.code == Code.NothingToSell, `code {tostring(result.code)}`)
		checkUnchanged(check, before, env.profile(USER_A), "inconnues seules")
		check(env.inventory.GetState(USER_A).used == 6, "occupation modifiée (D-012)")
	end)

	case("sac mixte : connues vendues, inconnues conservées", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.inventory.resources[UNKNOWN] = 4
				profile.inventory.resources.wood = 3
				profile.inventory.resources.green_leaf = 2
			end,
		})
		local result = env.sellAt(USER_A)
		check(result.ok, `code {tostring(result.code)}`)
		check(result.coinsEarned == 3 * 2 + 2 * 1, `coinsEarned = {result.coinsEarned}`)
		check(result.quantitySold == 5, "quantité vendue incorrecte")
		check(result.items[UNKNOWN] == nil, "ressource inconnue vendue")
		local profile = env.profile(USER_A)
		check(profile.inventory.resources[UNKNOWN] == 4, "ressource inconnue modifiée ou supprimée")
		check(profile.inventory.resources.wood == nil and profile.inventory.resources.green_leaf == nil, "connues non retirées")
		check(env.inventory.GetState(USER_A).used == 4, "occupation après vente incorrecte")
		-- Seconde vente : il ne reste que l'inconnue.
		env.advance(5)
		check(env.sellAt(USER_A).code == Code.NothingToSell, "inconnue vendue à la seconde vente")
	end)

	-- 7 et 8. STATISTIQUES -------------------------------------------------

	case("statistiques : totalCoinsEarned, totalSales, totalCoinsSpent", function(check)
		local env = newEnv({ USER_A })
		env.give(USER_A, { stone = 2 })
		check(env.sellAt(USER_A).ok, "première vente refusée")
		env.advance(2)
		env.give(USER_A, { green_leaf = 5 })
		check(env.sellAt(USER_A).ok, "seconde vente refusée")
		local stats = env.profile(USER_A).stats
		check(stats.totalCoinsEarned == 6 + 5, `totalCoinsEarned = {stats.totalCoinsEarned}`)
		check(stats.totalSales == 2, `totalSales = {stats.totalSales}`)
		check(stats.totalCoinsSpent == 0, "totalCoinsSpent modifié")
		check(stats.totalResourcesCollected == 0, "totalResourcesCollected modifié par la vente")
		check(env.profile(USER_A).currencies.coins == stats.totalCoinsEarned - stats.totalCoinsSpent, "solde incohérent")
	end)

	-- 9. REQUÊTES INVALIDES OU FALSIFIÉES ----------------------------------

	case("requête invalide ou falsifiée", function(check)
		local env = newEnv({ USER_A }, { unlimited = true })
		env.give(USER_A, { stone = 4 })
		local before = env.profile(USER_A)
		local payloads: { any } = {
			nil,
			ZONE,
			42,
			true,
			{},
			{ sellZoneId = 42 },
			{ sellZoneId = "" },
			{ sellZoneId = string.rep("a", Security.Payload.maxSellZoneIdLength + 1) },
			{ ZONE },
			{ sellZoneId = ZONE, amount = 999 },
			{ sellZoneId = ZONE, coins = 1_000_000 },
			{ sellZoneId = ZONE, items = { stone = 999 } },
			{ sellZoneId = ZONE, value = math.huge },
			{ sellZoneId = ZONE, multiplier = 50 },
		}
		for index = 1, 14 do
			local result = env.sell.HandleRequest(USER_A, payloads[index])
			check(not result.ok and result.code == Code.InvalidTarget, `payload {index} : code {tostring(result.code)}`)
		end
		local unknownZone = env.sell.HandleRequest(USER_A, { sellZoneId = "GoldenDesert_Main" })
		check(unknownZone.code == Code.InvalidTarget, "zone inconnue acceptée")
		checkUnchanged(check, before, env.profile(USER_A), "falsification")
	end)

	-- 10. DISTANCE ET PERSONNAGE --------------------------------------------

	case("joueur trop éloigné, puis à portée", function(check)
		local env = newEnv({ USER_A }, { unlimited = true })
		env.give(USER_A, { wood = 2 })
		local before = env.profile(USER_A)
		env.positions[USER_A] = { X = maxDistance + 0.5, Y = 0, Z = 0 }
		check(env.sellAt(USER_A).code == Code.TooFar, "vente acceptée à distance")
		env.positions[USER_A] = { X = 0, Y = maxDistance + 0.5, Z = 0 }
		check(env.sellAt(USER_A).code == Code.TooFar, "vente acceptée depuis trop haut")
		checkUnchanged(check, before, env.profile(USER_A), "distance")
		env.positions[USER_A] = { X = maxDistance - 0.5, Y = 0, Z = 0 }
		check(env.sellAt(USER_A).ok, "vente refusée à portée")
	end)

	case("personnage absent ou mort", function(check)
		local env = newEnv({ USER_A })
		env.give(USER_A, { wood = 2 })
		local before = env.profile(USER_A)
		env.positions[USER_A] = nil
		check(env.sellAt(USER_A).code == Code.NoCharacter, "vente sans personnage")
		checkUnchanged(check, before, env.profile(USER_A), "sans personnage")
	end)

	-- 11. PROFIL NON CHARGÉ --------------------------------------------------

	case("profil non chargé, en chargement ou libéré", function(check)
		local env = newEnv({ USER_A })
		env.positions[USER_B] = { X = 0, Y = 0, Z = 0 }
		check(env.sellAt(USER_B).code == Code.ProfileNotLoaded, "joueur inconnu : vente acceptée")

		-- Chargement suspendu pendant l'appel DataStore.
		local suspended = false
		env.store.setBeforeCall(function(key: string)
			if key == "Player_4002" and not suspended then
				suspended = true
				coroutine.yield()
			end
		end)
		local loader = coroutine.create(function()
			return env.playerData.LoadPlayer(USER_B)
		end)
		coroutine.resume(loader)
		check(suspended and coroutine.status(loader) == "suspended", "chargement non suspendu (préparation du test)")
		check(env.sellAt(USER_B).code == Code.ProfileNotLoaded, "vente acceptée pendant le chargement")
		env.store.setBeforeCall(nil)
		coroutine.resume(loader)
		check(env.playerData.IsLoaded(USER_B), "chargement non terminé")

		-- Après la libération.
		env.give(USER_A, { stone = 1 })
		check(env.playerData.ReleasePlayer(USER_A).ok, "libération en échec")
		check(env.sellAt(USER_A).code == Code.ProfileNotLoaded, "vente acceptée après libération")
	end)

	-- 12. LIMITE DE FRÉQUENCE -----------------------------------------------

	case("requêtes répétées et limitation de fréquence", function(check)
		local env = newEnv({ USER_A, USER_B })
		env.give(USER_A, { stone = 10 })
		env.give(USER_B, { green_leaf = 3 })
		local successes, nothing, limited, silent = 0, 0, 0, 0
		for _ = 1, 200 do
			local result = env.sellAt(USER_A)
			if result.ok then
				successes += 1
			elseif result.code == Code.NothingToSell then
				nothing += 1
			elseif result.code == Code.RateLimited then
				limited += 1
				if result.silent then
					silent += 1
				end
			end
		end
		check(successes == 1, `{successes} vente(s) réussie(s) au lieu d'une`)
		check(nothing == sellBurst - 1, `{nothing} réponse(s) NOTHING_TO_SELL`)
		check(limited == 200 - sellBurst and silent == limited - 1, "une seule réponse RATE_LIMITED non silencieuse attendue")
		check(env.profile(USER_A).currencies.coins == 30, "Coins crédités plusieurs fois")
		check(env.sellAt(USER_B).ok, "un joueur limité gêne un autre joueur")
		-- Après recharge du seau, la vente redevient possible.
		env.advance(sellBurst / Security.RateLimits.Sell.refillPerSecond + 0.1)
		env.give(USER_A, { wood = 1 })
		check(env.sellAt(USER_A).ok, "vente refusée après recharge")
		env.sell.RemovePlayer(USER_A)
		check(env.rateLimit.GetRejectedCount(USER_A, SellService.RATE_LIMIT_ACTION) == 0, "limite non nettoyée au départ")
	end)

	-- 13. VENTES CONCURRENTES ------------------------------------------------

	case("deux ventes concurrentes sur le même inventaire", function(check)
		local env = newEnv({ USER_A })
		env.give(USER_A, { green_leaf = 10, wood = 10, stone = 10 })
		-- Deux demandes arrivées dans la même image : traitées l'une après
		-- l'autre, la seconde voit le sac déjà vidé.
		local first = env.sellAt(USER_A)
		local second = env.sellAt(USER_A)
		check(first.ok and first.coinsEarned == 60, "première vente incorrecte")
		check(not second.ok and second.code == Code.NothingToSell, `seconde vente : {tostring(second.code)}`)
		local profile = env.profile(USER_A)
		check(profile.currencies.coins == 60 and profile.stats.totalSales == 1, "ressources vendues deux fois")
	end)

	case("vente pendant une sauvegarde en cours : rien de vendu deux fois", function(check)
		local env = newEnv({ USER_A })
		env.give(USER_A, { stone = 5 })
		local suspended = false
		env.store.setBeforeCall(function()
			if not suspended then
				suspended = true
				coroutine.yield()
			end
		end)
		local saver = coroutine.create(function()
			return env.playerData.SavePlayer(USER_A, "test")
		end)
		coroutine.resume(saver)
		check(coroutine.status(saver) == "suspended", "sauvegarde non suspendue (préparation du test)")
		check(env.sellAt(USER_A).ok, "vente refusée pendant une sauvegarde")
		check(env.sellAt(USER_A).code == Code.NothingToSell, "seconde vente acceptée")
		env.store.setBeforeCall(nil)
		coroutine.resume(saver)
		check(env.profile(USER_A).currencies.coins == 15, "solde incorrect après la sauvegarde")
	end)

	-- 14. ÉCHEC DE MUTATION --------------------------------------------------

	case("échec de mutation : ni perte ni duplication", function(check)
		-- Le brouillon devient invalide après la vente (refus du schéma).
		local env = newEnv({ USER_A }, {
			wrapPlayerData = function(playerData: any): any
				return {
					GetData = playerData.GetData,
					Update = function(userId: number, mutator: any): any
						return playerData.Update(userId, function(draft: any): boolean?
							local returned = mutator(draft)
							draft.currencies.coins = 0.5
							return returned
						end)
					end,
				}
			end,
		})
		env.give(USER_A, { stone = 3, wood = 2 })
		local before = env.profile(USER_A)
		local result = env.sellAt(USER_A)
		check(not result.ok and result.code == Code.InternalError, `code {tostring(result.code)}`)
		check(result.coinsEarned == 0 and result.quantitySold == 0, "montant annoncé malgré l'échec")
		checkUnchanged(check, before, env.profile(USER_A), "mutation refusée")
	end)

	case("erreur dans la mutation : ni perte ni duplication", function(check)
		local env = newEnv({ USER_A }, {
			wrapPlayerData = function(playerData: any): any
				return {
					GetData = playerData.GetData,
					Update = function(userId: number, mutator: any): any
						return playerData.Update(userId, function(draft: any): boolean?
							mutator(draft)
							error("panne simulée après le crédit")
						end)
					end,
				}
			end,
		})
		env.give(USER_A, { green_leaf = 9 })
		local before = env.profile(USER_A)
		check(env.sellAt(USER_A).code == Code.InternalError, "erreur non signalée")
		checkUnchanged(check, before, env.profile(USER_A), "erreur de mutation")
	end)

	-- 15. DÉPASSEMENTS ET DONNÉES ANORMALES ---------------------------------

	case("dépassement : solde proche du maximum", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.currencies.coins = MAX - 2
				profile.inventory.resources.stone = 1
			end,
		})
		local before = env.profile(USER_A)
		check(env.sellAt(USER_A).code == Code.InternalError, "dépassement du solde accepté")
		checkUnchanged(check, before, env.profile(USER_A), "solde maximal")
		check(loggedOverflow(env), "dépassement non détecté explicitement (seul le schéma l'a bloqué)")
	end)

	case("dépassement : statistiques proches du maximum", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.stats.totalSales = MAX
				profile.inventory.resources.wood = 1
			end,
		})
		local before = env.profile(USER_A)
		check(env.sellAt(USER_A).code == Code.InternalError, "dépassement de totalSales accepté")
		checkUnchanged(check, before, env.profile(USER_A), "totalSales maximal")
		check(loggedOverflow(env), "dépassement non détecté explicitement (seul le schéma l'a bloqué)")
	end)

	case("dépassement : quantité énorme", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.inventory.resources.stone = MAX
			end,
		})
		local before = env.profile(USER_A)
		check(env.sellAt(USER_A).code == Code.InternalError, "quantité × prix hors bornes acceptée")
		checkUnchanged(check, before, env.profile(USER_A), "quantité énorme")
		check(loggedOverflow(env), "dépassement non détecté explicitement (seul le schéma l'a bloqué)")
	end)

	case("SaleValue : formule partagée, bornes et données anormales", function(check)
		check(SaleValue.MAX_SAFE_INTEGER == DataSchema.MAX_SAFE_INTEGER, "bornes différentes de DataSchema")
		check(SaleValue.unitPrice("green_leaf") == 1 and SaleValue.unitPrice("wood") == 2 and SaleValue.unitPrice("stone") == 3, "prix")
		check(SaleValue.unitPrice(UNKNOWN) == nil, "prix attribué à une ressource inconnue")
		local quote = SaleValue.quote({
			green_leaf = 2,
			stone = 1,
			wood = -4,
			[UNKNOWN] = 3,
			broken = 0 / 0,
			fraction = 1.5,
		} :: any)
		check(quote.total == 5 and quote.quantity == 3, `devis {quote.total} / {quote.quantity}`)
		check(quote.unsellableQuantity == 3, "inconnues mal comptées")
		check(quote.items.wood == nil, "quantité négative vendue")
		check(not quote.overflow, "dépassement signalé à tort")
		check(SaleValue.quote(nil :: any).total == 0, "inventaire absent")
		check(SaleValue.quote({ stone = MAX }).overflow, "dépassement non détecté")
	end)

	-- 16. SYNCHRONISATION DU HUD ---------------------------------------------

	case("état client après vente : Coins, sac et estimation", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.inventory.resources[UNKNOWN] = 2
			end,
		})
		env.give(USER_A, { green_leaf = 4, stone = 2 })
		local beforeState = env.collection.GetClientState(USER_A)
		check(beforeState.coins == 0, "solde initial incorrect")
		local estimate = SaleValue.quote(beforeState.inventory.resources).total
		local result = env.sellAt(USER_A)
		check(result.ok and result.coinsEarned == estimate, `estimation client {estimate}, crédit serveur {result.coinsEarned}`)
		local state = env.collection.GetClientState(USER_A)
		check(state.coins == result.coinsEarned, "solde du HUD non synchronisé")
		check(state.inventory.used == 2 and state.inventory.free == baseCapacity - 2, "sac du HUD non synchronisé")
		check(SaleValue.quote(state.inventory.resources).total == 0, "estimation non nulle après vente")
		check(env.sell.GetQuote(USER_A).unsellableQuantity == 2, "devis serveur incorrect")
	end)

	-- 17. VENTE PUIS NOUVELLE COLLECTE ---------------------------------------

	case("sac plein, vente, puis nouvelle collecte", function(check)
		local env = newEnv({ USER_A })
		env.give(USER_A, { green_leaf = baseCapacity })
		env.positions[USER_A] = { X = 101, Y = 0, Z = 0 }
		check(env.collection.HandleRequest(USER_A, { resourceId = LEAF }).code == Code.InventoryFull, "sac plein non détecté")
		env.positions[USER_A] = { X = 1, Y = 0, Z = 0 }
		env.collection.ResetTravelReference(USER_A)
		local sale = env.sellAt(USER_A)
		check(sale.ok and sale.coinsEarned == baseCapacity * price.green_leaf, "vente du sac plein incorrecte")
		env.advance(10)
		env.positions[USER_A] = { X = 101, Y = 0, Z = 0 }
		env.collection.ResetTravelReference(USER_A)
		local collect = env.collection.HandleRequest(USER_A, { resourceId = LEAF })
		check(collect.ok, `collecte après vente : {tostring(collect.code)}`)
		local profile = env.profile(USER_A)
		check(profile.inventory.resources.green_leaf == 1, "sac après collecte incorrect")
		check(profile.currencies.coins == baseCapacity * price.green_leaf, "Coins modifiés par la collecte")
	end)

	-- MULTIJOUEUR ------------------------------------------------------------

	case("deux joueurs : ventes et soldes indépendants", function(check)
		local env = newEnv({ USER_A, USER_B })
		env.give(USER_A, { stone = 4 })
		env.give(USER_B, { wood = 1 })
		check(env.sellAt(USER_A).ok and env.sellAt(USER_B).ok, "vente refusée")
		check(env.profile(USER_A).currencies.coins == 12, "solde de A incorrect")
		check(env.profile(USER_B).currencies.coins == 2, "solde de B incorrect")
		check(env.sellAt(USER_B).code == Code.NothingToSell, "B vend deux fois")
		check(env.profile(USER_A).currencies.coins == 12, "la vente de B a modifié A")
	end)

	-- 18. PERSISTANCE --------------------------------------------------------

	case("Coins et sac restaurés après sauvegarde et rechargement", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.inventory.resources[UNKNOWN] = 1
			end,
		})
		env.give(USER_A, { wood = 6, stone = 1 })
		check(env.sellAt(USER_A).ok, "vente refusée")
		env.give(USER_A, { green_leaf = 2 })
		env.sell.RemovePlayer(USER_A)
		check(env.playerData.ReleasePlayer(USER_A).ok, "sauvegarde de sortie en échec")

		local stored = env.store.peek(KEY_A).profile
		check(stored.currencies.coins == 15, `solde stocké {stored.currencies.coins}`)

		local other = newEnv({ USER_A }, { store = env.store })
		local profile = other.profile(USER_A)
		check(profile.currencies.coins == 15, "solde non restauré")
		check(profile.stats.totalCoinsEarned == 15 and profile.stats.totalSales == 1, "statistiques non restaurées")
		check(profile.inventory.resources.green_leaf == 2, "sac non restauré")
		check(profile.inventory.resources.wood == nil and profile.inventory.resources.stone == nil, "ressources vendues revenues")
		check(profile.inventory.resources[UNKNOWN] == 1, "ressource inconnue perdue")
	end)

	return failures, caseCount
end

return SellServiceTests
