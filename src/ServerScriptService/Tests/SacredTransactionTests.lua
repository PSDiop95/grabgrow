--!strict
-- Vente et améliorations sacrées (T10.5a, D-037, D-038) : transactions
-- atomiques, effets, persistance U-A.
--
-- Vrai PlayerDataService sur MemoryDataStore (aucun DataStore réel, aucune
-- donnée de production), horloge simulée.

local SacredTransactionTests = {}

export type Modules = {
	PlayerDataService: any,
	MemoryDataStore: any,
	DataSchema: any,
	DataConfig: any,
	SacredTransactionService: any,
	SacredUpgradeRules: any,
	SacredResourceConfig: any,
	InventoryService: any,
	RateLimitService: any,
	GuardianSecurityConfig: any,
	UpgradeConfig: any,
	Remotes: any,
}

local USER_A = 3001
local USER_B = 3002
local SEED = "sacred_heartwood_seed"
local RELIC = "sacred_sun_relic"
local HEART = "sacred_frost_heart"

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

function SacredTransactionTests.run(modules: Modules): ({ string }, number)
	local PlayerDataService = modules.PlayerDataService
	local MemoryDataStore = modules.MemoryDataStore
	local DataSchema = modules.DataSchema
	local SacredTransactionService = modules.SacredTransactionService
	local Rules = modules.SacredUpgradeRules
	local SacredResourceConfig = modules.SacredResourceConfig
	local InventoryService = modules.InventoryService
	local RateLimitService = modules.RateLimitService
	local UpgradeConfig = modules.UpgradeConfig
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
		return { store = MemoryDataStore.new(), now = 1_000_000 }
	end

	local function newServer(world: any, serverId: string, rateLimit: any?): any
		local server: any = { saves = {} :: { string }, logs = {} :: { string }, failUpdate = false }
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
				table.insert(server.saves, tostring(reason))
				return server.data.RequestSave(userId, reason)
			end,
		}
		server.tx = SacredTransactionService.new({ playerData = proxy, rateLimit = rateLimit or allow, log = log })
		function server.load(userId: number): any
			return server.data.LoadPlayer(userId)
		end
		function server.profile(userId: number): any
			return server.data.GetData(userId)
		end
		function server.give(userId: number, resourceId: string, quantity: number)
			server.data.Update(userId, function(draft: any): boolean?
				draft.inventory.resources[resourceId] = quantity
				return true
			end)
		end
		function server.sell(userId: number, resourceId: string, payload: any?, extra: number?): any
			return server.tx.HandleSell(userId, payload or { resourceId = resourceId }, extra or 0)
		end
		function server.upgrade(userId: number, upgradeId: string, payload: any?, extra: number?): any
			return server.tx.HandleUpgrade(userId, payload or { upgradeId = upgradeId }, extra or 0)
		end
		function server.saveCount(reason: string): number
			local count = 0
			for _, entry in ipairs(server.saves) do
				if entry == reason then
					count += 1
				end
			end
			return count
		end
		return server
	end

	local function loaded(userId: number?): any
		local server = newServer(newWorld(), "S1")
		server.load(userId or USER_A)
		return server
	end

	-- Configuration ------------------------------------------------------------

	case("configuration : valeurs S2 et coûts R-1 (D-037, D-038)", function(check)
		local expected = {
			sacred_heartwood_seed = 198,
			sacred_sun_relic = 868,
			sacred_frost_heart = 5840,
			sacred_astral_essence = 27992,
		}
		for resourceId, value in pairs(expected) do
			check(SacredResourceConfig.Resources[resourceId].sellValue == value, `{resourceId} : valeur`)
		end
		local seen: { [string]: boolean } = {}
		for _, upgradeId in ipairs(SacredResourceConfig.UpgradeOrder) do
			local definition = SacredResourceConfig.Upgrades[upgradeId]
			check(definition ~= nil, `{upgradeId} : absente`)
			local resource = SacredResourceConfig.Resources[definition.resourceId]
			check(resource ~= nil, `{upgradeId} : ressource inconnue`)
			check(definition.cost == resource.rewardUnits, `{upgradeId} : coût ≠ offre du monde (R-1)`)
			check(not seen[definition.resourceId], `{upgradeId} : deux améliorations pour un monde`)
			seen[definition.resourceId] = true
			check(#Rules.key(upgradeId) <= 64, `{upgradeId} : clé trop longue`)
		end
	end)

	case("effets : portée, intervalle, capacité, boussole", function(check)
		local profile = DataSchema.newProfile()
		check(Rules.collectRange(profile, 10) == 10, "portée sans amélioration")
		check(Rules.collectInterval(profile, 1) == 1, "intervalle sans amélioration")
		check(Rules.capacity(profile, 140) == 140, "capacité sans amélioration")
		for _, upgradeId in ipairs(SacredResourceConfig.UpgradeOrder) do
			profile.achievements[Rules.key(upgradeId)] = true
		end
		check(Rules.collectRange(profile, 10) == 12, "Magnet sacré : +2 studs")
		check(math.abs(Rules.collectInterval(profile, 1) - 0.95) < 1e-9, "Grabber sacré : −5 %")
		check(Rules.capacity(profile, 140) == 154, "Sac sacré : +10 %")
		check(Rules.capacity(profile, 75) == 82, "Sac sacré : arrondi inférieur")
		local owned = Rules.owned(profile)
		check(owned.sacred_compass == true and owned.sacred_magnet == true, "possessions")
		profile.achievements["sacred_upgrade_nope"] = true
		check(Rules.owned(profile).sacred_upgrade_nope == nil and Rules.owned(profile).nope == nil, "clé inconnue ignorée")
		check(not Rules.owns(profile, "nope"), "amélioration inconnue")
	end)

	-- Vente --------------------------------------------------------------------

	case("vente sacrée : toutes les unités, Coins crédités, totalSales inchangé", function(check)
		local server = loaded()
		server.give(USER_A, SEED, 3)
		local before = deepCopy(server.profile(USER_A))
		local result = server.sell(USER_A, SEED)
		check(result.ok, `vente refusée ({result.code})`)
		check(result.quantitySold == 3 and result.coinsEarned == 594, "3 × 198 attendu")
		local after = server.profile(USER_A)
		check(after.inventory.resources[SEED] == nil, "unités non retirées")
		check(after.currencies.coins == before.currencies.coins + 594, "solde")
		check(after.stats.totalCoinsEarned == before.stats.totalCoinsEarned + 594, "totalCoinsEarned")
		check(after.stats.totalSales == before.stats.totalSales, "totalSales modifié (D-038)")
		check(server.saveCount("sacred_sale") == 1, "sauvegarde après vente")
	end)

	case("double vente : la seconde ne crédite rien", function(check)
		local server = loaded()
		server.give(USER_A, RELIC, 3)
		check(server.sell(USER_A, RELIC).ok, "1re vente")
		local coins = server.profile(USER_A).currencies.coins
		local second = server.sell(USER_A, RELIC)
		check(second.code == Code.NothingToSell, `NOTHING_TO_SELL attendu, {second.code}`)
		check(server.profile(USER_A).currencies.coins == coins, "second crédit")
	end)

	case("vente : identifiants refusés, ressources ordinaires intactes", function(check)
		local server = loaded()
		server.give(USER_A, "green_leaf", 5)
		local before = deepCopy(server.profile(USER_A))
		check(server.sell(USER_A, "green_leaf").code == Code.InvalidTarget, "ressource ordinaire")
		check(server.sell(USER_A, "sacred_nope").code == Code.InvalidTarget, "identifiant inconnu")
		check(server.sell(USER_A, SEED).code == Code.NothingToSell, "aucune unité")
		check(deepEqual(server.profile(USER_A), before), "profil modifié")
	end)

	case("vente : payload falsifié", function(check)
		local server = loaded()
		server.give(USER_A, SEED, 3)
		local before = deepCopy(server.profile(USER_A))
		local forged: { any } = {
			{ resourceId = SEED, quantity = 99 },
			{ resourceId = SEED, coins = 1e9 },
			{ resourceId = 42 },
			"sacred_heartwood_seed",
		}
		for index, payload in ipairs(forged) do
			check(server.sell(USER_A, SEED, payload).code == Code.InvalidTarget, `payload {index} accepté`)
		end
		check(server.sell(USER_A, SEED, nil, 1).code == Code.InvalidTarget, "argument en trop accepté")
		check(deepEqual(server.profile(USER_A), before), "profil modifié")
	end)

	case("vente : échec de mutation, rien de partiel", function(check)
		local server = loaded()
		server.give(USER_A, HEART, 3)
		local before = deepCopy(server.profile(USER_A))
		server.failUpdate = true
		check(server.sell(USER_A, HEART).code == Code.InternalError, "INTERNAL_ERROR attendu")
		check(deepEqual(server.profile(USER_A), before), "modification partielle")
		check(server.saveCount("sacred_sale") == 0, "sauvegarde sans opération")
	end)

	-- Améliorations ------------------------------------------------------------

	case("amélioration : unités consommées, acquisition posée, capacité +10 %", function(check)
		local server = loaded()
		server.give(USER_A, HEART, 3)
		local capacityBefore = InventoryService.describe(server.profile(USER_A)).capacity
		local result = server.upgrade(USER_A, "sacred_backpack")
		check(result.ok, `achat refusé ({result.code})`)
		check(result.unitsSpent == 3 and result.resourceId == HEART, "coût")
		local profile = server.profile(USER_A)
		check(profile.inventory.resources[HEART] == nil, "unités non consommées")
		check(profile.achievements[Rules.key("sacred_backpack")] == true, "clé U-A absente")
		local expected = math.floor(UpgradeConfig.Backpack.levels[profile.upgrades.backpackLevel].value * 1.10)
		check(InventoryService.describe(profile).capacity == expected, "capacité")
		check(InventoryService.describe(profile).capacity > capacityBefore, "capacité inchangée")
		check(server.saveCount("sacred_upgrade") == 1, "sauvegarde après achat")
	end)

	case("double achat : MAX_LEVEL, aucune seconde consommation", function(check)
		local server = loaded()
		server.give(USER_A, SEED, 6)
		check(server.upgrade(USER_A, "sacred_magnet").ok, "1er achat")
		local second = server.upgrade(USER_A, "sacred_magnet")
		check(second.code == Code.MaxLevel, `MAX_LEVEL attendu, {second.code}`)
		check(server.profile(USER_A).inventory.resources[SEED] == 3, "3 unités restantes attendues")
	end)

	case("ressources insuffisantes : rien n'est modifié", function(check)
		local server = loaded()
		server.give(USER_A, RELIC, 2)
		local before = deepCopy(server.profile(USER_A))
		local result = server.upgrade(USER_A, "sacred_grabber")
		check(result.code == Code.InsufficientResources, `INSUFFICIENT_RESOURCES attendu, {result.code}`)
		check(deepEqual(server.profile(USER_A), before), "profil modifié")
		check(server.upgrade(USER_A, "sacred_magnet").code == Code.InsufficientResources, "unités d'un autre monde")
	end)

	case("vendre ou améliorer : la vente exclut l'achat", function(check)
		local server = loaded()
		server.give(USER_A, SEED, 3)
		check(server.sell(USER_A, SEED).ok, "vente")
		check(server.upgrade(USER_A, "sacred_magnet").code == Code.InsufficientResources, "achat après vente")
		check(not Rules.owns(server.profile(USER_A), "sacred_magnet"), "acquis sans unités")
	end)

	case("vendre après améliorer : unités consommées non revendables", function(check)
		local server = loaded()
		server.give(USER_A, RELIC, 3)
		check(server.upgrade(USER_A, "sacred_grabber").ok, "achat")
		local coins = server.profile(USER_A).currencies.coins
		local sale = server.sell(USER_A, RELIC)
		check(sale.code == Code.NothingToSell, `NOTHING_TO_SELL attendu, {sale.code}`)
		check(server.profile(USER_A).currencies.coins == coins, "crédit sur unités consommées")
		check(Rules.owns(server.profile(USER_A), "sacred_grabber"), "acquisition perdue")
	end)

	case("amélioration : identifiant inconnu, payload falsifié, échec de mutation", function(check)
		local server = loaded()
		server.give(USER_A, HEART, 3)
		local before = deepCopy(server.profile(USER_A))
		check(server.upgrade(USER_A, "Backpack").code == Code.InvalidTarget, "amélioration ordinaire")
		check(server.upgrade(USER_A, "nope").code == Code.InvalidTarget, "identifiant inconnu")
		check(
			server.upgrade(USER_A, "sacred_backpack", { upgradeId = "sacred_backpack", cost = 0 }).code
				== Code.InvalidTarget,
			"champ en trop"
		)
		check(server.upgrade(USER_A, "sacred_backpack", nil, 1).code == Code.InvalidTarget, "argument en trop")
		server.failUpdate = true
		check(server.upgrade(USER_A, "sacred_backpack").code == Code.InternalError, "INTERNAL_ERROR attendu")
		check(deepEqual(server.profile(USER_A), before), "modification partielle")
	end)

	case("sac plein : vente et achat possibles", function(check)
		local server = loaded()
		local capacity = InventoryService.describe(server.profile(USER_A)).capacity
		server.give(USER_A, "green_leaf", capacity - 6)
		server.give(USER_A, HEART, 3)
		server.give(USER_A, SEED, 3)
		check(InventoryService.describe(server.profile(USER_A)).free == 0, "sac plein")
		check(server.upgrade(USER_A, "sacred_backpack").ok, "achat sac plein")
		check(server.sell(USER_A, SEED).ok, "vente sac plein")
		local state = InventoryService.describe(server.profile(USER_A))
		check(state.free > 0, "place libérée")
	end)

	-- Joueurs, profil, fréquence ----------------------------------------------

	case("deux joueurs : transactions isolées", function(check)
		local server = loaded()
		server.load(USER_B)
		server.give(USER_B, SEED, 3)
		local coinsB = server.profile(USER_B).currencies.coins
		check(server.sell(USER_A, SEED).code == Code.NothingToSell, "A vend les unités de B")
		check(server.upgrade(USER_A, "sacred_magnet").code == Code.InsufficientResources, "A dépense les unités de B")
		check(server.profile(USER_B).inventory.resources[SEED] == 3, "unités de B modifiées")
		check(server.profile(USER_B).currencies.coins == coinsB, "Coins de B modifiés")
		check(server.upgrade(USER_B, "sacred_magnet").ok, "achat de B")
		check(not Rules.owns(server.profile(USER_A), "sacred_magnet"), "acquisition partagée")
	end)

	case("profil non chargé : PROFILE_NOT_LOADED", function(check)
		local server = newServer(newWorld(), "S1")
		check(server.sell(USER_A, SEED).code == Code.ProfileNotLoaded, "vente")
		check(server.upgrade(USER_A, "sacred_magnet").code == Code.ProfileNotLoaded, "achat")
	end)

	case("fréquence : rafale limitée, refus silencieux", function(check)
		local world = newWorld()
		local rateLimit = RateLimitService.new({
			clock = function(): number
				return world.now
			end,
			limits = modules.GuardianSecurityConfig.RateLimits,
			logEveryRejections = 1000,
		})
		local server = newServer(world, "S1", rateLimit)
		server.load(USER_A)
		local limited = 0
		for _ = 1, 6 do
			local result = server.sell(USER_A, SEED)
			if result.code == Code.RateLimited then
				limited += 1
				check(result.silent, "refus non silencieux")
			end
		end
		check(limited > 0, "aucune limite")
	end)

	-- Persistance --------------------------------------------------------------

	case("reconnexion : acquisition et vente conservées (U-A, v3)", function(check)
		local world = newWorld()
		local first = newServer(world, "S1")
		first.load(USER_A)
		first.give(USER_A, HEART, 3)
		first.give(USER_A, SEED, 3)
		check(first.upgrade(USER_A, "sacred_backpack").ok, "achat")
		check(first.sell(USER_A, SEED).ok, "vente")
		local coins = first.profile(USER_A).currencies.coins
		check(first.data.ReleasePlayer(USER_A).ok, "sortie")
		local second = newServer(world, "S2")
		check(second.load(USER_A).ok, "rechargement")
		local profile = second.profile(USER_A)
		check(profile.schemaVersion == 3, "schéma modifié")
		check(Rules.owns(profile, "sacred_backpack"), "acquisition perdue")
		check(profile.inventory.resources[SEED] == nil and profile.inventory.resources[HEART] == nil, "unités revenues")
		check(profile.currencies.coins == coins, "Coins perdus")
		check(second.upgrade(USER_A, "sacred_backpack").code == Code.MaxLevel, "rachat après reconnexion")
		check(DataSchema.validate(profile), "profil refusé par le schéma")
	end)

	case("reconnexion après chaque étape : collecte, vente, amélioration", function(check)
		local world = newWorld()
		local function reconnect(previous: any, serverId: string): any
			check(previous.data.ReleasePlayer(USER_A).ok, `sortie avant {serverId}`)
			local nextServer = newServer(world, serverId)
			check(nextServer.load(USER_A).ok, `rechargement {serverId}`)
			return nextServer
		end
		local s1 = newServer(world, "S1")
		s1.load(USER_A)
		-- Collecte : unités posées comme par la réclamation (D-035).
		s1.give(USER_A, SEED, 3)
		s1.give(USER_A, HEART, 3)
		local s2 = reconnect(s1, "S2")
		check(s2.profile(USER_A).inventory.resources[SEED] == 3, "unités perdues après collecte")
		check(s2.sell(USER_A, SEED).ok, "vente")
		local coins = s2.profile(USER_A).currencies.coins
		local s3 = reconnect(s2, "S3")
		check(s3.profile(USER_A).currencies.coins == coins, "Coins perdus après vente")
		check(s3.profile(USER_A).inventory.resources[SEED] == nil, "unités vendues revenues")
		check(s3.sell(USER_A, SEED).code == Code.NothingToSell, "revente après reconnexion")
		check(s3.upgrade(USER_A, "sacred_magnet").code == Code.InsufficientResources, "consommation d'unités vendues")
		check(s3.upgrade(USER_A, "sacred_backpack").ok, "amélioration")
		local s4 = reconnect(s3, "S4")
		local profile = s4.profile(USER_A)
		check(Rules.owns(profile, "sacred_backpack"), "acquisition perdue")
		check(profile.inventory.resources[HEART] == nil, "unités consommées revenues")
		check(s4.sell(USER_A, HEART).code == Code.NothingToSell, "vente d'unités consommées")
		check(s4.upgrade(USER_A, "sacred_backpack").code == Code.MaxLevel, "rachat")
		check(profile.currencies.coins == coins, "Coins modifiés par l'amélioration")
	end)

	case("déconnexion avec sauvegarde en échec : état cohérent", function(check)
		local world = newWorld()
		world.store.seed(storeKey(USER_A), { profile = DataSchema.newProfile() })
		local first = newServer(world, "S1")
		first.load(USER_A)
		first.give(USER_A, RELIC, 3)
		check(first.data.SavePlayer(USER_A).ok, "sauvegarde initiale")
		world.store.setAlwaysFail(true)
		check(first.sell(USER_A, RELIC).ok, "vente en mémoire")
		first.data.ReleasePlayer(USER_A)
		world.store.setAlwaysFail(false)
		world.now += modules.DataConfig.SessionLock.timeoutSeconds + 60
		local second = newServer(world, "S2")
		check(second.load(USER_A).ok, "rechargement")
		local profile = second.profile(USER_A)
		local units = profile.inventory.resources[RELIC]
		local earned = profile.stats.totalCoinsEarned
		-- Soit la vente est entièrement perdue (unités, Coins d'avant), soit
		-- entièrement conservée : jamais unités ET Coins.
		check((units == 3 and earned == 0) or (units == nil and earned == 3 * 868), "état partiel")
	end)

	return failures, caseCount
end

return SacredTransactionTests
