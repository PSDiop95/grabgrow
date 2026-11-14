--!strict
-- Temps de jeu d'une session (T7, A-21, décision D-020). Logique pure.
--
-- Le serveur compte le temps écoulé entre le chargement du profil et
-- chaque sauvegarde (automatique, sortie, fermeture du serveur), avec une
-- horloge monotone (os.clock en production). PlayerDataService ajoute le
-- résultat à `stats.playTimeSeconds` juste avant d'écrire : aucune
-- sauvegarde supplémentaire.
--
-- Garanties :
--   * hors ligne jamais compté : le compteur démarre au chargement ;
--   * aucun double comptage : chaque intervalle est compté une fois, même
--     si l'écriture échoue (le temps reste dans le profil en mémoire et
--     part à l'écriture suivante) ;
--   * horloge qui recule ou valeur invalide : rien n'est ajouté ;
--   * intervalle anormalement long (serveur figé) : borné à `maxStep` ;
--   * fractions de seconde reportées, jamais perdues ni arrondies vers le haut.
-- Un serveur qui plante perd au plus le temps écoulé depuis la dernière
-- sauvegarde : sous-comptage possible, jamais de sur-comptage.

local PlayTimeTracker = {}

export type State = {
	accountedAt: number,
	remainder: number,
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function PlayTimeTracker.start(now: number): State
	assert(isFiniteNumber(now), "PlayTimeTracker.start : horloge invalide")
	return { accountedAt = now, remainder = 0 }
end

-- Secondes entières à ajouter depuis le dernier appel ; avance `state`.
function PlayTimeTracker.accrue(state: State, now: number, maxStep: number): number
	if not isFiniteNumber(now) then
		return 0
	end
	local delta = now - state.accountedAt
	state.accountedAt = now
	if delta <= 0 then
		return 0
	end
	if delta > maxStep then
		delta = maxStep
	end
	local total = state.remainder + delta
	local whole = math.floor(total)
	state.remainder = total - whole
	return whole
end

-- Nouvelle valeur de `current` après ajout de `seconds`, bornée à `maxValue`.
function PlayTimeTracker.add(current: number, seconds: number, maxValue: number): number
	if seconds <= 0 then
		return current
	end
	if current >= maxValue - seconds then
		return maxValue
	end
	return current + seconds
end

return PlayTimeTracker
