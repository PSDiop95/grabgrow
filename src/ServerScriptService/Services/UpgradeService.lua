--!strict
-- Achat des améliorations (T4, décision D-015), entièrement validé côté
-- serveur. Achat x1 uniquement (D-003) : x10, x100 et MAX sont reportés.
--
-- Le client n'envoie qu'un identifiant ({ upgradeId = "Backpack" }). Niveau
-- actuel, coût et effet sont lus dans le profil serveur et UpgradeConfig.
--
-- Ordre des contrôles : limite de fréquence -> profil chargé -> payload ->
-- amélioration connue -> transaction (un seul PlayerDataService.Update) :
--   niveau max ? -> coût du niveau suivant -> débit (EconomyService) ->
--   niveau + 1.
-- Tout ou rien : un refus ou une erreur ne modifie ni le solde ni le
-- niveau. La mutation ne suspend jamais le fil : deux demandes simultanées
-- s'exécutent l'une après l'autre, la seconde lit le niveau et le solde
-- laissés par la première (aucun double débit, aucun saut de niveau).
--
-- Effets : appliqués par les services qui lisent le niveau à chaque usage
-- (InventoryService, CollectionService, SellService). Boots : `onUpgraded`
-- permet à Bootstrap de fixer Humanoid.WalkSpeed côté serveur.
--
-- Aucune sauvegarde DataStore déclenchée : cycle normal de T1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local UpgradeMath = require(ReplicatedStorage.Shared.Util.UpgradeMath)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.EconomySecurityConfig)
local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SecurityLog = require(script.Parent.SecurityLog)
local PayloadValidator = require(script.Parent.Parent.Systems.PayloadValidator)

local UpgradeService = {}

local ResultCode = Remotes.ResultCode

-- Nom de la limite dans EconomySecurityConfig.RateLimits.
UpgradeService.RATE_LIMIT_ACTION = "Upgrade"

export type Result = {
	ok: boolean,
	code: string,
	upgradeId: string?,
	-- Niveau après l'achat (succès) ou niveau actuel lu (MAX_LEVEL).
	level: number?,
	-- Coins débités (0 en cas de refus).
	coinsSpent: number,
	-- true : ne pas répondre au client (rejets en rafale déjà signalés).
	silent: boolean,
}

export type Dependencies = {
	playerData: {
		GetData: (userId: number) -> any?,
		Update: (userId: number, mutator: (draft: any) -> boolean?) -> PlayerDataService.Result,
	},
	rateLimit: { Allow: (userId: number, action: string) -> boolean, Clear: (userId: number) -> () },
	-- Horloge monotone en secondes (os.clock en production).
	clock: () -> number,
	-- Appelé après chaque achat réussi (effets hors profil, ex. WalkSpeed).
	onUpgraded: ((userId: number, upgradeId: string, level: number) -> ())?,
	-- T6 (facultatif) : journal de sécurité.
	security: SecurityLog.Recorder?,
	log: ((level: string, message: string) -> ())?,
}

local function defaultLog(level: string, message: string)
	if level == "info" then
		print(`[Upgrade] {message}`)
	else
		warn(`[Upgrade] {level} : {message}`)
	end
end

-- Seule forme acceptée : une table avec l'unique champ `upgradeId`, texte
-- non vide de longueur bornée, sans argument supplémentaire. Aucun prix,
-- niveau ni effet.
local function readUpgradeId(payload: any, extraArgumentCount: number?): (string?, string?)
	return PayloadValidator.readId(payload, "upgradeId", SecurityConfig.Payload.maxIdLength, extraArgumentCount)
end

function UpgradeService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local rateLimit = dependencies.rateLimit
	local clock = dependencies.clock
	local onUpgraded = dependencies.onUpgraded
	local security: SecurityLog.Recorder = dependencies.security or SecurityLog.none()
	local log = dependencies.log or defaultLog
	local Event = SecurityLog.Type
	local ACTION = "Upgrade"

	local lastRateNoticeAt: { [number]: number } = {}
	local operationCount = 0

	local service = {}

	local function reject(code: string, upgradeId: string?, level: number?, silent: boolean?): Result
		return {
			ok = false,
			code = code,
			upgradeId = upgradeId,
			level = level,
			coinsSpent = 0,
			silent = silent == true,
		}
	end

	-- Achète le niveau suivant de `upgradeId`. Sans limite de fréquence ni
	-- lecture du payload : voir HandleRequest.
	function service.Purchase(userId: number, upgradeId: string): Result
		if type(upgradeId) ~= "string" or UpgradeConfig[upgradeId] == nil then
			return reject(ResultCode.InvalidTarget)
		end
		local profileKey = UpgradeConfig[upgradeId].profileKey
		local reason = `Upgrade:{upgradeId}`

		local outcome: string? = nil
		local readLevel: number? = nil
		local newLevel: number? = nil
		local debited: EconomyService.Entry? = nil

		local result = playerData.Update(userId, function(draft: any): boolean?
			-- Niveau et solde lus DANS la mutation.
			local level = UpgradeMath.levelOf(draft, upgradeId)
			if level == nil then
				outcome = "level"
				return false
			end
			readLevel = level
			local cost = UpgradeMath.nextCost(upgradeId, level)
			if cost == nil then
				outcome = "max"
				return false
			end
			local entry, code = EconomyService.debit(draft, cost, reason)
			if entry == nil then
				outcome = if code == EconomyService.Code.InsufficientFunds then "funds" else tostring(code)
				return false
			end
			draft.upgrades[profileKey] = level + 1
			debited = entry
			newLevel = level + 1
			return nil
		end)

		if result.ok and debited ~= nil and newLevel ~= nil then
			local entry = debited :: EconomyService.Entry
			local level = newLevel :: number
			operationCount += 1
			local operationId = `Upgrade-{operationCount}`
			log("info", `{EconomyService.describe(userId, operationId, entry)} ; {upgradeId} niveau {level - 1} -> {level}`)
			if onUpgraded then
				onUpgraded(userId, upgradeId, level)
			end
			return {
				ok = true,
				code = ResultCode.Success,
				upgradeId = upgradeId,
				level = level,
				coinsSpent = entry.amount,
				silent = false,
			}
		end
		if result.code == PlayerDataService.Code.NotLoaded then
			return reject(ResultCode.ProfileNotLoaded, upgradeId)
		end
		if outcome == "max" then
			return reject(ResultCode.MaxLevel, upgradeId, readLevel)
		end
		if outcome == "funds" then
			return reject(ResultCode.InsufficientFunds, upgradeId, readLevel)
		end
		log("error", `joueur {userId} : achat {upgradeId} annulé ({tostring(outcome or result.code)} : {tostring(result.message)})`)
		return reject(ResultCode.InternalError, upgradeId, readLevel)
	end

	-- Traite une demande d'achat. `payload` vient du client : non fiable.
	-- `extraArgumentCount` : arguments reçus après le payload (0 attendu).
	function service.HandleRequest(userId: number, payload: any, extraArgumentCount: number?): Result
		if not rateLimit.Allow(userId, UpgradeService.RATE_LIMIT_ACTION) then
			local now = clock()
			local last = lastRateNoticeAt[userId] or -math.huge
			local noticed = now - last < SecurityConfig.RateLimitFeedback.noticeIntervalSeconds
			if not noticed then
				lastRateNoticeAt[userId] = now
			end
			security.Record(userId, Event.RateLimited, { action = ACTION })
			return reject(ResultCode.RateLimited, nil, nil, noticed)
		end

		-- GetData est nil pendant le chargement et après la libération.
		if playerData.GetData(userId) == nil then
			security.Record(userId, Event.ProfileNotLoaded, { action = ACTION })
			return reject(ResultCode.ProfileNotLoaded)
		end

		local upgradeId, payloadReason = readUpgradeId(payload, extraArgumentCount)
		if upgradeId == nil then
			security.Record(userId, Event.InvalidPayload, { action = ACTION, reason = payloadReason })
			return reject(ResultCode.InvalidTarget)
		end
		if UpgradeConfig[upgradeId] == nil then
			security.Record(userId, Event.UnknownId, { action = ACTION, id = upgradeId })
			return reject(ResultCode.InvalidTarget)
		end
		local result = service.Purchase(userId, upgradeId)
		if not result.ok then
			security.Record(userId, Event.EconomyRefused, { action = ACTION, id = upgradeId, code = result.code })
		end
		return result
	end

	-- Vitesse de déplacement des Boots du joueur, ou nil si non chargé.
	function service.GetWalkSpeed(userId: number): number?
		local profile = playerData.GetData(userId)
		return if profile then UpgradeMath.valueFor(profile, "Boots") else nil
	end

	-- À appeler quand le joueur quitte.
	function service.RemovePlayer(userId: number)
		lastRateNoticeAt[userId] = nil
		rateLimit.Clear(userId)
	end

	return service
end

return UpgradeService
