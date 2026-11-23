--!strict
-- Règles pures des gardiens (T10.3) : phases, géométrie des attaques,
-- placement des éclats, arène et accès aux sites sacrés.
--
-- Utilisé par le serveur (décisions) et par le client (dessin des
-- télégraphies, indications) : une seule définition des formes. Aucune API
-- Roblox : positions en tables { X, Y, Z }, testables avec Lune. Les tests
-- de touche sont faits dans le plan horizontal (X, Z).

local ResourceConfig = require(script.Parent.Parent.Config.ResourceConfig)
local WorldConfig = require(script.Parent.Parent.Config.WorldConfig)
local GuardianConfig = require(script.Parent.Parent.Config.GuardianConfig)

local GuardianRules = {}

export type Position = { X: number, Y: number, Z: number }
export type Planar = { X: number, Z: number }

-- Attaque annoncée : géométrie figée au moment de l'annonce. Le joueur
-- esquive en sortant de la zone avant `impactAt`.
export type AttackPlan = {
	attackId: string,
	shape: string,
	origin: Planar,
	-- Direction unitaire (line, cone) ; vers le joueur à l'annonce.
	direction: Planar,
	-- Centres des disques (circle).
	targets: { Planar },
}

GuardianRules.Access = table.freeze({
	Unlocked = "unlocked", -- victoire déjà obtenue (accès permanent, T10-D01)
	Eligible = "eligible", -- monde débloqué et ressources du monde découvertes
	WorldLocked = "world_locked",
	DiscoveryRequired = "discovery_required",
	UnknownSite = "unknown_site",
})

local function planar(position: Planar): Planar
	return { X = position.X, Z = position.Z }
end

local function planarDistance(a: Planar, b: Planar): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
GuardianRules.planarDistance = planarDistance

-- Direction unitaire de `from` vers `to` ; +Z si les points sont confondus.
function GuardianRules.directionTo(from: Planar, to: Planar): Planar
	local dx, dz = to.X - from.X, to.Z - from.Z
	local length = math.sqrt(dx * dx + dz * dz)
	if not (length > 1e-6) then
		return { X = 0, Z = 1 }
	end
	return { X = dx / length, Z = dz / length }
end

-- Recul borné (A-7) : distance vers l'extérieur, réduite pour que le
-- joueur ne dépasse pas `maxRadius` du centre ; 0 s'il y est déjà.
function GuardianRules.knockbackDistance(center: Planar, position: Planar, wanted: number, maxRadius: number): number
	if not (wanted > 0) then
		return 0
	end
	local room = maxRadius - planarDistance(center, position)
	if not (room > 0) then
		return 0
	end
	return math.min(wanted, room)
end

-- Phase 1, 2 ou 3 selon la fraction de PV restante.
function GuardianRules.phaseFor(health: number, maxHealth: number): number
	local thresholds = GuardianConfig.Combat.phaseThresholds
	local fraction = if maxHealth > 0 then health / maxHealth else 0
	local phase = 1
	for index, threshold in ipairs(thresholds) do
		if fraction <= threshold then
			phase = index + 1
		end
	end
	return phase
end

-- Fige la géométrie d'une attaque. `random(min, max)` : réel uniforme
-- (Random:NextNumber côté serveur ; déterministe dans les tests).
function GuardianRules.planAttack(
	definition: GuardianConfig.AttackDefinition,
	origin: Planar,
	target: Planar,
	random: (min: number, max: number) -> number
): AttackPlan
	local plan: AttackPlan = {
		attackId = definition.id,
		shape = definition.shape,
		origin = planar(origin),
		direction = GuardianRules.directionTo(origin, target),
		targets = {},
	}
	if definition.shape == "circle" then
		local count = definition.count or 1
		local spread = definition.spread or 0
		-- Le premier disque vise le joueur ; les autres l'entourent.
		table.insert(plan.targets, planar(target))
		for _ = 2, count do
			local angle = random(0, 2 * math.pi)
			local distance = random(spread * 0.4, spread)
			table.insert(plan.targets, {
				X = target.X + math.cos(angle) * distance,
				Z = target.Z + math.sin(angle) * distance,
			})
		end
	end
	return plan
end

-- La position `position` est-elle dans la zone de l'attaque ?
-- Position non finie : considérée hors zone (jamais d'erreur).
function GuardianRules.isHit(definition: GuardianConfig.AttackDefinition, plan: AttackPlan, position: Planar): boolean
	local x, z = position.X, position.Z
	if not (x == x and z == z and math.abs(x) < math.huge and math.abs(z) < math.huge) then
		return false
	end
	local origin = plan.origin
	local shape = definition.shape
	if shape == "ring" then
		local distance = planarDistance(origin, position)
		return distance >= (definition.innerRadius or 0) and distance <= (definition.outerRadius or 0)
	elseif shape == "circle" then
		local radius = definition.radius or 0
		for _, center in ipairs(plan.targets) do
			if planarDistance(center, position) <= radius then
				return true
			end
		end
		return false
	elseif shape == "line" then
		local dx, dz = x - origin.X, z - origin.Z
		local along = dx * plan.direction.X + dz * plan.direction.Z
		local across = math.abs(dx * plan.direction.Z - dz * plan.direction.X)
		return along >= 0 and along <= (definition.length or 0) and across <= (definition.width or 0) / 2
	elseif shape == "cone" then
		local distance = planarDistance(origin, position)
		if distance > (definition.radius or 0) then
			return false
		end
		if distance < 1e-6 then
			return true
		end
		local dx, dz = (x - origin.X) / distance, (z - origin.Z) / distance
		local cosine = dx * plan.direction.X + dz * plan.direction.Z
		local halfAngle = math.rad((definition.angleDegrees or 0) / 2)
		return cosine >= math.cos(halfAngle)
	end
	return false
end

-- Position d'un éclat : couronne [minRadius, maxRadius] autour du centre.
function GuardianRules.shardPosition(center: Position, random: (min: number, max: number) -> number): Position
	local shards = GuardianConfig.Combat.shards
	local angle = random(0, 2 * math.pi)
	local distance = random(shards.minRadius, shards.maxRadius)
	return {
		X = center.X + math.cos(angle) * distance,
		Y = center.Y,
		Z = center.Z + math.sin(angle) * distance,
	}
end

function GuardianRules.isInsideArena(center: Planar, position: Planar, radius: number): boolean
	return planarDistance(center, position) <= radius
end

-- Ressources ordinaires d'un monde (ResourceConfig), triées.
function GuardianRules.worldResources(worldId: string): { string }
	local list: { string } = {}
	for resourceId, definition in pairs(ResourceConfig) do
		if definition.worldId == worldId then
			table.insert(list, resourceId)
		end
	end
	table.sort(list)
	return list
end

-- Accès d'un joueur à un site (affichage et décision serveur).
--   worlds     : mondes débloqués { [worldId] = true } (profil serveur)
--   discovered : journal { [resourceId] = true }
--   victories  : sites vaincus { [siteId] = true }
-- Accès permanent après victoire (T10-D01) : prioritaire sur le reste.
-- Sinon : monde débloqué ET toutes les ressources ordinaires du monde
-- découvertes. L'accès ne dépend jamais d'un autre joueur.
function GuardianRules.siteAccess(siteId: string, worlds: any, discovered: any, victories: any): string
	local Access = GuardianRules.Access
	local site = GuardianConfig.Sites[siteId]
	if site == nil or WorldConfig[site.worldId] == nil then
		return Access.UnknownSite
	end
	if type(victories) == "table" and victories[siteId] == true then
		return Access.Unlocked
	end
	if type(worlds) ~= "table" or worlds[site.worldId] ~= true then
		return Access.WorldLocked
	end
	for _, resourceId in ipairs(GuardianRules.worldResources(site.worldId)) do
		if type(discovered) ~= "table" or discovered[resourceId] ~= true then
			return Access.DiscoveryRequired
		end
	end
	return Access.Eligible
end

-- Nombre de ressources ordinaires découvertes / total (indication client).
function GuardianRules.discoveryProgress(worldId: string, discovered: any): (number, number)
	local list = GuardianRules.worldResources(worldId)
	local count = 0
	for _, resourceId in ipairs(list) do
		if type(discovered) == "table" and discovered[resourceId] == true then
			count += 1
		end
	end
	return count, #list
end

-- Peut-on ajouter `amount` unités consommant `capacityPerUnit` place(s)
-- chacune dans un sac de `used` / `capacity` ? (ressources sacrées, futur)
function GuardianRules.fitsInBag(used: number, capacity: number, amount: number, capacityPerUnit: number): boolean
	return used + amount * capacityPerUnit <= capacity
end

-- Persistance option A (v3, D-035) : clés réservées de profile.achievements.
-- Valeur `true` seulement, jamais retirées. Préfixes réservés : aucun succès
-- d'AchievementConfig ni aucun siteId ne doit les reprendre (ConfigTests).
GuardianRules.VICTORY_PREFIX = "sanctuary_"
GuardianRules.REWARD_PREFIX = "sanctuary_reward_"

-- Victoire personnelle : accès permanent au site (T10-D01).
function GuardianRules.victoryKey(siteId: string): string
	return GuardianRules.VICTORY_PREFIX .. siteId
end

-- Récompense de première victoire réclamée (une seule fois, D-035).
function GuardianRules.rewardKey(siteId: string): string
	return GuardianRules.REWARD_PREFIX .. siteId
end

-- Victoires lues dans le profil : { [siteId] = true } pour les sites connus.
function GuardianRules.profileVictories(profile: any): { [string]: boolean }
	local victories: { [string]: boolean } = {}
	local achievements = if type(profile) == "table" then profile.achievements else nil
	if type(achievements) ~= "table" then
		return victories
	end
	for siteId in pairs(GuardianConfig.Sites) do
		if achievements[GuardianRules.victoryKey(siteId)] == true then
			victories[siteId] = true
		end
	end
	return victories
end

-- Récompense déjà réclamée pour ce site dans le profil.
function GuardianRules.rewardClaimed(profile: any, siteId: string): boolean
	local achievements = if type(profile) == "table" then profile.achievements else nil
	return type(achievements) == "table" and achievements[GuardianRules.rewardKey(siteId)] == true
end

return GuardianRules
