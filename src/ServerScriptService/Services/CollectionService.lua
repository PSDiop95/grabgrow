--!strict
-- Collecte de ressources, entièrement validée côté serveur.
--
-- Le client n'envoie qu'un identifiant de nœud ({ resourceId = "..." }).
-- Quantité, cadence, portée et capacité sont calculées ici à partir des
-- configurations et du profil serveur. Aucun Coin n'est crédité : la vente
-- arrive en T3.
--
-- Ordre des contrôles (le moins coûteux d'abord) :
--   limite de fréquence -> profil chargé -> payload -> nœud connu -> nœud
--   actif -> personnage -> distance -> déplacement plausible -> cadence ->
--   capacité et ajout (InventoryService) -> consommation du nœud.
-- Entre le contrôle « nœud actif » et sa consommation, rien ne suspend le
-- fil : deux joueurs ne peuvent pas recevoir la même ressource.
--
-- Dépendances injectées (horloge, position du personnage, services) :
-- testable sans Roblox. Le branchement sur le RemoteEvent est dans
-- Bootstrap. Paramètres de sécurité : ServerStorage, jamais répliqués.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage.Shared.Config
local GameConfig = require(Config.GameConfig)
local ResourceConfig = require(Config.ResourceConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.CollectionSecurityConfig)
local InventoryService = require(script.Parent.InventoryService)
local ResourceSpawner = require(script.Parent.Parent.Systems.ResourceSpawner)

local CollectionService = {}

local ResultCode = Remotes.ResultCode

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
-- non vide de longueur bornée.
local function readNodeId(payload: any): string?
	if type(payload) ~= "table" then
		return nil
	end
	local nodeId = payload.resourceId
	if type(nodeId) ~= "string" or nodeId == "" or #nodeId > SecurityConfig.Payload.maxResourceIdLength then
		return nil
	end
	for key in pairs(payload) do
		if key ~= "resourceId" then
			return nil
		end
	end
	return nodeId
end

function CollectionService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local inventory = dependencies.inventory
	local spawner = dependencies.spawner
	local rateLimit = dependencies.rateLimit
	local clock = dependencies.clock
	local getCharacterPosition = dependencies.getCharacterPosition
	local log = dependencies.log or defaultLog

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
			silent = silent == true,
		}
	end

	-- Distance parcourue depuis la dernière collecte réussie, comparée à ce
	-- qu'un personnage peut couvrir à pied dans le temps écoulé.
	local function isTravelPlausible(state: PlayerState, position: Position, now: number): boolean
		local lastPosition = state.lastPosition
		if lastPosition == nil then
			return true
		end
		local elapsed = math.max(now - state.lastCollectAt, 0)
		local allowed = GameConfig.Movement.baseWalkSpeed * SecurityConfig.Travel.speedFactor * elapsed
			+ SecurityConfig.Travel.slackStuds
		return distanceBetween(position, lastPosition) <= allowed
	end

	-- Traite une demande de collecte. `payload` vient du client : non fiable.
	function service.HandleRequest(userId: number, payload: any): Result
		local now = clock()
		local state = getPlayerState(userId)

		if not rateLimit.Allow(userId, CollectionService.RATE_LIMIT_ACTION) then
			local noticed = now - state.lastRateNoticeAt < SecurityConfig.RateLimitFeedback.noticeIntervalSeconds
			if not noticed then
				state.lastRateNoticeAt = now
			end
			return reject(ResultCode.RateLimited, nil, noticed)
		end

		local profile = playerData.GetData(userId)
		if profile == nil then
			return reject(ResultCode.ProfileNotLoaded)
		end

		local nodeId = readNodeId(payload)
		if nodeId == nil then
			return reject(ResultCode.InvalidTarget)
		end
		local node = spawner.GetNode(nodeId)
		if node == nil then
			return reject(ResultCode.InvalidTarget, nodeId)
		end
		if node.state ~= ResourceSpawner.State.Active then
			return reject(ResultCode.ResourceUnavailable, nodeId)
		end

		local position = getCharacterPosition(userId)
		if position == nil then
			return reject(ResultCode.NoCharacter, nodeId)
		end
		-- Portée nominale sans Magnet (hors MVP) + marge de sécurité.
		local maxDistance = GameConfig.Collection.baseRangeStuds + SecurityConfig.Distance.toleranceStuds
		if distanceBetween(position, node.position) > maxDistance then
			return reject(ResultCode.TooFar, nodeId)
		end
		if not isTravelPlausible(state, position, now) then
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
		state.nextCollectAt = math.max(now, state.nextCollectAt) + grabber.value
		state.lastPosition = position
		state.lastCollectAt = now

		return {
			ok = true,
			code = ResultCode.Success,
			resourceId = nodeId,
			resourceType = node.resourceType,
			amount = added.granted,
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
		local grabber = UpgradeConfig.Grabber.levels[profile.upgrades.grabberLevel]
		if inventoryState == nil or grabber == nil then
			return nil
		end
		return {
			inventory = inventoryState,
			coins = profile.currencies.coins,
			collectIntervalSeconds = grabber.value,
			collectRangeStuds = GameConfig.Collection.baseRangeStuds,
		}
	end

	-- Déplacement légitime et brutal (réapparition du personnage) : oublie
	-- le lieu de la dernière collecte.
	function service.ResetTravelReference(userId: number)
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
