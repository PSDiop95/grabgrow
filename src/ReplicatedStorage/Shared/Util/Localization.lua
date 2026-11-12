--!strict
-- Textes d'interface par clé de localisation (anglais et français).
-- Logique pure : la langue est passée par l'appelant (Player.LocaleId).
--
-- Noms de mondes : noms propres, identiques dans les deux langues.
--
-- Solution minimale du MVP. À remplacer par les tables de localisation
-- Roblox (LocalizationService) quand l'interface complète sera faite (T5) :
-- les clés resteront les mêmes.

local Localization = {}

Localization.DEFAULT_LANGUAGE = "en"

local STRINGS: { [string]: { [string]: string } } = {
	en = {
		["resource.green_leaf"] = "Green Leaf",
		["resource.wood"] = "Wood Chunk",
		["resource.stone"] = "Stone",
		["hud.bag"] = "Bag",
		["hud.bag_full"] = "Bag full!",
		["collect.action"] = "Grab",
		["collect.too_far"] = "Too far",
		["hud.coins"] = "Coins",
		["hud.sell_value"] = "Sell value",
		["sell.action"] = "Sell",
		["sell.station"] = "Sell",
		["sell.estimate"] = "~%d Coins",
		["sell.gain"] = "+%d Coins",
		["sell.empty"] = "Bag empty",
		["sell.nothing"] = "Nothing to sell",
		["sell.too_far"] = "Get closer to the stand",
		["sell.failed"] = "Sale failed. Nothing was lost.",
		["sell.go_sell"] = "Bag full! Sell at the stand",
		-- T4 : améliorations, boutique, mondes.
		["upgrade.backpack"] = "Backpack",
		["upgrade.grabber"] = "Grabber",
		["upgrade.magnet"] = "Magnet",
		["upgrade.boots"] = "Boots",
		["upgrade.multiplier"] = "Multiplier",
		["world.green_valley"] = "Green Valley",
		["world.golden_desert"] = "Golden Desert",
		["world.frozen_peaks"] = "Frozen Peaks",
		["world.mystic_world"] = "Mystic World",
		["shop.open"] = "Shop",
		["shop.title"] = "Upgrades",
		["shop.close"] = "Close",
		["shop.level"] = "Lv %d",
		["shop.max"] = "MAX",
		["shop.price"] = "%d Coins",
		["shop.need"] = "Need %d",
		["shop.pending"] = "...",
		["shop.bought"] = "Upgraded!",
		["shop.failed"] = "Purchase failed. Nothing was spent.",
		["shop.insufficient"] = "Not enough Coins",
		["shop.max_reached"] = "Max level reached",
		["shop.worlds"] = "Worlds",
		["hud.worlds"] = "Worlds",
		["world.unlocked"] = "Unlocked",
		["world.locked"] = "Locked",
		["world.requires_backpack"] = "Backpack Lv %d",
		["world.requires_previous"] = "Unlock the previous world first",
		["world.unlock"] = "Unlock",
		["world.confirm"] = "Confirm?",
		["world.unlocked_toast"] = "World unlocked!",
		["world.coming_soon"] = "Content coming soon",
		["world.failed"] = "Unlock failed. Nothing was spent.",
	},
	fr = {
		["resource.green_leaf"] = "Feuille",
		["resource.wood"] = "Bois",
		["resource.stone"] = "Pierre",
		["hud.bag"] = "Sac",
		["hud.bag_full"] = "Sac plein !",
		["collect.action"] = "Prendre",
		["collect.too_far"] = "Trop loin",
		["hud.coins"] = "Coins",
		["hud.sell_value"] = "Valeur",
		["sell.action"] = "Vendre",
		["sell.station"] = "Vente",
		["sell.estimate"] = "~%d Coins",
		["sell.gain"] = "+%d Coins",
		["sell.empty"] = "Sac vide",
		["sell.nothing"] = "Rien à vendre",
		["sell.too_far"] = "Approchez-vous du stand",
		["sell.failed"] = "Vente impossible. Rien n'est perdu.",
		["sell.go_sell"] = "Sac plein ! Vendez au stand",
		-- T4 : améliorations, boutique, mondes.
		["upgrade.backpack"] = "Sac à dos",
		["upgrade.grabber"] = "Pince",
		["upgrade.magnet"] = "Aimant",
		["upgrade.boots"] = "Bottes",
		["upgrade.multiplier"] = "Multiplicateur",
		["world.green_valley"] = "Green Valley",
		["world.golden_desert"] = "Golden Desert",
		["world.frozen_peaks"] = "Frozen Peaks",
		["world.mystic_world"] = "Mystic World",
		["shop.open"] = "Boutique",
		["shop.title"] = "Améliorations",
		["shop.close"] = "Fermer",
		["shop.level"] = "Niv. %d",
		["shop.max"] = "MAX",
		["shop.price"] = "%d Coins",
		["shop.need"] = "Manque %d",
		["shop.pending"] = "...",
		["shop.bought"] = "Amélioré !",
		["shop.failed"] = "Achat impossible. Rien n'a été dépensé.",
		["shop.insufficient"] = "Pas assez de Coins",
		["shop.max_reached"] = "Niveau maximum atteint",
		["shop.worlds"] = "Mondes",
		["hud.worlds"] = "Mondes",
		["world.unlocked"] = "Débloqué",
		["world.locked"] = "Verrouillé",
		["world.requires_backpack"] = "Sac à dos niv. %d",
		["world.requires_previous"] = "Débloquez d'abord le monde précédent",
		["world.unlock"] = "Débloquer",
		["world.confirm"] = "Confirmer ?",
		["world.unlocked_toast"] = "Monde débloqué !",
		["world.coming_soon"] = "Contenu à venir",
		["world.failed"] = "Déblocage impossible. Rien n'a été dépensé.",
	},
}

-- "fr-fr" -> "fr". Langue inconnue -> langue par défaut.
function Localization.languageOf(localeId: string?): string
	if type(localeId) == "string" then
		local language = string.lower(string.sub(localeId, 1, 2))
		if STRINGS[language] ~= nil then
			return language
		end
	end
	return Localization.DEFAULT_LANGUAGE
end

-- Texte de `key` dans la langue de `localeId`. Repli : langue par défaut,
-- puis la clé elle-même (visible à l'écran : oubli facile à repérer).
function Localization.get(key: string, localeId: string?): string
	local language = Localization.languageOf(localeId)
	return STRINGS[language][key] or STRINGS[Localization.DEFAULT_LANGUAGE][key] or key
end

-- Texte de `key` dont le motif `%d` reçoit `value` (entier).
function Localization.format(key: string, localeId: string?, value: number): string
	return (string.gsub(Localization.get(key, localeId), "%%d", string.format("%d", value)))
end

function Localization.has(key: string, language: string): boolean
	local strings = STRINGS[language]
	return strings ~= nil and strings[key] ~= nil
end

function Localization.languages(): { string }
	local list = {}
	for language in pairs(STRINGS) do
		table.insert(list, language)
	end
	table.sort(list)
	return list
end

return Localization
