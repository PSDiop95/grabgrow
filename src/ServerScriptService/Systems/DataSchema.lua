--!strict
-- Schéma versionné du profil joueur (v1 D-006, v2 D-020, v3 D-022) : profil par
-- défaut, contrôle d'intégrité et migrations.
--
-- Règles d'intégrité (décision D-008) :
--   * champ ou section manquant  -> valeur par défaut ajoutée ;
--   * nombre hors bornes         -> borné (niveau, solde négatif, décimale) ;
--   * type incorrect, NaN        -> profil refusé (CorruptData), jamais réparé ;
--   * version future             -> profil refusé (UnsupportedVersion) ;
--   * clés inconnues             -> conservées telles quelles.
-- Un profil refusé n'est jamais réécrit : la sauvegarde reste intacte.
--
-- Logique pure : aucun appel réseau, aucun état.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local DataConfig = require(Config.DataConfig)
local GameConfig = require(Config.GameConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local DataSchema = {}

DataSchema.ErrorCode = table.freeze({
	CorruptData = "CorruptData",
	UnsupportedVersion = "UnsupportedVersion",
	MigrationFailed = "MigrationFailed",
})

-- Au-delà, un nombre flottant ne représente plus tous les entiers.
local MAX_SAFE_INTEGER = 9_007_199_254_740_991
DataSchema.MAX_SAFE_INTEGER = MAX_SAFE_INTEGER

type LevelBounds = { min: number, max: number }

-- min = niveau de départ, max = niveau maximum, lus dans UpgradeConfig
-- pour les cinq améliorations (T4, D-015). magnetLevel = 0 : non acquis
-- (D-006).
local LEVEL_BOUNDS: { [string]: LevelBounds } = {}
for _, definition in pairs(UpgradeConfig) do
	LEVEL_BOUNDS[definition.profileKey] = {
		min = definition.startLevel,
		max = definition.startLevel + #definition.levels - 1,
	}
end

local CURRENCY_IDS = { "coins", "gems", "stars" }

-- Mondes persistés. Le monde de départ (GameConfig.StartingWorldId) est
-- toujours débloqué ; les autres démarrent verrouillés.
local WORLD_IDS = { "GreenValley", "GoldenDesert", "FrozenPeaks", "MysticWorld" }

local STAT_IDS = {
	"totalResourcesCollected",
	"totalCoinsEarned",
	"totalCoinsSpent",
	"totalSales",
	"playTimeSeconds",
}

local SETTING_DEFAULTS: { [string]: boolean } = {
	musicEnabled = true,
	sfxEnabled = true,
}

-- Longueur maximale d'un identifiant de succès persisté.
local MAX_ACHIEVEMENT_ID_LENGTH = 64
-- Longueur maximale d'un identifiant de ressource du journal (v3).
local MAX_DISCOVERY_ID_LENGTH = 64

-- Migrations : Migrations[n] transforme un profil de version n en profil de
-- version n + 1 (et fixe son schemaVersion).
DataSchema.Migrations = {
	-- v1 -> v2 (T7, D-020) : succès permanents, aucun obtenu. Aucune autre
	-- donnée modifiée. Une section `achievements` déjà présente (clé
	-- inconnue d'un v1) est conservée et contrôlée ensuite.
	[1] = function(profile: any): any
		if profile.achievements == nil then
			profile.achievements = {}
		end
		profile.schemaVersion = 2
		return profile
	end,

	-- v2 -> v3 (T8.6, D-022) : journal de collection VIDE (D-022 D3 : aucun
	-- historique reconstitué, même depuis l'inventaire). Aucune autre donnée
	-- modifiée. Une section `collection` déjà présente (clé inconnue d'un v2)
	-- est conservée telle quelle et contrôlée ensuite ; une sous-section
	-- `discoveredResources` absente est ajoutée. Idempotente.
	[2] = function(profile: any): any
		local collection = profile.collection
		if collection == nil then
			profile.collection = { discoveredResources = {} }
		elseif type(collection) == "table" and collection.discoveredResources == nil then
			collection.discoveredResources = {}
		end
		-- Section non table : laissée telle quelle, refusée par le contrôle
		-- (CorruptData), jamais réécrite.
		profile.schemaVersion = 3
		return profile
	end,
} :: { [number]: (profile: any) -> any }

-- Construit un profil par défaut neuf à chaque appel : aucune table
-- partagée entre joueurs.
function DataSchema.newProfile(): any
	local upgrades = {}
	for levelId, bounds in pairs(LEVEL_BOUNDS) do
		upgrades[levelId] = bounds.min
	end

	local worlds = {}
	for _, worldId in ipairs(WORLD_IDS) do
		worlds[worldId] = worldId == GameConfig.StartingWorldId
	end

	local stats = {}
	for _, statId in ipairs(STAT_IDS) do
		stats[statId] = 0
	end

	return {
		schemaVersion = DataConfig.SchemaVersion,
		currencies = {
			coins = GameConfig.Currencies.Coins.startingBalance,
			gems = 0,
			stars = 0,
		},
		inventory = {
			resources = {},
		},
		upgrades = upgrades,
		worlds = worlds,
		stats = stats,
		-- Succès obtenus (T7, v2) : { [identifiant] = true }.
		achievements = {},
		-- Journal de collection (T8.6, v3) : ressources découvertes,
		-- { [identifiant de ResourceConfig] = true }. Historique : jamais
		-- retiré par une vente. Totaux et pourcentages dérivés, non stockés.
		collection = { discoveredResources = {} },
		settings = TableUtil.deepCopy(SETTING_DEFAULTS),
		lastSaveAt = 0,
	}
end

type CheckContext = {
	repair: boolean,
	repairs: { string },
	fatal: string?,
}

local function fail(context: CheckContext, message: string)
	if context.fatal == nil then
		context.fatal = message
	end
end

local function getSection(context: CheckContext, parent: any, path: string, key: string): any?
	local value = parent[key]
	if value == nil then
		table.insert(context.repairs, `{path}{key} : section manquante`)
		if not context.repair then
			return nil
		end
		value = {}
		parent[key] = value
	elseif type(value) ~= "table" then
		fail(context, `{path}{key} : table attendue, reçu {type(value)}`)
		return nil
	end
	return value
end

local function checkInteger(
	context: CheckContext,
	container: any,
	path: string,
	key: string,
	default: number,
	min: number,
	max: number
)
	local value = container[key]
	local fixed: number
	if value == nil then
		fixed = default
	elseif type(value) ~= "number" or value ~= value then
		fail(context, `{path}.{key} : entier attendu, reçu {tostring(value)} ({type(value)})`)
		return
	else
		fixed = math.clamp(math.floor(value), min, max)
	end
	if fixed ~= value then
		table.insert(context.repairs, `{path}.{key} : {tostring(value)} -> {fixed}`)
		if context.repair then
			container[key] = fixed
		end
	end
end

local function checkBoolean(context: CheckContext, container: any, path: string, key: string, default: boolean)
	local value = container[key]
	if value == nil then
		table.insert(context.repairs, `{path}.{key} : absent -> {tostring(default)}`)
		if context.repair then
			container[key] = default
		end
	elseif type(value) ~= "boolean" then
		fail(context, `{path}.{key} : booléen attendu, reçu {type(value)}`)
	end
end

-- Contrôle un profil déjà à la version courante. En mode réparation, les
-- écarts réparables sont corrigés sur place ; sinon ils sont seulement listés.
local function checkProfile(profile: any, repair: boolean): CheckContext
	local context: CheckContext = { repair = repair, repairs = {}, fatal = nil }

	if profile.schemaVersion ~= DataConfig.SchemaVersion then
		fail(context, `schemaVersion : {tostring(profile.schemaVersion)} au lieu de {DataConfig.SchemaVersion}`)
		return context
	end

	local currencies = getSection(context, profile, "", "currencies")
	if currencies then
		for _, currencyId in ipairs(CURRENCY_IDS) do
			checkInteger(context, currencies, "currencies", currencyId, 0, 0, MAX_SAFE_INTEGER)
		end
	end

	local inventory = getSection(context, profile, "", "inventory")
	if inventory then
		local resources = getSection(context, inventory, "inventory.", "resources")
		if resources then
			-- Les identifiants inconnus de ResourceConfig sont conservés :
			-- les supprimer ferait perdre des données si une ressource est
			-- retirée puis rétablie.
			for resourceId in pairs(resources) do
				if type(resourceId) ~= "string" or resourceId == "" then
					fail(context, `inventory.resources : clé invalide ({tostring(resourceId)})`)
				else
					checkInteger(context, resources, "inventory.resources", resourceId, 0, 0, MAX_SAFE_INTEGER)
				end
			end
		end
	end

	local upgrades = getSection(context, profile, "", "upgrades")
	if upgrades then
		for levelId, bounds in pairs(LEVEL_BOUNDS) do
			checkInteger(context, upgrades, "upgrades", levelId, bounds.min, bounds.min, bounds.max)
		end
	end

	local worlds = getSection(context, profile, "", "worlds")
	if worlds then
		for _, worldId in ipairs(WORLD_IDS) do
			checkBoolean(context, worlds, "worlds", worldId, worldId == GameConfig.StartingWorldId)
		end
		for worldId, unlocked in pairs(worlds) do
			if type(unlocked) ~= "boolean" then
				fail(context, `worlds.{tostring(worldId)} : booléen attendu, reçu {type(unlocked)}`)
			end
		end
		if worlds[GameConfig.StartingWorldId] == false then
			table.insert(context.repairs, `worlds.{GameConfig.StartingWorldId} : false -> true`)
			if repair then
				worlds[GameConfig.StartingWorldId] = true
			end
		end
	end

	local stats = getSection(context, profile, "", "stats")
	if stats then
		for _, statId in ipairs(STAT_IDS) do
			checkInteger(context, stats, "stats", statId, 0, 0, MAX_SAFE_INTEGER)
		end
	end

	-- Succès (v2) : identifiants inconnus d'AchievementConfig conservés
	-- (succès retiré puis rétabli) ; seule la valeur `true` est valide.
	local achievements = getSection(context, profile, "", "achievements")
	if achievements then
		for achievementId, earned in pairs(achievements) do
			if type(achievementId) ~= "string" or achievementId == "" or #achievementId > MAX_ACHIEVEMENT_ID_LENGTH then
				fail(context, `achievements : clé invalide ({tostring(achievementId)})`)
			elseif earned ~= true then
				fail(context, `achievements.{achievementId} : true attendu, reçu {tostring(earned)} ({type(earned)})`)
			end
		end
	end

	-- Journal (v3) : identifiants inconnus de ResourceConfig conservés
	-- (ressource retirée puis rétablie) mais jamais comptés ; seule la
	-- valeur `true` est valide.
	local collection = getSection(context, profile, "", "collection")
	if collection then
		local discovered = getSection(context, collection, "collection.", "discoveredResources")
		if discovered then
			for resourceId, found in pairs(discovered) do
				if type(resourceId) ~= "string" or resourceId == "" or #resourceId > MAX_DISCOVERY_ID_LENGTH then
					fail(context, `collection.discoveredResources : clé invalide ({tostring(resourceId)})`)
				elseif found ~= true then
					fail(
						context,
						`collection.discoveredResources.{resourceId} : true attendu, reçu {tostring(found)} ({type(found)})`
					)
				end
			end
		end
	end

	local settings = getSection(context, profile, "", "settings")
	if settings then
		for settingId, default in pairs(SETTING_DEFAULTS) do
			checkBoolean(context, settings, "settings", settingId, default)
		end
	end

	checkInteger(context, profile, "profil", "lastSaveAt", 0, 0, MAX_SAFE_INTEGER)

	return context
end

-- Amène `profile` de sa version à `targetVersion` par étapes successives.
-- `profile` est modifiable : passer une copie. Les paramètres `migrations`
-- et `targetVersion` existent pour tester le mécanisme sans migration réelle.
-- Retourne (profil, nil, nil) ou (nil, code, message).
function DataSchema.migrate(
	profile: any,
	migrations: { [number]: (profile: any) -> any },
	targetVersion: number
): (any?, string?, string?)
	if type(profile) ~= "table" then
		return nil, DataSchema.ErrorCode.CorruptData, `profil : table attendue, reçu {type(profile)}`
	end

	local version = profile.schemaVersion
	if type(version) ~= "number" or version % 1 ~= 0 or version < 1 then
		return nil, DataSchema.ErrorCode.CorruptData, `schemaVersion invalide ({tostring(version)})`
	end
	if version > targetVersion then
		return nil,
			DataSchema.ErrorCode.UnsupportedVersion,
			`profil en version {version}, serveur en version {targetVersion}`
	end

	while version < targetVersion do
		local step = migrations[version]
		if step == nil then
			return nil, DataSchema.ErrorCode.MigrationFailed, `aucune migration v{version} -> v{version + 1}`
		end
		local ok, migrated = pcall(step, profile)
		if not ok then
			return nil, DataSchema.ErrorCode.MigrationFailed, `migration v{version} : {tostring(migrated)}`
		end
		if type(migrated) ~= "table" or migrated.schemaVersion ~= version + 1 then
			return nil,
				DataSchema.ErrorCode.MigrationFailed,
				`migration v{version} : résultat sans schemaVersion = {version + 1}`
		end
		profile = migrated
		version += 1
	end

	return profile, nil, nil
end

-- Prépare un profil lu dans le DataStore : copie, migration, réparation.
-- Ne modifie jamais `raw`.
-- Retourne (profil, nil, nil, réparations) ou (nil, code, message, {}).
function DataSchema.normalize(raw: any): (any?, string?, string?, { string })
	local profile, code, message = DataSchema.migrate(TableUtil.deepCopy(raw), DataSchema.Migrations, DataConfig.SchemaVersion)
	if profile == nil then
		return nil, code, message, {}
	end

	local context = checkProfile(profile, true)
	if context.fatal ~= nil then
		return nil, DataSchema.ErrorCode.CorruptData, context.fatal, {}
	end
	return profile, nil, nil, context.repairs
end

-- Contrôle strict d'un profil en mémoire avant de l'accepter : aucune
-- réparation, le moindre écart est un refus. Ne modifie pas `profile`.
function DataSchema.validate(profile: any): (boolean, string?)
	if type(profile) ~= "table" then
		return false, `profil : table attendue, reçu {type(profile)}`
	end
	local context = checkProfile(profile, false)
	if context.fatal ~= nil then
		return false, context.fatal
	end
	if #context.repairs > 0 then
		return false, context.repairs[1]
	end
	return true, nil
end

return DataSchema
