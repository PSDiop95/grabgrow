--!strict
-- Lecture des tables d'amélioration (T4, D-015). Logique pure, partagée :
--   * le serveur l'applique au profil autoritatif (achats, effets) ;
--   * le client l'utilise seulement pour l'affichage.
--
-- Un niveau est valide s'il est entier et compris entre startLevel et
-- maxLevel. Toute fonction reçoit un identifiant d'amélioration
-- (clé de UpgradeConfig) et retourne nil si l'entrée est invalide.

local UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)

local UpgradeMath = {}

local function entryAt(upgradeId: string, level: number): UpgradeConfig.UpgradeLevel?
	local definition = UpgradeConfig[upgradeId]
	if definition == nil or type(level) ~= "number" or level % 1 ~= 0 then
		return nil
	end
	return definition.levels[level - definition.startLevel + 1]
end

-- Identifiants dans l'ordre d'affichage.
function UpgradeMath.ids(): { string }
	local ids = {}
	for upgradeId in pairs(UpgradeConfig) do
		table.insert(ids, upgradeId)
	end
	table.sort(ids, function(a: string, b: string): boolean
		return UpgradeConfig[a].order < UpgradeConfig[b].order
	end)
	return ids
end

function UpgradeMath.startLevel(upgradeId: string): number?
	local definition = UpgradeConfig[upgradeId]
	return if definition then definition.startLevel else nil
end

function UpgradeMath.maxLevel(upgradeId: string): number?
	local definition = UpgradeConfig[upgradeId]
	return if definition then definition.startLevel + #definition.levels - 1 else nil
end

-- Statistique effective au niveau `level`.
function UpgradeMath.valueAt(upgradeId: string, level: number): number?
	local entry = entryAt(upgradeId, level)
	return if entry then entry.value else nil
end

-- Coût pour passer de `level` à `level + 1`, ou nil (niveau max ou invalide).
function UpgradeMath.nextCost(upgradeId: string, level: number): number?
	if entryAt(upgradeId, level) == nil then
		return nil
	end
	local nextEntry = entryAt(upgradeId, level + 1)
	return if nextEntry then nextEntry.cost else nil
end

-- Coût total du niveau de départ jusqu'à `level` inclus.
function UpgradeMath.cumulativeCost(upgradeId: string, level: number): number?
	local definition = UpgradeConfig[upgradeId]
	if definition == nil or entryAt(upgradeId, level) == nil then
		return nil
	end
	local total = 0
	for current = definition.startLevel + 1, level do
		total += (entryAt(upgradeId, current) :: UpgradeConfig.UpgradeLevel).cost
	end
	return total
end

-- Niveau de l'amélioration dans `profile.upgrades`, ou nil.
function UpgradeMath.levelOf(profile: any, upgradeId: string): number?
	local definition = UpgradeConfig[upgradeId]
	if definition == nil or type(profile) ~= "table" or type(profile.upgrades) ~= "table" then
		return nil
	end
	local level = profile.upgrades[definition.profileKey]
	if entryAt(upgradeId, level) == nil then
		return nil
	end
	return level
end

-- Statistique effective de l'amélioration pour un profil, ou nil.
function UpgradeMath.valueFor(profile: any, upgradeId: string): number?
	local level = UpgradeMath.levelOf(profile, upgradeId)
	return if level then UpgradeMath.valueAt(upgradeId, level) else nil
end

return UpgradeMath
