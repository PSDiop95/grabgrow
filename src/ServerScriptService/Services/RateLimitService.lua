--!strict
-- Limite de fréquence par joueur et par action (seau à jetons).
-- Protège les RemoteEvents contre le rejeu massif. Ne bannit jamais : les
-- demandes en trop sont rejetées et journalisées de temps en temps.
--
-- Horloge injectée : testable sans Roblox.

local RateLimitService = {}

export type Limit = {
	-- Nombre de demandes acceptées d'un coup, seau plein.
	burst: number,
	-- Jetons rendus par seconde.
	refillPerSecond: number,
}

export type Dependencies = {
	-- Horloge monotone en secondes (os.clock en production).
	clock: () -> number,
	limits: { [string]: Limit },
	-- Une ligne de journal toutes les N demandes rejetées par joueur et action.
	logEveryRejections: number,
	log: ((level: string, message: string) -> ())?,
}

type Bucket = {
	tokens: number,
	updatedAt: number,
	rejected: number,
}

local function defaultLog(_level: string, message: string)
	warn(`[RateLimit] {message}`)
end

function RateLimitService.new(dependencies: Dependencies)
	local clock = dependencies.clock
	local limits = dependencies.limits
	local log = dependencies.log or defaultLog

	local buckets: { [number]: { [string]: Bucket } } = {}

	local service = {}

	-- Consomme un jeton. false : demande à rejeter.
	-- Une action sans limite configurée est toujours rejetée.
	function service.Allow(userId: number, action: string): boolean
		local limit = limits[action]
		if limit == nil then
			log("error", `action sans limite configurée : {action}`)
			return false
		end

		local now = clock()
		local playerBuckets = buckets[userId]
		if playerBuckets == nil then
			playerBuckets = {}
			buckets[userId] = playerBuckets
		end
		local bucket = playerBuckets[action]
		if bucket == nil then
			bucket = { tokens = limit.burst, updatedAt = now, rejected = 0 }
			playerBuckets[action] = bucket
		end

		local elapsed = math.max(now - bucket.updatedAt, 0)
		bucket.tokens = math.min(limit.burst, bucket.tokens + elapsed * limit.refillPerSecond)
		bucket.updatedAt = now

		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end

		bucket.rejected += 1
		if bucket.rejected % dependencies.logEveryRejections == 1 then
			log("warn", `joueur {userId}, action {action} : {bucket.rejected} demande(s) rejetée(s) depuis son arrivée`)
		end
		return false
	end

	-- Nombre de demandes rejetées pour ce joueur et cette action.
	function service.GetRejectedCount(userId: number, action: string): number
		local playerBuckets = buckets[userId]
		local bucket = if playerBuckets then playerBuckets[action] else nil
		return if bucket then bucket.rejected else 0
	end

	-- À appeler quand le joueur quitte.
	function service.Clear(userId: number)
		buckets[userId] = nil
	end

	return service
end

return RateLimitService
