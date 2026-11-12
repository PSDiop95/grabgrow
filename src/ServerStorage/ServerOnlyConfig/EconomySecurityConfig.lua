--!strict
-- Paramètres de sécurité des achats (T4, décision D-015) : améliorations et
-- déblocage des mondes. Serveur uniquement (ServerStorage, jamais répliqué).
--
-- TOUTES ces valeurs sont des HYPOTHÈSES DE DÉPART, absentes de la Bible
-- économique. À mesurer en test réel et à ajuster en T6.
--
-- Aucun prix ici : coûts dans UpgradeConfig et WorldConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local EconomySecurityConfig = {
	-- Seau à jetons par joueur. Un achat x1 par toucher : un joueur rapide
	-- enchaîne au plus quelques achats par seconde.
	RateLimits = {
		Upgrade = {
			burst = 5,
			refillPerSecond = 3,
		},
		UnlockWorld = {
			burst = 2,
			refillPerSecond = 0.5,
		},
	},

	RateLimitFeedback = {
		-- Un joueur limité reçoit au plus une réponse RATE_LIMITED par période.
		noticeIntervalSeconds = 1,
		-- Une ligne de journal toutes les N demandes rejetées par joueur.
		logEveryRejections = 50,
	},

	Payload = {
		-- Longueur maximale d'un identifiant d'amélioration ou de monde.
		maxIdLength = 32,
	},
}

return TableUtil.deepFreeze(EconomySecurityConfig)
