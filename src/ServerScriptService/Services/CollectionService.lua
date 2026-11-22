--!strict
-- Collecte de ressources, entièrement validée côté serveur.
--
-- Le client n'envoie qu'un identifiant de nœud ({ resourceId = "..." }).
-- Quantité, cadence, portée et capacité sont calculées ici à partir des
-- configurations et du profil serveur. Aucun Coin n'est crédité ici.
--
-- T4 (D-015) : portée = Magnet, intervalle = Grabber, vitesse de référence
-- du contrôle de trajet = Boots, tous lus à chaque demande dans le profil
-- serveur. Une amélioration achetée s'applique donc à la demande suivante.
--
-- Ordre des contrôles (le moins coûteux d'abord) :
--   limite de fréquence -> profil chargé -> payload -> nœud connu -> monde
--   de la ressource débloqué (T8) -> nœud actif -> personnage (position
--   finie) -> distance -> déplacements
--   (MovementValidator, T6) -> trajet depuis la dernière collecte -> cadence
--   -> capacité et ajout (InventoryService) -> consommation du nœud.
-- T6 : les refus sont journalisés par SecurityLog (limité par joueur).
-- Entre le contrôle « nœud actif » et sa consommation, rien ne suspend le
-- fil : deux joueurs ne peuvent pas recevoir la même ressource.
--
-- Dépendances injectées (horloge, position du personnage, services) :
-- testable sans Roblox. Le branchement sur le RemoteEvent est dans
-- Bootstrap. Paramètres de sécurité : ServerStorage, jamais répliqués.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage.Shared.Config
local ResourceConfig = require(Config.ResourceConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local UpgradeMath = require(ReplicatedStorage.Shared.Util.UpgradeMath)
local SacredUpgradeRules = require(ReplicatedStorage.Shared.Util.SacredUpgradeRules)
local CollectionJournalRules = require(ReplicatedStorage.Shared.Util.CollectionJournalRules)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.CollectionSecurityConfig)
local InventoryService = require(script.Parent.InventoryService)
local ResourceSpawner = require(script.Parent.Parent.Systems.ResourceSpawner)
local MovementValidator = require(script.Parent.Parent.Systems.MovementValidator)
local PayloadValidator = require(script.Parent.Parent.Systems.PayloadValidator)
local SecurityLog = require(script.Parent.SecurityLog)

local CollectionService = {}

local ResultCode = Remotes.ResultCode

-- Statistique entière du profil (DataSchema garantit son type) ; 0 sinon.
local function statOf(profile: any, statId: string): number
	local stats = profile.stats
	local value = if type(stats) == "table" then stats[statId] else nil
	return if type(value) == "number" then value else 0
end

-- Le monde de la ressource est-il débloqué dans le profil serveur ?
-- Ressource inconnue, monde absent ou section `worlds` illisible : non.
local function isWorldUnlocked(profile: any, resourceType: string): boolean
	local definition = ResourceConfig[resourceType]
	local worlds = profile.worlds
	if definition == nil or type(worlds) ~= "table" then
		return false
	end
	return worlds[definition.worldId] == true
end

-- Nom de la limite dans CollectionSecurityConfig.RateLimits.
CollectionService.RATE_LIMIT_ACTION = "Collect"

export type Position = ResourceSpawner.Position

export type Result = {
	ok: boolean,
	code: string,
	-- Identifiant de nœud demandé, s'il était lisible.
	resourceId: string?,
	-- Renseignés en cas de succès uniquement.
	resourceType: string?,
	amount: number,
	-- T8.6 : première découverte de la ressource (journal), calculée par le
	-- serveur dans la mutation de l'ajout. false en cas de refus.
	firstDiscovery: boolean,
	-- true : ne pas répondre au client (rejets en rafale déjà signalés).
	silent: boolean,
}

-- État public envoyé au client pour l'affichage. Les marges de sécurité
-- n'y figurent pas.
export type ClientState = {
	inventory: InventoryService.State,
	-- Solde affiché par le HUD (T3). Miroir : jamais une source d'autorité.
	coins: number,
	collectIntervalSeconds: number,
	collectRangeStuds: number,
	-- T4 : niveaux par amélioration (clés de UpgradeConfig), mondes
	-- débloqués, multiplicateur de vente et vitesse. Affichage seulement.
	upgrades: { [string]: number },
	worlds: { [string]: boolean },
	sellMultiplier: number,
	walkSpeed: number,
	-- T5.3 : statistiques persistantes utiles au guidage de première
	-- session (copie en lecture seule de profile.stats). Affichage seulement :
	-- le client ne les renvoie jamais et rien ne les lit côté serveur.
	progress: Progress,
	-- T8.6 (D-022) : journal de collection, ressources découvertes
	-- { [identifiant de ResourceConfig] = true } (identifiants inconnus
	-- filtrés). Lecture seule : aucune demande client ne le modifie.
	discovered: { [string]: boolean },
	-- T10.5a (D-038) : améliorations sacrées acquises { [upgradeId] = true }.
	-- Portée et intervalle ci-dessus les incluent déjà. Affichage seulement.
	sacredUpgrades: { [string]: boolean },
}

export type Progress = {
	resourcesCollected: number,
	sales: number,
	coinsSpent: number,
}

export type Dependencies = {
	playerData: { GetData: (userId: number) -> any? },
	inventory: {
		AddResource: (userId: number, resourceId: string, amount: number) -> InventoryService.AddResult,
	},
	spawner: {
		GetNode: (nodeId: string) -> ResourceSpawner.Node?,
		TryCollect: (nodeId: string) -> boolean,
	},
	rateLimit: { Allow: (userId: number, action: string) -> boolean, Clear: (userId: number) -> () },
	-- Horloge monotone en secondes (os.clock en production).
	clock: () -> number,
	-- Position du personnage VUE PAR LE SERVEUR, ou nil s'il est absent ou
	-- mort. Jamais une position envoyée par le client.
	getCharacterPosition: (userId: number) -> Position?,
	-- T6 (facultatifs) : contrôle des déplacements et journal de sécurité.
	movement: { CanAct: (userId: number, position: any, now: number) -> (boolean, string?) }?,
	security: SecurityLog.Recorder?,
	log: ((level: string, message: string) -> ())?,
}

type PlayerState = {
	-- Échéance nominale de la prochaine collecte.
	nextCollectAt: number,
	-- Lieu et heure de la dernière collecte réussie (plausibilité du trajet).
	lastPosition: Position?,
	lastCollectAt: number,
	lastRateNoticeAt: number,
	lastSuspiciousLogAt: number,
}

local function defaultLog(level: string, message: string)
	warn(`[Collection] {level} : {message}`)
end

local function distanceBetween(a: Position, b: Position): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Seule forme acceptée : une table avec l'unique champ `resourceId`, texte
-- non vide de longueur bornée, sans argument supplémentaire (PayloadValidator).
local function readNodeId(payload: any, extraArgumentCount: number?): (string?, string?)
	return PayloadValidator.readId(payload, "resourceId", SecurityConfig.Payload.maxResourceIdLength, extraArgumentCount)
end

function CollectionService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local inventory = dependencies.inventory
	local spawner = dependencies.spawner
	local rateLimit = dependencies.rateLimit
	local clock = dependencies.clock
	local getCharacterPosition = dependencies.getCharacterPosition
	local movement = dependencies.movement
	local security: SecurityLog.Recorder = dependencies.security or SecurityLog.none()
	local log = dependencies.log or defaultLog
	local Event = SecurityLog.Type
	local ACTION = "Collect"

	local players: { [number]: PlayerState } = {}

	local service = {}

	local function getPlayerState(userId: number): PlayerState
		local state = players[userId]
		if state == nil then
			state = {
				nextCollectAt = -math.huge,
				lastPosition = nil,
				lastCollectAt = -math.huge,
				lastRateNoticeAt = -math.huge,
				lastSuspiciousLogAt = -math.huge,
			}
			players[userId] = state
		end
		return state
	end

	local function reject(code: string, nodeId: string?, silent: boolean?): Result
		return {
			ok = false,
			code = code,
			resourceId = nodeId,
			resourceType = nil,
			amount = 0,
			firstDiscovery = false,
			silent = silent == true,
		}
	end

	-- Distance parcourue depuis la dernière collecte réussie, comparée à ce
	-- qu'un personnage peut couvrir à pied dans le temps écoulé.
	-- `walkSpeed` = vitesse des Boots du profil serveur.
	local function isTravelPlausible(state: PlayerState, position: Position, now: number, walkSpeed: number): boolean
		local lastPosition = state.lastPosition
		if lastPosition == nil then
			return true
		end
		local elapsed = math.max(now - state.lastCollectAt, 0)
		local allowed = walkSpeed * SecurityConfig.Travel.speedFactor * elapsed
			+ SecurityConfig.Travel.slackStuds
		return distanceBetween(position, lastPosition) <= allowed
	end

	-- Traite une demande de collecte. `payload` vient du client : non fiable.
	-- `extraArgumentCount` : arguments reçus après le payload (0 attendu).
	function service.HandleRequest(userId: number, payload: any, extraArgumentCount: number?): Result
		local now = clock()
		local state = getPlayerState(userId)

		if not rateLimit.Allow(userId, CollectionService.RATE_LIMIT_ACTION) then
			local noticed = now - state.lastRateNoticeAt < SecurityConfig.RateLimitFeedback.noticeIntervalSeconds
			if not noticed then
				state.lastRateNoticeAt = now
			end
			security.Record(userId, Event.RateLimited, { action = ACTION })
			return reject(ResultCode.RateLimited, nil, noticed)
		end

		local profile = playerData.GetData(userId)
		if profile == nil then
			security.Record(userId, Event.ProfileNotLoaded, { action = ACTION })
			return reject(ResultCode.ProfileNotLoaded)
		end

		local nodeId, payloadReason = readNodeId(payload, extraArgumentCount)
		if nodeId == nil then
			security.Record(userId, Event.InvalidPayload, { action = ACTION, reason = payloadReason })
			return reject(ResultCode.InvalidTarget)
		end
		local node = spawner.GetNode(nodeId)
		if node == nil then
			security.Record(userId, Event.UnknownId, { action = ACTION, id = nodeId })
			return reject(ResultCode.InvalidTarget, nodeId)
		end
		-- T8 (D-021) : le monde de la ressource (ResourceConfig, serveur) doit
		-- être débloqué dans le profil serveur. Indépendant de la carte et de
		-- la position : une demande falsifiée vers un nœud d'un monde
		-- verrouillé est refusée même si le personnage est à portée.
		if not isWorldUnlocked(profile, node.resourceType) then
			security.Record(userId, Event.ActionRefused, { action = ACTION, code = ResultCode.WorldLocked })
			return reject(ResultCode.WorldLocked, nodeId)
		end
		if node.state ~= ResourceSpawner.State.Active then
			return reject(ResultCode.ResourceUnavailable, nodeId)
		end

		local position = getCharacterPosition(userId)
		if position == nil then
			return reject(ResultCode.NoCharacter, nodeId)
		end
		-- NaN ou infini : toute comparaison serait fausse et laisserait passer.
		if not MovementValidator.isFinitePosition(position) then
			security.Record(userId, Event.MovementRefused, { action = ACTION, reason = "invalid_position" })
			return reject(ResultCode.TooFar, nodeId)
		end
		-- Portée nominale du Magnet (profil serveur) + marge de sécurité.
		local range = UpgradeMath.valueFor(profile, "Magnet")
		local walkSpeed = UpgradeMath.valueFor(profile, "Boots")
		if range == nil or walkSpeed == nil then
			log("error", `joueur {userId} : magnetLevel ou bootsLevel inconnu`)
			return reject(ResultCode.InternalError, nodeId)
		end
		-- T10.5a (D-038) : Magnet sacré, portée ajoutée si acquis.
		local maxDistance = SacredUpgradeRules.collectRange(profile, range) + SecurityConfig.Distance.toleranceStuds
		if not (distanceBetween(position, node.position) <= maxDistance) then
			security.Record(userId, Event.ActionRefused, { action = ACTION, code = ResultCode.TooFar })
			return reject(ResultCode.TooFar, nodeId)
		end
		-- T6 : déplacements récents jugés par MovementValidator (R2 : TOO_FAR).
		if movement ~= nil then
			local allowed, reason = movement.CanAct(userId, position, now)
			if not allowed then
				security.Record(userId, Event.MovementRefused, { action = ACTION, reason = reason })
				return reject(ResultCode.TooFar, nodeId)
			end
		end
		if not isTravelPlausible(state, position, now, walkSpeed) then
			security.Record(userId, Event.MovementRefused, { action = ACTION, reason = "travel" })
			if now - state.lastSuspiciousLogAt >= SecurityConfig.Logging.suspiciousIntervalSeconds then
				state.lastSuspiciousLogAt = now
				log("warn", `joueur {userId} : déplacement implausible entre deux collectes ({nodeId})`)
			end
			return reject(ResultCode.TooFar, nodeId)
		end

		local grabber = UpgradeConfig.Grabber.levels[profile.upgrades.grabberLevel]
		if grabber == nil then
			log("error", `joueur {userId} : grabberLevel inconnu ({tostring(profile.upgrades.grabberLevel)})`)
			return reject(ResultCode.InternalError, nodeId)
		end
		if now < state.nextCollectAt - SecurityConfig.Cooldown.jitterToleranceSeconds then
			return reject(ResultCode.Cooldown, nodeId)
		end

		local definition = ResourceConfig[node.resourceType]
		local added = inventory.AddResource(userId, node.resourceType, definition.collectAmount)
		if not added.ok then
			if added.code == InventoryService.Code.InventoryFull then
				-- La ressource reste disponible.
				return reject(ResultCode.InventoryFull, nodeId)
			elseif added.code == InventoryService.Code.NotLoaded then
				return reject(ResultCode.ProfileNotLoaded, nodeId)
			end
			log("error", `joueur {userId} : ajout refusé ({tostring(added.code)}) pour {nodeId}`)
			return reject(ResultCode.InternalError, nodeId)
		end

		-- Ne peut pas échouer : le nœud était actif et rien n'a suspendu le fil.
		if not spawner.TryCollect(nodeId) then
			log("error", `nœud {nodeId} crédité au joueur {userId} mais non consommé`)
		end

		-- Échéance calée sur l'intervalle nominal : une demande arrivée en
		-- avance (gigue) ne raccourcit pas la suivante.
		-- T10.5a (D-038) : Grabber sacré, intervalle réduit si acquis.
		state.nextCollectAt = math.max(now, state.nextCollectAt)
			+ SacredUpgradeRules.collectInterval(profile, grabber.value)
		state.lastPosition = position
		state.lastCollectAt = now

		return {
			ok = true,
			code = ResultCode.Success,
			resourceId = nodeId,
			resourceType = node.resourceType,
			amount = added.granted,
			firstDiscovery = added.firstDiscovery == true,
			silent = false,
		}
	end

	-- État public du joueur pour l'affichage, ou nil si le profil n'est pas
	-- chargé.
	function service.GetClientState(userId: number): ClientState?
		local profile = playerData.GetData(userId)
		if profile == nil then
			return nil
		end
		local inventoryState = InventoryService.describe(profile)
		local interval = UpgradeMath.valueFor(profile, "Grabber")
		local range = UpgradeMath.valueFor(profile, "Magnet")
		local multiplier = UpgradeMath.valueFor(profile, "Multiplier")
		local walkSpeed = UpgradeMath.valueFor(profile, "Boots")
		if inventoryState == nil or interval == nil or range == nil or multiplier == nil or walkSpeed == nil then
			return nil
		end
		local upgrades: { [string]: number } = {}
		for _, upgradeId in ipairs(UpgradeMath.ids()) do
			upgrades[upgradeId] = UpgradeMath.levelOf(profile, upgradeId) :: number
		end
		local worlds: { [string]: boolean } = {}
		for worldId, unlocked in pairs(profile.worlds) do
			if type(worldId) == "string" and unlocked == true then
				worlds[worldId] = true
			end
		end
		return {
			inventory = inventoryState,
			coins = profile.currencies.coins,
			collectIntervalSeconds = SacredUpgradeRules.collectInterval(profile, interval),
			collectRangeStuds = SacredUpgradeRules.collectRange(profile, range),
			-- T10.5a : améliorations sacrées acquises (affichage, boussole).
			sacredUpgrades = SacredUpgradeRules.owned(profile),
			upgrades = upgrades,
			worlds = worlds,
			sellMultiplier = multiplier,
			walkSpeed = walkSpeed,
			progress = {
				resourcesCollected = statOf(profile, "totalResourcesCollected"),
				sales = statOf(profile, "totalSales"),
				coinsSpent = statOf(profile, "totalCoinsSpent"),
			},
			discovered = CollectionJournalRules.publicView(
				if type(profile.collection) == "table" then profile.collection.discoveredResources else nil
			),
		}
	end

	-- Déplacement légitime et brutal (réapparition du personnage).
	-- T6 : avec `position` (connue du SERVEUR, ex. point d'apparition), la
	-- référence devient cette position à l'instant présent : un « Reset »
	-- volontaire ne permet plus une collecte n'importe où. Sans position
	-- (ou position non finie), la référence est oubliée (comportement T2).
	function service.ResetTravelReference(userId: number, position: Position?)
		if position ~= nil and MovementValidator.isFinitePosition(position) then
			local state = getPlayerState(userId)
			state.lastPosition = { X = position.X, Y = position.Y, Z = position.Z }
			state.lastCollectAt = clock()
			return
		end
		local state = players[userId]
		if state then
			state.lastPosition = nil
		end
	end

	-- À appeler quand le joueur quitte.
	function service.RemovePlayer(userId: number)
		players[userId] = nil
		rateLimit.Clear(userId)
	end

	return service
end

return CollectionService
