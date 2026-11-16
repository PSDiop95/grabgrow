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
	-- v2 (T7, D-020) : section `achievements` (succès permanents).
	-- v3 (T8.6, D-022) : section `collection` (journal de collection).
	SchemaVersion = 3,

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

	-- Temps de jeu (T7, A-21, D-020) : intervalle maximal compté entre deux
	-- sauvegardes. Les sauvegardes ont lieu toutes les 60 s ; un écart plus
	-- long que 300 s signale un serveur figé et n'est compté qu'à 300 s.
	PlayTime = {
		maxAccrualSeconds = 300,
	},

	Save = {
		autosaveIntervalSeconds = 60,
		-- T8.7 (D-023) : délai d'une sauvegarde demandée après un achat
		-- d'amélioration ou un déblocage de monde. Les demandes reçues
		-- pendant ce délai sont regroupées en une seule écriture. Réglage
		-- technique de départ (budget d'écritures DataStore).
		importantSaveDelaySeconds = 5,
		-- Période d'attente quand une sauvegarde du même profil est en cours.
		busyPollSeconds = 0.1,
	},
}

return TableUtil.deepFreeze(DataConfig)
