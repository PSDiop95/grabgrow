--!strict
-- Règles pures des effets visuels des ressources (T10.1, D-027 ; T10.2,
-- D-032) : pose d'attente (dont pirouette Épique), sélection des nœuds
-- animés, attribution des émetteurs prêtés, niveau d'effets, nombre de
-- particules des éclats, attribution d'une disparition (éclat local ou
-- disparition vue d'un autre joueur), mise à l'échelle des pièces (V-01).
-- Aucune API Roblox : testable sous Lune (Tests/ResourceFxTests). Le rendu
-- réel est vérifié dans Studio.

local ResourceFxRules = {}

export type Idle = {
	bob: number,
	bobPeriod: number,
	spin: number,
	pulse: number,
	pulsePeriod: number,
	special: { period: number, duration: number, hop: number, turns: number }?,
}

export type EffectLevel = "full" | "low" | "reduced"

export type Pose = {
	offsetY: number, -- studs, ajouté à la hauteur de repos
	yawDegrees: number, -- rotation supplémentaire autour de Y
	scale: number, -- facteur d'échelle (1 = taille de repos)
}

export type Candidate = { id: string, distance: number }

-- Candidat à un émetteur prêté : `priority` = rareté (plus haut d'abord).
export type EmitterCandidate = { id: string, distance: number, priority: number }

-- Phase déterministe par nœud (0..1) : deux nœuds voisins ne flottent pas
-- en même temps, sans tirage aléatoire ni état.
function ResourceFxRules.phaseFor(nodeId: string): number
	local hash = 0
	for index = 1, #nodeId do
		hash = (hash * 31 + string.byte(nodeId, index)) % 1000003
	end
	return (hash % 1000) / 1000
end

-- Lacet de départ déterministe par nœud (degrés, 0..359).
function ResourceFxRules.baseYawFor(nodeId: string): number
	return math.floor(ResourceFxRules.phaseFor(nodeId) * 360) % 360
end

-- Pose d'attente à l'instant `t` (s). Effets réduits ou paramètres
-- invalides : pose neutre.
function ResourceFxRules.idlePose(idle: Idle?, t: number, phase: number, reducedEffects: boolean): Pose
	if idle == nil or reducedEffects then
		return { offsetY = 0, yawDegrees = 0, scale = 1 }
	end
	local offsetY = 0
	if idle.bob > 0 and idle.bobPeriod > 0 then
		offsetY = idle.bob * math.sin(2 * math.pi * (t / idle.bobPeriod + phase))
	end
	local yaw = if idle.spin ~= 0 then (idle.spin * t + phase * 360) % 360 else 0
	local scale = 1
	if idle.pulse > 0 and idle.pulsePeriod > 0 then
		scale = 1 + idle.pulse * math.sin(2 * math.pi * (t / idle.pulsePeriod + phase))
	end
	local spins = idle.spin ~= 0
	-- Pirouette périodique : petit saut et tour complet, au début de chaque
	-- période (décalée par la phase du nœud).
	local special = idle.special
	if special and special.period > 0 and special.duration > 0 and special.duration < special.period then
		local cycle = ((t / special.period + phase) % 1) * special.period
		if cycle < special.duration then
			local alpha = cycle / special.duration
			local eased = alpha * alpha * (3 - 2 * alpha)
			offsetY += special.hop * math.sin(math.pi * alpha)
			yaw = (yaw + 360 * special.turns * eased) % 360
			spins = true
		end
	end
	return { offsetY = offsetY, yawDegrees = if spins then yaw else 0, scale = scale }
end

-- Niveau d'effets : « Effets réduits » d'abord, puis qualité graphique
-- Roblox (1..10 ; nil ou 0 = automatique).
function ResourceFxRules.effectLevel(reducedEffects: boolean, qualityLevel: number?, lowQualityMax: number): EffectLevel
	if reducedEffects then
		return "reduced"
	end
	if qualityLevel ~= nil and qualityLevel >= 1 and qualityLevel <= lowQualityMax then
		return "low"
	end
	return "full"
end

-- Émetteurs prêtés : rareté la plus haute d'abord, puis la plus proche,
-- dans le rayon, `maxCount` au plus. Ensemble { [id] = true }.
function ResourceFxRules.allocateEmitters(
	candidates: { EmitterCandidate },
	maxCount: number,
	radius: number
): { [string]: boolean }
	local inRange: { EmitterCandidate } = {}
	for _, candidate in ipairs(candidates) do
		if candidate.distance <= radius then
			table.insert(inRange, candidate)
		end
	end
	table.sort(inRange, function(a: EmitterCandidate, b: EmitterCandidate): boolean
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.id < b.id
	end)
	local selected: { [string]: boolean } = {}
	for index = 1, math.min(maxCount, #inRange) do
		selected[inRange[index].id] = true
	end
	return selected
end

-- Particules d'un éclat (`normal` ou `reduced`) selon le niveau d'effets ;
-- « low » garde le nombre normal (éclat bref, pool borné).
function ResourceFxRules.burstCount(normal: number, reduced: number, level: EffectLevel): number
	local count = if level == "reduced" then reduced else normal
	return math.max(0, math.floor(count))
end

-- Disparition d'un nœud (Available devenu faux, décidé par le serveur) :
-- "claimed" si le joueur local vient de le demander (l'éclat de collecte
-- suit : aucun second effet), sinon "pop" (pris par un autre joueur).
function ResourceFxRules.disappearance(now: number, claimedUntil: number?): "claimed" | "pop"
	if claimedUntil ~= nil and now <= claimedUntil then
		return "claimed"
	end
	return "pop"
end

-- Nœuds à animer : les plus proches dans le rayon, `maxCount` au plus.
-- Retourne un ensemble { [id] = true }. Égalité de distance : ordre des
-- identifiants (résultat stable).
function ResourceFxRules.selectAnimated(candidates: { Candidate }, maxCount: number, radius: number): { [string]: boolean }
	local inRange: { Candidate } = {}
	for _, candidate in ipairs(candidates) do
		if candidate.distance <= radius then
			table.insert(inRange, candidate)
		end
	end
	table.sort(inRange, function(a: Candidate, b: Candidate): boolean
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.id < b.id
	end)
	local selected: { [string]: boolean } = {}
	for index = 1, math.min(maxCount, #inRange) do
		selected[inRange[index].id] = true
	end
	return selected
end

-- V-01 : pose d'une pièce d'un nœud mis à l'échelle `scale` autour de son
-- centre. `offset` = position de la pièce dans le repère du centre ;
-- `size` = taille de repos. Retourne (décalage, taille) mis à l'échelle.
function ResourceFxRules.scalePiece(offset: { number }, size: { number }, scale: number): ({ number }, { number })
	return { offset[1] * scale, offset[2] * scale, offset[3] * scale }, { size[1] * scale, size[2] * scale, size[3] * scale }
end

-- Échelle uniforme qui ramène une boîte englobante `size` à la plus grande
-- dimension `targetSize` (studs). nil si la boîte est vide ou invalide.
function ResourceFxRules.fitScale(size: { number }, targetSize: number): number?
	local largest = math.max(size[1], size[2], size[3])
	if not (largest > 0) or not (targetSize > 0) then
		return nil
	end
	return targetSize / largest
end

return ResourceFxRules
