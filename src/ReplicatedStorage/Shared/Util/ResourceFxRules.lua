--!strict
-- Règles pures des effets visuels des ressources (T10.1, D-027) : pose
-- d'attente, sélection des nœuds animés, mise à l'échelle des pièces d'un
-- nœud (correction V-01). Aucune API Roblox : testable sous Lune
-- (Tests/ResourceFxTests). Le rendu réel est vérifié dans Studio.

local ResourceFxRules = {}

export type Idle = {
	bob: number,
	bobPeriod: number,
	spin: number,
	pulse: number,
	pulsePeriod: number,
}

export type Pose = {
	offsetY: number, -- studs, ajouté à la hauteur de repos
	yawDegrees: number, -- rotation supplémentaire autour de Y
	scale: number, -- facteur d'échelle (1 = taille de repos)
}

export type Candidate = { id: string, distance: number }

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
	local yaw = (idle.spin * t + phase * 360) % 360
	local scale = 1
	if idle.pulse > 0 and idle.pulsePeriod > 0 then
		scale = 1 + idle.pulse * math.sin(2 * math.pi * (t / idle.pulsePeriod + phase))
	end
	return { offsetY = offsetY, yawDegrees = if idle.spin ~= 0 then yaw else 0, scale = scale }
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
