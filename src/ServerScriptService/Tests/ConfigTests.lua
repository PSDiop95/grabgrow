--!strict
-- Tests de cohérence des modules de configuration.
-- Logique pure (aucune API Roblox) : exécutable dans Studio via
-- RunTests.server.lua, ou hors Studio avec un runner Luau.
--
-- Ces tests vérifient la cohérence STRUCTURELLE (types, bornes, références
-- croisées, monotonie). Ils ne recopient pas les valeurs de la Bible
-- économique, pour ne pas créer une seconde table de prix.

local ConfigTests = {}

export type Configs = {
	GameConfig: any,
	ResourceConfig: any,
	UpgradeConfig: any,
	WorldConfig: any,
}

local MVP_RESOURCE_COUNT = 3
local MVP_UPGRADE_COUNT = 2

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value > 0 and value % 1 == 0
end

local function isNonNegativeInteger(value: any): boolean
	return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function isNonEmptyString(value: any): boolean
	return type(value) == "string" and value ~= ""
end

local function count(dictionary: { [any]: any }): number
	local total = 0
	for _ in pairs(dictionary) do
		total += 1
	end
	return total
end

-- Retourne la liste des échecs (vide si tout est cohérent).
function ConfigTests.run(configs: Configs): { string }
	local failures: { string } = {}
	local function check(condition: boolean, message: string)
		if not condition then
			table.insert(failures, message)
		end
	end

	local gameConfig = configs.GameConfig
	local resources = configs.ResourceConfig
	local upgrades = configs.UpgradeConfig
	local worlds = configs.WorldConfig

	-- GameConfig
	local startingWorld = worlds[gameConfig.StartingWorldId]
	check(startingWorld ~= nil, "GameConfig.StartingWorldId absent de WorldConfig")
	check(
		startingWorld ~= nil and startingWorld.unlockedByDefault == true,
		"le monde de départ doit être débloqué par défaut"
	)
	check(gameConfig.Currencies.Coins ~= nil, "la monnaie Coins doit être définie")
	for currencyId, currency in pairs(gameConfig.Currencies) do
		check(
			isNonNegativeInteger(currency.startingBalance),
			`Currencies.{currencyId}.startingBalance doit être un entier >= 0`
		)
	end
	check(
		type(gameConfig.Collection.baseRangeStuds) == "number" and gameConfig.Collection.baseRangeStuds > 0,
		"Collection.baseRangeStuds doit être > 0"
	)
	check(
		type(gameConfig.Movement.baseWalkSpeed) == "number" and gameConfig.Movement.baseWalkSpeed > 0,
		"Movement.baseWalkSpeed doit être > 0"
	)

	-- WorldConfig
	local defaultWorldCount = 0
	for worldId, world in pairs(worlds) do
		check(isNonEmptyString(world.displayNameKey), `{worldId}.displayNameKey manquant`)
		check(isPositiveInteger(world.order), `{worldId}.order doit être un entier > 0`)
		check(isNonNegativeInteger(world.unlockCost), `{worldId}.unlockCost doit être un entier >= 0`)
		check(
			isPositiveInteger(world.requiredBackpackLevel),
			`{worldId}.requiredBackpackLevel doit être un entier > 0`
		)
		if world.unlockedByDefault then
			defaultWorldCount += 1
			check(world.unlockCost == 0, `{worldId} est débloqué par défaut mais a un coût`)
		end
	end
	check(defaultWorldCount == 1, "exactement un monde doit être débloqué par défaut")

	-- ResourceConfig
	check(
		count(resources) == MVP_RESOURCE_COUNT,
		`le MVP attend {MVP_RESOURCE_COUNT} ressources, trouvé {count(resources)}`
	)
	for resourceId, resource in pairs(resources) do
		check(isNonEmptyString(resource.displayNameKey), `{resourceId}.displayNameKey manquant`)
		check(worlds[resource.worldId] ~= nil, `{resourceId}.worldId inconnu de WorldConfig`)
		check(isNonEmptyString(resource.rarity), `{resourceId}.rarity manquant`)
		check(isPositiveInteger(resource.sellValue), `{resourceId}.sellValue doit être un entier > 0`)
		check(
			type(resource.spawnWeight) == "number" and resource.spawnWeight > 0,
			`{resourceId}.spawnWeight doit être > 0`
		)
		check(isPositiveInteger(resource.collectAmount), `{resourceId}.collectAmount doit être un entier > 0`)
		check(
			type(resource.respawnSeconds) == "number" and resource.respawnSeconds > 0,
			`{resourceId}.respawnSeconds doit être > 0`
		)
	end

	-- UpgradeConfig
	check(
		count(upgrades) == MVP_UPGRADE_COUNT,
		`le MVP attend {MVP_UPGRADE_COUNT} améliorations, trouvé {count(upgrades)}`
	)
	for upgradeId, upgrade in pairs(upgrades) do
		check(isNonEmptyString(upgrade.displayNameKey), `{upgradeId}.displayNameKey manquant`)
		check(gameConfig.Currencies[upgrade.currency] ~= nil, `{upgradeId}.currency inconnue de GameConfig`)
		check(isNonEmptyString(upgrade.stat), `{upgradeId}.stat manquant`)
		check(#upgrade.levels >= 2, `{upgradeId} doit avoir au moins 2 niveaux`)
		check(#upgrade.levels == count(upgrade.levels), `{upgradeId}.levels doit être une liste contiguë`)

		for level, entry in ipairs(upgrade.levels) do
			check(isNonNegativeInteger(entry.cost), `{upgradeId} niveau {level} : cost doit être un entier >= 0`)
			check(
				type(entry.value) == "number" and entry.value > 0,
				`{upgradeId} niveau {level} : value doit être > 0`
			)
			if level == 1 then
				check(entry.cost == 0, `{upgradeId} niveau 1 doit être gratuit`)
			else
				check(
					entry.cost > upgrade.levels[level - 1].cost,
					`{upgradeId} niveau {level} : le coût doit croître strictement`
				)
			end
		end
	end

	-- Sens de progression des statistiques : chaque niveau doit améliorer.
	local backpack = upgrades.Backpack
	check(backpack ~= nil, "UpgradeConfig.Backpack manquant")
	if backpack then
		for level = 2, #backpack.levels do
			check(
				backpack.levels[level].value > backpack.levels[level - 1].value,
				`Backpack niveau {level} : la capacité doit augmenter`
			)
			check(isPositiveInteger(backpack.levels[level].value), `Backpack niveau {level} : capacité non entière`)
		end
		for worldId, world in pairs(worlds) do
			check(
				world.requiredBackpackLevel <= #backpack.levels,
				`{worldId}.requiredBackpackLevel dépasse le niveau maximum du Backpack`
			)
		end
	end

	local grabber = upgrades.Grabber
	check(grabber ~= nil, "UpgradeConfig.Grabber manquant")
	if grabber then
		for level = 2, #grabber.levels do
			check(
				grabber.levels[level].value < grabber.levels[level - 1].value,
				`Grabber niveau {level} : l'intervalle doit diminuer`
			)
		end
	end

	return failures
end

return ConfigTests
