--!strict
-- Paramètres de la persistance des profils joueurs (T1).
-- Source : architecture technique, section 7 ; décisions D-006 et D-008.
--
-- Aucune valeur économique ici. Les durées sont des réglages techniques
-- de départ, à ajuster d'après les mesures en test privé.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local DataConfig = {
	-- Version courante du schéma de profil. Toute hausse exige une
	-- migration dans DataSchema.Migrations et des tests.
	SchemaVersion = 1,

	Store = {
		-- DataStore de production (architecture 7.2).
		name = "GrabAndGrow_PlayerData_v1",
		-- DataStore distinct utilisé depuis Studio quand le magasin en
		-- mémoire est désactivé : Studio ne touche jamais la production.
		studioName = "GrabAndGrow_PlayerData_v1_Studio",
		keyPrefix = "Player_",
		-- Copies de récupération d'un profil normalisé (D-008), dans le même
		-- DataStore : `Recovery_<UserId>_<heure Unix>`. Jamais écrasées.
		recoveryKeyPrefix = "Recovery_",
	},

	Studio = {
		-- true  : dans Studio, les profils vivent en mémoire et sont perdus
		--         à l'arrêt (aucun appel DataStore).
		-- false : dans Studio, utiliser le DataStore réel `studioName`
		--         (place publié + accès API Studio activé).
		-- Sans effet hors Studio : la production utilise toujours `name`.
		useMemoryStore = true,
	},

	-- Reprises d'un appel DataStore en échec : attente 1, 2, 4, 8 s.
	Retry = {
		maxAttempts = 5,
		baseDelaySeconds = 1,
		maxDelaySeconds = 8,
	},

	SessionLock = {
		-- Durée de validité du verrou après sa dernière écriture. Doit
		-- rester nettement supérieure à l'intervalle de sauvegarde, qui le
		-- renouvelle.
		timeoutSeconds = 180,
		-- Attente d'un verrou détenu par un autre serveur (cas normal :
		-- l'ancien serveur termine sa sauvegarde de sortie).
		acquireAttempts = 6,
		acquireDelaySeconds = 5,
	},

	Save = {
		autosaveIntervalSeconds = 60,
		-- Période d'attente quand une sauvegarde du même profil est en cours.
		busyPollSeconds = 0.1,
	},
}

return TableUtil.deepFreeze(DataConfig)
