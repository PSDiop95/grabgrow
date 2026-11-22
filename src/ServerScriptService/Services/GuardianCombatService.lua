--!strict
-- Combat PvE contre les gardiens, entièrement décidé par le serveur (T10.3).
--
-- COMBAT INDIVIDUEL (D-028, T10-D02) : un état de combat par joueur, jamais
-- partagé. Les PV, les éclats, les attaques, les touches et la victoire du
-- joueur A n'ont aucun effet sur le combat du joueur B, même s'ils combattent
-- le même gardien au même moment. Aucun état global de gardien.
--
-- Boucle : Awakening (réveil) -> Combat (phases 1 à 3 : annonce de
-- l'attaque, fenêtre d'esquive, impact jugé sur la position VUE PAR LE
-- SERVEUR) -> victoire (PV à 0) -> délai de réapparition propre au joueur.
-- Abandon (rien n'est attribué) : sortie de l'arène prolongée, personnage
-- absent, départ du joueur, nouvelle activation impossible pendant un combat.
--
-- Le client envoie seulement « saisir l'éclat X » ({ shardId = "..." }).
-- Dégâts, PV, touches et victoire ne sont jamais acceptés du client.
-- Une touche reçue étourdit le joueur (aucune saisie) et le repousse
-- (effet affiché par son client) : ni PV de l'avatar, ni sac, ni Coins.
--
-- Dépendances injectées (horloge, hasard, positions, envoi) : testable sans
-- Roblox. Ce service n'écrit RIEN dans le profil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianRules = require(ReplicatedStorage.Shared.Util.GuardianRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local SecurityConfig = require(ServerStorage.ServerOnlyConfig.GuardianSecurityConfig)
local MovementValidator = require(script.Parent.Parent.Systems.MovementValidator)
local PayloadValidator = require(script.Parent.Parent.Systems.PayloadValidator)
local SecurityLog = require(script.Parent.SecurityLog)

local GuardianCombatService = {}

local ResultCode = Remotes.ResultCode
local Combat = GuardianConfig.Combat

GuardianCombatService.RATE_LIMIT_ACTION = "GuardianStrike"

GuardianCombatService.State = table.freeze({
	Awakening = "Awakening",
	Combat = "Combat",
})

GuardianCombatService.EndReason = table.freeze({
	Victory = "victory",
	LeftArena = "left_arena",
	NoCharacter = "no_character",
	PlayerLeft = "player_left",
})

export type Position = GuardianRules.Position

export type Site = {
	siteId: string,
	guardianId: string,
	-- Centre de l'arène (position du gardien), lu sur la carte.
	center: Position,
}

export type VictoryInfo = {
	combatId: string,
	siteId: string,
	guardianId: string,
	durationSeconds: number,
	strikes: number,
	hitsTaken: number,
}

export type Result = {
	ok: boolean,
	code: string,
	shardId: string?,
	health: number?,
	silent: boolean,
}

export type Dependencies = {
	clock: () -> number,
	-- Réel uniforme dans [min, max] (Random:NextNumber en production).
	random: (min: number, max: number) -> number,
	getCharacterPosition: (userId: number) -> Position?,
	-- Message au SEUL joueur concerné (RemoteEvent GuardianEvent).
	send: (userId: number, message: { [string]: any }) -> (),
	-- Appelé une fois par combat gagné, après la fin du combat.
	onVictory: (userId: number, info: VictoryInfo) -> (),
	rateLimit: { Allow: (userId: number, action: string) -> boolean, Clear: (userId: number) -> () },
	movement: { CanAct: (userId: number, position: any, now: number) -> (boolean, string?) }?,
	security: SecurityLog.Recorder?,
	log: ((level: string, message: string) -> ())?,
}

type PendingAttack = {
	id: number,
	definition: GuardianConfig.AttackDefinition,
	plan: GuardianRules.AttackPlan,
	impactAt: number,
	endsAt: number,
	resolved: boolean,
}

type CombatState = {
	combatId: string,
	userId: number,
	site: Site,
	guardian: GuardianConfig.GuardianDefinition,
	state: string,
	health: number,
	phase: number,
	startedAt: number,
	combatAt: number,
	nextAttackAt: number,
	attackCounter: number,
	attacks: { PendingAttack },
	shards: { [string]: Position },
	shardCount: number,
	shardRespawns: { number },
	nextStrikeAt: number,
	stunnedUntil: number,
	outsideSince: number?,
	strikes: number,
	hitsTaken: number,
	lastRateNoticeAt: number,
}

local function defaultLog(level: string, message: string)
	warn(`[Guardian] {level} : {message}`)
end

local function distance3(a: Position, b: Position): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function copyPosition(position: Position): Position
	return { X = position.X, Y = position.Y, Z = position.Z }
end

function GuardianCombatService.new(dependencies: Dependencies)
	local clock = dependencies.clock
	local random = dependencies.random
	local getCharacterPosition = dependencies.getCharacterPosition
	local send = dependencies.send
	local onVictory = dependencies.onVictory
	local rateLimit = dependencies.rateLimit
	local movement = dependencies.movement
	local security: SecurityLog.Recorder = dependencies.security or SecurityLog.none()
	local log = dependencies.log or defaultLog
	local Event = SecurityLog.Type
	local ACTION = "GuardianStrike"

	local combats: { [number]: CombatState } = {}
	-- Réapparition du gardien POUR CE JOUEUR après sa victoire (session).
	local respawnAt: { [number]: { [string]: number } } = {}
	local combatSerial = 0
	local shardSerial = 0
	local lastRateNoticeAt: { [number]: number } = {}

	local service = {}

	local function reject(code: string, shardId: string?, silent: boolean?): Result
		return { ok = false, code = code, shardId = shardId, health = nil, silent = silent == true }
	end

	local function sendCombat(combat: CombatState, now: number)
		send(combat.userId, {
			type = "combat",
			combatId = combat.combatId,
			siteId = combat.site.siteId,
			guardianId = combat.site.guardianId,
			state = combat.state,
			health = combat.health,
			maxHealth = combat.guardian.maxHealth,
			phase = combat.phase,
			awakeningSeconds = math.max(combat.combatAt - now, 0),
		})
	end

	local function spawnShard(combat: CombatState)
		shardSerial += 1
		local shardId = `sh{shardSerial}`
		local position = GuardianRules.shardPosition(combat.site.center, random)
		combat.shards[shardId] = position
		combat.shardCount += 1
		send(combat.userId, {
			type = "shard",
			combatId = combat.combatId,
			shardId = shardId,
			position = copyPosition(position),
		})
	end

	local function endCombat(combat: CombatState, reason: string)
		combats[combat.userId] = nil
		send(combat.userId, { type = "ended", combatId = combat.combatId, reason = reason })
	end

	-- Fin par victoire : le combat est retiré AVANT l'appel de onVictory,
	-- donc une seconde victoire du même combat est impossible.
	local function win(combat: CombatState, now: number)
		combats[combat.userId] = nil
		local perUser = respawnAt[combat.userId]
		if perUser == nil then
			perUser = {}
			respawnAt[combat.userId] = perUser
		end
		perUser[combat.site.siteId] = now + Combat.respawnSeconds
		send(combat.userId, {
			type = "ended",
			combatId = combat.combatId,
			reason = GuardianCombatService.EndReason.Victory,
			respawnSeconds = Combat.respawnSeconds,
		})
		local info: VictoryInfo = {
			combatId = combat.combatId,
			siteId = combat.site.siteId,
			guardianId = combat.site.guardianId,
			durationSeconds = now - combat.startedAt,
			strikes = combat.strikes,
			hitsTaken = combat.hitsTaken,
		}
		local ok, err = pcall(function()
			onVictory(combat.userId, info)
		end)
		if not ok then
			log("error", `victoire {combat.combatId} : {tostring(err)}`)
		end
	end

	-- Délai restant avant que le gardien réapparaisse pour ce joueur.
	function service.GetRespawnRemaining(userId: number, siteId: string): number
		local perUser = respawnAt[userId]
		local at = if perUser then perUser[siteId] else nil
		if at == nil then
			return 0
		end
		return math.max(at - clock(), 0)
	end

	function service.IsInCombat(userId: number): boolean
		return combats[userId] ~= nil
	end

	function service.ActiveCount(): number
		local count = 0
		for _ in pairs(combats) do
			count += 1
		end
		return count
	end

	-- Instantané en lecture seule (tests, journal).
	function service.GetCombat(userId: number): { [string]: any }?
		local combat = combats[userId]
		if combat == nil then
			return nil
		end
		local shardIds = {}
		for shardId in pairs(combat.shards) do
			table.insert(shardIds, shardId)
		end
		table.sort(shardIds)
		return {
			combatId = combat.combatId,
			siteId = combat.site.siteId,
			state = combat.state,
			health = combat.health,
			maxHealth = combat.guardian.maxHealth,
			phase = combat.phase,
			shardIds = shardIds,
			pendingAttacks = #combat.attacks,
			stunnedUntil = combat.stunnedUntil,
			hitsTaken = combat.hitsTaken,
			strikes = combat.strikes,
		}
	end

	-- Position serveur d'un éclat (tests).
	function service.GetShardPosition(userId: number, shardId: string): Position?
		local combat = combats[userId]
		local position = if combat then combat.shards[shardId] else nil
		return if position then copyPosition(position) else nil
	end

	-- Démarre le combat du joueur. Appelé par SacredSiteService APRÈS les
	-- contrôles d'accès, de monde et de distance à l'autel.
	function service.Start(userId: number, site: Site): (boolean, string)
		local guardian = GuardianConfig.Guardians[site.guardianId]
		if guardian == nil then
			return false, ResultCode.InvalidTarget
		end
		if combats[userId] ~= nil then
			return false, ResultCode.AlreadyInCombat
		end
		if service.GetRespawnRemaining(userId, site.siteId) > 0 then
			return false, ResultCode.GuardianRespawning
		end
		local now = clock()
		combatSerial += 1
		local combat: CombatState = {
			combatId = `c{combatSerial}`,
			userId = userId,
			site = { siteId = site.siteId, guardianId = site.guardianId, center = copyPosition(site.center) },
			guardian = guardian,
			state = GuardianCombatService.State.Awakening,
			health = guardian.maxHealth,
			phase = 1,
			startedAt = now,
			combatAt = now + Combat.awakeningSeconds,
			nextAttackAt = math.huge,
			attackCounter = 0,
			attacks = {},
			shards = {},
			shardCount = 0,
			shardRespawns = {},
			nextStrikeAt = -math.huge,
			stunnedUntil = -math.huge,
			outsideSince = nil,
			strikes = 0,
			hitsTaken = 0,
			lastRateNoticeAt = -math.huge,
		}
		combats[userId] = combat
		sendCombat(combat, now)
		return true, ResultCode.Success
	end

	-- Saisie d'un éclat. `payload` vient du client : non fiable.
	function service.HandleStrike(userId: number, payload: any, extraArgumentCount: number?): Result
		local now = clock()

		if not rateLimit.Allow(userId, GuardianCombatService.RATE_LIMIT_ACTION) then
			local last = lastRateNoticeAt[userId] or -math.huge
			local noticed = now - last < SecurityConfig.RateLimitFeedback.noticeIntervalSeconds
			if not noticed then
				lastRateNoticeAt[userId] = now
			end
			security.Record(userId, Event.RateLimited, { action = ACTION })
			return reject(ResultCode.RateLimited, nil, noticed)
		end

		local shardId, payloadReason =
			PayloadValidator.readId(payload, "shardId", SecurityConfig.Payload.maxIdLength, extraArgumentCount)
		if shardId == nil then
			security.Record(userId, Event.InvalidPayload, { action = ACTION, reason = payloadReason })
			return reject(ResultCode.InvalidTarget)
		end

		local combat = combats[userId]
		if combat == nil then
			-- Gardien déjà vaincu, combat abandonné ou jamais commencé.
			return reject(ResultCode.NotInCombat, shardId)
		end
		if combat.state ~= GuardianCombatService.State.Combat then
			return reject(ResultCode.NotInCombat, shardId)
		end
		local shardPosition = combat.shards[shardId]
		if shardPosition == nil then
			-- Éclat inconnu, déjà saisi, ou appartenant au combat d'un autre
			-- joueur : identique pour le client.
			security.Record(userId, Event.UnknownId, { action = ACTION, id = shardId })
			return reject(ResultCode.InvalidTarget, shardId)
		end
		if now < combat.stunnedUntil then
			return reject(ResultCode.Stunned, shardId)
		end

		local position = getCharacterPosition(userId)
		if position == nil then
			return reject(ResultCode.NoCharacter, shardId)
		end
		if not MovementValidator.isFinitePosition(position) then
			security.Record(userId, Event.MovementRefused, { action = ACTION, reason = "invalid_position" })
			return reject(ResultCode.TooFar, shardId)
		end
		local maxDistance = Combat.shards.grabRangeStuds + SecurityConfig.Distance.toleranceStuds
		if not (distance3(position, shardPosition) <= maxDistance) then
			security.Record(userId, Event.ActionRefused, { action = ACTION, code = ResultCode.TooFar })
			return reject(ResultCode.TooFar, shardId)
		end
		if movement ~= nil then
			local allowed, reason = movement.CanAct(userId, position, now)
			if not allowed then
				security.Record(userId, Event.MovementRefused, { action = ACTION, reason = reason })
				return reject(ResultCode.TooFar, shardId)
			end
		end
		if now < combat.nextStrikeAt - SecurityConfig.Cooldown.jitterToleranceSeconds then
			return reject(ResultCode.Cooldown, shardId)
		end

		-- Dégâts fixés par la configuration serveur, jamais par le client.
		combat.shards[shardId] = nil
		combat.shardCount -= 1
		table.insert(combat.shardRespawns, now + Combat.shards.respawnSeconds)
		combat.nextStrikeAt = math.max(now, combat.nextStrikeAt) + Combat.shards.minIntervalSeconds
		combat.strikes += 1
		combat.health = math.max(combat.health - Combat.shards.damage, 0)
		send(userId, { type = "shardRemoved", combatId = combat.combatId, shardId = shardId })

		if combat.health <= 0 then
			win(combat, now)
			return { ok = true, code = ResultCode.Success, shardId = shardId, health = 0, silent = false }
		end
		combat.phase = GuardianRules.phaseFor(combat.health, combat.guardian.maxHealth)
		sendCombat(combat, now)
		return { ok = true, code = ResultCode.Success, shardId = shardId, health = combat.health, silent = false }
	end

	local function applyHit(combat: CombatState, pending: PendingAttack, position: Position, now: number)
		combat.stunnedUntil = now + Combat.hit.stunSeconds
		combat.hitsTaken += 1
		local away = GuardianRules.directionTo(combat.site.center, position)
		send(combat.userId, {
			type = "hit",
			combatId = combat.combatId,
			attackId = pending.definition.id,
			direction = away,
			stunSeconds = Combat.hit.stunSeconds,
			knockbackStuds = Combat.hit.knockbackStuds,
		})
	end

	local function announceAttack(combat: CombatState, position: Position, now: number)
		local names = combat.guardian.phaseAttacks[combat.phase]
		combat.attackCounter += 1
		local attackId = names[(combat.attackCounter - 1) % #names + 1]
		local definition = combat.guardian.attacks[attackId]
		local plan = GuardianRules.planAttack(definition, combat.site.center, position, random)
		local impactAt = now + definition.telegraphSeconds
		table.insert(combat.attacks, {
			id = combat.attackCounter,
			definition = definition,
			plan = plan,
			impactAt = impactAt,
			endsAt = impactAt + (definition.lingerSeconds or 0),
			resolved = false,
		})
		combat.nextAttackAt = impactAt + combat.guardian.attackIntervalSeconds[combat.phase]
		send(combat.userId, {
			type = "attack",
			combatId = combat.combatId,
			attackId = attackId,
			serial = combat.attackCounter,
			plan = plan,
			telegraphSeconds = definition.telegraphSeconds,
			lingerSeconds = definition.lingerSeconds or 0,
		})
	end

	local function tickCombat(combat: CombatState, now: number)
		local position = getCharacterPosition(combat.userId)
		if position == nil or not MovementValidator.isFinitePosition(position) then
			endCombat(combat, GuardianCombatService.EndReason.NoCharacter)
			return
		end

		if GuardianRules.isInsideArena(combat.site.center, position, Combat.arena.radius) then
			combat.outsideSince = nil
		else
			local since = combat.outsideSince or now
			combat.outsideSince = since
			if now - since >= Combat.arena.leaveGraceSeconds then
				endCombat(combat, GuardianCombatService.EndReason.LeftArena)
				return
			end
		end

		if combat.state == GuardianCombatService.State.Awakening then
			if now < combat.combatAt then
				return
			end
			combat.state = GuardianCombatService.State.Combat
			combat.nextAttackAt = now + combat.guardian.attackIntervalSeconds[1] * 0.5
			for _ = 1, Combat.shards.activeCount do
				spawnShard(combat)
			end
			sendCombat(combat, now)
			return
		end

		-- Éclats à faire réapparaître.
		local index = 1
		while index <= #combat.shardRespawns do
			if now >= combat.shardRespawns[index] and combat.shardCount < Combat.shards.activeCount then
				table.remove(combat.shardRespawns, index)
				spawnShard(combat)
			else
				index += 1
			end
		end

		-- Résolution des attaques annoncées, sur la position serveur.
		index = 1
		while index <= #combat.attacks do
			local pending = combat.attacks[index]
			if now >= pending.impactAt then
				local stunned = now < combat.stunnedUntil
				if not pending.resolved then
					pending.resolved = true
					if not stunned and GuardianRules.isHit(pending.definition, pending.plan, position) then
						applyHit(combat, pending, position, now)
					end
				elseif not stunned and now < pending.endsAt then
					-- Zone persistante (lingerSeconds) : entrer dedans touche.
					if GuardianRules.isHit(pending.definition, pending.plan, position) then
						applyHit(combat, pending, position, now)
					end
				end
				if now >= pending.endsAt then
					table.remove(combat.attacks, index)
					continue
				end
			end
			index += 1
		end

		if now >= combat.nextAttackAt then
			announceAttack(combat, position, now)
		end
	end

	-- Boucle serveur (GuardianConfig.Combat.tickSeconds), pendant les combats
	-- seulement. Une erreur dans un combat n'interrompt pas les autres.
	function service.Tick()
		local now = clock()
		local list: { CombatState } = {}
		for _, combat in pairs(combats) do
			table.insert(list, combat)
		end
		for _, combat in ipairs(list) do
			local ok, err = pcall(function()
				tickCombat(combat, now)
			end)
			if not ok then
				log("error", `combat {combat.combatId} (joueur {combat.userId}) : {tostring(err)} ; combat abandonné`)
				if combats[combat.userId] == combat then
					endCombat(combat, GuardianCombatService.EndReason.NoCharacter)
				end
			end
		end
	end

	-- Départ du joueur : combat abandonné sans attribution, état effacé.
	function service.RemovePlayer(userId: number)
		combats[userId] = nil
		respawnAt[userId] = nil
		lastRateNoticeAt[userId] = nil
		rateLimit.Clear(userId)
	end

	-- Abandon explicite (personnage réapparu, voyage vers un autre monde).
	function service.Abandon(userId: number, reason: string)
		local combat = combats[userId]
		if combat then
			endCombat(combat, reason)
		end
	end

	return service
end

return GuardianCombatService
