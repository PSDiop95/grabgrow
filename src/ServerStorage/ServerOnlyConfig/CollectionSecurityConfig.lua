--!strict
-- Paramètres de sécurité de la collecte (T2, anomalie A-16, décision D-010).
-- Serveur uniquement : ce module vit dans ServerStorage et n'est jamais
-- répliqué au client.
--
-- TOUTES ces valeurs sont des HYPOTHÈSES DE DÉPART, absentes de la Bible
-- économique. À mesurer en test réel (latence mobile) et à ajuster en T6/T7.
--
-- Ne pas dupliquer ici ce qui est défini ailleurs :
--   * portée nominale de collecte    -> UpgradeConfig.Magnet (niveau du profil)
--   * intervalle nominal de collecte -> UpgradeConfig.Grabber.levels[n].value
--   * vitesse de marche de référence -> UpgradeConfig.Boots (niveau du profil)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local CollectionSecurityConfig = {
	Distance = {
		-- Marge ajoutée à la portée nominale (studs). Couvre l'écart entre la
		-- position vue par le client et celle répliquée au serveur (16 studs/s
		-- et 150 ms de latence = 2,4 studs) et la taille de la ressource.
		-- S'ajoute à la portée du Magnet du joueur.
		toleranceStuds = 4,
	},

	Cooldown = {
		-- Avance maximale acceptée sur l'intervalle nominal (secondes), pour
		-- absorber la gigue réseau. L'échéance suivante reste calée sur
		-- l'intervalle nominal : la cadence moyenne ne peut pas le dépasser.
		jitterToleranceSeconds = 0.1,
	},

	-- Plausibilité du déplacement entre deux collectes réussies : distance
	-- maximale = vitesse des Boots du joueur x speedFactor x temps écoulé + slackStuds.
	-- Limite la collecte par téléportation. Volontairement large (chute,
	-- poussée physique) : ce n'est pas un anti-triche de déplacement complet.
	Travel = {
		speedFactor = 2,
		slackStuds = 20,
	},

	-- Seau à jetons par joueur et par action : `burst` demandes d'un coup,
	-- puis `refillPerSecond` demandes par seconde. La cadence légitime la
	-- plus rapide (Grabber niveau 10, 0,36 s) est de 2,8 demandes/s.
	RateLimits = {
		Collect = {
			burst = 10,
			refillPerSecond = 5,
		},
	},

	RateLimitFeedback = {
		-- Un joueur limité reçoit au plus une réponse RATE_LIMITED par période.
		noticeIntervalSeconds = 1,
		-- Une ligne de journal toutes les N demandes rejetées par joueur.
		logEveryRejections = 50,
	},

	Logging = {
		-- Période minimale entre deux lignes « déplacement implausible » pour
		-- un même joueur.
		suspiciousIntervalSeconds = 10,
	},

	Payload = {
		maxResourceIdLength = 64,
	},
}

return TableUtil.deepFreeze(CollectionSecurityConfig)
