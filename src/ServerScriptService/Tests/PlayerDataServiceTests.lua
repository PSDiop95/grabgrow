--!strict
-- Tests de PlayerDataService avec un magasin en mémoire injecté : aucun
-- appel au DataStore réel. Horloge et attentes simulées (une attente
-- avance l'horloge), donc exécution instantanée.
--
-- Les cas de concurrence pilotent des coroutines à la main : le magasin
-- suspend le fil au début d'un appel, comme le ferait la latence réseau.

local PlayerDataServiceTests = {}

export type Modules = {
	PlayerDataService: any,
	MemoryDataStore: any,
	DataSchema: any,
	DataConfig: any,
}

local USER_A = 1001
local USER_B = 1002
local KEY_A = "Player_1001"
local KEY_B = "Player_1002"

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

-- Retourne (liste des échecs, nombre de cas exécutés).
function PlayerDataServiceTests.run(modules: Modules): ({ string }, number)
	local PlayerDataService = modules.PlayerDataService
	local MemoryDataStore = modules.MemoryDataStore
	local DataSchema = modules.DataSchema
	local config = modules.DataConfig
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

	-- Environnement partagé par plusieurs « serveurs » : même magasin,
	-- même horloge.
	local function newWorld()
		local world = {
			store = MemoryDataStore.new(),
			now = 1_000_000,
			-- true : une attente suspend la coroutine au lieu d'avancer l'horloge.
			yieldOnWait = false,
			waited = 0,
		}
		return world
	end

	local function newServer(world: any, serverId: string)
		local server = { lost = {} :: { number }, logs = {} :: { string } }
		server.service = PlayerDataService.new({
			store = world.store,
			serverId = serverId,
			clock = function(): number
				return world.now
			end,
			wait = function(seconds: number)
				if world.yieldOnWait then
					coroutine.yield()
				else
					world.now += seconds
					world.waited += seconds
				end
			end,
			spawn = function(callback: () -> ())
				callback()
			end,
			onSessionLost = function(userId: number)
				table.insert(server.lost, userId)
			end,
			log = function(level: string, message: string)
				table.insert(server.logs, `{level} {message}`)
			end,
		})
		return server
	end

	local function existingProfile(): any
		local profile = DataSchema.newProfile()
		profile.currencies.coins = 500
		profile.inventory.resources.wood = 12
		profile.upgrades.backpackLevel = 3
		profile.worlds.GoldenDesert = true
		profile.stats.totalSales = 8
		profile.lastSaveAt = 900_000
		return profile
	end

	local function addCoins(amount: number): (draft: any) -> boolean?
		return function(draft: any): boolean?
			draft.currencies.coins += amount
			return nil
		end
	end

	-- CHARGEMENT ----------------------------------------------------------

	case("chargement : nouveau joueur", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		local result = server.service.LoadPlayer(USER_A)
		check(result.ok, `échec : {tostring(result.code)}`)
		check(server.service.IsLoaded(USER_A), "IsLoaded faux")
		check(deepEqual(server.service.GetData(USER_A), DataSchema.newProfile()), "profil différent du défaut")
		local stored = world.store.peek(KEY_A)
		check(stored ~= nil and deepEqual(stored.profile, DataSchema.newProfile()), "profil par défaut non écrit")
		check(stored ~= nil and stored.session ~= nil and stored.session.id == "A:1", "verrou absent ou incorrect")
		check(
			stored ~= nil and stored.session.expiresAt == world.now + config.SessionLock.timeoutSeconds,
			"expiration du verrou incorrecte"
		)
	end)

	case("chargement : joueur existant sans perte", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = existingProfile() })
		local server = newServer(world, "A")
		local result = server.service.LoadPlayer(USER_A)
		check(result.ok, `échec : {tostring(result.code)}`)
		check(deepEqual(server.service.GetData(USER_A), existingProfile()), "profil chargé différent du profil stocké")
		check(deepEqual(world.store.peek(KEY_A).profile, existingProfile()), "profil stocké modifié par le chargement")
	end)

	case("chargement : échec temporaire puis réussite", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = existingProfile() })
		world.store.failNext(2)
		local server = newServer(world, "A")
		local result = server.service.LoadPlayer(USER_A)
		check(result.ok, `échec : {tostring(result.code)}`)
		check(server.service.GetData(USER_A).currencies.coins == 500, "profil existant non retrouvé")
		check(
			world.waited == config.Retry.baseDelaySeconds * 3,
			`attente progressive attendue (1 + 2), trouvé {world.waited}`
		)
	end)

	case("chargement : échec définitif, aucun profil vide", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = existingProfile() })
		world.store.setAlwaysFail(true)
		local server = newServer(world, "A")
		local result = server.service.LoadPlayer(USER_A)
		check(not result.ok and result.code == Code.StoreError, `code {tostring(result.code)}`)
		check(not server.service.IsLoaded(USER_A), "profil marqué chargé")
		check(server.service.GetData(USER_A) == nil, "données disponibles après échec")
		check(world.store.getWriteCount() == 0, "écriture malgré l'échec")
		check(deepEqual(world.store.peek(KEY_A), { profile = existingProfile() }), "sauvegarde existante modifiée")

		-- Le joueur peut revenir quand le DataStore répond de nouveau.
		world.store.setAlwaysFail(false)
		local retry = server.service.LoadPlayer(USER_A)
		check(retry.ok, "nouvelle tentative refusée")
		check(server.service.GetData(USER_A).currencies.coins == 500, "profil existant perdu")
	end)

	case("chargement : profil non chargé inaccessible", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		check(not server.service.IsLoaded(USER_A), "IsLoaded vrai")
		check(server.service.GetData(USER_A) == nil, "GetData retourne des données")
		check(server.service.Update(USER_A, addCoins(10)).code == Code.NotLoaded, "Update accepté")
		check(server.service.SavePlayer(USER_A).code == Code.NotLoaded, "SavePlayer accepté")
		check(server.service.ReleasePlayer(USER_A).code == Code.NotLoaded, "ReleasePlayer accepté")
		check(world.store.getWriteCount() == 0, "écriture sans profil chargé")
		check(server.service.LoadPlayer(0).code == Code.InvalidArgument, "userId 0 accepté")
		check(server.service.LoadPlayer(1.5).code == Code.InvalidArgument, "userId décimal accepté")
		check(server.service.LoadPlayer("1001" :: any).code == Code.InvalidArgument, "userId texte accepté")
	end)

	case("chargement : double chargement refusé", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(5))
		local second = server.service.LoadPlayer(USER_A)
		check(second.code == Code.AlreadyLoaded, `code {tostring(second.code)}`)
		check(server.service.GetData(USER_A).currencies.coins == 5, "session existante altérée")
	end)

	case("chargement : données corrompues jamais écrasées", function(check)
		local samples: { [string]: any } = {
			["valeur non table"] = "corrompu",
			["sans profil"] = { session = nil, autre = 1 },
			["profil mal typé"] = { profile = { schemaVersion = 1, currencies = "oops" } },
			["verrou illisible"] = { profile = existingProfile(), session = "A:1" },
		}
		for name, sample in pairs(samples) do
			local world = newWorld()
			world.store.seed(KEY_A, sample)
			local server = newServer(world, "A")
			local result = server.service.LoadPlayer(USER_A)
			check(not result.ok and result.code == Code.CorruptData, `{name} : code {tostring(result.code)}`)
			check(not server.service.IsLoaded(USER_A), `{name} : profil chargé`)
			check(world.store.getWriteCount() == 0, `{name} : écriture effectuée`)
			check(deepEqual(world.store.peek(KEY_A), sample), `{name} : valeur stockée modifiée`)
		end
	end)

	case("chargement : version future refusée sans écriture", function(check)
		local world = newWorld()
		local future = existingProfile()
		future.schemaVersion = config.SchemaVersion + 1
		world.store.seed(KEY_A, { profile = future })
		local server = newServer(world, "A")
		local result = server.service.LoadPlayer(USER_A)
		check(result.code == Code.UnsupportedVersion, `code {tostring(result.code)}`)
		check(deepEqual(world.store.peek(KEY_A), { profile = future }), "valeur stockée modifiée")
	end)

	case("chargement : profil réparable chargé et signalé", function(check)
		local world = newWorld()
		local partial = { schemaVersion = 1, currencies = { coins = 321 }, upgrades = { backpackLevel = 999 } }
		world.store.seed(KEY_A, { profile = partial })
		local server = newServer(world, "A")
		local result = server.service.LoadPlayer(USER_A)
		check(result.ok, `échec : {tostring(result.code)}`)
		local data = server.service.GetData(USER_A)
		check(data.currencies.coins == 321, "coins perdus")
		check(DataSchema.validate(data), "profil chargé non conforme")
		local reported = false
		for _, line in ipairs(server.logs) do
			if string.find(line, "réparé", 1, true) then
				reported = true
			end
		end
		check(reported, "réparation non journalisée")
		check(deepEqual(world.store.peek(KEY_A).profile, partial), "profil original réécrit au chargement (D-008)")
	end)

	case("chargement : UserId négatif de Studio accepté", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		check(server.service.LoadPlayer(-1).ok, "joueur de test Studio (-1) refusé")
		check(world.store.peek("Player_-1") ~= nil, "profil de test non créé")
	end)

	-- D-008 : PROFIL NORMALISÉ ---------------------------------------------

	local function recoveryKeys(world: any): { string }
		local list = {}
		local prefix = config.Store.recoveryKeyPrefix
		for _, key in ipairs(world.store.keys()) do
			if string.sub(key, 1, #prefix) == prefix then
				table.insert(list, key)
			end
		end
		return list
	end

	local function partialProfile(): any
		return { schemaVersion = 1, currencies = { coins = 321 }, upgrades = { backpackLevel = 999 } }
	end

	local function hasLog(server: any, fragment: string): boolean
		for _, line in ipairs(server.logs) do
			if string.find(line, fragment, 1, true) then
				return true
			end
		end
		return false
	end

	local function failRecoveryKeys(world: any)
		world.store.setFailingKeys(function(key: string): boolean
			return string.sub(key, 1, #config.Store.recoveryKeyPrefix) == config.Store.recoveryKeyPrefix
		end)
	end

	case("D-008 : chargement normalisé sans réécriture ni copie immédiate", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = partialProfile(), autreChamp = "conservé" })
		local server = newServer(world, "A")
		check(server.service.LoadPlayer(USER_A).ok, "chargement refusé")
		local stored = world.store.peek(KEY_A)
		check(deepEqual(stored.profile, partialProfile()), "profil original modifié au chargement")
		check(stored.autreChamp == "conservé", "champ inconnu de premier niveau supprimé")
		check(stored.session ~= nil and stored.session.id == "A:1", "verrou non posé")
		check(#recoveryKeys(world) == 0, "copie écrite dès le chargement")
		check(server.service.GetData(USER_A).upgrades.backpackLevel ~= 999, "profil non normalisé en mémoire")
		check(hasLog(server, "normalisé en mémoire"), "normalisation non journalisée")
	end)

	case("D-008 : copie de récupération écrite avant la première sauvegarde", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = partialProfile() })
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		local loadTime = world.now
		server.service.Update(USER_A, addCoins(9))
		world.now += 30
		check(server.service.SavePlayer(USER_A).ok, "sauvegarde refusée")

		local keys = recoveryKeys(world)
		local expectedKey = `Recovery_{USER_A}_{loadTime}`
		check(#keys == 1 and keys[1] == expectedKey, `clé de copie inattendue : {table.concat(keys, ", ")}`)
		local record = world.store.peek(expectedKey)
		check(record ~= nil and deepEqual(record.originalProfile, partialProfile()), "copie différente de l'original")
		check(record ~= nil and record.userId == USER_A and record.sourceKey == KEY_A, "copie sans provenance")
		check(record ~= nil and #record.repairs > 0, "copie sans liste des corrections")
		local stored = world.store.peek(KEY_A)
		check(stored.profile.currencies.coins == 330, "profil normalisé non sauvegardé")
		check(DataSchema.validate(stored.profile), "profil sauvegardé non conforme")

		local writes = world.store.getWriteCount()
		server.service.SavePlayer(USER_A)
		check(#recoveryKeys(world) == 1, "seconde copie créée")
		check(world.store.getWriteCount() == writes + 1, "la copie est réécrite à chaque sauvegarde")
	end)

	case("D-008 : copie impossible, sauvegarde bloquée puis reprise", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = partialProfile() })
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(9))
		failRecoveryKeys(world)
		local blocked = server.service.SavePlayer(USER_A)
		check(blocked.code == Code.BackupFailed, `code {tostring(blocked.code)}`)
		check(deepEqual(world.store.peek(KEY_A).profile, partialProfile()), "original écrasé sans copie")
		check(server.service.IsLoaded(USER_A), "session perdue après un blocage")
		check(server.service.GetData(USER_A).currencies.coins == 330, "données en mémoire perdues")
		check(hasLog(server, "sauvegarde bloquée"), "blocage non journalisé")

		world.store.setFailingKeys(nil)
		check(server.service.SavePlayer(USER_A).ok, "sauvegarde toujours bloquée après rétablissement")
		check(#recoveryKeys(world) == 1, "copie absente après rétablissement")
		check(world.store.peek(KEY_A).profile.currencies.coins == 330, "profil non sauvegardé après rétablissement")
	end)

	case("D-008 : sortie avec copie impossible, original intact et verrou libéré", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = partialProfile() })
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(9))
		failRecoveryKeys(world)
		local result = server.service.ReleasePlayer(USER_A)
		check(result.code == Code.BackupFailed, `code {tostring(result.code)}`)
		local stored = world.store.peek(KEY_A)
		check(deepEqual(stored.profile, partialProfile()), "original écrasé à la sortie")
		check(stored.session == nil, "verrou non libéré")
		check(not server.service.IsLoaded(USER_A), "session conservée")
	end)

	case("D-008 : copie déjà écrite (réponse perdue) acceptée", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = partialProfile() })
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		world.store.failAfterWriteNext(1)
		check(server.service.SavePlayer(USER_A).ok, "sauvegarde refusée après une réponse perdue")
		check(#recoveryKeys(world) == 1, "copie absente ou dupliquée")
	end)

	case("D-008 : copie existante différente jamais écrasée", function(check)
		local world = newWorld()
		local existingKey = `Recovery_{USER_A}_{world.now}`
		world.store.seed(KEY_A, { profile = partialProfile() })
		world.store.seed(existingKey, { autre = "copie" })
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		check(server.service.SavePlayer(USER_A).code == Code.BackupFailed, "copie existante ignorée")
		check(deepEqual(world.store.peek(existingKey), { autre = "copie" }), "copie existante écrasée")
		check(deepEqual(world.store.peek(KEY_A).profile, partialProfile()), "original écrasé")
	end)

	case("D-008 : profil conforme ou nouveau, aucune copie", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = existingProfile() })
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.SavePlayer(USER_A)
		server.service.ReleasePlayer(USER_A)
		check(#recoveryKeys(world) == 0, "copie créée pour un profil conforme")
		local fresh = newWorld()
		local other = newServer(fresh, "B")
		other.service.LoadPlayer(USER_A)
		other.service.SavePlayer(USER_A)
		check(#recoveryKeys(fresh) == 0, "copie créée pour un nouveau profil")
	end)

	-- ACCÈS ET MODIFICATION -----------------------------------------------

	case("données : GetData retourne une copie", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		local copy = server.service.GetData(USER_A)
		copy.currencies.coins = 1_000_000
		copy.inventory.resources.wood = 99
		local fresh = server.service.GetData(USER_A)
		check(fresh.currencies.coins == 0, "le profil interne a été modifié par la copie")
		check(fresh.inventory.resources.wood == nil, "l'inventaire interne a été modifié par la copie")
	end)

	case("données : Update valide appliqué, invalide refusé en bloc", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		check(server.service.Update(USER_A, addCoins(100)).ok, "modification valide refusée")
		check(server.service.GetData(USER_A).currencies.coins == 100, "modification non appliquée")

		local rejected: { [string]: (draft: any) -> boolean? } = {
			["solde négatif"] = function(draft: any): boolean?
				draft.inventory.resources.wood = 5 -- partie valide : ne doit pas passer
				draft.currencies.coins = -1
				return nil
			end,
			["niveau hors limites"] = function(draft: any): boolean?
				draft.upgrades.backpackLevel = 999
				return nil
			end,
			["type incorrect"] = function(draft: any): boolean?
				draft.currencies.coins = "100"
				return nil
			end,
			["section supprimée"] = function(draft: any): boolean?
				draft.currencies = nil
				return nil
			end,
			["version modifiée"] = function(draft: any): boolean?
				draft.schemaVersion = config.SchemaVersion + 1
				return nil
			end,
			["erreur"] = function(draft: any): boolean?
				draft.currencies.coins = 5
				error("panne")
			end,
			["fil suspendu"] = function(draft: any): boolean?
				draft.currencies.coins = 5
				coroutine.yield()
				return nil
			end,
		}
		for name, mutator in pairs(rejected) do
			local result = server.service.Update(USER_A, mutator)
			check(result.code == Code.InvalidUpdate, `{name} : code {tostring(result.code)}`)
		end
		local aborted = server.service.Update(USER_A, function(draft: any): boolean?
			draft.currencies.coins = 7
			return false
		end)
		check(aborted.code == Code.Aborted, `abandon : code {tostring(aborted.code)}`)

		local data = server.service.GetData(USER_A)
		check(data.currencies.coins == 100, "une modification refusée a changé le solde")
		check(data.inventory.resources.wood == nil, "une modification refusée a été appliquée en partie")
	end)

	-- SAUVEGARDE ----------------------------------------------------------

	case("sauvegarde : normale après modification", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(250))
		world.now += 30
		local result = server.service.SavePlayer(USER_A)
		check(result.ok, `échec : {tostring(result.code)}`)
		local stored = world.store.peek(KEY_A)
		check(stored.profile.currencies.coins == 250, "modification non sauvegardée")
		check(stored.profile.lastSaveAt == world.now, "lastSaveAt non mis à jour")
		check(server.service.GetData(USER_A).lastSaveAt == world.now, "lastSaveAt non reporté en mémoire")
		check(stored.session.id == "A:1", "verrou perdu à la sauvegarde")
		check(
			stored.session.expiresAt == world.now + config.SessionLock.timeoutSeconds,
			"verrou non renouvelé à la sauvegarde"
		)
		check(server.service.IsLoaded(USER_A), "profil déchargé par la sauvegarde")
	end)

	case("sauvegarde : échec puis reprise, données gardées en mémoire", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(75))

		world.store.failNext(config.Retry.maxAttempts)
		local failed = server.service.SavePlayer(USER_A)
		check(failed.code == Code.StoreError, `code {tostring(failed.code)}`)
		check(world.store.peek(KEY_A).profile.currencies.coins == 0, "écriture malgré l'échec")
		check(server.service.IsLoaded(USER_A), "profil déchargé après un échec de sauvegarde")
		check(server.service.GetData(USER_A).currencies.coins == 75, "données en mémoire perdues")

		local retried = server.service.SavePlayer(USER_A)
		check(retried.ok, "la sauvegarde suivante échoue")
		check(world.store.peek(KEY_A).profile.currencies.coins == 75, "données non sauvegardées à la reprise")
	end)

	case("sauvegarde : échec temporaire absorbé par les reprises", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(20))
		world.store.failNext(config.Retry.maxAttempts - 1)
		check(server.service.SavePlayer(USER_A).ok, "sauvegarde en échec malgré les reprises")
		check(world.store.peek(KEY_A).profile.currencies.coins == 20, "données non sauvegardées")
	end)

	case("sauvegarde : deux demandes simultanées, modification récente incluse", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(10))
		local writesBefore = world.store.getWriteCount()

		-- Le premier appel au magasin se suspend avant d'écrire.
		local suspended = false
		world.store.setBeforeCall(function()
			if not suspended then
				suspended = true
				coroutine.yield()
			end
		end)
		world.yieldOnWait = true

		local firstResult: any, secondResult: any
		local first = coroutine.create(function()
			firstResult = server.service.SavePlayer(USER_A)
		end)
		coroutine.resume(first)
		check(coroutine.status(first) == "suspended", "la première sauvegarde aurait dû être en cours")

		-- Modification pendant l'écriture, puis seconde demande.
		server.service.Update(USER_A, addCoins(5))
		local second = coroutine.create(function()
			secondResult = server.service.SavePlayer(USER_A)
		end)
		coroutine.resume(second)
		check(coroutine.status(second) == "suspended", "la seconde demande aurait dû attendre")
		check(world.store.getWriteCount() == writesBefore, "écriture avant la fin de la première demande")

		coroutine.resume(first)
		check(coroutine.status(first) == "dead", "la première sauvegarde ne se termine pas")
		coroutine.resume(second)
		check(coroutine.status(second) == "dead", "la seconde sauvegarde ne se termine pas")

		check(firstResult ~= nil and firstResult.ok, "première demande en échec")
		check(secondResult ~= nil and secondResult.ok, "seconde demande en échec")
		check(world.store.getMaxConcurrentCalls() == 1, "deux écritures simultanées du même profil")
		check(
			world.store.getWriteCount() == writesBefore + 2,
			`2 écritures successives attendues, trouvé {world.store.getWriteCount() - writesBefore}`
		)
		check(world.store.peek(KEY_A).profile.currencies.coins == 15, "modification récente absente de la sauvegarde")
	end)

	case("sauvegarde : sortie du joueur", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(40))
		local result = server.service.ReleasePlayer(USER_A)
		check(result.ok, `échec : {tostring(result.code)}`)
		local stored = world.store.peek(KEY_A)
		check(stored.profile.currencies.coins == 40, "modification non sauvegardée à la sortie")
		check(stored.session == nil, "verrou non libéré à la sortie")
		check(not server.service.IsLoaded(USER_A), "profil encore chargé")
		check(server.service.GetData(USER_A) == nil, "données encore accessibles")

		-- Reconnexion sur un autre serveur : immédiate, sans perte.
		local other = newServer(world, "B")
		local waitedBefore = world.waited
		check(other.service.LoadPlayer(USER_A).ok, "reconnexion refusée")
		check(world.waited == waitedBefore, "la reconnexion a dû attendre un verrou")
		check(other.service.GetData(USER_A).currencies.coins == 40, "progression perdue à la reconnexion")
	end)

	case("sauvegarde : sortie avec DataStore en panne", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(40))
		world.store.setAlwaysFail(true)
		local result = server.service.ReleasePlayer(USER_A)
		check(result.code == Code.StoreError, `code {tostring(result.code)}`)
		check(not server.service.IsLoaded(USER_A), "session conservée en mémoire après le départ")
		world.store.setAlwaysFail(false)
		local stored = world.store.peek(KEY_A)
		check(stored.profile.currencies.coins == 0, "écriture partielle")
		check(stored.session ~= nil, "verrou retiré sans sauvegarde")
	end)

	case("sauvegarde : fermeture du serveur", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.LoadPlayer(USER_B)
		server.service.Update(USER_A, addCoins(11))
		server.service.Update(USER_B, addCoins(22))
		server.service.Shutdown()
		local storedA = world.store.peek(KEY_A)
		local storedB = world.store.peek(KEY_B)
		check(storedA.profile.currencies.coins == 11 and storedB.profile.currencies.coins == 22, "profils non sauvegardés")
		check(storedA.session == nil and storedB.session == nil, "verrous non libérés")
		check(not server.service.IsLoaded(USER_A) and not server.service.IsLoaded(USER_B), "profils encore chargés")
		check(server.service.LoadPlayer(USER_A).code == Code.ShuttingDown, "chargement accepté pendant l'arrêt")
	end)

	-- SESSIONS ------------------------------------------------------------

	case("sessions : deux serveurs, verrou actif respecté", function(check)
		local world = newWorld()
		local serverA = newServer(world, "A")
		local serverB = newServer(world, "B")
		serverA.service.LoadPlayer(USER_A)
		serverA.service.Update(USER_A, addCoins(60))
		serverA.service.SavePlayer(USER_A)
		local before = world.store.peek(KEY_A)

		local result = serverB.service.LoadPlayer(USER_A)
		check(result.code == Code.SessionLocked, `code {tostring(result.code)}`)
		check(not serverB.service.IsLoaded(USER_A), "second serveur chargé malgré le verrou")
		check(deepEqual(world.store.peek(KEY_A), before), "valeur stockée modifiée par le serveur refusé")
		check(
			world.waited == (config.SessionLock.acquireAttempts - 1) * config.SessionLock.acquireDelaySeconds,
			`attente du verrou incorrecte ({world.waited} s)`
		)

		-- Le détenteur continue normalement.
		serverA.service.Update(USER_A, addCoins(1))
		check(serverA.service.SavePlayer(USER_A).ok, "le détenteur ne peut plus sauvegarder")
		check(world.store.peek(KEY_A).profile.currencies.coins == 61, "sauvegarde du détenteur perdue")
		check(#serverA.lost == 0, "session du détenteur déclarée perdue")
	end)

	case("sessions : verrou libéré pendant l'attente", function(check)
		local world = newWorld()
		local serverA = newServer(world, "A")
		local serverB = newServer(world, "B")
		serverA.service.LoadPlayer(USER_A)
		serverA.service.Update(USER_A, addCoins(33))

		-- L'ancien serveur termine sa sauvegarde de sortie pendant que le
		-- nouveau attend.
		world.yieldOnWait = true
		local result: any
		local loading = coroutine.create(function()
			result = serverB.service.LoadPlayer(USER_A)
		end)
		coroutine.resume(loading)
		check(coroutine.status(loading) == "suspended", "le second serveur aurait dû attendre")
		world.yieldOnWait = false
		serverA.service.ReleasePlayer(USER_A)
		coroutine.resume(loading)

		check(result ~= nil and result.ok, "chargement refusé après libération")
		check(serverB.service.GetData(USER_A).currencies.coins == 33, "progression du premier serveur perdue")
	end)

	case("sessions : verrou renouvelé par la sauvegarde", function(check)
		local world = newWorld()
		local serverA = newServer(world, "A")
		local serverB = newServer(world, "B")
		serverA.service.LoadPlayer(USER_A)
		world.now += config.SessionLock.timeoutSeconds - 20
		serverA.service.SavePlayer(USER_A)
		-- Le verrou initial serait expiré ; le renouvellement le prolonge.
		world.now += 30
		local result = serverB.service.LoadPlayer(USER_A)
		check(result.code == Code.SessionLocked, `code {tostring(result.code)}`)
	end)

	case("sessions : verrou expiré repris, ancienne session neutralisée", function(check)
		local world = newWorld()
		local serverA = newServer(world, "A")
		local serverB = newServer(world, "B")
		serverA.service.LoadPlayer(USER_A)
		serverA.service.Update(USER_A, addCoins(10))
		serverA.service.SavePlayer(USER_A)
		-- Modification jamais sauvegardée, puis serveur A figé au-delà du délai.
		serverA.service.Update(USER_A, addCoins(1000))
		world.now += config.SessionLock.timeoutSeconds + 1

		local result = serverB.service.LoadPlayer(USER_A)
		check(result.ok, `reprise refusée : {tostring(result.code)}`)
		check(serverB.service.GetData(USER_A).currencies.coins == 10, "le repreneur ne lit pas la dernière sauvegarde")
		check(world.store.peek(KEY_A).session.id == "B:1", "verrou non attribué au repreneur")
		serverB.service.Update(USER_A, addCoins(5))
		serverB.service.SavePlayer(USER_A)

		-- L'ancienne session se réveille : elle ne doit rien écrire.
		local stale = serverA.service.SavePlayer(USER_A)
		check(stale.code == Code.LockLost, `code {tostring(stale.code)}`)
		check(world.store.peek(KEY_A).profile.currencies.coins == 15, "l'ancienne session a écrasé le profil")
		check(world.store.peek(KEY_A).session.id == "B:1", "l'ancienne session a repris le verrou")
		check(#serverA.lost == 1 and serverA.lost[1] == USER_A, "perte de session non signalée")
		check(not serverA.service.IsLoaded(USER_A), "ancienne session encore utilisable")
		check(serverA.service.Update(USER_A, addCoins(1)).code == Code.NotLoaded, "Update accepté sur session perdue")
	end)

	case("sessions : libération par une autre session refusée", function(check)
		local world = newWorld()
		local serverA = newServer(world, "A")
		local serverB = newServer(world, "B")
		serverA.service.LoadPlayer(USER_A)
		serverA.service.Update(USER_A, addCoins(1000))
		world.now += config.SessionLock.timeoutSeconds + 1
		serverB.service.LoadPlayer(USER_A)
		serverB.service.Update(USER_A, addCoins(5))
		serverB.service.SavePlayer(USER_A)
		local before = world.store.peek(KEY_A)

		local result = serverA.service.ReleasePlayer(USER_A)
		check(result.code == Code.LockLost, `code {tostring(result.code)}`)
		check(deepEqual(world.store.peek(KEY_A), before), "valeur stockée modifiée par une session non propriétaire")
		check(not serverA.service.IsLoaded(USER_A), "session non retirée de la mémoire")
		check(serverB.service.SavePlayer(USER_A).ok, "le propriétaire ne peut plus sauvegarder")
	end)

	case("sessions : libération du verrou propriétaire uniquement", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.LoadPlayer(USER_B)
		server.service.ReleasePlayer(USER_A)
		check(world.store.peek(KEY_A).session == nil, "verrou du joueur libéré encore présent")
		check(world.store.peek(KEY_B).session ~= nil, "verrou d'un autre joueur retiré")
		check(server.service.IsLoaded(USER_B), "autre joueur déchargé")
	end)

	case("sessions : libération rejouée après une réponse perdue", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(9))
		world.store.failAfterWriteNext(1)
		local result = server.service.ReleasePlayer(USER_A)
		check(result.ok, `code {tostring(result.code)}`)
		local stored = world.store.peek(KEY_A)
		check(stored.profile.currencies.coins == 9 and stored.session == nil, "état final incorrect")
	end)

	case("sessions : joueur parti pendant le chargement", function(check)
		local world = newWorld()
		world.store.seed(KEY_A, { profile = existingProfile() })
		local server = newServer(world, "A")
		local suspended = false
		world.store.setBeforeCall(function()
			if not suspended then
				suspended = true
				coroutine.yield()
			end
		end)

		local result: any
		local loading = coroutine.create(function()
			result = server.service.LoadPlayer(USER_A)
		end)
		coroutine.resume(loading)
		check(coroutine.status(loading) == "suspended", "le chargement aurait dû être en cours")
		check(not server.service.IsLoaded(USER_A), "profil accessible pendant le chargement")
		check(server.service.Update(USER_A, addCoins(1)).code == Code.NotLoaded, "Update accepté pendant le chargement")

		check(server.service.ReleasePlayer(USER_A).ok, "libération pendant le chargement refusée")
		coroutine.resume(loading)
		check(result ~= nil and result.code == Code.Cancelled, `code {tostring(result and result.code)}`)
		check(not server.service.IsLoaded(USER_A), "profil chargé après le départ")
		local stored = world.store.peek(KEY_A)
		check(stored.session == nil, "verrou conservé après le départ")
		local expected = existingProfile()
		expected.lastSaveAt = world.now
		check(deepEqual(stored.profile, expected), "profil altéré par un chargement annulé")
	end)

	case("sessions : retour immédiat sur le même serveur", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.service.LoadPlayer(USER_A)
		server.service.Update(USER_A, addCoins(3))
		server.service.ReleasePlayer(USER_A)
		check(server.service.LoadPlayer(USER_A).ok, "rechargement refusé")
		check(server.service.GetData(USER_A).currencies.coins == 3, "progression perdue")
		check(world.store.peek(KEY_A).session.id == "A:2", "identifiant de verrou non renouvelé")
	end)

	return failures, caseCount
end

return PlayerDataServiceTests
