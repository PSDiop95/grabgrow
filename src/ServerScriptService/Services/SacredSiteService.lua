--!strict
-- Sites sacrés : accès, activation du gardien et victoires (T10.3).
--
-- Accès (GuardianRules.siteAccess, contrôlé ici côté serveur) :
--   * accès permanent après une victoire personnelle (T10-D01) ;
--   * sinon : monde du site débloqué ET toutes ses ressources ordinaires
--     découvertes dans le Journal (données v3 existantes).
-- L'accès et la victoire d'un joueur ne dépendent jamais d'un autre joueur.
--
-- Activation : { siteId = "RootSanctuary" } envoyé près de l'autel ; le
-- serveur contrôle profil, monde, accès, distance à l'autel (position vue
-- par le serveur) puis démarre le combat INDIVIDUEL (GuardianCombatService).
--
-- Victoire : attribuée une seule fois par identifiant de combat serveur,
-- au seul joueur qui a mené ce combat (aucun « dernier coup », aucune
-- présence à proximité ne suffit).
--
-- PERSISTANCE (option A, v3, D-035) : les victoires sont gardées par
-- `victoryStore`, injecté.
--   * profileVictoryStore (production) : clé
--     achievements["sanctuary_<siteId>"] = true, posée une fois par
--     PlayerDataService.Update, puis sauvegarde demandée. Si l'écriture
--     échoue, la victoire reste en session et sera réécrite à la victoire
--     suivante ou à la réclamation de la récompense.
--   * sessionVictoryStore (tests) : mémoire de session seulement.
-- Récompense : 3 unités sacrées réclamées à la terrasse
-- (SacredResourceService) ; aucun Coin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianRules = require(ReplicatedStorage.Shared.Util.GuardianRules)
local CollectionJournalRules = require(ReplicatedStorage.Shared.Util.CollectionJournalRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.GuardianSecurityConfig)
local MovementValidator = require(script.Parent.Parent.Systems.MovementValidator)
local PayloadValidator = require(script.Parent.Parent.Systems.PayloadValidator)
local SecurityLog = require(script.Parent.SecurityLog)
local GuardianCombatService = require(script.Parent.GuardianCombatService)

local SacredSiteService = {}

local ResultCode = Remotes.ResultCode
local Access = GuardianRules.Access

SacredSiteService.RATE_LIMIT_ACTION = "GuardianActivate"

export type Position = GuardianRules.Position

-- Site lu sur la carte (Systems/SacredSites).
export type MapSite = {
	siteId: string,
	guardianId: string,
	center: Position,
	altar: Position,
}

-- Support des victoires. Session aujourd'hui ; profil après autorisation.
export type VictoryStore = {
	Has: (userId: number, siteId: string) -> boolean,
	-- true si c'est la première victoire enregistrée pour ce site.
	Record: (userId: number, siteId: string) -> boolean,
	List: (userId: number) -> { [string]: boolean },
	Remove: (userId: number) -> (),
	persistent: boolean,
}

export type Result = {
	ok: boolean,
	code: string,
	siteId: string?,
	silent: boolean,
}

-- Accès en écriture au profil (PlayerDataService).
export type ProfileWriter = {
	GetData: (userId: number) -> any?,
	Update: (userId: number, mutator: (draft: any) -> boolean?) -> { ok: boolean, code: string?, message: string? },
	RequestSave: (userId: number, reason: string?) -> any,
}

export type Dependencies = {
	playerData: { GetData: (userId: number) -> any? },
	combat: {
		Start: (userId: number, site: GuardianCombatService.Site) -> (boolean, string),
		GetRespawnRemaining: (userId: number, siteId: string) -> number,
		IsInCombat: (userId: number) -> boolean,
	},
	getSite: (siteId: string) -> MapSite?,
	getCharacterPosition: (userId: number) -> Position?,
	send: (userId: number, message: { [string]: any }) -> (),
	rateLimit: { Allow: (userId: number, action: string) -> boolean, Clear: (userId: number) -> () },
	clock: () -> number,
	victoryStore: VictoryStore?,
	movement: { CanAct: (userId: number, position: any, now: number) -> (boolean, string?) }?,
	security: SecurityLog.Recorder?,
	log: ((level: string, message: string) -> ())?,
}

local function defaultLog(level: string, message: string)
	warn(`[SacredSite] {level} : {message}`)
end

local function distance3(a: Position, b: Position): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Magasin de victoires en mémoire de session (aucune persistance).
function SacredSiteService.sessionVictoryStore(): VictoryStore
	local byUser: { [number]: { [string]: boolean } } = {}
	return {
		persistent = false,
		Has = function(userId: number, siteId: string): boolean
			local sites = byUser[userId]
			return sites ~= nil and sites[siteId] == true
		end,
		Record = function(userId: number, siteId: string): boolean
			local sites = byUser[userId]
			if sites == nil then
				sites = {}
				byUser[userId] = sites
			end
			local first = sites[siteId] ~= true
			sites[siteId] = true
			return first
		end,
		List = function(userId: number): { [string]: boolean }
			local copy: { [string]: boolean } = {}
			for siteId, value in pairs(byUser[userId] or {}) do
				copy[siteId] = value
			end
			return copy
		end,
		Remove = function(userId: number)
			byUser[userId] = nil
		end,
	}
end

-- Magasin persistant (option A, v3) : clé de victoire dans
-- profile.achievements. Une copie de session couvre un échec d'écriture.
function SacredSiteService.profileVictoryStore(
	playerData: ProfileWriter,
	log: ((level: string, message: string) -> ())?
): VictoryStore
	local session = SacredSiteService.sessionVictoryStore()
	local write = log or defaultLog

	local function stored(userId: number): { [string]: boolean }
		return GuardianRules.profileVictories(playerData.GetData(userId))
	end

	return {
		persistent = true,
		Has = function(userId: number, siteId: string): boolean
			return session.Has(userId, siteId) or stored(userId)[siteId] == true
		end,
		Record = function(userId: number, siteId: string): boolean
			local alreadyStored = stored(userId)[siteId] == true
			local first = not alreadyStored and not session.Has(userId, siteId)
			session.Record(userId, siteId)
			if alreadyStored then
				return false
			end
			local key = GuardianRules.victoryKey(siteId)
			local result = playerData.Update(userId, function(draft: any): boolean?
				if type(draft.achievements) ~= "table" or draft.achievements[key] == true then
					return false
				end
				draft.achievements[key] = true
				return true
			end)
			if result.ok then
				playerData.RequestSave(userId, "guardian_victory")
			else
				write(
					"warn",
					`victoire {siteId} du joueur {userId} non enregistrée ({tostring(result.code)}) : gardée en session`
				)
			end
			return first
		end,
		List = function(userId: number): { [string]: boolean }
			local merged = stored(userId)
			for siteId, value in pairs(session.List(userId)) do
				merged[siteId] = value
			end
			return merged
		end,
		-- Seule la copie de session disparaît ; le profil est conservé.
		Remove = session.Remove,
	}
end

function SacredSiteService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local combat = dependencies.combat
	local getSite = dependencies.getSite
	local getCharacterPosition = dependencies.getCharacterPosition
	local send = dependencies.send
	local rateLimit = dependencies.rateLimit
	local clock = dependencies.clock
	local victoryStore = dependencies.victoryStore or SacredSiteService.sessionVictoryStore()
	local movement = dependencies.movement
	local security: SecurityLog.Recorder = dependencies.security or SecurityLog.none()
	local log = dependencies.log or defaultLog
	local Event = SecurityLog.Type
	local ACTION = "GuardianActivate"

	-- Combats déjà attribués (anti-doublon), par identifiant serveur.
	local grantedCombats: { [string]: number } = {}
	local lastRateNoticeAt: { [number]: number } = {}

	local service = {}

	local function reject(code: string, siteId: string?, silent: boolean?): Result
		return { ok = false, code = code, siteId = siteId, silent = silent == true }
	end

	local function accessFor(profile: any, userId: number, siteId: string): string
		local discovered = if type(profile.collection) == "table"
			then CollectionJournalRules.publicView(profile.collection.discoveredResources)
			else {}
		return GuardianRules.siteAccess(siteId, profile.worlds, discovered, victoryStore.List(userId))
	end

	-- Vue d'affichage envoyée au client : accès et réapparition par site.
	function service.GetView(userId: number): { [string]: any }?
		local profile = playerData.GetData(userId)
		if profile == nil then
			return nil
		end
		local sites: { [string]: any } = {}
		for siteId in pairs(GuardianConfig.Sites) do
			sites[siteId] = {
				access = accessFor(profile, userId, siteId),
				respawnSeconds = combat.GetRespawnRemaining(userId, siteId),
				-- Récompense de première victoire déjà réclamée (D-035).
				rewardClaimed = GuardianRules.rewardClaimed(profile, siteId),
			}
		end
		return { type = "sites", sites = sites, persistent = victoryStore.persistent }
	end

	function service.SendView(userId: number)
		local view = service.GetView(userId)
		if view then
			send(userId, view)
		end
	end

	function service.HasVictory(userId: number, siteId: string): boolean
		return victoryStore.Has(userId, siteId)
	end

	-- Demande d'activation. `payload` vient du client : non fiable.
	function service.HandleActivate(userId: number, payload: any, extraArgumentCount: number?): Result
		local now = clock()

		if not rateLimit.Allow(userId, SacredSiteService.RATE_LIMIT_ACTION) then
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

		local siteId, payloadReason =
			PayloadValidator.readId(payload, "siteId", SecurityConfig.Payload.maxIdLength, extraArgumentCount)
		if siteId == nil then
			security.Record(userId, Event.InvalidPayload, { action = ACTION, reason = payloadReason })
			return reject(ResultCode.InvalidTarget)
		end
		local definition = GuardianConfig.Sites[siteId]
		local site = if definition then getSite(siteId) else nil
		if definition == nil or site == nil then
			security.Record(userId, Event.UnknownId, { action = ACTION, id = siteId })
			return reject(ResultCode.InvalidTarget, siteId)
		end

		local access = accessFor(profile, userId, siteId)
		if access == Access.WorldLocked then
			security.Record(userId, Event.ActionRefused, { action = ACTION, code = ResultCode.WorldLocked })
			return reject(ResultCode.WorldLocked, siteId)
		elseif access == Access.DiscoveryRequired then
			return reject(ResultCode.RequirementNotMet, siteId)
		elseif access ~= Access.Eligible and access ~= Access.Unlocked then
			return reject(ResultCode.InvalidTarget, siteId)
		end

		local position = getCharacterPosition(userId)
		if position == nil then
			return reject(ResultCode.NoCharacter, siteId)
		end
		if not MovementValidator.isFinitePosition(position) then
			security.Record(userId, Event.MovementRefused, { action = ACTION, reason = "invalid_position" })
			return reject(ResultCode.TooFar, siteId)
		end
		local maxDistance = GuardianConfig.Combat.arena.altarRangeStuds + SecurityConfig.Distance.toleranceStuds
		if not (distance3(position, site.altar) <= maxDistance) then
			security.Record(userId, Event.ActionRefused, { action = ACTION, code = ResultCode.TooFar })
			return reject(ResultCode.TooFar, siteId)
		end
		if movement ~= nil then
			local allowed, reason = movement.CanAct(userId, position, now)
			if not allowed then
				security.Record(userId, Event.MovementRefused, { action = ACTION, reason = reason })
				return reject(ResultCode.TooFar, siteId)
			end
		end

		local started, code = combat.Start(userId, {
			siteId = siteId,
			guardianId = site.guardianId,
			center = site.center,
		})
		if not started then
			return reject(code, siteId)
		end
		return { ok = true, code = ResultCode.Success, siteId = siteId, silent = false }
	end

	-- Appelé par GuardianCombatService.onVictory, jamais par le client.
	-- Attribution unique par combat ; retourne true si attribuée maintenant.
	function service.RecordVictory(userId: number, info: GuardianCombatService.VictoryInfo): boolean
		if grantedCombats[info.combatId] ~= nil then
			log("warn", `victoire {info.combatId} déjà attribuée (joueur {userId}) : ignorée`)
			return false
		end
		if GuardianConfig.Sites[info.siteId] == nil then
			log("error", `victoire {info.combatId} : site inconnu {tostring(info.siteId)}`)
			return false
		end
		if GuardianConfig.Sites[info.siteId].guardianId ~= info.guardianId then
			log("error", `victoire {info.combatId} : gardien incohérent {tostring(info.guardianId)} pour {info.siteId}`)
			return false
		end
		grantedCombats[info.combatId] = userId
		local firstVictory = victoryStore.Record(userId, info.siteId)
		-- Journal d'attribution (motif stable). Aucun Coin (D-035).
		print(
			`[Guardian] GuardianReward:{info.guardianId} user={userId} combat={info.combatId} first={firstVictory} `
				.. `duration={math.floor(info.durationSeconds)}s strikes={info.strikes} hits={info.hitsTaken} `
				.. `persistent={victoryStore.persistent}`
		)
		send(userId, {
			type = "victory",
			combatId = info.combatId,
			siteId = info.siteId,
			guardianId = info.guardianId,
			firstVictory = firstVictory,
			persistent = victoryStore.persistent,
		})
		service.SendView(userId)
		return true
	end

	function service.RemovePlayer(userId: number)
		lastRateNoticeAt[userId] = nil
		rateLimit.Clear(userId)
		-- Copie de session effacée ; les victoires du profil restent.
		victoryStore.Remove(userId)
	end

	return service
end

return SacredSiteService
