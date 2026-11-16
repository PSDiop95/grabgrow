--!strict
-- Instrumentation analytics (T9) : point unique d'appel à Roblox
-- AnalyticsService. Catalogue : docs/analytics/ANALYTICS_EVENT_CATALOG.md.
--
-- Règles :
--   * appelé UNIQUEMENT par le serveur, après une opération confirmée
--     (résultat `ok` d'un service) ; aucun RemoteEvent n'y mène ;
--   * ne modifie jamais le profil : lecture seule via `getProfile` ;
--   * ne bloque jamais le jeu : chaque envoi est isolé par pcall, sans
--     nouvelle tentative ; un événement perdu n'est jamais rejoué ;
--   * aucune donnée personnelle : ni UserId, ni nom, ni position, ni texte
--     du joueur dans les champs ; tous les identifiants envoyés viennent
--     des configurations serveur (cardinalité bornée) ;
--   * aucun événement sans session ouverte, et une session ne s'ouvre que
--     sur un profil chargé (un profil refusé ne produit rien) ;
--   * onboarding : étapes déduites de l'état persistant du profil (aucun
--     champ nouveau, schéma v3 inchangé), envoyées dans l'ordre et une
--     seule fois par session ; Roblox ne compte de toute façon que la
--     première occurrence d'une étape par joueur.
--
-- Le nom du module reprend celui du service Roblox (comme CollectionService) :
-- l'API Roblox n'est jamais appelée ici, mais par le `sink` injecté
-- (Systems/AnalyticsSinks), ce qui rend le module testable sous Lune.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementConfig = require(ReplicatedStorage.Shared.Config.AchievementConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local UpgradeMath = require(ReplicatedStorage.Shared.Util.UpgradeMath)

local AnalyticsService = {}

-- Champs personnalisés : liste ordonnée (au plus 3), traduite par le sink
-- en Enum.AnalyticsCustomFieldKeys.CustomField01..03.
export type Fields = { string }

export type FlowType = "Source" | "Sink"

-- Contrat du sink. Chaque fonction peut lever une erreur : elle est isolée.
export type Sink = {
	custom: (player: any, eventName: string, value: number, fields: Fields?) -> (),
	economy: (
		player: any,
		flowType: FlowType,
		currency: string,
		amount: number,
		endingBalance: number,
		transactionType: string,
		itemSku: string,
		fields: Fields?
	) -> (),
	onboarding: (player: any, step: number, stepName: string, fields: Fields?) -> (),
	progressionComplete: (player: any, pathName: string, level: number, levelName: string, fields: Fields?) -> (),
}

export type Dependencies = {
	config: any,
	sink: Sink,
	-- Horloge monotone en secondes (os.clock).
	clock: () -> number,
	-- Lecture seule du profil chargé, nil sinon.
	getProfile: (userId: number) -> any?,
	getPlayerCount: () -> number,
	log: ((level: string, message: string) -> ())?,
}

export type Counters = {
	sent: number,
	dropped: number,
	failed: number,
	invalid: number,
}

type Session = {
	startedAt: number,
	lastOnboardingStep: number,
	pending: { [string]: number },
	lastFlushAt: number,
	backpackFull: boolean,
}

local HIGH = "high"
local LOW = "low"
local MAX_FIELDS = 3

local function defaultLog(level: string, message: string)
	if level == "error" or level == "warn" then
		warn(`[Analytics] {message}`)
	else
		print(`[Analytics] {message}`)
	end
end

local function isCount(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 0 and value < math.huge
end

local function isPositiveCount(value: any): boolean
	return isCount(value) and value > 0
end

local function isWorld(worldId: any): boolean
	return type(worldId) == "string" and WorldConfig[worldId] ~= nil
end

-- Monde d'une zone de vente : préfixe `<WorldId>_` de l'identifiant posé
-- sur la carte. Tout autre identifiant devient la valeur inconnue (la
-- cardinalité reste bornée par WorldConfig).
function AnalyticsService.worldOfSellZone(sellZoneId: any, unknownValue: string): string
	if type(sellZoneId) == "string" then
		local prefix = string.match(sellZoneId, "^([%w]+)_")
		if prefix ~= nil and isWorld(prefix) then
			return prefix
		end
	end
	return unknownValue
end

-- Étapes d'onboarding atteintes d'après le profil : longueur du préfixe
-- continu (1 = a rejoint le jeu, 5 = premier monde débloqué).
function AnalyticsService.onboardingReached(profile: any): number
	if type(profile) ~= "table" or type(profile.stats) ~= "table" then
		return 0
	end
	local stats = profile.stats
	local upgraded = false
	for _, upgradeId in ipairs(UpgradeMath.ids()) do
		local level = UpgradeMath.levelOf(profile, upgradeId)
		local start = UpgradeMath.startLevel(upgradeId)
		if level ~= nil and start ~= nil and level > start then
			upgraded = true
			break
		end
	end
	local unlocked = 0
	if type(profile.worlds) == "table" then
		for _, isUnlocked in pairs(profile.worlds) do
			if isUnlocked == true then
				unlocked += 1
			end
		end
	end
	local reached = {
		true,
		isPositiveCount(stats.totalResourcesCollected),
		isPositiveCount(stats.totalSales),
		upgraded,
		unlocked > 1,
	}
	local prefix = 0
	for _, isReached in ipairs(reached) do
		if not isReached then
			break
		end
		prefix += 1
	end
	return prefix
end

function AnalyticsService.new(deps: Dependencies)
	local config = deps.config
	local sink = deps.sink
	local clock = deps.clock
	local getProfile = deps.getProfile
	local getPlayerCount = deps.getPlayerCount
	local log = deps.log or defaultLog
	local enabled = config.enabled == true
	local unknown: string = config.unknownValue

	local sessions: { [number]: Session } = {}
	local counters: Counters = { sent = 0, dropped = 0, failed = 0, invalid = 0 }
	local windowStart = clock()
	local windowCount = 0
	local droppedLogged = false
	local lastErrorLogAt: { [string]: number } = {}

	local service = {}

	local function limits(): (number, number)
		local players = math.max(1, getPlayerCount())
		local budget = config.Budget
		return budget.softBasePerMinute + budget.softPerPlayerPerMinute * players,
			budget.hardBasePerMinute + budget.hardPerPlayerPerMinute * players
	end

	-- Réserve une place dans la fenêtre d'une minute, ou refuse l'envoi.
	local function admit(priority: string, now: number): boolean
		if now - windowStart >= 60 then
			windowStart = now
			windowCount = 0
			droppedLogged = false
		end
		local soft, hard = limits()
		local limit = if priority == HIGH then hard else soft
		if windowCount >= limit then
			counters.dropped += 1
			if not droppedLogged then
				droppedLogged = true
				log("warn", `budget atteint ({windowCount} envois cette minute) : événements écartés`)
			end
			return false
		end
		windowCount += 1
		return true
	end

	local function reportFailure(method: string, err: any, now: number)
		counters.failed += 1
		local last = lastErrorLogAt[method]
		if last == nil or now - last >= config.Errors.logIntervalSeconds then
			lastErrorLogAt[method] = now
			log("warn", `{method} en échec (sans nouvelle tentative) : {tostring(err)}`)
		end
	end

	local function rejectInvalid(message: string)
		counters.invalid += 1
		log("warn", `événement ignoré : {message}`)
	end

	-- Envoi isolé : n'échoue jamais, ne suspend pas le fil.
	local function send(priority: string, method: string, ...: any): boolean
		local now = clock()
		if not admit(priority, now) then
			return false
		end
		local fn = (sink :: any)[method]
		local ok, err = pcall(fn, ...)
		if not ok then
			reportFailure(method, err, now)
			return false
		end
		counters.sent += 1
		return true
	end

	local function fields(...: string): Fields
		local list = { ... }
		assert(#list <= MAX_FIELDS, "au plus 3 champs personnalisés")
		return list
	end

	local function sessionOf(player: any): (Session?, number?)
		if not enabled or type(player) ~= "table" and typeof(player) ~= "Instance" then
			return nil, nil
		end
		local userId = player.UserId
		if type(userId) ~= "number" then
			return nil, nil
		end
		return sessions[userId], userId
	end

	local function advanceOnboarding(player: any, session: Session, userId: number)
		-- getProfile copie le profil : aucune lecture une fois le funnel fini.
		if session.lastOnboardingStep >= #config.Onboarding then
			return
		end
		local reached = AnalyticsService.onboardingReached(getProfile(userId))
		while session.lastOnboardingStep < reached do
			local stepInfo = config.Onboarding[session.lastOnboardingStep + 1]
			session.lastOnboardingStep += 1
			send(HIGH, "onboarding", player, stepInfo.step, stepInfo.name, nil)
		end
	end

	local function flushCollection(player: any, session: Session)
		session.lastFlushAt = clock()
		local pending = session.pending
		session.pending = {}
		for worldId, count in pairs(pending) do
			if count > 0 then
				send(LOW, "custom", player, config.Event.ResourcesCollected, count, fields(worldId))
			end
		end
	end

	local function economy(player: any, flowType: FlowType, amount: any, balance: any, kind: string, suffix: string)
		if not isPositiveCount(amount) or not isCount(balance) then
			rejectInvalid(`{kind} : montant {tostring(amount)} ou solde {tostring(balance)} invalide`)
			return
		end
		send(
			HIGH,
			"economy",
			player,
			flowType,
			config.Currency.Coins,
			amount,
			balance,
			config.TransactionType[kind],
			`{config.SkuPrefix[kind]}:{suffix}`,
			nil
		)
	end

	-- Profil chargé et joueur prêt : ouvre la session.
	function service.SessionStarted(player: any)
		if not enabled then
			return
		end
		local userId = player.UserId
		if type(userId) ~= "number" or sessions[userId] ~= nil then
			return
		end
		local profile = getProfile(userId)
		if profile == nil then
			return
		end
		local now = clock()
		local reached = AnalyticsService.onboardingReached(profile)
		local session: Session = {
			startedAt = now,
			-- Aucune étape rétroactive : seul un joueur sans progression
			-- envoie l'étape 1 ; les autres reprennent où ils en sont.
			lastOnboardingStep = if reached <= 1 then 0 else reached,
			pending = {},
			lastFlushAt = now,
			backpackFull = false,
		}
		sessions[userId] = session
		advanceOnboarding(player, session, userId)
	end

	-- Départ du joueur : envoie le lot en attente et la durée, une seule fois.
	function service.SessionEnded(player: any)
		local session, userId = sessionOf(player)
		if session == nil or userId == nil then
			return
		end
		sessions[userId] = nil
		flushCollection(player, session)
		local duration = math.max(0, math.floor(clock() - session.startedAt))
		send(HIGH, "custom", player, config.Event.SessionEnded, duration, nil)
	end

	function service.CollectSucceeded(player: any, result: any)
		local session, userId = sessionOf(player)
		if session == nil or userId == nil or type(result) ~= "table" or result.ok ~= true then
			return
		end
		local definition = ResourceConfig[result.resourceType]
		if definition == nil or not isPositiveCount(result.amount) then
			rejectInvalid(`collecte : ressource {tostring(result.resourceType)} ou quantité {tostring(result.amount)}`)
			return
		end
		local worldId = definition.worldId
		session.pending[worldId] = (session.pending[worldId] or 0) + result.amount
		if result.firstDiscovery == true then
			send(LOW, "custom", player, config.Event.JournalDiscovery, 1, fields(worldId, definition.rarity))
		end
		advanceOnboarding(player, session, userId)
	end

	-- Seul le sac plein est mesuré parmi les refus : un événement par
	-- épisode (réarmé par la vente suivante), jamais un par demande.
	function service.CollectRejected(player: any, code: any)
		local session = sessionOf(player)
		if session == nil or code ~= Remotes.ResultCode.InventoryFull or session.backpackFull then
			return
		end
		session.backpackFull = true
		send(LOW, "custom", player, config.Event.BackpackFull, 1, nil)
	end

	function service.SaleSucceeded(player: any, result: any)
		local session, userId = sessionOf(player)
		if session == nil or userId == nil or type(result) ~= "table" or result.ok ~= true then
			return
		end
		session.backpackFull = false
		flushCollection(player, session)
		local worldId = AnalyticsService.worldOfSellZone(result.sellZoneId, unknown)
		economy(player, "Source", result.coinsEarned, result.balanceAfter, "Sale", worldId)
		advanceOnboarding(player, session, userId)
	end

	function service.AchievementGranted(player: any, grant: any)
		local session = sessionOf(player)
		if session == nil or type(grant) ~= "table" then
			return
		end
		if type(grant.achievementId) ~= "string" or AchievementConfig[grant.achievementId] == nil then
			rejectInvalid(`succès inconnu {tostring(grant.achievementId)}`)
			return
		end
		economy(player, "Source", grant.reward, grant.balanceAfter, "Achievement", grant.achievementId)
	end

	function service.UpgradeSucceeded(player: any, result: any)
		local session, userId = sessionOf(player)
		if session == nil or userId == nil or type(result) ~= "table" or result.ok ~= true then
			return
		end
		local upgradeId = result.upgradeId
		if type(upgradeId) ~= "string" or UpgradeMath.startLevel(upgradeId) == nil or not isCount(result.level) then
			rejectInvalid(`amélioration {tostring(upgradeId)} niveau {tostring(result.level)}`)
			return
		end
		economy(player, "Sink", result.coinsSpent, result.balanceAfter, "Upgrade", upgradeId)
		send(LOW, "custom", player, config.Event.UpgradePurchased, 1, fields(upgradeId, tostring(result.level)))
		advanceOnboarding(player, session, userId)
	end

	function service.WorldUnlocked(player: any, result: any)
		local session, userId = sessionOf(player)
		if session == nil or userId == nil or type(result) ~= "table" or result.ok ~= true then
			return
		end
		local worldId = result.worldId
		if not isWorld(worldId) then
			rejectInvalid(`monde inconnu {tostring(worldId)}`)
			return
		end
		-- Un déblocage gratuit n'est pas un mouvement de Coins.
		if result.coinsSpent ~= 0 then
			economy(player, "Sink", result.coinsSpent, result.balanceAfter, "WorldUnlock", worldId)
		end
		send(HIGH, "progressionComplete", player, config.Progression.Worlds, WorldConfig[worldId].order, worldId, nil)
		advanceOnboarding(player, session, userId)
	end

	function service.TravelSucceeded(player: any, result: any)
		local session = sessionOf(player)
		if session == nil or type(result) ~= "table" or result.ok ~= true then
			return
		end
		if not isWorld(result.worldId) then
			rejectInvalid(`voyage vers un monde inconnu {tostring(result.worldId)}`)
			return
		end
		send(LOW, "custom", player, config.Event.WorldEntered, 1, fields(result.worldId))
	end

	-- Envoie les lots de collecte arrivés à échéance. `players` : joueurs
	-- présents (Players:GetPlayers()).
	function service.Tick(players: { any })
		if not enabled then
			return
		end
		local now = clock()
		for _, player in ipairs(players) do
			local session = sessionOf(player)
			if session ~= nil and now - session.lastFlushAt >= config.Collection.flushIntervalSeconds then
				flushCollection(player, session)
			end
		end
	end

	function service.IsSessionOpen(userId: number): boolean
		return sessions[userId] ~= nil
	end

	function service.GetCounters(): Counters
		return table.clone(counters)
	end

	return service
end

return AnalyticsService
