--!strict
-- Règles d'affichage du voyage entre mondes (T8.2, D-021), côté client.
-- Fonctions pures, testables en Lune. Aucune autorité : le serveur décide
-- de chaque voyage (WorldTravelService) ; ces règles évitent seulement
-- d'envoyer des demandes vouées au refus et choisissent le texte affiché.

local TravelRules = {}

-- États d'une ligne de monde (boutique) ou d'un portail.
TravelRules.State = table.freeze({
	Locked = "locked", -- monde non débloqué (miroir de l'état serveur)
	Here = "here", -- le joueur est déjà sur cette île
	ComingSoon = "coming_soon", -- débloqué, mais aucune île sur la carte
	Pending = "pending", -- demande envoyée, réponse attendue
	Travel = "travel", -- voyage possible
})

export type Point = { worldId: string, X: number, Z: number }

export type RowInfo = {
	unlocked: boolean,
	available: boolean,
	current: boolean,
	pending: boolean,
}

-- Monde de l'île où se trouve le joueur : celui du point d'arrivée le plus
-- proche à l'horizontale (îles séparées de milliers de studs). Nil sans
-- position ou sans point d'arrivée.
function TravelRules.currentWorld(position: { X: number, Z: number }?, points: { Point }): string?
	if position == nil then
		return nil
	end
	local bestId: string? = nil
	local bestDistance = math.huge
	for _, point in ipairs(points) do
		local dx, dz = point.X - position.X, point.Z - position.Z
		local distance = dx * dx + dz * dz
		-- Égalité : ordre alphabétique, pour un résultat stable.
		if distance < bestDistance or (distance == bestDistance and bestId ~= nil and point.worldId < bestId) then
			bestId = point.worldId
			bestDistance = distance
		end
	end
	return bestId
end

-- État affiché d'un monde. Ordre : verrou, présence, île absente, attente.
function TravelRules.rowState(info: RowInfo): string
	if not info.unlocked then
		return TravelRules.State.Locked
	end
	if info.current then
		return TravelRules.State.Here
	end
	if not info.available then
		return TravelRules.State.ComingSoon
	end
	if info.pending then
		return TravelRules.State.Pending
	end
	return TravelRules.State.Travel
end

-- Une demande doit-elle partir vers le serveur dans cet état ?
function TravelRules.shouldRequest(state: string): boolean
	return state == TravelRules.State.Travel
end

-- Message affiché quand le joueur choisit un monde qu'il ne peut pas
-- rejoindre (aucune demande envoyée) ; nil : rien à afficher.
function TravelRules.blockedMessage(state: string): string?
	if state == TravelRules.State.Locked then
		return "travel.locked"
	elseif state == TravelRules.State.ComingSoon then
		return "world.coming_soon"
	end
	return nil
end

-- Message affiché pour une réponse Travel refusée ; nil : silencieux.
-- Le succès est traité à part (message nommé « Bienvenue dans … »).
function TravelRules.refusalMessage(code: string?, codes: { [string]: string }): string?
	if code == codes.WorldLocked then
		return "travel.locked"
	elseif code == codes.WorldUnavailable then
		return "world.coming_soon"
	elseif code == codes.NoCharacter then
		return "travel.no_character"
	elseif code == codes.RateLimited then
		return "travel.wait"
	end
	-- INVALID_TARGET, PROFILE_NOT_LOADED : silencieux.
	return nil
end

return TravelRules
