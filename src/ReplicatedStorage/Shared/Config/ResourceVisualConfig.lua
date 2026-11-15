--!strict
-- Apparence des ressources collectables (T8, D-021) : silhouette, taille,
-- couleur, orientation et matériau, par identifiant de ResourceConfig.
-- Aucune valeur économique ici ; lu par Systems/ResourceNodes.
--
-- Données simples (pas d'Enum, Vector3 ni Color3) : le module se charge
-- hors Roblox (tests Lune). ResourceNodes convertit au moment de créer le
-- Part.
--   shape       : nom d'Enum.PartType (Ball, Block, Cylinder, Wedge)
--   size        : studs ; Ball : trois valeurs égales ; Cylinder : axe X
--   color       : RGB 0..255
--   orientation : degrés, appliqués après l'orientation du point de spawn
--   material    : nom d'Enum.Material
--   particles   : facultatif (T8.3) ; { color = RGB, rate = particules/s }.
--                 Un petit ParticleEmitter sur le nœud, coupé quand le nœud
--                 est collecté. Réservé à la rareté Épique (un nœud par
--                 monde : budget audit T8 de 2 émetteurs par monde).
--   details     : facultatif (T8.4) ; 4 petites pièces au plus, posées
--                 relativement au centre du nœud (orientation du nœud non
--                 appliquée) : { shape, size, offset, orientation, color,
--                 material }. Sans collision ni requête ; masquées avec le
--                 nœud. Même règle Neon que la pièce principale.
--
-- Règles (GDD 13, D-021) : silhouette ou couleur distincte au sein d'un monde,
-- tailles lisibles sur mobile (1,2 à 3 studs), Neon réservé aux raretés
-- Rare et Épique ; aucune lumière dynamique ; particules seulement pour
-- l'Épique (budget de performance).
-- Formes primitives provisoires : à remplacer par des assets contrôlés
-- (docs/assets/ASSET_MANIFEST.md) sans toucher à la logique.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type Triple = { number }

export type ResourceDetail = {
	shape: string,
	size: Triple,
	offset: Triple,
	orientation: Triple,
	color: Triple,
	material: string,
}

export type ResourceVisual = {
	shape: string,
	size: Triple,
	color: Triple,
	orientation: Triple,
	material: string,
	particles: { color: Triple, rate: number }?,
	details: { ResourceDetail }?,
}

local ResourceVisualConfig: { [string]: ResourceVisual } = {
	-- Green Valley
	green_leaf = { shape = "Ball", size = { 1.8, 1.8, 1.8 }, color = { 96, 204, 78 }, orientation = { 0, 0, 0 }, material = "SmoothPlastic" },
	wood = { shape = "Cylinder", size = { 2.6, 1.4, 1.4 }, color = { 150, 98, 56 }, orientation = { 0, 35, 0 }, material = "SmoothPlastic" },
	stone = { shape = "Block", size = { 2, 1.6, 2 }, color = { 138, 142, 150 }, orientation = { 0, 20, 8 }, material = "SmoothPlastic" },
	wild_fruit = { shape = "Ball", size = { 1.6, 1.6, 1.6 }, color = { 235, 90, 70 }, orientation = { 0, 0, 0 }, material = "SmoothPlastic" },
	green_crystal = { shape = "Block", size = { 1.2, 2.6, 1.2 }, color = { 60, 230, 140 }, orientation = { 0, 45, 15 }, material = "Neon" },

	-- Golden Desert
	sandstone = { shape = "Block", size = { 2.2, 1.4, 2.2 }, color = { 226, 190, 120 }, orientation = { 0, 15, 0 }, material = "SmoothPlastic" },
	copper_ore = { shape = "Block", size = { 1.8, 1.6, 1.8 }, color = { 196, 110, 60 }, orientation = { 10, 30, 10 }, material = "SmoothPlastic" },
	fossil = { shape = "Cylinder", size = { 2.4, 1.2, 1.2 }, color = { 232, 222, 196 }, orientation = { 0, 60, 0 }, material = "SmoothPlastic" },
	gold_nugget = { shape = "Ball", size = { 1.6, 1.6, 1.6 }, color = { 255, 196, 40 }, orientation = { 0, 0, 0 }, material = "Neon" },
	sun_crystal = { shape = "Block", size = { 1.4, 3, 1.4 }, color = { 255, 150, 30 }, orientation = { 0, 45, 15 }, material = "Neon", particles = { color = { 255, 210, 90 }, rate = 4 } },

	-- Frozen Peaks (T8.4 : modèles à plusieurs pièces, sans transparence)
	-- Éclat de glace : fragment anguleux cyan pâle, deux facettes.
	ice_shard = {
		shape = "Wedge", size = { 1.4, 2, 2 }, color = { 170, 228, 255 }, orientation = { 0, 25, 0 }, material = "SmoothPlastic",
		details = {
			{ shape = "Wedge", size = { 0.9, 1.3, 1.2 }, offset = { 0.6, -0.35, 0.4 }, orientation = { 0, 150, 0 }, color = { 215, 246, 255 }, material = "SmoothPlastic" },
		},
	},
	-- Minerai d'argent : roche grise à inclusions argentées.
	silver_ore = {
		shape = "Block", size = { 1.9, 1.5, 1.8 }, color = { 118, 122, 134 }, orientation = { 8, 30, 6 }, material = "SmoothPlastic",
		details = {
			{ shape = "Block", size = { 0.55, 0.55, 0.55 }, offset = { 0.65, 0.55, 0.35 }, orientation = { 45, 30, 0 }, color = { 228, 232, 242 }, material = "Metal" },
			{ shape = "Block", size = { 0.5, 0.5, 0.5 }, offset = { -0.6, 0.35, -0.6 }, orientation = { 30, 0, 45 }, color = { 214, 220, 232 }, material = "Metal" },
			{ shape = "Block", size = { 0.45, 0.45, 0.45 }, offset = { 0.1, 0.75, -0.2 }, orientation = { 0, 45, 45 }, color = { 240, 242, 250 }, material = "Metal" },
		},
	},
	-- Pierre gelée : bloc gris foncé, plaques et pointe de glace.
	frozen_stone = {
		shape = "Block", size = { 2.2, 1.8, 2.2 }, color = { 78, 84, 98 }, orientation = { 0, 20, 6 }, material = "SmoothPlastic",
		details = {
			{ shape = "Block", size = { 1.5, 0.3, 1.3 }, offset = { 0.15, 0.95, 0.1 }, orientation = { 0, 20, 4 }, color = { 196, 232, 250 }, material = "SmoothPlastic" },
			{ shape = "Block", size = { 0.3, 0.9, 1 }, offset = { 1.05, 0.1, -0.3 }, orientation = { 0, 20, 0 }, color = { 176, 222, 246 }, material = "SmoothPlastic" },
			{ shape = "Wedge", size = { 0.5, 0.8, 0.6 }, offset = { -0.5, 1.4, -0.3 }, orientation = { 0, 60, 0 }, color = { 210, 240, 255 }, material = "SmoothPlastic" },
		},
	},
	-- Cristal bleu : grappe facettée (prisme central et deux pointes).
	blue_crystal = {
		shape = "Block", size = { 1.2, 2.6, 1.2 }, color = { 60, 140, 255 }, orientation = { 0, 45, 8 }, material = "Neon",
		details = {
			{ shape = "Block", size = { 0.7, 1.6, 0.7 }, offset = { 0.75, -0.55, 0.2 }, orientation = { 0, 30, -28 }, color = { 110, 180, 255 }, material = "Neon" },
			{ shape = "Block", size = { 0.6, 1.3, 0.6 }, offset = { -0.65, -0.7, -0.3 }, orientation = { 20, 10, 26 }, color = { 40, 110, 230 }, material = "Neon" },
		},
	},
	-- Diamant de glace : facettes cyan et bleues superposées, particules.
	ice_diamond = {
		shape = "Block", size = { 1.6, 1.6, 1.6 }, color = { 190, 250, 255 }, orientation = { 45, 45, 0 }, material = "Neon",
		particles = { color = { 210, 245, 255 }, rate = 4 },
		details = {
			{ shape = "Block", size = { 1.25, 1.25, 1.25 }, offset = { 0, 0, 0 }, orientation = { 0, 45, 45 }, color = { 70, 200, 255 }, material = "Neon" },
		},
	},

	-- Mystic World
	mystic_dust = { shape = "Ball", size = { 1.6, 1.6, 1.6 }, color = { 190, 120, 255 }, orientation = { 0, 0, 0 }, material = "SmoothPlastic" },
	star_fragment = { shape = "Wedge", size = { 1.6, 1.6, 1.6 }, color = { 255, 240, 150 }, orientation = { 0, 30, 0 }, material = "SmoothPlastic" },
	spectral_ore = { shape = "Block", size = { 1.8, 1.8, 1.8 }, color = { 120, 230, 220 }, orientation = { 15, 30, 15 }, material = "SmoothPlastic" },
	purple_crystal = { shape = "Block", size = { 1.2, 2.8, 1.2 }, color = { 170, 60, 255 }, orientation = { 0, 45, 15 }, material = "Neon" },
	mystic_core = { shape = "Ball", size = { 2.2, 2.2, 2.2 }, color = { 255, 80, 200 }, orientation = { 0, 0, 0 }, material = "Neon" },
}

return TableUtil.deepFreeze(ResourceVisualConfig)
