--!strict
-- Règles des retours audio et visuels (T5.2) : quel retour produire pour
-- une réponse du serveur ou un changement d'état du sac. Logique pure,
-- sans API Roblox : testée par Lune. Le rendu (sons, particules,
-- animations) est fait par FeedbackController.
--
-- Principe : un retour positif n'existe que pour une réponse serveur
-- `ok == true` dont les champs sont cohérents. Le montant affiché d'une
-- vente est `coinsEarned` reçu du serveur, jamais une estimation locale.
-- Aucune règle de jeu ici : rien n'est décidé ni calculé pour le serveur.

local Shared = script.Parent.Parent
local AchievementConfig = require(Shared.Config.AchievementConfig)
local FeedbackConfig = require(Shared.Config.FeedbackConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Remotes = require(Shared.Remotes.Remotes)

local FeedbackRules = {}

-- `visual` : "collect" | "sell" | "upgrade" | "world" | nil (son seul).
-- `sound`  : clé de FeedbackConfig.Sounds, ou nil.
-- `key`    : clé anti-doublon. `delay` : délai avant le son (s).
export type Cue = {
	sound: string?,
	visual: string?,
	positive: boolean,
	key: string,
	delay: number,
	id: string?,
	resourceType: string?,
	amount: number?,
	level: number?,
}

export type Prefs = {
	soundEnabled: boolean,
	reducedEffects: boolean,
}

local Action = Remotes.Action
local Code = Remotes.ResultCode

-- Refus qui méritent un son discret (le message est déjà affiché par les
-- contrôleurs existants). Les autres refus restent silencieux.
local AUDIBLE_REFUSALS: { [string]: { [string]: boolean } } = {
	[Action.Sell] = { [Code.NothingToSell] = true },
	[Action.Upgrade] = { [Code.InsufficientFunds] = true, [Code.MaxLevel] = true },
	[Action.UnlockWorld] = { [Code.InsufficientFunds] = true, [Code.RequirementNotMet] = true },
}

local TIER_ORDER: { [string]: number } = { empty = 1, low = 2, filling = 3, nearly_full = 4, full = 5 }

local BAG_FULL_KEY = "bag_full"

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value > 0 and value % 1 == 0 and value < math.huge
end

local function cue(fields: { [string]: any }): Cue
	return {
		sound = fields.sound,
		visual = fields.visual,
		positive = fields.positive == true,
		key = fields.key,
		delay = fields.delay or 0,
		id = fields.id,
		resourceType = fields.resourceType,
		amount = fields.amount,
		level = fields.level,
	}
end

local function successCues(result: any): { Cue }
	local action = result.action
	if action == Action.Collect then
		local resourceType = result.resourceType
		if
			type(result.resourceId) ~= "string"
			or type(resourceType) ~= "string"
			or ResourceConfig[resourceType] == nil
			or not isPositiveInteger(result.amount)
		then
			return {}
		end
		return {
			cue({
				sound = "collect",
				visual = "collect",
				positive = true,
				key = `Collect:{result.resourceId}`,
				id = result.resourceId,
				resourceType = resourceType,
				amount = result.amount,
			}),
		}
	elseif action == Action.Sell then
		if not isPositiveInteger(result.coinsEarned) then
			return {}
		end
		return {
			cue({ sound = "sell", visual = "sell", positive = true, key = "Sell", amount = result.coinsEarned }),
			cue({
				sound = "coins",
				positive = true,
				key = "Sell:coins",
				delay = FeedbackConfig.CoinsChimeDelaySeconds,
				amount = result.coinsEarned,
			}),
		}
	elseif action == Action.Upgrade then
		local upgradeId = result.upgradeId
		if type(upgradeId) ~= "string" or UpgradeConfig[upgradeId] == nil or not isPositiveInteger(result.level) then
			return {}
		end
		return {
			cue({
				sound = "upgrade",
				visual = "upgrade",
				positive = true,
				key = `Upgrade:{upgradeId}:{result.level}`,
				id = upgradeId,
				level = result.level,
			}),
		}
	elseif action == Action.UnlockWorld then
		local worldId = result.worldId
		if type(worldId) ~= "string" or WorldConfig[worldId] == nil then
			return {}
		end
		return {
			cue({ sound = "world", visual = "world", positive = true, key = `UnlockWorld:{worldId}`, id = worldId }),
		}
	elseif action == Action.Achievement then
		-- T7 : son seul ; le message est affiché par AchievementController.
		local achievementId = result.achievementId
		if type(achievementId) ~= "string" or AchievementConfig[achievementId] == nil or not isPositiveInteger(result.coinsEarned) then
			return {}
		end
		return {
			cue({
				sound = "coins",
				positive = true,
				key = `Achievement:{achievementId}`,
				id = achievementId,
				amount = result.coinsEarned,
			}),
		}
	end
	return {}
end

-- Retours pour une réponse ActionResult du serveur. Payload illisible ou
-- incohérent : aucun retour.
function FeedbackRules.fromResult(result: any): { Cue }
	if type(result) ~= "table" or type(result.action) ~= "string" then
		return {}
	end
	if result.ok == true then
		return successCues(result)
	end
	local code = result.code
	if type(code) ~= "string" then
		return {}
	end
	if result.action == Action.Collect and code == Code.InventoryFull then
		return { cue({ sound = "bag_full", key = BAG_FULL_KEY }) }
	end
	local audible = AUDIBLE_REFUSALS[result.action]
	if audible and audible[code] then
		return { cue({ sound = "refuse", key = `{result.action}:{code}` }) }
	end
	return {}
end

-- Retours d'un changement d'état du sac (tiers de BagDisplay), seulement à
-- la hausse : entrée dans « presque plein » ou « plein ». Premier état
-- reçu (previous nil) : aucun retour.
function FeedbackRules.fromBagTier(previous: string?, current: string?): { Cue }
	if previous == nil or current == nil then
		return {}
	end
	local before, after = TIER_ORDER[previous], TIER_ORDER[current]
	if before == nil or after == nil or after <= before then
		return {}
	end
	local delay = FeedbackConfig.BagSoundDelaySeconds
	if current == "full" then
		return { cue({ sound = "bag_full", key = BAG_FULL_KEY, delay = delay }) }
	elseif current == "nearly_full" then
		return { cue({ sound = "bag_warning", key = "bag_warning", delay = delay }) }
	end
	return {}
end

-- Fenêtre anti-doublon propre à une clé (le sac plein se répète moins).
function FeedbackRules.windowFor(key: string): number
	if key == BAG_FULL_KEY then
		return FeedbackConfig.BagFullRepeatSeconds
	end
	return FeedbackConfig.DedupeWindowSeconds
end

export type Deduper = {
	accept: (self: Deduper, key: string, now: number) -> boolean,
}

-- Filtre anti-doublon : `accept` est faux si la même clé a été acceptée
-- moins de `windowFor(key)` secondes plus tôt.
function FeedbackRules.newDeduper(): Deduper
	local lastAccepted: { [string]: number } = {}
	local deduper = {}
	function deduper.accept(_self: Deduper, key: string, now: number): boolean
		local last = lastAccepted[key]
		if last ~= nil and now - last < FeedbackRules.windowFor(key) then
			return false
		end
		lastAccepted[key] = now
		-- Purge légère : les clés de collecte sont nombreuses (une par nœud).
		for other, time in pairs(lastAccepted) do
			if now - time >= FeedbackConfig.BagFullRepeatSeconds then
				lastAccepted[other] = nil
			end
		end
		lastAccepted[key] = now
		return true
	end
	return deduper :: any
end

export type Budget = {
	tryAcquire: (self: Budget) -> boolean,
	release: (self: Budget) -> (),
	active: (self: Budget) -> number,
}

-- Nombre maximal d'effets simultanés. Chaque `tryAcquire` réussi doit être
-- suivi d'un `release` à la destruction de l'effet.
function FeedbackRules.newBudget(maximum: number): Budget
	local count = 0
	local budget = {}
	function budget.tryAcquire(_self: Budget): boolean
		if count >= maximum then
			return false
		end
		count += 1
		return true
	end
	function budget.release(_self: Budget)
		count = math.max(count - 1, 0)
	end
	function budget.active(_self: Budget): number
		return count
	end
	return budget :: any
end

-- Volume final d'un son : 0 si le son est désactivé ou inconnu.
function FeedbackRules.soundVolume(soundKey: string, prefs: Prefs): number
	local definition = FeedbackConfig.Sounds[soundKey]
	if definition == nil or not prefs.soundEnabled then
		return 0
	end
	local factor = if prefs.reducedEffects then FeedbackConfig.ReducedVolumeFactor else 1
	return definition.volume * FeedbackConfig.EffectsVolume * factor
end

-- Valeur normale ou réduite selon les préférences ; un retour réduit
-- reste visible (au moins 1 pour les nombres d'éléments).
function FeedbackRules.pick(normal: number, reduced: number, prefs: Prefs): number
	if prefs.reducedEffects then
		return math.max(math.min(reduced, normal), if normal >= 1 then 1 else 0)
	end
	return normal
end

return FeedbackRules
