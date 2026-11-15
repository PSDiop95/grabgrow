--!strict
-- Tests de WorldTravelService (T8, D-021) avec de vrais services
-- (PlayerDataService, RateLimitService), un magasin en mémoire, une horloge
-- simulée, une carte (points d'arrivée) et un déplacement simulés. Aucune
-- API Roblox.
--
-- Le dernier groupe enchaîne voyage et collecte avec CollectionService et
-- MovementValidator, branchés comme dans Bootstrap : un voyage légitime ne
-- doit déclencher aucun faux positif, et ne doit pas permettre de collecter
-- ailleurs qu'au point d'arrivée.

local WorldTravelServiceTests = {}

export type Modules = {
	WorldTravelService: any,
	CollectionService: any,
	InventoryService: any,
	PlayerDataService: any,
	RateLimitService: any,
	ResourceSpawner: any,
	MovementValidator: any,
	MemoryDataStore: any,
	DataSchema: any,
	UpgradeConfig: any,
	TravelSecurityConfig: any,
	MovementSecurityConfig: any,
	CollectionSecurityConfig: any,
	SecurityLog: any,
	Remotes: any,
}

local USER_A = 8001
local USER_B = 8002
local KEY_A = "Player_8001"

local DESERT_ARRIVAL = { X = 5000, Y = 3, Z = 0 }
local VALLEY_ARRIVAL = { X = 0, Y = 3, Z = 10 }

-- Retourne (liste des échecs, nombre de cas exécutés).
function WorldTravelServiceTests.run(modules: Modules): ({ string }, number)
	local WorldTravelService = modules.WorldTravelService
	local CollectionService = modules.CollectionService
	local InventoryService = modules.InventoryService
	local PlayerDataService = modules.PlayerDataService
	local RateLimitService = modules.RateLimitService
	local ResourceSpawner = modules.ResourceSpawner
	local MovementValidator = modules.MovementValidator
	local MemoryDataStore = modules.MemoryDataStore
	local DataSchema = modules.DataSchema
	local UpgradeConfig = modules.UpgradeConfig
	local Security = modules.TravelSecurityConfig
	local MovementConfig = modules.MovementSecurityConfig
	local CollectionSecurity = modules.CollectionSecurityConfig
	local Event = modules.SecurityLog.Type
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

	local burst = Security.RateLimits.Travel.burst
	local refillSeconds = 1 / Security.RateLimits.Travel.refillPerSecond
	local interval = UpgradeConfig.Grabber.levels[1].value
	local walkSpeed = UpgradeConfig.Boots.levels[1].value

	-- Un serveur, joueurs chargés selon `userIds`. Options : `prepare`
	-- modifie le profil stocké du joueur A avant son chargement ; `arrivals`
	-- remplace les points d'arrivée de la carte ; `alive = false` simule un
	-- personnage absent (modifiable ensuite : `env.alive`) ; `store` réutilise
	-- le magasin d'un autre serveur (reconnexion).
	local function newEnv(
		userIds: { number },
		options: {
			prepare: ((profile: any) -> ())?,
			arrivals: { [string]: any }?,
			alive: boolean?,
			store: any?,
		}?
	)
		local env = {
			now = 100,
			store = (if options then options.store else nil) or MemoryDataStore.new(),
			positions = {} :: { [number]: any },
			teleports = {} :: { { userId: number, position: any } },
			events = {} :: { { userId: number, eventType: string, fields: any } },
			logs = {} :: { string },
			arrivals = (if options then options.arrivals else nil)
				or { GoldenDesert = DESERT_ARRIVAL, GreenValley = VALLEY_ARRIVAL },
		}
		env.alive = not (options and options.alive == false)
		local function clock(): number
			return env.now
		end
		local function log(level: string, message: string)
			table.insert(env.logs, `{level} {message}`)
		end
		local security = {
			Record = function(userId: number, eventType: string, fields: any)
				table.insert(env.events, { userId = userId, eventType = eventType, fields = fields })
			end,
		}

		local prepare = if options then options.prepare else nil
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

		-- Déplacement et contrôles branchés comme dans Bootstrap.
		env.validator = MovementValidator.new(MovementConfig)
		env.spawner = ResourceSpawner.new({ schedule = function() end })
		env.collection = CollectionService.new({
			playerData = env.playerData,
			inventory = InventoryService.new({ playerData = env.playerData }),
			spawner = env.spawner,
			rateLimit = {
				Allow = function(): boolean
					return true
				end,
				Clear = function() end,
			},
			clock = clock,
			getCharacterPosition = function(userId: number): any
				return env.positions[userId]
			end,
			movement = env.validator,
			log = log,
		})
		env.travel = WorldTravelService.new({
			playerData = env.playerData,
			rateLimit = RateLimitService.new({
				clock = clock,
				limits = Security.RateLimits,
				logEveryRejections = Security.RateLimitFeedback.logEveryRejections,
				log = log,
			}),
			clock = clock,
			getArrival = function(worldId: string): any
				return env.arrivals[worldId]
			end,
			teleport = function(userId: number, position: any): boolean
				if not env.alive then
					return false
				end
				table.insert(env.teleports, { userId = userId, position = position })
				env.positions[userId] = { X = position.X, Y = position.Y, Z = position.Z }
				env.validator.Reset(userId, position, env.now, MovementConfig.ServerTeleport.graceSeconds)
				env.collection.ResetTravelReference(userId, position)
				return true
			end,
			security = security,
			log = log,
		})

		for _, userId in ipairs(userIds) do
			assert(env.playerData.LoadPlayer(userId).ok, "chargement du joueur de test")
			local spawn = { X = 1, Y = 0, Z = 1 }
			env.positions[userId] = spawn
			env.validator.SetSpeed(userId, walkSpeed)
			env.validator.Reset(userId, spawn, env.now)
			env.collection.ResetTravelReference(userId, spawn)
		end

		function env.request(userId: number, payload: any, extra: number?): any
			return env.travel.HandleRequest(userId, payload, extra or 0)
		end

		function env.hasEvent(eventType: string): boolean
			for _, event in ipairs(env.events) do
				if event.eventType == eventType then
					return true
				end
			end
			return false
		end

		-- Échantillons serveur à 4 Hz pendant `seconds`, position inchangée.
		function env.idle(seconds: number): number
			local anomalies = 0
			local dt = MovementConfig.Sampling.intervalSeconds
			for _ = 1, math.floor(seconds / dt + 0.5) do
				env.now += dt
				for userId, position in pairs(env.positions) do
					local verdict = env.validator.Observe(userId, position, env.now)
					if verdict.status == "anomaly" or verdict.status == "correct" then
						anomalies += 1
					end
				end
			end
			return anomalies
		end

		return env
	end

	local function unlockDesert(profile: any)
		profile.worlds.GoldenDesert = true
	end

	-- VOYAGE VALIDE -----------------------------------------------------------

	case("voyage vers un monde débloqué : déplacement au point d'arrivée", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert })
		local writes = env.store.getWriteCount()
		local coins = env.playerData.GetData(USER_A).currencies.coins
		local result = env.request(USER_A, { worldId = "GoldenDesert" })
		check(result.ok and result.code == Code.Success, `code {tostring(result.code)}`)
		check(result.worldId == "GoldenDesert" and not result.silent, "résultat incorrect")
		check(#env.teleports == 1, `{#env.teleports} déplacement(s)`)
		local target = env.teleports[1] and env.teleports[1].position
		check(target ~= nil and target.X == DESERT_ARRIVAL.X and target.Z == DESERT_ARRIVAL.Z, "destination différente du point d'arrivée")
		check(env.store.getWriteCount() == writes, "le voyage a écrit dans le DataStore")
		check(env.playerData.GetData(USER_A).currencies.coins == coins, "le voyage a modifié le solde")
	end)

	case("retour à Green Valley : toujours possible", function(check)
		local env = newEnv({ USER_A })
		local result = env.request(USER_A, { worldId = "GreenValley" })
		check(result.ok, `code {tostring(result.code)}`)
		check(#env.teleports == 1, "aucun déplacement")
	end)

	-- REFUS -------------------------------------------------------------------

	case("monde verrouillé : WORLD_LOCKED, aucun déplacement, journal", function(check)
		local env = newEnv({ USER_A })
		local result = env.request(USER_A, { worldId = "GoldenDesert" })
		check(not result.ok and result.code == Code.WorldLocked, `code {tostring(result.code)}`)
		check(#env.teleports == 0, "déplacement malgré le verrou")
		check(env.hasEvent(Event.ActionRefused), "refus non journalisé")
	end)

	case("monde verrouillé : même avec un point d'arrivée et en répétant", function(check)
		local env = newEnv({ USER_A }, { arrivals = { FrozenPeaks = DESERT_ARRIVAL, MysticWorld = DESERT_ARRIVAL } })
		for _, worldId in ipairs({ "FrozenPeaks", "MysticWorld" }) do
			check(env.request(USER_A, { worldId = worldId }).code == Code.WorldLocked, `{worldId} accepté`)
			env.now += refillSeconds
		end
		check(#env.teleports == 0, "déplacement vers un monde verrouillé")
	end)

	case("monde inconnu : INVALID_TARGET", function(check)
		local env = newEnv({ USER_A }, { arrivals = { Atlantis = DESERT_ARRIVAL } })
		local result = env.request(USER_A, { worldId = "Atlantis" })
		check(result.code == Code.InvalidTarget, `code {tostring(result.code)}`)
		check(env.hasEvent(Event.UnknownId), "identifiant inconnu non journalisé")
		check(#env.teleports == 0, "déplacement vers un monde inconnu")
	end)

	case("payloads invalides : INVALID_TARGET, aucun déplacement", function(check)
		local samples: { { payload: any, extra: number } } = {
			{ payload = nil, extra = 0 },
			{ payload = "GoldenDesert", extra = 0 },
			{ payload = {}, extra = 0 },
			{ payload = { worldId = 5 }, extra = 0 },
			{ payload = { worldId = "" }, extra = 0 },
			{ payload = { worldId = string.rep("a", Security.Payload.maxIdLength + 1) }, extra = 0 },
			{ payload = { worldId = "Golden Desert" }, extra = 0 },
			-- Position imposée par le client : champ supplémentaire refusé.
			{ payload = { worldId = "GoldenDesert", position = { X = 1, Y = 2, Z = 3 } }, extra = 0 },
			{ payload = { worldId = "GoldenDesert" }, extra = 1 },
		}
		for index, sample in ipairs(samples) do
			local env = newEnv({ USER_A }, { prepare = unlockDesert })
			local result = env.request(USER_A, sample.payload, sample.extra)
			check(result.code == Code.InvalidTarget, `échantillon {index} : {tostring(result.code)}`)
			check(#env.teleports == 0, `échantillon {index} : déplacement`)
			check(env.hasEvent(Event.InvalidPayload), `échantillon {index} : non journalisé`)
		end
	end)

	case("monde débloqué sans île : WORLD_UNAVAILABLE, non journalisé", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert, arrivals = {} })
		local result = env.request(USER_A, { worldId = "GoldenDesert" })
		check(result.code == Code.WorldUnavailable, `code {tostring(result.code)}`)
		check(#env.teleports == 0, "déplacement sans point d'arrivée")
		check(#env.events == 0, "refus normal journalisé comme suspect")
	end)

	case("point d'arrivée non fini (NaN) : WORLD_UNAVAILABLE", function(check)
		local env = newEnv({ USER_A }, {
			prepare = unlockDesert,
			arrivals = { GoldenDesert = { X = 0 / 0, Y = 0, Z = 0 } },
		})
		check(env.request(USER_A, { worldId = "GoldenDesert" }).code == Code.WorldUnavailable, "arrivée NaN acceptée")
		check(#env.teleports == 0, "déplacement vers une position non finie")
	end)

	case("personnage absent : NO_CHARACTER", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert, alive = false })
		check(env.request(USER_A, { worldId = "GoldenDesert" }).code == Code.NoCharacter, "voyage sans personnage")
	end)

	case("profil non chargé : PROFILE_NOT_LOADED", function(check)
		local env = newEnv({})
		check(env.request(USER_A, { worldId = "GreenValley" }).code == Code.ProfileNotLoaded, "voyage sans profil")
		check(#env.teleports == 0, "déplacement sans profil")
	end)

	case("limite de fréquence : rafale, réponse silencieuse, recharge", function(check)
		local env = newEnv({ USER_A })
		for index = 1, burst do
			check(env.request(USER_A, { worldId = "GreenValley" }).ok, `voyage {index} refusé`)
		end
		local limited = env.request(USER_A, { worldId = "GreenValley" })
		check(limited.code == Code.RateLimited and not limited.silent, "première limitation absente ou silencieuse")
		local again = env.request(USER_A, { worldId = "GreenValley" })
		check(again.code == Code.RateLimited and again.silent, "limitation répétée non silencieuse")
		check(#env.teleports == burst, "déplacement au-delà de la limite")
		env.now += refillSeconds
		check(env.request(USER_A, { worldId = "GreenValley" }).ok, "voyage refusé après recharge")
	end)

	case("deux joueurs : déblocage propre à chaque profil", function(check)
		local env = newEnv({ USER_A, USER_B }, { prepare = unlockDesert })
		check(env.request(USER_B, { worldId = "GoldenDesert" }).code == Code.WorldLocked, "joueur B accepté")
		check(env.request(USER_A, { worldId = "GoldenDesert" }).ok, "joueur A refusé")
		check(#env.teleports == 1 and env.teleports[1].userId == USER_A, "mauvais joueur déplacé")
	end)

	case("départ du joueur : limite de fréquence nettoyée", function(check)
		local env = newEnv({ USER_A })
		for _ = 1, burst do
			env.request(USER_A, { worldId = "GreenValley" })
		end
		check(env.request(USER_A, { worldId = "GreenValley" }).code == Code.RateLimited, "limite absente")
		env.travel.RemovePlayer(USER_A)
		check(env.request(USER_A, { worldId = "GreenValley" }).ok, "limite conservée après le départ")
	end)

	-- VOYAGE ET COLLECTE (MovementValidator, CollectionService) ---------------

	case("après un voyage : collecte au point d'arrivée acceptée, aucun faux positif", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert })
		env.spawner.Register("sandstone_001", "sandstone", { X = 5002, Y = 0, Z = 0 })
		env.spawner.Register("green_leaf_001", "green_leaf", { X = 0, Y = 0, Z = 0 })
		check(env.collection.HandleRequest(USER_A, { resourceId = "green_leaf_001" }).ok, "collecte initiale refusée")
		env.now += interval
		check(env.request(USER_A, { worldId = "GoldenDesert" }).ok, "voyage refusé")
		-- Position encore en transit pendant la grâce : ancienne position.
		local stale = env.validator.Observe(USER_A, { X = 1, Y = 0, Z = 1 }, env.now + 0.25)
		check(stale.status == "skipped", `position en transit jugée : {stale.status}`)
		local result = env.collection.HandleRequest(USER_A, { resourceId = "sandstone_001" })
		check(result.ok, `collecte au point d'arrivée : {tostring(result.code)}`)
		check(env.idle(3) == 0, "anomalie de déplacement après un voyage légitime")
		check(#env.events == 0, "refus journalisé pendant un parcours légitime")
	end)

	case("après un voyage : collecte loin du point d'arrivée refusée", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert })
		env.spawner.Register("sandstone_001", "sandstone", { X = 5300, Y = 0, Z = 0 })
		check(env.request(USER_A, { worldId = "GoldenDesert" }).ok, "voyage refusé")
		-- Le client prétend être à côté d'un nœud éloigné du point d'arrivée.
		env.positions[USER_A] = { X = 5300, Y = 3, Z = 0 }
		env.now += 0.25
		local result = env.collection.HandleRequest(USER_A, { resourceId = "sandstone_001" })
		check(not result.ok and result.code == Code.TooFar, `code {tostring(result.code)}`)
	end)

	case("témoin : sans remise à zéro, la même collecte serait refusée", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert })
		env.spawner.Register("sandstone_001", "sandstone", { X = 5002, Y = 0, Z = 0 })
		env.spawner.Register("green_leaf_001", "green_leaf", { X = 0, Y = 0, Z = 0 })
		check(env.collection.HandleRequest(USER_A, { resourceId = "green_leaf_001" }).ok, "collecte initiale refusée")
		env.now += interval
		-- Déplacement brut, sans passer par WorldTravelService.
		env.positions[USER_A] = { X = DESERT_ARRIVAL.X, Y = DESERT_ARRIVAL.Y, Z = DESERT_ARRIVAL.Z }
		local result = env.collection.HandleRequest(USER_A, { resourceId = "sandstone_001" })
		check(result.code == Code.TooFar, `déplacement brut accepté : {tostring(result.code)}`)
		check(CollectionSecurity.Travel.slackStuds < DESERT_ARRIVAL.X, "témoin mal dimensionné")
	end)

	-- VÉRIFICATIONS A (sécurité du voyage) -------------------------------------

	-- Copie canonique d'une table (clés triées) pour comparer avant / après.
	local function serialize(value: any): string
		if type(value) ~= "table" then
			return `{type(value)}:{tostring(value)}`
		end
		local keys = {}
		for key in pairs(value) do
			table.insert(keys, key)
		end
		table.sort(keys, function(a: any, b: any): boolean
			return tostring(a) < tostring(b)
		end)
		local parts = {}
		for _, key in ipairs(keys) do
			table.insert(parts, `{tostring(key)}={serialize(value[key])}`)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end

	case("A : falsifications répétées vers chaque monde verrouillé : jamais de déplacement", function(check)
		local env = newEnv({ USER_A }, {
			arrivals = { GoldenDesert = DESERT_ARRIVAL, FrozenPeaks = DESERT_ARRIVAL, MysticWorld = DESERT_ARRIVAL },
		})
		local payloads: { any } = {
			{ worldId = "GoldenDesert" },
			{ worldId = "FrozenPeaks" },
			{ worldId = "MysticWorld" },
			{ worldId = "goldendesert" },
			{ worldId = "GoldenDesert", unlocked = true },
			{ worldId = "GoldenDesert", force = true },
		}
		for round = 1, 3 do
			for index, payload in ipairs(payloads) do
				check(not env.request(USER_A, payload).ok, `tour {round}, demande {index} acceptée`)
				env.now += refillSeconds
			end
		end
		check(#env.teleports == 0, `{#env.teleports} déplacement(s) vers un monde verrouillé`)
		check(env.playerData.GetData(USER_A).worlds.GoldenDesert ~= true, "monde débloqué par une demande de voyage")
	end)

	case("A : joueur mort au moment de la demande : NO_CHARACTER, références inchangées", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert })
		local before = env.validator.Inspect(USER_A).anchor
		env.alive = false
		check(env.request(USER_A, { worldId = "GoldenDesert" }).code == Code.NoCharacter, "voyage d'un joueur mort")
		local after = env.validator.Inspect(USER_A).anchor
		check(after.X == before.X and after.Z == before.Z and after.t == before.t, "référence de déplacement modifiée")
		check(#env.teleports == 0, "déplacement d'un joueur mort")
	end)

	case("A : profil libéré (déconnexion) : PROFILE_NOT_LOADED", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert })
		check(env.playerData.ReleasePlayer(USER_A).ok, "libération du profil")
		check(env.request(USER_A, { worldId = "GoldenDesert" }).code == Code.ProfileNotLoaded, "voyage sans profil actif")
		check(#env.teleports == 0, "déplacement sans profil")
	end)

	case("A : voyage pendant une suspension T6 : suspension conservée, collecte refusée", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert })
		env.spawner.Register("sandstone_001", "sandstone", { X = 5002, Y = 0, Z = 0 })
		-- Sauts de 45 studs répétés : correction et suspension (T6).
		local dt = MovementConfig.Sampling.intervalSeconds
		local position = { X = 1, Y = 0, Z = 1 }
		local corrected = false
		for _ = 1, 6 do
			if corrected then
				break
			end
			env.now += dt
			position = { X = position.X + 45, Y = 0, Z = position.Z }
			corrected = env.validator.Observe(USER_A, position, env.now).status == "correct"
			for _ = 1, 4 do
				env.now += dt
				corrected = corrected or env.validator.Observe(USER_A, position, env.now).status == "correct"
			end
		end
		check(corrected, "dispositif : aucune correction obtenue")
		local suspendedUntil = env.validator.Inspect(USER_A).suspendedUntil
		check(suspendedUntil > env.now, "dispositif : aucune suspension")
		check(env.request(USER_A, { worldId = "GoldenDesert" }).ok, "voyage refusé")
		check(env.validator.Inspect(USER_A).suspendedUntil == suspendedUntil, "suspension levée par le voyage")
		local result = env.collection.HandleRequest(USER_A, { resourceId = "sandstone_001" })
		check(not result.ok and result.code == Code.TooFar, `collecte pendant la suspension : {tostring(result.code)}`)
	end)

	case("A : demandes enchaînées : un déplacement par voyage accepté, position cohérente", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert })
		-- Trois demandes dans la même image serveur : la troisième est limitée.
		local first = env.request(USER_A, { worldId = "GoldenDesert" })
		local second = env.request(USER_A, { worldId = "GreenValley" })
		local third = env.request(USER_A, { worldId = "GoldenDesert" })
		check(first.ok and second.ok, "voyages valides refusés")
		check(third.code == Code.RateLimited, `troisième demande : {tostring(third.code)}`)
		check(#env.teleports == 2, `{#env.teleports} déplacement(s) pour 2 voyages acceptés`)
		local position = env.positions[USER_A]
		local anchor = env.validator.Inspect(USER_A).anchor
		check(position.X == VALLEY_ARRIVAL.X and position.Z == VALLEY_ARRIVAL.Z, "position finale différente du dernier voyage accepté")
		check(anchor.X == VALLEY_ARRIVAL.X and anchor.Z == VALLEY_ARRIVAL.Z, "référence de déplacement incohérente")
		check(env.idle(3) == 0, "anomalie après des voyages enchaînés")
	end)

	-- VÉRIFICATIONS B (cohérence du profil) -----------------------------------

	case("B : le voyage ne modifie aucune donnée du profil", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				unlockDesert(profile)
				profile.currencies.coins = 1234
				profile.inventory.resources.sandstone = 4
			end,
		})
		local before = serialize(env.playerData.GetData(USER_A))
		local writes = env.store.getWriteCount()
		for _ = 1, 3 do
			env.request(USER_A, { worldId = "GoldenDesert" })
			env.request(USER_A, { worldId = "GreenValley" })
			env.now += 2 * refillSeconds
		end
		check(#env.teleports == 6, `{#env.teleports} déplacement(s) sur 6`)
		check(serialize(env.playerData.GetData(USER_A)) == before, "profil modifié par le voyage")
		check(env.store.getWriteCount() == writes, "écriture DataStore pendant les voyages")
	end)

	case("B : retour à Green Valley puis reconnexion : profil conservé", function(check)
		local env = newEnv({ USER_A }, { prepare = unlockDesert })
		env.spawner.Register("sandstone_001", "sandstone", { X = 5002, Y = 0, Z = 0 })
		check(env.request(USER_A, { worldId = "GoldenDesert" }).ok, "voyage refusé")
		check(env.collection.HandleRequest(USER_A, { resourceId = "sandstone_001" }).ok, "collecte refusée")
		env.now += refillSeconds
		check(env.request(USER_A, { worldId = "GreenValley" }).ok, "retour refusé")
		-- Données de jeu (hors métadonnées de session et de sauvegarde).
		local function gameplay(profile: any): string
			return serialize({ profile.currencies, profile.inventory, profile.upgrades, profile.worlds, profile.schemaVersion })
		end
		local before = gameplay(env.playerData.GetData(USER_A))
		check(env.playerData.ReleasePlayer(USER_A).ok, "sauvegarde de sortie en échec")

		-- Nouveau serveur, même magasin : reconnexion.
		local other = newEnv({ USER_A }, { store = env.store })
		local profile = other.playerData.GetData(USER_A)
		check(profile.worlds.GoldenDesert == true, "déblocage perdu à la reconnexion")
		check(profile.inventory.resources.sandstone == 1, "ressource de Golden Desert perdue")
		check(gameplay(profile) == before, "progression différente après reconnexion")
		-- Aucune position ni monde courant persistés (D5) : apparition au hub.
		check(profile.position == nil and profile.currentWorld == nil, "position persistée")
	end)

	case("B : profil existant sans ressources T8 : chargé sans modification", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.inventory.resources = { green_leaf = 3, wood = 2, stone = 1 }
			end,
		})
		local resources = env.playerData.GetData(USER_A).inventory.resources
		check(resources.green_leaf == 3 and resources.wood == 2 and resources.stone == 1, "inventaire modifié au chargement")
		check(resources.sandstone == nil and resources.wild_fruit == nil, "clé ajoutée au chargement")
		local worlds = env.playerData.GetData(USER_A).worlds
		check(worlds.GreenValley == true and worlds.GoldenDesert ~= true, "mondes modifiés au chargement")
	end)

	case("B : ressources des quatre mondes : conservées après sauvegarde et rechargement", function(check)
		local env = newEnv({ USER_A }, {
			prepare = function(profile: any)
				profile.inventory.resources = { green_crystal = 1, gold_nugget = 2, ice_diamond = 1, mystic_core = 3 }
			end,
		})
		check(env.playerData.ReleasePlayer(USER_A).ok, "sauvegarde en échec")
		local other = newEnv({ USER_A }, { store = env.store })
		local resources = other.playerData.GetData(USER_A).inventory.resources
		check(
			resources.green_crystal == 1 and resources.gold_nugget == 2 and resources.ice_diamond == 1 and resources.mystic_core == 3,
			"ressources des nouveaux mondes perdues"
		)
	end)

	return failures, caseCount
end

return WorldTravelServiceTests
