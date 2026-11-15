--!strict
-- Voyage entre mondes (T8, décision D-021), entièrement décidé par le serveur.
--
-- Le client n'envoie qu'un identifiant ({ worldId = "GoldenDesert" }) ; il ne
-- choisit jamais la position d'arrivée. Contrôles, dans l'ordre :
--   limite de fréquence -> profil chargé -> payload (PayloadValidator) ->
--   monde connu -> monde débloqué dans le profil serveur -> point d'arrivée
--   présent sur la carte -> personnage vivant, déplacé par le serveur.
--
-- Le déplacement lui-même (`teleport`, Bootstrap) place le personnage puis
-- refait les références de déplacement au point d'arrivée
-- (MovementValidator.Reset avec grâce, CollectionService.ResetTravelReference) :
-- un voyage légitime ne déclenche pas de faux positif et ne permet pas de
-- collecter ailleurs qu'au point d'arrivée. Suspension et historique des
-- anomalies T6 conservés.
--
-- Aucun Coin, aucune écriture de profil : le voyage ne touche pas les
-- données persistantes (position non sauvegardée, D-021 D5).
--
-- Dépendances injectées : testable sans Roblox.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.TravelSecurityConfig)
local SecurityLog = require(script.Parent.SecurityLog)
local MovementValidator = require(script.Parent.Parent.Systems.MovementValidator)
local PayloadValidator = require(script.Parent.Parent.Systems.PayloadValidator)

local WorldTravelService = {}

local ResultCode = Remotes.ResultCode

-- Nom de la limite dans TravelSecurityConfig.RateLimits.
WorldTravelService.RATE_LIMIT_ACTION = "Travel"

export type Position = { X: number, Y: number, Z: number }

export type Result = {
	ok: boolean,
	code: string,
	worldId: string?,
	-- true : ne pas répondre au client (rejets en rafale déjà signalés).
	silent: boolean,
}

export type Dependencies = {
	playerData: { GetData: (userId: number) -> any? },
	rateLimit: { Allow: (userId: number, action: string) -> boolean, Clear: (userId: number) -> () },
	clock: () -> number,
	-- Position d'arrivée du monde (carte, serveur), ou nil.
	getArrival: (worldId: string) -> Position?,
	-- Déplace le personnage à `position` et refait les références de
	-- déplacement ; false si le personnage est absent ou mort.
	teleport: (userId: number, position: Position) -> boolean,
	security: SecurityLog.Recorder?,
	log: ((level: string, message: string) -> ())?,
}

local function defaultLog(level: string, message: string)
	if level == "info" then
		print(`[Travel] {message}`)
	else
		warn(`[Travel] {level} : {message}`)
	end
end

function WorldTravelService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local rateLimit = dependencies.rateLimit
	local clock = dependencies.clock
	local getArrival = dependencies.getArrival
	local teleport = dependencies.teleport
	local security: SecurityLog.Recorder = dependencies.security or SecurityLog.none()
	local log = dependencies.log or defaultLog
	local Event = SecurityLog.Type
	local ACTION = "Travel"

	local lastRateNoticeAt: { [number]: number } = {}

	local service = {}

	local function reject(code: string, worldId: string?, silent: boolean?): Result
		return { ok = false, code = code, worldId = worldId, silent = silent == true }
	end

	-- Traite une demande de voyage. `payload` vient du client : non fiable.
	-- `extraArgumentCount` : arguments reçus après le payload (0 attendu).
	function service.HandleRequest(userId: number, payload: any, extraArgumentCount: number?): Result
		if not rateLimit.Allow(userId, WorldTravelService.RATE_LIMIT_ACTION) then
			local now = clock()
			local last = lastRateNoticeAt[userId] or -math.huge
			local noticed = now - last < SecurityConfig.RateLimitFeedback.noticeIntervalSeconds
			if not noticed then
				lastRateNoticeAt[userId] = now
			end
			security.Record(userId, Event.RateLimited, { action = ACTION })
			return reject(ResultCode.RateLimited, nil, noticed)
		end

		local profile = playerData.GetData(userId)
		if profile == nil then
			security.Record(userId, Event.ProfileNotLoaded, { action = ACTION })
			return reject(ResultCode.ProfileNotLoaded)
		end

		local worldId, payloadReason =
			PayloadValidator.readId(payload, "worldId", SecurityConfig.Payload.maxIdLength, extraArgumentCount)
		if worldId == nil then
			security.Record(userId, Event.InvalidPayload, { action = ACTION, reason = payloadReason })
			return reject(ResultCode.InvalidTarget)
		end
		if WorldConfig[worldId] == nil then
			security.Record(userId, Event.UnknownId, { action = ACTION, id = worldId })
			return reject(ResultCode.InvalidTarget)
		end

		local worlds = profile.worlds
		if type(worlds) ~= "table" or worlds[worldId] ~= true then
			security.Record(userId, Event.ActionRefused, { action = ACTION, code = ResultCode.WorldLocked, id = worldId })
			return reject(ResultCode.WorldLocked, worldId)
		end

		-- Monde débloqué mais encore sans île sur la carte : refus normal,
		-- non journalisé (l'interface peut l'afficher comme « à venir »).
		local arrival = getArrival(worldId)
		if arrival == nil or not MovementValidator.isFinitePosition(arrival) then
			return reject(ResultCode.WorldUnavailable, worldId)
		end

		if not teleport(userId, arrival) then
			return reject(ResultCode.NoCharacter, worldId)
		end
		log("info", `joueur {userId} : voyage vers {worldId}`)
		return { ok = true, code = ResultCode.Success, worldId = worldId, silent = false }
	end

	-- À appeler quand le joueur quitte.
	function service.RemovePlayer(userId: number)
		lastRateNoticeAt[userId] = nil
		rateLimit.Clear(userId)
	end

	return service
end

return WorldTravelService
