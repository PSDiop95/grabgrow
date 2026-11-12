--!strict
-- Textes d'interface par clé de localisation (anglais et français).
-- Logique pure : la langue est passée par l'appelant (Player.LocaleId).
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
