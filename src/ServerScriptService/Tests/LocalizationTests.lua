--!strict
-- Tests de couverture des textes EN/FR (T5.4). Logique pure : aucune API
-- Roblox. Le rendu (police, retours à la ligne) se vérifie dans Studio.
--
-- Vérifie : mêmes clés dans les deux langues, mêmes motifs (%d, {nom}),
-- textes réellement traduits, vouvoiement, typographie (espaces,
-- ponctuation, apostrophes), accents usuels, longueurs maximales par usage,
-- et présence des clés construites par le code (unités, gains, contrôles,
-- expulsions).

local LocalizationTests = {}

export type Modules = {
	Localization: any,
	UpgradeConfig: any,
	ResourceConfig: any,
	WorldConfig: any,
	OnboardingRules: any,
}

-- Longueurs maximales (caractères) selon l'emplacement à l'écran. Hypothèses
-- calibrées sur un téléphone en paysage (TextScaled ou retour à la ligne).
local LENGTH_LIMITS: { { prefix: string, max: number } } = {
	-- Boutons et pastilles.
	{ prefix = "collect.action", max = 10 },
	{ prefix = "sell.action", max = 10 },
	{ prefix = "sell.station", max = 10 },
	{ prefix = "shop.open", max = 10 },
	{ prefix = "shop.close", max = 10 },
	{ prefix = "shop.max", max = 10 },
	{ prefix = "world.unlock", max = 12 },
	{ prefix = "travel.go", max = 12 },
	{ prefix = "settings.on", max = 10 },
	{ prefix = "settings.off", max = 10 },
	{ prefix = "onboarding.show", max = 10 },
	-- Noms affichés sur les cartes et billboards.
	{ prefix = "resource.", max = 16 },
	{ prefix = "world.green_valley", max = 16 },
	{ prefix = "world.golden_desert", max = 16 },
	{ prefix = "world.frozen_peaks", max = 16 },
	{ prefix = "world.mystic_world", max = 16 },
	-- HUD et états du sac.
	{ prefix = "hud.", max = 20 },
	-- Unités : le motif {value} compte pour quelques chiffres.
	{ prefix = "unit.", max = 16 },
	-- Guidage : contrôles, puis carte (ordre : la règle la plus précise d'abord).
	{ prefix = "onboarding.ctrl.", max = 44 },
	{ prefix = "onboarding.", max = 80 },
	-- Fenêtre d'expulsion Roblox (texte long accepté).
	{ prefix = "system.", max = 160 },
}
-- Par défaut : messages courts (toasts, cartes de boutique).
local DEFAULT_MAX_LENGTH = 48

-- Textes identiques en EN et FR : noms propres, Coins, symboles, unités.
local SAME_IN_BOTH: { [string]: boolean } = {
	["hud.coins"] = true,
	["sell.estimate"] = true,
	["sell.gain"] = true,
	["shop.max"] = true,
	["shop.price"] = true,
	["shop.pending"] = true,
	["world.green_valley"] = true,
	["world.golden_desert"] = true,
	["world.frozen_peaks"] = true,
	["world.mystic_world"] = true,
	["onboarding.show"] = true,
	["unit.seconds"] = true,
	["unit.studs"] = true,
	["unit.speed"] = true,
	["unit.multiplier"] = true,
}

-- Mots de tutoiement interdits en français (décision T5.4 : vouvoiement).
local TU_WORDS: { [string]: boolean } = {
	tu = true,
	te = true,
	toi = true,
	ton = true,
	ta = true,
	tes = true,
}

-- Débuts de mots français souvent écrits sans accent par erreur
-- (« premiere » détecte aussi « premieres »).
local UNACCENTED: { string } = {
	"ameliore",
	"amelioration",
	"debloque",
	"etape",
	"depense",
	"verrouille",
	"parametres",
	"portee",
	"delai",
	"premiere",
	"donnees",
	"chargees",
	"utilisees",
	"ete",
	"reduits",
	"active",
	"desactive",
	"bien joue",
	"pres d",
	"a vous",
	"a venir",
	"a dos",
	"a vendre",
}

local function lengthLimit(key: string): number
	for _, rule in ipairs(LENGTH_LIMITS) do
		-- Préfixe terminé par « . » : famille de clés ; sinon clé exacte.
		local isFamily = string.sub(rule.prefix, -1) == "."
		if (isFamily and string.sub(key, 1, #rule.prefix) == rule.prefix) or key == rule.prefix then
			return rule.max
		end
	end
	return DEFAULT_MAX_LENGTH
end

-- Motifs d'un texte, triés : "%d" et "{nom}".
local function placeholders(text: string): string
	local list = {}
	for _ in string.gmatch(text, "%%d") do
		table.insert(list, "%d")
	end
	for name in string.gmatch(text, "{(%w+)}") do
		table.insert(list, `\{{name}\}`)
	end
	table.sort(list)
	return table.concat(list, ",")
end

-- Mots en minuscules (lettres ASCII et octets UTF-8 non ASCII).
local function words(text: string): { string }
	local list = {}
	for word in string.gmatch(string.lower(text), "[%a\128-\255]+") do
		table.insert(list, word)
	end
	return list
end

function LocalizationTests.run(modules: Modules): ({ string }, number)
	local Localization = modules.Localization
	local UpgradeConfig = modules.UpgradeConfig
	local ResourceConfig = modules.ResourceConfig
	local WorldConfig = modules.WorldConfig
	local OnboardingRules = modules.OnboardingRules
	local NBSP = Localization.NBSP

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

	local enKeys: { string } = Localization.keys("en")
	local frKeys: { string } = Localization.keys("fr")

	case("langues disponibles", function(check)
		local languages = Localization.languages()
		check(#languages == 2 and languages[1] == "en" and languages[2] == "fr", "attendu : en, fr")
		check(#enKeys > 0, "aucune clé EN")
	end)

	case("mêmes clés en EN et FR", function(check)
		for _, key in ipairs(enKeys) do
			check(Localization.has(key, "fr"), `FR manquant : {key}`)
		end
		for _, key in ipairs(frKeys) do
			check(Localization.has(key, "en"), `EN manquant : {key}`)
		end
		check(#enKeys == #frKeys, `nombre de clés EN {#enKeys} / FR {#frKeys}`)
	end)

	case("mêmes motifs %d et {nom}", function(check)
		for _, key in ipairs(enKeys) do
			local en = placeholders(Localization.get(key, "en"))
			local fr = placeholders(Localization.get(key, "fr"))
			check(en == fr, `{key} : EN [{en}] / FR [{fr}]`)
		end
	end)

	case("textes traduits", function(check)
		for _, key in ipairs(enKeys) do
			local same = Localization.get(key, "en") == Localization.get(key, "fr")
			check(same == (SAME_IN_BOTH[key] == true), `{key} : identique en EN et FR = {same}`)
		end
	end)

	case("textes non vides, sans espaces superflus", function(check)
		for _, language in ipairs({ "en", "fr" }) do
			for _, key in ipairs(Localization.keys(language)) do
				local text = Localization.get(key, language)
				check(text ~= "", `{language} {key} : vide`)
				check(string.match(text, "^%s") == nil and string.match(text, "%s$") == nil, `{language} {key} : espace en bord`)
				check(string.find(text, "  ", 1, true) == nil, `{language} {key} : double espace`)
			end
		end
	end)

	case("longueurs maximales (mobile)", function(check)
		for _, language in ipairs({ "en", "fr" }) do
			for _, key in ipairs(Localization.keys(language)) do
				local length = utf8.len(Localization.get(key, language))
				check(length ~= nil, `{language} {key} : UTF-8 invalide`)
				local limit = lengthLimit(key)
				check(length ~= nil and (length :: number) <= limit, `{language} {key} : {length} > {limit}`)
			end
		end
	end)

	case("vouvoiement en français", function(check)
		for _, key in ipairs(frKeys) do
			for _, word in ipairs(words(Localization.get(key, "fr"))) do
				check(not TU_WORDS[word], `{key} : « {word} »`)
			end
		end
	end)

	case("accents français", function(check)
		for _, key in ipairs(frKeys) do
			-- Espaces insécables ramenés à des espaces pour la recherche.
			local text = " " .. string.lower((string.gsub(Localization.get(key, "fr"), NBSP, " "))) .. " "
			for _, word in ipairs(UNACCENTED) do
				local found = string.find(text, `[^%a\128-\255]{word}`) ~= nil
				check(not found, `{key} : « {word} » sans accent`)
			end
		end
	end)

	case("ponctuation française : espace insécable", function(check)
		for _, key in ipairs(frKeys) do
			local text = Localization.get(key, "fr")
			check(string.find(text, " [!?:;]") == nil, `{key} : espace simple avant ponctuation`)
			for position in string.gmatch(text, "()[!?:;]") do
				local before = string.sub(text, math.max(position - #NBSP, 1), position - 1)
				-- "~%d" ou "{nom}:" n'existent pas ; une ponctuation doit suivre
				-- un espace insécable.
				check(before == NBSP, `{key} : pas d'espace insécable avant la ponctuation`)
			end
		end
		check(Localization.get("hud.sell_hint", "fr-fr") == `Vendez au stand{NBSP}!`, "hud.sell_hint")
	end)

	case("ponctuation anglaise : pas d'espace avant", function(check)
		for _, key in ipairs(enKeys) do
			local text = Localization.get(key, "en")
			check(string.find(text, "[ " .. NBSP .. "][!?:;]") == nil, `{key} : espace avant ponctuation`)
		end
	end)

	case("apostrophes droites uniquement", function(check)
		local curly = utf8.char(0x2019)
		for _, language in ipairs({ "en", "fr" }) do
			for _, key in ipairs(Localization.keys(language)) do
				local text = Localization.get(key, language)
				check(string.find(text, curly, 1, true) == nil, `{language} {key} : apostrophe typographique`)
				check(string.find(text, "`", 1, true) == nil, `{language} {key} : accent grave isolé`)
			end
		end
	end)

	case("clés construites par le code", function(check)
		local required: { string } = {
			"system.kick.load_failed",
			"system.kick.session_locked",
			"system.kick.session_lost",
			"unit.seconds",
			"unit.studs",
			"unit.speed",
			"unit.multiplier",
		}
		for _, definition in pairs(UpgradeConfig) do
			table.insert(required, definition.displayNameKey)
			table.insert(required, `{definition.displayNameKey}.gain`)
		end
		for _, definition in pairs(ResourceConfig) do
			table.insert(required, definition.displayNameKey)
		end
		for _, definition in pairs(WorldConfig) do
			if type(definition) == "table" and definition.displayNameKey then
				table.insert(required, definition.displayNameKey)
			end
		end
		for _, controls in ipairs({ "collect", "sell", "shop" }) do
			for _, device in ipairs({ "touch", "keyboard", "gamepad" }) do
				table.insert(required, OnboardingRules.controlsKey(controls, device))
			end
		end
		for _, key in ipairs(required) do
			check(Localization.has(key, "en") and Localization.has(key, "fr"), `clé absente : {key}`)
		end
	end)

	case("gains et unités remplis", function(check)
		for _, language in ipairs({ "en", "fr" }) do
			for _, definition in pairs(UpgradeConfig) do
				local text = Localization.fill(`{definition.displayNameKey}.gain`, language, { from = "1", to = "2" })
				check(string.find(text, "{", 1, true) == nil, `{language} {definition.displayNameKey}.gain incomplet`)
			end
		end
		check(Localization.fill("unit.studs", "fr-fr", { value = "12,5" }) == "12,5 studs", "unit.studs FR")
		check(Localization.fill("unit.multiplier", "en-us", { value = "1.5" }) == "x1.5", "unit.multiplier EN")
		check(Localization.fill("unit.seconds", "en-us", { value = "0.8" }) == "0.8 s", "unit.seconds EN")
	end)

	case("messages d'expulsion (A-22)", function(check)
		for _, name in ipairs({ "load_failed", "session_locked", "session_lost" }) do
			local key = `system.kick.{name}`
			local en = Localization.get(key, "en-us")
			local fr = Localization.get(key, "fr-fr")
			check(en ~= key and fr ~= key, `{key} : non résolu`)
			check(en ~= fr, `{key} : non traduit`)
		end
		check(
			string.sub(Localization.get("system.kick.load_failed", "fr-fr"), 1, 12) == "Vos données",
			"FR : vouvoiement du message de chargement"
		)
		check(
			string.find(Localization.get("system.kick.load_failed", "fr-fr"), "Rien n'est perdu", 1, true) ~= nil,
			"FR : rassurer sur la perte de données"
		)
	end)

	case("langue du joueur et replis", function(check)
		check(Localization.languageOf("fr-fr") == "fr", "fr-fr")
		check(Localization.languageOf("fr-ca") == "fr", "fr-ca")
		check(Localization.languageOf("FR-BE") == "fr", "FR-BE")
		check(Localization.languageOf("en-gb") == "en", "en-gb")
		check(Localization.languageOf("es-es") == "en", "langue inconnue -> en")
		check(Localization.languageOf(nil) == "en", "nil -> en")
		check(Localization.get("system.kick.session_lost", "es-es") == Localization.get("system.kick.session_lost", "en"), "repli EN")
		check(Localization.get("absent.key", "fr-fr") == "absent.key", "clé inconnue visible")
	end)

	return failures, caseCount
end

return LocalizationTests
