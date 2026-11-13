--!strict
-- Règles du guidage de première session (T5.3). Logique pure, client :
-- aucune API Roblox, aucun état.
--
-- Le guidage est un système d'interface, jamais une autorité :
--   * l'étape est déduite des statistiques persistantes envoyées par le
--     serveur (`state.progress`, miroir en lecture seule) et des niveaux
--     d'amélioration ; aucun champ de profil dédié (D-2 = b) ;
--   * une étape n'avance que sur une réponse serveur `ok == true` et
--     `code == SUCCESS` (ActionResult), jamais sur une demande du client ;
--   * l'étape ne recule jamais (maximum), donc un doublon d'événement ou un
--     état plus ancien ne change rien (idempotence).
--
-- États : INTRO -> COLLECT -> SELL -> UPGRADE -> COMPLETED. INTRO n'existe
-- qu'en session (accueil d'un joueur sans aucune collecte) : il a le même
-- rang que COLLECT et ne se termine que par `endIntro` ou une collecte.

local OnboardingConfig = require(script.Parent.Parent.Config.OnboardingConfig)
local UpgradeMath = require(script.Parent.UpgradeMath)

local OnboardingRules = {}

OnboardingRules.Step = table.freeze({
	Intro = "INTRO",
	Collect = "COLLECT",
	Sell = "SELL",
	Upgrade = "UPGRADE",
	Completed = "COMPLETED",
})

local Step = OnboardingRules.Step

local RANK: { [string]: number } = {
	[Step.Intro] = 1,
	[Step.Collect] = 1,
	[Step.Sell] = 2,
	[Step.Upgrade] = 3,
	[Step.Completed] = 4,
}

-- Numéro affiché (« Étape n / 3 »), nil pour l'accueil et la fin.
local STEP_NUMBER: { [string]: number } = {
	[Step.Collect] = 1,
	[Step.Sell] = 2,
	[Step.Upgrade] = 3,
}

-- Codes repris de Remotes.ResultCode et Remotes.Action (module partagé non
-- requis ici pour garder la logique sans dépendance réseau).
local SUCCESS = "SUCCESS"

-- Repère : "resource" | "sell" | "shop" | "cards".
export type Target = string
-- Famille d'indication de contrôle : "collect" | "sell" | "shop".
export type Controls = string
-- Appareil : "touch" | "keyboard" | "gamepad".
export type Device = string

export type Hint = {
	-- Clé de localisation du texte principal.
	key: string,
	-- Valeur de `%d` dans le texte, s'il en contient un.
	value: number?,
	-- Clé du titre (accueil seulement).
	titleKey: string?,
	-- Repère à afficher, ou nil.
	target: Target?,
	-- Famille d'indication de contrôle, ou nil.
	controls: Controls?,
	-- Numéro d'étape affiché, ou nil.
	stepNumber: number?,
}

local function isCount(value: any): boolean
	return type(value) == "number" and value == value and value >= 0
end

function OnboardingRules.isStep(value: any): boolean
	return type(value) == "string" and RANK[value] ~= nil
end

function OnboardingRules.rank(step: string): number
	return RANK[step] or 0
end

-- L'étape la plus avancée ; à rang égal, `current` est conservée.
function OnboardingRules.max(current: string, other: string): string
	if OnboardingRules.rank(other) > OnboardingRules.rank(current) then
		return other
	end
	return current
end

function OnboardingRules.stepNumber(step: string): number?
	return STEP_NUMBER[step]
end

-- Au moins une amélioration au-dessus de son niveau de départ.
local function hasUpgrade(upgrades: any): boolean
	if type(upgrades) ~= "table" then
		return false
	end
	for _, upgradeId in ipairs(UpgradeMath.ids()) do
		local level = upgrades[upgradeId]
		local start = UpgradeMath.startLevel(upgradeId)
		if type(level) == "number" and start ~= nil and level > start then
			return true
		end
	end
	return false
end

-- Étape déduite de l'état serveur (StateUpdated), ou nil si l'état ne
-- contient pas de progression lisible (le guidage reste alors masqué).
--   coinsSpent > 0 ou amélioration acquise -> COMPLETED
--   sales > 0                              -> UPGRADE
--   resourcesCollected > 0                 -> SELL
--   sinon                                  -> COLLECT
function OnboardingRules.fromState(state: any): string?
	if type(state) ~= "table" or type(state.progress) ~= "table" then
		return nil
	end
	local progress = state.progress
	if not isCount(progress.resourcesCollected) or not isCount(progress.sales) or not isCount(progress.coinsSpent) then
		return nil
	end
	if progress.coinsSpent > 0 or hasUpgrade(state.upgrades) then
		return Step.Completed
	elseif progress.sales > 0 then
		return Step.Upgrade
	elseif progress.resourcesCollected > 0 then
		return Step.Sell
	end
	return Step.Collect
end

-- Étape de départ de la session : accueil seulement pour un joueur qui
-- n'a encore rien collecté.
function OnboardingRules.initial(derived: string): string
	return if derived == Step.Collect then Step.Intro else derived
end

-- Fusion d'une étape en cours et d'une étape déduite d'un nouvel état.
function OnboardingRules.merge(current: string?, derived: string?): string?
	if derived == nil then
		return current
	elseif current == nil then
		return OnboardingRules.initial(derived)
	end
	return OnboardingRules.max(current, derived)
end

function OnboardingRules.endIntro(step: string): string
	return if step == Step.Intro then Step.Collect else step
end

-- Étape atteinte par une réponse serveur positive, ou nil.
local function reachedBy(result: any): (string?, string?)
	if type(result) ~= "table" or result.ok ~= true or result.code ~= SUCCESS then
		return nil, nil
	end
	local action = result.action
	if action == "Collect" then
		if type(result.amount) == "number" and result.amount > 0 then
			return Step.Sell, "collected"
		end
	elseif action == "Sell" then
		if type(result.coinsEarned) == "number" and result.coinsEarned > 0 then
			return Step.Upgrade, "sold"
		end
	elseif action == "Upgrade" then
		if type(result.upgradeId) == "string" and type(result.level) == "number" then
			return Step.Completed, "upgraded"
		end
	elseif action == "UnlockWorld" then
		if type(result.worldId) == "string" then
			return Step.Completed, "upgraded"
		end
	end
	return nil, nil
end

-- Étape après une réponse serveur (ActionResult). Retourne la nouvelle
-- étape et l'événement confirmé (« collected », « sold », « upgraded »)
-- seulement si l'étape avance ; sinon l'étape inchangée et nil (refus,
-- réponse illisible, doublon, étape déjà dépassée).
function OnboardingRules.afterResult(step: string, result: any): (string, string?)
	local reached, event = reachedBy(result)
	if reached == nil then
		return step, nil
	end
	local newStep = OnboardingRules.max(step, reached)
	if newStep == step then
		return step, nil
	end
	return newStep, event
end

-- Appui sur « masquer » : l'accueil passe à la première étape (carte
-- visible) ; toute autre étape est masquée sans changer de progression.
function OnboardingRules.onHide(step: string): (string, boolean)
	if step == Step.Intro then
		return Step.Collect, false
	end
	return step, true
end

-- Visibilité de la carte et du bouton « Guide ». Boutique ouverte : rien
-- (les cartes achetables sont marquées à la place).
function OnboardingRules.visibility(step: string?, hasContent: boolean, hidden: boolean, shopOpen: boolean): (boolean, boolean)
	if not hasContent or shopOpen or step == nil then
		return false, false
	end
	if hidden then
		return false, step ~= Step.Completed
	end
	return true, false
end

-- Améliorations achetables avec le solde affiché, dans l'ordre de la
-- boutique (affichage seulement : le serveur revérifie tout).
function OnboardingRules.affordable(state: any): { string }
	local list = {}
	if type(state) ~= "table" or type(state.coins) ~= "number" or type(state.upgrades) ~= "table" then
		return list
	end
	for _, upgradeId in ipairs(UpgradeMath.ids()) do
		local level = state.upgrades[upgradeId]
		local cost = if type(level) == "number" then UpgradeMath.nextCost(upgradeId, level) else nil
		if cost ~= nil and state.coins >= cost then
			table.insert(list, upgradeId)
		end
	end
	return list
end

-- Coût de l'amélioration la moins chère encore disponible, ou nil.
function OnboardingRules.cheapestCost(state: any): number?
	if type(state) ~= "table" or type(state.upgrades) ~= "table" then
		return nil
	end
	local best: number? = nil
	for _, upgradeId in ipairs(UpgradeMath.ids()) do
		local level = state.upgrades[upgradeId]
		local cost = if type(level) == "number" then UpgradeMath.nextCost(upgradeId, level) else nil
		if cost ~= nil and (best == nil or cost < best) then
			best = cost
		end
	end
	return best
end

-- Assez de ressources pour montrer la station de vente.
function OnboardingRules.readyToSell(state: any): boolean
	if type(state) ~= "table" or type(state.inventory) ~= "table" then
		return false
	end
	local used, capacity = state.inventory.used, state.inventory.capacity
	if type(used) ~= "number" or type(capacity) ~= "number" or used <= 0 then
		return false
	end
	return used >= math.min(OnboardingConfig.sellHintMinItems, capacity)
end

local function gatherOrSell(state: any): (Target, Controls)
	if OnboardingRules.readyToSell(state) then
		return "sell", "sell"
	end
	return "resource", "collect"
end

-- Indication à afficher pour `step`, ou nil (guidage terminé ou inconnu).
-- `shopOpen` : la boutique est ouverte (les cartes achetables sont
-- marquées, le texte reste masqué derrière le panneau).
function OnboardingRules.hint(step: string, state: any, shopOpen: boolean): Hint?
	local number = STEP_NUMBER[step]
	if step == Step.Intro then
		return { key = "onboarding.welcome_body", titleKey = "onboarding.welcome_title" }
	elseif step == Step.Collect then
		return { key = "onboarding.collect", target = "resource", controls = "collect", stepNumber = number }
	elseif step == Step.Sell then
		if OnboardingRules.readyToSell(state) then
			return { key = "onboarding.sell", target = "sell", controls = "sell", stepNumber = number }
		end
		return { key = "onboarding.keep_collecting", target = "resource", controls = "collect", stepNumber = number }
	elseif step == Step.Upgrade then
		if #OnboardingRules.affordable(state) > 0 then
			if shopOpen then
				return { key = "onboarding.upgrade_pick", target = "cards", stepNumber = number }
			end
			return { key = "onboarding.upgrade", target = "shop", controls = "shop", stepNumber = number }
		end
		local cheapest = OnboardingRules.cheapestCost(state)
		local coins = if type(state) == "table" and type(state.coins) == "number" then state.coins else 0
		if cheapest == nil then
			return nil
		end
		local target, controls = gatherOrSell(state)
		return {
			key = "onboarding.earn_more",
			value = math.max(cheapest - coins, 1),
			target = target,
			controls = controls,
			stepNumber = number,
		}
	end
	return nil
end

-- Famille d'appareil d'après le nom du dernier type d'entrée
-- (Enum.UserInputType.Name) ; `touchEnabled` sert de repli.
function OnboardingRules.deviceOf(inputTypeName: string?, touchEnabled: boolean): Device
	if type(inputTypeName) == "string" then
		if string.sub(inputTypeName, 1, 7) == "Gamepad" then
			return "gamepad"
		elseif inputTypeName == "Touch" then
			return "touch"
		elseif inputTypeName == "Keyboard" or string.sub(inputTypeName, 1, 5) == "Mouse" then
			return "keyboard"
		end
	end
	return if touchEnabled then "touch" else "keyboard"
end

-- Clé de l'indication de contrôle (`onboarding.ctrl.<famille>.<appareil>`).
function OnboardingRules.controlsKey(controls: Controls, device: Device): string
	return `onboarding.ctrl.{controls}.{device}`
end

return OnboardingRules
