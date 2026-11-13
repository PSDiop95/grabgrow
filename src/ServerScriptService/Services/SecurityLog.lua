--!strict
-- Journal structuré des événements suspects (T6, D-019).
--
-- Une ligne : `[Security] type=<type> user=<UserId> <clé>=<valeur>... count=<n> suppressed=<n>`
--   * count      : occurrences de ce type pour ce joueur depuis son arrivée ;
--   * suppressed : occurrences non écrites depuis la ligne précédente.
-- Seule donnée de joueur : UserId (aucun nom, aucune donnée de compte).
--
-- Limites : une ligne par joueur et par type par période ; plafond global
-- par fenêtre. Ne lève jamais d'erreur : une décision de sécurité ne
-- dépend jamais de la réussite de la journalisation (appel protégé).

local SecurityLog = {}

SecurityLog.Type = table.freeze({
	InvalidPayload = "invalid_payload",
	UnknownId = "unknown_id",
	RateLimited = "rate_limited",
	ProfileNotLoaded = "profile_not_loaded",
	ActionRefused = "action_refused", -- TOO_FAR, NO_CHARACTER, etc.
	MovementRefused = "movement_refused", -- collecte ou vente refusée par MovementValidator
	MovementAnomaly = "movement_anomaly",
	MovementCorrection = "movement_correction",
	EconomyRefused = "economy_refused", -- achat ou déblocage refusé
	DataInconsistency = "data_inconsistency",
})

export type Fields = { [string]: any }

-- Interface minimale attendue par les services (dépendance facultative).
export type Recorder = { Record: (userId: number, eventType: string, fields: Fields?) -> () }

export type Dependencies = {
	clock: () -> number,
	config: any,
	-- Destination d'une ligne (warn en production, table en test).
	sink: ((line: string) -> ())?,
	-- Signalement d'une panne du journal lui-même (warn par défaut).
	fallback: ((message: string) -> ())?,
}

type Counter = { count: number, suppressed: number, lastWrittenAt: number }

local function sanitize(value: any, maxLength: number): string
	if type(value) == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "nonfinite"
		end
		if value % 1 == 0 then
			return string.format("%d", value)
		end
		return string.format("%.2f", value)
	end
	if type(value) == "boolean" then
		return tostring(value)
	end
	local text = if type(value) == "string" then value else type(value)
	text = string.gsub(string.sub(text, 1, maxLength * 2), "[^%w_%-%.:]", "?")
	return string.sub(text, 1, maxLength)
end

function SecurityLog.new(dependencies: Dependencies)
	local clock = dependencies.clock
	local config = dependencies.config
	local fallback = dependencies.fallback or function(message: string)
		warn(message)
	end
	local sink = dependencies.sink or function(line: string)
		warn(line)
	end

	local counters: { [number]: { [string]: Counter } } = {}
	local windowStart = -math.huge
	local windowLines = 0
	local droppedGlobal = 0

	local log = {}

	local function record(userId: number, eventType: string, fields: Fields?)
		local now = clock()
		local perPlayer = counters[userId]
		if perPlayer == nil then
			perPlayer = {}
			counters[userId] = perPlayer
		end
		local counter = perPlayer[eventType]
		if counter == nil then
			counter = { count = 0, suppressed = 0, lastWrittenAt = -math.huge }
			perPlayer[eventType] = counter
		end
		counter.count += 1

		if now - counter.lastWrittenAt < config.perPlayerTypeIntervalSeconds then
			counter.suppressed += 1
			return
		end
		if now - windowStart >= config.globalWindowSeconds then
			if droppedGlobal > 0 then
				sink(`[Security] type=log_overflow dropped={droppedGlobal}`)
			end
			windowStart = now
			windowLines = 0
			droppedGlobal = 0
		end
		if windowLines >= config.globalMaxLines then
			counter.suppressed += 1
			droppedGlobal += 1
			return
		end

		local parts = { `type={sanitize(eventType, config.maxValueLength)}`, `user={sanitize(userId, 20)}` }
		if fields then
			local keys = {}
			for key in pairs(fields) do
				if type(key) == "string" then
					table.insert(keys, key)
				end
			end
			table.sort(keys)
			for _, key in ipairs(keys) do
				table.insert(parts, `{sanitize(key, 24)}={sanitize(fields[key], config.maxValueLength)}`)
			end
		end
		table.insert(parts, `count={counter.count}`)
		table.insert(parts, `suppressed={counter.suppressed}`)
		counter.suppressed = 0
		counter.lastWrittenAt = now
		windowLines += 1
		sink(`[Security] {table.concat(parts, " ")}`)
	end

	-- Enregistre un événement. Ne lève jamais d'erreur.
	function log.Record(userId: number, eventType: string, fields: Fields?)
		local ok, err = pcall(function()
			record(userId, eventType, fields)
		end)
		if not ok then
			pcall(fallback, `[Security] journal indisponible : {tostring(err)}`)
		end
	end

	-- Occurrences d'un type pour un joueur (tests, diagnostic).
	function log.GetCount(userId: number, eventType: string): number
		local perPlayer = counters[userId]
		local counter = if perPlayer then perPlayer[eventType] else nil
		return if counter then counter.count else 0
	end

	-- À appeler quand le joueur quitte.
	function log.Remove(userId: number)
		counters[userId] = nil
	end

	return log
end

-- Enregistreur sans effet (dépendance facultative des services).
function SecurityLog.none(): Recorder
	return {
		Record = function() end,
	}
end

return SecurityLog
