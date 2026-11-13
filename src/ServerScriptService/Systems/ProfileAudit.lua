--!strict
-- Contrôle de cohérence d'un profil chargé (T6, D-019).
--
-- LECTURE SEULE : retourne une liste de constats, destinée au journal de
-- sécurité. Aucune correction, suppression ni modification du profil.
--
-- Sources légitimes de Coins hors ventes, à connaître avant de conclure :
--   * préréglages de test Studio (StudioTestPresets) : fixent solde,
--     niveaux et mondes sans passer par les ventes ni les achats -> des
--     constats sont ATTENDUS sur un profil de test Studio ;
--   * aucune autre source en production au 2026-11-13 (ni récompense, ni
--     achat Robux) ; toute future source devra alimenter
--     stats.totalCoinsEarned ou être ajoutée ici.
-- Un constat est donc un signal à examiner, jamais une preuve de triche.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local UpgradeMath = require(ReplicatedStorage.Shared.Util.UpgradeMath)
local InventoryService = require(script.Parent.Parent.Services.InventoryService)

local ProfileAudit = {}

ProfileAudit.Check = table.freeze({
	-- solde + dépensé > gagné : Coins sans origine connue.
	CoinsUnexplained = "coins_unexplained",
	-- solde + dépensé < gagné : Coins disparus.
	CoinsMissing = "coins_missing",
	-- coût cumulé des niveaux et mondes > total dépensé.
	UnpaidProgress = "unpaid_progress",
	-- sac au-delà de sa capacité.
	InventoryOverCapacity = "inventory_over_capacity",
	-- plus d'unités dans le sac que jamais collectées.
	InventoryExceedsCollected = "inventory_exceeds_collected",
	-- monde débloqué sans le précédent ou sans le niveau de Backpack requis.
	WorldRequirement = "world_requirement",
	-- profil illisible pour l'audit.
	Unreadable = "unreadable",
})

export type Issue = { check: string, [string]: any }

local function number(value: any): number?
	return if type(value) == "number" and value == value then value else nil
end

function ProfileAudit.run(profile: any): { Issue }
	local Check = ProfileAudit.Check
	local issues: { Issue } = {}
	if type(profile) ~= "table" or type(profile.currencies) ~= "table" or type(profile.stats) ~= "table" then
		return { { check = Check.Unreadable } }
	end

	local coins = number(profile.currencies.coins)
	local earned = number(profile.stats.totalCoinsEarned)
	local spent = number(profile.stats.totalCoinsSpent)
	local collected = number(profile.stats.totalResourcesCollected)
	if coins == nil or earned == nil or spent == nil or collected == nil then
		return { { check = Check.Unreadable } }
	end

	local balanceGap = coins + spent - earned
	if balanceGap > 0 then
		table.insert(issues, { check = Check.CoinsUnexplained, excess = balanceGap })
	elseif balanceGap < 0 then
		table.insert(issues, { check = Check.CoinsMissing, deficit = -balanceGap })
	end

	-- Coût minimal de la progression actuelle.
	local required = 0
	for _, upgradeId in ipairs(UpgradeMath.ids()) do
		local level = UpgradeMath.levelOf(profile, upgradeId)
		local cost = if level then UpgradeMath.cumulativeCost(upgradeId, level) else nil
		if cost == nil then
			return { { check = Check.Unreadable, field = upgradeId } }
		end
		required += cost
	end
	local worlds = if type(profile.worlds) == "table" then profile.worlds else {}
	for worldId, world in pairs(WorldConfig) do
		if worlds[worldId] == true and not world.unlockedByDefault then
			required += world.unlockCost
			local backpackLevel = UpgradeMath.levelOf(profile, "Backpack") or 0
			local previousUnlocked = true
			for otherId, other in pairs(WorldConfig) do
				if other.order == world.order - 1 then
					previousUnlocked = worlds[otherId] == true or other.unlockedByDefault
				end
			end
			if not previousUnlocked or backpackLevel < world.requiredBackpackLevel then
				table.insert(issues, { check = Check.WorldRequirement, world = worldId })
			end
		end
	end
	if required > spent then
		table.insert(issues, { check = Check.UnpaidProgress, missing = required - spent })
	end

	local ok, state = pcall(InventoryService.describe, profile)
	if ok and state ~= nil then
		if state.used > state.capacity then
			table.insert(issues, { check = Check.InventoryOverCapacity, used = state.used, capacity = state.capacity })
		end
		if state.used > collected then
			table.insert(issues, { check = Check.InventoryExceedsCollected, used = state.used, collected = collected })
		end
	else
		table.insert(issues, { check = Check.Unreadable, field = "inventory" })
	end

	return issues
end

return ProfileAudit
