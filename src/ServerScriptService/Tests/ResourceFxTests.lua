--!strict
-- Tests des règles d'effets des ressources (T10.1, D-027) : phase et lacet
-- déterministes, pose d'attente (dont « Effets réduits »), budget de nœuds
-- animés, mise à l'échelle des pièces (V-01), ajustement de taille des
-- modèles importés, cohérence de RarityVisualConfig. Logique pure : le
-- rendu réel (rebond, flash, modèles) se vérifie dans Studio.

local ResourceFxTests = {}

export type Modules = {
	ResourceFxRules: any,
	RarityVisualConfig: any,
	ResourceConfig: any,
}

local EPSILON = 1e-6

local function near(a: number, b: number): boolean
	return math.abs(a - b) < EPSILON
end

function ResourceFxTests.run(modules: Modules): ({ string }, number)
	local Rules = modules.ResourceFxRules
	local RarityVisualConfig = modules.RarityVisualConfig
	local ResourceConfig = modules.ResourceConfig

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

	local EPIC = RarityVisualConfig.Rarities.Epic

	case("phase : déterministe et dans [0, 1[", function(check)
		for _, id in ipairs({ "", "a", "GreenValley_green_leaf_01", "MysticWorld_purple_crystal_12" }) do
			local phase = Rules.phaseFor(id)
			check(phase >= 0 and phase < 1, `phase hors bornes pour "{id}"`)
			check(phase == Rules.phaseFor(id), `phase instable pour "{id}"`)
		end
		check(Rules.phaseFor("node_01") ~= Rules.phaseFor("node_02"), "deux nœuds voisins de même phase")
	end)

	case("lacet de départ : entier dans [0, 360[", function(check)
		local yaw = Rules.baseYawFor("GoldenDesert_copper_ore_03")
		check(yaw >= 0 and yaw < 360 and yaw == math.floor(yaw), "lacet invalide")
	end)

	case("pose : neutre sans paramètres ou en effets réduits", function(check)
		for _, pose in ipairs({ Rules.idlePose(nil, 3.2, 0.4, false), Rules.idlePose(EPIC, 3.2, 0.4, true) }) do
			check(pose.offsetY == 0 and pose.yawDegrees == 0 and pose.scale == 1, "pose non neutre")
		end
	end)

	case("pose : amplitudes bornées par la configuration", function(check)
		for t = 0, 10, 0.37 do
			local pose = Rules.idlePose(EPIC, t, 0.25, false)
			check(math.abs(pose.offsetY) <= EPIC.bob + EPSILON, `flottement > {EPIC.bob}`)
			check(math.abs(pose.scale - 1) <= EPIC.pulse + EPSILON, `pulsation > {EPIC.pulse}`)
			check(pose.yawDegrees >= 0 and pose.yawDegrees < 360, "lacet hors [0, 360[")
		end
	end)

	case("pose : période du flottement respectée", function(check)
		local common = RarityVisualConfig.Rarities.Common
		local a = Rules.idlePose(common, 1, 0.1, false)
		local b = Rules.idlePose(common, 1 + common.bobPeriod, 0.1, false)
		check(near(a.offsetY, b.offsetY), "flottement non périodique")
		check(a.yawDegrees == 0 and a.scale == 1, "Commun : ni rotation ni pulsation attendues")
	end)

	case("sélection : plus proches d'abord, budget et rayon respectés", function(check)
		local candidates = {}
		for index = 1, 40 do
			table.insert(candidates, { id = string.format("n%02d", index), distance = index * 2 })
		end
		local selected = Rules.selectAnimated(candidates, 24, 60)
		local count = 0
		for _ in pairs(selected) do
			count += 1
		end
		check(count == 24, `24 nœuds attendus, {count} obtenus`)
		check(selected["n01"] == true and selected["n24"] == true, "nœuds les plus proches absents")
		check(selected["n25"] == nil, "nœud au-delà du budget sélectionné")

		local far = Rules.selectAnimated({ { id = "a", distance = 61 }, { id = "b", distance = 60 } }, 24, 60)
		check(far["a"] == nil and far["b"] == true, "rayon de 60 studs non respecté")
	end)

	case("sélection : égalité de distance résolue par identifiant", function(check)
		local selected = Rules.selectAnimated({ { id = "b", distance = 5 }, { id = "a", distance = 5 } }, 1, 60)
		check(selected["a"] == true and selected["b"] == nil, "résultat instable")
		local none = Rules.selectAnimated({ { id = "a", distance = 1 } }, 0, 60)
		check(next(none) == nil, "budget nul : aucun nœud attendu")
	end)

	case("V-01 : décalage et taille des détails suivent l'échelle", function(check)
		local offset, size = Rules.scalePiece({ 0.6, -0.35, 0.4 }, { 0.9, 1.3, 1.2 }, 0.3)
		check(near(offset[1], 0.18) and near(offset[2], -0.105) and near(offset[3], 0.12), "décalage non mis à l'échelle")
		check(near(size[1], 0.27) and near(size[2], 0.39) and near(size[3], 0.36), "taille non mise à l'échelle")
		local o1, s1 = Rules.scalePiece({ 1, 2, 3 }, { 1, 1, 1 }, 1)
		check(o1[1] == 1 and o1[3] == 3 and s1[2] == 1, "échelle 1 : pièce modifiée")
	end)

	case("modèle importé : échelle d'ajustement", function(check)
		check(near(Rules.fitScale({ 4, 2, 1 }, 2) :: number, 0.5), "plus grande dimension non ramenée à la cible")
		check(near(Rules.fitScale({ 0.5, 1, 0.25 }, 2.5) :: number, 2.5), "agrandissement incorrect")
		check(Rules.fitScale({ 0, 0, 0 }, 2) == nil, "boîte vide acceptée")
		check(Rules.fitScale({ 1, 1, 1 }, 0) == nil, "cible nulle acceptée")
	end)

	case("RarityVisualConfig : une entrée valide par rareté utilisée", function(check)
		for resourceId, resource in pairs(ResourceConfig) do
			if type(resource) == "table" and resource.rarity ~= nil then
				check(RarityVisualConfig.Rarities[resource.rarity] ~= nil, `{resourceId} : rareté {resource.rarity} sans présentation`)
			end
		end
		for rarity, visual in pairs(RarityVisualConfig.Rarities) do
			for _, field in ipairs({ "bob", "spin", "pulse" }) do
				check(type(visual[field]) == "number" and visual[field] >= 0, `{rarity}.{field} invalide`)
			end
			check(visual.bob <= 0.5, `{rarity}.bob > 0,5 stud (lisibilité)`)
			check(visual.pulse <= 0.1, `{rarity}.pulse > 10 %`)
			check(visual.bobPeriod > 0 and visual.pulsePeriod > 0, `{rarity} : période nulle`)
			check(
				visual.reducedCollectParticles >= 0 and visual.reducedCollectParticles <= visual.collectParticles,
				`{rarity} : effets réduits plus intenses que la normale`
			)
		end
	end)

	case("RarityVisualConfig : budget d'animation (T10_PERFORMANCE_BUDGET)", function(check)
		check(RarityVisualConfig.MaxAnimatedNodes == 24, "24 nœuds animés au plus attendus")
		check(RarityVisualConfig.AnimationRadiusStuds == 60, "rayon de 60 studs attendu")
		check(RarityVisualConfig.AnimationHz > 0 and RarityVisualConfig.AnimationHz <= 30, "fréquence hors ]0, 30] Hz")
		check(RarityVisualConfig.SelectionRefreshSeconds > 0, "rafraîchissement nul")
		check(table.isfrozen(RarityVisualConfig.Rarities.Epic), "configuration modifiable")
	end)

	return failures, caseCount
end

return ResourceFxTests
