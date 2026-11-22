--!strict
-- Paramètres de sécurité des gardiens et des sites sacrés (T10.3).
-- Serveur uniquement (ServerStorage, jamais répliqué).
-- HYPOTHÈSES DE DÉPART, à mesurer en test réel (latence mobile).
--
-- Ne pas dupliquer ici ce qui est défini dans GuardianConfig (portées
-- nominales, cadence nominale, durées de combat).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local GuardianSecurityConfig = {
	Distance = {
		-- Marge ajoutée aux portées nominales (éclat, autel, nœud sacré) :
		-- écart client/serveur (≈ 2,4 studs à 16 studs/s et 150 ms) et taille
		-- de la cible. Même valeur que la collecte.
		toleranceStuds = 4,
	},

	Cooldown = {
		-- Avance tolérée sur l'intervalle minimal entre deux saisies d'éclat.
		jitterToleranceSeconds = 0.1,
	},

	-- Seau à jetons par joueur et par action (RateLimitService).
	-- Cadence légitime d'éclats : ≤ 2,9 saisies/s.
	RateLimits = {
		GuardianActivate = { burst = 3, refillPerSecond = 0.5 },
		GuardianStrike = { burst = 8, refillPerSecond = 4 },
		SacredCollect = { burst = 5, refillPerSecond = 2 },
	},

	RateLimitFeedback = {
		noticeIntervalSeconds = 1,
		logEveryRejections = 50,
	},

	Payload = {
		maxIdLength = 64,
	},
}

return TableUtil.deepFreeze(GuardianSecurityConfig)
