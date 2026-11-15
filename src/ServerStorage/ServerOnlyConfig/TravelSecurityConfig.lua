--!strict
-- Paramètres de sécurité du voyage entre mondes (T8, D-021). Serveur
-- uniquement (ServerStorage, jamais répliqué).
--
-- TOUTES ces valeurs sont des HYPOTHÈSES DE DÉPART, absentes de la Bible :
-- à mesurer en test réel. Grâce d'observation après un voyage :
-- MovementSecurityConfig.ServerTeleport.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local TravelSecurityConfig = {
	-- Seau à jetons par joueur : deux voyages d'affilée, puis un toutes les
	-- 5 s. Un voyage légitime est rare (changement de monde).
	RateLimits = {
		Travel = {
			burst = 2,
			refillPerSecond = 0.2,
		},
	},

	RateLimitFeedback = {
		-- Un joueur limité reçoit au plus une réponse RATE_LIMITED par période.
		noticeIntervalSeconds = 1,
		-- Une ligne de journal toutes les N demandes rejetées par joueur.
		logEveryRejections = 20,
	},

	Payload = {
		-- Longueur maximale d'un identifiant de monde.
		maxIdLength = 32,
	},

	Arrival = {
		-- Hauteur ajoutée au-dessus du point d'arrivée (studs) : centre du
		-- HumanoidRootPart d'un avatar debout (environ 3 studs).
		heightStuds = 3,
	},
}

return TableUtil.deepFreeze(TravelSecurityConfig)
