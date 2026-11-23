--!strict
-- Gardiens et sites sacrés (T10.3, D-028, addendum T10-D01 à T10-D03, D-034).
--
-- Combat PvE INDIVIDUEL : chaque joueur a son propre état de combat sur le
-- serveur (PV du gardien, éclats, attaques, victoire). Le modèle du gardien
-- est UN modèle statique par site, commun à tous ; chaque client l'anime
-- localement pour SON combat (GuardianController). Aucun état partagé.
--
-- Partagé client/serveur : le client lit les durées et les formes pour
-- dessiner les télégraphies ; le serveur reste seul juge (positions vues
-- par le serveur, touches, PV, victoire). Les marges de sécurité sont dans
-- ServerStorage.ServerOnlyConfig.GuardianSecurityConfig.
--
-- TOUTES les valeurs sont des HYPOTHÈSES DE GAMEPLAY (durée cible 60-90 s,
-- faisable seul), à régler en test réel. AUCUNE valeur économique ici :
-- récompenses en Coins et ressources sacrées non fixées (D-030, T10-D03).
--
-- Formes d'attaque (GuardianRules.isHit) :
--   ring   : anneau autour du gardien (innerRadius, outerRadius)
--   circle : disques visés sur la position du joueur à l'annonce
--            (count, radius, spread ; lingerSeconds : zone qui reste active)
--   line   : rectangle depuis le gardien vers le joueur (width, length)
--   cone   : secteur depuis le gardien vers le joueur (angleDegrees, radius)

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type AttackDefinition = {
	id: string,
	shape: string,
	nameKey: string,
	-- Annonce visuelle avant l'impact (fenêtre d'esquive).
	telegraphSeconds: number,
	innerRadius: number?,
	outerRadius: number?,
	radius: number?,
	count: number?,
	spread: number?,
	width: number?,
	length: number?,
	angleDegrees: number?,
	lingerSeconds: number?,
	-- Couleur de la télégraphie (affichage).
	color: { number }, -- RGB 0..255
}

export type GuardianDefinition = {
	worldId: string,
	siteId: string,
	nameKey: string,
	maxHealth: number,
	-- Délai entre deux attaques, par phase (1 à 3).
	attackIntervalSeconds: { number },
	-- Attaques disponibles par phase (identifiants de `attacks`).
	phaseAttacks: { { string } },
	attacks: { [string]: AttackDefinition },
	-- Couleur d'accent du gardien et des éclats (affichage).
	accent: { number }, -- RGB 0..255
}

export type SiteDefinition = {
	worldId: string,
	guardianId: string,
	nameKey: string,
	order: number,
}

local Combat = {
	-- Réveil du gardien après l'activation (aucune attaque pendant ce temps).
	awakeningSeconds = 3,
	-- Seuils de phase (fraction de PV restante) : phase 2 sous 66 %, 3 sous 33 %.
	phaseThresholds = { 0.66, 0.33 },
	-- Éclats de faiblesse : saisis avec le bouton de collecte (« Grab »).
	shards = {
		activeCount = 4,
		damage = 1,
		respawnSeconds = 2.5,
		-- Distance au centre de l'arène où apparaissent les éclats.
		minRadius = 9,
		maxRadius = 20,
		-- Portée nominale de saisie d'un éclat (indépendante du Magnet :
		-- le combat ne dépend pas des améliorations).
		grabRangeStuds = 10,
		-- Intervalle minimal entre deux saisies.
		minIntervalSeconds = 0.35,
	},
	-- Touche reçue : étourdi (aucune saisie) et repoussé. Ni PV de l'avatar,
	-- ni sac, ni Coins ne sont touchés.
	hit = {
		stunSeconds = 1.5,
		-- Recul maximal, vers l'extérieur de l'arène (A-7, 2026-11-23).
		knockbackStuds = 18,
		-- Distance au centre que le recul ne fait jamais dépasser (borne
		-- serveur, puis client). Le sol des sites s'arrête vers 30 studs,
		-- vide au-delà : 6 studs de marge pour la latence et le dépassement
		-- mesuré en Studio (jusqu'à 1,8 stud au-delà de la borne).
		maxRadiusStuds = 24,
		-- Durée du recul côté client (vitesse = distance / durée, environ
		-- 40 studs/s au maximum : dans les marges de MovementSecurityConfig).
		knockbackSeconds = 0.45,
	},
	arena = {
		-- Rayon de l'arène (combat) autour du centre du site.
		radius = 28,
		-- Hors de l'arène plus longtemps : combat abandonné, rien n'est attribué.
		leaveGraceSeconds = 20,
		-- Portée de l'autel pour activer le combat.
		altarRangeStuds = 12,
	},
	-- Après une victoire, délai avant que le gardien réapparaisse pour CE
	-- joueur (nouveau combat possible). Mémoire de session seulement.
	respawnSeconds = 45,
	-- Fréquence de la boucle serveur, pendant les combats seulement.
	tickSeconds = 0.1,
}

local Guardians: { [string]: GuardianDefinition } = {
	ForestGuardian = {
		worldId = "GreenValley",
		siteId = "RootSanctuary",
		nameKey = "guardian.forest",
		maxHealth = 24,
		attackIntervalSeconds = { 4.2, 3.8, 3.4 },
		phaseAttacks = { { "root_slam" }, { "root_slam", "root_lines" }, { "root_lines", "root_slam" } },
		accent = { 120, 200, 90 },
		attacks = {
			-- Attaque de proximité : anneau autour du gardien.
			root_slam = {
				id = "root_slam",
				shape = "ring",
				nameKey = "guardian.attack.root_slam",
				telegraphSeconds = 1.5,
				innerRadius = 0,
				outerRadius = 12,
				color = { 150, 95, 50 },
			},
			-- Projection de racines : ligne vers le joueur.
			root_lines = {
				id = "root_lines",
				shape = "line",
				nameKey = "guardian.attack.root_lines",
				telegraphSeconds = 1.5,
				width = 6,
				length = 30,
				color = { 110, 170, 60 },
			},
		},
	},

	SandGuardian = {
		worldId = "GoldenDesert",
		siteId = "SunTemple",
		nameKey = "guardian.sand",
		maxHealth = 30,
		attackIntervalSeconds = { 4.0, 3.5, 3.1 },
		phaseAttacks = { { "sand_sweep" }, { "sand_sweep", "rock_throw" }, { "rock_throw", "sand_sweep" } },
		accent = { 235, 185, 80 },
		attacks = {
			-- Balayage : secteur devant le gardien, vers le joueur.
			sand_sweep = {
				id = "sand_sweep",
				shape = "cone",
				nameKey = "guardian.attack.sand_sweep",
				telegraphSeconds = 1.5,
				angleDegrees = 100,
				radius = 18,
				color = { 230, 170, 70 },
			},
			-- Projection de rochers : disques sur la position du joueur.
			rock_throw = {
				id = "rock_throw",
				shape = "circle",
				nameKey = "guardian.attack.rock_throw",
				telegraphSeconds = 1.5,
				count = 3,
				radius = 5,
				spread = 7,
				color = { 160, 110, 70 },
			},
		},
	},

	IceGuardian = {
		worldId = "FrozenPeaks",
		siteId = "FrostAltar",
		nameKey = "guardian.ice",
		maxHealth = 36,
		attackIntervalSeconds = { 3.8, 3.3, 2.9 },
		phaseAttacks = { { "ice_charge" }, { "ice_charge", "ice_wave" }, { "ice_wave", "frost_field", "ice_charge" } },
		accent = { 140, 215, 255 },
		attacks = {
			-- Charge : longue ligne vers le joueur.
			ice_charge = {
				id = "ice_charge",
				shape = "line",
				nameKey = "guardian.attack.ice_charge",
				telegraphSeconds = 1.5,
				width = 8,
				length = 34,
				color = { 120, 200, 255 },
			},
			-- Vague de glace : anneau large, centre sûr.
			ice_wave = {
				id = "ice_wave",
				shape = "ring",
				nameKey = "guardian.attack.ice_wave",
				telegraphSeconds = 1.6,
				innerRadius = 10,
				outerRadius = 22,
				color = { 180, 235, 255 },
			},
			-- Zones dangereuses au sol : disques qui restent actifs.
			frost_field = {
				id = "frost_field",
				shape = "circle",
				nameKey = "guardian.attack.frost_field",
				telegraphSeconds = 1.5,
				count = 3,
				radius = 4.5,
				spread = 9,
				lingerSeconds = 3,
				color = { 90, 170, 235 },
			},
		},
	},

	MysticGuardian = {
		worldId = "MysticWorld",
		siteId = "AstralSanctuary",
		nameKey = "guardian.mystic",
		maxHealth = 42,
		attackIntervalSeconds = { 3.6, 3.1, 2.7 },
		phaseAttacks = { { "star_bolts" }, { "star_bolts", "astral_nova" }, { "astral_nova", "star_bolts" } },
		accent = { 200, 120, 255 },
		attacks = {
			-- Projectiles énergétiques : plusieurs disques autour du joueur.
			star_bolts = {
				id = "star_bolts",
				shape = "circle",
				nameKey = "guardian.attack.star_bolts",
				telegraphSeconds = 1.5,
				count = 4,
				radius = 4,
				spread = 8,
				color = { 220, 140, 255 },
			},
			-- Attaque de zone : anneau extérieur, refuge près du gardien.
			astral_nova = {
				id = "astral_nova",
				shape = "ring",
				nameKey = "guardian.attack.astral_nova",
				telegraphSeconds = 1.7,
				innerRadius = 8,
				outerRadius = 28,
				color = { 170, 90, 255 },
			},
		},
	},
}

local Sites: { [string]: SiteDefinition } = {
	RootSanctuary = { worldId = "GreenValley", guardianId = "ForestGuardian", nameKey = "site.root_sanctuary", order = 1 },
	SunTemple = { worldId = "GoldenDesert", guardianId = "SandGuardian", nameKey = "site.sun_temple", order = 2 },
	FrostAltar = { worldId = "FrozenPeaks", guardianId = "IceGuardian", nameKey = "site.frost_altar", order = 3 },
	AstralSanctuary = { worldId = "MysticWorld", guardianId = "MysticGuardian", nameKey = "site.astral_sanctuary", order = 4 },
}

-- Ressources sacrées : définitions dans Config/SacredResourceConfig (D-035,
-- hors ResourceConfig). Ici : seulement le geste de réclamation.
local SacredResources = {
	-- Portée de réclamation sur un nœud sacré (terrasse de récompense).
	grabRangeStuds = 10,
}

local GuardianConfig = {
	Combat = Combat,
	Guardians = Guardians,
	Sites = Sites,
	SacredResources = SacredResources,
	-- Nom des dossiers de la carte (build_sacred_sites.luau).
	MapFolderName = "SacredSites",
}

return TableUtil.deepFreeze(GuardianConfig)
