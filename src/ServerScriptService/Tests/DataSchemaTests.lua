--!strict
-- Tests du schéma de profil : profil par défaut, intégrité, migrations.
-- Logique pure. Les modules testés sont passés en paramètre.

local DataSchemaTests = {}

export type Modules = {
	DataSchema: any,
	DataConfig: any,
	GameConfig: any,
	UpgradeConfig: any,
	WorldConfig: any,
}

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Retourne (liste des échecs, nombre de cas exécutés).
function DataSchemaTests.run(modules: Modules): ({ string }, number)
	local DataSchema = modules.DataSchema
	local DataConfig = modules.DataConfig
	local failures: { string } = {}
	local caseCount = 0

	local function case(name: string, body: (check: (condition: boolean, message: string) -> ()) -> ())
		caseCount += 1
		local ok, err = pcall(body :: any, function(condition: boolean, message: string)
			if not condition then
				table.insert(failures, `{name} : {message}`)
			end
		end)
		if not ok then
			table.insert(failures, `{name} : erreur {tostring(err)}`)
		end
	end

	-- Profil tel qu'écrit par un serveur v1 (avant T7) : sans succès.
	local function v1Profile(): any
		local profile = DataSchema.newProfile()
		profile.schemaVersion = 1
		profile.achievements = nil
		return profile
	end

	case("nouveau profil conforme à v3", function(check)
		local profile = DataSchema.newProfile()
		check(profile.schemaVersion == 3, "schemaVersion ~= 3")
		check(DataConfig.SchemaVersion == 3, "DataConfig.SchemaVersion ~= 3")
		local valid, message = DataSchema.validate(profile)
		check(valid, `profil par défaut refusé : {tostring(message)}`)
		local normalized, _, _, repairs = DataSchema.normalize(profile)
		check(normalized ~= nil and #repairs == 0, "le profil par défaut ne doit demander aucune réparation")
		check(deepEqual(normalized, profile), "normalize modifie le profil par défaut")
	end)

	case("valeurs par défaut (D-006, D-020, D-022)", function(check)
		local profile = DataSchema.newProfile()
		local expected = {
			schemaVersion = 3,
			currencies = { coins = 0, gems = 0, stars = 0 },
			inventory = { resources = {} },
			upgrades = {
				backpackLevel = 1,
				grabberLevel = 1,
				magnetLevel = 0,
				bootsLevel = 1,
				multiplierLevel = 1,
			},
			worlds = {
				GreenValley = true,
				GoldenDesert = false,
				FrozenPeaks = false,
				MysticWorld = false,
			},
			stats = {
				totalResourcesCollected = 0,
				totalCoinsEarned = 0,
				totalCoinsSpent = 0,
				totalSales = 0,
				playTimeSeconds = 0,
			},
			achievements = {},
			collection = { discoveredResources = {} },
			settings = { musicEnabled = true, sfxEnabled = true },
			lastSaveAt = 0,
		}
		check(deepEqual(profile, expected), "le profil par défaut diffère du schéma v3 de référence")
	end)

	case("valeurs par défaut cohérentes avec les configurations", function(check)
		local profile = DataSchema.newProfile()
		check(
			profile.currencies.coins == modules.GameConfig.Currencies.Coins.startingBalance,
			"coins ~= GameConfig.Currencies.Coins.startingBalance"
		)
		check(profile.worlds[modules.GameConfig.StartingWorldId] == true, "monde de départ verrouillé")
		for worldId, world in pairs(modules.WorldConfig) do
			check(profile.worlds[worldId] ~= nil, `monde {worldId} de WorldConfig absent du schéma`)
			check(
				profile.worlds[worldId] == world.unlockedByDefault,
				`monde {worldId} : valeur par défaut différente de WorldConfig.unlockedByDefault`
			)
		end
		check(modules.UpgradeConfig.Backpack.levels[profile.upgrades.backpackLevel] ~= nil, "backpackLevel hors table")
		check(modules.UpgradeConfig.Grabber.levels[profile.upgrades.grabberLevel] ~= nil, "grabberLevel hors table")
		check(modules.UpgradeConfig.Backpack.levels[profile.upgrades.backpackLevel].cost == 0, "niveau de départ payant")
	end)

	case("copie indépendante des tables", function(check)
		local first = DataSchema.newProfile()
		first.currencies.coins = 999
		first.inventory.resources.wood = 5
		first.worlds.GoldenDesert = true
		first.settings.musicEnabled = false
		local second = DataSchema.newProfile()
		check(second.currencies.coins == 0, "coins partagés entre profils")
		check(next(second.inventory.resources) == nil, "inventaire partagé entre profils")
		check(second.worlds.GoldenDesert == false, "mondes partagés entre profils")
		check(second.settings.musicEnabled == true, "réglages partagés entre profils")
	end)

	case("normalize ne modifie pas l'entrée", function(check)
		local raw: any = { schemaVersion = 1, upgrades = { backpackLevel = 999 } }
		local normalized = DataSchema.normalize(raw)
		check(normalized ~= nil, "profil réparable refusé")
		check(raw.upgrades.backpackLevel == 999, "l'entrée a été modifiée")
		check(raw.currencies == nil, "une section a été ajoutée à l'entrée")
	end)

	case("champs manquants ajoutés, données valides préservées", function(check)
		local raw = {
			schemaVersion = 1,
			currencies = { coins = 1234 },
			inventory = { resources = { wood = 7, ancienne_ressource = 3 } },
			upgrades = { backpackLevel = 4 },
			worlds = { GreenValley = true, GoldenDesert = true },
		}
		local profile, code, _, repairs = DataSchema.normalize(raw)
		check(profile ~= nil, `refusé : {tostring(code)}`)
		if profile == nil then
			return
		end
		check(profile.currencies.coins == 1234, "coins perdus")
		check(profile.currencies.gems == 0 and profile.currencies.stars == 0, "monnaies manquantes non ajoutées")
		check(profile.inventory.resources.wood == 7, "inventaire perdu")
		check(profile.inventory.resources.ancienne_ressource == 3, "ressource inconnue supprimée")
		check(profile.upgrades.backpackLevel == 4, "niveau valide perdu")
		check(profile.upgrades.grabberLevel == 1 and profile.upgrades.magnetLevel == 0, "niveaux manquants non ajoutés")
		check(profile.worlds.GoldenDesert == true, "monde débloqué perdu")
		check(profile.worlds.FrozenPeaks == false, "monde manquant non ajouté")
		check(profile.stats.totalSales == 0, "stats manquantes non ajoutées")
		check(profile.settings.sfxEnabled == true, "réglages manquants non ajoutés")
		check(profile.lastSaveAt == 0, "lastSaveAt manquant non ajouté")
		check(#repairs > 0, "les ajouts doivent être signalés")
		local valid, message = DataSchema.validate(profile)
		check(valid, `profil réparé invalide : {tostring(message)}`)
	end)

	case("clés inconnues conservées", function(check)
		local raw = DataSchema.newProfile()
		raw.champFutur = { valeur = 1 }
		local profile = DataSchema.normalize(raw)
		check(profile ~= nil and profile.champFutur ~= nil and profile.champFutur.valeur == 1, "clé inconnue supprimée")
	end)

	case("types incorrects refusés", function(check)
		local function corrupt(mutate: (profile: any) -> ()): any
			local profile = DataSchema.newProfile()
			mutate(profile)
			return profile
		end
		local samples: { [string]: any } = {
			["profil non table"] = "texte",
			["currencies non table"] = corrupt(function(profile)
				profile.currencies = "oops"
			end),
			["coins texte"] = corrupt(function(profile)
				profile.currencies.coins = "100"
			end),
			["coins NaN"] = corrupt(function(profile)
				profile.currencies.coins = 0 / 0
			end),
			["niveau booléen"] = corrupt(function(profile)
				profile.upgrades.backpackLevel = true
			end),
			["monde nombre"] = corrupt(function(profile)
				profile.worlds.GoldenDesert = 1
			end),
			["réglage texte"] = corrupt(function(profile)
				profile.settings.musicEnabled = "oui"
			end),
			["quantité texte"] = corrupt(function(profile)
				profile.inventory.resources.wood = "beaucoup"
			end),
			["clé de ressource numérique"] = corrupt(function(profile)
				profile.inventory.resources[1] = 5
			end),
			["resources non table"] = corrupt(function(profile)
				profile.inventory.resources = 3
			end),
			["schemaVersion absent"] = corrupt(function(profile)
				profile.schemaVersion = nil
			end),
			["schemaVersion décimal"] = corrupt(function(profile)
				profile.schemaVersion = 1.5
			end),
			["schemaVersion zéro"] = corrupt(function(profile)
				profile.schemaVersion = 0
			end),
		}
		for name, sample in pairs(samples) do
			local profile, code = DataSchema.normalize(sample)
			check(profile == nil, `{name} : accepté`)
			check(code == DataSchema.ErrorCode.CorruptData, `{name} : code {tostring(code)}`)
			if type(sample) == "table" then
				check(not DataSchema.validate(sample), `{name} : validate accepte`)
			end
		end
	end)

	case("niveaux hors limites bornés", function(check)
		local raw = DataSchema.newProfile()
		local backpackMax = #modules.UpgradeConfig.Backpack.levels
		local grabberMax = #modules.UpgradeConfig.Grabber.levels
		raw.upgrades.backpackLevel = backpackMax + 50
		raw.upgrades.grabberLevel = 0
		raw.upgrades.magnetLevel = -3
		raw.upgrades.bootsLevel = 2.7
		raw.upgrades.multiplierLevel = #modules.UpgradeConfig.Multiplier.levels + 1
		local profile, _, _, repairs = DataSchema.normalize(raw)
		check(profile ~= nil, "refusé")
		if profile == nil then
			return
		end
		check(profile.upgrades.backpackLevel == backpackMax, "backpackLevel non borné au maximum")
		check(profile.upgrades.grabberLevel == 1, "grabberLevel non borné au minimum")
		check(profile.upgrades.magnetLevel == 0, "magnetLevel non borné à 0")
		check(profile.upgrades.bootsLevel == 2, "bootsLevel décimal non arrondi")
		check(
			profile.upgrades.multiplierLevel == #modules.UpgradeConfig.Multiplier.levels,
			"multiplierLevel non borné"
		)
		check(grabberMax >= 1 and #repairs == 5, `5 réparations attendues, trouvé {#repairs}`)
		check(not DataSchema.validate(raw), "validate doit refuser un niveau hors limites")
	end)

	-- D-015 : le Magnet s'arrête au niveau 9 (ancienne borne : 10).
	case("magnetLevel 10 (ancienne borne) ramené à 9", function(check)
		local raw = DataSchema.newProfile()
		raw.upgrades.magnetLevel = 10
		local profile = DataSchema.normalize(raw)
		check(profile ~= nil and profile.upgrades.magnetLevel == 9, "magnetLevel non borné à 9")
		raw.upgrades.magnetLevel = 9
		check(DataSchema.validate(raw), "magnetLevel 9 doit être valide")
	end)

	case("valeurs numériques invalides bornées", function(check)
		local raw = DataSchema.newProfile()
		raw.currencies.coins = -50
		raw.currencies.gems = 12.9
		raw.inventory.resources.wood = -1
		raw.stats.totalSales = -4
		raw.worlds.GreenValley = false
		raw.lastSaveAt = -10
		local profile = DataSchema.normalize(raw)
		check(profile ~= nil, "refusé")
		if profile == nil then
			return
		end
		check(profile.currencies.coins == 0, "solde négatif conservé")
		check(profile.currencies.gems == 12, "solde décimal conservé")
		check(profile.inventory.resources.wood == 0, "quantité négative conservée")
		check(profile.stats.totalSales == 0, "statistique négative conservée")
		check(profile.worlds.GreenValley == true, "monde de départ verrouillé")
		check(profile.lastSaveAt == 0, "lastSaveAt négatif conservé")
		check(not DataSchema.validate(raw), "validate doit refuser un solde négatif")
	end)

	case("version future refusée", function(check)
		local raw = DataSchema.newProfile()
		raw.schemaVersion = DataConfig.SchemaVersion + 1
		raw.currencies.coins = 777
		local profile, code = DataSchema.normalize(raw)
		check(profile == nil, "version future acceptée")
		check(code == DataSchema.ErrorCode.UnsupportedVersion, `code {tostring(code)}`)
		check(raw.currencies.coins == 777, "l'entrée a été modifiée")
		check(not DataSchema.validate(raw), "validate accepte une version future")
	end)

	-- MIGRATION RÉELLE v1 -> v2 (T7, D-020) ------------------------------

	case("migrations réelles : v1 -> v2 et v2 -> v3", function(check)
		local count = 0
		for version in pairs(DataSchema.Migrations) do
			count += 1
			check(version == 1 or version == 2, `migration inattendue depuis v{tostring(version)}`)
		end
		check(count == 2, `2 migrations attendues, trouvé {count}`)
	end)

	case("v1 -> v2 : succès vides, toutes les données conservées", function(check)
		local raw = v1Profile()
		raw.currencies.coins = 4321
		raw.inventory.resources.wood = 17
		raw.inventory.resources.ancienne_ressource = 2
		raw.upgrades.backpackLevel = 6
		raw.upgrades.magnetLevel = 3
		raw.worlds.GoldenDesert = true
		raw.stats.totalResourcesCollected = 5000
		raw.stats.totalCoinsEarned = 9000
		raw.stats.totalCoinsSpent = 4679
		raw.stats.totalSales = 70
		raw.stats.playTimeSeconds = 3600
		raw.settings.musicEnabled = false
		raw.lastSaveAt = 1_700_000_000
		raw.champFutur = { valeur = 1 }

		local profile, code, message, repairs = DataSchema.normalize(raw)
		check(profile ~= nil, `refusé : {tostring(code)} {tostring(message)}`)
		if profile == nil then
			return
		end
		-- v1 -> v2 -> v3 enchaînées (T8.6).
		check(profile.schemaVersion == 3, "version finale incorrecte")
		check(type(profile.achievements) == "table" and next(profile.achievements) == nil, "succès non vides")
		check(next(profile.collection.discoveredResources) == nil, "journal non vide")
		check(#repairs == 0, `aucune réparation attendue, trouvé {#repairs}`)
		check(raw.schemaVersion == 1 and raw.achievements == nil, "l'entrée a été modifiée")
		-- Toutes les autres sections : identiques.
		for key, value in pairs(raw) do
			if key ~= "schemaVersion" then
				check(deepEqual(profile[key], value), `section {key} modifiée par la migration`)
			end
		end
		check(DataSchema.validate(profile), "profil migré invalide")
	end)

	case("v1 -> v2 : section achievements déjà présente conservée", function(check)
		local raw = v1Profile()
		raw.achievements = { collect_100 = true }
		local profile = DataSchema.normalize(raw)
		check(profile ~= nil and profile.achievements.collect_100 == true, "succès existant perdu")
	end)

	case("v2 : succès invalides refusés, inconnus conservés", function(check)
		local unknown = DataSchema.newProfile()
		unknown.achievements.ancien_succes = true
		local kept = DataSchema.normalize(unknown)
		check(kept ~= nil and kept.achievements.ancien_succes == true, "succès inconnu supprimé")

		local samples: { [string]: (profile: any) -> () } = {
			["achievements non table"] = function(profile)
				profile.achievements = true
			end,
			["valeur false"] = function(profile)
				profile.achievements.collect_100 = false
			end,
			["valeur nombre"] = function(profile)
				profile.achievements.collect_100 = 1
			end,
			["clé numérique"] = function(profile)
				profile.achievements[1] = true
			end,
			["clé vide"] = function(profile)
				profile.achievements[""] = true
			end,
			["clé trop longue"] = function(profile)
				profile.achievements[string.rep("a", 65)] = true
			end,
		}
		for name, mutate in pairs(samples) do
			local profile = DataSchema.newProfile()
			mutate(profile)
			local normalized, code = DataSchema.normalize(profile)
			check(normalized == nil and code == DataSchema.ErrorCode.CorruptData, `{name} : {tostring(code)}`)
			check(not DataSchema.validate(profile), `{name} : validate accepte`)
		end
	end)

	case("v2 : section achievements absente ajoutée", function(check)
		local raw = DataSchema.newProfile()
		raw.achievements = nil
		local profile, _, _, repairs = DataSchema.normalize(raw)
		check(profile ~= nil and type(profile.achievements) == "table", "section non ajoutée")
		check(#repairs == 1, "ajout non signalé")
		check(not DataSchema.validate(raw), "validate accepte un profil sans achievements")
	end)

	-- Mécanisme de migration, exercé avec des migrations de test.
	local testMigrations = {
		[1] = function(profile: any): any
			profile.schemaVersion = 2
			profile.pets = {}
			return profile
		end,
		[2] = function(profile: any): any
			profile.schemaVersion = 3
			profile.currencies.tickets = 0
			return profile
		end,
	}

	case("migration : profil déjà à jour inchangé", function(check)
		local raw = v1Profile()
		raw.currencies.coins = 42
		local migrated, code = DataSchema.migrate(raw, {}, 1)
		check(migrated ~= nil, `refusé : {tostring(code)}`)
		check(migrated ~= nil and migrated.currencies.coins == 42 and migrated.schemaVersion == 1, "profil modifié")
	end)

	case("migration : v1 -> v2 -> v3 conserve les données", function(check)
		local raw = v1Profile()
		raw.currencies.coins = 4200
		raw.inventory.resources.stone = 9
		raw.upgrades.backpackLevel = 6
		local migrated, code, message = DataSchema.migrate(raw, testMigrations, 3)
		check(migrated ~= nil, `refusé : {tostring(code)} {tostring(message)}`)
		if migrated == nil then
			return
		end
		check(migrated.schemaVersion == 3, "version finale incorrecte")
		check(migrated.pets ~= nil, "étape v1 -> v2 non appliquée")
		check(migrated.currencies.tickets == 0, "étape v2 -> v3 non appliquée")
		check(migrated.currencies.coins == 4200, "coins perdus")
		check(migrated.inventory.resources.stone == 9, "inventaire perdu")
		check(migrated.upgrades.backpackLevel == 6, "niveau perdu")
	end)

	case("migration : étape manquante refusée", function(check)
		local migrated, code = DataSchema.migrate(v1Profile(), { [2] = testMigrations[2] }, 3)
		check(migrated == nil and code == DataSchema.ErrorCode.MigrationFailed, `code {tostring(code)}`)
	end)

	case("migration : étape en erreur ou incohérente refusée", function(check)
		local failing = {
			[1] = function(_profile: any): any
				error("panne")
			end,
		}
		local migrated, code = DataSchema.migrate(v1Profile(), failing, 2)
		check(migrated == nil and code == DataSchema.ErrorCode.MigrationFailed, `erreur : code {tostring(code)}`)

		local forgetful = {
			[1] = function(profile: any): any
				return profile -- schemaVersion non mis à jour
			end,
		}
		migrated, code = DataSchema.migrate(v1Profile(), forgetful, 2)
		check(migrated == nil and code == DataSchema.ErrorCode.MigrationFailed, `oubli : code {tostring(code)}`)
	end)

	case("migration : version future refusée", function(check)
		local raw = DataSchema.newProfile()
		raw.schemaVersion = 4
		local migrated, code = DataSchema.migrate(raw, testMigrations, 3)
		check(migrated == nil and code == DataSchema.ErrorCode.UnsupportedVersion, `code {tostring(code)}`)
	end)

	return failures, caseCount
end

return DataSchemaTests
