--!strict
-- Crédits des modèles 3D (A-4, option C) : cohérence de CreditsConfig et
-- présence des textes du panneau. Logique pure.

local CreditsTests = {}

export type Modules = {
	CreditsConfig: any,
	Localization: any,
}

-- Nombre de meshes Polyfork CC BY 4.0 du manifeste (20 ressources, T10).
local EXPECTED_COUNT = 20
local KEYS = { "settings.credits", "settings.credits_open", "credits.title", "credits.intro", "credits.close" }

function CreditsTests.run(modules: Modules): ({ string }, number)
	local CreditsConfig = modules.CreditsConfig
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

	case("20 modèles, titres et fiches uniques", function(check)
		check(#CreditsConfig.Models == EXPECTED_COUNT, `{#CreditsConfig.Models} modèles`)
		local titles, slugs = {}, {}
		for _, credit in ipairs(CreditsConfig.Models) do
			check(type(credit.title) == "string" and credit.title ~= "", "titre vide")
			check(type(credit.slug) == "string" and string.match(credit.slug, "^[a-z0-9%-]+$") ~= nil, `fiche {tostring(credit.slug)}`)
			check(not titles[credit.title], `titre en double : {credit.title}`)
			check(not slugs[credit.slug], `fiche en double : {credit.slug}`)
			titles[credit.title] = true
			slugs[credit.slug] = true
		end
	end)

	case("ordre alphabétique", function(check)
		for index = 2, #CreditsConfig.Models do
			local previous, current = CreditsConfig.Models[index - 1].title, CreditsConfig.Models[index].title
			check(previous < current, `{previous} avant {current}`)
		end
	end)

	case("format d'attribution CC BY 4.0", function(check)
		check(CreditsConfig.Author == "Polyfork" and CreditsConfig.License == "CC BY 4.0", "auteur ou licence")
		local lines = CreditsConfig.lines()
		check(#lines == #CreditsConfig.Models, "une ligne par modèle")
		check(
			lines[2] == "Apple by Polyfork (https://polyfork.dev/asset/apple-b15012), CC BY 4.0",
			`ligne inattendue : {tostring(lines[2])}`
		)
		for _, line in ipairs(lines) do
			check(string.match(line, "^.+ by Polyfork %(https://polyfork%.dev/asset/[a-z0-9%-]+%), CC BY 4%.0$") ~= nil, line)
		end
	end)

	case("textes du panneau en EN et FR", function(check)
		for _, key in ipairs(KEYS) do
			check(Localization.has(key, "en") and Localization.has(key, "fr"), `{key} manquant`)
		end
		check(string.find(Localization.get("credits.intro", "en"), "CC BY 4.0", 1, true) ~= nil, "licence absente (EN)")
		check(string.find(Localization.get("credits.intro", "fr"), "CC BY 4.0", 1, true) ~= nil, "licence absente (FR)")
	end)

	return failures, caseCount
end

return CreditsTests
