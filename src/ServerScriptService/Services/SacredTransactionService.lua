--!strict
-- Vente et consommation des ressources sacrées (T10.5a, T10-D03, D-037,
-- D-038). Serveur autoritaire.
--
-- Vente ({ resourceId }) : TOUTES les unités possédées de cette ressource
-- sacrée, au prix `sellValue` de SacredResourceConfig (Multiplier non
-- appliqué). Crédit par EconomyService.credit (totalCoinsEarned) ;
-- stats.totalSales inchangé (D-038).
--
-- Amélioration ({ upgradeId }) : un seul niveau (R-1). Retire `cost` unités
-- de la ressource du monde et pose achievements["sacred_upgrade_<id>"]
-- (U-A, schéma v3). L'effet est lu par SacredUpgradeRules à partir du
-- profil, jamais du client.
--
-- Atomicité : chaque opération est UNE mutation PlayerDataService.Update
-- (brouillon copié, contrôlé par DataSchema, remplacé seulement si tout
-- réussit ; le fil n'est jamais suspendu). Deux demandes simultanées ne
-- peuvent donc pas vendre ni dépenser deux fois les mêmes unités : la
-- seconde voit l'état laissé par la première.
--
-- Aucune condition de proximité : actions de menu, comme UpgradeService ;
-- la valeur est décidée par le serveur et l'offre est unique (R1).
--
-- Ordre des contrôles : limite de fréquence -> profil chargé -> payload ->
-- identifiant connu -> mutation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SacredResourceConfig = require(ReplicatedStorage.Shared.Config.SacredResourceConfig)
local SacredUpgradeRules = require(ReplicatedStorage.Shared.Util.SacredUpgradeRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.GuardianSecurityConfig)
local PayloadValidator = require(script.Parent.Parent.Systems.PayloadValidator)
local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SecurityLog = require(script.Parent.SecurityLog)

local SacredTransactionService = {}

local ResultCode = Remotes.ResultCode

SacredTransactionService.SELL_ACTION = "SacredSell"
SacredTransactionService.UPGRADE_ACTION = "SacredUpgrade"
-- Motif journalisé des Coins crédités par une vente sacrée.
SacredTransactionService.SELL_REASON = "SacredSell"
SacredTransactionService.SELL_SAVE_REASON = "sacred_sale"
SacredTransactionService.UPGRADE_SAVE_REASON = "sacred_upgrade"

export type SellResult = {
	ok: boolean,
	code: string,
	resourceId: string?,
	quantitySold: number,
	coinsEarned: number,
	balanceAfter: number?,
	silent: boolean,
}

export type UpgradeResult = {
	ok: boolean,
	code: string,
	upgradeId: string?,
	resourceId: string?,
	unitsSpent: number,
	silent: boolean,
}

export type Dependencies = {
	playerData: {
		GetData: (userId: number) -> any?,
		Update: (userId: number, mutator: (draft: any) -> boolean?) -> PlayerDataService.Result,
		RequestSave: (userId: number, reason: string?) -> any,
	},
	rateLimit: { Allow: (userId: number, action: string) -> boolean, Clear: (userId: number) -> () },
	security: SecurityLog.Recorder?,
	log: ((level: string, message: string) -> ())?,
}

local function defaultLog(level: string, message: string)
	if level == "info" then
		print(`[SacredTransaction] {message}`)
	else
		warn(`[SacredTransaction] {level} : {message}`)
	end
end

-- Quantité entière positive lue dans un inventaire, ou 0.
local function quantityOf(resources: any, resourceId: string): number
	local quantity = if type(resources) == "table" then resources[resourceId] else nil
	if type(quantity) ~= "number" or quantity ~= quantity or quantity < 1 or quantity % 1 ~= 0 then
		return 0
	end
	return quantity
end

function SacredTransactionService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local rateLimit = dependencies.rateLimit
	local security: SecurityLog.Recorder = dependencies.security or SecurityLog.none()
	local log = dependencies.log or defaultLog
	local Event = SecurityLog.Type

	local operationCount = 0
	local service = {}

	local function rejectSell(code: string, resourceId: string?, silent: boolean?): SellResult
		return {
			ok = false,
			code = code,
			resourceId = resourceId,
			quantitySold = 0,
			coinsEarned = 0,
			balanceAfter = nil,
			silent = silent == true,
		}
	end

	local function rejectUpgrade(code: string, upgradeId: string?, silent: boolean?): UpgradeResult
		return {
			ok = false,
			code = code,
			upgradeId = upgradeId,
			resourceId = nil,
			unitsSpent = 0,
			silent = silent == true,
		}
	end

	-- Contrôles communs avant la mutation. Retourne (identifiant, nil) ou
	-- (nil, code de refus, silencieux).
	local function precheck(
		userId: number,
		action: string,
		field: string,
		payload: any,
		extraArgumentCount: number?
	): (string?, string?, boolean?)
		if not rateLimit.Allow(userId, action) then
			security.Record(userId, Event.RateLimited, { action = action })
			return nil, ResultCode.RateLimited, true
		end
		if playerData.GetData(userId) == nil then
			security.Record(userId, Event.ProfileNotLoaded, { action = action })
			return nil, ResultCode.ProfileNotLoaded, false
		end
		local id, reason = PayloadValidator.readId(payload, field, SecurityConfig.Payload.maxIdLength, extraArgumentCount)
		if id == nil then
			security.Record(userId, Event.InvalidPayload, { action = action, reason = reason })
			return nil, ResultCode.InvalidTarget, false
		end
		return id, nil, nil
	end

	function service.HandleSell(userId: number, payload: any, extraArgumentCount: number?): SellResult
		local resourceId, code, silent =
			precheck(userId, SacredTransactionService.SELL_ACTION, "resourceId", payload, extraArgumentCount)
		if resourceId == nil then
			return rejectSell(code :: string, nil, silent)
		end
		local definition = SacredResourceConfig.Resources[resourceId]
		if definition == nil then
			security.Record(userId, Event.UnknownId, { action = SacredTransactionService.SELL_ACTION, id = resourceId })
			return rejectSell(ResultCode.InvalidTarget, resourceId)
		end

		local outcome: string? = nil
		local sold = 0
		local credited: EconomyService.Entry? = nil
		local result = playerData.Update(userId, function(draft: any): boolean?
			if type(draft.inventory) ~= "table" or type(draft.inventory.resources) ~= "table" then
				outcome = "profile"
				return false
			end
			local resources = draft.inventory.resources
			local quantity = quantityOf(resources, resourceId)
			if quantity <= 0 then
				outcome = ResultCode.NothingToSell
				return false
			end
			local amount = quantity * definition.sellValue
			local entry, creditCode = EconomyService.credit(draft, amount, SacredTransactionService.SELL_REASON)
			if entry == nil then
				outcome = tostring(creditCode)
				return false
			end
			resources[resourceId] = nil
			sold = quantity
			credited = entry
			return nil
		end)

		if result.ok and credited ~= nil then
			local entry = credited :: EconomyService.Entry
			operationCount += 1
			log(
				"info",
				`{EconomyService.describe(userId, `SacredSell-{operationCount}`, entry)} ; {resourceId} x{sold} à {definition.sellValue}`
			)
			playerData.RequestSave(userId, SacredTransactionService.SELL_SAVE_REASON)
			return {
				ok = true,
				code = ResultCode.Success,
				resourceId = resourceId,
				quantitySold = sold,
				coinsEarned = entry.amount,
				balanceAfter = entry.balanceAfter,
				silent = false,
			}
		end
		if result.code == PlayerDataService.Code.NotLoaded then
			return rejectSell(ResultCode.ProfileNotLoaded, resourceId)
		end
		if outcome == ResultCode.NothingToSell then
			return rejectSell(ResultCode.NothingToSell, resourceId)
		end
		log("error", `joueur {userId} : vente sacrée {resourceId} annulée ({tostring(outcome or result.code)} : {tostring(result.message)})`)
		return rejectSell(ResultCode.InternalError, resourceId)
	end

	function service.HandleUpgrade(userId: number, payload: any, extraArgumentCount: number?): UpgradeResult
		local upgradeId, code, silent =
			precheck(userId, SacredTransactionService.UPGRADE_ACTION, "upgradeId", payload, extraArgumentCount)
		if upgradeId == nil then
			return rejectUpgrade(code :: string, nil, silent)
		end
		local definition = SacredUpgradeRules.definition(upgradeId)
		if definition == nil then
			security.Record(userId, Event.UnknownId, { action = SacredTransactionService.UPGRADE_ACTION, id = upgradeId })
			return rejectUpgrade(ResultCode.InvalidTarget, upgradeId)
		end

		local key = SacredUpgradeRules.key(upgradeId)
		local resourceId = definition.resourceId
		local outcome: string? = nil
		local result = playerData.Update(userId, function(draft: any): boolean?
			if type(draft.achievements) ~= "table"
				or type(draft.inventory) ~= "table"
				or type(draft.inventory.resources) ~= "table"
			then
				outcome = "profile"
				return false
			end
			if draft.achievements[key] == true then
				outcome = ResultCode.MaxLevel
				return false
			end
			local resources = draft.inventory.resources
			local quantity = quantityOf(resources, resourceId)
			if quantity < definition.cost then
				outcome = ResultCode.InsufficientResources
				return false
			end
			local remaining = quantity - definition.cost
			resources[resourceId] = if remaining > 0 then remaining else nil
			draft.achievements[key] = true
			outcome = ResultCode.Success
			return nil
		end)

		if result.ok and outcome == ResultCode.Success then
			operationCount += 1
			log(
				"info",
				`SacredUpgrade-{operationCount} user={userId} {upgradeId} : {resourceId} -{definition.cost}`
			)
			playerData.RequestSave(userId, SacredTransactionService.UPGRADE_SAVE_REASON)
			return {
				ok = true,
				code = ResultCode.Success,
				upgradeId = upgradeId,
				resourceId = resourceId,
				unitsSpent = definition.cost,
				silent = false,
			}
		end
		if result.code == PlayerDataService.Code.NotLoaded then
			return rejectUpgrade(ResultCode.ProfileNotLoaded, upgradeId)
		end
		if outcome == ResultCode.MaxLevel or outcome == ResultCode.InsufficientResources then
			if outcome == ResultCode.MaxLevel then
				security.Record(userId, Event.ActionRefused, {
					action = SacredTransactionService.UPGRADE_ACTION,
					code = ResultCode.MaxLevel,
				})
			end
			return rejectUpgrade(outcome :: string, upgradeId)
		end
		log("error", `joueur {userId} : amélioration sacrée {upgradeId} annulée ({tostring(outcome or result.code)} : {tostring(result.message)})`)
		return rejectUpgrade(ResultCode.InternalError, upgradeId)
	end

	function service.RemovePlayer(userId: number)
		rateLimit.Clear(userId)
	end

	return service
end

return SacredTransactionService
