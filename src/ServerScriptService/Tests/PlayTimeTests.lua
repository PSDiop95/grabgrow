--!strict
-- Tests du temps de jeu (T7, A-21, D-020) : PlayTimeTracker (logique pure)
-- et son branchement dans PlayerDataService, avec un magasin en mémoire.
-- Deux horloges simulées : `now` (os.time, verrous) et `play` (os.clock,
-- temps de jeu). Aucun appel au DataStore réel.

local PlayTimeTests = {}

export type Modules = {
	PlayTimeTracker: any,
	PlayerDataService: any,
	MemoryDataStore: any,
	DataConfig: any,
}

local USER_A = 2001
local KEY_A = "Player_2001"

function PlayTimeTests.run(modules: Modules): ({ string }, number)
	local Tracker = modules.PlayTimeTracker
	local PlayerDataService = modules.PlayerDataService
	local MemoryDataStore = modules.MemoryDataStore
	local config = modules.DataConfig
	local Code = PlayerDataService.Code
	local MAX_STEP = config.PlayTime.maxAccrualSeconds

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

	local function newWorld()
		return { store = MemoryDataStore.new(), now = 1_000_000, play = 500 }
	end

	local function newServer(world: any, serverId: string, withPlayClock: boolean?)
		return PlayerDataService.new({
			store = world.store,
			serverId = serverId,
			clock = function(): number
				return world.now
			end,
			wait = function(seconds: number)
				world.now += seconds
				world.play += seconds
			end,
			spawn = function(callback: () -> ())
				callback()
			end,
			log = function() end,
			playClock = if withPlayClock == false
				then nil
				else function(): number
					return world.play
				end,
		})
	end

	local function storedPlayTime(world: any): number?
		local stored = world.store.peek(KEY_A)
		return if stored and stored.profile then stored.profile.stats.playTimeSeconds else nil
	end

	-- LOGIQUE PURE -----------------------------------------------------------

	case("tracker : intervalle simple compté une fois", function(check)
		local state = Tracker.start(100)
		check(Tracker.accrue(state, 160, MAX_STEP) == 60, "60 s attendues")
		check(Tracker.accrue(state, 160, MAX_STEP) == 0, "même instant compté deux fois")
	end)

	case("tracker : fractions reportées, jamais arrondies vers le haut", function(check)
		local state = Tracker.start(0)
		local total = 0
		for step = 1, 10 do
			total += Tracker.accrue(state, step * 0.4, MAX_STEP)
		end
		check(total == 4, `4 s attendues, trouvé {total}`)
		check(Tracker.accrue(state, 4.9, MAX_STEP) == 0, "0,9 s arrondie vers le haut")
		check(Tracker.accrue(state, 5.0, MAX_STEP) == 1, "fraction perdue")
	end)

	case("tracker : horloge qui recule ou invalide ignorée", function(check)
		local state = Tracker.start(1000)
		check(Tracker.accrue(state, 900, MAX_STEP) == 0, "temps négatif compté")
		check(Tracker.accrue(state, 930, MAX_STEP) == 30, "reprise après recul incorrecte")
		check(Tracker.accrue(state, 0 / 0, MAX_STEP) == 0, "NaN compté")
		check(Tracker.accrue(state, math.huge, MAX_STEP) == 0, "infini compté")
		check(Tracker.accrue(state, 940, MAX_STEP) == 10, "état corrompu par une valeur invalide")
	end)

	case("tracker : intervalle anormal borné", function(check)
		local state = Tracker.start(0)
		check(Tracker.accrue(state, 10_000, MAX_STEP) == MAX_STEP, `borne {MAX_STEP} non appliquée`)
		check(Tracker.accrue(state, 10_060, MAX_STEP) == 60, "intervalle suivant incorrect")
	end)

	case("tracker : ajout borné au maximum", function(check)
		check(Tracker.add(10, 5, 100) == 15, "ajout simple")
		check(Tracker.add(98, 5, 100) == 100, "dépassement non borné")
		check(Tracker.add(10, 0, 100) == 10, "ajout nul")
	end)

	-- PLAYERDATASERVICE ------------------------------------------------------

	case("service : déconnexion normale", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		check(server.LoadPlayer(USER_A).ok, "chargement refusé")
		world.play += 125
		check(server.ReleasePlayer(USER_A).ok, "sortie en échec")
		check(storedPlayTime(world) == 125, `125 s attendues, trouvé {tostring(storedPlayTime(world))}`)
	end)

	case("service : sauvegarde automatique puis sortie, pas de double comptage", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.LoadPlayer(USER_A)
		world.play += 60
		check(server.SavePlayer(USER_A, "auto").ok, "sauvegarde en échec")
		check(storedPlayTime(world) == 60, "60 s attendues après la sauvegarde")
		world.play += 30
		check(server.SavePlayer(USER_A, "auto").ok, "2e sauvegarde en échec")
		world.play += 15
		server.ReleasePlayer(USER_A)
		check(storedPlayTime(world) == 105, `105 s attendues, trouvé {tostring(storedPlayTime(world))}`)
	end)

	case("service : échec de sauvegarde, temps conservé sans double comptage", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.LoadPlayer(USER_A)
		world.play += 60
		world.store.setAlwaysFail(true)
		check(server.SavePlayer(USER_A, "auto").code == Code.StoreError, "échec attendu")
		world.store.setAlwaysFail(false)
		check(storedPlayTime(world) == 0, "écriture partielle")
		-- Les reprises de l'échec ont fait avancer l'horloge (attentes).
		local expected = world.play - 500 + 40
		world.play += 40
		check(server.ReleasePlayer(USER_A).ok, "sortie en échec")
		check(storedPlayTime(world) == expected, `{expected} s attendues, trouvé {tostring(storedPlayTime(world))}`)
	end)

	case("service : déconnexion brutale (serveur perdu), au plus la dernière sauvegarde", function(check)
		local world = newWorld()
		local crashed = newServer(world, "A")
		crashed.LoadPlayer(USER_A)
		world.play += 60
		crashed.SavePlayer(USER_A, "auto")
		world.play += 45 -- perdu : jamais sauvegardé
		-- Le serveur disparaît sans sortie ; le verrou expire.
		world.now += config.SessionLock.timeoutSeconds + 1
		world.play += 3600 -- hors ligne
		local other = newServer(world, "B")
		check(other.LoadPlayer(USER_A).ok, "reprise après expiration refusée")
		check(other.GetData(USER_A).stats.playTimeSeconds == 60, "temps non sauvegardé compté")
		world.play += 20
		other.ReleasePlayer(USER_A)
		check(storedPlayTime(world) == 80, `80 s attendues (hors ligne exclu), trouvé {tostring(storedPlayTime(world))}`)
	end)

	case("service : reconnexion et sessions multiples, hors ligne exclu", function(check)
		local world = newWorld()
		local total = 0
		for index, duration in ipairs({ 30, 75, 12 }) do
			local server = newServer(world, `S{index}`)
			check(server.LoadPlayer(USER_A).ok, `session {index} refusée`)
			world.play += duration
			total += duration
			check(server.ReleasePlayer(USER_A).ok, `sortie {index} en échec`)
			world.play += 10_000 -- hors ligne entre deux sessions
		end
		check(storedPlayTime(world) == total, `{total} s attendues, trouvé {tostring(storedPlayTime(world))}`)
	end)

	case("service : second serveur refusé, aucun comptage parallèle", function(check)
		local world = newWorld()
		local serverA = newServer(world, "A")
		local serverB = newServer(world, "B")
		serverA.LoadPlayer(USER_A)
		local refused = serverB.LoadPlayer(USER_A)
		check(refused.code == Code.SessionLocked, `code {tostring(refused.code)}`)
		local playAfterAttempts = world.play
		world.play += 10
		serverA.ReleasePlayer(USER_A)
		local expected = playAfterAttempts - 500 + 10
		check(storedPlayTime(world) == expected, `{expected} s attendues, trouvé {tostring(storedPlayTime(world))}`)
	end)

	case("service : fermeture du serveur", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.LoadPlayer(USER_A)
		world.play += 42
		server.Shutdown()
		check(storedPlayTime(world) == 42, `42 s attendues, trouvé {tostring(storedPlayTime(world))}`)
	end)

	case("service : serveur figé, intervalle borné", function(check)
		local world = newWorld()
		local server = newServer(world, "A")
		server.LoadPlayer(USER_A)
		world.play += 5_000
		server.ReleasePlayer(USER_A)
		check(storedPlayTime(world) == MAX_STEP, `{MAX_STEP} s attendues, trouvé {tostring(storedPlayTime(world))}`)
	end)

	case("service : sans horloge de jeu, rien n'est compté", function(check)
		local world = newWorld()
		local server = newServer(world, "A", false)
		server.LoadPlayer(USER_A)
		world.play += 100
		server.ReleasePlayer(USER_A)
		check(storedPlayTime(world) == 0, "temps compté sans horloge")
	end)

	case("service : temps existant conservé et prolongé", function(check)
		local world = newWorld()
		local first = newServer(world, "A")
		first.LoadPlayer(USER_A)
		world.play += 100
		first.ReleasePlayer(USER_A)
		local second = newServer(world, "B")
		second.LoadPlayer(USER_A)
		check(second.GetData(USER_A).stats.playTimeSeconds == 100, "temps perdu au chargement")
		world.play += 1
		second.ReleasePlayer(USER_A)
		check(storedPlayTime(world) == 101, "temps non prolongé")
	end)

	return failures, caseCount
end

return PlayTimeTests
