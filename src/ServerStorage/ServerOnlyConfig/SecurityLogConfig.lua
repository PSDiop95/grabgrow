--!strict
-- Paramètres du journal de sécurité (T6, D-019). Serveur uniquement.
-- Hypothèses initiales : à ajuster selon le volume réel des journaux.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local SecurityLogConfig = {
	-- Au plus une ligne par joueur et par type d'événement pendant cette
	-- durée (s) ; les occurrences intermédiaires sont comptées
	-- (`suppressed=`) et rapportées avec la ligne suivante.
	perPlayerTypeIntervalSeconds = 10,

	-- Plafond global : au plus `globalMaxLines` lignes par période de
	-- `globalWindowSeconds`, tous joueurs confondus (protection contre un
	-- afflux de tricheurs).
	globalMaxLines = 60,
	globalWindowSeconds = 60,

	-- Longueur maximale d'une valeur texte journalisée. Les valeurs venant
	-- du client sont réduites aux caractères [%w_%-.:] avant écriture.
	maxValueLength = 48,
}

return TableUtil.deepFreeze(SecurityLogConfig)
