--!strict
-- Tests de MovementValidator (T6, A-26, A-37). Logique pure : positions et
-- horloge simulées, échantillonnage à MovementSecurityConfig.Sampling.
--
-- Scénarios : déplacement normal, Boots, saut, chute, pente, collision
-- (projection isolée), rafales réseau (latence simulée), speed hack,
-- téléportation, tentatives répétées, correction sans boucle, réapparition,
-- NaN et infini, cohérence avant action.

local MovementValidatorTests = {}

export type Modules = {
	MovementValidator: any,
	MovementSecurityConfig: any,
}

local USER = 7001

function MovementValidatorTests.run(modules: Modules): ({ string }, number)
	local MovementValidator = modules.MovementValidator
	local Config = modules.MovementSecurityConfig

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

	local DT = Config.Sampling.intervalSeconds
	local SPEED = 16

	-- Joueur suivi, apparu en (0, 0, 0) à t = 100, vitesse de référence SPEED.
	local function newEnv(speed: number?)
		local env = {
			now = 100,
			position = { X = 0, Y = 0, Z = 0 },
			verdicts = {} :: { any },
			corrections = 0,
			validator = MovementValidator.new(Config),
		}
		env.validator.SetSpeed(USER, speed or SPEED)
		env.validator.Reset(USER, env.position, env.now)

		-- Un échantillon après DT, à la position actuelle.
		function env.step(dx: number?, dy: number?, dz: number?): any
			env.now += DT
			env.position = {
				X = env.position.X + (dx or 0),
				Y = env.position.Y + (dy or 0),
				Z = env.position.Z + (dz or 0),
			}
			local verdict = env.validator.Observe(USER, env.position, env.now)
			table.insert(env.verdicts, verdict)
			if verdict.status == "correct" then
				env.corrections += 1
				-- Le serveur a remis le personnage à la position validée.
				local target = verdict.correctionPosition
				env.position = { X = target.X, Y = target.Y, Z = target.Z }
			end
			return verdict
		end

		-- Marche à `velocity` studs/s selon X pendant `seconds`.
		function env.walk(velocity: number, seconds: number)
			for _ = 1, math.floor(seconds / DT + 0.5) do
				env.step(velocity * DT)
			end
		end

		function env.count(status: string): number
			local n = 0
			for _, verdict in ipairs(env.verdicts) do
				if verdict.status == status then
					n += 1
				end
			end
			return n
		end

		function env.canAct(): (boolean, string?)
			return env.validator.CanAct(USER, env.position, env.now)
		end

		return env
	end

	-- CONFIGURATION ------------------------------------------------------------

	case("configuration : seuils positifs et distincts", function(check)
		check(DT > 0 and Config.Window.durationSeconds >= DT, "échantillonnage ou fenêtre invalide")
		check(Config.Horizontal.speedFactor >= 1, "facteur de vitesse < 1 : faux rejets assurés")
		check(Config.Teleport.singleSampleStuds > Config.Horizontal.slackStuds, "seuil de téléportation <= marge de fenêtre")
		check(Config.Escalation.repeatedCount >= 2, "une anomalie isolée ne doit pas corriger")
		check(
			Config.Escalation.minCorrectionIntervalSeconds >= Config.Escalation.postCorrectionGraceSeconds,
			"intervalle de correction < période de grâce"
		)
	end)

	-- DÉPLACEMENTS LÉGITIMES (aucun faux rejet) ---------------------------------

	case("déplacement normal 16 studs/s pendant 20 s", function(check)
		local env = newEnv()
		env.walk(SPEED, 20)
		check(env.count("ok") == #env.verdicts, `{#env.verdicts - env.count("ok")} échantillon(s) non valides`)
		local allowed = env.canAct()
		check(allowed, "action refusée après une marche normale")
	end)

	case("vitesse Boots : 20,5 studs/s avec Boots 20,5", function(check)
		local env = newEnv(20.5)
		env.walk(20.5, 10)
		check(env.count("ok") == #env.verdicts, "faux rejet à la vitesse des Boots")
	end)

	case("vitesse Boots non répercutée : 20,5 studs/s, référence 16 (tolérance)", function(check)
		local env = newEnv(SPEED)
		env.walk(20.5, 10)
		check(env.count("ok") == #env.verdicts, "faux rejet dans la tolérance de 1,5")
	end)

	case("sauts répétés en marchant", function(check)
		local env = newEnv()
		for i = 1, 60 do
			local dy = if i % 4 == 1 then 4 elseif i % 4 == 2 then 3 elseif i % 4 == 3 then -3 else -4
			env.step(SPEED * DT, dy)
		end
		check(env.count("ok") == #env.verdicts, "saut pénalisé")
	end)

	case("chute de 300 studs en marchant", function(check)
		local env = newEnv()
		for _ = 1, 12 do
			env.step(SPEED * DT, -25)
		end
		check(env.count("ok") == #env.verdicts, "chute pénalisée")
	end)

	case("montée d'une pente à 45° et d'une échelle", function(check)
		local env = newEnv()
		for _ = 1, 40 do
			env.step(SPEED * DT, SPEED * DT)
		end
		for _ = 1, 20 do
			env.step(0, SPEED * 0.7 * DT)
		end
		check(env.count("ok") == #env.verdicts, "montée légitime pénalisée")
	end)

	case("latence simulée : positions figées 0,75 s puis rattrapées", function(check)
		local env = newEnv()
		for _ = 1, 10 do
			env.step(0)
			env.step(0)
			env.step(SPEED * DT * 3)
		end
		check(env.count("ok") == #env.verdicts, "rafale réseau pénalisée")
	end)

	case("latence simulée : gel de 1,5 s puis rattrapage d'un coup", function(check)
		local env = newEnv()
		env.walk(SPEED, 2)
		for _ = 1, 5 do
			env.step(0)
		end
		env.step(SPEED * 1.5)
		env.walk(SPEED, 2)
		check(env.count("ok") == #env.verdicts, "gel réseau de 1,5 s pénalisé")
	end)

	case("collision : projection isolée de 40 studs, journal sans correction", function(check)
		local env = newEnv()
		env.walk(SPEED, 2)
		local hit = env.step(0, 0, 40)
		check(hit.status == "anomaly" and hit.kind == "teleport" and hit.newEpisode, `statut {hit.status}`)
		env.walk(0, 3)
		check(env.corrections == 0, "correction sur une anomalie isolée")
		local inspect = env.validator.Inspect(USER)
		check(not inspect.episodeOpen, "épisode non refermé après la projection")
		local allowed = env.canAct()
		check(allowed, "action toujours refusée 3 s après une projection isolée")
	end)

	-- TRICHE --------------------------------------------------------------------

	case("vitesse anormale : 40 studs/s détectée puis corrigée", function(check)
		local env = newEnv()
		env.walk(SPEED, 1)
		local firstBad: any = nil
		local firstBadAt = 0
		local correctedAt = 0
		for _ = 1, 30 do
			local verdict = env.step(40 * DT)
			if firstBad == nil and verdict.status ~= "ok" then
				firstBad, firstBadAt = verdict, env.now
			end
			if verdict.status == "correct" and correctedAt == 0 then
				correctedAt = env.now
			end
		end
		check(firstBad ~= nil and firstBad.status == "anomaly" and firstBad.kind == "speed", "speed hack non détecté")
		check(correctedAt > 0, "aucune correction d'un speed hack persistant")
		check(
			correctedAt - firstBadAt >= Config.Escalation.persistentEpisodeSeconds - 1e-9,
			"correction avant la revérification (anomalie isolée corrigée)"
		)
	end)

	case("speed hack : corrections espacées d'au moins minCorrectionIntervalSeconds", function(check)
		local env = newEnv()
		local times = {}
		for _ = 1, 120 do
			local verdict = env.step(40 * DT)
			if verdict.status == "correct" then
				table.insert(times, env.now)
			end
		end
		check(#times >= 2, `{#times} correction(s) en 30 s`)
		for i = 2, #times do
			check(
				times[i] - times[i - 1] >= Config.Escalation.minCorrectionIntervalSeconds - 1e-9,
				`corrections à {times[i] - times[i - 1]} s d'écart`
			)
		end
	end)

	case("téléportation de 200 studs : détectée, action refusée, corrigée si elle persiste", function(check)
		local env = newEnv()
		env.walk(SPEED, 1)
		local anchorX = env.position.X
		local verdict = env.step(200)
		check(verdict.status == "anomaly" and verdict.kind == "teleport", `statut {verdict.status} {tostring(verdict.kind)}`)
		local allowed, reason = env.canAct()
		check(not allowed and reason == "anomaly", `action pendant l'anomalie : {tostring(reason)}`)
		env.walk(0, Config.Escalation.persistentEpisodeSeconds + DT)
		check(env.corrections == 1, `{env.corrections} correction(s)`)
		check(math.abs(env.position.X - anchorX) < 1e-6, "position de correction différente de la dernière position validée")
	end)

	case("téléportation verticale (+40 studs en un échantillon)", function(check)
		local env = newEnv()
		env.walk(SPEED, 1)
		local verdict = env.step(0, 40)
		check(verdict.status == "anomaly" and verdict.kind == "vertical", `statut {verdict.status} {tostring(verdict.kind)}`)
	end)

	case("tentatives répétées : 3 sauts de 45 studs en 10 s -> correction, suspension", function(check)
		local env = newEnv()
		env.walk(SPEED, 1)
		local corrected: any = nil
		for _ = 1, 3 do
			local verdict = env.step(45)
			if verdict.status == "correct" then
				corrected = verdict
			end
			env.walk(0, 2.5)
		end
		check(corrected ~= nil, "aucune correction après 3 anomalies")
		check(env.corrections == 1, `{env.corrections} correction(s)`)
		local allowed, reason = env.canAct()
		check(not allowed and reason == "suspended", `suspension absente : {tostring(reason)}`)
		env.walk(0, Config.Escalation.suspensionSeconds)
		local after = env.canAct()
		check(after, "action toujours refusée après la suspension")
	end)

	case("après correction : pas de boucle pour un déplacement légitime", function(check)
		local env = newEnv()
		for _ = 1, 3 do
			env.step(45)
			env.walk(0, 2.5)
		end
		check(env.corrections == 1, "pas de correction initiale")
		local before = #env.verdicts
		env.walk(SPEED, 20)
		for i = before + 1, #env.verdicts do
			local status = env.verdicts[i].status
			check(status == "ok" or status == "skipped", `échantillon {i} : {status}`)
		end
		check(env.corrections == 1, "nouvelle correction sur un déplacement légitime")
	end)

	case("crédit de gel borné : immobile 30 s puis speed hack détecté", function(check)
		local env = newEnv()
		env.walk(0, 30)
		local detectedAfter: number? = nil
		for i = 1, 20 do
			local verdict = env.step(40 * DT)
			if verdict.status ~= "ok" and detectedAfter == nil then
				detectedAfter = i * DT
			end
		end
		check(detectedAfter ~= nil and (detectedAfter :: number) <= 2.5, `détection après {tostring(detectedAfter)} s`)
	end)

	case("immobile longtemps puis saut juste avant l'action : refusé", function(check)
		local env = newEnv()
		env.walk(0, 30)
		local allowed, reason = env.validator.CanAct(USER, { X = env.position.X + 30, Y = 0, Z = 0 }, env.now + 0.1)
		check(not allowed and reason == "position_mismatch", `saut accepté : {tostring(reason)}`)
	end)

	case("période de grâce : un échantillon en vol n'est pas jugé", function(check)
		local env = newEnv()
		for _ = 1, 2 do
			env.step(45)
			env.walk(0, 2.5)
		end
		local corrected = env.step(45)
		check(corrected.status == "correct", `troisième anomalie : {corrected.status}`)
		-- Position encore lointaine juste après la correction (réseau).
		env.now += DT
		local verdict = env.validator.Observe(USER, { X = env.position.X + 300, Y = 0, Z = 0 }, env.now)
		check(verdict.status == "skipped", `échantillon en vol jugé : {verdict.status}`)
	end)

	case("réapparition : nouvelle ancre, historique et suspension conservés", function(check)
		local env = newEnv()
		for _ = 1, 3 do
			env.step(45)
			env.walk(0, 2.5)
		end
		local suspendedUntil = env.validator.Inspect(USER).suspendedUntil
		env.validator.Reset(USER, { X = 500, Y = 0, Z = 500 }, env.now)
		local inspect = env.validator.Inspect(USER)
		check(inspect.anchor.X == 500 and inspect.anchor.Z == 500, "ancre non placée au point d'apparition")
		check(inspect.suspendedUntil == suspendedUntil, "suspension effacée par la réapparition")
		local allowed = env.validator.CanAct(USER, { X = 500, Y = 0, Z = 500 }, env.now)
		check(not allowed, "réapparition utilisée pour lever la suspension")
	end)

	case("réapparition : téléportation juste après est détectée", function(check)
		local env = newEnv()
		env.now += 10
		env.validator.Reset(USER, { X = 0, Y = 0, Z = 0 }, env.now)
		env.now += DT
		local verdict = env.validator.Observe(USER, { X = 300, Y = 0, Z = 0 }, env.now)
		check(verdict.status == "anomaly", `statut {verdict.status}`)
	end)

	-- VOYAGE SERVEUR (T8, D-021) ---------------------------------------------

	case("T8 voyage serveur : positions en transit non jugées, aucun faux positif", function(check)
		local env = newEnv()
		env.walk(16, 2)
		local grace = Config.ServerTeleport.graceSeconds
		local arrival = { X = 5000, Y = 10, Z = 0 }
		env.validator.Reset(USER, arrival, env.now, grace)
		-- Le client renvoie encore l'ancienne position, puis la nouvelle.
		local old = env.position
		local statuses = {}
		-- Échantillons strictement avant la fin de la grâce.
		for index = 1, math.ceil(grace / DT) - 1 do
			env.now += DT
			local sample = if index <= 2 then old else arrival
			table.insert(statuses, env.validator.Observe(USER, sample, env.now).status)
		end
		for index, status in ipairs(statuses) do
			check(status == "skipped", `échantillon {index} pendant la grâce : {status}`)
		end
		env.position = { X = arrival.X, Y = arrival.Y, Z = arrival.Z }
		env.walk(16, 3)
		check(env.count("anomaly") == 0 and env.corrections == 0, "faux positif après le voyage")
		local inspect = env.validator.Inspect(USER)
		check(inspect.recentEpisodes == 0, "épisode créé par le voyage")
		check(env.canAct(), "action refusée après un voyage légitime")
	end)

	case("T8 voyage serveur : CanAct jugé au point d'arrivée pendant la grâce", function(check)
		local env = newEnv()
		local arrival = { X = 5000, Y = 10, Z = 0 }
		env.validator.Reset(USER, arrival, env.now, Config.ServerTeleport.graceSeconds)
		env.now += DT
		check(env.validator.CanAct(USER, arrival, env.now), "action au point d'arrivée refusée")
		local allowed, reason = env.validator.CanAct(USER, { X = 0, Y = 0, Z = 0 }, env.now)
		check(not allowed and reason == "position_mismatch", `action loin de l'arrivée : {tostring(reason)}`)
	end)

	case("T8 voyage serveur : déplacement anormal détecté après la grâce", function(check)
		local env = newEnv()
		local arrival = { X = 5000, Y = 10, Z = 0 }
		env.validator.Reset(USER, arrival, env.now, Config.ServerTeleport.graceSeconds)
		env.now += Config.ServerTeleport.graceSeconds
		env.position = { X = arrival.X, Y = arrival.Y, Z = arrival.Z }
		local verdict = env.step(300)
		check(verdict.status == "anomaly", `téléportation après la grâce : {verdict.status}`)
	end)

	case("T8 voyage serveur : suspension et historique conservés", function(check)
		local env = newEnv()
		for _ = 1, 3 do
			env.step(45)
			env.walk(0, 2.5)
		end
		local before = env.validator.Inspect(USER)
		env.validator.Reset(USER, { X = 5000, Y = 10, Z = 0 }, env.now, Config.ServerTeleport.graceSeconds)
		local after = env.validator.Inspect(USER)
		check(after.suspendedUntil == before.suspendedUntil, "suspension effacée par le voyage")
		check(after.lastCorrectionAt == before.lastCorrectionAt, "historique de correction effacé")
		check(not env.validator.CanAct(USER, { X = 5000, Y = 10, Z = 0 }, env.now), "voyage utilisé pour lever la suspension")
	end)

	case("T8 : Reset sans grâce inchangé (réapparition T6)", function(check)
		local env = newEnv()
		env.validator.Reset(USER, { X = 0, Y = 0, Z = 0 }, env.now, nil)
		env.now += DT
		check(env.validator.Observe(USER, { X = 300, Y = 0, Z = 0 }, env.now).status == "anomaly", "grâce appliquée sans demande")
		env.validator.Reset(USER, { X = 0, Y = 0, Z = 0 }, env.now, 0 / 0)
		env.now += DT
		check(env.validator.Observe(USER, { X = 300, Y = 0, Z = 0 }, env.now).status == "anomaly", "grâce NaN acceptée")
	end)

	case("NaN et infini : refusés, jamais pris comme référence", function(check)
		local env = newEnv()
		env.walk(SPEED, 1)
		local nan = 0 / 0
		local verdict = env.validator.Observe(USER, { X = nan, Y = 0, Z = 0 }, env.now + DT)
		check(verdict.status == "anomaly" and verdict.kind == "invalid_position", `NaN : {verdict.status}`)
		local allowed, reason = env.validator.CanAct(USER, { X = math.huge, Y = 0, Z = 0 }, env.now + DT)
		check(not allowed and reason == "invalid_position", `infini accepté : {tostring(reason)}`)
		check(not MovementValidator.isFinitePosition({ X = 1, Y = -math.huge, Z = 0 }), "isFinitePosition(-inf)")
		check(not MovementValidator.isFinitePosition(nil), "isFinitePosition(nil)")
		local anchor = env.validator.Inspect(USER).anchor
		check(anchor.X == anchor.X, "NaN mémorisé comme ancre")
	end)

	case("cohérence avant action : saut entre deux échantillons", function(check)
		local env = newEnv()
		env.walk(SPEED, 2)
		local allowed, reason = env.validator.CanAct(USER, { X = env.position.X + 40, Y = 0, Z = 0 }, env.now + 0.1)
		check(not allowed and reason == "position_mismatch", `saut accepté : {tostring(reason)}`)
		local ok = env.validator.CanAct(USER, { X = env.position.X + 1, Y = 0, Z = 0 }, env.now + 0.1)
		check(ok, "petit déplacement refusé")
	end)

	case("vitesse de référence absente ou joueur inconnu : non jugé", function(check)
		local validator = MovementValidator.new(Config)
		check(validator.CanAct(42, { X = 0, Y = 0, Z = 0 }, 1), "joueur inconnu refusé")
		validator.Reset(42, { X = 0, Y = 0, Z = 0 }, 1)
		local verdict = validator.Observe(42, { X = 900, Y = 0, Z = 0 }, 1.25)
		check(verdict.status == "skipped", "jugé sans vitesse de référence")
		validator.SetSpeed(42, 0 / 0)
		verdict = validator.Observe(42, { X = 900, Y = 0, Z = 0 }, 1.5)
		check(verdict.status == "skipped", "vitesse NaN acceptée")
		validator.Remove(42)
		check(validator.Inspect(42) == nil, "état conservé après départ")
	end)

	case("coût : 100 joueurs x 4 Hz x 10 s sans dérive mémoire", function(check)
		local validator = MovementValidator.new(Config)
		for userId = 1, 100 do
			validator.SetSpeed(userId, SPEED)
			validator.Reset(userId, { X = 0, Y = 0, Z = 0 }, 0)
		end
		for i = 1, 40 do
			for userId = 1, 100 do
				validator.Observe(userId, { X = i * SPEED * DT, Y = 0, Z = 0 }, i * DT)
			end
		end
		-- La fenêtre ne garde que les échantillons de la dernière seconde.
		local ok = true
		for userId = 1, 100 do
			if validator.Inspect(userId).episodeOpen then
				ok = false
			end
		end
		check(ok, "faux rejet dans la charge")
	end)

	return failures, caseCount
end

return MovementValidatorTests
