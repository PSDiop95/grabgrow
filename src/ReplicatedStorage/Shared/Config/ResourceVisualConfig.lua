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
--
-- Règles (GDD 13, D-021) : silhouette ou couleur distincte au sein d'un monde,
-- tailles lisibles sur mobile (1,2 à 3 studs), Neon réservé aux raretés
-- Rare et Épique ; aucune lumière ni particule (budget de performance).
-- Formes primitives provisoires : à remplacer par des assets contrôlés
-- (docs/assets/ASSET_MANIFEST.md) sans toucher à la logique.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type Triple = { number }

export type ResourceVisual = {
	shape: string,
	size: Triple,
	color: Triple,
	orientation: Triple,
	material: string,
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
	sun_crystal = { shape = "Block", size = { 1.4, 3, 1.4 }, color = { 255, 150, 30 }, orientation = { 0, 45, 15 }, material = "Neon" },

	-- Frozen Peaks
	ice_shard = { shape = "Wedge", size = { 1.4, 2, 2 }, color = { 170, 225, 255 }, orientation = { 0, 25, 0 }, material = "SmoothPlastic" },
	silver_ore = { shape = "Block", size = { 1.8, 1.6, 1.8 }, color = { 200, 205, 215 }, orientation = { 10, 30, 10 }, material = "SmoothPlastic" },
	frozen_stone = { shape = "Block", size = { 2.2, 1.8, 2.2 }, color = { 120, 150, 200 }, orientation = { 0, 20, 8 }, material = "SmoothPlastic" },
	blue_crystal = { shape = "Block", size = { 1.2, 2.6, 1.2 }, color = { 60, 140, 255 }, orientation = { 0, 45, 15 }, material = "Neon" },
	ice_diamond = { shape = "Block", size = { 1.6, 1.6, 1.6 }, color = { 190, 250, 255 }, orientation = { 45, 45, 0 }, material = "Neon" },

	-- Mystic World
	mystic_dust = { shape = "Ball", size = { 1.6, 1.6, 1.6 }, color = { 190, 120, 255 }, orientation = { 0, 0, 0 }, material = "SmoothPlastic" },
	star_fragment = { shape = "Wedge", size = { 1.6, 1.6, 1.6 }, color = { 255, 240, 150 }, orientation = { 0, 30, 0 }, material = "SmoothPlastic" },
	spectral_ore = { shape = "Block", size = { 1.8, 1.8, 1.8 }, color = { 120, 230, 220 }, orientation = { 15, 30, 15 }, material = "SmoothPlastic" },
	purple_crystal = { shape = "Block", size = { 1.2, 2.8, 1.2 }, color = { 170, 60, 255 }, orientation = { 0, 45, 15 }, material = "Neon" },
	mystic_core = { shape = "Ball", size = { 2.2, 2.2, 2.2 }, color = { 255, 80, 200 }, orientation = { 0, 0, 0 }, material = "Neon" },
}

return TableUtil.deepFreeze(ResourceVisualConfig)
