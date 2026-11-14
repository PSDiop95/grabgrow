--!strict
-- Tests des améliorations et du déblocage des mondes (T4) avec de vrais
-- services (PlayerDataService, InventoryService, CollectionService,
-- SellService, UpgradeService, WorldUnlockService), un magasin en mémoire,
-- une horloge simulée et des positions fixées par le test. Aucune API Roblox.
--
-- Invariants vérifiés :
--   * un achat débite exactement le coût du niveau suivant (UpgradeConfig) ;
--   * un refus ne modifie ni solde, ni niveau, ni statistiques ;
--   * le solde n'est jamais négatif ; aucun double débit ;
--   * totalCoinsSpent = somme des débits ; totalCoinsEarned = somme des ventes.

local UpgradeServiceTests = {}

export type Modules = {
	UpgradeService: any,
	WorldUnlockService: any,
	EconomyService: any,
	SellService: any,
	CollectionService: any,
	InventoryService: any,
	PlayerDataService: any,
	RateLimitService: any,
	ResourceSpawner: any,
	MemoryDataStore: any,
	DataSchema: any,
	UpgradeMath: any,
	UpgradeConfig: any,
	WorldConfig: any,
	ResourceConfig: any,
	CollectionSecurityConfig: any,
	EconomySecurityConfig: any,
	Remotes: any,
	StudioTestPresets: any,
}

local USER_A = 5001
local USER_B = 5002
local ZONE = "GreenValley_Main"
local UNLIMITED = {
	Allow = function(): boolean
		return true
	end,
	Clear = function() end,
}

function UpgradeServiceTests.run(modules: Modules): ({ string }, number)
	local UpgradeService = modules.UpgradeService
	local WorldUnlockService = modules.WorldUnlockService
	local SellService = modules.SellService
	local CollectionService = modules.CollectionService
	local InventoryService = modules.InventoryService
	local PlayerDataService = modules.PlayerDataService
	local RateLimitService = modules.RateLimitService
	local ResourceSpawner = modules.ResourceSpawner
	local MemoryDataStore = modules.MemoryDataStore
	local UpgradeMath = modules.UpgradeMath
	local UpgradeConfig = modules.UpgradeConfig
	local WorldConfig = modules.WorldConfig
	local ResourceConfig = modules.ResourceConfig
	local CollectionSecurity = modules.CollectionSecurityConfig
	local Security = modules.EconomySecurityConfig
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

	-- Options : `store` réutilise un magasin ; `limited` active les vraies
	-- limites de fréquence des achats ; `nodes` = { nodeId = position }.
	local function newEnv(userIds: { number }, options: { store: any?, limited: boolean?, nodes: { [string]: any }? }?)
		local opts: any = options or {}
		local env = {
			now = 1000,
			store = opts.store or MemoryDataStore.new(),
			positions = {} :: { [number]: any },
			logs = {} :: { string },
			upgraded = {} :: { string },
		}
		local function log(level: string, message: string)
			table.insert(env.logs, `{level} {message}`)
		end
		local function clock(): number
			return env.now
		end
		local function getPosition(userId: number): any
			return env.positions[userId]
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
			schedule = function() end,
		})
		for nodeId, position in pairs(opts.nodes or {}) do
			env.spawner.Register(nodeId, "green_leaf", position)
		end
		env.collection = CollectionService.new({
			playerData = env.playerData,
			inventory = env.inventory,
			spawner = env.spawner,
			rateLimit = UNLIMITED,
			clock = clock,
			getCharacterPosition = getPosition,
			log = log,
		})
		env.sell = SellService.new({
			playerData = env.playerData,
			rateLimit = UNLIMITED,
			getSellZone = function(zoneId: string): any
				return if zoneId == ZONE then { position = { X = 0, Y = 0, Z = 0 } } else nil
			end,
			getCharacterPosition = getPosition,
			clock = clock,
			log = log,
		})
		local function limiter(): any
			if not opts.limited then
				return UNLIMITED
			end
			return RateLimitService.new({
				clock = clock,
				limits = Security.RateLimits,
				logEveryRejections = Security.RateLimitFeedback.logEveryRejections,
				log = log,
			})
		end
		env.upgrade = UpgradeService.new({
			playerData = env.playerData,
			rateLimit = limiter(),
			clock = clock,
			onUpgraded = function(userId: number, upgradeId: string, level: number)
				table.insert(env.upgraded, `{userId}:{upgradeId}:{level}`)
			end,
			log = log,
		})
		env.world = WorldUnlockService.new({
			playerData = env.playerData,
			rateLimit = limiter(),
			clock = clock,
			log = log,
		})

		for _, userId in ipairs(userIds) do
			assert(env.playerData.LoadPlayer(userId).ok, "chargement du joueur de test")
			env.positions[userId] = { X = 0, Y = 0, Z = 0 }
		end

		function env.profile(userId: number): any
			return env.playerData.GetData(userId)
		end

		-- Prépare un profil chargé (solde, niveaux, mondes, sac).
		function env.set(userId: number, values: { coins: number?, upgrades: { [string]: number }?, worlds: { [string]: boolean }?, resources: { [string]: number }? })
			local result = env.playerData.Update(userId, function(draft: any): boolean?
				if values.coins then
					draft.currencies.coins = values.coins
				end
				for upgradeId, level in pairs(values.upgrades or {}) do
					draft.upgrades[UpgradeConfig[upgradeId].profileKey] = level
				end
				for worldId, unlocked in pairs(values.worlds or {}) do
					draft.worlds[worldId] = unlocked
				end
				for resourceId, quantity in pairs(values.resources or {}) do
					draft.inventory.resources[resourceId] = quantity
				end
				return nil
			end)
			assert(result.ok, `préparation : {tostring(result.code)} {tostring(result.message)}`)
		end

		function env.buy(userId: number, upgradeId: any): any
			return env.upgrade.HandleRequest(userId, { upgradeId = upgradeId })
		end

		function env.unlock(userId: number, worldId: any): any
			return env.world.HandleRequest(userId, { worldId = worldId })
		end

		return env
	end

	local function fingerprint(profile: any): string
		local parts = {
			`coins={profile.currencies.coins}`,
			`earned={profile.stats.totalCoinsEarned}`,
			`spent={profile.stats.totalCoinsSpent}`,
		}
		for key, level in pairs(profile.upgrades) do
			table.insert(parts, `{key}={level}`)
		end
		for worldId, unlocked in pairs(profile.worlds) do
			table.insert(parts, `{worldId}={tostring(unlocked)}`)
		end
		table.sort(parts)
		return table.concat(parts, ",")
	end

	local ids = UpgradeMath.ids()

	-- 1-2. ACHAT DE CHAQUE ÉQUIPEMENT, DÉBIT EXACT -------------------------

	case("achat de chaque équipement : niveau + 1 et débit exact", function(check)
		check(#ids == 5, `5 améliorations attendues, trouvé {#ids}`)
		for _, upgradeId in ipairs(ids) do
			local env = newEnv({ USER_A })
			local start = UpgradeConfig[upgradeId].startLevel
			local cost = UpgradeMath.nextCost(upgradeId, start)
			env.set(USER_A, { coins = cost + 7 })
			local result = env.buy(USER_A, upgradeId)
			check(result.ok and result.code == Code.Success, `{upgradeId} : {tostring(result.code)}`)
			check(result.level == start + 1 and result.coinsSpent == cost, `{upgradeId} : résultat incorrect`)
			local profile = env.profile(USER_A)
			check(UpgradeMath.levelOf(profile, upgradeId) == start + 1, `{upgradeId} : niveau non augmenté`)
			check(profile.currencies.coins == 7, `{upgradeId} : solde {profile.currencies.coins} au lieu de 7`)
			check(profile.stats.totalCoinsSpent == cost, `{upgradeId} : totalCoinsSpent incorrect`)
			check(profile.stats.totalCoinsEarned == 0, `{upgradeId} : totalCoinsEarned modifié`)
			check(env.upgraded[1] == `{USER_A}:{upgradeId}:{start + 1}`, `{upgradeId} : onUpgraded non appelé`)
		end
	end)

	case("Magnet démarre à 0 et monte à 1 (D-006, D-015)", function(check)
		local env = newEnv({ USER_A })
		check(env.profile(USER_A).upgrades.magnetLevel == 0, "magnetLevel initial différent de 0")
		check(UpgradeMath.valueAt("Magnet", 0) == 12, "portée au niveau 0 différente de 12")
		check(UpgradeMath.nextCost("Magnet", 0) == 200 and UpgradeMath.valueAt("Magnet", 1) == 14, "niveau 1 : 14 studs pour 200")
		check(UpgradeMath.maxLevel("Magnet") == 9 and UpgradeMath.valueAt("Magnet", 9) == 30, "niveau max 9 à 30 studs")
	end)

	-- 3. FONDS INSUFFISANTS ---------------------------------------------------

	case("refus si fonds insuffisants : rien ne change", function(check)
		for _, upgradeId in ipairs(ids) do
			local env = newEnv({ USER_A })
			local cost = UpgradeMath.nextCost(upgradeId, UpgradeConfig[upgradeId].startLevel)
			env.set(USER_A, { coins = cost - 1 })
			local before = fingerprint(env.profile(USER_A))
			local result = env.buy(USER_A, upgradeId)
			check(not result.ok and result.code == Code.InsufficientFunds, `{upgradeId} : {tostring(result.code)}`)
			check(result.coinsSpent == 0, `{upgradeId} : coinsSpent non nul`)
			check(fingerprint(env.profile(USER_A)) == before, `{upgradeId} : profil modifié`)
			check(#env.upgraded == 0, `{upgradeId} : onUpgraded appelé sur un refus`)
		end
	end)

	-- 4. NIVEAU MAXIMUM ------------------------------------------------------

	case("refus au niveau maximum", function(check)
		for _, upgradeId in ipairs(ids) do
			local env = newEnv({ USER_A })
			local maxLevel = UpgradeMath.maxLevel(upgradeId)
			env.set(USER_A, { coins = 10_000_000, upgrades = { [upgradeId] = maxLevel } })
			local before = fingerprint(env.profile(USER_A))
			local result = env.buy(USER_A, upgradeId)
			check(not result.ok and result.code == Code.MaxLevel, `{upgradeId} : {tostring(result.code)}`)
			check(result.level == maxLevel, `{upgradeId} : niveau renvoyé incorrect`)
			check(fingerprint(env.profile(USER_A)) == before, `{upgradeId} : profil modifié au niveau max`)
		end
	end)

	-- 5. EFFETS RÉELS --------------------------------------------------------

	case("Backpack : capacité augmentée immédiatement, sac conservé", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { coins = 100, resources = { green_leaf = 50 } })
		check(env.inventory.AddResource(USER_A, "green_leaf", 1).code == InventoryService.Code.InventoryFull, "sac de 50 non plein")
		check(env.buy(USER_A, "Backpack").ok, "achat refusé")
		check(env.inventory.GetCapacity(USER_A) == 75, "capacité non mise à jour")
		check(env.profile(USER_A).inventory.resources.green_leaf == 50, "ressources perdues")
		local added = env.inventory.AddResource(USER_A, "green_leaf", 30)
		check(added.ok and added.granted == 25, "nouvelle capacité non appliquée")
	end)

	case("Grabber : intervalle de collecte réduit côté serveur", function(check)
		local nodes = {}
		for index = 1, 4 do
			nodes[`leaf_{index}`] = { X = index, Y = 0, Z = 0 }
		end
		local early = 0.62 -- < 0,75 - 0,1 (niveau 1), >= 0,65 - 0,1 (niveau 3)
		check(early < UpgradeMath.valueAt("Grabber", 1) - CollectionSecurity.Cooldown.jitterToleranceSeconds, "préparation : écart")

		local base = newEnv({ USER_A }, { nodes = nodes })
		check(base.collection.HandleRequest(USER_A, { resourceId = "leaf_1" }).ok, "1re collecte refusée")
		base.now += early
		check(base.collection.HandleRequest(USER_A, { resourceId = "leaf_2" }).code == Code.Cooldown, "niveau 1 : cadence non appliquée")

		local fast = newEnv({ USER_A }, { nodes = nodes })
		fast.set(USER_A, { coins = 550 })
		check(fast.buy(USER_A, "Grabber").ok, "achat niveau 2 refusé")
		check(fast.buy(USER_A, "Grabber").ok, "achat niveau 3 refusé")
		check(fast.collection.GetClientState(USER_A).collectIntervalSeconds == 0.65, "intervalle non mis à jour")
		check(fast.collection.HandleRequest(USER_A, { resourceId = "leaf_1" }).ok, "1re collecte refusée (rapide)")
		fast.now += early
		check(fast.collection.HandleRequest(USER_A, { resourceId = "leaf_2" }).ok, "niveau 3 : intervalle non appliqué")
		fast.now += 0.3
		check(fast.collection.HandleRequest(USER_A, { resourceId = "leaf_3" }).code == Code.Cooldown, "collecte plus rapide que le Grabber acceptée")
	end)

	case("Magnet : portée serveur augmentée, jamais illimitée", function(check)
		local tolerance = CollectionSecurity.Distance.toleranceStuds
		local distance = UpgradeMath.valueAt("Magnet", 0) + tolerance + 1 -- hors portée au niveau 0
		local nodes = { near = { X = distance, Y = 0, Z = 0 }, far = { X = 0, Y = 0, Z = 30 + tolerance + 1 } }

		local base = newEnv({ USER_A }, { nodes = nodes })
		check(base.collection.HandleRequest(USER_A, { resourceId = "near" }).code == Code.TooFar, "niveau 0 : portée dépassée acceptée")

		local env = newEnv({ USER_A }, { nodes = nodes })
		env.set(USER_A, { coins = 200 })
		check(env.buy(USER_A, "Magnet").ok, "achat refusé")
		check(env.collection.GetClientState(USER_A).collectRangeStuds == 14, "portée affichée non mise à jour")
		check(env.collection.HandleRequest(USER_A, { resourceId = "near" }).ok, "niveau 1 : portée non appliquée")

		local maxed = newEnv({ USER_A }, { nodes = nodes })
		maxed.set(USER_A, { upgrades = { Magnet = UpgradeMath.maxLevel("Magnet") } })
		check(maxed.collection.HandleRequest(USER_A, { resourceId = "far" }).code == Code.TooFar, "niveau max : collecte à distance arbitraire")
	end)

	case("Boots : vitesse serveur et contrôle de trajet ajustés", function(check)
		local factor = CollectionSecurity.Travel.speedFactor
		local slack = CollectionSecurity.Travel.slackStuds
		local elapsed = 10
		-- Entre la limite à 16 studs/s et celle à 16,5 studs/s.
		local jump = (16 * factor * elapsed + slack + 16.5 * factor * elapsed + slack) / 2
		local nodes = { first = { X = 1, Y = 0, Z = 0 }, second = { X = jump, Y = 0, Z = 1 } }

		local function run(env: any): string
			check(env.collection.HandleRequest(USER_A, { resourceId = "first" }).ok, "1re collecte refusée")
			env.now += elapsed
			env.positions[USER_A] = { X = jump, Y = 0, Z = 0 }
			return env.collection.HandleRequest(USER_A, { resourceId = "second" }).code
		end

		local base = newEnv({ USER_A }, { nodes = nodes })
		check(base.upgrade.GetWalkSpeed(USER_A) == 16, "vitesse de base différente de 16")
		check(run(base) == Code.TooFar, "niveau 1 : trajet trop long accepté")

		local env = newEnv({ USER_A }, { nodes = nodes })
		env.set(USER_A, { coins = 250 })
		check(env.buy(USER_A, "Boots").ok, "achat refusé")
		check(env.upgrade.GetWalkSpeed(USER_A) == 16.5, "vitesse non mise à jour")
		check(env.collection.GetClientState(USER_A).walkSpeed == 16.5, "vitesse non transmise au client")
		check(run(env) == Code.Success, "niveau 2 : vitesse des Boots ignorée par le contrôle de trajet")
	end)

	case("Multiplier : vente = floor(base × multiplicateur), sans rétroactivité", function(check)
		local env = newEnv({ USER_A })
		local price = ResourceConfig.green_leaf.sellValue
		env.set(USER_A, { coins = 300, resources = { green_leaf = 7 } })
		local first = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE })
		check(first.ok and first.coinsEarned == 7 * price and first.multiplier == 1, "vente x1 incorrecte")
		local earnedBefore = env.profile(USER_A).stats.totalCoinsEarned

		check(env.buy(USER_A, "Multiplier").ok, "achat refusé")
		check(env.profile(USER_A).stats.totalCoinsEarned == earnedBefore, "vente passée modifiée")
		check(env.collection.GetClientState(USER_A).sellMultiplier == 1.05, "multiplicateur non transmis")

		env.set(USER_A, { resources = { green_leaf = 7 } })
		local coinsBefore = env.profile(USER_A).currencies.coins
		local second = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE })
		local expected = math.floor(7 * price * 105 / 100)
		check(second.ok and second.coinsEarned == expected, `vente x1,05 : {second.coinsEarned}, attendu {expected}`)
		check(second.baseValue == 7 * price and second.multiplier == 1.05, "base ou multiplicateur renvoyé incorrect")
		local profile = env.profile(USER_A)
		check(profile.currencies.coins == coinsBefore + expected, "solde incorrect")
		check(profile.stats.totalCoinsEarned == earnedBefore + expected, "totalCoinsEarned incorrect")
	end)

	-- 6. HUD -----------------------------------------------------------------

	case("état client mis à jour après achat", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { coins = 1_000 })
		local before = env.collection.GetClientState(USER_A)
		check(before.upgrades.Backpack == 1 and before.upgrades.Magnet == 0, "niveaux initiaux incorrects")
		check(before.worlds.GreenValley == true and before.worlds.GoldenDesert == nil, "mondes initiaux incorrects")
		check(env.buy(USER_A, "Backpack").ok, "achat refusé")
		local after = env.collection.GetClientState(USER_A)
		check(after.upgrades.Backpack == 2, "niveau non transmis")
		check(after.inventory.capacity == 75, "capacité non transmise")
		check(after.coins == 1_000 - UpgradeConfig.Backpack.levels[2].cost, "solde non transmis")
	end)

	-- 7-8. ACHATS RÉPÉTÉS ET CONCURRENTS -------------------------------------

	case("achats répétés jusqu'au maximum : coût cumulé exact", function(check)
		for _, upgradeId in ipairs(ids) do
			local env = newEnv({ USER_A })
			local maxLevel = UpgradeMath.maxLevel(upgradeId)
			local total = UpgradeMath.cumulativeCost(upgradeId, maxLevel)
			env.set(USER_A, { coins = total })
			local purchases = 0
			for _ = 1, 30 do
				local result = env.buy(USER_A, upgradeId)
				if not result.ok then
					check(result.code == Code.MaxLevel, `{upgradeId} : arrêt sur {tostring(result.code)}`)
					break
				end
				purchases += 1
			end
			local profile = env.profile(USER_A)
			check(purchases == maxLevel - UpgradeConfig[upgradeId].startLevel, `{upgradeId} : {purchases} achat(s)`)
			check(profile.currencies.coins == 0, `{upgradeId} : solde final {profile.currencies.coins}`)
			check(profile.stats.totalCoinsSpent == total, `{upgradeId} : totalCoinsSpent incorrect`)
			check(UpgradeMath.levelOf(profile, upgradeId) == maxLevel, `{upgradeId} : niveau final incorrect`)
		end
	end)

	case("deux achats simultanés : pas de double débit", function(check)
		local env = newEnv({ USER_A })
		-- Coût du niveau 2 + 249 : niveau 3 (250) inaccessible.
		local levelTwoCost = UpgradeConfig.Backpack.levels[2].cost
		env.set(USER_A, { coins = levelTwoCost + 249 })
		local first = env.buy(USER_A, "Backpack")
		local second = env.buy(USER_A, "Backpack")
		check(first.ok and first.level == 2, "premier achat incorrect")
		check(not second.ok and second.code == Code.InsufficientFunds, `second achat : {tostring(second.code)}`)
		local profile = env.profile(USER_A)
		check(profile.currencies.coins == 249 and profile.upgrades.backpackLevel == 2, "débit en double")
		check(profile.stats.totalCoinsSpent == levelTwoCost, "totalCoinsSpent en double")
	end)

	case("deux joueurs simultanés : achats isolés", function(check)
		local env = newEnv({ USER_A, USER_B })
		env.set(USER_A, { coins = 150 })
		env.set(USER_B, { coins = 1_000 })
		check(env.buy(USER_A, "Grabber").ok and env.buy(USER_B, "Backpack").ok, "achats refusés")
		local a, b = env.profile(USER_A), env.profile(USER_B)
		check(a.currencies.coins == 0 and a.upgrades.grabberLevel == 2 and a.upgrades.backpackLevel == 1, "profil A incorrect")
		check(b.currencies.coins == 1_000 - UpgradeConfig.Backpack.levels[2].cost and b.upgrades.backpackLevel == 2 and b.upgrades.grabberLevel == 1, "profil B incorrect")
	end)

	-- 9. STATISTIQUES ET COMPATIBILITÉ T3 ------------------------------------

	case("ventes et achats enchaînés : statistiques cohérentes", function(check)
		local env = newEnv({ USER_A })
		local price = ResourceConfig.stone.sellValue
		local earned, spent = 0, 0
		for _ = 1, 4 do
			env.set(USER_A, { resources = { stone = 40 } })
			local sale = env.sell.HandleRequest(USER_A, { sellZoneId = ZONE })
			check(sale.ok, "vente refusée")
			earned += sale.coinsEarned
			local purchase = env.buy(USER_A, "Multiplier")
			if purchase.ok then
				spent += purchase.coinsSpent
			end
			local profile = env.profile(USER_A)
			check(profile.currencies.coins >= 0, "solde négatif")
			check(profile.currencies.coins == earned - spent, "solde différent de gains - dépenses")
		end
		local profile = env.profile(USER_A)
		check(profile.stats.totalCoinsEarned == earned, "totalCoinsEarned incorrect")
		check(profile.stats.totalCoinsSpent == spent, "totalCoinsSpent incorrect")
		check(profile.stats.totalSales == 4, "totalSales incorrect")
		check(earned > 4 * 40 * price - 1, "gains anormaux")
	end)

	-- 10-11. PERSISTANCE -----------------------------------------------------

	case("niveaux, solde et mondes restaurés après reconnexion", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { coins = 5_000, upgrades = { Backpack = 5 } })
		check(env.buy(USER_A, "Magnet").ok and env.buy(USER_A, "Boots").ok, "achats refusés")
		check(env.unlock(USER_A, "GoldenDesert").ok, "déblocage refusé")
		local expected = fingerprint(env.profile(USER_A))
		check(env.playerData.ReleasePlayer(USER_A).ok, "sauvegarde de sortie en échec")

		local other = newEnv({ USER_A }, { store = env.store })
		local profile = other.profile(USER_A)
		check(fingerprint(profile) == expected, "profil restauré différent")
		check(profile.upgrades.magnetLevel == 1 and profile.upgrades.bootsLevel == 2, "niveaux non restaurés")
		check(profile.worlds.GoldenDesert == true, "monde non restauré")
		check(other.collection.GetClientState(USER_A).collectRangeStuds == 14, "effet non restauré")
	end)

	-- 14. PAYLOADS FALSIFIÉS -------------------------------------------------

	case("payloads falsifiés : prix, niveau, solde, effet ignorés et refusés", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { coins = UpgradeConfig.Backpack.levels[2].cost - 1 })
		local before = fingerprint(env.profile(USER_A))
		local payloads: { any } = {
			{ upgradeId = "Backpack", price = 0 },
			{ upgradeId = "Backpack", level = 16 },
			{ upgradeId = "Backpack", coins = 1_000_000 },
			{ upgradeId = "Backpack", value = 9999 },
			{ upgradeId = "Gems" },
			{ upgradeId = "backpackLevel" },
			{ upgradeId = 1 },
			{ upgradeId = "" },
			{ upgradeId = string.rep("B", Security.Payload.maxIdLength + 1) },
			{ upgradeId = { "Backpack" } },
			{},
			"Backpack",
			123,
			nil,
		}
		for index, payload in ipairs(payloads) do
			local result = env.upgrade.HandleRequest(USER_A, payload)
			check(not result.ok and result.code == Code.InvalidTarget, `payload n°{index} : {tostring(result.code)}`)
		end
		check(env.upgrade.HandleRequest(USER_A, nil).code == Code.InvalidTarget, "payload nil accepté")
		-- Demande honnête avec fonds insuffisants : le prix ne peut pas être imposé.
		check(env.buy(USER_A, "Backpack").code == Code.InsufficientFunds, "prix client accepté")
		check(fingerprint(env.profile(USER_A)) == before, "profil modifié par un payload falsifié")
	end)

	-- Profil en chargement ou libéré --------------------------------------

	case("achat pendant le chargement et après la libération", function(check)
		local env = newEnv({ USER_A })
		check(env.buy(USER_B, "Backpack").code == Code.ProfileNotLoaded, "joueur inconnu : achat accepté")

		local suspended = false
		env.store.setBeforeCall(function(key: string)
			if key == "Player_5002" and not suspended then
				suspended = true
				coroutine.yield()
			end
		end)
		local loader = coroutine.create(function()
			return env.playerData.LoadPlayer(USER_B)
		end)
		coroutine.resume(loader)
		check(suspended and coroutine.status(loader) == "suspended", "chargement non suspendu (préparation)")
		check(env.buy(USER_B, "Backpack").code == Code.ProfileNotLoaded, "achat accepté pendant le chargement")
		check(env.unlock(USER_B, "GoldenDesert").code == Code.ProfileNotLoaded, "déblocage accepté pendant le chargement")
		env.store.setBeforeCall(nil)
		coroutine.resume(loader)

		env.set(USER_A, { coins = 1_000 })
		check(env.playerData.ReleasePlayer(USER_A).ok, "libération en échec")
		check(env.buy(USER_A, "Backpack").code == Code.ProfileNotLoaded, "achat accepté après libération")
		check(env.store.peek("Player_5001").profile.currencies.coins == 1_000, "solde sauvegardé modifié après libération")
	end)

	case("achat pendant la sauvegarde de sortie : refusé, rien perdu", function(check)
		local env = newEnv({ USER_A })
		env.set(USER_A, { coins = 1_000 })
		local suspended = false
		env.store.setBeforeCall(function()
			if not suspended then
				suspended = true
				coroutine.yield()
			end
		end)
		local releaser = coroutine.create(function()
			return env.playerData.ReleasePlayer(USER_A)
		end)
		coroutine.resume(releaser)
		check(coroutine.status(releaser) == "suspended", "libération non suspendue (préparation)")
		check(env.buy(USER_A, "Backpack").code == Code.ProfileNotLoaded, "achat accepté pendant la fermeture")
		env.store.setBeforeCall(nil)
		coroutine.resume(releaser)
		local stored = env.store.peek("Player_5001").profile
		check(stored.currencies.coins == 1_000 and stored.upgrades.backpackLevel == 1, "profil sauvegardé incohérent")
	end)

	-- Limite de fréquence ---------------------------------------------------

	case("rafale d'achats : limite de fréquence", function(check)
		local env = newEnv({ USER_A }, { limited = true })
		env.set(USER_A, { coins = 10_000_000 })
		local burst = Security.RateLimits.Upgrade.burst
		local successes, limited, silent = 0, 0, 0
		for _ = 1, 50 do
			local result = env.buy(USER_A, "Backpack")
			if result.ok then
				successes += 1
			elseif result.code == Code.RateLimited then
				limited += 1
				if result.silent then
					silent += 1
				end
			end
		end
		check(successes == burst, `{successes} achat(s) au lieu de {burst}`)
		check(limited == 50 - burst and silent == limited - 1, "une seule réponse RATE_LIMITED non silencieuse attendue")
		check(env.profile(USER_A).upgrades.backpackLevel == 1 + burst, "niveau incohérent")
	end)

	-- 12-13. DÉBLOCAGE DES MONDES ---------------------------------------------

	case("déblocage autorisé : Golden Desert", function(check)
		local world = WorldConfig.GoldenDesert
		local env = newEnv({ USER_A })
		env.set(USER_A, { coins = world.unlockCost + 3, upgrades = { Backpack = world.requiredBackpackLevel } })
		local result = env.unlock(USER_A, "GoldenDesert")
		check(result.ok and result.coinsSpent == world.unlockCost, `code {tostring(result.code)}`)
		local profile = env.profile(USER_A)
		check(profile.worlds.GoldenDesert == true, "monde non débloqué")
		check(profile.currencies.coins == 3, "débit incorrect")
		check(profile.stats.totalCoinsSpent == world.unlockCost, "totalCoinsSpent incorrect")
		check(env.collection.GetClientState(USER_A).worlds.GoldenDesert == true, "état client non mis à jour")
		-- Second déblocage : aucun nouveau débit.
		local again = env.unlock(USER_A, "GoldenDesert")
		check(not again.ok and again.code == Code.AlreadyUnlocked, "double déblocage accepté")
		check(env.profile(USER_A).currencies.coins == 3, "double débit")
	end)

	case("déblocage refusé : niveau, fonds, ordre, déjà débloqué, inconnu", function(check)
		local desert = WorldConfig.GoldenDesert
		local function attempt(values: any, worldId: any): (any, boolean)
			local env = newEnv({ USER_A })
			env.set(USER_A, values)
			local before = fingerprint(env.profile(USER_A))
			local result = env.unlock(USER_A, worldId)
			return result, fingerprint(env.profile(USER_A)) == before
		end

		local result, unchanged = attempt({ coins = 1_000_000, upgrades = { Backpack = desert.requiredBackpackLevel - 1 } }, "GoldenDesert")
		check(result.code == Code.RequirementNotMet and unchanged, `Backpack insuffisant : {tostring(result.code)}`)

		result, unchanged = attempt({ coins = desert.unlockCost - 1, upgrades = { Backpack = desert.requiredBackpackLevel } }, "GoldenDesert")
		check(result.code == Code.InsufficientFunds and unchanged, `fonds insuffisants : {tostring(result.code)}`)

		result, unchanged = attempt({ coins = 1_000_000, upgrades = { Backpack = 16 } }, "FrozenPeaks")
		check(result.code == Code.RequirementNotMet and unchanged, `monde précédent verrouillé : {tostring(result.code)}`)

		result, unchanged = attempt({ coins = 1_000_000, upgrades = { Backpack = 16 }, worlds = { GoldenDesert = true } }, "MysticWorld")
		check(result.code == Code.RequirementNotMet and unchanged, `saut de monde : {tostring(result.code)}`)

		result, unchanged = attempt({ coins = 0 }, "GreenValley")
		check(result.code == Code.AlreadyUnlocked and unchanged, `monde de départ : {tostring(result.code)}`)

		local invalidWorlds: { any } = { "Atlantis", "", 42, string.rep("W", 100) }
		for _, worldId in ipairs(invalidWorlds) do
			result, unchanged = attempt({ coins = 1_000_000, upgrades = { Backpack = 16 } }, worldId)
			check(result.code == Code.InvalidTarget and unchanged, `monde {tostring(worldId)} : {tostring(result.code)}`)
		end

		local env = newEnv({ USER_A })
		env.set(USER_A, { coins = 1_000_000, upgrades = { Backpack = 16 } })
		local forged = env.world.HandleRequest(USER_A, { worldId = "GoldenDesert", cost = 0 })
		check(forged.code == Code.InvalidTarget, "champ supplémentaire accepté")
	end)

	case("progression complète des quatre mondes dans l'ordre", function(check)
		local env = newEnv({ USER_A })
		local total = 0
		for _, worldId in ipairs({ "GoldenDesert", "FrozenPeaks", "MysticWorld" }) do
			total += WorldConfig[worldId].unlockCost
		end
		env.set(USER_A, { coins = total, upgrades = { Backpack = 16 } })
		for _, worldId in ipairs({ "GoldenDesert", "FrozenPeaks", "MysticWorld" }) do
			local result = env.unlock(USER_A, worldId)
			check(result.ok and result.coinsSpent == WorldConfig[worldId].unlockCost, `{worldId} : {tostring(result.code)}`)
		end
		local profile = env.profile(USER_A)
		check(profile.currencies.coins == 0 and profile.stats.totalCoinsSpent == total, "débits incorrects")
		for worldId in pairs(WorldConfig) do
			check(profile.worlds[worldId] == true, `{worldId} non débloqué`)
		end
	end)

	-- Préréglages des tests manuels (outil Studio) ----------------------

	case("préréglages U1–U9 : profils valides et scénarios attendus", function(check)
		local Presets = modules.StudioTestPresets
		for _, name in ipairs(Presets.names()) do
			local env = newEnv({ USER_A })
			env.set(USER_A, { coins = 77, resources = { stone = 4 } })
			local ok, reason = Presets.apply(env.playerData, USER_A, name)
			check(ok, `{name} : {tostring(reason)}`)
			local preset = Presets.Presets[name]
			local profile = env.profile(USER_A)
			check(profile.currencies.coins == preset.coins, `{name} : solde incorrect`)
			-- Statistiques remises à zéro, sauf celles fixées par le préréglage (T5.3).
			for statId, value in pairs(profile.stats) do
				local expected = if preset.stats then preset.stats[statId] or 0 else 0
				check(value == expected, `{name} : statistique {statId} = {tostring(value)} au lieu de {expected}`)
			end
			if preset.resources == nil then
				check(next(profile.inventory.resources) == nil, `{name} : sac non vidé`)
			end
		end

		local function scenario(name: string, run: (env: any) -> any): any
			local env = newEnv({ USER_A })
			assert(Presets.apply(env.playerData, USER_A, name))
			return run(env)
		end
		for name, upgradeId in pairs({ U1 = "Backpack", U2 = "Grabber", U3 = "Magnet", U4 = "Boots", U5 = "Multiplier" }) do
			local result = scenario(name, function(env: any): any
				return env.buy(USER_A, upgradeId)
			end)
			check(result.ok, `{name} : achat {upgradeId} refusé ({tostring(result.code)})`)
		end
		for _, upgradeId in ipairs(ids) do
			local result = scenario("U6", function(env: any): any
				return env.buy(USER_A, upgradeId)
			end)
			check(result.code == Code.InsufficientFunds, `U6 : {upgradeId} payable`)
		end
		check(scenario("U7_locked", function(env: any): any
			return env.unlock(USER_A, "GoldenDesert")
		end).code == Code.RequirementNotMet, "U7_locked : déblocage accepté")
		check(scenario("U7_ready", function(env: any): any
			return env.unlock(USER_A, "GoldenDesert")
		end).ok, "U7_ready : déblocage refusé")
		local u9 = scenario("U9", function(env: any): any
			return { grabber = env.buy(USER_A, "Grabber").code, backpack = env.buy(USER_A, "Backpack").code }
		end)
		check(u9.grabber == Code.MaxLevel and u9.backpack == Code.InsufficientFunds, "U9 : états inattendus")

		local env = newEnv({ USER_A })
		check(not Presets.apply(env.playerData, USER_A, "inconnu"), "préréglage inconnu accepté")
		check(not Presets.apply(env.playerData, USER_B, "U1"), "profil non chargé accepté")
	end)

	return failures, caseCount
end

return UpgradeServiceTests
