--!strict
-- Améliorations spéciales sacrées (T10.5a, D-037, D-038). Logique pure,
-- partagée :
--   * le serveur l'applique au profil autoritatif (capacité, portée,
--     intervalle de collecte) ;
--   * le client l'utilise seulement pour l'affichage.
--
-- Acquisition (U-A) : profile.achievements["sacred_upgrade_<id>"] = true,
-- un seul niveau par amélioration (R-1). Aucune clé = non acquise. Une clé
-- d'amélioration inconnue de SacredResourceConfig est ignorée (conservée
-- par DataSchema, sans effet).

local SacredResourceConfig = require(script.Parent.Parent.Config.SacredResourceConfig)

local SacredUpgradeRules = {}

local Stat = SacredResourceConfig.Stat

function SacredUpgradeRules.key(upgradeId: string): string
	return SacredResourceConfig.UpgradePrefix .. upgradeId
end

function SacredUpgradeRules.definition(upgradeId: any): SacredResourceConfig.UpgradeDefinition?
	if type(upgradeId) ~= "string" then
		return nil
	end
	return SacredResourceConfig.Upgrades[upgradeId]
end

-- Le profil possède-t-il l'amélioration ? Lecture seule, tolérante.
function SacredUpgradeRules.owns(profile: any, upgradeId: string): boolean
	if SacredResourceConfig.Upgrades[upgradeId] == nil then
		return false
	end
	if type(profile) ~= "table" or type(profile.achievements) ~= "table" then
		return false
	end
	return profile.achievements[SacredUpgradeRules.key(upgradeId)] == true
end

-- Améliorations possédées, { [upgradeId] = true } (état client).
function SacredUpgradeRules.owned(profile: any): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	for _, upgradeId in ipairs(SacredResourceConfig.UpgradeOrder) do
		if SacredUpgradeRules.owns(profile, upgradeId) then
			owned[upgradeId] = true
		end
	end
	return owned
end

-- Applique les améliorations possédées portant sur `stat` à `base`.
local function apply(profile: any, stat: string, base: number): number
	local value = base
	for _, upgradeId in ipairs(SacredResourceConfig.UpgradeOrder) do
		local definition = SacredResourceConfig.Upgrades[upgradeId]
		if definition.stat == stat and SacredUpgradeRules.owns(profile, upgradeId) then
			if definition.add ~= nil then
				value += definition.add
			end
			if definition.multiply ~= nil then
				value *= definition.multiply
			end
		end
	end
	return value
end

-- Capacité du sac : +10 % de la capacité courante, arrondi inférieur.
function SacredUpgradeRules.capacity(profile: any, base: number): number
	return math.floor(apply(profile, Stat.Capacity, base))
end

-- Portée nominale de collecte (studs).
function SacredUpgradeRules.collectRange(profile: any, base: number): number
	return apply(profile, Stat.CollectRange, base)
end

-- Intervalle minimal entre deux collectes (secondes).
function SacredUpgradeRules.collectInterval(profile: any, base: number): number
	return apply(profile, Stat.CollectInterval, base)
end

return SacredUpgradeRules
