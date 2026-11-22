--!strict
-- Effets visuels des ressources par rareté (T10.1, D-027 ; étendu en
-- T10.2, D-032) : présence (flottement, rotation, pulsation, animation
-- spéciale), particules d'attente, aura, éclats de collecte et de
-- réapparition, budgets. Aucune valeur économique, aucune règle de jeu ;
-- la rareté vient de ResourceConfig. Lu par les contrôleurs clients
-- NodeVisuals et ResourceVFXController.
--
-- Valeurs = hypothèses de confort (docs/phases/T10_2_VFX_REPORT.md), à
-- valider sur Galaxy A23 et en « Effets réduits ».
--   bob, bobPeriod     : flottement (studs, s)
--   spin               : rotation en lacet (degrés par seconde)
--   pulse, pulsePeriod : variation d'échelle (fraction ; 0 = aucune), période (s)
--   special            : facultatif ; pirouette périodique (Épique) :
--                        { period (s), duration (s), hop (studs), turns }
--   idleParticles      : facultatif ; émetteur d'attente prêté par le pool
--                        { rate (/s), size, lifetime = {min, max},
--                          speed = {min, max}, shape = "Point"|"Ring",
--                          lowQuality (gardé en qualité basse) }
--   aura               : facultatif ; disque Neon opaque au sol (indice de
--                        rareté non coloré, GDD 12) { diameter, height }
--   collectParticles / reducedCollectParticles : éclat orienté vers le joueur
--   respawnParticles / reducedRespawnParticles : bouffée de reconstruction
--
-- Niveaux d'effets (ResourceFxRules.effectLevel) :
--   full    : tout ;
--   low     : qualité graphique Roblox basse (1 à LowQualityMax) : seules
--             les particules d'attente `lowQuality` restent ;
--   reduced : « Effets réduits » : ni animation d'attente, ni particules
--             d'attente ; aura statique conservée ; éclats réduits.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type Range = { number }

export type IdleParticles = {
	rate: number,
	size: number,
	lifetime: Range,
	speed: Range,
	shape: string,
	lowQuality: boolean,
}

export type Special = {
	period: number,
	duration: number,
	hop: number,
	turns: number,
}

export type RarityVisual = {
	priority: number,
	bob: number,
	bobPeriod: number,
	spin: number,
	pulse: number,
	pulsePeriod: number,
	special: Special?,
	idleParticles: IdleParticles?,
	aura: { diameter: number, height: number }?,
	collectParticles: number,
	reducedCollectParticles: number,
	respawnParticles: number,
	reducedRespawnParticles: number,
}

local ResourceVFXConfig = {
	Rarities = {
		-- Commun : aucun effet coûteux (flottement seul).
		Common = {
			priority = 0,
			bob = 0.15,
			bobPeriod = 2.8,
			spin = 0,
			pulse = 0,
			pulsePeriod = 1,
			collectParticles = 6,
			reducedCollectParticles = 3,
			respawnParticles = 0,
			reducedRespawnParticles = 0,
		},
		-- Peu commun : petites particules.
		Uncommon = {
			priority = 1,
			bob = 0.2,
			bobPeriod = 2.6,
			spin = 10,
			pulse = 0,
			pulsePeriod = 1,
			idleParticles = { rate = 1.5, size = 0.16, lifetime = { 0.8, 1.2 }, speed = { 0.4, 0.9 }, shape = "Point", lowQuality = false },
			collectParticles = 8,
			reducedCollectParticles = 3,
			respawnParticles = 4,
			reducedRespawnParticles = 2,
		},
		-- Rare : pulsation visible.
		Rare = {
			priority = 2,
			bob = 0.25,
			bobPeriod = 2.4,
			spin = 20,
			pulse = 0.06,
			pulsePeriod = 1.4,
			idleParticles = { rate = 2, size = 0.2, lifetime = { 0.8, 1.3 }, speed = { 0.5, 1 }, shape = "Point", lowQuality = false },
			collectParticles = 10,
			reducedCollectParticles = 4,
			respawnParticles = 6,
			reducedRespawnParticles = 2,
		},
		-- Épique : aura (disque au sol + anneau de particules), pirouette.
		Epic = {
			priority = 3,
			bob = 0.3,
			bobPeriod = 2.2,
			spin = 25,
			pulse = 0.04,
			pulsePeriod = 1.6,
			special = { period = 6, duration = 0.7, hop = 0.5, turns = 1 },
			idleParticles = { rate = 4, size = 0.25, lifetime = { 0.9, 1.4 }, speed = { 1, 2 }, shape = "Ring", lowQuality = true },
			aura = { diameter = 3, height = 0.12 },
			collectParticles = 14,
			reducedCollectParticles = 5,
			respawnParticles = 8,
			reducedRespawnParticles = 3,
		},
	} :: { [string]: RarityVisual },

	-- Animation d'attente (T10_PERFORMANCE_BUDGET.md) : nœuds les plus
	-- proches de la caméra seulement.
	MaxAnimatedNodes = 24,
	AnimationRadiusStuds = 60,
	AnimationHz = 30,
	-- Réattribution des nœuds animés, émetteurs et auras (s).
	SelectionRefreshSeconds = 0.5,

	-- Émetteurs d'attente prêtés (pool) par niveau d'effets ; priorité à la
	-- rareté, puis à la distance.
	MaxIdleEmitters = { full = 8, low = 3, reduced = 0 },
	IdleParticleRadiusStuds = 45,
	-- Auras (disques opaques, sans particules en « reduced ») : une par
	-- Épique proche.
	MaxAuras = 3,
	AuraRadiusStuds = 90,

	-- Éclats (collecte, réapparition) : pool partagé ; au-delà, pas de
	-- particules (le reste du retour est conservé).
	BurstPoolSize = 6,
	BurstLifetime = { 0.3, 0.45 },
	-- Collecte : cône vers le joueur (degrés) et vitesse (studs/s).
	CollectSpreadDegrees = 25,
	CollectSpeed = { 9, 14 },
	-- Retour immédiat à l'envoi d'une demande (avant la réponse serveur) :
	-- léger écrasement, sans masquer le nœud.
	PressScale = 0.9,
	PressSeconds = 0.12,
	-- Disparition vue par les autres joueurs (nœud pris par quelqu'un
	-- d'autre) : rétrécissement puis masquage.
	PopSeconds = 0.15,
	-- Réapparition : reconstruction depuis cette échelle (s).
	RespawnStartScale = 0.2,
	RespawnSeconds = 0.3,
	-- Délai pendant lequel une disparition est attribuée à la demande du
	-- joueur local (l'éclat de collecte suit) : pas de double effet (s).
	LocalClaimSeconds = 1,

	-- Qualité graphique Roblox (SavedQualityLevel 1..10) : niveau « low »
	-- jusqu'à cette valeur incluse ; « Automatic » = « full ».
	LowQualityMax = 3,
}

return TableUtil.deepFreeze(ResourceVFXConfig)
