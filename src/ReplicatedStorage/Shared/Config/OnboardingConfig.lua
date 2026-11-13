--!strict
-- Paramètres du guidage de première session (T5.3). Interface seulement :
-- aucune valeur économique, aucune récompense. HYPOTHÈSES DE DÉPART, à
-- ajuster après observation de vrais nouveaux joueurs (T7).

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local OnboardingConfig = {
	-- Nombre d'étapes affichées (Collecter, Vendre, Améliorer).
	totalSteps = 3,
	-- Étape « Vendre » : au-delà de ce nombre d'unités dans le sac (ou sac
	-- plein si la capacité est plus petite), le guidage montre la station.
	-- En dessous, il invite à continuer la collecte. Une vente plus tôt est
	-- reconnue (aucune quantité imposée).
	sellHintMinItems = 10,
	-- Durées d'affichage (secondes).
	introSeconds = 5,
	soldMessageSeconds = 3,
	doneMessageSeconds = 6,
	-- Rafraîchissement des repères (cible la plus proche, flèche de bord),
	-- seulement tant qu'un repère est affiché.
	markerRefreshSeconds = 0.25,
}

return TableUtil.deepFreeze(OnboardingConfig)
