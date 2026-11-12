--!strict
-- Présentation du sac dans le HUD (T5.1) : état visuel déduit de
-- l'occupation et de la capacité reçues du serveur.
--
-- Affichage seulement : `used` et `capacity` viennent de l'état serveur
-- (InventoryService ; capacité = niveau Backpack, ressources inconnues
-- comprises dans `used`). Ce module ne calcule ni n'invente aucune
-- capacité. Logique pure, sans API Roblox : testée par Lune.
--
-- États :
--   * empty       : sac vide            -> pastille compacte ;
--   * low         : moins de 25 %       -> pastille compacte ;
--   * filling     : 25 % à moins de 80 % -> barre, couleur vert -> jaune ;
--   * nearly_full : 80 % à moins de 100 % -> barre orange, « Presque plein » ;
--   * full        : used >= capacity     -> barre rouge, « Sac plein ! »,
--                                           invitation à vendre.
-- Seuils et couleurs : paramètres d'interface (hypothèses de lisibilité, à
-- valider sur appareil), sans effet sur le jeu.

local BagDisplay = {}

BagDisplay.COMPACT_BELOW = 0.25
BagDisplay.NEARLY_FULL_FROM = 0.8

export type Tier = "empty" | "low" | "filling" | "nearly_full" | "full"
export type Rgb = { r: number, g: number, b: number }

export type View = {
	tier: Tier,
	-- Remplissage affiché, borné à [0, 1].
	ratio: number,
	-- Pastille (true) ou barre complète (false).
	compact: boolean,
	-- Couleur du remplissage (0-255).
	fill: Rgb,
	-- Mot d'état devant le compteur (nil : compteur seul).
	labelKey: string?,
	-- Ligne d'invitation à la place du détail (nil : détail des ressources).
	hintKey: string?,
	-- État d'alerte (contour renforcé, impulsion à l'entrée).
	alert: boolean,
}

local GREEN: Rgb = table.freeze({ r = 96, g = 204, b = 78 })
local YELLOW: Rgb = table.freeze({ r = 242, g = 196, b = 56 })
local ORANGE: Rgb = table.freeze({ r = 245, g = 138, b = 52 })
local RED: Rgb = table.freeze({ r = 230, g = 80, b = 70 })
BagDisplay.Colors = table.freeze({ green = GREEN, yellow = YELLOW, orange = ORANGE, red = RED })

local function lerp(a: Rgb, b: Rgb, t: number): Rgb
	local k = math.clamp(t, 0, 1)
	return {
		r = math.floor(a.r + (b.r - a.r) * k + 0.5),
		g = math.floor(a.g + (b.g - a.g) * k + 0.5),
		b = math.floor(a.b + (b.b - a.b) * k + 0.5),
	}
end

local function isNumber(value: any): boolean
	return type(value) == "number" and value == value
end

-- Vue du sac pour `used` unités sur `capacity`. Valeurs illisibles : sac
-- vide. Même règle « plein » que InventoryController.isFull (used >= capacity).
function BagDisplay.view(used: number, capacity: number): View
	local safeUsed = if isNumber(used) then math.max(used, 0) else 0
	local safeCapacity = if isNumber(capacity) then math.max(capacity, 0) else 0

	if safeCapacity <= 0 then
		-- Capacité inconnue : jamais envoyée par le serveur ; rien d'inventé.
		return {
			tier = "empty",
			ratio = 0,
			compact = true,
			fill = GREEN,
			labelKey = nil,
			hintKey = nil,
			alert = false,
		}
	end

	local ratio = math.clamp(safeUsed / safeCapacity, 0, 1)
	if safeUsed >= safeCapacity then
		return {
			tier = "full",
			ratio = 1,
			compact = false,
			fill = RED,
			labelKey = "hud.bag_full",
			hintKey = "hud.sell_hint",
			alert = true,
		}
	elseif ratio >= BagDisplay.NEARLY_FULL_FROM then
		return {
			tier = "nearly_full",
			ratio = ratio,
			compact = false,
			fill = ORANGE,
			labelKey = "hud.bag_almost_full",
			hintKey = nil,
			alert = true,
		}
	end

	local tier: Tier = if safeUsed <= 0
		then "empty"
		elseif ratio < BagDisplay.COMPACT_BELOW then "low"
		else "filling"
	return {
		tier = tier,
		ratio = ratio,
		compact = tier ~= "filling",
		fill = lerp(GREEN, YELLOW, ratio / BagDisplay.NEARLY_FULL_FROM),
		labelKey = nil,
		hintKey = nil,
		alert = false,
	}
end

-- Clés de localisation utilisées par l'affichage du sac (contrôlées par
-- les tests dans chaque langue).
BagDisplay.KEYS = table.freeze({ "hud.bag", "hud.bag_full", "hud.bag_almost_full", "hud.sell_hint" })

return BagDisplay
