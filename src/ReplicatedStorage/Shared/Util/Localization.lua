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
		-- T8 (D-021) : ressources des quatre mondes.
		["resource.wild_fruit"] = "Wild Fruit",
		["resource.green_crystal"] = "Green Crystal",
		["resource.sandstone"] = "Sandstone",
		["resource.copper_ore"] = "Copper Ore",
		["resource.fossil"] = "Fossil",
		["resource.gold_nugget"] = "Gold Nugget",
		["resource.sun_crystal"] = "Sun Crystal",
		["resource.ice_shard"] = "Ice Shard",
		["resource.silver_ore"] = "Silver Ore",
		["resource.frozen_stone"] = "Frozen Stone",
		["resource.blue_crystal"] = "Blue Crystal",
		["resource.ice_diamond"] = "Ice Diamond",
		["resource.mystic_dust"] = "Mystic Dust",
		["resource.star_fragment"] = "Star Fragment",
		["resource.spectral_ore"] = "Spectral Ore",
		["resource.purple_crystal"] = "Purple Crystal",
		["resource.mystic_core"] = "Mystic Core",
		["hud.bag"] = "Bag",
		["hud.bag_full"] = "Bag full!",
		-- T5.1 : états du sac dans le HUD.
		["hud.bag_almost_full"] = "Almost full",
		["hud.sell_hint"] = "Sell at the stand!",
		["collect.action"] = "Grab",
		["collect.too_far"] = "Too far",
		["collect.world_locked"] = "Unlock this world first",
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
		["sell.go_sell"] = "Bag full! Sell at the stand!",
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
		-- T8.2 : voyage entre mondes (portails, boutique).
		["travel.go"] = "Travel",
		["travel.here"] = "You are here",
		["travel.arrived"] = "Welcome to {world}!",
		["travel.locked"] = "Unlock this world in the Shop",
		["travel.wait"] = "Please wait a moment",
		["travel.no_character"] = "Wait until you respawn",
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
		-- T5.4 : unités des effets d'amélioration ({value} déjà mis en forme).
		["unit.seconds"] = "{value} s",
		["unit.studs"] = "{value} studs",
		["unit.speed"] = "{value} studs/s",
		["unit.multiplier"] = "x{value}",
		-- T7 : succès permanents (D-020). {name} : nom du succès.
		["achievement.unlocked"] = "Achievement: {name} +{coins} Coins",
		["achievement.collect_100"] = "100 resources collected",
		["achievement.collect_1000"] = "1,000 resources collected",
		["achievement.collect_5000"] = "5,000 resources collected",
		["achievement.collect_20000"] = "20,000 resources collected",
		["achievement.sales_10"] = "10 sales made",
		["achievement.sales_50"] = "50 sales made",
		["achievement.sales_200"] = "200 sales made",
		["achievement.earned_10000"] = "10,000 Coins earned",
		["achievement.earned_100000"] = "100,000 Coins earned",
		["achievement.upgrades_10"] = "10 upgrades bought",
		["achievement.upgrades_25"] = "25 upgrades bought",
		["achievement.world_2"] = "First world unlocked",
		-- T8.6 : journal de collection (D-022). {discovered}, {total},
		-- {percent}, {value}, {name} : textes déjà mis en forme.
		["journal.open"] = "Journal",
		["journal.title"] = "Collection Journal",
		["journal.total"] = "{discovered} / {total} discovered — {percent}%",
		["journal.world_progress"] = "{discovered} / {total} — {percent}%",
		["journal.unknown"] = "Unknown",
		["journal.locked"] = "World locked",
		["journal.back"] = "Back",
		["journal.value"] = "{value} Coins",
		["journal.new_discovery"] = "New discovery: {name}!",
		["rarity.common"] = "Common",
		["rarity.uncommon"] = "Uncommon",
		["rarity.rare"] = "Rare",
		["rarity.epic"] = "Epic",
		-- T5.4 : messages d'expulsion (A-22), lus côté serveur avec la langue
		-- du joueur.
		["system.kick.load_failed"] = "Your data could not be loaded. Nothing was lost. Please rejoin in a few minutes.",
		["system.kick.session_locked"] = "Your data is still in use by another server. Please rejoin in a few minutes.",
		["system.kick.session_lost"] = "Your session was opened on another server.",
	},
	fr = {
		["resource.green_leaf"] = "Feuille",
		["resource.wood"] = "Bois",
		["resource.stone"] = "Pierre",
		-- T8 (D-021) : ressources des quatre mondes.
		["resource.wild_fruit"] = "Fruit sauvage",
		["resource.green_crystal"] = "Cristal vert",
		["resource.sandstone"] = "Grès",
		["resource.copper_ore"] = "Cuivre brut",
		["resource.fossil"] = "Fossile",
		["resource.gold_nugget"] = "Pépite d'or",
		["resource.sun_crystal"] = "Cristal solaire",
		["resource.ice_shard"] = "Éclat de glace",
		["resource.silver_ore"] = "Minerai d'argent",
		["resource.frozen_stone"] = "Pierre gelée",
		["resource.blue_crystal"] = "Cristal bleu",
		["resource.ice_diamond"] = "Diamant de glace",
		["resource.mystic_dust"] = "Poudre mystique",
		["resource.star_fragment"] = "Éclat d'étoile",
		["resource.spectral_ore"] = "Minerai spectral",
		["resource.purple_crystal"] = "Cristal violet",
		["resource.mystic_core"] = "Cœur mystique",
		["hud.bag"] = "Sac",
		["hud.bag_full"] = "Sac plein !",
		["hud.bag_almost_full"] = "Presque plein",
		["hud.sell_hint"] = "Vendez au stand !",
		["collect.action"] = "Prendre",
		["collect.too_far"] = "Trop loin",
		["collect.world_locked"] = "Débloquez d'abord ce monde",
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
		["sell.go_sell"] = "Sac plein ! Vendez au stand !",
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
		["travel.go"] = "Voyager",
		["travel.here"] = "Vous êtes ici",
		["travel.arrived"] = "Bienvenue dans {world} !",
		["travel.locked"] = "Débloquez ce monde dans la Boutique",
		["travel.wait"] = "Patientez un instant",
		["travel.no_character"] = "Attendez votre réapparition",
		["settings.title"] = "Paramètres",
		["settings.sound"] = "Son",
		["settings.reduced_effects"] = "Effets réduits",
		["settings.on"] = "Activé",
		["settings.off"] = "Désactivé",
		["onboarding.welcome_title"] = "Bienvenue dans Grab & Grow !",
		["onboarding.welcome_body"] = "Collectez des ressources, vendez-les et améliorez votre équipement.",
		["onboarding.step"] = "Étape %d/3",
		["onboarding.collect"] = "Collectez vos premières ressources !",
		["onboarding.keep_collecting"] = "Bien joué ! Continuez de remplir votre sac.",
		["onboarding.sell"] = "Votre sac se remplit. Vendez vos ressources !",
		["onboarding.sold"] = "Belle vente ! +%d Coins",
		["onboarding.upgrade"] = "Utilisez vos Coins pour améliorer votre équipement !",
		["onboarding.upgrade_pick"] = "Choisissez une amélioration au prix vert.",
		["onboarding.earn_more"] = "Collectez et vendez : encore %d Coins pour votre première amélioration.",
		["onboarding.done"] = "{name} niveau {level} ! À vous de jouer : prenez, vendez, améliorez.",
		["onboarding.show"] = "Guide",
		["onboarding.ctrl.collect.touch"] = "Touchez une ressource ou maintenez Prendre",
		["onboarding.ctrl.collect.keyboard"] = "Maintenez E ou cliquez sur une ressource",
		["onboarding.ctrl.collect.gamepad"] = "Maintenez X près d'une ressource",
		["onboarding.ctrl.sell.touch"] = "Allez au stand et touchez Vendre",
		["onboarding.ctrl.sell.keyboard"] = "Allez au stand et appuyez sur F",
		["onboarding.ctrl.sell.gamepad"] = "Allez au stand et appuyez sur Y",
		["onboarding.ctrl.shop.touch"] = "Touchez Boutique",
		["onboarding.ctrl.shop.keyboard"] = "Appuyez sur B ou cliquez sur Boutique",
		["onboarding.ctrl.shop.gamepad"] = "Appuyez sur la flèche haut de la croix",
		["unit.seconds"] = "{value} s",
		["unit.studs"] = "{value} studs",
		["unit.speed"] = "{value} studs/s",
		["unit.multiplier"] = "x{value}",
		["achievement.unlocked"] = "Succès : {name} +{coins} Coins",
		["achievement.collect_100"] = "100 ressources collectées",
		["achievement.collect_1000"] = "1\u{00A0}000 ressources collectées",
		["achievement.collect_5000"] = "5\u{00A0}000 ressources collectées",
		["achievement.collect_20000"] = "20\u{00A0}000 ressources collectées",
		["achievement.sales_10"] = "10 ventes réalisées",
		["achievement.sales_50"] = "50 ventes réalisées",
		["achievement.sales_200"] = "200 ventes réalisées",
		["achievement.earned_10000"] = "10\u{00A0}000 Coins gagnés",
		["achievement.earned_100000"] = "100\u{00A0}000 Coins gagnés",
		["achievement.upgrades_10"] = "10 améliorations achetées",
		["achievement.upgrades_25"] = "25 améliorations achetées",
		["achievement.world_2"] = "Premier monde débloqué",
		["journal.open"] = "Journal",
		["journal.title"] = "Journal de collection",
		["journal.total"] = "{discovered} / {total} découvertes — {percent}\u{00A0}%",
		["journal.world_progress"] = "{discovered} / {total} — {percent}\u{00A0}%",
		["journal.unknown"] = "Inconnue",
		["journal.locked"] = "Monde verrouillé",
		["journal.back"] = "Retour",
		["journal.value"] = "{value} Coins",
		["journal.new_discovery"] = "Nouvelle découverte : {name} !",
		["rarity.common"] = "Commune",
		["rarity.uncommon"] = "Peu commune",
		["rarity.rare"] = "Rare",
		["rarity.epic"] = "Épique",
		["system.kick.load_failed"] = "Vos données n'ont pas pu être chargées. Rien n'est perdu. Veuillez revenir dans quelques minutes.",
		["system.kick.session_locked"] = "Vos données sont encore utilisées par un autre serveur. Veuillez revenir dans quelques minutes.",
		["system.kick.session_lost"] = "Votre session a été ouverte sur un autre serveur.",
	},
}

-- Typographie française : espace insécable avant « ! ? : ; » pour qu'un
-- retour à la ligne ne laisse jamais la ponctuation seule en début de ligne.
-- Appliquée une fois au chargement : les tables restent lisibles.
Localization.NBSP = utf8.char(0x00A0)
for key, text in pairs(STRINGS.fr) do
	STRINGS.fr[key] = (string.gsub(text, " ([!?:;])", Localization.NBSP .. "%1"))
end

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

-- Clés définies pour `language`, triées (tests de couverture).
function Localization.keys(language: string): { string }
	local list = {}
	for key in pairs(STRINGS[language] or {}) do
		table.insert(list, key)
	end
	table.sort(list)
	return list
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
