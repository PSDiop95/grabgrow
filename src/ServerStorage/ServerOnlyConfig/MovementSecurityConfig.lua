--!strict
-- Paramètres de la validation des déplacements (T6, A-26, A-37, décision
-- D-019). Serveur uniquement : ServerStorage, jamais répliqué au client.
--
-- TOUTES ces valeurs sont des HYPOTHÈSES INITIALES (R4, validées sous
-- réserve par le propriétaire le 2026-11-13), absentes de la Bible. Elles
-- sont à calibrer avec des tests de latence et des déplacements légitimes
-- réels. Elles se règlent ici, sans toucher au code de MovementValidator.
--
-- Unités : distances en studs, durées en secondes, vitesses en studs/s.
-- « Vitesse de référence » = vitesse des Boots lue dans le PROFIL SERVEUR
-- (jamais Humanoid.WalkSpeed, modifiable par le client, A-37).
--
-- Deux seuils distincts :
--   * Teleport  : saut horizontal entre DEUX ÉCHANTILLONS consécutifs ;
--   * Horizontal: vitesse moyenne sur la FENÊTRE GLISSANTE, depuis la plus
--                 ancienne position validée de la fenêtre.
-- Le vertical est jugé à part : la descente (saut, chute) n'est jamais
-- limitée ; seule la montée l'est.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local MovementSecurityConfig = {
	Sampling = {
		-- Période d'échantillonnage serveur de chaque personnage (s).
		-- 0,25 s = 4 lectures par seconde et par joueur.
		intervalSeconds = 0.25,
	},

	Window = {
		-- Durée de la fenêtre glissante (s). Les rafales réseau (positions
		-- figées puis rattrapées d'un coup) se compensent sur cette durée.
		durationSeconds = 1.0,
		-- Position identique d'un échantillon au suivant (à
		-- stationaryEpsilonStuds près) : joueur immobile OU positions figées
		-- par le réseau. Une telle suite garde l'heure de son début, dans la
		-- limite de freezeCreditSeconds de plus que la fenêtre : un gel
		-- réseau jusqu'à durationSeconds + freezeCreditSeconds (2 s) puis un
		-- rattrapage d'un coup ne sont pas pénalisés. Borné pour qu'une
		-- longue immobilité ne donne pas de crédit de vitesse illimité.
		stationaryEpsilonStuds = 0.05,
		freezeCreditSeconds = 1.0,
	},

	Horizontal = {
		-- Distance horizontale admise sur la fenêtre :
		--   vitesse de référence x speedFactor x durée + slackStuds.
		-- 1,5 : marge de latence et de poussées physiques ; 8 studs :
		-- rattrapage d'environ 0,5 s de positions retenues à 16 studs/s.
		speedFactor = 1.5,
		slackStuds = 8,
	},

	Teleport = {
		-- Saut horizontal admis entre deux échantillons consécutifs :
		--   vitesse de référence x Horizontal.speedFactor x écart + singleSampleStuds.
		-- 30 studs : bien au-delà d'une rafale réseau ou d'une collision.
		singleSampleStuds = 30,
	},

	Vertical = {
		-- Montée admise sur la fenêtre :
		--   vitesse de référence x riseSpeedFactor x durée + jumpAllowanceStuds + slackStuds.
		-- riseSpeedFactor = 1 : pentes jusqu'à 45° et échelles. Saut Roblox
		-- par défaut : environ 7,2 studs. La descente n'est jamais limitée.
		riseSpeedFactor = 1.0,
		jumpAllowanceStuds = 8,
		slackStuds = 4,
	},

	Escalation = {
		-- Une anomalie = un ÉPISODE : suite d'échantillons hors limites,
		-- terminée par un échantillon valide. Une anomalie isolée n'est que
		-- journalisée (aucune correction).
		-- Correction (retour à la dernière position validée + suspension) si :
		--   * repeatedCount épisodes dans les repeatedWindowSeconds dernières secondes ;
		--   * OU un même épisode dure plus de persistentEpisodeSeconds
		--     (anomalie revérifiée à chaque échantillon et toujours présente).
		repeatedCount = 3,
		repeatedWindowSeconds = 10,
		persistentEpisodeSeconds = 3,
		-- Après une correction : collecte et vente refusées (TOO_FAR, R2).
		suspensionSeconds = 5,
		-- Après une correction : échantillons ignorés le temps que la
		-- position imposée par le serveur revienne du client (évite qu'un
		-- échantillon en vol ne relance une correction : pas de boucle).
		postCorrectionGraceSeconds = 1,
		-- Écart minimal entre deux corrections d'un même joueur.
		minCorrectionIntervalSeconds = 5,
	},

	ServerTeleport = {
		-- T8 (D-021) : après un voyage fait par le SERVEUR (WorldTravelService),
		-- échantillons ignorés pendant cette durée (s), le temps que la
		-- position imposée revienne du client : les positions encore en
		-- transit ne créent pas de faux positif. Même valeur que
		-- Escalation.postCorrectionGraceSeconds (validée en T6). CanAct reste
		-- appliqué pendant la grâce (collecte et vente jugées par rapport au
		-- point d'arrivée). HYPOTHÈSE, à mesurer avec la latence mobile.
		graceSeconds = 1,
	},

	Action = {
		-- Collecte et vente refusées pendant un épisode ouvert et durant
		-- holdSeconds après sa fin.
		holdSeconds = 1,
		-- Cohérence avant action : écart admis depuis la dernière position
		-- validée, calculé sur au plus maxAnchorAgeSeconds (deux périodes
		-- d'échantillonnage) : un joueur longtemps immobile n'obtient pas
		-- de marge pour un saut juste avant sa demande.
		maxAnchorAgeSeconds = 0.5,
	},
}

return TableUtil.deepFreeze(MovementSecurityConfig)
