--!strict
-- Profils joueurs : chargement, données de session en mémoire, sauvegarde,
-- verrou de session, libération. Seule source d'autorité sur le profil.
--
-- Ne contient aucune règle de gameplay (collecte, prix, achats) : les
-- futurs services modifient le profil par `Update`, qui valide chaque
-- changement contre le schéma.
--
-- Toutes les dépendances externes (magasin, horloge, attente) sont
-- injectées : le service se teste sans DataStore réel (décision D-005).
-- Les événements Roblox (PlayerAdded, BindToClose) sont branchés dans
-- Systems/PlayerSession.
--
-- Valeur stockée sous la clé `Player_<UserId>` :
--   { profile = <profil schéma v1>, session = { id, expiresAt } | nil }
-- `session` est le verrou : seul le serveur qui le détient peut écrire.
--
-- D-008 : un profil normalisé au chargement (champs ajoutés, valeurs
-- bornées, migration) n'est pas réécrit au chargement. Avant sa première
-- sauvegarde, l'original est copié sous `Recovery_<UserId>_<heure>` ; si
-- cette copie échoue, la sauvegarde est bloquée.
-- Détails et limites : docs/DATA_PERSISTENCE.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)
local DataSchema = require(script.Parent.Parent.Systems.DataSchema)
local PlayTimeTracker = require(script.Parent.Parent.Systems.PlayTimeTracker)

local PlayerDataService = {}

PlayerDataService.Code = table.freeze({
	NotLoaded = "NotLoaded", -- profil absent, en cours de chargement ou de libération
	AlreadyLoaded = "AlreadyLoaded",
	InvalidArgument = "InvalidArgument",
	StoreError = "StoreError", -- DataStore en échec après toutes les reprises
	SessionLocked = "SessionLocked", -- profil détenu par un autre serveur
	LockLost = "LockLost", -- verrou repris par un autre serveur
	CorruptData = DataSchema.ErrorCode.CorruptData,
	UnsupportedVersion = DataSchema.ErrorCode.UnsupportedVersion,
	MigrationFailed = DataSchema.ErrorCode.MigrationFailed,
	BackupFailed = "BackupFailed", -- copie de récupération impossible : sauvegarde bloquée (D-008)
	InvalidUpdate = "InvalidUpdate", -- modification refusée par le schéma
	Aborted = "Aborted", -- modification abandonnée par l'appelant
	Cancelled = "Cancelled", -- joueur parti pendant le chargement
	ShuttingDown = "ShuttingDown",
})

export type Result = {
	ok: boolean,
	code: string?,
	message: string?,
}

-- Sous-ensemble de GlobalDataStore utilisé par le service.
export type Store = {
	UpdateAsync: (self: any, key: string, transform: (any, any) -> ...any) -> ...any,
}

export type Dependencies = {
	store: Store,
	-- Identifiant unique de ce serveur (game.JobId en production).
	serverId: string,
	-- Heure Unix en secondes (os.time en production).
	clock: () -> number,
	-- Attente bloquante du fil courant (task.wait en production).
	wait: (seconds: number) -> (),
	-- Lance une fonction sans attendre sa fin (task.spawn en production).
	spawn: (callback: () -> ()) -> (),
	-- Appelé quand un autre serveur a repris le verrou d'un joueur présent.
	onSessionLost: ((userId: number) -> ())?,
	log: ((level: string, message: string) -> ())?,
	-- Horloge monotone en secondes (os.clock en production) pour le temps
	-- de jeu (T7, A-21). Absente : stats.playTimeSeconds n'est pas alimenté.
	playClock: (() -> number)?,
	-- Remplace DataConfig (tests uniquement).
	config: any?,
}

type Session = {
	userId: number,
	key: string,
	lockId: string,
	state: "loading" | "active" | "releasing" | "lost",
	data: any,
	saving: boolean,
	resaveRequested: boolean,
	releaseRequested: boolean,
	-- T8.7 (D-023) : sauvegarde différée déjà programmée par RequestSave.
	saveScheduled: boolean,
	lastSaveResult: Result,
	-- Copie de récupération à écrire avant la première sauvegarde d'un
	-- profil normalisé (D-008). nil une fois écrite, ou si inutile.
	pendingBackup: { key: string, record: any }?,
	-- Temps de jeu non encore ajouté au profil (nil tant que non actif).
	playTime: PlayTimeTracker.State?,
}

local OK: Result = table.freeze({ ok = true })

local function failure(code: string, message: string?): Result
	return { ok = false, code = code, message = message }
end

local function defaultLog(level: string, message: string)
	if level == "info" then
		print(`[PlayerData] {message}`)
	else
		warn(`[PlayerData] {level} : {message}`)
	end
end

-- Entier non nul. Les serveurs de test de Studio (Test > Local Server)
-- donnent aux joueurs des UserId négatifs (-1, -2...) ; ils n'existent pas
-- sur un serveur publié.
local function isValidUserId(userId: any): boolean
	return type(userId) == "number" and userId % 1 == 0 and userId ~= 0 and math.abs(userId) ~= math.huge
end

local function describeLock(lock: any, now: number): string
	if lock == nil then
		return "aucun"
	end
	local remaining = lock.expiresAt - now
	if remaining > 0 then
		return `{lock.id} (expire dans {remaining} s)`
	end
	return `{lock.id} (expiré depuis {-remaining} s)`
end

function PlayerDataService.new(dependencies: Dependencies)
	local store = dependencies.store
	local clock = dependencies.clock
	local wait = dependencies.wait
	local spawn = dependencies.spawn
	local log = dependencies.log or defaultLog
	local config = dependencies.config or DataConfig
	local playClock = dependencies.playClock
	local playTimeConfig = config.PlayTime or DataConfig.PlayTime

	local sessions: { [number]: Session } = {}
	local loadCounter = 0
	local shuttingDown = false

	local service = {}

	-- Appelle UpdateAsync avec reprises et attente progressive. `transform`
	-- reçoit en second argument le numéro de la tentative.
	-- Retourne (true) ou (false, dernière erreur).
	local function updateWithRetry(key: string, transform: (stored: any, attempt: number) -> ...any): (boolean, string?)
		local delay = config.Retry.baseDelaySeconds
		local lastError = "erreur inconnue"
		for attempt = 1, config.Retry.maxAttempts do
			local ok, err = pcall(function()
				store:UpdateAsync(key, function(stored: any): ...any
					return transform(stored, attempt)
				end)
			end)
			if ok then
				return true, nil
			end
			lastError = tostring(err)
			log("warn", `{key} : appel DataStore en échec ({attempt}/{config.Retry.maxAttempts}) : {lastError}`)
			if attempt < config.Retry.maxAttempts then
				wait(delay)
				delay = math.min(delay * 2, config.Retry.maxDelaySeconds)
			end
		end
		return false, lastError
	end

	local function newLock(session: Session): any
		return { id = session.lockId, expiresAt = clock() + config.SessionLock.timeoutSeconds }
	end

	-- Écrit la copie de récupération de l'original (D-008). N'écrase jamais
	-- une copie existante différente.
	local function writeBackup(session: Session): Result
		local backup = session.pendingBackup :: { key: string, record: any }
		local conflict = false
		local ok, err = updateWithRetry(backup.key, function(stored: any): ...any
			conflict = false
			if stored == nil then
				return backup.record, { session.userId }
			end
			if not TableUtil.deepEqual(stored, backup.record) then
				conflict = true
			end
			-- Identique : écrite par une tentative dont la réponse s'est perdue.
			return nil
		end)
		if not ok then
			return failure(PlayerDataService.Code.BackupFailed, err)
		end
		if conflict then
			return failure(PlayerDataService.Code.BackupFailed, `{backup.key} existe déjà avec un autre contenu`)
		end
		log("info", `{session.key} : copie de récupération écrite : {backup.key}`)
		session.pendingBackup = nil
		return OK
	end

	-- Retire le verrou sans toucher au profil stocké.
	local function releaseLockOnly(session: Session)
		local ok, err = updateWithRetry(session.key, function(stored: any): ...any
			if type(stored) == "table" and type(stored.session) == "table" and stored.session.id == session.lockId then
				stored.session = nil
				return stored, { session.userId }
			end
			return nil
		end)
		if not ok then
			log("error", `{session.key} : verrou non libéré : {tostring(err)}`)
		end
	end

	-- Ajoute au profil en mémoire le temps de jeu écoulé depuis le dernier
	-- ajout (T7, A-21). Appelé juste avant chaque écriture : le temps compté
	-- reste en mémoire si l'écriture échoue, donc jamais compté deux fois.
	local function accruePlayTime(session: Session)
		local tracker = session.playTime
		if tracker == nil or playClock == nil then
			return
		end
		local seconds = PlayTimeTracker.accrue(tracker, playClock(), playTimeConfig.maxAccrualSeconds)
		local stats = if type(session.data) == "table" then session.data.stats else nil
		if seconds > 0 and type(stats) == "table" and type(stats.playTimeSeconds) == "number" then
			stats.playTimeSeconds = PlayTimeTracker.add(stats.playTimeSeconds, seconds, DataSchema.MAX_SAFE_INTEGER)
		end
	end

	-- Écrit le profil si ce serveur détient toujours le verrou. `release`
	-- retire le verrou dans la même écriture. Ne réécrit jamais une valeur
	-- détenue par une autre session.
	local function writeProfile(session: Session, release: boolean): Result
		if session.pendingBackup ~= nil then
			local backupResult = writeBackup(session)
			if not backupResult.ok then
				log(
					"error",
					`{session.key} : sauvegarde bloquée, copie de récupération impossible (D-008) : {tostring(backupResult.message)}`
				)
				if release then
					-- Le profil original reste en place ; les modifications de
					-- la session sont perdues.
					releaseLockOnly(session)
				end
				return backupResult
			end
		end

		accruePlayTime(session)
		local snapshot = TableUtil.deepCopy(session.data)
		snapshot.lastSaveAt = clock()

		local outcome = "pending"
		local ok, err = updateWithRetry(session.key, function(stored: any, attempt: number): ...any
			outcome = "lockLost"
			if type(stored) ~= "table" then
				return nil
			end
			local lock = stored.session
			if type(lock) == "table" and lock.id == session.lockId then
				outcome = "saved"
				-- Les autres champs de premier niveau sont conservés.
				stored.profile = snapshot
				stored.session = if release then nil else newLock(session)
				return stored, { session.userId }
			end
			-- Libération rejouée après une réponse perdue : la tentative
			-- précédente a déjà écrit le profil et retiré le verrou.
			if release and lock == nil and attempt > 1 and type(stored.profile) == "table" then
				if stored.profile.lastSaveAt == snapshot.lastSaveAt then
					outcome = "saved"
				end
			end
			return nil
		end)

		if not ok then
			return failure(PlayerDataService.Code.StoreError, err)
		end
		if outcome ~= "saved" then
			return failure(PlayerDataService.Code.LockLost, "verrou de session détenu par un autre serveur")
		end
		-- session.data a pu être remplacé par Update pendant l'écriture :
		-- seule la date est reportée, pas le contenu sauvegardé.
		session.data.lastSaveAt = snapshot.lastSaveAt
		return OK
	end

	local function markLost(session: Session)
		if session.state == "lost" then
			return
		end
		session.state = "lost"
		log("error", `{session.key} : verrou perdu, profil retiré de la mémoire sans écriture`)
		if dependencies.onSessionLost then
			dependencies.onSessionLost(session.userId)
		end
	end

	-- Une seule écriture à la fois par profil. Une demande reçue pendant une
	-- écriture provoque une seconde écriture à la suite, pour inclure les
	-- modifications faites entre-temps.
	local function saveSession(session: Session, reason: string): Result
		if session.saving then
			session.resaveRequested = true
			while session.saving do
				wait(config.Save.busyPollSeconds)
			end
			return session.lastSaveResult
		end

		session.saving = true
		local result: Result
		repeat
			session.resaveRequested = false
			result = writeProfile(session, false)
		until not (result.ok and session.resaveRequested and session.state == "active")
		session.lastSaveResult = result
		session.saving = false

		if result.code == PlayerDataService.Code.LockLost then
			markLost(session)
		elseif not result.ok then
			log("error", `{session.key} : sauvegarde ({reason}) en échec : {tostring(result.message)}`)
		else
			log(
				"info",
				`{session.key} : sauvegarde ({reason}) OK, lastSaveAt={session.data.lastSaveAt}, verrou renouvelé pour {config.SessionLock.timeoutSeconds} s`
			)
		end
		return result
	end

	local function releaseSession(session: Session): Result
		session.state = "releasing"
		while session.saving do
			wait(config.Save.busyPollSeconds)
		end

		session.saving = true
		local result = writeProfile(session, true)
		session.lastSaveResult = result
		session.saving = false

		if sessions[session.userId] == session then
			sessions[session.userId] = nil
		end
		local reason = if shuttingDown then "fermeture serveur" else "sortie"
		if not result.ok then
			log(
				"error",
				`{session.key} : sauvegarde ({reason}) en échec ({tostring(result.code)}) : {tostring(result.message)}`
			)
		else
			log("info", `{session.key} : sauvegarde ({reason}) OK, lastSaveAt={session.data.lastSaveAt}, verrou libéré`)
		end
		return result
	end

	-- Prend le verrou et lit le profil en une seule opération atomique.
	local function acquire(session: Session): (Result, any?)
		local outcome: any = nil
		for attempt = 1, config.SessionLock.acquireAttempts do
			local ok, err = updateWithRetry(session.key, function(stored: any): ...any
				outcome = nil
				local profile: any
				local repairs: { string } = {}
				local isNew = false

				if stored == nil then
					-- Clé absente, lue sans erreur : nouveau joueur.
					profile = DataSchema.newProfile()
					isNew = true
				elseif type(stored) ~= "table" then
					outcome = {
						code = PlayerDataService.Code.CorruptData,
						message = `valeur stockée de type {type(stored)}`,
					}
					return nil
				else
					local lock = stored.session
					if lock ~= nil then
						if type(lock) ~= "table" or type(lock.id) ~= "string" or type(lock.expiresAt) ~= "number" then
							outcome = { code = PlayerDataService.Code.CorruptData, message = "verrou de session illisible" }
							return nil
						end
						if lock.id ~= session.lockId and clock() < lock.expiresAt then
							outcome = {
								code = PlayerDataService.Code.SessionLocked,
								message = `profil détenu par la session {describeLock(lock, clock())}`,
							}
							return nil
						end
					end

					local normalized, code, message, normalizeRepairs = DataSchema.normalize(stored.profile)
					if normalized == nil then
						outcome = { code = code, message = message }
						return nil
					end

					local migrated = stored.profile.schemaVersion ~= config.SchemaVersion
					outcome = {
						profile = normalized,
						repairs = normalizeRepairs,
						isNew = false,
						previousLock = describeLock(lock, clock()),
						-- D-008 : original à préserver avant toute réécriture.
						original = if #normalizeRepairs > 0 or migrated then stored.profile else nil,
					}
					-- Le profil stocké reste tel quel : seul le verrou change.
					stored.session = newLock(session)
					return stored, { session.userId }
				end

				outcome = { profile = profile, repairs = repairs, isNew = isNew, previousLock = "aucun" }
				return { profile = profile, session = newLock(session) }, { session.userId }
			end)

			if not ok then
				return failure(PlayerDataService.Code.StoreError, err), nil
			end
			if outcome.profile ~= nil then
				for _, repair in ipairs(outcome.repairs) do
					log("warn", `{session.key} : profil réparé au chargement : {repair}`)
				end
				if outcome.original ~= nil then
					local capturedAt = clock()
					local backupKey = `{config.Store.recoveryKeyPrefix}{session.userId}_{capturedAt}`
					session.pendingBackup = {
						key = backupKey,
						record = {
							kind = "PreNormalizationBackup",
							userId = session.userId,
							sourceKey = session.key,
							capturedAt = capturedAt,
							serverSchemaVersion = config.SchemaVersion,
							repairs = TableUtil.deepCopy(outcome.repairs),
							originalProfile = TableUtil.deepCopy(outcome.original),
						},
					}
					log(
						"warn",
						`{session.key} : profil normalisé en mémoire uniquement ; original conservé, copie {backupKey} avant la première sauvegarde (D-008)`
					)
				end
				log(
					"info",
					`{session.key} : {if outcome.isNew then "nouveau profil créé" else "profil chargé"}, lastSaveAt={outcome.profile.lastSaveAt}, verrou précédent : {outcome.previousLock}, nouveau verrou : {session.lockId}`
				)
				-- Copie : la table transmise au magasin ne doit pas rester
				-- partagée avec les données de session.
				return OK, TableUtil.deepCopy(outcome.profile)
			end
			if outcome.code ~= PlayerDataService.Code.SessionLocked then
				break
			end
			if session.releaseRequested or shuttingDown then
				break
			end
			if attempt < config.SessionLock.acquireAttempts then
				log(
					"warn",
					`{session.key} : {outcome.message} ; nouvelle tentative dans {config.SessionLock.acquireDelaySeconds} s ({attempt}/{config.SessionLock.acquireAttempts})`
				)
				wait(config.SessionLock.acquireDelaySeconds)
			end
		end

		log("error", `{session.key} : chargement refusé ({tostring(outcome.code)}) : {tostring(outcome.message)}`)
		return failure(outcome.code, outcome.message), nil
	end

	-- Charge le profil et prend le verrou de session. Bloquant.
	-- En cas d'échec, rien n'est écrit et aucun profil n'est disponible :
	-- l'appelant doit empêcher le joueur de jouer.
	function service.LoadPlayer(userId: number): Result
		if not isValidUserId(userId) then
			return failure(PlayerDataService.Code.InvalidArgument, "userId invalide")
		end
		if shuttingDown then
			return failure(PlayerDataService.Code.ShuttingDown)
		end

		-- Retour immédiat du même joueur : attendre la fin de la sauvegarde
		-- de sortie précédente sur ce serveur.
		local previous = sessions[userId]
		if previous ~= nil and (previous.state == "releasing" or previous.state == "lost") then
			local attempts = config.SessionLock.acquireAttempts
			local remaining = attempts * config.SessionLock.acquireDelaySeconds
			while sessions[userId] == previous and remaining > 0 do
				wait(config.Save.busyPollSeconds)
				remaining -= config.Save.busyPollSeconds
			end
		end
		if sessions[userId] ~= nil then
			return failure(PlayerDataService.Code.AlreadyLoaded, "une session existe déjà pour ce joueur")
		end

		loadCounter += 1
		local key = `{config.Store.keyPrefix}{userId}`
		local session: Session = {
			userId = userId,
			key = key,
			-- Unique par chargement : une session abandonnée de ce même
			-- serveur ne peut pas écrire à la place de la suivante.
			lockId = `{dependencies.serverId}:{loadCounter}`,
			state = "loading",
			data = nil,
			saving = false,
			resaveRequested = false,
			releaseRequested = false,
			saveScheduled = false,
			lastSaveResult = OK,
			pendingBackup = nil,
		}
		sessions[userId] = session

		local result, profile = acquire(session)
		if not result.ok then
			sessions[userId] = nil
			return result
		end

		session.data = profile
		if session.releaseRequested or shuttingDown then
			-- Joueur parti (ou serveur en arrêt) pendant le chargement :
			-- rendre le verrou tout de suite.
			releaseSession(session)
			return failure(PlayerDataService.Code.Cancelled, "chargement annulé")
		end

		session.state = "active"
		if playClock ~= nil then
			-- Le temps de chargement et le temps hors ligne ne comptent pas.
			session.playTime = PlayTimeTracker.start(playClock())
		end
		return OK
	end

	function service.IsLoaded(userId: number): boolean
		local session = sessions[userId]
		return session ~= nil and session.state == "active"
	end

	-- Retourne une COPIE du profil, ou nil s'il n'est pas chargé. Modifier
	-- la copie n'a aucun effet : utiliser Update.
	function service.GetData(userId: number): any?
		local session = sessions[userId]
		if session == nil or session.state ~= "active" then
			return nil
		end
		return TableUtil.deepCopy(session.data)
	end

	-- Seule voie de modification du profil. `mutator` reçoit un brouillon
	-- qu'il modifie sur place. Le brouillon ne remplace le profil que s'il
	-- respecte le schéma : sinon rien ne change (tout ou rien).
	-- `mutator` ne doit pas suspendre le fil ; il peut retourner false pour
	-- abandonner. Aucune écriture DataStore n'est déclenchée ici.
	function service.Update(userId: number, mutator: (draft: any) -> boolean?): Result
		local session = sessions[userId]
		if session == nil or session.state ~= "active" then
			return failure(PlayerDataService.Code.NotLoaded, "profil non chargé")
		end
		if type(mutator) ~= "function" then
			return failure(PlayerDataService.Code.InvalidArgument, "mutator doit être une fonction")
		end

		local draft = TableUtil.deepCopy(session.data)
		local thread = coroutine.create(mutator)
		local ok, returned = coroutine.resume(thread, draft)
		if not ok then
			log("error", `{session.key} : erreur dans une modification : {tostring(returned)}`)
			return failure(PlayerDataService.Code.InvalidUpdate, tostring(returned))
		end
		if coroutine.status(thread) ~= "dead" then
			coroutine.close(thread)
			log("error", `{session.key} : modification refusée (fil suspendu)`)
			return failure(PlayerDataService.Code.InvalidUpdate, "mutator ne doit pas suspendre le fil")
		end
		if returned == false then
			return failure(PlayerDataService.Code.Aborted)
		end

		local valid, message = DataSchema.validate(draft)
		if not valid then
			log("error", `{session.key} : modification refusée par le schéma : {tostring(message)}`)
			return failure(PlayerDataService.Code.InvalidUpdate, message)
		end

		session.data = draft
		return OK
	end

	-- Sauvegarde le profil et renouvelle le verrou. Bloquant.
	-- `reason` ne sert qu'au journal (ex. "auto").
	function service.SavePlayer(userId: number, reason: string?): Result
		local session = sessions[userId]
		if session == nil or session.state ~= "active" then
			return failure(PlayerDataService.Code.NotLoaded, "profil non chargé")
		end
		return saveSession(session, reason or "manuelle")
	end

	-- T8.7 (D-023) : demande une sauvegarde après une opération importante
	-- (achat d'amélioration, déblocage de monde). Non bloquant : la
	-- sauvegarde part après DataConfig.Save.importantSaveDelaySeconds, et
	-- toutes les demandes reçues pendant ce délai n'en font qu'une (budget
	-- d'écritures DataStore). Retourne OK si une sauvegarde est programmée
	-- ou déjà prévue, NotLoaded sinon. Aucune règle de jeu ici.
	function service.RequestSave(userId: number, reason: string?): Result
		local session = sessions[userId]
		if session == nil or session.state ~= "active" then
			return failure(PlayerDataService.Code.NotLoaded, "profil non chargé")
		end
		if session.saveScheduled then
			return OK
		end
		session.saveScheduled = true
		local delaySeconds = config.Save.importantSaveDelaySeconds or DataConfig.Save.importantSaveDelaySeconds
		spawn(function()
			wait(delaySeconds)
			session.saveScheduled = false
			-- Joueur parti entre-temps : la sauvegarde de sortie s'en charge.
			if sessions[userId] == session and session.state == "active" then
				saveSession(session, reason or "opération importante")
			end
		end)
		return OK
	end

	-- Sauvegarde finale, libération du verrou et retrait de la mémoire.
	-- À appeler quand le joueur quitte. Bloquant.
	function service.ReleasePlayer(userId: number): Result
		local session = sessions[userId]
		if session == nil then
			return failure(PlayerDataService.Code.NotLoaded, "aucune session pour ce joueur")
		end

		if session.state == "loading" then
			-- LoadPlayer rendra le verrou dès la fin de la lecture.
			session.releaseRequested = true
			return OK
		elseif session.state == "lost" then
			-- Le verrou appartient à une autre session : ne rien écrire.
			sessions[userId] = nil
			return failure(PlayerDataService.Code.LockLost, "verrou détenu par un autre serveur")
		elseif session.state == "releasing" then
			while sessions[userId] == session do
				wait(config.Save.busyPollSeconds)
			end
			return session.lastSaveResult
		end

		return releaseSession(session)
	end

	-- Arrêt du serveur : sauvegarde et libère tous les profils en parallèle,
	-- puis attend la fin. Refuse tout nouveau chargement.
	function service.Shutdown()
		shuttingDown = true
		local pending = 0
		for userId in pairs(sessions) do
			pending += 1
			spawn(function()
				service.ReleasePlayer(userId)
				pending -= 1
			end)
		end
		-- Les chargements en cours se terminent seuls (releaseRequested).
		while pending > 0 or next(sessions) ~= nil do
			wait(config.Save.busyPollSeconds)
		end
	end

	return service
end

return PlayerDataService
