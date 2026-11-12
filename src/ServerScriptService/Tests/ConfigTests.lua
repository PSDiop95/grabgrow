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
	-- T2 : paramètres de sécurité de la collecte et textes d'interface.
	CollectionSecurityConfig: any,
	-- T3 : paramètres de sécurité de la vente.
	SellSecurityConfig: any,
	-- T4 : paramètres de sécurité des achats (améliorations, mondes).
	EconomySecurityConfig: any,
	Localization: any,
}

local MVP_RESOURCE_COUNT = 3
-- T4 (D-015) : les cinq améliorations et les quatre mondes de la Bible.
local MVP_UPGRADE_COUNT = 5
local WORLD_COUNT = 4

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
	-- Portée et vitesse de base vivent dans UpgradeConfig (D-015).
	check(gameConfig.Collection == nil, "GameConfig.Collection dupliquerait UpgradeConfig.Magnet")
	check(gameConfig.Movement == nil, "GameConfig.Movement dupliquerait UpgradeConfig.Boots")

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
	check(count(worlds) == WORLD_COUNT, `{WORLD_COUNT} mondes attendus, trouvé {count(worlds)}`)
	-- Ordre strict (D-015) : ordres 1..n contigus, uniques.
	local seenOrders: { [number]: string } = {}
	for worldId, world in pairs(worlds) do
		check(seenOrders[world.order] == nil, `{worldId}.order en double`)
		seenOrders[world.order] = worldId
	end
	for order = 1, count(worlds) do
		check(seenOrders[order] ~= nil, `aucun monde d'ordre {order}`)
	end
	if startingWorld ~= nil then
		check(startingWorld.order == 1, "le monde de départ doit être d'ordre 1")
	end

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
	local seenProfileKeys: { [string]: boolean } = {}
	local seenUpgradeOrders: { [number]: boolean } = {}
	for upgradeId, upgrade in pairs(upgrades) do
		check(isNonEmptyString(upgrade.displayNameKey), `{upgradeId}.displayNameKey manquant`)
		check(isNonEmptyString(upgrade.profileKey), `{upgradeId}.profileKey manquant`)
		check(not seenProfileKeys[upgrade.profileKey], `{upgradeId}.profileKey en double`)
		seenProfileKeys[upgrade.profileKey] = true
		check(isPositiveInteger(upgrade.order), `{upgradeId}.order doit être un entier > 0`)
		check(not seenUpgradeOrders[upgrade.order], `{upgradeId}.order en double`)
		seenUpgradeOrders[upgrade.order] = true
		check(isNonNegativeInteger(upgrade.startLevel), `{upgradeId}.startLevel doit être un entier >= 0`)
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
				check(entry.cost == 0, `{upgradeId} niveau de départ doit être gratuit`)
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

	-- Magnet, Boots, Multiplier : statistique strictement croissante.
	for _, upgradeId in ipairs({ "Magnet", "Boots", "Multiplier" }) do
		local upgrade = upgrades[upgradeId]
		check(upgrade ~= nil, `UpgradeConfig.{upgradeId} manquant`)
		if upgrade then
			for index = 2, #upgrade.levels do
				check(
					upgrade.levels[index].value > upgrade.levels[index - 1].value,
					`{upgradeId} entrée {index} : la statistique doit augmenter`
				)
			end
		end
	end
	-- D-006 / D-015 : Magnet démarre au niveau 0 (non acquis), les autres à 1.
	check(upgrades.Magnet ~= nil and upgrades.Magnet.startLevel == 0, "Magnet.startLevel doit valoir 0 (D-006)")
	for _, upgradeId in ipairs({ "Backpack", "Grabber", "Boots", "Multiplier" }) do
		check(upgrades[upgradeId] ~= nil and upgrades[upgradeId].startLevel == 1, `{upgradeId}.startLevel doit valoir 1`)
	end
	-- Multiplier : centièmes exacts, départ x1, plafond global respecté.
	local multiplier = upgrades.Multiplier
	if multiplier then
		check(multiplier.levels[1].value == 1, "Multiplier de départ doit valoir x1")
		for index, entry in ipairs(multiplier.levels) do
			local hundredths = entry.value * 100
			check(
				math.abs(hundredths - math.floor(hundredths + 0.5)) < 1e-9,
				`Multiplier entrée {index} : valeur non exprimable en centièmes`
			)
			check(
				entry.value <= gameConfig.Selling.maxSellMultiplier,
				`Multiplier entrée {index} : dépasse Selling.maxSellMultiplier`
			)
		end
	end

	-- CollectionSecurityConfig (T2, hypothèses de départ : cohérence seulement)
	local security = configs.CollectionSecurityConfig
	local grabberLevels = upgrades.Grabber.levels
	local fastestInterval = grabberLevels[#grabberLevels].value
	check(
		type(security.Distance.toleranceStuds) == "number" and security.Distance.toleranceStuds >= 0,
		"Distance.toleranceStuds doit être >= 0"
	)
	check(
		security.Distance.toleranceStuds < upgrades.Magnet.levels[1].value,
		"la tolérance de distance doit rester inférieure à la portée nominale"
	)
	check(
		security.Cooldown.jitterToleranceSeconds >= 0 and security.Cooldown.jitterToleranceSeconds < fastestInterval,
		"Cooldown.jitterToleranceSeconds doit être >= 0 et inférieur au plus petit intervalle du Grabber"
	)
	check(security.Travel.speedFactor >= 1, "Travel.speedFactor doit être >= 1")
	check(security.Travel.slackStuds >= 0, "Travel.slackStuds doit être >= 0")
	local collectLimit = security.RateLimits.Collect
	check(collectLimit ~= nil, "RateLimits.Collect doit être défini")
	if collectLimit ~= nil then
		check(isPositiveInteger(collectLimit.burst), "RateLimits.Collect.burst doit être un entier > 0")
		-- Un joueur honnête au Grabber maximal ne doit jamais être limité.
		check(
			collectLimit.refillPerSecond > 1 / fastestInterval,
			"RateLimits.Collect.refillPerSecond doit dépasser la cadence légitime maximale"
		)
	end
	check(isPositiveInteger(security.RateLimitFeedback.logEveryRejections), "logEveryRejections doit être un entier > 0")
	check(isPositiveInteger(security.Payload.maxResourceIdLength), "maxResourceIdLength doit être un entier > 0")

	-- Vente (T3) : distance nominale et marges serveur, hypothèses de départ.
	check(
		type(gameConfig.Selling) == "table" and isPositiveInteger(gameConfig.Selling.interactRangeStuds),
		"GameConfig.Selling.interactRangeStuds doit être un entier > 0"
	)
	check(
		type(gameConfig.Selling) == "table"
			and type(gameConfig.Selling.maxSellMultiplier) == "number"
			and gameConfig.Selling.maxSellMultiplier >= 1,
		"GameConfig.Selling.maxSellMultiplier doit être >= 1"
	)
	-- T4 : paramètres de sécurité des achats.
	local economySecurity = configs.EconomySecurityConfig
	check(economySecurity ~= nil, "EconomySecurityConfig manquant")
	if economySecurity ~= nil then
		for _, action in ipairs({ "Upgrade", "UnlockWorld" }) do
			local limit = economySecurity.RateLimits[action]
			check(
				limit ~= nil and isPositiveInteger(limit.burst) and limit.refillPerSecond > 0,
				`EconomySecurityConfig.RateLimits.{action} invalide`
			)
		end
		check(isPositiveInteger(economySecurity.RateLimitFeedback.logEveryRejections), "Economy logEveryRejections doit être un entier > 0")
		check(isPositiveInteger(economySecurity.Payload.maxIdLength), "Economy maxIdLength doit être un entier > 0")
	end
	local sellSecurity = configs.SellSecurityConfig
	check(sellSecurity ~= nil, "SellSecurityConfig manquant")
	if sellSecurity ~= nil and type(gameConfig.Selling) == "table" then
		check(
			sellSecurity.Distance.toleranceStuds >= 0
				and sellSecurity.Distance.toleranceStuds < gameConfig.Selling.interactRangeStuds,
			"SellSecurityConfig.Distance.toleranceStuds doit être >= 0 et inférieur à la distance nominale"
		)
		local sellLimit = sellSecurity.RateLimits.Sell
		check(
			sellLimit ~= nil and isPositiveInteger(sellLimit.burst) and sellLimit.refillPerSecond > 0,
			"SellSecurityConfig.RateLimits.Sell invalide"
		)
		check(isPositiveInteger(sellSecurity.RateLimitFeedback.logEveryRejections), "Sell logEveryRejections doit être un entier > 0")
		check(isPositiveInteger(sellSecurity.Payload.maxSellZoneIdLength), "maxSellZoneIdLength doit être un entier > 0")
	end
	-- Toute ressource configurée doit être vendable (prix entier >= 1).
	for resourceId, resource in pairs(resources) do
		check(isPositiveInteger(resource.sellValue), `{resourceId}.sellValue doit être un entier >= 1`)
	end

	-- Localization : chaque nom de ressource existe dans chaque langue.
	local localization = configs.Localization
	for _, language in ipairs(localization.languages()) do
		for resourceId, resource in pairs(resources) do
			check(
				localization.has(resource.displayNameKey, language),
				`texte manquant ({language}) pour la ressource {resourceId}`
			)
		end
	end

	-- Textes d'interface utilisés par les contrôleurs, dans chaque langue.
	local uiKeys = {
		"hud.bag", "hud.bag_full", "collect.action", "collect.too_far",
		"hud.coins", "hud.sell_value", "sell.action", "sell.station", "sell.estimate",
		"sell.gain", "sell.empty", "sell.nothing", "sell.too_far", "sell.failed", "sell.go_sell",
		-- T4 : boutique et mondes.
		"shop.open", "shop.title", "shop.close", "shop.level", "shop.max", "shop.price", "shop.need",
		"shop.pending", "shop.bought", "shop.failed", "shop.insufficient", "shop.max_reached",
		"shop.worlds", "hud.worlds", "world.unlocked", "world.locked", "world.requires_backpack",
		"world.requires_previous", "world.unlock", "world.confirm", "world.unlocked_toast",
		"world.coming_soon", "world.failed",
		-- T5.1 : états du sac.
		"hud.bag_almost_full", "hud.sell_hint",
	}
	-- Noms des améliorations et des mondes.
	for _, language in ipairs(localization.languages()) do
		for upgradeId, upgrade in pairs(upgrades) do
			check(localization.has(upgrade.displayNameKey, language), `texte manquant ({language}) : {upgradeId}`)
			-- Message d'achat « avant → après » (A-40).
			local gainKey = `{upgrade.displayNameKey}.gain`
			check(localization.has(gainKey, language), `texte manquant ({language}) : {gainKey}`)
			local filled = localization.fill(gainKey, language, { from = "1", to = "2" })
			check(
				string.find(filled, "1", 1, true) ~= nil and string.find(filled, "2", 1, true) ~= nil and string.find(filled, "{", 1, true) == nil,
				`motifs from/to incomplets ({language}) : {gainKey}`
			)
		end
		for worldId, world in pairs(worlds) do
			check(localization.has(world.displayNameKey, language), `texte manquant ({language}) : {worldId}`)
		end
	end
	for _, language in ipairs(localization.languages()) do
		for _, key in ipairs(uiKeys) do
			check(localization.has(key, language), `texte manquant ({language}) : {key}`)
		end
	end

	return failures
end

return ConfigTests
