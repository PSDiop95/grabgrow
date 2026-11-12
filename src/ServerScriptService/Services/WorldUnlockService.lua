--!strict
-- Déblocage des mondes (T4, décision D-015), entièrement validé côté serveur.
--
-- Le client n'envoie qu'un identifiant ({ worldId = "GoldenDesert" }) ; la
-- confirmation avant achat est une étape d'interface, jamais une preuve.
--
-- Conditions (WorldConfig, Bible 6 ; ordre strict D-015) :
--   * monde connu et non débloqué ;
--   * monde d'ordre n - 1 débloqué ;
--   * backpackLevel >= requiredBackpackLevel ;
--   * solde >= unlockCost, débité une seule fois.
-- Contrôles, débit et `worlds[worldId] = true` dans un seul
-- PlayerDataService.Update : tout ou rien, sans double débit.
--
-- T4 ne crée aucun contenu : débloquer un monde n'y téléporte pas encore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local UpgradeMath = require(ReplicatedStorage.Shared.Util.UpgradeMath)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.EconomySecurityConfig)
local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local WorldUnlockService = {}

local ResultCode = Remotes.ResultCode

WorldUnlockService.RATE_LIMIT_ACTION = "UnlockWorld"

export type Result = {
	ok: boolean,
	code: string,
	worldId: string?,
	coinsSpent: number,
	silent: boolean,
}

export type Dependencies = {
	playerData: {
		GetData: (userId: number) -> any?,
		Update: (userId: number, mutator: (draft: any) -> boolean?) -> PlayerDataService.Result,
	},
	rateLimit: { Allow: (userId: number, action: string) -> boolean, Clear: (userId: number) -> () },
	clock: () -> number,
	log: ((level: string, message: string) -> ())?,
}

local function defaultLog(level: string, message: string)
	if level == "info" then
		print(`[World] {message}`)
	else
		warn(`[World] {level} : {message}`)
	end
end

-- Monde d'ordre `order`, ou nil.
local function worldIdAtOrder(order: number): string?
	for worldId, world in pairs(WorldConfig) do
		if world.order == order then
			return worldId
		end
	end
	return nil
end

local function readWorldId(payload: any): string?
	if type(payload) ~= "table" then
		return nil
	end
	local worldId = payload.worldId
	if type(worldId) ~= "string" or worldId == "" or #worldId > SecurityConfig.Payload.maxIdLength then
		return nil
	end
	for key in pairs(payload) do
		if key ~= "worldId" then
			return nil
		end
	end
	return worldId
end

-- Le profil remplit-il les conditions de déblocage (hors solde) ?
-- Retourne nil si oui, sinon le code de refus. Lecture seule.
function WorldUnlockService.checkRequirements(profile: any, worldId: string): string?
	local world = WorldConfig[worldId]
	if world == nil then
		return ResultCode.InvalidTarget
	end
	if type(profile.worlds) ~= "table" then
		return ResultCode.InternalError
	end
	if profile.worlds[worldId] == true then
		return ResultCode.AlreadyUnlocked
	end
	local previousId = worldIdAtOrder(world.order - 1)
	if previousId ~= nil and profile.worlds[previousId] ~= true then
		return ResultCode.RequirementNotMet
	end
	local backpackLevel = UpgradeMath.levelOf(profile, "Backpack")
	if backpackLevel == nil then
		return ResultCode.InternalError
	end
	if backpackLevel < world.requiredBackpackLevel then
		return ResultCode.RequirementNotMet
	end
	return nil
end

function WorldUnlockService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local rateLimit = dependencies.rateLimit
	local clock = dependencies.clock
	local log = dependencies.log or defaultLog

	local lastRateNoticeAt: { [number]: number } = {}
	local operationCount = 0

	local service = {}

	local function reject(code: string, worldId: string?, silent: boolean?): Result
		return { ok = false, code = code, worldId = worldId, coinsSpent = 0, silent = silent == true }
	end

	function service.Unlock(userId: number, worldId: string): Result
		local world = if type(worldId) == "string" then WorldConfig[worldId] else nil
		if world == nil then
			return reject(ResultCode.InvalidTarget)
		end

		local refusal: string? = nil
		local debited: EconomyService.Entry? = nil

		local result = playerData.Update(userId, function(draft: any): boolean?
			local code = WorldUnlockService.checkRequirements(draft, worldId)
			if code ~= nil then
				refusal = code
				return false
			end
			if world.unlockCost > 0 then
				local entry, debitCode = EconomyService.debit(draft, world.unlockCost, `UnlockWorld:{worldId}`)
				if entry == nil then
					refusal = if debitCode == EconomyService.Code.InsufficientFunds
						then ResultCode.InsufficientFunds
						else ResultCode.InternalError
					return false
				end
				debited = entry
			end
			draft.worlds[worldId] = true
			return nil
		end)

		if result.ok then
			operationCount += 1
			local spent = 0
			if debited ~= nil then
				local entry = debited :: EconomyService.Entry
				spent = entry.amount
				local operationId = `UnlockWorld-{operationCount}`
				log("info", `{EconomyService.describe(userId, operationId, entry)} ; monde {worldId} débloqué`)
			else
				log("info", `joueur {userId} : monde {worldId} débloqué (gratuit)`)
			end
			return { ok = true, code = ResultCode.Success, worldId = worldId, coinsSpent = spent, silent = false }
		end
		if result.code == PlayerDataService.Code.NotLoaded then
			return reject(ResultCode.ProfileNotLoaded, worldId)
		end
		if refusal ~= nil and refusal ~= ResultCode.InternalError then
			return reject(refusal, worldId)
		end
		log("error", `joueur {userId} : déblocage {worldId} annulé ({tostring(refusal or result.code)} : {tostring(result.message)})`)
		return reject(ResultCode.InternalError, worldId)
	end

	-- Traite une demande de déblocage. `payload` vient du client : non fiable.
	function service.HandleRequest(userId: number, payload: any): Result
		if not rateLimit.Allow(userId, WorldUnlockService.RATE_LIMIT_ACTION) then
			local now = clock()
			local last = lastRateNoticeAt[userId] or -math.huge
			local noticed = now - last < SecurityConfig.RateLimitFeedback.noticeIntervalSeconds
			if not noticed then
				lastRateNoticeAt[userId] = now
			end
			return reject(ResultCode.RateLimited, nil, noticed)
		end
		if playerData.GetData(userId) == nil then
			return reject(ResultCode.ProfileNotLoaded)
		end
		local worldId = readWorldId(payload)
		if worldId == nil or WorldConfig[worldId] == nil then
			return reject(ResultCode.InvalidTarget)
		end
		return service.Unlock(userId, worldId)
	end

	function service.RemovePlayer(userId: number)
		lastRateNoticeAt[userId] = nil
		rateLimit.Clear(userId)
	end

	return service
end

return WorldUnlockService
