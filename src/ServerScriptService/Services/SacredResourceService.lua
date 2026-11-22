--!strict
-- Réclamation de la récompense sacrée à la terrasse du site (T10.3, D-035).
--
-- Règles (D-035, régime R1) :
--   * récompense : `rewardUnits` unités de la ressource sacrée du site
--     (SacredResourceConfig, hors ResourceConfig), UNE SEULE FOIS par profil,
--     après une victoire personnelle contre le gardien du site ;
--   * le client n'envoie qu'un identifiant de nœud ({ nodeId = "..." }) :
--     quantité, ressource et droit sont décidés ici ;
--   * sac sans assez de place : INVENTORY_FULL, rien n'est modifié et le
--     droit est conservé (nouvel essai après avoir libéré de la place,
--     même après reconnexion ou changement de serveur) ;
--   * ajout des unités et clé achievements["sanctuary_reward_<siteId>"]
--     dans UNE mutation PlayerDataService.Update (tout ou rien, sans
--     suspension du fil) : deux demandes ne peuvent pas attribuer deux fois ;
--     la seconde voit la clé et reçoit ALREADY_CLAIMED.
--   * la clé de victoire est posée dans la même mutation si elle manque
--     (victoire gardée en session après un échec d'écriture) : jamais de
--     récompense sans victoire dans le profil.
--
-- Ordre des contrôles : limite de fréquence -> profil chargé -> payload ->
-- nœud connu -> victoire -> position et distance -> déplacements ->
-- mutation (déjà réclamée -> place dans le sac -> attribution).
--
-- Aucune valeur de vente ni consommation ici (lot ultérieur, valeurs non
-- validées). Les unités restent dans le sac : SellService ne vend pas les
-- identifiants inconnus de ResourceConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local SacredResourceConfig = require(ReplicatedStorage.Shared.Config.SacredResourceConfig)
local GuardianRules = require(ReplicatedStorage.Shared.Util.GuardianRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.GuardianSecurityConfig)
local MovementValidator = require(script.Parent.Parent.Systems.MovementValidator)
local PayloadValidator = require(script.Parent.Parent.Systems.PayloadValidator)
local InventoryService = require(script.Parent.InventoryService)
local SecurityLog = require(script.Parent.SecurityLog)

local SacredResourceService = {}

local ResultCode = Remotes.ResultCode

SacredResourceService.RATE_LIMIT_ACTION = "SacredCollect"
SacredResourceService.SAVE_REASON = "sacred_reward"

export type Position = GuardianRules.Position

export type Node = {
	nodeId: string,
	siteId: string,
	resourceId: string,
	position: Position,
}

export type Result = {
	ok: boolean,
	code: string,
	nodeId: string?,
	siteId: string?,
	resourceId: string?,
	amount: number,
	silent: boolean,
}

export type Dependencies = {
	playerData: {
		GetData: (userId: number) -> any?,
		Update: (userId: number, mutator: (draft: any) -> boolean?) -> { ok: boolean, code: string?, message: string? },
		RequestSave: (userId: number, reason: string?) -> any,
	},
	sites: { HasVictory: (userId: number, siteId: string) -> boolean },
	getNode: (nodeId: string) -> Node?,
	getCharacterPosition: (userId: number) -> Position?,
	rateLimit: { Allow: (userId: number, action: string) -> boolean, Clear: (userId: number) -> () },
	clock: (() -> number)?,
	movement: { CanAct: (userId: number, position: any, now: number) -> (boolean, string?) }?,
	security: SecurityLog.Recorder?,
	log: ((level: string, message: string) -> ())?,
}

local function defaultLog(level: string, message: string)
	if level == "info" then
		print(`[SacredReward] {message}`)
	else
		warn(`[SacredReward] {level} : {message}`)
	end
end

local function distance3(a: Position, b: Position): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function SacredResourceService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local sites = dependencies.sites
	local getNode = dependencies.getNode
	local getCharacterPosition = dependencies.getCharacterPosition
	local rateLimit = dependencies.rateLimit
	local clock = dependencies.clock or os.clock
	local movement = dependencies.movement
	local security: SecurityLog.Recorder = dependencies.security or SecurityLog.none()
	local log = dependencies.log or defaultLog
	local Event = SecurityLog.Type
	local ACTION = "SacredCollect"

	local service = {}

	local function reject(code: string, nodeId: string?, siteId: string?, silent: boolean?): Result
		return {
			ok = false,
			code = code,
			nodeId = nodeId,
			siteId = siteId,
			resourceId = nil,
			amount = 0,
			silent = silent == true,
		}
	end

	function service.HandleCollect(userId: number, payload: any, extraArgumentCount: number?): Result
		if not rateLimit.Allow(userId, SacredResourceService.RATE_LIMIT_ACTION) then
			security.Record(userId, Event.RateLimited, { action = ACTION })
			return reject(ResultCode.RateLimited, nil, nil, true)
		end
		local profile = playerData.GetData(userId)
		if profile == nil then
			return reject(ResultCode.ProfileNotLoaded)
		end
		local nodeId, payloadReason =
			PayloadValidator.readId(payload, "nodeId", SecurityConfig.Payload.maxIdLength, extraArgumentCount)
		if nodeId == nil then
			security.Record(userId, Event.InvalidPayload, { action = ACTION, reason = payloadReason })
			return reject(ResultCode.InvalidTarget)
		end
		local node = getNode(nodeId)
		local siteId = if node then node.siteId else nil
		local resourceId = if siteId then SacredResourceConfig.BySite[siteId] else nil
		local definition = if resourceId then SacredResourceConfig.Resources[resourceId] else nil
		if node == nil or siteId == nil or GuardianConfig.Sites[siteId] == nil or resourceId == nil or definition == nil then
			security.Record(userId, Event.UnknownId, { action = ACTION, id = nodeId })
			return reject(ResultCode.InvalidTarget, nodeId)
		end
		-- Victoire personnelle seulement (profil ou session de ce joueur).
		if not sites.HasVictory(userId, siteId) then
			return reject(ResultCode.RequirementNotMet, nodeId, siteId)
		end
		local position = getCharacterPosition(userId)
		if position == nil then
			return reject(ResultCode.NoCharacter, nodeId, siteId)
		end
		local maxDistance = GuardianConfig.SacredResources.grabRangeStuds + SecurityConfig.Distance.toleranceStuds
		if not MovementValidator.isFinitePosition(position) or not (distance3(position, node.position) <= maxDistance) then
			security.Record(userId, Event.ActionRefused, { action = ACTION, code = ResultCode.TooFar })
			return reject(ResultCode.TooFar, nodeId, siteId)
		end
		if movement ~= nil then
			local allowed, reason = movement.CanAct(userId, position, clock())
			if not allowed then
				security.Record(userId, Event.MovementRefused, { action = ACTION, reason = reason })
				return reject(ResultCode.TooFar, nodeId, siteId)
			end
		end

		-- Transaction : une seule mutation, décidée sur le brouillon.
		local units = definition.rewardUnits
		local victoryKey = GuardianRules.victoryKey(siteId)
		local rewardKey = GuardianRules.rewardKey(siteId)
		local outcome: string? = nil
		local result = playerData.Update(userId, function(draft: any): boolean?
			if type(draft.achievements) ~= "table" or type(draft.inventory) ~= "table" then
				return false
			end
			if draft.achievements[rewardKey] == true then
				outcome = ResultCode.AlreadyClaimed
				return false
			end
			local state = InventoryService.describe(draft)
			if state == nil then
				return false
			end
			if not GuardianRules.fitsInBag(state.used, state.capacity, units, definition.bagSlotsPerUnit) then
				outcome = ResultCode.InventoryFull
				return false
			end
			local resources = draft.inventory.resources
			resources[resourceId] = (resources[resourceId] or 0) + units
			draft.achievements[victoryKey] = true
			draft.achievements[rewardKey] = true
			outcome = ResultCode.Success
			return true
		end)

		if not result.ok then
			if outcome == ResultCode.AlreadyClaimed then
				security.Record(userId, Event.ActionRefused, { action = ACTION, code = ResultCode.AlreadyClaimed })
				return reject(ResultCode.AlreadyClaimed, nodeId, siteId)
			elseif outcome == ResultCode.InventoryFull then
				return reject(ResultCode.InventoryFull, nodeId, siteId)
			end
			log("error", `réclamation {siteId} du joueur {userId} refusée ({tostring(result.code)})`)
			return reject(ResultCode.InternalError, nodeId, siteId)
		end

		playerData.RequestSave(userId, SacredResourceService.SAVE_REASON)
		log("info", `SacredReward:{resourceId} user={userId} site={siteId} units={units}`)
		return {
			ok = true,
			code = ResultCode.Success,
			nodeId = nodeId,
			siteId = siteId,
			resourceId = resourceId,
			amount = units,
			silent = false,
		}
	end

	function service.RemovePlayer(userId: number)
		rateLimit.Clear(userId)
	end

	return service
end

return SacredResourceService
