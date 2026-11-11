--!strict
-- Tests de ResourceSpawner (cycle ACTIVE -> COLLECTED -> RESPAWNING ->
-- ACTIVE) et de RateLimitService. Horloge et minuterie simulées.

local ResourceSpawnerTests = {}

export type Modules = {
	ResourceSpawner: any,
	RateLimitService: any,
	ResourceConfig: any,
}

local ORIGIN = { X = 0, Y = 0, Z = 0 }

-- Retourne (liste des échecs, nombre de cas exécutés).
function ResourceSpawnerTests.run(modules: Modules): ({ string }, number)
	local ResourceSpawner = modules.ResourceSpawner
	local RateLimitService = modules.RateLimitService
	local ResourceConfig = modules.ResourceConfig
	local State = ResourceSpawner.State

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

	local function newEnv()
		local env = {
			now = 0,
			timers = {} :: { { at: number, callback: () -> () } },
			changes = {} :: { string },
		}
		env.spawner = ResourceSpawner.new({
			schedule = function(delaySeconds: number, callback: () -> ())
				table.insert(env.timers, { at = env.now + delaySeconds, callback = callback })
			end,
			onStateChanged = function(nodeId: string, state: string)
				table.insert(env.changes, `{nodeId}:{state}`)
			end,
		})
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
		return env
	end

	-- RESOURCESPAWNER ------------------------------------------------------

	case("enregistrement : nœud actif, doublon et type inconnu refusés", function(check)
		local env = newEnv()
		check(env.spawner.Register("green_leaf_001", "green_leaf", ORIGIN), "enregistrement refusé")
		check(env.spawner.Count() == 1, "compte incorrect")
		local node = env.spawner.GetNode("green_leaf_001")
		check(node ~= nil and node.state == State.Active, "nœud non actif")
		check(node ~= nil and node.resourceType == "green_leaf", "type incorrect")

		check(not env.spawner.Register("green_leaf_001", "wood", ORIGIN), "doublon accepté")
		check(env.spawner.GetNode("green_leaf_001").resourceType == "green_leaf", "doublon a remplacé le nœud")
		check(not env.spawner.Register("gold_001", "gold", ORIGIN), "type inconnu accepté")
		check(not env.spawner.Register("", "wood", ORIGIN), "identifiant vide accepté")
		check(env.spawner.Count() == 1, "compte modifié par un refus")
		check(env.spawner.GetNode("absent") == nil, "nœud inconnu retourné")
	end)

	case("la vue d'un nœud est une copie", function(check)
		local env = newEnv()
		env.spawner.Register("wood_001", "wood", ORIGIN)
		local node = env.spawner.GetNode("wood_001")
		node.state = State.Respawning
		check(env.spawner.GetNode("wood_001").state == State.Active, "état interne modifié par la vue")
		check(env.spawner.TryCollect("wood_001"), "collecte refusée après modification de la vue")
	end)

	case("collecte : une seule fois par cycle", function(check)
		local env = newEnv()
		env.spawner.Register("stone_001", "stone", ORIGIN)
		check(env.spawner.TryCollect("stone_001"), "première collecte refusée")
		check(env.spawner.GetNode("stone_001").state == State.Respawning, "état après collecte")
		check(not env.spawner.TryCollect("stone_001"), "seconde collecte acceptée")
		check(not env.spawner.TryCollect("absent"), "collecte d'un nœud inconnu acceptée")
		check(#env.timers == 1, `{#env.timers} minuterie(s) au lieu d'une`)
		check(
			table.concat(env.changes, " ") == `stone_001:{State.Collected} stone_001:{State.Respawning}`,
			`transitions : {table.concat(env.changes, " ")}`
		)
	end)

	case("réapparition après le délai configuré de chaque ressource", function(check)
		for resourceType, definition in pairs(ResourceConfig) do
			local env = newEnv()
			local nodeId = `{resourceType}_001`
			env.spawner.Register(nodeId, resourceType, ORIGIN)
			env.spawner.TryCollect(nodeId)
			env.advance(definition.respawnSeconds - 0.01)
			check(env.spawner.GetNode(nodeId).state == State.Respawning, `{resourceType} : réapparue trop tôt`)
			check(not env.spawner.TryCollect(nodeId), `{resourceType} : collectable pendant la réapparition`)
			env.advance(0.01)
			check(env.spawner.GetNode(nodeId).state == State.Active, `{resourceType} : non réapparue`)
			check(env.changes[#env.changes] == `{nodeId}:{State.Active}`, `{resourceType} : transition non signalée`)
			check(env.spawner.TryCollect(nodeId), `{resourceType} : non collectable après réapparition`)
		end
	end)

	case("nœuds indépendants", function(check)
		local env = newEnv()
		env.spawner.Register("green_leaf_001", "green_leaf", ORIGIN)
		env.spawner.Register("green_leaf_002", "green_leaf", ORIGIN)
		env.spawner.TryCollect("green_leaf_001")
		check(env.spawner.GetNode("green_leaf_002").state == State.Active, "le second nœud a changé d'état")
		check(env.spawner.TryCollect("green_leaf_002"), "second nœud non collectable")
	end)

	case("nœud retiré : minuterie sans effet, pas de doublon", function(check)
		local env = newEnv()
		env.spawner.Register("wood_001", "wood", ORIGIN)
		env.spawner.TryCollect("wood_001")
		check(env.spawner.Unregister("wood_001"), "retrait refusé")
		check(not env.spawner.Unregister("wood_001"), "second retrait accepté")
		-- Même identifiant réenregistré puis collecté avant l'ancienne échéance.
		env.spawner.Register("wood_001", "wood", ORIGIN)
		env.advance(1)
		env.spawner.TryCollect("wood_001")
		local changesBefore = #env.changes
		env.advance(ResourceConfig.wood.respawnSeconds - 1)
		check(#env.changes == changesBefore, "l'ancienne minuterie a agi sur le nouveau nœud")
		check(env.spawner.GetNode("wood_001").state == State.Respawning, "réapparition anticipée")
		env.advance(1)
		check(env.spawner.GetNode("wood_001").state == State.Active, "le nouveau nœud n'est pas réapparu")

		env.spawner.TryCollect("wood_001")
		env.spawner.Destroy()
		check(env.spawner.Count() == 0, "nœuds restants après Destroy")
		env.advance(10)
		check(env.spawner.GetNode("wood_001") == nil, "nœud recréé par une minuterie")
	end)

	-- RATELIMITSERVICE -----------------------------------------------------

	local function newLimiter()
		local env = { now = 0, logs = {} :: { string } }
		env.limiter = RateLimitService.new({
			clock = function(): number
				return env.now
			end,
			limits = { Collect = { burst = 3, refillPerSecond = 2 } },
			logEveryRejections = 5,
			log = function(level: string, message: string)
				table.insert(env.logs, `{level} {message}`)
			end,
		})
		return env
	end

	case("limite : rafale puis rejet, recharge avec le temps", function(check)
		local env = newLimiter()
		for index = 1, 3 do
			check(env.limiter.Allow(1, "Collect"), `demande {index} rejetée`)
		end
		check(not env.limiter.Allow(1, "Collect"), "quatrième demande acceptée")
		env.now += 0.5
		check(env.limiter.Allow(1, "Collect"), "jeton non rendu après 0,5 s")
		check(not env.limiter.Allow(1, "Collect"), "plus d'un jeton rendu en 0,5 s")
		env.now += 100
		local accepted = 0
		for _ = 1, 10 do
			if env.limiter.Allow(1, "Collect") then
				accepted += 1
			end
		end
		check(accepted == 3, `rafale de {accepted} après une longue attente (plafond 3)`)
	end)

	case("limite : par joueur, action inconnue rejetée, nettoyage", function(check)
		local env = newLimiter()
		for _ = 1, 3 do
			env.limiter.Allow(1, "Collect")
		end
		check(not env.limiter.Allow(1, "Collect"), "joueur 1 non limité")
		check(env.limiter.Allow(2, "Collect"), "joueur 2 limité par le joueur 1")
		check(not env.limiter.Allow(2, "Inconnue"), "action sans limite acceptée")
		check(env.limiter.GetRejectedCount(1, "Collect") == 1, "compteur de rejets incorrect")
		env.limiter.Clear(1)
		check(env.limiter.GetRejectedCount(1, "Collect") == 0, "compteur conservé après Clear")
		check(env.limiter.Allow(1, "Collect"), "joueur 1 toujours limité après Clear")
	end)

	case("limite : journal périodique, sans bannissement", function(check)
		local env = newLimiter()
		for _ = 1, 3 + 11 do
			env.limiter.Allow(1, "Collect")
		end
		-- 11 rejets, une ligne au 1er, au 6e et au 11e.
		check(#env.logs == 3, `{#env.logs} ligne(s) de journal`)
		env.now += 10
		check(env.limiter.Allow(1, "Collect"), "joueur toujours bloqué après attente")
	end)

	return failures, caseCount
end

return ResourceSpawnerTests
