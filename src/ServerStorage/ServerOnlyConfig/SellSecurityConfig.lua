--!strict
-- Paramètres de sécurité de la vente (T3, décision D-014).
-- Serveur uniquement : ce module vit dans ServerStorage et n'est jamais
-- répliqué au client.
--
-- TOUTES ces valeurs sont des HYPOTHÈSES DE DÉPART, absentes de la Bible
-- économique. À mesurer en test réel et à ajuster en T6/T7.
--
-- Ne pas dupliquer ici ce qui est défini ailleurs :
--   * distance nominale d'interaction -> GameConfig.Selling.interactRangeStuds
--   * prix des ressources             -> ResourceConfig.sellValue

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local SellSecurityConfig = {
	Distance = {
		-- Marge ajoutée à la distance nominale (studs), mesurée en 3D du
		-- HumanoidRootPart au centre de la zone : latence (16 studs/s x
		-- 150 ms = 2,4 studs) et hauteur du personnage au-dessus du sol.
		toleranceStuds = 4,
	},

	-- Seau à jetons par joueur. Une vente légitime vide le sac : au-delà
	-- d'une vente par seconde, les demandes n'ont aucun effet utile.
	RateLimits = {
		Sell = {
			burst = 3,
			refillPerSecond = 1,
		},
	},

	RateLimitFeedback = {
		-- Un joueur limité reçoit au plus une réponse RATE_LIMITED par période.
		noticeIntervalSeconds = 1,
		-- Une ligne de journal toutes les N demandes rejetées par joueur.
		logEveryRejections = 50,
	},

	Payload = {
		maxSellZoneIdLength = 64,
	},
}

return TableUtil.deepFreeze(SellSecurityConfig)
