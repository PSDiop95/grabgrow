--!strict
-- Tests des règles d'effets des ressources (T10.1, D-027 ; T10.2, D-032) :
-- phase et lacet déterministes, pose d'attente (dont pirouette Épique et
-- « Effets réduits »), budget de nœuds animés, attribution des émetteurs
-- prêtés, niveau d'effets, éclats, attribution des disparitions, mise à
-- l'échelle des pièces (V-01), ajustement des modèles importés, cohérence
-- de ResourceVFXConfig. Logique pure : le rendu réel se vérifie dans Studio.

local ResourceFxTests = {}

export type Modules = {
	ResourceFxRules: any,
	ResourceVFXConfig: any,
	ResourceConfig: any,
}

local EPSILON = 1e-6

local function near(a: number, b: number): boolean
	return math.abs(a - b) < EPSILON
end

function ResourceFxTests.run(modules: Modules): ({ string }, number)
	local Rules = modules.ResourceFxRules
	local ResourceVFXConfig = modules.ResourceVFXConfig
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

	local EPIC = ResourceVFXConfig.Rarities.Epic

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
			local hop = if EPIC.special then EPIC.special.hop else 0
			check(math.abs(pose.offsetY) <= EPIC.bob + hop + EPSILON, `flottement > {EPIC.bob + hop}`)
			check(math.abs(pose.scale - 1) <= EPIC.pulse + EPSILON, `pulsation > {EPIC.pulse}`)
			check(pose.yawDegrees >= 0 and pose.yawDegrees < 360, "lacet hors [0, 360[")
		end
	end)

	case("pose : période du flottement respectée", function(check)
		local common = ResourceVFXConfig.Rarities.Common
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

	case("ResourceVFXConfig : une entrée valide par rareté utilisée", function(check)
		for resourceId, resource in pairs(ResourceConfig) do
			if type(resource) == "table" and resource.rarity ~= nil then
				check(ResourceVFXConfig.Rarities[resource.rarity] ~= nil, `{resourceId} : rareté {resource.rarity} sans présentation`)
			end
		end
		for rarity, visual in pairs(ResourceVFXConfig.Rarities) do
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

	case("ResourceVFXConfig : budget d'animation (T10_PERFORMANCE_BUDGET)", function(check)
		check(ResourceVFXConfig.MaxAnimatedNodes == 24, "24 nœuds animés au plus attendus")
		check(ResourceVFXConfig.AnimationRadiusStuds == 60, "rayon de 60 studs attendu")
		check(ResourceVFXConfig.AnimationHz > 0 and ResourceVFXConfig.AnimationHz <= 30, "fréquence hors ]0, 30] Hz")
		check(ResourceVFXConfig.SelectionRefreshSeconds > 0, "rafraîchissement nul")
		check(table.isfrozen(ResourceVFXConfig.Rarities.Epic), "configuration modifiable")
	end)


	local function plainEpic()
		return { bob = EPIC.bob, bobPeriod = EPIC.bobPeriod, spin = EPIC.spin, pulse = EPIC.pulse, pulsePeriod = EPIC.pulsePeriod }
	end

	case("pirouette Épique : périodique, bornée, absente hors fenêtre", function(check)
		local special = EPIC.special
		check(special ~= nil and special.duration < special.period, "pirouette Épique attendue")
		if special == nil then
			return
		end
		-- Phase 0 : la pirouette occupe le début de chaque période.
		local mid = special.duration / 2
		check(Rules.idlePose(EPIC, mid, 0, false).offsetY > Rules.idlePose(plainEpic(), mid, 0, false).offsetY, "saut absent pendant la pirouette")
		local after = special.duration + 0.5
		local outside, plain = Rules.idlePose(EPIC, after, 0, false), Rules.idlePose(plainEpic(), after, 0, false)
		check(near(outside.offsetY, plain.offsetY) and near(outside.yawDegrees, plain.yawDegrees), "pirouette hors fenêtre")
		local again = special.period + mid
		check(Rules.idlePose(EPIC, again, 0, false).offsetY > Rules.idlePose(plainEpic(), again, 0, false).offsetY, "pirouette non périodique")
		local reduced = Rules.idlePose(EPIC, mid, 0, true)
		check(reduced.offsetY == 0 and reduced.yawDegrees == 0, "pirouette en effets réduits")
		-- Sans rotation configurée, pas de lacet hors pirouette.
		local still = Rules.idlePose({ bob = 0, bobPeriod = 1, spin = 0, pulse = 0, pulsePeriod = 1 }, 3.3, 0.7, false)
		check(still.yawDegrees == 0, "lacet sans rotation configurée")
	end)

	case("niveau d'effets : réduits, qualité basse, automatique", function(check)
		local low = ResourceVFXConfig.LowQualityMax
		check(Rules.effectLevel(true, 10, low) == "reduced", "effets réduits prioritaires")
		check(Rules.effectLevel(false, 1, low) == "low", "qualité 1 : low")
		check(Rules.effectLevel(false, low, low) == "low", "qualité limite : low")
		check(Rules.effectLevel(false, low + 1, low) == "full", "qualité au-dessus : full")
		check(Rules.effectLevel(false, nil, low) == "full", "automatique : full")
		check(Rules.effectLevel(false, 0, low) == "full", "0 : full")
	end)

	case("émetteurs prêtés : rareté puis distance, budget et rayon", function(check)
		local candidates = {
			{ id = "common_near", distance = 1, priority = 0 },
			{ id = "epic_far", distance = 40, priority = 3 },
			{ id = "rare_mid", distance = 20, priority = 2 },
			{ id = "rare_near", distance = 5, priority = 2 },
			{ id = "epic_out", distance = 46, priority = 3 },
		}
		local two = Rules.allocateEmitters(candidates, 2, 45)
		check(two["epic_far"] == true and two["rare_near"] == true, "rareté d'abord, puis distance")
		check(two["rare_mid"] == nil and two["common_near"] == nil, "budget dépassé")
		check(two["epic_out"] == nil, "hors rayon attribué")
		check(next(Rules.allocateEmitters(candidates, 0, 45)) == nil, "budget nul")
		local tie = Rules.allocateEmitters({ { id = "b", distance = 3, priority = 1 }, { id = "a", distance = 3, priority = 1 } }, 1, 45)
		check(tie["a"] == true, "égalité : ordre des identifiants")
	end)

	case("éclats : nombre selon le niveau d'effets", function(check)
		check(Rules.burstCount(10, 4, "full") == 10 and Rules.burstCount(10, 4, "low") == 10, "normal attendu")
		check(Rules.burstCount(10, 4, "reduced") == 4, "réduit attendu")
		check(Rules.burstCount(-2, -1, "full") == 0, "négatif accepté")
		check(Rules.burstCount(2.7, 1, "full") == 2, "nombre non entier")
	end)

	case("disparition : demande locale récente ou autre joueur (pas de double effet)", function(check)
		check(Rules.disappearance(10, 10.5) == "claimed", "demande locale en cours")
		check(Rules.disappearance(10, 10) == "claimed", "borne incluse")
		check(Rules.disappearance(10, 9.9) == "pop", "demande expirée")
		check(Rules.disappearance(10, nil) == "pop", "aucune demande locale")
	end)

	case("ResourceVFXConfig : effets par rareté (T10.2)", function(check)
		local R = ResourceVFXConfig.Rarities
		check(R.Common.idleParticles == nil and R.Common.aura == nil and R.Common.special == nil, "Commun : aucun effet coûteux")
		check(R.Common.spin == 0 and R.Common.pulse == 0, "Commun : ni rotation ni pulsation")
		check(R.Uncommon.idleParticles ~= nil and R.Uncommon.aura == nil, "Peu commun : petites particules seules")
		check(R.Rare.pulse >= 0.05, "Rare : pulsation visible (≥ 5 %)")
		check(R.Epic.aura ~= nil and R.Epic.idleParticles ~= nil and R.Epic.special ~= nil, "Épique : aura, particules, animation spéciale")
		check(R.Epic.idleParticles.lowQuality == true, "Épique : particules gardées en qualité basse")
		local order = { "Common", "Uncommon", "Rare", "Epic" }
		for index = 2, #order do
			local previous, current = R[order[index - 1]], R[order[index]]
			check(current.priority > previous.priority, `{order[index]} : priorité non croissante`)
			check(current.collectParticles >= previous.collectParticles, `{order[index]} : éclat moins fourni`)
		end
		for rarity, visual in pairs(R) do
			check(visual.reducedCollectParticles >= 1, `{rarity} : éclat réduit invisible`)
			check(visual.reducedCollectParticles < visual.collectParticles, `{rarity} : éclat réduit non réduit`)
			check(visual.reducedRespawnParticles <= visual.respawnParticles, `{rarity} : bouffée réduite plus forte`)
			local style = visual.idleParticles
			if style then
				check(style.rate > 0 and style.rate <= 4, `{rarity} : débit hors ]0, 4]`)
				check(style.lifetime[1] <= style.lifetime[2] and style.lifetime[2] <= 1.5, `{rarity} : durée de vie`)
				check(style.shape == "Point" or style.shape == "Ring", `{rarity} : forme inconnue`)
			end
		end
	end)

	case("ResourceVFXConfig : budgets VFX (T10_PERFORMANCE_BUDGET)", function(check)
		local C = ResourceVFXConfig
		check(C.MaxIdleEmitters.reduced == 0, "aucun émetteur d'attente en effets réduits")
		check(C.MaxIdleEmitters.low <= C.MaxIdleEmitters.full and C.MaxIdleEmitters.full <= 8, "émetteurs : 8 au plus")
		check(C.BurstPoolSize >= 6 and C.BurstPoolSize <= 8, "pool d'éclats : 6 à 8")
		check(C.MaxAuras <= 4, "auras : 4 au plus")
		-- Particules visibles au pire : attente + éclats (≤ 150).
		local maxIdle, maxBurst = 0, 0
		for _, visual in pairs(C.Rarities) do
			local style = visual.idleParticles
			if style then
				maxIdle = math.max(maxIdle, style.rate * style.lifetime[2])
			end
			maxBurst = math.max(maxBurst, visual.collectParticles, visual.respawnParticles)
		end
		local worst = C.MaxIdleEmitters.full * maxIdle + C.BurstPoolSize * maxBurst
		check(worst <= 150, `pire cas {worst} particules > 150`)
		check(C.PressScale > 0.5 and C.PressScale < 1 and C.PressSeconds <= 0.2, "écrasement discret et bref")
		check(C.PopSeconds <= 0.25 and C.RespawnSeconds <= 0.5, "animations brèves")
		check(C.RespawnStartScale > 0 and C.RespawnStartScale < 1, "échelle de reconstruction")
		check(C.LocalClaimSeconds > 0 and C.LocalClaimSeconds <= 2, "fenêtre de demande locale")
	end)

	return failures, caseCount
end

return ResourceFxTests
