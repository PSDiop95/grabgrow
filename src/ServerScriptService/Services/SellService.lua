--!strict
-- Vente des ressources du sac contre des Coins (T3), entièrement validée
-- côté serveur.
--
-- Le client n'envoie qu'un identifiant de zone ({ sellZoneId = "..." }).
-- Quantités et montant sont calculés ici, à partir du profil serveur et de
-- ResourceConfig (formule partagée : Shared/Util/SaleValue).
--
-- Ordre des contrôles (le moins coûteux d'abord) :
--   limite de fréquence -> profil chargé -> payload -> zone connue ->
--   personnage -> distance -> transaction (un seul PlayerDataService.Update).
--
-- Transaction atomique : dans la même mutation, lecture de l'inventaire,
-- calcul, retrait des ressources vendues, crédit des Coins et mise à jour
-- des statistiques. T4 (D-015) : le crédit passe par EconomyService.credit
-- et le montant est floor(base × Multiplier), lu dans le profil serveur. Un refus, une erreur ou un profil invalide annulent
-- tout (tout ou rien, garanti par Update). La mutation ne suspend jamais
-- le fil : deux ventes ne peuvent pas lire le même inventaire, une même
-- ressource ne peut pas être vendue deux fois.
--
-- Ressources inconnues de ResourceConfig : jamais vendues ni supprimées,
-- elles restent dans le sac (D-012, D-014).
--
-- Dépendances injectées : testable sans Roblox. Branchement sur le
-- RemoteEvent dans Bootstrap. Paramètres de sécurité : ServerStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local SaleValue = require(ReplicatedStorage.Shared.Util.SaleValue)
local UpgradeMath = require(ReplicatedStorage.Shared.Util.UpgradeMath)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.SellSecurityConfig)
local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SellService = {}

local ResultCode = Remotes.ResultCode

-- Nom de la limite dans SellSecurityConfig.RateLimits.
SellService.RATE_LIMIT_ACTION = "Sell"
-- Motif journalisé des Coins crédités par une vente.
SellService.TRANSACTION_REASON = "Sell"

export type Position = { X: number, Y: number, Z: number }

export type Zone = {
	-- Centre de la zone, vu par le serveur.
	position: Position,
}

export type Result = {
	ok: boolean,
	code: string,
	-- Zone demandée, si elle était lisible.
	sellZoneId: string?,
	-- Coins réellement crédités, Multiplier compris (0 en cas de refus).
	coinsEarned: number,
	-- Valeur avant Multiplier (0 en cas de refus).
	baseValue: number,
	-- Multiplicateur appliqué (1 en cas de refus).
	multiplier: number,
	-- Unités retirées du sac (0 en cas de refus).
	quantitySold: number,
	-- Quantités vendues par ressource (vide en cas de refus).
	items: { [string]: number },
	-- true : ne pas répondre au client (rejets en rafale déjà signalés).
	silent: boolean,
}

export type Dependencies = {
	playerData: {
		GetData: (userId: number) -> any?,
		Update: (userId: number, mutator: (draft: any) -> boolean?) -> PlayerDataService.Result,
	},
	rateLimit: { Allow: (userId: number, action: string) -> boolean, Clear: (userId: number) -> () },
	-- Zone de vente par identifiant, ou nil si inconnue.
	getSellZone: (sellZoneId: string) -> Zone?,
	-- Position du personnage VUE PAR LE SERVEUR, ou nil s'il est absent ou mort.
	getCharacterPosition: (userId: number) -> Position?,
	-- Horloge monotone en secondes (os.clock en production).
	clock: () -> number,
	log: ((level: string, message: string) -> ())?,
}

local function defaultLog(level: string, message: string)
	if level == "info" then
		print(`[Sell] {message}`)
	else
		warn(`[Sell] {level} : {message}`)
	end
end

local function distanceBetween(a: Position, b: Position): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Seule forme acceptée : une table avec l'unique champ `sellZoneId`, texte
-- non vide de longueur bornée. Aucune quantité, aucun montant.
local function readZoneId(payload: any): string?
	if type(payload) ~= "table" then
		return nil
	end
	local zoneId = payload.sellZoneId
	if type(zoneId) ~= "string" or zoneId == "" or #zoneId > SecurityConfig.Payload.maxSellZoneIdLength then
		return nil
	end
	for key in pairs(payload) do
		if key ~= "sellZoneId" then
			return nil
		end
	end
	return zoneId
end

local function describeItems(items: { [string]: number }): string
	local parts = {}
	for resourceId, quantity in pairs(items) do
		table.insert(parts, `{resourceId}={quantity}`)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function SellService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local rateLimit = dependencies.rateLimit
	local getSellZone = dependencies.getSellZone
	local getCharacterPosition = dependencies.getCharacterPosition
	local clock = dependencies.clock
	local log = dependencies.log or defaultLog

	-- Dernière réponse RATE_LIMITED envoyée, par joueur.
	local lastRateNoticeAt: { [number]: number } = {}
	-- Identifiant d'opération du journal (unique par serveur).
	local operationCount = 0

	local service = {}

	local function reject(code: string, zoneId: string?, silent: boolean?): Result
		return {
			ok = false,
			code = code,
			sellZoneId = zoneId,
			coinsEarned = 0,
			baseValue = 0,
			multiplier = 1,
			quantitySold = 0,
			items = {},
			silent = silent == true,
		}
	end

	-- Vend toutes les ressources vendables du sac. Transaction unique.
	-- Retourne le résultat ; ne contrôle ni zone ni distance (voir HandleRequest).
	local function sellInventory(userId: number, zoneId: string): Result
		local outcome: string? = nil
		local sold: SaleValue.Quote? = nil
		local credited: EconomyService.Entry? = nil
		local multiplier = 1

		local result = playerData.Update(userId, function(draft: any): boolean?
			-- Lecture de l'inventaire et calcul DANS la mutation : aucune
			-- autre opération ne peut s'intercaler.
			local quote = SaleValue.quote(draft.inventory.resources)
			if quote.overflow then
				outcome = "overflow"
				return false
			end
			if quote.quantity <= 0 or quote.total <= 0 then
				outcome = "nothing"
				return false
			end
			-- Multiplier du profil serveur ; un niveau illisible annule tout.
			local level = UpgradeMath.valueFor(draft, "Multiplier")
			if level == nil then
				outcome = "multiplier"
				return false
			end
			multiplier = level
			local amount = SaleValue.applyMultiplier(quote.total, multiplier, GameConfig.Selling.maxSellMultiplier)
			if amount == nil or not SaleValue.canAdd(draft.stats.totalSales, 1) then
				outcome = "overflow"
				return false
			end

			local resources = draft.inventory.resources
			for resourceId, quantity in pairs(quote.items) do
				-- Garde : la quantité vendue est exactement celle lue.
				if resources[resourceId] ~= quantity then
					outcome = "inconsistent"
					return false
				end
				resources[resourceId] = nil
			end
			-- Crédit centralisé : solde et totalCoinsEarned, bornés.
			-- totalCoinsSpent n'est jamais touché par une vente.
			local entry, code = EconomyService.credit(draft, amount, SellService.TRANSACTION_REASON)
			if entry == nil then
				outcome = if code == EconomyService.Code.Overflow then "overflow" else tostring(code)
				return false
			end
			credited = entry
			draft.stats.totalSales += 1
			sold = quote
			return nil
		end)

		if result.ok and sold ~= nil and credited ~= nil then
			local quote = sold :: SaleValue.Quote
			local entry = credited :: EconomyService.Entry
			operationCount += 1
			local operationId = `Sell-{operationCount}`
			log(
				"info",
				`{EconomyService.describe(userId, operationId, entry)} ; zone {zoneId}, base {quote.total} x{multiplier}, {quote.quantity} unité(s) : {describeItems(quote.items)}`
			)
			return {
				ok = true,
				code = ResultCode.Success,
				sellZoneId = zoneId,
				coinsEarned = entry.amount,
				baseValue = quote.total,
				multiplier = multiplier,
				quantitySold = quote.quantity,
				items = quote.items,
				silent = false,
			}
		end
		if result.code == PlayerDataService.Code.NotLoaded then
			return reject(ResultCode.ProfileNotLoaded, zoneId)
		end
		if outcome == "nothing" then
			return reject(ResultCode.NothingToSell, zoneId)
		end
		if outcome == "overflow" then
			log("error", `joueur {userId} : vente refusée, dépassement numérique (données anormales)`)
		else
			log("error", `joueur {userId} : vente annulée ({tostring(outcome or result.code)} : {tostring(result.message)})`)
		end
		return reject(ResultCode.InternalError, zoneId)
	end

	-- Traite une demande de vente. `payload` vient du client : non fiable.
	function service.HandleRequest(userId: number, payload: any): Result
		if not rateLimit.Allow(userId, SellService.RATE_LIMIT_ACTION) then
			local now = clock()
			local last = lastRateNoticeAt[userId] or -math.huge
			local noticed = now - last < SecurityConfig.RateLimitFeedback.noticeIntervalSeconds
			if not noticed then
				lastRateNoticeAt[userId] = now
			end
			return reject(ResultCode.RateLimited, nil, noticed)
		end

		-- GetData est nil pendant le chargement et après la libération.
		if playerData.GetData(userId) == nil then
			return reject(ResultCode.ProfileNotLoaded)
		end

		local zoneId = readZoneId(payload)
		if zoneId == nil then
			return reject(ResultCode.InvalidTarget)
		end
		local zone = getSellZone(zoneId)
		if zone == nil then
			return reject(ResultCode.InvalidTarget, zoneId)
		end

		local position = getCharacterPosition(userId)
		if position == nil then
			return reject(ResultCode.NoCharacter, zoneId)
		end
		local maxDistance = GameConfig.Selling.interactRangeStuds + SecurityConfig.Distance.toleranceStuds
		if distanceBetween(position, zone.position) > maxDistance then
			return reject(ResultCode.TooFar, zoneId)
		end

		return sellInventory(userId, zoneId)
	end

	-- Devis du sac actuel (affichage, tests). nil si le profil n'est pas chargé.
	function service.GetQuote(userId: number): SaleValue.Quote?
		local profile = playerData.GetData(userId)
		if profile == nil then
			return nil
		end
		return SaleValue.quote(profile.inventory.resources)
	end

	-- À appeler quand le joueur quitte.
	function service.RemovePlayer(userId: number)
		lastRateNoticeAt[userId] = nil
		rateLimit.Clear(userId)
	end

	return service
end

return SellService
