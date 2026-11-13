--!strict
-- Textes d'interface par clé de localisation (anglais et français).
-- Logique pure : la langue est passée par l'appelant (Player.LocaleId).
--
-- Noms de mondes : noms propres, identiques dans les deux langues.
--
-- Module conservé pour le MVP (D-016, D-4) : pas de migration vers
-- LocalizationService ; les clés resteraient les mêmes en cas de migration.

local Localization = {}

Localization.DEFAULT_LANGUAGE = "en"

local STRINGS: { [string]: { [string]: string } } = {
	en = {
		["resource.green_leaf"] = "Green Leaf",
		["resource.wood"] = "Wood Chunk",
		["resource.stone"] = "Stone",
		["hud.bag"] = "Bag",
		["hud.bag_full"] = "Bag full!",
		-- T5.1 : états du sac dans le HUD.
		["hud.bag_almost_full"] = "Almost full",
		["hud.sell_hint"] = "Sell at the stand!",
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
		-- Message d'achat : valeur avant -> après (A-40).
		["upgrade.backpack.gain"] = "Bag {from} → {to}",
		["upgrade.grabber.gain"] = "Grab delay {from} → {to}",
		["upgrade.magnet.gain"] = "Range {from} → {to}",
		["upgrade.boots.gain"] = "Speed {from} → {to}",
		["upgrade.multiplier.gain"] = "Sell value {from} → {to}",
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
		-- T5.2 : message de déblocage nommé, préférences audio et effets.
		["world.unlocked_named"] = "{world} unlocked!",
		["settings.title"] = "Settings",
		["settings.sound"] = "Sound",
		["settings.reduced_effects"] = "Reduced effects",
		["settings.on"] = "On",
		["settings.off"] = "Off",
		-- T5.3 : guidage de première session.
		["onboarding.welcome_title"] = "Welcome to Grab & Grow!",
		["onboarding.welcome_body"] = "Collect resources, sell them and upgrade your equipment.",
		["onboarding.step"] = "Step %d/3",
		["onboarding.collect"] = "Collect your first resources!",
		["onboarding.keep_collecting"] = "Nice! Keep filling your backpack.",
		["onboarding.sell"] = "Your backpack is filling up. Sell your resources!",
		["onboarding.sold"] = "Great sale! +%d Coins",
		["onboarding.upgrade"] = "Spend your Coins to upgrade your equipment!",
		["onboarding.upgrade_pick"] = "Pick an upgrade with a green price.",
		["onboarding.earn_more"] = "Collect and sell: %d more Coins for your first upgrade.",
		["onboarding.done"] = "{name} level {level}! Your turn: grab, sell, upgrade.",
		["onboarding.show"] = "Guide",
		["onboarding.ctrl.collect.touch"] = "Tap a resource or hold Grab",
		["onboarding.ctrl.collect.keyboard"] = "Hold E or click a resource",
		["onboarding.ctrl.collect.gamepad"] = "Hold X near a resource",
		["onboarding.ctrl.sell.touch"] = "Go to the stand and tap Sell",
		["onboarding.ctrl.sell.keyboard"] = "Go to the stand and press F",
		["onboarding.ctrl.sell.gamepad"] = "Go to the stand and press Y",
		["onboarding.ctrl.shop.touch"] = "Tap Shop",
		["onboarding.ctrl.shop.keyboard"] = "Press B or click Shop",
		["onboarding.ctrl.shop.gamepad"] = "Press D-pad up",
	},
	fr = {
		["resource.green_leaf"] = "Feuille",
		["resource.wood"] = "Bois",
		["resource.stone"] = "Pierre",
		["hud.bag"] = "Sac",
		["hud.bag_full"] = "Sac plein !",
		["hud.bag_almost_full"] = "Presque plein",
		["hud.sell_hint"] = "Vendez au stand !",
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
		["upgrade.backpack.gain"] = "Sac {from} → {to}",
		["upgrade.grabber.gain"] = "Délai de collecte {from} → {to}",
		["upgrade.magnet.gain"] = "Portée {from} → {to}",
		["upgrade.boots.gain"] = "Vitesse {from} → {to}",
		["upgrade.multiplier.gain"] = "Valeur de vente {from} → {to}",
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
		["world.unlocked_named"] = "{world} débloqué !",
		["settings.title"] = "Paramètres",
		["settings.sound"] = "Son",
		["settings.reduced_effects"] = "Effets réduits",
		["settings.on"] = "Activé",
		["settings.off"] = "Désactivé",
		["onboarding.welcome_title"] = "Bienvenue dans Grab & Grow !",
		["onboarding.welcome_body"] = "Collecte des ressources, vends-les et améliore ton équipement.",
		["onboarding.step"] = "Étape %d/3",
		["onboarding.collect"] = "Collecte tes premières ressources !",
		["onboarding.keep_collecting"] = "Bien joué ! Continue de remplir ton sac.",
		["onboarding.sell"] = "Ton sac se remplit. Vends tes ressources !",
		["onboarding.sold"] = "Belle vente ! +%d Coins",
		["onboarding.upgrade"] = "Utilise tes Coins pour améliorer ton équipement !",
		["onboarding.upgrade_pick"] = "Choisis une amélioration au prix vert.",
		["onboarding.earn_more"] = "Collecte et vends : encore %d Coins pour ta première amélioration.",
		["onboarding.done"] = "{name} niveau {level} ! À toi de jouer : prends, vends, améliore.",
		["onboarding.show"] = "Guide",
		["onboarding.ctrl.collect.touch"] = "Touche une ressource ou maintiens Prendre",
		["onboarding.ctrl.collect.keyboard"] = "Maintiens E ou clique sur une ressource",
		["onboarding.ctrl.collect.gamepad"] = "Maintiens X près d'une ressource",
		["onboarding.ctrl.sell.touch"] = "Va au stand et touche Vendre",
		["onboarding.ctrl.sell.keyboard"] = "Va au stand et appuie sur F",
		["onboarding.ctrl.sell.gamepad"] = "Va au stand et appuie sur Y",
		["onboarding.ctrl.shop.touch"] = "Touche Boutique",
		["onboarding.ctrl.shop.keyboard"] = "Appuie sur B ou clique sur Boutique",
		["onboarding.ctrl.shop.gamepad"] = "Appuie sur la croix haut",
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

-- Texte de `key` dont chaque motif `{nom}` reçoit `values[nom]` (texte déjà
-- mis en forme). Motif sans valeur : laissé tel quel (oubli visible).
function Localization.fill(key: string, localeId: string?, values: { [string]: string }): string
	return (string.gsub(Localization.get(key, localeId), "{(%w+)}", function(name: string): string
		return values[name] or `\{{name}\}`
	end))
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
