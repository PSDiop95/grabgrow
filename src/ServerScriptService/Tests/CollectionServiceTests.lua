--!strict
-- Tests de CollectionService avec de vrais services (PlayerDataService,
-- InventoryService, ResourceSpawner, RateLimitService), un magasin en
-- mémoire, une horloge et une minuterie simulées, et des positions de
-- personnage fixées par le test. Aucune API Roblox.
--
-- Plusieurs joueurs = plusieurs UserId sur le même service, comme sur un
-- serveur réel.

local CollectionServiceTests = {}

export type Modules = {
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
	Remotes: any,
}

local USER_A = 3001
local USER_B = 3002
local KEY_A = "Player_3001"

local LEAF = "green_leaf_001"
local LEAF_2 = "green_leaf_002"
local WOOD = "wood_001"
local STONE_FAR = "stone_001"

-- Retourne (liste des échecs, nombre de cas exécutés).
function CollectionServiceTests.run(modules: Modules): ({ string }, number)
	local CollectionService = modules.CollectionService
	local InventoryService = modules.InventoryService
	local PlayerDataService = modules.PlayerDataService
	local RateLimitService = modules.RateLimitService
	local ResourceSpawner = modules.ResourceSpawner
	local MemoryDataStore = modules.MemoryDataStore
	local DataSchema = modules.DataSchema
	local ResourceConfig = modules.ResourceConfig
	local UpgradeConfig = modules.UpgradeConfig
	local Security = modules.CollectionSecurityConfig
	local Code = modules.Remotes.ResultCode
	local NodeState = ResourceSpawner.State

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

	local interval = UpgradeConfig.Grabber.levels[1].value
	local jitter = Security.Cooldown.jitterToleranceSeconds
	local maxDistance = UpgradeConfig.Magnet.levels[1].value + Security.Distance.toleranceStuds
	local baseCapacity = UpgradeConfig.Backpack.levels[1].value
	local burst = Security.RateLimits.Collect.burst

	-- Un serveur : nœuds LEAF (0,0,0), LEAF_2 (4,0,0), WOOD (0,0,5),
	-- STONE_FAR (300,0,0). Joueurs chargés selon `userIds`.
	-- Options : `prepare` modifie le profil stocké du joueur A avant son
	-- chargement ; `store` réutilise un magasin ; `unlimited` retire la
	-- limite de fréquence (pour observer la cadence seule).
	local function newEnv(
		userIds: { number },
		options: { prepare: ((profile: any) -> ())?, store: any?, unlimited: boolean? }?
	)
		local prepare = if options then options.prepare else nil
		local env = {
			now = 500,
			store = (if options then options.store else nil) or MemoryDataStore.new(),
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

		if prepare then
			local profile = DataSchema.newProfile()
			prepare(profile)
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
		env.rateLimit = RateLimitService.new({
			clock = clock,
			limits = Security.RateLimits,
			logEveryRejections = Security.RateLimitFeedback.logEveryRejections,
			log = log,
		})
		env.collection = CollectionService.new({
			playerData = env.playerData,
			inventory = env.inventory,
			spawner = env.spawner,
			rateLimit = if options and options.unlimited
				then {
					Allow = function(): boolean
						return true
					end,
					Clear = function() end,
				}
				else env.rateLimit,
			clock = clock,
			getCharacterPosition = function(userId: number): any
				return env.positions[userId]
			end,
			log = log,
		})

		env.spawner.Register(LEAF, "green_leaf", { X = 0, Y = 0, Z = 0 })
		env.spawner.Register(LEAF_2, "green_leaf", { X = 4, Y = 0, Z = 0 })
		env.spawner.Register(WOOD, "wood", { X = 0, Y = 0, Z = 5 })
		env.spawner.Register(STONE_FAR, "stone", { X = 300, Y = 0, Z = 0 })

		for _, userId in ipairs(userIds) do
			assert(env.playerData.LoadPlayer(userId).ok, "chargement du joueur de test")
			env.positions[userId] = { X = 1, Y = 0, Z = 1 }
		end

		function env.advance(seconds: number)
			env.now += seconds
			local remaining = {}
			local due = {}
			for _, timer in ipairs(env.timers) do
				table.insert(if timer.at <= env.now + 1e-9 then due else remaining, timer)
			end
			env.timers = remaining
			for _, timer in ipairs(due) do
				timer.callback()
			end
		end

		function env.collect(userId: number, nodeId: string): any
			return env.collection.HandleRequest(userId, { resourceId = nodeId })
		end

		function env.used(userId: number): number
			return env.inventory.GetState(userId).used
		end

		function env.nodeState(nodeId: string): string
			return env.spawner.GetNode(nodeId).state
		end

		return env
	end

	-- COLLECTE VALIDE --------------------------------------------------------

	case("collecte valide", function(check)
		local env = newEnv({ USER_A })
		local result = env.collect(USER_A, LEAF)
		check(result.ok and result.code == Code.Success, `code {tostring(result.code)}`)
		check(result.resourceId == LEAF and result.resourceType == "green_leaf", "ressource du résultat incorrecte")
		check(result.amount == ResourceConfig.green_leaf.collectAmount, `amount = {result.amount}`)
		check(not result.silent, "résultat silencieux")
		local profile = env.playerData.GetData(USER_A)
		check(profile.inventory.resources.green_leaf == ResourceConfig.green_leaf.collectAmount, "inventaire non crédité")
		check(profile.stats.totalResourcesCollected == ResourceConfig.green_leaf.collectAmount, "statistique incorrecte")
		check(profile.currencies.coins == 0, "des Coins ont été crédités à la collecte")
		check(env.nodeState(LEAF) == NodeState.Respawning, "nœud non consommé")
		check(env.store.getWriteCount() == 1, "une collecte a déclenché une écriture DataStore")
	end)

	case("les trois ressources sont collectables", function(check)
		local env = newEnv({ USER_A })
		env.positions[USER_A] = { X = 0, Y = 0, Z = 2 }
		check(env.collect(USER_A, LEAF).ok, "feuille refusée")
		env.advance(interval)
		check(env.collect(USER_A, WOOD).ok, "bois refusé")
		env.advance(60)
		env.positions[USER_A] = { X = 300, Y = 0, Z = 2 }
		check(env.collect(USER_A, STONE_FAR).ok, "pierre refusée")
		local resources = env.inventory.GetState(USER_A).resources
		check(resources.green_leaf == 1 and resources.wood == 1 and resources.stone == 1, "inventaire incomplet")
	end)

	-- REFUS ------------------------------------------------------------------

	case("ressource inexistante", function(check)
		local env = newEnv({ USER_A })
		local result = env.collect(USER_A, "green_leaf_999")
		check(not result.ok and result.code == Code.InvalidTarget, `code {tostring(result.code)}`)
		-- Un type de ressource n'est pas un identifiant de nœud.
		check(env.collect(USER_A, "green_leaf").code == Code.InvalidTarget, "type accepté comme identifiant")
		check(env.used(USER_A) == 0, "inventaire crédité")
	end)

	case("payload invalide ou falsifié", function(check)
		local env = newEnv({ USER_A })
		local payloads: { any } = {
			"green_leaf_001",
			42,
			true,
			{},
			{ resourceId = 42 },
			{ resourceId = "" },
			{ resourceId = string.rep("a", Security.Payload.maxResourceIdLength + 1) },
			{ LEAF },
		}
		for index, payload in ipairs(payloads) do
			local result = env.collection.HandleRequest(USER_A, payload)
			check(not result.ok and result.code == Code.InvalidTarget, `payload {index} : code {tostring(result.code)}`)
		end
		check(env.collection.HandleRequest(USER_A, nil).code == Code.InvalidTarget, "payload absent accepté")
		env.advance(10)

		-- Champs supplémentaires : la demande entière est refusée.
		local forged: { any } = {
			{ resourceId = LEAF, amount = 999 },
			{ resourceId = LEAF, reward = 999, coins = 1_000_000 },
			{ resourceId = LEAF, capacity = 99_999 },
			{ resourceId = LEAF, cooldown = 0, multiplier = 50 },
		}
		for index, payload in ipairs(forged) do
			local result = env.collection.HandleRequest(USER_A, payload)
			check(result.code == Code.InvalidTarget, `falsification {index} : code {tostring(result.code)}`)
		end
		local profile = env.playerData.GetData(USER_A)
		check(next(profile.inventory.resources) == nil, "inventaire crédité par un payload invalide")
		check(profile.currencies.coins == 0, "Coins modifiés")
		check(env.nodeState(LEAF) == NodeState.Active, "nœud consommé par un payload invalide")
	end)

	case("ressource inactive", function(check)
		local env = newEnv({ USER_A, USER_B })
		check(env.collect(USER_A, LEAF).ok, "première collecte refusée")
		local result = env.collect(USER_B, LEAF)
		check(not result.ok and result.code == Code.ResourceUnavailable, `code {tostring(result.code)}`)
		check(env.used(USER_B) == 0, "ressource créditée deux fois")
	end)

	case("joueur trop éloigné", function(check)
		local env = newEnv({ USER_A })
		env.positions[USER_A] = { X = maxDistance + 0.5, Y = 0, Z = 0 }
		local result = env.collect(USER_A, LEAF)
		check(not result.ok and result.code == Code.TooFar, `code {tostring(result.code)}`)
		check(env.nodeState(LEAF) == NodeState.Active, "nœud consommé à distance")
		check(env.used(USER_A) == 0, "inventaire crédité à distance")

		-- La hauteur compte aussi.
		env.positions[USER_A] = { X = 0, Y = maxDistance + 0.5, Z = 0 }
		check(env.collect(USER_A, LEAF).code == Code.TooFar, "collecte acceptée depuis trop haut")

		env.positions[USER_A] = { X = maxDistance - 0.5, Y = 0, Z = 0 }
		check(env.collect(USER_A, LEAF).ok, "collecte refusée à portée")
	end)

	case("personnage absent ou mort", function(check)
		local env = newEnv({ USER_A })
		env.positions[USER_A] = nil
		local result = env.collect(USER_A, LEAF)
		check(not result.ok and result.code == Code.NoCharacter, `code {tostring(result.code)}`)
		check(env.nodeState(LEAF) == NodeState.Active, "nœud consommé sans personnage")
	end)

	case("cooldown non respecté", function(check)
		local env = newEnv({ USER_A })
		check(env.collect(USER_A, LEAF).ok, "première collecte refusée")
		local result = env.collect(USER_A, WOOD)
		check(not result.ok and result.code == Code.Cooldown, `code {tostring(result.code)}`)
		check(env.nodeState(WOOD) == NodeState.Active, "nœud consommé pendant le cooldown")

		env.advance(interval - jitter - 0.05)
		check(env.collect(USER_A, WOOD).code == Code.Cooldown, "collecte acceptée trop tôt")
		env.advance(jitter + 0.05)
		check(env.collect(USER_A, WOOD).ok, "collecte refusée après l'intervalle")
		check(env.used(USER_A) == 2, "inventaire incorrect")
	end)

	case("cooldown : la tolérance de gigue ne permet pas de dépasser la cadence", function(check)
		local env = newEnv({ USER_A }, { unlimited = true })
		-- Assez de nœuds pour que la réapparition ne limite jamais la cadence.
		local nodes = { LEAF, LEAF_2, WOOD }
		for index = 1, 8 do
			local nodeId = `green_leaf_1{index}`
			env.spawner.Register(nodeId, "green_leaf", { X = index % 3, Y = 0, Z = 2 })
			table.insert(nodes, nodeId)
		end
		local startedAt = env.now
		local successes = 0
		-- 20 s d'une demande toutes les 50 ms, sur le premier nœud disponible.
		for _ = 1, 400 do
			for _, nodeId in ipairs(nodes) do
				if env.nodeState(nodeId) == NodeState.Active then
					if env.collect(USER_A, nodeId).ok then
						successes += 1
					end
					break
				end
			end
			env.advance(0.05)
		end
		local elapsed = env.now - startedAt
		local nominalMax = math.floor((elapsed + jitter) / interval) + 1
		check(successes <= nominalMax, `{successes} collectes en {elapsed} s (maximum nominal {nominalMax})`)
		check(successes >= nominalMax - 3, `cadence trop basse : {successes} pour {nominalMax}`)
	end)

	case("sac plein", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile)
				profile.inventory.resources.wood = baseCapacity
			end,
		})
		local result = env.collect(USER_A, LEAF)
		check(not result.ok and result.code == Code.InventoryFull, `code {tostring(result.code)}`)
		check(env.nodeState(LEAF) == NodeState.Active, "ressource consommée alors que le sac est plein")
		check(env.used(USER_A) == baseCapacity, "capacité dépassée")
		check(env.inventory.GetState(USER_A).resources.green_leaf == nil, "ressource ajoutée")
	end)

	case("sac presque plein : la dernière place puis refus", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile)
				profile.inventory.resources.stone = baseCapacity - 1
			end,
		})
		check(env.collect(USER_A, LEAF).ok, "dernière place refusée")
		env.advance(interval)
		check(env.collect(USER_A, WOOD).code == Code.InventoryFull, "collecte acceptée au-delà de la capacité")
		check(env.used(USER_A) == baseCapacity, "capacité dépassée")
	end)

	case("profil non chargé", function(check)
		local env = newEnv({})
		env.positions[USER_A] = { X = 0, Y = 0, Z = 0 }
		local result = env.collect(USER_A, LEAF)
		check(not result.ok and result.code == Code.ProfileNotLoaded, `code {tostring(result.code)}`)
		check(env.nodeState(LEAF) == NodeState.Active, "nœud consommé sans profil")
		check(env.collection.GetClientState(USER_A) == nil, "état client fourni sans profil")
	end)

	-- MULTIJOUEUR ------------------------------------------------------------

	case("deux joueurs ciblant la même ressource", function(check)
		local env = newEnv({ USER_A, USER_B })
		local first = env.collect(USER_A, LEAF)
		local second = env.collect(USER_B, LEAF)
		check(first.ok, "premier joueur refusé")
		check(not second.ok and second.code == Code.ResourceUnavailable, `second : code {tostring(second.code)}`)
		check(env.used(USER_A) + env.used(USER_B) == ResourceConfig.green_leaf.collectAmount, "ressource dupliquée")
	end)

	case("deux joueurs, ressources différentes, inventaires indépendants", function(check)
		local env = newEnv({ USER_A, USER_B })
		check(env.collect(USER_A, LEAF).ok, "A refusé")
		check(env.collect(USER_B, WOOD).ok, "B refusé : le cooldown de A ne doit pas s'appliquer à B")
		local a = env.inventory.GetState(USER_A).resources
		local b = env.inventory.GetState(USER_B).resources
		check(a.green_leaf == 1 and a.wood == nil, "inventaire de A incorrect")
		check(b.wood == 1 and b.green_leaf == nil, "inventaire de B incorrect")
		-- Le cooldown de B ne bloque pas A une fois le sien écoulé.
		env.advance(interval)
		check(env.collect(USER_A, LEAF_2).ok, "A bloqué après son intervalle")
	end)

	-- RÉAPPARITION -----------------------------------------------------------

	case("réapparition après délai", function(check)
		local env = newEnv({ USER_A, USER_B })
		local respawn = ResourceConfig.green_leaf.respawnSeconds
		check(env.collect(USER_A, LEAF).ok, "collecte refusée")
		env.advance(respawn - 0.1)
		check(env.collect(USER_B, LEAF).code == Code.ResourceUnavailable, "collectable avant la réapparition")
		env.advance(0.1)
		check(env.nodeState(LEAF) == NodeState.Active, "nœud non réapparu")
		check(env.collect(USER_B, LEAF).ok, "non collectable après réapparition")
		check(env.used(USER_A) == 1 and env.used(USER_B) == 1, "inventaires incorrects")
	end)

	-- ANTI-EXPLOIT -----------------------------------------------------------

	case("rejeu de RemoteEvent", function(check)
		local env = newEnv({ USER_A })
		local counts: { [string]: number } = {}
		local answered = 0
		for _ = 1, 200 do
			local result = env.collect(USER_A, LEAF)
			counts[result.code] = (counts[result.code] or 0) + 1
			if not result.silent then
				answered += 1
			end
		end
		check(counts[Code.Success] == 1, `{tostring(counts[Code.Success])} succès`)
		check(counts[Code.RateLimited] == 200 - burst, `{tostring(counts[Code.RateLimited])} demandes limitées`)
		check(answered == burst + 1, `{answered} réponses envoyées (attendu : {burst + 1})`)
		check(env.used(USER_A) == 1, "ressource créditée plusieurs fois")

		-- Pas de sanction durable : la collecte reprend après une pause.
		env.advance(5)
		check(env.collect(USER_A, WOOD).ok, "joueur toujours bloqué après la rafale")
	end)

	case("rejeu : un joueur limité ne gêne pas les autres", function(check)
		local env = newEnv({ USER_A, USER_B })
		for _ = 1, 100 do
			env.collect(USER_A, "green_leaf_999")
		end
		check(env.collect(USER_B, LEAF).ok, "B limité par le rejeu de A")
	end)

	case("déplacement implausible entre deux collectes", function(check)
		local env = newEnv({ USER_A })
		check(env.collect(USER_A, LEAF).ok, "première collecte refusée")
		-- Une seconde plus tard, à 300 studs : téléportation.
		env.advance(1)
		env.positions[USER_A] = { X = 300, Y = 0, Z = 1 }
		local result = env.collect(USER_A, STONE_FAR)
		check(not result.ok and result.code == Code.TooFar, `code {tostring(result.code)}`)
		check(env.nodeState(STONE_FAR) == NodeState.Active, "nœud consommé après téléportation")
		check(#env.logs == 1, `{#env.logs} ligne(s) de journal`)

		-- Le temps de faire le trajet à pied : accepté.
		local speed = UpgradeConfig.Boots.levels[1].value * Security.Travel.speedFactor
		env.advance(300 / speed)
		check(env.collect(USER_A, STONE_FAR).ok, "collecte refusée après un trajet plausible")
	end)

	case("réapparition du personnage : trajet de référence oublié", function(check)
		local env = newEnv({ USER_A })
		check(env.collect(USER_A, LEAF).ok, "première collecte refusée")
		env.advance(1)
		env.positions[USER_A] = { X = 300, Y = 0, Z = 1 }
		env.collection.ResetTravelReference(USER_A)
		check(env.collect(USER_A, STONE_FAR).ok, "collecte refusée après réapparition")
	end)

	-- ÉTAT CLIENT ET PERSISTANCE ---------------------------------------------

	case("état client : valeurs des configurations, sans marge de sécurité", function(check)
		local env = newEnv({ USER_A })
		env.collect(USER_A, LEAF)
		local state = env.collection.GetClientState(USER_A)
		check(state ~= nil, "état absent")
		check(state.inventory.used == 1 and state.inventory.capacity == baseCapacity, "inventaire incorrect")
		check(state.collectIntervalSeconds == interval, "intervalle incorrect")
		check(state.collectRangeStuds == UpgradeConfig.Magnet.levels[1].value, "portée incorrecte")
	end)

	case("départ du joueur : état de collecte nettoyé", function(check)
		local env = newEnv({ USER_A })
		for _ = 1, 50 do
			env.collect(USER_A, "green_leaf_999")
		end
		check(env.rateLimit.GetRejectedCount(USER_A, CollectionService.RATE_LIMIT_ACTION) > 0, "aucun rejet enregistré")
		env.collection.RemovePlayer(USER_A)
		check(env.rateLimit.GetRejectedCount(USER_A, CollectionService.RATE_LIMIT_ACTION) == 0, "limite non nettoyée")
	end)

	case("inventaire restauré après reconnexion", function(check)
		local env = newEnv({ USER_A })
		check(env.collect(USER_A, LEAF).ok, "feuille refusée")
		env.advance(interval)
		check(env.collect(USER_A, WOOD).ok, "bois refusé")
		env.collection.RemovePlayer(USER_A)
		check(env.playerData.ReleasePlayer(USER_A).ok, "sauvegarde de sortie en échec")
		check(env.collect(USER_A, LEAF_2).code == Code.ProfileNotLoaded, "collecte acceptée après le départ")

		local other = newEnv({ USER_A }, { store = env.store })
		local resources = other.inventory.GetState(USER_A).resources
		check(resources.green_leaf == 1 and resources.wood == 1, "inventaire non restauré")
		check(other.playerData.GetData(USER_A).stats.totalResourcesCollected == 2, "statistique non restaurée")
	end)

	return failures, caseCount
end

return CollectionServiceTests
