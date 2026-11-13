--!strict
-- Tests de sécurité T6 : RemoteEvents (payloads, arguments, identifiants,
-- spam, profil absent), contrôle des déplacements dans la collecte et la
-- vente, réapparition, NaN, intégrité économique (double vente, double
-- achat, concurrence, aucune création de monnaie), multijoueur simulé,
-- déconnexion et reconnexion, journal de sécurité, audit de profil.
--
-- Vrais services, magasin en mémoire, horloge et positions simulées. Aucune
-- API Roblox, aucun DataStore réel.

local SecurityTests = {}

export type Modules = {
	CollectionService: any,
	InventoryService: any,
	SellService: any,
	UpgradeService: any,
	WorldUnlockService: any,
	PlayerDataService: any,
	RateLimitService: any,
	ResourceSpawner: any,
	MemoryDataStore: any,
	DataSchema: any,
	SaleValue: any,
	UpgradeMath: any,
	MovementValidator: any,
	PayloadValidator: any,
	SecurityLog: any,
	ProfileAudit: any,
	CollectionSecurityConfig: any,
	SellSecurityConfig: any,
	EconomySecurityConfig: any,
	MovementSecurityConfig: any,
	SecurityLogConfig: any,
	Remotes: any,
}

local USER_A = 8001
local USER_B = 8002
local USER_GHOST = 8099
local ZONE = "GreenValley_Main"
local LEAF = "green_leaf_001"
local LEAF_2 = "green_leaf_002"
local STONE_FAR = "stone_001"

local function keyOf(userId: number): string
	return `Player_{userId}`
end

function SecurityTests.run(modules: Modules): ({ string }, number)
	local CollectionService = modules.CollectionService
	local InventoryService = modules.InventoryService
	local SellService = modules.SellService
	local UpgradeService = modules.UpgradeService
	local WorldUnlockService = modules.WorldUnlockService
	local PlayerDataService = modules.PlayerDataService
	local RateLimitService = modules.RateLimitService
	local ResourceSpawner = modules.ResourceSpawner
	local MemoryDataStore = modules.MemoryDataStore
	local DataSchema = modules.DataSchema
	local SaleValue = modules.SaleValue
	local UpgradeMath = modules.UpgradeMath
	local MovementValidator = modules.MovementValidator
	local PayloadValidator = modules.PayloadValidator
	local SecurityLog = modules.SecurityLog
	local ProfileAudit = modules.ProfileAudit
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

	-- Serveur complet simulé. `prepare[userId]` modifie le profil stocké
	-- avant son chargement. `movement` : validateur ou bouchon facultatif.
	local function newEnv(options: { prepare: { [number]: (profile: any) -> () }?, movement: any?, store: any? }?)
		local env = {
			now = 1000,
			store = (if options then options.store else nil) or MemoryDataStore.new(),
			positions = {} :: { [number]: any },
			lines = {} :: { string },
		}
		local function clock(): number
			return env.now
		end
		local function quiet() end

		local prepare = if options then options.prepare else nil
		if prepare then
			for userId, mutate in pairs(prepare) do
				local profile = DataSchema.newProfile()
				mutate(profile)
				env.store.seed(keyOf(userId), { profile = profile })
			end
		end

		env.security = SecurityLog.new({
			clock = clock,
			config = modules.SecurityLogConfig,
			sink = function(line: string)
				table.insert(env.lines, line)
			end,
			fallback = quiet,
		})
		env.playerData = PlayerDataService.new({
			store = env.store,
			serverId = "S6",
			clock = function(): number
				return 2_000_000
			end,
			wait = function() end,
			spawn = function(callback: () -> ())
				callback()
			end,
			log = quiet,
		})
		local function getPosition(userId: number): any
			return env.positions[userId]
		end
		env.spawner = ResourceSpawner.new({
			schedule = function() end,
		})
		env.spawner.Register(LEAF, "green_leaf", { X = 0, Y = 0, Z = 0 })
		env.spawner.Register(LEAF_2, "green_leaf", { X = 4, Y = 0, Z = 0 })
		env.spawner.Register(STONE_FAR, "stone", { X = 300, Y = 0, Z = 0 })
		local movement = if options then options.movement else nil

		env.collection = CollectionService.new({
			playerData = env.playerData,
			inventory = InventoryService.new({ playerData = env.playerData }),
			spawner = env.spawner,
			rateLimit = RateLimitService.new({
				clock = clock,
				limits = modules.CollectionSecurityConfig.RateLimits,
				logEveryRejections = 1_000_000,
				log = quiet,
			}),
			clock = clock,
			getCharacterPosition = getPosition,
			movement = movement,
			security = env.security,
			log = quiet,
		})
		env.sell = SellService.new({
			playerData = env.playerData,
			rateLimit = RateLimitService.new({
				clock = clock,
				limits = modules.SellSecurityConfig.RateLimits,
				logEveryRejections = 1_000_000,
				log = quiet,
			}),
			getSellZone = function(zoneId: string): any
				return if zoneId == ZONE then { position = { X = 0, Y = 0, Z = 0 } } else nil
			end,
			getCharacterPosition = getPosition,
			clock = clock,
			movement = movement,
			security = env.security,
			log = quiet,
		})
		local economyLimit = RateLimitService.new({
			clock = clock,
			limits = modules.EconomySecurityConfig.RateLimits,
			logEveryRejections = 1_000_000,
			log = quiet,
		})
		env.upgrade = UpgradeService.new({
			playerData = env.playerData,
			rateLimit = economyLimit,
			clock = clock,
			security = env.security,
			log = quiet,
		})
		env.world = WorldUnlockService.new({
			playerData = env.playerData,
			rateLimit = economyLimit,
			clock = clock,
			security = env.security,
			log = quiet,
		})

		function env.load(userId: number)
			assert(env.playerData.LoadPlayer(userId).ok, "chargement du joueur de test")
			env.positions[userId] = { X = 1, Y = 0, Z = 1 }
		end

		function env.data(userId: number): any
			return env.playerData.GetData(userId)
		end

		-- Instantané des champs économiques (comparaison avant / après).
		function env.snapshot(userId: number): any
			local data = env.data(userId)
			return {
				coins = data.currencies.coins,
				inventory = data.inventory.resources,
				upgrades = data.upgrades,
				worlds = data.worlds,
				stats = data.stats,
			}
		end

		-- Solde = gagné - dépensé : aucune création ni perte de monnaie.
		function env.balanced(userId: number): boolean
			local data = env.data(userId)
			return data.currencies.coins == data.stats.totalCoinsEarned - data.stats.totalCoinsSpent
				and data.currencies.coins >= 0
		end

		return env
	end

	-- Les quatre RemoteEvents client -> serveur, avec un identifiant valide.
	local ACTIONS = {
		{
			name = "Collect",
			field = "resourceId",
			valid = LEAF,
			call = function(env: any, userId: number, payload: any, extra: number?): any
				return env.collection.HandleRequest(userId, payload, extra)
			end,
		},
		{
			name = "Sell",
			field = "sellZoneId",
			valid = ZONE,
			call = function(env: any, userId: number, payload: any, extra: number?): any
				return env.sell.HandleRequest(userId, payload, extra)
			end,
		},
		{
			name = "Upgrade",
			field = "upgradeId",
			valid = "Backpack",
			call = function(env: any, userId: number, payload: any, extra: number?): any
				return env.upgrade.HandleRequest(userId, payload, extra)
			end,
		},
		{
			name = "UnlockWorld",
			field = "worldId",
			valid = "GoldenDesert",
			call = function(env: any, userId: number, payload: any, extra: number?): any
				return env.world.HandleRequest(userId, payload, extra)
			end,
		},
	}

	local function withCoins(coins: number): (profile: any) -> ()
		return function(profile: any)
			profile.currencies.coins = coins
			profile.stats.totalCoinsEarned = coins
		end
	end

	-- PAYLOADVALIDATOR --------------------------------------------------------

	case("PayloadValidator : chaque motif de refus", function(check)
		local Reason = PayloadValidator.Reason
		local cases: { { any } } = {
			{ { id = "a" }, 1, Reason.ExtraArguments },
			{ nil, 0, Reason.NotTable },
			{ "id", 0, Reason.NotTable },
			{ {}, 0, Reason.MissingField },
			{ { id = 5 }, 0, Reason.WrongType },
			{ { id = "" }, 0, Reason.Empty },
			{ { id = string.rep("a", 65) }, 0, Reason.TooLong },
			{ { id = "a b" }, 0, Reason.BadCharacters },
			{ { id = "a\0" }, 0, Reason.BadCharacters },
			{ { id = "a", amount = 9 }, 0, Reason.ExtraField },
			{ { id = "a", [1] = "x" }, 0, Reason.ExtraField },
		}
		for index, entry in ipairs(cases) do
			local value, reason = PayloadValidator.readId(entry[1], "id", 64, entry[2])
			check(value == nil and reason == entry[3], `cas {index} : {tostring(value)} / {tostring(reason)}`)
		end
		local value, reason = PayloadValidator.readId({ id = "green_leaf-001" }, "id", 64, 0)
		check(value == "green_leaf-001" and reason == nil, "identifiant valide refusé")
		local unchecked = PayloadValidator.readId({ id = "a" }, "id", 64, nil)
		check(unchecked == "a", "nil (non contrôlé) traité comme argument en trop")
	end)

	-- REMOTEEVENTS : chaque action --------------------------------------------

	for _, action in ipairs(ACTIONS) do
		case(`{action.name} : payloads malformés, champs et arguments en trop`, function(check)
			local env = newEnv({ prepare = { [USER_A] = withCoins(50) } })
			env.load(USER_A)
			local before = env.snapshot(USER_A)
			local field = action.field
			local bad: { { any } } = {
				{ nil, 0 },
				{ "texte", 0 },
				{ 42, 0 },
				{ true, 0 },
				{ {}, 0 },
				{ { [field] = 5 }, 0 },
				{ { [field] = "" }, 0 },
				{ { [field] = string.rep("x", 200) }, 0 },
				{ { [field] = "a/b" }, 0 },
				{ { [field] = action.valid, amount = 9999 }, 0 },
				{ { [field] = action.valid, price = 0, level = 99, coins = 1e9 }, 0 },
				{ { [field] = action.valid }, 1 },
				{ { [field] = action.valid }, 3 },
			}
			for index, entry in ipairs(bad) do
				env.now += 5
				local result = action.call(env, USER_A, entry[1], entry[2])
				check(not result.ok and result.code == Code.InvalidTarget, `cas {index} : {tostring(result.code)}`)
			end
			check(deepEqual(before, env.snapshot(USER_A)), "profil modifié par un payload invalide")
			check(env.security.GetCount(USER_A, SecurityLog.Type.InvalidPayload) == #bad, "refus non journalisés")
		end)

		case(`{action.name} : identifiant inexistant`, function(check)
			local env = newEnv()
			env.load(USER_A)
			local before = env.snapshot(USER_A)
			local result = action.call(env, USER_A, { [action.field] = "does_not_exist_42" }, 0)
			check(not result.ok and result.code == Code.InvalidTarget, `code {tostring(result.code)}`)
			check(deepEqual(before, env.snapshot(USER_A)), "profil modifié")
			check(env.security.GetCount(USER_A, SecurityLog.Type.UnknownId) == 1, "identifiant inconnu non journalisé")
		end)

		case(`{action.name} : payload valide traité`, function(check)
			local env = newEnv()
			env.load(USER_A)
			local result = action.call(env, USER_A, { [action.field] = action.valid }, 0)
			check(result.code ~= Code.InvalidTarget and result.code ~= Code.RateLimited, `code {tostring(result.code)}`)
		end)

		case(`{action.name} : spam de 300 demandes`, function(check)
			local env = newEnv({ prepare = { [USER_A] = withCoins(10_000) } })
			env.load(USER_A)
			local limited, loud, succeeded = 0, 0, 0
			for _ = 1, 300 do
				local result = action.call(env, USER_A, { [action.field] = action.valid }, 0)
				if result.code == Code.RateLimited then
					limited += 1
					if not result.silent then
						loud += 1
					end
				elseif result.ok then
					succeeded += 1
				end
			end
			check(limited >= 290, `{limited} demande(s) limitée(s) seulement`)
			check(loud == 1, `{loud} réponse(s) RATE_LIMITED envoyées au client`)
			check(succeeded <= 5, `{succeeded} succès sous spam`)
			check(env.balanced(USER_A), "monnaie créée ou perdue sous spam")
		end)

		case(`{action.name} : joueur sans profil actif`, function(check)
			local env = newEnv()
			local result = action.call(env, USER_GHOST, { [action.field] = action.valid }, 0)
			check(not result.ok and result.code == Code.ProfileNotLoaded, `code {tostring(result.code)}`)
		end)
	end

	-- DÉPLACEMENTS DANS LA COLLECTE ET LA VENTE --------------------------------

	local refusingMovement = {
		CanAct = function(): (boolean, string?)
			return false, "anomaly"
		end,
	}

	case("collecte refusée par le contrôle des déplacements (TOO_FAR, rien consommé)", function(check)
		local env = newEnv({ movement = refusingMovement })
		env.load(USER_A)
		local result = env.collection.HandleRequest(USER_A, { resourceId = LEAF }, 0)
		check(not result.ok and result.code == Code.TooFar, `code {tostring(result.code)}`)
		check(env.spawner.GetNode(LEAF).state == ResourceSpawner.State.Active, "nœud consommé")
		check(env.collection.GetClientState(USER_A).inventory.used == 0, "ressource créditée")
		check(env.security.GetCount(USER_A, SecurityLog.Type.MovementRefused) == 1, "refus non journalisé")
	end)

	case("vente refusée par le contrôle des déplacements (TOO_FAR, sac intact)", function(check)
		local env = newEnv({
			movement = refusingMovement,
			prepare = {
				[USER_A] = function(profile: any)
					profile.inventory.resources.green_leaf = 5
					profile.stats.totalResourcesCollected = 5
				end,
			},
		})
		env.load(USER_A)
		local before = env.snapshot(USER_A)
		local result = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE }, 0)
		check(not result.ok and result.code == Code.TooFar, `code {tostring(result.code)}`)
		check(deepEqual(before, env.snapshot(USER_A)), "profil modifié")
	end)

	case("validateur réel : téléportation puis collecte et vente refusées", function(check)
		local validator = MovementValidator.new(modules.MovementSecurityConfig)
		local env = newEnv({
			movement = validator,
			prepare = {
				[USER_A] = function(profile: any)
					profile.inventory.resources.wood = 2
					profile.stats.totalResourcesCollected = 2
				end,
			},
		})
		env.load(USER_A)
		validator.SetSpeed(USER_A, 16)
		validator.Reset(USER_A, { X = 200, Y = 0, Z = 200 }, env.now)
		-- Le client se « téléporte » sur la ressource et la zone de vente.
		env.now += 0.25
		env.positions[USER_A] = { X = 1, Y = 0, Z = 1 }
		local verdict = validator.Observe(USER_A, env.positions[USER_A], env.now)
		check(verdict.status == "anomaly", `téléportation non détectée : {verdict.status}`)
		local collect = env.collection.HandleRequest(USER_A, { resourceId = LEAF }, 0)
		check(collect.code == Code.TooFar, `collecte : {tostring(collect.code)}`)
		local sale = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE }, 0)
		check(sale.code == Code.TooFar, `vente : {tostring(sale.code)}`)
		check(env.data(USER_A).currencies.coins == 0, "Coins crédités")
	end)

	case("NaN et infini : collecte et vente refusées (TOO_FAR)", function(check)
		local env = newEnv({
			prepare = {
				[USER_A] = function(profile: any)
					profile.inventory.resources.green_leaf = 3
					profile.stats.totalResourcesCollected = 3
				end,
			},
		})
		env.load(USER_A)
		local nan = 0 / 0
		for index, position in ipairs({
			{ X = nan, Y = 0, Z = 0 },
			{ X = 0, Y = math.huge, Z = 0 },
			{ X = 0, Y = 0, Z = -math.huge },
		}) do
			env.positions[USER_A] = position
			env.now += 5
			local collect = env.collection.HandleRequest(USER_A, { resourceId = LEAF }, 0)
			check(collect.code == Code.TooFar, `collecte cas {index} : {tostring(collect.code)}`)
			local sale = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE }, 0)
			check(sale.code == Code.TooFar, `vente cas {index} : {tostring(sale.code)}`)
		end
		check(env.data(USER_A).currencies.coins == 0, "vente acceptée avec une position non finie")
		check(env.collection.GetClientState(USER_A).inventory.used == 3, "collecte acceptée avec une position non finie")
	end)

	case("réapparition : la référence est le point d'apparition (Reset ne téléporte plus)", function(check)
		local env = newEnv()
		env.load(USER_A)
		check(env.collection.HandleRequest(USER_A, { resourceId = LEAF }, 0).ok, "première collecte")
		env.now += 5
		-- Réapparition au point (0, 0, 0), puis position aussitôt sur un nœud à 300 studs.
		env.collection.ResetTravelReference(USER_A, { X = 0, Y = 0, Z = 0 })
		env.positions[USER_A] = { X = 300, Y = 0, Z = 1 }
		local result = env.collection.HandleRequest(USER_A, { resourceId = STONE_FAR }, 0)
		check(result.code == Code.TooFar, `collecte après Reset : {tostring(result.code)}`)
		-- Comportement T2 conservé sans position : la référence est oubliée.
		env.collection.ResetTravelReference(USER_A, nil)
		env.now += 5
		local legacy = env.collection.HandleRequest(USER_A, { resourceId = STONE_FAR }, 0)
		check(legacy.ok, `sans position : {tostring(legacy.code)}`)
	end)

	-- INTÉGRITÉ ÉCONOMIQUE -----------------------------------------------------

	case("double vente au même instant : un seul crédit", function(check)
		local env = newEnv({
			prepare = {
				[USER_A] = function(profile: any)
					profile.inventory.resources = { green_leaf = 6, wood = 2 }
					profile.stats.totalResourcesCollected = 8
				end,
			},
		})
		env.load(USER_A)
		local expected = SaleValue.quote(env.data(USER_A).inventory.resources).total
		local first = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE }, 0)
		local second = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE }, 0)
		check(first.ok and first.coinsEarned == expected, `première vente : {tostring(first.code)} {first.coinsEarned}`)
		check(not second.ok and second.code == Code.NothingToSell, `seconde vente : {tostring(second.code)}`)
		check(env.data(USER_A).currencies.coins == expected, "double crédit")
		check(env.balanced(USER_A), "solde incohérent")
	end)

	case("double achat au même instant avec le solde d'un seul : un seul débit", function(check)
		local cost = UpgradeMath.nextCost("Backpack", 1)
		local env = newEnv({ prepare = { [USER_A] = withCoins(cost) } })
		env.load(USER_A)
		local first = env.upgrade.HandleRequest(USER_A, { upgradeId = "Backpack" }, 0)
		local second = env.upgrade.HandleRequest(USER_A, { upgradeId = "Backpack" }, 0)
		check(first.ok, `premier achat : {tostring(first.code)}`)
		check(second.code == Code.InsufficientFunds, `second achat : {tostring(second.code)}`)
		local data = env.data(USER_A)
		check(data.upgrades.backpackLevel == 2 and data.currencies.coins == 0, "double achat ou débit incorrect")
		check(env.balanced(USER_A), "solde incohérent")
	end)

	case("achat sans solde suffisant : refusé, rien modifié, journalisé", function(check)
		local env = newEnv()
		env.load(USER_A)
		local before = env.snapshot(USER_A)
		local result = env.upgrade.HandleRequest(USER_A, { upgradeId = "Grabber" }, 0)
		check(result.code == Code.InsufficientFunds, `code {tostring(result.code)}`)
		check(deepEqual(before, env.snapshot(USER_A)), "profil modifié")
		check(env.security.GetCount(USER_A, SecurityLog.Type.EconomyRefused) == 1, "refus non journalisé")
	end)

	case("déblocage sans prérequis : refusé même avec un solde suffisant", function(check)
		local env = newEnv({ prepare = { [USER_A] = withCoins(1_000_000) } })
		env.load(USER_A)
		local before = env.snapshot(USER_A)
		local desert = env.world.HandleRequest(USER_A, { worldId = "GoldenDesert" }, 0)
		check(desert.code == Code.RequirementNotMet, `GoldenDesert : {tostring(desert.code)}`)
		env.now += 5
		local peaks = env.world.HandleRequest(USER_A, { worldId = "FrozenPeaks" }, 0)
		check(peaks.code == Code.RequirementNotMet, `FrozenPeaks : {tostring(peaks.code)}`)
		check(deepEqual(before, env.snapshot(USER_A)), "profil modifié")
	end)

	case("appels simultanés mélangés sur un même profil : aucune création de monnaie", function(check)
		local env = newEnv({ prepare = { [USER_A] = withCoins(400) } })
		env.load(USER_A)
		local spentSeen, earnedSeen = 0, 0
		for round = 1, 40 do
			env.now += 0.8
			-- Inventaire injecté par la voie autorisée (Update), comme une collecte.
			env.playerData.Update(USER_A, function(draft: any): boolean?
				draft.inventory.resources.green_leaf = (draft.inventory.resources.green_leaf or 0) + 3
				draft.stats.totalResourcesCollected += 3
				return nil
			end)
			local sale = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE }, 0)
			local purchase = env.upgrade.HandleRequest(USER_A, { upgradeId = if round % 2 == 0 then "Grabber" else "Boots" }, 0)
			local again = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE }, 0)
			earnedSeen += sale.coinsEarned + again.coinsEarned
			spentSeen += purchase.coinsSpent
			check(env.balanced(USER_A), `tour {round} : solde incohérent`)
		end
		local data = env.data(USER_A)
		check(data.stats.totalCoinsEarned == 400 + earnedSeen, "gains non comptés ou inventés")
		check(data.stats.totalCoinsSpent == spentSeen, "dépenses non comptées ou inventées")
	end)

	-- MULTIJOUEUR SIMULÉ -------------------------------------------------------

	case("deux joueurs collectent la même ressource : un seul sac crédité", function(check)
		local env = newEnv()
		env.load(USER_A)
		env.load(USER_B)
		local a = env.collection.HandleRequest(USER_A, { resourceId = LEAF }, 0)
		local b = env.collection.HandleRequest(USER_B, { resourceId = LEAF }, 0)
		check(a.ok ~= b.ok, "zéro ou deux succès")
		check(b.code == Code.ResourceUnavailable, `second joueur : {tostring(b.code)}`)
		local total = env.collection.GetClientState(USER_A).inventory.used
			+ env.collection.GetClientState(USER_B).inventory.used
		check(total == 1, `{total} unité(s) créditée(s)`)
	end)

	case("deux joueurs vendent simultanément : chacun son propre sac", function(check)
		local function bag(quantity: number): (profile: any) -> ()
			return function(profile: any)
				profile.inventory.resources.green_leaf = quantity
				profile.stats.totalResourcesCollected = quantity
			end
		end
		local env = newEnv({ prepare = { [USER_A] = bag(4), [USER_B] = bag(7) } })
		env.load(USER_A)
		env.load(USER_B)
		local a = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE }, 0)
		local b = env.sell.HandleRequest(USER_B, { sellZoneId = ZONE }, 0)
		local price = SaleValue.quote({ green_leaf = 1 }).total
		check(a.ok and a.coinsEarned == 4 * price, `A : {a.coinsEarned}`)
		check(b.ok and b.coinsEarned == 7 * price, `B : {b.coinsEarned}`)
		check(env.balanced(USER_A) and env.balanced(USER_B), "solde incohérent")
	end)

	case("déconnexion pendant une opération puis reconnexion : données cohérentes", function(check)
		local store = MemoryDataStore.new()
		local env = newEnv({ store = store, prepare = { [USER_A] = withCoins(300) } })
		env.load(USER_A)
		local purchase = env.upgrade.HandleRequest(USER_A, { upgradeId = "Backpack" }, 0)
		check(purchase.ok, "achat initial")
		local expected = env.snapshot(USER_A)
		check(env.playerData.ReleasePlayer(USER_A).ok, "sauvegarde de sortie")
		-- Demandes arrivées après la sortie : refusées, rien n'est écrit.
		env.now += 5
		for _, action in ipairs(ACTIONS) do
			local result = action.call(env, USER_A, { [action.field] = action.valid }, 0)
			check(result.code == Code.ProfileNotLoaded, `{action.name} après sortie : {tostring(result.code)}`)
		end
		-- Reconnexion sur un autre serveur, même magasin.
		local other = newEnv({ store = store })
		other.load(USER_A)
		check(deepEqual(expected, other.snapshot(USER_A)), "profil différent après reconnexion")
		check(other.balanced(USER_A), "solde incohérent après reconnexion")
	end)

	-- JOURNAL DE SÉCURITÉ -----------------------------------------------------

	local function newLog(sink: ((line: string) -> ())?)
		local env = { now = 0, lines = {} :: { string } }
		env.log = SecurityLog.new({
			clock = function(): number
				return env.now
			end,
			config = modules.SecurityLogConfig,
			sink = sink or function(line: string)
				table.insert(env.lines, line)
			end,
			fallback = function() end,
		})
		return env
	end

	case("SecurityLog : une ligne par joueur et par type, rafales comptées", function(check)
		local env = newLog()
		for _ = 1, 25 do
			env.log.Record(1, "invalid_payload", { action = "Collect" })
		end
		check(#env.lines == 1, `{#env.lines} ligne(s) pour une rafale`)
		env.log.Record(1, "rate_limited", { action = "Collect" })
		env.log.Record(2, "invalid_payload", { action = "Collect" })
		check(#env.lines == 3, "types ou joueurs non indépendants")
		env.now += modules.SecurityLogConfig.perPlayerTypeIntervalSeconds
		env.log.Record(1, "invalid_payload", { action = "Collect" })
		local last = env.lines[#env.lines]
		check(string.find(last, "count=26", 1, true) ~= nil, `compteur absent : {last}`)
		check(string.find(last, "suppressed=24", 1, true) ~= nil, `occurrences masquées absentes : {last}`)
		check(env.log.GetCount(1, "invalid_payload") == 26, "compteur interne")
	end)

	case("SecurityLog : format structuré, valeurs client assainies", function(check)
		local env = newLog()
		env.log.Record(5, "unknown_id", { id = "evil id\n[Security] type=fake user=1", action = "Sell" })
		local line = env.lines[1]
		check(string.sub(line, 1, 30) == "[Security] type=unknown_id use", `préfixe : {line}`)
		check(string.find(line, "\n", 1, true) == nil, "retour à la ligne injecté")
		check(select(2, string.gsub(line, "%[Security%]", "")) == 1, "fausse ligne injectée")
		check(string.find(line, "action=Sell", 1, true) ~= nil, "champ absent")
	end)

	case("SecurityLog : plafond global contre un afflux", function(check)
		local env = newLog()
		for userId = 1, 500 do
			env.log.Record(userId, "rate_limited", nil)
		end
		check(#env.lines == modules.SecurityLogConfig.globalMaxLines, `{#env.lines} ligne(s)`)
		env.now += modules.SecurityLogConfig.globalWindowSeconds
		env.log.Record(9999, "rate_limited", nil)
		check(string.find(env.lines[#env.lines - 1], "log_overflow", 1, true) ~= nil, "débordement non signalé")
	end)

	case("SecurityLog en panne : aucune erreur, décisions inchangées", function(check)
		local broken = newLog(function()
			error("journal hors service")
		end)
		local ok = pcall(broken.log.Record, 1, "invalid_payload", nil)
		check(ok, "Record a levé une erreur")
		-- Un service branché sur un journal en panne décide normalement.
		local env = newEnv()
		env.load(USER_A)
		local collection = CollectionService.new({
			playerData = env.playerData,
			inventory = InventoryService.new({ playerData = env.playerData }),
			spawner = env.spawner,
			rateLimit = {
				Allow = function(): boolean
					return true
				end,
				Clear = function() end,
			},
			clock = function(): number
				return env.now
			end,
			getCharacterPosition = function(): any
				return { X = 1, Y = 0, Z = 1 }
			end,
			security = broken.log,
			log = function() end,
		})
		local refused = collection.HandleRequest(USER_A, { resourceId = LEAF, amount = 5 }, 0)
		check(refused.code == Code.InvalidTarget, `refus : {tostring(refused.code)}`)
		local accepted = collection.HandleRequest(USER_A, { resourceId = LEAF }, 0)
		check(accepted.ok, `collecte : {tostring(accepted.code)}`)
	end)

	-- AUDIT DE PROFIL ---------------------------------------------------------

	local function auditChecks(profile: any): { [string]: any }
		local found = {}
		for _, issue in ipairs(ProfileAudit.run(profile)) do
			found[issue.check] = issue
		end
		return found
	end

	case("audit : nouveau profil et profil avancé cohérent sans constat", function(check)
		check(next(auditChecks(DataSchema.newProfile())) == nil, "constat sur un nouveau profil")
		local profile = DataSchema.newProfile()
		local backpack = UpgradeMath.cumulativeCost("Backpack", 3)
		profile.upgrades.backpackLevel = 3
		profile.stats.totalCoinsEarned = backpack + 40
		profile.stats.totalCoinsSpent = backpack
		profile.currencies.coins = 40
		profile.inventory.resources.green_leaf = 10
		profile.stats.totalResourcesCollected = 90
		local found = auditChecks(profile)
		check(next(found) == nil, `constat inattendu : {tostring((next(found)))}`)
	end)

	case("audit : Coins sans origine, niveaux non payés, monde sans prérequis", function(check)
		local profile = DataSchema.newProfile()
		profile.currencies.coins = 500
		profile.upgrades.backpackLevel = 2
		profile.worlds.GoldenDesert = true
		local found = auditChecks(profile)
		check(found.coins_unexplained ~= nil and found.coins_unexplained.excess == 500, "Coins sans origine")
		check(found.unpaid_progress ~= nil, "progression non payée")
		check(found.world_requirement ~= nil and found.world_requirement.world == "GoldenDesert", "prérequis de monde")
	end)

	case("audit : Coins disparus, sac au-delà de la capacité et des collectes", function(check)
		local profile = DataSchema.newProfile()
		profile.stats.totalCoinsEarned = 30
		profile.inventory.resources.green_leaf = 999
		local found = auditChecks(profile)
		check(found.coins_missing ~= nil and found.coins_missing.deficit == 30, "Coins disparus")
		check(found.inventory_over_capacity ~= nil, "sac au-delà de la capacité")
		check(found.inventory_exceeds_collected ~= nil, "sac au-delà des collectes")
	end)

	case("audit : lecture seule et profil illisible sans erreur", function(check)
		local profile = DataSchema.newProfile()
		profile.currencies.coins = 77
		local copy = DataSchema.newProfile()
		copy.currencies.coins = 77
		ProfileAudit.run(profile)
		check(deepEqual(profile, copy), "profil modifié par l'audit")
		local ok, issues = pcall(ProfileAudit.run, { currencies = "x" })
		check(ok and issues[1].check == ProfileAudit.Check.Unreadable, "profil illisible mal traité")
		local okNil = pcall(ProfileAudit.run, nil)
		check(okNil, "profil nil : erreur")
	end)

	return failures, caseCount
end

return SecurityTests
