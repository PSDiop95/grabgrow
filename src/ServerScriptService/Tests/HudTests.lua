--!strict
-- Tests du HUD (T5.1) : états du sac (BagDisplay) à partir de l'état
-- serveur (InventoryService.describe), textes EN/FR. Logique pure : aucune
-- API Roblox. Le rendu des contrôleurs client se vérifie dans Studio.

local HudTests = {}

export type Modules = {
	BagDisplay: any,
	InventoryService: any,
	DataSchema: any,
	UpgradeMath: any,
	Localization: any,
}

-- Longueur maximale d'un texte d'état du sac (débordement sur téléphone).
local MAX_STATE_TEXT_LENGTH = 20

local TIER_ORDER = { empty = 1, low = 2, filling = 3, nearly_full = 4, full = 5 }

function HudTests.run(modules: Modules): ({ string }, number)
	local BagDisplay = modules.BagDisplay
	local InventoryService = modules.InventoryService
	local DataSchema = modules.DataSchema
	local UpgradeMath = modules.UpgradeMath
	local Localization = modules.Localization

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

	local function sameRgb(a: any, b: any): boolean
		return a.r == b.r and a.g == b.g and a.b == b.b
	end

	-- État du sac tel que le serveur l'envoie, pour un profil donné.
	local function serverBag(resources: { [string]: number }, backpackLevel: number): any
		local profile = DataSchema.newProfile()
		profile.upgrades.backpackLevel = backpackLevel
		for resourceId, quantity in pairs(resources) do
			profile.inventory.resources[resourceId] = quantity
		end
		return InventoryService.describe(profile)
	end

	local baseCapacity = UpgradeMath.valueAt("Backpack", 1)
	local Colors = BagDisplay.Colors

	case("sac vide", function(check)
		local view = BagDisplay.view(0, baseCapacity)
		check(view.tier == "empty", `état {view.tier}`)
		check(view.compact == true, "pastille attendue")
		check(view.ratio == 0, "remplissage non nul")
		check(view.alert == false and view.labelKey == nil and view.hintKey == nil, "alerte sur sac vide")
	end)

	case("sac presque vide : pastille", function(check)
		local view = BagDisplay.view(1, baseCapacity)
		check(view.tier == "low" and view.compact, `1 / {baseCapacity} : {view.tier}`)
		check(view.ratio > 0, "remplissage nul pour 1 unité")
		local justBelow = math.ceil(baseCapacity * BagDisplay.COMPACT_BELOW) - 1
		check(BagDisplay.view(justBelow, baseCapacity).compact, `{justBelow} / {baseCapacity} doit rester compact`)
		check(sameRgb(view.fill, Colors.green) or view.fill.g > view.fill.r, "couleur de départ non verte")
	end)

	case("sac à 50 % : barre et couleur intermédiaire", function(check)
		local half = baseCapacity / 2
		local view = BagDisplay.view(half, baseCapacity)
		check(view.tier == "filling" and not view.compact, `état {view.tier}`)
		check(view.ratio == 0.5, `ratio {view.ratio}`)
		check(not view.alert and view.labelKey == nil, "alerte à 50 %")
		check(not sameRgb(view.fill, Colors.green) and not sameRgb(view.fill, Colors.yellow), "couleur non évolutive")
		-- La couleur évolue vers le jaune : le rouge augmente avec le remplissage.
		local early = BagDisplay.view(math.ceil(baseCapacity * 0.3), baseCapacity)
		check(view.fill.r > early.fill.r, "pas de progression de couleur")
	end)

	case("sac presque plein : alerte", function(check)
		local from = math.ceil(baseCapacity * BagDisplay.NEARLY_FULL_FROM)
		local view = BagDisplay.view(from, baseCapacity)
		check(view.tier == "nearly_full", `{from} / {baseCapacity} : {view.tier}`)
		check(view.alert and view.labelKey == "hud.bag_almost_full", "mot d'état absent")
		check(view.hintKey == nil, "invitation à vendre trop tôt")
		check(sameRgb(view.fill, Colors.orange), "couleur d'alerte")
		check(BagDisplay.view(baseCapacity - 1, baseCapacity).tier == "nearly_full", "capacité - 1")
		check(BagDisplay.view(from - 1, baseCapacity).tier == "filling", "seuil trop bas")
	end)

	case("sac plein : invitation à vendre", function(check)
		local view = BagDisplay.view(baseCapacity, baseCapacity)
		check(view.tier == "full" and view.ratio == 1, `état {view.tier}`)
		check(view.labelKey == "hud.bag_full" and view.hintKey == "hud.sell_hint", "textes de l'état plein")
		check(view.alert and not view.compact, "état plein non mis en avant")
		check(sameRgb(view.fill, Colors.red), "couleur de l'état plein")
		-- Au-delà de la capacité (capacité réduite, données anciennes) : plein, borné.
		local over = BagDisplay.view(baseCapacity + 7, baseCapacity)
		check(over.tier == "full" and over.ratio == 1, "dépassement non borné")
	end)

	case("capacité après amélioration Backpack (état serveur)", function(check)
		local level2 = UpgradeMath.valueAt("Backpack", 2)
		check(type(level2) == "number" and level2 > baseCapacity, "niveau 2 du Backpack introuvable")
		local before = serverBag({ green_leaf = baseCapacity }, 1)
		local after = serverBag({ green_leaf = baseCapacity }, 2)
		check(before.capacity == baseCapacity and after.capacity == level2, "capacité serveur inattendue")
		local viewBefore = BagDisplay.view(before.used, before.capacity)
		local viewAfter = BagDisplay.view(after.used, after.capacity)
		check(viewBefore.tier == "full", `avant : {viewBefore.tier}`)
		check(viewAfter.tier ~= "full", `après : {viewAfter.tier}`)
		check(viewAfter.ratio == baseCapacity / level2, "ratio non recalculé sur la capacité serveur")
	end)

	case("ressources inconnues comptées dans l'occupation", function(check)
		local bag = serverBag({ green_leaf = 3, legacy_resource = baseCapacity - 3 }, 1)
		check(bag.used == baseCapacity, `occupation serveur {bag.used}`)
		local view = BagDisplay.view(bag.used, bag.capacity)
		check(view.tier == "full", `ressource inconnue ignorée : {view.tier}`)
	end)

	case("progression monotone, sans retour d'état", function(check)
		for _, capacity in ipairs({ baseCapacity, UpgradeMath.valueAt("Backpack", 2), 7, 1 }) do
			local previous = 0
			for used = 0, capacity do
				local rank = TIER_ORDER[BagDisplay.view(used, capacity).tier]
				check(rank ~= nil, `état inconnu à {used} / {capacity}`)
				check(rank >= previous, `retour d'état à {used} / {capacity}`)
				previous = rank or previous
			end
			check(BagDisplay.view(capacity, capacity).tier == "full", `{capacity} / {capacity} non plein`)
		end
	end)

	case("valeurs illisibles : aucune capacité inventée", function(check)
		local nan = 0 / 0
		for _, pair in ipairs({ { nan, 50 }, { -4, 50 }, { 10, 0 }, { 10, nan }, { 10, -5 } }) do
			local view = BagDisplay.view(pair[1], pair[2])
			check(view.ratio >= 0 and view.ratio <= 1, `ratio hors bornes pour {pair[1]}, {pair[2]}`)
		end
		check(BagDisplay.view(-4, 50).tier == "empty", "quantité négative")
		local noCapacity = BagDisplay.view(10, 0)
		check(noCapacity.tier == "empty" and not noCapacity.alert, "capacité nulle traitée comme une vraie capacité")
	end)

	case("textes EN/FR des états du sac", function(check)
		for _, language in ipairs(Localization.languages()) do
			for _, key in ipairs(BagDisplay.KEYS) do
				check(Localization.has(key, language), `texte manquant ({language}) : {key}`)
				local text = Localization.get(key, language)
				check(#text <= MAX_STATE_TEXT_LENGTH, `texte trop long ({language}) : {key} = {text}`)
			end
		end
		check(Localization.get("hud.bag_almost_full", "fr-fr") == "Presque plein", "français presque plein")
		check(Localization.get("hud.sell_hint", "en-us") == "Sell at the stand!", "anglais invitation")
		check(Localization.get("hud.sell_hint", "fr-fr") ~= Localization.get("hud.sell_hint", "en-us"), "non traduit")
	end)

	return failures, caseCount
end

return HudTests
