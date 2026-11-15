--!strict
-- Validation serveur des déplacements (T6, A-26, A-37, décision D-019).
--
-- Contexte : la position d'un personnage Roblox est simulée par son client
-- (propriété réseau). Le serveur ne peut pas l'empêcher de bouger ; il
-- peut observer la position répliquée, juger sa plausibilité, refuser les
-- actions économiques et, en dernier recours, remettre le personnage à la
-- dernière position validée.
--
-- Principes :
--   * une position reçue du client n'est JAMAIS une référence : la
--     référence (ancre) vient d'un échantillon jugé valide, d'un point
--     d'apparition ou d'une correction faits par le serveur ;
--   * vitesse de référence = Boots du profil serveur (SetSpeed), jamais
--     Humanoid.WalkSpeed (A-37) ;
--   * horizontal et vertical jugés séparément ; descente (saut, chute)
--     jamais limitée ;
--   * deux seuils : saut entre deux échantillons (téléportation) et vitesse
--     moyenne sur une fenêtre glissante (rafales réseau absorbées) ;
--   * stratégie graduelle (R1) : une anomalie isolée = observation et
--     journal ; une anomalie revérifiée qui persiste ou des anomalies
--     répétées = correction de position + suspension temporaire de la
--     collecte et de la vente. Jamais d'expulsion ni de bannissement.
--
-- Logique pure : horloge et positions fournies par l'appelant (Bootstrap
-- en production, tests en Lune). Paramètres : MovementSecurityConfig.

local MovementValidator = {}

export type Position = { X: number, Y: number, Z: number }

type Sample = { X: number, Y: number, Z: number, t: number }

export type Verdict = {
	-- "skipped" : non jugé (non suivi, pas d'ancre, période de grâce) ;
	-- "ok" ; "anomaly" ; "correct" : remettre le personnage à `correctionPosition`.
	status: string,
	-- "teleport" | "speed" | "vertical" | "invalid_position"
	kind: string?,
	-- Dépassement du seuil, en studs (0 si sans objet).
	excess: number,
	-- true au premier échantillon d'un nouvel épisode.
	newEpisode: boolean,
	-- Épisodes récents (fenêtre Escalation.repeatedWindowSeconds).
	recentEpisodes: number,
	correctionPosition: Position?,
}

type PlayerState = {
	speed: number?,
	anchor: Sample?,
	valid: { Sample },
	previous: Sample?,
	-- Début de la suite d'échantillons immobiles en cours (gel réseau).
	stationarySince: number?,
	episodeStart: number?,
	episodes: { number },
	lastEpisodeEndAt: number,
	suspendedUntil: number,
	graceUntil: number,
	lastCorrectionAt: number,
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Position exploitable : table de trois nombres finis (ni NaN ni infini).
function MovementValidator.isFinitePosition(position: any): boolean
	return type(position) == "table"
		and isFiniteNumber(position.X)
		and isFiniteNumber(position.Y)
		and isFiniteNumber(position.Z)
end

local function horizontalDistance(a: Position, b: Position): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function toSample(position: Position, now: number): Sample
	return { X = position.X, Y = position.Y, Z = position.Z, t = now }
end

function MovementValidator.new(config: any)
	local players: { [number]: PlayerState } = {}

	local horizontalFactor = config.Horizontal.speedFactor
	local escalation = config.Escalation

	local validator = {}

	local function stateOf(userId: number): PlayerState
		local state = players[userId]
		if state == nil then
			state = {
				speed = nil,
				anchor = nil,
				valid = {},
				previous = nil,
				stationarySince = nil,
				episodeStart = nil,
				episodes = {},
				lastEpisodeEndAt = -math.huge,
				suspendedUntil = -math.huge,
				graceUntil = -math.huge,
				lastCorrectionAt = -math.huge,
			}
			players[userId] = state
		end
		return state
	end

	-- Limites admises depuis une référence validée, après `elapsed` secondes.
	local function horizontalLimit(speed: number, elapsed: number): number
		return speed * horizontalFactor * elapsed + config.Horizontal.slackStuds
	end
	local function riseLimit(speed: number, elapsed: number): number
		return speed * config.Vertical.riseSpeedFactor * elapsed
			+ config.Vertical.jumpAllowanceStuds
			+ config.Vertical.slackStuds
	end

	-- Plus ancienne position validée encore dans la fenêtre ; à défaut,
	-- l'ancre (dernière position validée).
	local function windowReference(state: PlayerState, now: number): Sample?
		local cutoff = now - config.Window.durationSeconds
		local valid = state.valid
		while #valid > 1 and valid[1].t < cutoff do
			table.remove(valid, 1)
		end
		return valid[1] or state.anchor
	end

	local function pruneEpisodes(state: PlayerState, now: number)
		local cutoff = now - escalation.repeatedWindowSeconds
		local episodes = state.episodes
		while #episodes > 0 and episodes[1] < cutoff do
			table.remove(episodes, 1)
		end
	end

	-- Vitesse de référence (Boots du profil serveur). Appelé au chargement,
	-- à l'apparition et après un achat de Boots.
	function validator.SetSpeed(userId: number, speed: number?)
		local state = stateOf(userId)
		state.speed = if isFiniteNumber(speed) and (speed :: number) > 0 then speed else nil
	end

	-- Position imposée par le SERVEUR (apparition, téléportation légitime) :
	-- nouvelle ancre. Ferme l'épisode ouvert sans effacer l'historique des
	-- anomalies ni la suspension (une réapparition ne blanchit rien).
	-- `graceSeconds` (T8, voyage serveur) : échantillons ignorés pendant
	-- cette durée, comme après une correction ; absent = aucune grâce
	-- (comportement T6 inchangé). Jamais plus que la grâce demandée : un
	-- appel sans grâce annule une grâce en cours.
	function validator.Reset(userId: number, position: Position?, now: number, graceSeconds: number?)
		local state = stateOf(userId)
		state.valid = {}
		state.previous = nil
		state.stationarySince = nil
		state.graceUntil = if isFiniteNumber(graceSeconds) and (graceSeconds :: number) > 0
			then now + (graceSeconds :: number)
			else -math.huge
		if state.episodeStart ~= nil then
			state.episodeStart = nil
			state.lastEpisodeEndAt = now
		end
		if position ~= nil and MovementValidator.isFinitePosition(position) then
			local sample = toSample(position, now)
			state.anchor = sample
			table.insert(state.valid, sample)
		else
			state.anchor = nil
		end
	end

	-- Juge une position observée par le serveur. Ne modifie jamais le
	-- personnage : l'appelant applique la correction si status = "correct".
	function validator.Observe(userId: number, position: any, now: number): Verdict
		local state = players[userId]
		local verdict: Verdict = {
			status = "skipped",
			kind = nil,
			excess = 0,
			newEpisode = false,
			recentEpisodes = 0,
			correctionPosition = nil,
		}
		if state == nil or state.speed == nil or state.anchor == nil then
			return verdict
		end
		if now < state.graceUntil then
			-- Position imposée en cours d'aller-retour réseau.
			return verdict
		end
		local speed = state.speed :: number

		local kind: string? = nil
		local excess = 0
		if not MovementValidator.isFinitePosition(position) then
			kind = "invalid_position"
		else
			-- 1. Saut entre deux échantillons consécutifs (téléportation).
			local previous = state.previous
			if previous ~= nil then
				local dt = math.max(now - previous.t, 0)
				local limit = speed * horizontalFactor * dt + config.Teleport.singleSampleStuds
				local step = horizontalDistance(position, previous)
				if step > limit then
					kind, excess = "teleport", step - limit
				end
			end
			-- 2. Vitesse moyenne sur la fenêtre, puis 3. montée.
			local reference = windowReference(state, now) :: Sample
			local elapsed = math.max(now - reference.t, 0)
			if kind == nil then
				local limit = horizontalLimit(speed, elapsed)
				local distance = horizontalDistance(position, reference)
				if distance > limit then
					kind, excess = "speed", distance - limit
				end
			end
			if kind == nil then
				local limit = riseLimit(speed, elapsed)
				local rise = position.Y - reference.Y
				if rise > limit then
					kind, excess = "vertical", rise - limit
				end
			end
		end

		pruneEpisodes(state, now)

		if kind == nil then
			local sample = toSample(position, now)
			-- Position inchangée : immobilité ou gel réseau. La suite garde
			-- l'heure de son début (crédit borné, voir la configuration).
			local anchor = state.anchor :: Sample
			local epsilon = config.Window.stationaryEpsilonStuds
			if horizontalDistance(position, anchor) <= epsilon and math.abs(position.Y - anchor.Y) <= epsilon then
				local runStart = state.stationarySince or anchor.t
				state.stationarySince = runStart
				sample.t = math.max(runStart, now - config.Window.durationSeconds - config.Window.freezeCreditSeconds)
			else
				state.stationarySince = nil
			end
			if state.episodeStart ~= nil then
				state.episodeStart = nil
				state.lastEpisodeEndAt = now
			end
			table.insert(state.valid, sample)
			state.anchor = sample
			-- Heure réelle : le contrôle de téléportation porte sur l'écart effectif.
			state.previous = toSample(position, now)
			verdict.status = "ok"
			verdict.recentEpisodes = #state.episodes
			return verdict
		end

		-- Anomalie. Une position non finie n'est jamais mémorisée.
		state.previous = if kind == "invalid_position" then state.previous else toSample(position, now)
		verdict.kind = kind
		verdict.excess = excess
		if state.episodeStart == nil then
			state.episodeStart = now
			table.insert(state.episodes, now)
			verdict.newEpisode = true
		end
		verdict.recentEpisodes = #state.episodes

		local repeated = #state.episodes >= escalation.repeatedCount
		local persistent = now - (state.episodeStart :: number) >= escalation.persistentEpisodeSeconds
		local allowed = now - state.lastCorrectionAt >= escalation.minCorrectionIntervalSeconds
		if (repeated or persistent) and allowed then
			local anchor = state.anchor :: Sample
			local target = toSample(anchor, now)
			-- Le personnage repart de l'ancre, à l'instant de la correction.
			state.anchor = target
			state.valid = { target }
			state.previous = nil
			state.stationarySince = nil
			state.episodeStart = nil
			state.episodes = {}
			state.lastEpisodeEndAt = now
			state.graceUntil = now + escalation.postCorrectionGraceSeconds
			state.suspendedUntil = now + escalation.suspensionSeconds
			state.lastCorrectionAt = now
			verdict.status = "correct"
			verdict.correctionPosition = { X = target.X, Y = target.Y, Z = target.Z }
			return verdict
		end

		verdict.status = "anomaly"
		return verdict
	end

	-- Une collecte ou une vente peut-elle être acceptée maintenant, à cette
	-- position vue par le serveur ? Retourne (true, nil) ou (false, motif).
	-- Joueur non suivi : true (les autres contrôles serveur s'appliquent).
	function validator.CanAct(userId: number, position: any, now: number): (boolean, string?)
		if not MovementValidator.isFinitePosition(position) then
			return false, "invalid_position"
		end
		local state = players[userId]
		if state == nil then
			return true, nil
		end
		if now < state.suspendedUntil then
			return false, "suspended"
		end
		if state.episodeStart ~= nil then
			return false, "anomaly"
		end
		if now - state.lastEpisodeEndAt < config.Action.holdSeconds then
			return false, "recent_anomaly"
		end
		local anchor = state.anchor
		local speed = state.speed
		if anchor ~= nil and speed ~= nil then
			-- Cohérence avec la dernière position validée (au plus une
			-- période d'échantillonnage plus tôt) : bloque un saut fait
			-- entre deux échantillons, juste avant la demande.
			local elapsed = math.clamp(now - anchor.t, 0, config.Action.maxAnchorAgeSeconds)
			if horizontalDistance(position, anchor) > horizontalLimit(speed, elapsed) then
				return false, "position_mismatch"
			end
			if position.Y - anchor.Y > riseLimit(speed, elapsed) then
				return false, "position_mismatch"
			end
		end
		return true, nil
	end

	-- Lecture pour les tests et le diagnostic.
	function validator.Inspect(userId: number): any?
		local state = players[userId]
		if state == nil then
			return nil
		end
		return {
			anchor = state.anchor,
			episodeOpen = state.episodeStart ~= nil,
			recentEpisodes = #state.episodes,
			suspendedUntil = state.suspendedUntil,
			graceUntil = state.graceUntil,
			lastCorrectionAt = state.lastCorrectionAt,
		}
	end

	-- À appeler quand le joueur quitte.
	function validator.Remove(userId: number)
		players[userId] = nil
	end

	return validator
end

return MovementValidator
