--!strict
-- Présentation des ressources par rareté (T10.1, D-027) : animation
-- d'attente et intensité des effets côté client. Aucune valeur économique,
-- aucune règle de jeu ; la rareté elle-même vient de ResourceConfig.
--
-- Valeurs = hypothèses de confort (docs/assets/T10_VFX_DESIGN.md §3), à
-- valider sur Galaxy A23 et en « Effets réduits ».
--   bob        : amplitude du flottement (studs)
--   bobPeriod  : période du flottement (s)
--   spin       : rotation en lacet (degrés par seconde)
--   pulse      : variation d'échelle (fraction, 0 = aucune)
--   pulsePeriod: période de la pulsation (s)
--   collectParticles / reducedCollectParticles : éclat de collecte
--
-- « Effets réduits » : ni flottement, ni rotation, ni pulsation
-- (ResourceFxRules.idlePose).

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type RarityVisual = {
	bob: number,
	bobPeriod: number,
	spin: number,
	pulse: number,
	pulsePeriod: number,
	collectParticles: number,
	reducedCollectParticles: number,
}

local RarityVisualConfig = {
	Rarities = {
		Common = { bob = 0.15, bobPeriod = 2.8, spin = 0, pulse = 0, pulsePeriod = 1, collectParticles = 6, reducedCollectParticles = 3 },
		Uncommon = { bob = 0.2, bobPeriod = 2.6, spin = 10, pulse = 0, pulsePeriod = 1, collectParticles = 8, reducedCollectParticles = 3 },
		Rare = { bob = 0.25, bobPeriod = 2.4, spin = 20, pulse = 0, pulsePeriod = 1, collectParticles = 10, reducedCollectParticles = 4 },
		Epic = { bob = 0.3, bobPeriod = 2.2, spin = 25, pulse = 0.04, pulsePeriod = 1.6, collectParticles = 14, reducedCollectParticles = 5 },
	} :: { [string]: RarityVisual },

	-- Budget d'animation d'attente (T10_PERFORMANCE_BUDGET.md).
	MaxAnimatedNodes = 24,
	AnimationRadiusStuds = 60,
	AnimationHz = 30,
	-- Sélection des nœuds animés : recalculée à cette fréquence (s).
	SelectionRefreshSeconds = 0.5,
}

return TableUtil.deepFreeze(RarityVisualConfig)
