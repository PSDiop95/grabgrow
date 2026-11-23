--!strict
-- Tests des gardiens et des sites sacrés (T10.3, D-034). Logique pure :
-- horloge, hasard, positions et envois simulés ; aucune API Roblox.
-- Couvre : combat solo, deux et quatre joueurs (états indépendants),
-- déconnexion, distance, cadence, falsifications (champ en trop, éclat d'un
-- autre joueur), gardien déjà vaincu, double attribution, non-participant,
-- monde verrouillé, accès permanent, ressource sacrée et sac plein,
-- résolution des attaques sur la position serveur, sortie de l'arène.
-- Le rendu (télégraphies, animation locale) se vérifie dans Studio.

local GuardianTests = {}

export type Modules = {
	GuardianConfig: any,
	GuardianRules: any,
	GuardianCombatService: any,
	SacredSiteService: any,
	SacredResourceService: any,
	RateLimitService: any,
	GuardianSecurityConfig: any,
	ResourceConfig: any,
	Localization: any,
	Remotes: any,
	SacredResourceConfig: any,
	AchievementConfig: any,
}

function GuardianTests.run(modules: Modules): ({ string }, number)
	local GuardianConfig = modules.GuardianConfig
	local GuardianRules = modules.GuardianRules
	local GuardianCombatService = modules.GuardianCombatService
	local SacredSiteService = modules.SacredSiteService
	local RateLimitService = modules.RateLimitService
	local SecurityConfig = modules.GuardianSecurityConfig
	local ResourceConfig = modules.ResourceConfig
	local Localization = modules.Localization
	local SacredResourceConfig = modules.SacredResourceConfig
	local AchievementConfig = modules.AchievementConfig
	local Code = modules.Remotes.ResultCode
	local Combat = GuardianConfig.Combat
	local Access = GuardianRules.Access

	local failures: { string } = {}
	local caseCount = 0

	local function case(name: string, body: (check: (condition: boolean, message: string) -> ()) -> ())
		caseCount += 1
		local ok, err = pcall(body :: any, function(condition: boolean, message: string)
			if not condition then
				table.insert(failures, `{name} : {message}`)
			end
		end)
		if not ok then
			table.insert(failures, `{name} : erreur {tostring(err)}`)
		end
	end

	-- Environnement simulé ------------------------------------------------

	local CENTERS = {
		RootSanctuary = { X = 0, Y = 0, Z = 0 },
		SunTemple = { X = 3000, Y = 0, Z = 0 },
		FrostAltar = { X = -3000, Y = 0, Z = 0 },
		AstralSanctuary = { X = 0, Y = 4, Z = 3000 },
	}

	local ALL_WORLDS = { GreenValley = true, GoldenDesert = true, FrozenPeaks = true, MysticWorld = true }

	local function discoveredAll(): { [string]: boolean }
		local list: { [string]: boolean } = {}
		for resourceId in pairs(ResourceConfig) do
			list[resourceId] = true
		end
		return list
	end

	local function newProfile(worlds: { [string]: boolean }?, discovered: { [string]: boolean }?): any
		return {
			worlds = worlds or table.clone(ALL_WORLDS),
			collection = { discoveredResources = discovered or discoveredAll() },
			inventory = { resources = {} },
			upgrades = { backpackLevel = 1 },
		}
	end

	local function newEnv(options: { victoryStore: any? }?)
		local env: any = {
			now = 100,
			positions = {},
			profiles = {},
			messages = {},
			victories = {},
			seed = 12345,
		}
		local function clock(): number
			return env.now
		end
		-- Générateur congruentiel : déterministe, valeurs variées.
		local function random(min: number, max: number): number
			env.seed = (env.seed * 1103515245 + 12345) % 2147483648
			return min + (max - min) * (env.seed / 2147483648)
		end
		local rateLimit = RateLimitService.new({
			clock = clock,
			limits = SecurityConfig.RateLimits,
			logEveryRejections = 1000,
			log = function() end,
		})
		local function send(userId: number, message: any)
			local list = env.messages[userId]
			if list == nil then
				list = {}
				env.messages[userId] = list
			end
			table.insert(list, message)
		end
		local sites: any
		env.combat = GuardianCombatService.new({
			clock = clock,
			random = random,
			getCharacterPosition = function(userId: number)
				return env.positions[userId]
			end,
			send = send,
			onVictory = function(userId: number, info: any)
				table.insert(env.victories, { userId = userId, info = info })
				sites.RecordVictory(userId, info)
			end,
			rateLimit = rateLimit,
			log = function() end,
		})
		sites = SacredSiteService.new({
			playerData = {
				GetData = function(userId: number)
					return env.profiles[userId]
				end,
			},
			combat = env.combat,
			getSite = function(siteId: string): any
				local center = CENTERS[siteId]
				local definition = GuardianConfig.Sites[siteId]
				if center == nil or definition == nil then
					return nil
				end
				return {
					siteId = siteId,
					guardianId = definition.guardianId,
					center = center,
					altar = { X = center.X, Y = center.Y, Z = center.Z + 23 },
				}
			end,
			getCharacterPosition = function(userId: number)
				return env.positions[userId]
			end,
			send = send,
			rateLimit = rateLimit,
			clock = clock,
			victoryStore = if options then options.victoryStore else nil,
			log = function() end,
		})
		env.sites = sites
		env.rateLimit = rateLimit
		env.random = random

		function env.addPlayer(userId: number, profile: any?)
			env.profiles[userId] = profile or newProfile()
			env.positions[userId] = { X = 0, Y = 3, Z = 23 }
		end
		function env.atAltar(userId: number, siteId: string)
			local center = CENTERS[siteId]
			env.positions[userId] = { X = center.X, Y = center.Y + 3, Z = center.Z + 23 }
		end
		function env.advance(seconds: number)
			local target = env.now + seconds
			while env.now < target do
				env.now = math.min(env.now + Combat.tickSeconds, target)
				env.combat.Tick()
			end
		end
		function env.start(userId: number, siteId: string): any
			env.atAltar(userId, siteId)
			return sites.HandleActivate(userId, { siteId = siteId }, 0)
		end
		-- Saisit un éclat en se plaçant dessus (position serveur).
		function env.strikeOne(userId: number): any
			local snapshot = env.combat.GetCombat(userId)
			if snapshot == nil or #snapshot.shardIds == 0 then
				return nil
			end
			local shardId = snapshot.shardIds[1]
			local position = env.combat.GetShardPosition(userId, shardId)
			env.positions[userId] = { X = position.X, Y = position.Y + 3, Z = position.Z }
			return env.combat.HandleStrike(userId, { shardId = shardId }, 0)
		end
		-- Combat gagné en restant hors des zones (le temps avance assez pour
		-- la cadence et la réapparition des éclats ; la limite de fréquence
		-- n'est pas atteinte).
		function env.winFight(userId: number, siteId: string): boolean
			local result = env.start(userId, siteId)
			if not result.ok then
				return false
			end
			env.advance(Combat.awakeningSeconds + 0.1)
			for _ = 1, 400 do
				if env.combat.GetCombat(userId) == nil then
					return true
				end
				env.combat.Tick()
				-- Étourdi : attendre la fin de l'étourdissement.
				local snapshot = env.combat.GetCombat(userId)
				if snapshot and env.now < snapshot.stunnedUntil then
					env.advance(snapshot.stunnedUntil - env.now + 0.05)
				end
				env.strikeOne(userId)
				env.now += Combat.shards.minIntervalSeconds + 0.3
			end
			return env.combat.GetCombat(userId) == nil
		end
		function env.lastMessage(userId: number, kind: string): any?
			local list = env.messages[userId] or {}
			for index = #list, 1, -1 do
				if list[index].type == kind then
					return list[index]
				end
			end
			return nil
		end
		function env.count(userId: number, kind: string): number
			local count = 0
			for _, message in ipairs(env.messages[userId] or {}) do
				if message.type == kind then
					count += 1
				end
			end
			return count
		end
		return env
	end

	-- Configuration -----------------------------------------------------------

	case("configuration : quatre gardiens et sites cohérents", function(check)
		local count = 0
		for siteId, site in pairs(GuardianConfig.Sites) do
			count += 1
			local guardian = GuardianConfig.Guardians[site.guardianId]
			check(guardian ~= nil, `{siteId} : gardien inconnu`)
			if guardian then
				check(guardian.siteId == siteId and guardian.worldId == site.worldId, `{siteId} : site/monde incohérent`)
				check(#guardian.attackIntervalSeconds == 3 and #guardian.phaseAttacks == 3, `{siteId} : 3 phases attendues`)
				for _, list in ipairs(guardian.phaseAttacks) do
					for _, attackId in ipairs(list) do
						local attack = guardian.attacks[attackId]
						check(attack ~= nil, `{siteId} : attaque {attackId} inconnue`)
						if attack then
							-- Fenêtre d'esquive minimale (lisibilité mobile).
							check(attack.telegraphSeconds >= 1.5, `{attackId} : télégraphie < 1,5 s`)
						end
					end
				end
			end
		end
		check(count == 4, `4 sites attendus, {count}`)
	end)

	case("configuration : ressources sacrées dédiées (D-035)", function(check)
		local seen: { [string]: boolean } = {}
		local count = 0
		for resourceId, definition in pairs(SacredResourceConfig.Resources) do
			count += 1
			local site = GuardianConfig.Sites[definition.siteId]
			check(site ~= nil, `{resourceId} : site {definition.siteId} inconnu`)
			check(site == nil or site.worldId == definition.worldId, `{resourceId} : monde incohérent`)
			check(ResourceConfig[resourceId] == nil, `{resourceId} ne doit pas être dans ResourceConfig (Journal 20/20)`)
			check(definition.rarity == SacredResourceConfig.Rarity and SacredResourceConfig.Rarity == "Sacred", `{resourceId} : rareté`)
			check(definition.rewardUnits == 3, `{resourceId} : 3 unités attendues (D-035)`)
			check(definition.bagSlotsPerUnit == 1, `{resourceId} : 1 place par unité (D-035)`)
			check(SacredResourceConfig.BySite[definition.siteId] == resourceId, `{resourceId} : index par site`)
			check(not seen[definition.siteId], `{definition.siteId} : deux ressources`)
			seen[definition.siteId] = true
		end
		check(count == 4 and #SacredResourceConfig.Order == 4, `4 ressources sacrées attendues, {count}`)
		local total = 0
		for _ in pairs(ResourceConfig) do
			total += 1
		end
		check(total == 20, `ResourceConfig : 20 ressources attendues, {total}`)
	end)

	case("configuration : préfixes réservés des clés de profil", function(check)
		for achievementId in pairs(AchievementConfig) do
			check(
				string.sub(achievementId, 1, #GuardianRules.VICTORY_PREFIX) ~= GuardianRules.VICTORY_PREFIX,
				`succès {achievementId} : préfixe réservé`
			)
			-- T10.5a (U-A, D-037) : acquisitions des améliorations sacrées.
			check(
				string.sub(achievementId, 1, #SacredResourceConfig.UpgradePrefix) ~= SacredResourceConfig.UpgradePrefix,
				`succès {achievementId} : préfixe sacred_upgrade_ réservé`
			)
		end
		check(
			string.sub(SacredResourceConfig.UpgradePrefix, 1, #GuardianRules.VICTORY_PREFIX) ~= GuardianRules.VICTORY_PREFIX,
			"préfixes sanctuary_ et sacred_upgrade_ confondus"
		)
		for siteId in pairs(GuardianConfig.Sites) do
			check(string.sub(siteId, 1, 7) ~= "reward_", `site {siteId} : préfixe réservé`)
			check(#GuardianRules.rewardKey(siteId) <= 64, `{siteId} : clé trop longue`)
			check(GuardianRules.victoryKey(siteId) ~= GuardianRules.rewardKey(siteId), `{siteId} : clés confondues`)
		end
	end)

	case("configuration : textes EN/FR des gardiens", function(check)
		local keys: { string } = {}
		for _, guardian in pairs(GuardianConfig.Guardians) do
			table.insert(keys, guardian.nameKey)
			for _, attack in pairs(guardian.attacks) do
				table.insert(keys, attack.nameKey)
			end
		end
		for _, site in pairs(GuardianConfig.Sites) do
			table.insert(keys, site.nameKey)
		end
		for _, definition in pairs(SacredResourceConfig.Resources) do
			table.insert(keys, definition.nameKey)
		end
		for _, key in ipairs({ "sacred.reward_ready", "sacred.claim", "sacred.claimed", "sacred.already_claimed", "sacred.bag_full", "sacred.locked" }) do
			table.insert(keys, key)
		end
		-- T10.5b : section « Reliques sacrées » de la Boutique.
		for _, definition in pairs(SacredResourceConfig.Upgrades) do
			table.insert(keys, definition.nameKey)
			table.insert(keys, `{definition.nameKey}.desc`)
		end
		for _, key in ipairs({
			"shop.sacred",
			"sacred.none",
			"sacred.have",
			"sacred.sell",
			"sacred.use",
			"sacred.confirm",
			"sacred.active",
			"sacred.sold",
			"sacred.upgraded",
			"sacred.need",
			"sacred.nothing",
			"sacred.failed",
		}) do
			table.insert(keys, key)
		end
		for _, key in ipairs(keys) do
			check(Localization.has(key, "en") and Localization.has(key, "fr"), `{key} manquant`)
		end
	end)

	-- Règles pures --------------------------------------------------------------

	case("règles : phases", function(check)
		check(GuardianRules.phaseFor(30, 30) == 1, "100 %")
		check(GuardianRules.phaseFor(20, 30) == 1, "67 %")
		check(GuardianRules.phaseFor(19, 30) == 2, "63 %")
		check(GuardianRules.phaseFor(9, 30) == 3, "30 %")
		check(GuardianRules.phaseFor(0, 30) == 3, "0 %")
	end)

	case("règles : formes d'attaque", function(check)
		local origin = { X = 0, Z = 0 }
		local function plan(definition: any, target: any): any
			return GuardianRules.planAttack(definition, origin, target, function(min: number, _max: number)
				return min
			end)
		end
		local ring = { id = "r", shape = "ring", innerRadius = 10, outerRadius = 20 }
		local p = plan(ring, { X = 15, Z = 0 })
		check(GuardianRules.isHit(ring, p, { X = 15, Z = 0 }), "anneau : dedans")
		check(not GuardianRules.isHit(ring, p, { X = 5, Z = 0 }), "anneau : refuge central")
		check(not GuardianRules.isHit(ring, p, { X = 25, Z = 0 }), "anneau : dehors")
		local line = { id = "l", shape = "line", width = 6, length = 30 }
		p = plan(line, { X = 0, Z = 10 })
		check(GuardianRules.isHit(line, p, { X = 2, Z = 20 }), "ligne : dedans")
		check(not GuardianRules.isHit(line, p, { X = 4, Z = 20 }), "ligne : à côté")
		check(not GuardianRules.isHit(line, p, { X = 0, Z = -5 }), "ligne : derrière")
		local cone = { id = "c", shape = "cone", angleDegrees = 90, radius = 18 }
		p = plan(cone, { X = 10, Z = 0 })
		check(GuardianRules.isHit(cone, p, { X = 10, Z = 3 }), "cône : dedans")
		check(not GuardianRules.isHit(cone, p, { X = 0, Z = 10 }), "cône : hors angle")
		check(not GuardianRules.isHit(cone, p, { X = 20, Z = 0 }), "cône : hors portée")
		local circle = { id = "d", shape = "circle", count = 3, radius = 4, spread = 8 }
		p = plan(circle, { X = 5, Z = 5 })
		check(#p.targets == 3, "3 disques")
		check(GuardianRules.isHit(circle, p, { X = 6, Z = 5 }), "disque visé sur le joueur")
		check(not GuardianRules.isHit(circle, p, { X = 0 / 0, Z = 0 }), "NaN : hors zone")
	end)

	case("règles : recul borné près du centre (A-7)", function(check)
		local center = { X = 100, Z = -50 }
		local radius = Combat.hit.maxRadiusStuds
		local wanted = Combat.hit.knockbackStuds
		local function at(distance: number): { X: number, Z: number }
			return { X = center.X + distance, Z = center.Z }
		end
		check(GuardianRules.knockbackDistance(center, at(2), wanted, radius) == wanted, "près du centre : recul complet")
		check(GuardianRules.knockbackDistance(center, at(20), wanted, radius) == radius - 20, "près du bord : recul réduit")
		check(GuardianRules.knockbackDistance(center, at(radius), wanted, radius) == 0, "au bord : aucun recul")
		check(GuardianRules.knockbackDistance(center, at(radius + 3), wanted, radius) == 0, "hors arène : aucun recul")
		check(GuardianRules.knockbackDistance(center, at(5), 0, radius) == 0, "recul nul")
		check(GuardianRules.knockbackDistance(center, at(5), 0 / 0, radius) == 0, "valeur invalide")
		for distance = 0, radius + 5, 0.5 do
			local push = GuardianRules.knockbackDistance(center, at(distance), wanted, radius)
			check(push >= 0 and distance + push <= math.max(radius, distance) + 1e-9, `dépassement à {distance}`)
		end
		-- Sol des sites jusqu'à environ 30 studs (relevé 2026-11-23) : au
		-- moins 4 studs de marge, et pas au-delà de l'arène.
		check(radius <= 26 and radius <= Combat.arena.radius, "borne du recul trop près du vide")
	end)

	case("règles : accès aux sites", function(check)
		local worlds = { GreenValley = true }
		local all = discoveredAll()
		check(GuardianRules.siteAccess("RootSanctuary", worlds, all, {}) == Access.Eligible, "éligible")
		check(GuardianRules.siteAccess("SunTemple", worlds, all, {}) == Access.WorldLocked, "monde verrouillé")
		check(GuardianRules.siteAccess("RootSanctuary", worlds, { green_leaf = true }, {}) == Access.DiscoveryRequired, "découvertes")
		-- Accès permanent : prioritaire, même si le journal ou les mondes changent.
		check(GuardianRules.siteAccess("SunTemple", {}, {}, { SunTemple = true }) == Access.Unlocked, "accès permanent")
		check(GuardianRules.siteAccess("Nowhere", worlds, all, {}) == Access.UnknownSite, "site inconnu")
		local count, total = GuardianRules.discoveryProgress("GreenValley", { green_leaf = true, wood = true })
		check(count == 2 and total == 5, `progression {count}/{total}`)
	end)

	-- Combat -------------------------------------------------------------------

	case("combat solo : réveil, éclats, victoire unique", function(check)
		local env = newEnv()
		env.addPlayer(1)
		local result = env.start(1, "RootSanctuary")
		check(result.ok, `activation refusée {result.code}`)
		local snapshot = env.combat.GetCombat(1)
		check(snapshot ~= nil and snapshot.state == "Awakening", "état Awakening attendu")
		check(env.strikeOne(1) == nil, "aucun éclat pendant le réveil")
		env.advance(Combat.awakeningSeconds + 0.1)
		snapshot = env.combat.GetCombat(1)
		check(snapshot ~= nil and snapshot.state == "Combat", "état Combat attendu")
		check(snapshot ~= nil and #snapshot.shardIds == Combat.shards.activeCount, "éclats initiaux")
		local strike = env.strikeOne(1)
		check(strike ~= nil and strike.ok and strike.health == GuardianConfig.Guardians.ForestGuardian.maxHealth - 1, "1 dégât serveur")
		env.combat.RemovePlayer(1)
		env.addPlayer(1)
		check(env.winFight(1, "RootSanctuary"), "victoire non atteinte")
		check(#env.victories == 1 and env.victories[1].userId == 1, "une victoire attendue")
		check(env.sites.HasVictory(1, "RootSanctuary"), "site débloqué")
		check(env.lastMessage(1, "victory").firstVictory == true, "première victoire")
	end)

	case("deux joueurs : dégâts, victoires et déblocages indépendants", function(check)
		local env = newEnv()
		env.addPlayer(1)
		env.addPlayer(2)
		check(env.start(1, "SunTemple").ok and env.start(2, "SunTemple").ok, "activations")
		env.advance(Combat.awakeningSeconds + 0.1)
		local maxHealth = GuardianConfig.Guardians.SandGuardian.maxHealth
		env.strikeOne(1)
		env.now += 1
		env.strikeOne(1)
		check(env.combat.GetCombat(1).health == maxHealth - 2, "PV du joueur 1")
		check(env.combat.GetCombat(2).health == maxHealth, "PV du joueur 2 inchangés")
		-- Éclat du joueur 2 demandé par le joueur 1 : refusé, rien ne bouge.
		local foreign = env.combat.GetCombat(2).shardIds[1]
		local position = env.combat.GetShardPosition(2, foreign)
		env.positions[1] = { X = position.X, Y = position.Y + 3, Z = position.Z }
		env.now += 1
		local stolen = env.combat.HandleStrike(1, { shardId = foreign }, 0)
		check(not stolen.ok and stolen.code == Code.InvalidTarget, "éclat d'autrui refusé")
		check(env.combat.GetCombat(2).health == maxHealth, "PV du joueur 2 toujours intacts")
		check(env.combat.GetShardPosition(2, foreign) ~= nil, "éclat du joueur 2 toujours là")
		-- Victoire du joueur 1 seulement.
		env.combat.RemovePlayer(1)
		env.sites.RemovePlayer(1)
		env.addPlayer(1)
		check(env.winFight(1, "SunTemple"), "victoire du joueur 1")
		check(env.sites.HasVictory(1, "SunTemple"), "joueur 1 débloqué")
		check(not env.sites.HasVictory(2, "SunTemple"), "joueur 2 non débloqué")
		check(env.combat.GetCombat(2) ~= nil, "combat du joueur 2 toujours en cours")
		check(env.count(2, "victory") == 0, "aucun message de victoire au joueur 2")
	end)

	case("quatre joueurs : quatre combats isolés, victoires attribuées à chacun", function(check)
		local env = newEnv()
		for userId = 1, 4 do
			env.addPlayer(userId)
		end
		for userId = 1, 4 do
			check(env.winFight(userId, "FrostAltar"), `victoire du joueur {userId}`)
		end
		check(#env.victories == 4, `4 victoires attendues, {#env.victories}`)
		local seen: { [number]: boolean } = {}
		for _, victory in ipairs(env.victories) do
			check(not seen[victory.userId], "victoire en double")
			seen[victory.userId] = true
		end
	end)

	case("combats simultanés : un état par joueur, jamais global", function(check)
		local env = newEnv()
		for userId = 1, 3 do
			env.addPlayer(userId)
			check(env.start(userId, "AstralSanctuary").ok, `activation {userId}`)
		end
		check(env.combat.ActiveCount() == 3, "3 combats")
		local ids: { [string]: boolean } = {}
		for userId = 1, 3 do
			local snapshot = env.combat.GetCombat(userId)
			check(not ids[snapshot.combatId], "identifiant de combat partagé")
			ids[snapshot.combatId] = true
		end
	end)

	case("déconnexion pendant le combat : rien n'est attribué", function(check)
		local env = newEnv()
		env.addPlayer(1)
		env.start(1, "RootSanctuary")
		env.advance(Combat.awakeningSeconds + 0.1)
		env.strikeOne(1)
		env.combat.RemovePlayer(1)
		env.sites.RemovePlayer(1)
		check(env.combat.GetCombat(1) == nil, "combat effacé")
		check(#env.victories == 0, "aucune victoire")
		local after = env.combat.HandleStrike(1, { shardId = "sh1" }, 0)
		check(after.code == Code.NotInCombat, `NOT_IN_COMBAT attendu, {after.code}`)
	end)

	case("attaque hors distance : TOO_FAR, PV intacts", function(check)
		local env = newEnv()
		env.addPlayer(1)
		env.start(1, "RootSanctuary")
		env.advance(Combat.awakeningSeconds + 0.1)
		local shardId = env.combat.GetCombat(1).shardIds[1]
		local position = env.combat.GetShardPosition(1, shardId)
		env.positions[1] = { X = position.X + 30, Y = position.Y + 3, Z = position.Z }
		local result = env.combat.HandleStrike(1, { shardId = shardId }, 0)
		check(result.code == Code.TooFar, `TOO_FAR attendu, {result.code}`)
		check(env.combat.GetCombat(1).health == GuardianConfig.Guardians.ForestGuardian.maxHealth, "PV inchangés")
		env.positions[1] = { X = 0 / 0, Y = 0, Z = 0 }
		check(env.combat.HandleStrike(1, { shardId = shardId }, 0).code == Code.TooFar, "position NaN")
	end)

	case("attaque trop rapide : COOLDOWN puis RATE_LIMITED", function(check)
		local env = newEnv()
		env.addPlayer(1)
		env.start(1, "RootSanctuary")
		env.advance(Combat.awakeningSeconds + 0.1)
		check(env.strikeOne(1).ok, "première saisie")
		local second = env.strikeOne(1)
		check(second.code == Code.Cooldown, `COOLDOWN attendu, {second.code}`)
		local limited = false
		for _ = 1, 30 do
			local result = env.combat.HandleStrike(1, { shardId = "sh1" }, 0)
			if result.code == Code.RateLimited then
				limited = true
			end
		end
		check(limited, "rafale non limitée")
		check(env.combat.GetCombat(1).health == GuardianConfig.Guardians.ForestGuardian.maxHealth - 1, "un seul dégât")
	end)

	case("falsification des dégâts : champ ou argument en trop refusé", function(check)
		local env = newEnv()
		env.addPlayer(1)
		env.start(1, "RootSanctuary")
		env.advance(Combat.awakeningSeconds + 0.1)
		local shardId = env.combat.GetCombat(1).shardIds[1]
		local position = env.combat.GetShardPosition(1, shardId)
		env.positions[1] = { X = position.X, Y = position.Y + 3, Z = position.Z }
		local forged = env.combat.HandleStrike(1, { shardId = shardId, damage = 999 }, 0)
		check(forged.code == Code.InvalidTarget, "champ damage refusé")
		local extra = env.combat.HandleStrike(1, { shardId = shardId }, 1)
		check(extra.code == Code.InvalidTarget, "argument en trop refusé")
		check(env.combat.HandleStrike(1, "sh1", 0).code == Code.InvalidTarget, "payload non table")
		check(env.combat.GetCombat(1).health == GuardianConfig.Guardians.ForestGuardian.maxHealth, "PV inchangés")
	end)

	case("falsification des récompenses : aucune entrée client ne donne la victoire", function(check)
		local env = newEnv()
		env.addPlayer(1)
		local forged = env.sites.HandleActivate(1, { siteId = "RootSanctuary", victory = true }, 0)
		check(not forged.ok and forged.code == Code.InvalidTarget, "champ victory refusé")
		check(env.combat.GetCombat(1) == nil, "aucun combat ouvert")
		check(not env.sites.HasVictory(1, "RootSanctuary"), "aucune victoire")
		-- Victoire inventée (combat inexistant) puis rejouée : une seule fois.
		local info = { combatId = "c999", siteId = "RootSanctuary", guardianId = "ForestGuardian", durationSeconds = 0, strikes = 0, hitsTaken = 0 }
		check(env.sites.RecordVictory(1, info), "première attribution (appel serveur)")
		check(not env.sites.RecordVictory(1, info), "rejeu refusé")
	end)

	case("gardien déjà vaincu : NOT_IN_COMBAT, réapparition, accès conservé", function(check)
		local env = newEnv()
		env.addPlayer(1)
		check(env.winFight(1, "RootSanctuary"), "victoire")
		check(env.combat.HandleStrike(1, { shardId = "sh1" }, 0).code == Code.NotInCombat, "saisie après victoire")
		env.now += 5
		local again = env.start(1, "RootSanctuary")
		check(again.code == Code.GuardianRespawning, `GUARDIAN_RESPAWNING attendu, {again.code}`)
		env.now += Combat.respawnSeconds
		check(env.start(1, "RootSanctuary").ok, "nouveau combat après réapparition")
		-- Nouvelle défaite (abandon) : le déblocage n'est jamais retiré.
		env.positions[1] = { X = 500, Y = 3, Z = 500 }
		env.advance(Combat.arena.leaveGraceSeconds + 0.5)
		check(env.combat.GetCombat(1) == nil, "combat abandonné hors de l'arène")
		check(env.sites.HasVictory(1, "RootSanctuary"), "accès permanent conservé")
		check(env.lastMessage(1, "ended").reason == "left_arena", "motif left_arena")
	end)

	case("double attribution : une victoire par combat, seconde victoire non « première »", function(check)
		local env = newEnv()
		env.addPlayer(1)
		check(env.winFight(1, "RootSanctuary"), "victoire 1")
		local first = env.victories[1].info
		check(not env.sites.RecordVictory(1, first), "même combat rejoué")
		env.now += Combat.respawnSeconds + 1
		check(env.winFight(1, "RootSanctuary"), "victoire 2")
		check(#env.victories == 2, "deux combats, deux victoires")
		check(env.lastMessage(1, "victory").firstVictory == false, "seconde victoire non première")
		check(env.victories[1].info.combatId ~= env.victories[2].info.combatId, "identifiants distincts")
	end)

	case("joueur non participant : présence à proximité sans récompense", function(check)
		local env = newEnv()
		env.addPlayer(1)
		env.addPlayer(2)
		-- Le joueur 2 reste près de l'autel pendant tout le combat du joueur 1.
		env.atAltar(2, "RootSanctuary")
		check(env.winFight(1, "RootSanctuary"), "victoire du joueur 1")
		check(not env.sites.HasVictory(2, "RootSanctuary"), "joueur 2 non débloqué")
		check(env.count(2, "victory") == 0 and env.count(2, "attack") == 0, "aucun message de combat au joueur 2")
	end)

	case("monde verrouillé, découvertes manquantes, profil absent", function(check)
		local env = newEnv()
		env.addPlayer(1, newProfile({ GreenValley = true }, discoveredAll()))
		check(env.start(1, "SunTemple").code == Code.WorldLocked, "WORLD_LOCKED")
		env.addPlayer(2, newProfile(nil, { green_leaf = true }))
		check(env.start(2, "RootSanctuary").code == Code.RequirementNotMet, "REQUIREMENT_NOT_MET")
		check(env.sites.HandleActivate(3, { siteId = "RootSanctuary" }, 0).code == Code.ProfileNotLoaded, "profil absent")
		check(env.sites.HandleActivate(1, { siteId = "Atlantis" }, 0).code == Code.InvalidTarget, "site inconnu")
		env.positions[1] = { X = 0, Y = 3, Z = 80 }
		check(env.sites.HandleActivate(1, { siteId = "RootSanctuary" }, 0).code == Code.TooFar, "loin de l'autel")
		check(env.combat.ActiveCount() == 0, "aucun combat")
	end)

	case("activation pendant un combat : ALREADY_IN_COMBAT", function(check)
		local env = newEnv()
		env.addPlayer(1)
		check(env.start(1, "RootSanctuary").ok, "première activation")
		check(env.start(1, "RootSanctuary").code == Code.AlreadyInCombat, "seconde activation")
	end)

	case("attaques jugées sur la position serveur : touché, esquive, étourdi", function(check)
		local env = newEnv()
		env.addPlayer(1)
		env.start(1, "RootSanctuary")
		-- Le joueur reste près du gardien : l'anneau de proximité le touche.
		env.positions[1] = { X = 4, Y = 3, Z = 0 }
		env.advance(Combat.awakeningSeconds + 0.1)
		local guardian = GuardianConfig.Guardians.ForestGuardian
		env.advance(guardian.attackIntervalSeconds[1] * 0.5 + 0.05)
		local attack = env.lastMessage(1, "attack")
		check(attack ~= nil and attack.attackId == "root_slam", "attaque annoncée")
		env.advance(guardian.attacks.root_slam.telegraphSeconds + 0.1)
		check(env.count(1, "hit") == 1, "touche attendue")
		local hitMessage = env.lastMessage(1, "hit")
		check(
			hitMessage.knockbackStuds == math.min(Combat.hit.knockbackStuds, Combat.hit.maxRadiusStuds - 4)
				and hitMessage.knockbackSeconds == Combat.hit.knockbackSeconds,
			"recul borné envoyé (A-7)"
		)
		local snapshot = env.combat.GetCombat(1)
		check(snapshot.hitsTaken == 1 and snapshot.stunnedUntil > env.now, "étourdi")
		local shardId = snapshot.shardIds[1]
		local position = env.combat.GetShardPosition(1, shardId)
		env.positions[1] = { X = position.X, Y = position.Y + 3, Z = position.Z }
		check(env.combat.HandleStrike(1, { shardId = shardId }, 0).code == Code.Stunned, "STUNNED")
		-- Attaque suivante esquivée : le joueur sort de la zone avant l'impact.
		env.advance(guardian.attackIntervalSeconds[1] + 0.05)
		check(env.count(1, "attack") == 2, "deuxième annonce")
		env.positions[1] = { X = 25, Y = 3, Z = 0 }
		env.advance(guardian.attacks.root_slam.telegraphSeconds + 0.1)
		check(env.count(1, "hit") == 1, "esquive : pas de nouvelle touche")
	end)

	case("personnage absent : combat abandonné", function(check)
		local env = newEnv()
		env.addPlayer(1)
		env.start(1, "RootSanctuary")
		env.positions[1] = nil
		env.advance(0.2)
		check(env.combat.GetCombat(1) == nil, "combat terminé")
		check(env.lastMessage(1, "ended").reason == "no_character", "motif no_character")
		check(#env.victories == 0, "aucune victoire")
	end)

	case("messages au seul joueur concerné", function(check)
		local env = newEnv()
		env.addPlayer(1)
		env.addPlayer(2)
		env.start(1, "RootSanctuary")
		env.advance(Combat.awakeningSeconds + 3)
		check(env.count(1, "shard") >= Combat.shards.activeCount, "éclats envoyés au joueur 1")
		check(env.messages[2] == nil, "rien envoyé au joueur 2")
	end)

	case("accès permanent : magasin de session (persistance non autorisée)", function(check)
		local env = newEnv()
		env.addPlayer(1)
		check(env.winFight(1, "RootSanctuary"), "victoire")
		local view = env.sites.GetView(1)
		check(view.persistent == false, "magasin de session attendu")
		check(view.sites.RootSanctuary.access == Access.Unlocked, "accès Unlocked")
		-- Reconnexion : perdu tant que la persistance n'est pas autorisée.
		env.sites.RemovePlayer(1)
		check(not env.sites.HasVictory(1, "RootSanctuary"), "session effacée au départ (comportement attendu en v3)")
		-- Magasin persistant injecté : conservé (support prêt pour la proposition §7).
		local kept: { [number]: { [string]: boolean } } = {}
		local store = {
			persistent = true,
			Has = function(userId: number, siteId: string)
				return kept[userId] ~= nil and kept[userId][siteId] == true
			end,
			Record = function(userId: number, siteId: string)
				kept[userId] = kept[userId] or {}
				local first = kept[userId][siteId] ~= true
				kept[userId][siteId] = true
				return first
			end,
			List = function(userId: number)
				return table.clone(kept[userId] or {})
			end,
			Remove = function() end,
		}
		local persisted = newEnv({ victoryStore = store })
		persisted.addPlayer(1)
		check(persisted.winFight(1, "RootSanctuary"), "victoire (magasin persistant)")
		persisted.sites.RemovePlayer(1)
		check(persisted.sites.HasVictory(1, "RootSanctuary"), "conservé après reconnexion")
	end)

	-- Ressources sacrées : réclamation et persistance dans
	-- GuardianPersistenceTests (P1 à P15). Ici : règle de place pure.
	case("place dans le sac : bornes", function(check)
		check(GuardianRules.fitsInBag(47, 50, 3, 1) and not GuardianRules.fitsInBag(48, 50, 3, 1), "bornes à 1 place")
		check(GuardianRules.fitsInBag(45, 50, 1, 5) and not GuardianRules.fitsInBag(46, 50, 1, 5), "bornes à 5 places")
	end)

	return failures, caseCount
end

return GuardianTests
