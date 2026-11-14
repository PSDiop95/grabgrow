--!strict
-- Lecture des succès (T7, D-020). Logique pure, partagée :
--   * le serveur l'applique au profil autoritatif (AchievementService) ;
--   * le client pourra l'utiliser pour l'affichage seulement.
-- Un profil illisible ne donne aucun succès.

local AchievementConfig = require(script.Parent.Parent.Config.AchievementConfig)
local UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)
local WorldConfig = require(script.Parent.Parent.Config.WorldConfig)

local AchievementRules = {}

AchievementRules.Metric = table.freeze({
	ResourcesCollected = "resourcesCollected",
	Sales = "sales",
	CoinsEarned = "coinsEarned",
	UpgradesBought = "upgradesBought",
	WorldsUnlocked = "worldsUnlocked",
})

local STAT_OF_METRIC: { [string]: string } = {
	resourcesCollected = "totalResourcesCollected",
	sales = "totalSales",
	coinsEarned = "totalCoinsEarned",
}

local function count(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	return value
end

-- Valeur de `metric` pour `profile`, ou nil si illisible.
function AchievementRules.metricValue(profile: any, metric: string): number?
	if type(profile) ~= "table" then
		return nil
	end
	local statId = STAT_OF_METRIC[metric]
	if statId ~= nil then
		return if type(profile.stats) == "table" then count(profile.stats[statId]) else nil
	elseif metric == AchievementRules.Metric.UpgradesBought then
		if type(profile.upgrades) ~= "table" then
			return nil
		end
		local total = 0
		for _, definition in pairs(UpgradeConfig) do
			local level = count(profile.upgrades[definition.profileKey])
			if level == nil then
				return nil
			end
			total += math.max(0, level - definition.startLevel)
		end
		return total
	elseif metric == AchievementRules.Metric.WorldsUnlocked then
		if type(profile.worlds) ~= "table" then
			return nil
		end
		local total = 0
		for worldId in pairs(WorldConfig) do
			if profile.worlds[worldId] == true then
				total += 1
			end
		end
		return total
	end
	return nil
end

-- Identifiants des succès atteints et non encore obtenus, dans l'ordre.
function AchievementRules.pending(profile: any): { string }
	local ids = {}
	if type(profile) ~= "table" or type(profile.achievements) ~= "table" then
		return ids
	end
	for achievementId, definition in pairs(AchievementConfig) do
		if profile.achievements[achievementId] ~= true then
			local value = AchievementRules.metricValue(profile, definition.metric)
			if value ~= nil and value >= definition.goal then
				table.insert(ids, achievementId)
			end
		end
	end
	table.sort(ids, function(a: string, b: string): boolean
		return AchievementConfig[a].order < AchievementConfig[b].order
	end)
	return ids
end

-- Tous les identifiants, dans l'ordre d'affichage.
function AchievementRules.ids(): { string }
	local ids = {}
	for achievementId in pairs(AchievementConfig) do
		table.insert(ids, achievementId)
	end
	table.sort(ids, function(a: string, b: string): boolean
		return AchievementConfig[a].order < AchievementConfig[b].order
	end)
	return ids
end

return AchievementRules
