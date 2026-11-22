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
--                 Réservé à la rareté Épique. Depuis T10.2 : couleur de
--                 l'aura et des particules jouées côté client
--                 (ResourceVFXController) ; `rate` n'est plus lu (débit :
--                 ResourceVFXConfig).
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
	model: ResourceModel?,
}

-- T10.1 (D-025 à D-027) : modèle 3D importé, facultatif. Chargé par
-- Systems/ResourceModelLoader ; la forme primitive ci-dessus reste le
-- repli et la hitbox serveur. Provenance : docs/assets/ASSET_MANIFEST.md.
--   template   : nom d'un modèle stocké dans le place, sous
--                ServerStorage.ResourceTemplates (import manuel Studio)
--   assetId    : ou asset Roblox (Model) du créateur de l'expérience
--                (exactement une des deux sources)
--   targetSize : plus grande dimension visée (studs)
--   parts      : facultatif ; surcharge par nom de pièce { color, material,
--                scale, exclude } ; `scale` agrandit la pièce autour de son
--                centre (]0, 2]) avant l'ajustement à `targetSize` ;
--                `exclude = true` retire la pièce du gabarit
export type ResourceModel = {
	template: string?,
	assetId: number?,
	targetSize: number,
	parts: { [string]: { color: Triple?, material: string?, scale: number?, exclude: boolean? } }?,
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

	-- Mystic World (T8.5 : modèles à plusieurs pièces, sans transparence)
	-- Poudre mystique : petit amas compact violet et lavande.
	mystic_dust = {
		shape = "Ball", size = { 1.5, 1.5, 1.5 }, color = { 176, 112, 240 }, orientation = { 0, 0, 0 }, material = "SmoothPlastic",
		details = {
			{ shape = "Ball", size = { 1, 1, 1 }, offset = { 0.75, -0.3, 0.3 }, orientation = { 0, 0, 0 }, color = { 214, 184, 255 }, material = "SmoothPlastic" },
			{ shape = "Ball", size = { 0.8, 0.8, 0.8 }, offset = { -0.6, -0.4, -0.5 }, orientation = { 0, 0, 0 }, color = { 150, 90, 220 }, material = "SmoothPlastic" },
			{ shape = "Ball", size = { 0.45, 0.45, 0.45 }, offset = { 0.1, 0.85, 0.1 }, orientation = { 0, 0, 0 }, color = { 240, 224, 255 }, material = "SmoothPlastic" },
		},
	},
	-- Éclat d'étoile : fragment angulaire bleu clair et cyan, facettes.
	star_fragment = {
		shape = "Wedge", size = { 1.3, 2.2, 1.6 }, color = { 120, 220, 255 }, orientation = { 0, 35, 0 }, material = "SmoothPlastic",
		details = {
			{ shape = "Wedge", size = { 1.1, 1.6, 1.2 }, offset = { 0, -0.3, 0 }, orientation = { 0, 215, 0 }, color = { 80, 236, 236 }, material = "SmoothPlastic" },
			{ shape = "Block", size = { 0.5, 0.9, 0.5 }, offset = { 0.7, -0.6, 0.55 }, orientation = { 30, 45, 20 }, color = { 200, 244, 255 }, material = "SmoothPlastic" },
		},
	},
	-- Minerai spectral : bloc rocheux sombre, inclusions cyan et violettes.
	spectral_ore = {
		shape = "Block", size = { 2, 1.7, 1.9 }, color = { 52, 46, 82 }, orientation = { 8, 25, 6 }, material = "Slate",
		details = {
			{ shape = "Block", size = { 0.55, 0.55, 0.55 }, offset = { 0.7, 0.6, 0.35 }, orientation = { 45, 30, 0 }, color = { 90, 240, 230 }, material = "SmoothPlastic" },
			{ shape = "Block", size = { 0.5, 0.5, 0.5 }, offset = { -0.65, 0.4, -0.55 }, orientation = { 30, 0, 45 }, color = { 190, 110, 255 }, material = "SmoothPlastic" },
			{ shape = "Block", size = { 0.45, 0.45, 0.45 }, offset = { 0.2, 0.8, -0.35 }, orientation = { 0, 45, 45 }, color = { 120, 250, 240 }, material = "SmoothPlastic" },
			{ shape = "Block", size = { 0.4, 0.4, 0.4 }, offset = { -0.9, -0.1, 0.5 }, orientation = { 45, 0, 30 }, color = { 210, 140, 255 }, material = "SmoothPlastic" },
		},
	},
	-- Cristal violet : grand prisme vertical facetté, deux pointes.
	purple_crystal = {
		shape = "Block", size = { 1.2, 3, 1.2 }, color = { 160, 60, 255 }, orientation = { 0, 45, 6 }, material = "Neon",
		details = {
			{ shape = "Block", size = { 0.7, 1.7, 0.7 }, offset = { 0.8, -0.6, 0.2 }, orientation = { 0, 30, -26 }, color = { 200, 120, 255 }, material = "Neon" },
			{ shape = "Block", size = { 0.6, 1.3, 0.6 }, offset = { -0.7, -0.8, -0.3 }, orientation = { 18, 10, 24 }, color = { 120, 40, 220 }, material = "Neon" },
		},
	},
	-- Cœur mystique : noyau géométrique magenta, facettes violettes, pointes
	-- magenta et cyan ; particules (seul émetteur du monde).
	mystic_core = {
		shape = "Block", size = { 2.2, 2.2, 2.2 }, color = { 255, 70, 200 }, orientation = { 45, 45, 0 }, material = "Neon",
		particles = { color = { 255, 150, 240 }, rate = 4 },
		details = {
			{ shape = "Block", size = { 1.8, 1.8, 1.8 }, offset = { 0, 0, 0 }, orientation = { 0, 45, 45 }, color = { 150, 70, 255 }, material = "Neon" },
			{ shape = "Block", size = { 0.5, 1.4, 0.5 }, offset = { 0, 1.9, 0 }, orientation = { 0, 45, 0 }, color = { 255, 150, 240 }, material = "Neon" },
			{ shape = "Block", size = { 0.5, 1.2, 0.5 }, offset = { 1.5, 0.4, 0 }, orientation = { 0, 0, -50 }, color = { 110, 250, 255 }, material = "Neon" },
			{ shape = "Block", size = { 0.5, 1.2, 0.5 }, offset = { -1.5, 0.4, 0 }, orientation = { 0, 0, 50 }, color = { 110, 250, 255 }, material = "Neon" },
		},
	},
}

-- Prototype T10.1 : une ressource par monde (D-025). Modèles Polyfork
-- CC BY 4.0 « modifiés » (manifeste : res_green_leaf, res_copper_ore,
-- res_silver_ore, res_purple_crystal) : GLB corrigés par
-- tools/fix_glb_colors.luau (couleurs de sommets linéaire -> sRGB, feuille
-- recolorée en vert), importés à la main dans le place. Les couleurs
-- viennent des sommets : pièces blanches (la couleur du Part les
-- multiplie). Cristal de l'améthyste en Neon (rareté Rare).
local WHITE = { 255, 255, 255 }
ResourceVisualConfig.green_leaf.model = {
	template = "green_leaf",
	targetSize = 1.8,
	parts = { ["leaf-mesh"] = { color = WHITE, material = "SmoothPlastic" } },
}
ResourceVisualConfig.copper_ore.model = {
	template = "copper_ore",
	targetSize = 1.8,
	parts = {
		["copper-ore-deposit-body"] = { color = WHITE, material = "SmoothPlastic" },
		["copper-ore-deposit-copper"] = { color = WHITE, material = "SmoothPlastic" },
	},
}
ResourceVisualConfig.silver_ore.model = {
	template = "silver_ore",
	targetSize = 1.9,
	parts = {
		["deposit-matte"] = { color = WHITE, material = "SmoothPlastic" },
		["deposit-metal"] = { color = WHITE, material = "Metal" },
	},
}
ResourceVisualConfig.purple_crystal.model = {
	template = "purple_crystal",
	targetSize = 2.4,
	parts = {
		["amethyst-ore-deposit-mesh"] = { color = WHITE, material = "SmoothPlastic" },
		-- Cristaux agrandis : ils doivent dominer la roche (hypothèse visuelle).
		["amethyst-ore-deposit-mesh2"] = { color = { 160, 60, 255 }, material = "Neon", scale = 1.6 },
	},
}

-- Import des 16 autres ressources (2026-11-22, autorisé par le
-- propriétaire) : même chaîne que le prototype (GLB corrigés, import
-- manuel, gabarits ServerStorage.ResourceTemplates). Manifeste :
-- res_<ressource>. Neon seulement pour Rare et Épique (cristaux, diamant,
-- orbe). `exclude` : pièces retirées du gabarit (touffes d'herbe
-- du tas de rochers, petites pièces de l'orbe ; budget ≤ 3 pièces par
-- nœud). Tailles et couleurs : hypothèses visuelles à valider.
local function plain(...: string): { [string]: { color: Triple?, material: string?, scale: number?, exclude: boolean? } }
	local parts = {}
	for _, name in ipairs({ ... }) do
		parts[name] = { color = WHITE, material = "SmoothPlastic" }
	end
	return parts
end
local function model(template: string, targetSize: number, parts: { [string]: any }): ResourceModel
	return { template = template, targetSize = targetSize, parts = parts }
end

-- Green Valley
ResourceVisualConfig.wood.model = model("wood", 2.6, plain("log"))
ResourceVisualConfig.stone.model = model("stone", 2, plain("rock"))
ResourceVisualConfig.wild_fruit.model = model("wild_fruit", 1.6, plain("Node1"))
ResourceVisualConfig.green_crystal.model = model("green_crystal", 2.4, {
	rock = { color = WHITE, material = "SmoothPlastic" },
	gem = { color = { 60, 230, 140 }, material = "Neon" },
})

-- Golden Desert
ResourceVisualConfig.sandstone.model = model("sandstone", 2.2, plain("outcrop"))
ResourceVisualConfig.fossil.model = model("fossil", 2.4, plain("ribcage"))
-- Pépite : couleurs de sommets (or) sans Neon : le Neon l'aplatissait en
-- tache jaune (contrôle visuel Studio) ; la rareté reste lisible par ses
-- effets (ResourceVFXConfig).
ResourceVisualConfig.gold_nugget.model = model("gold_nugget", 1.6, plain("nugget"))
ResourceVisualConfig.sun_crystal.model = model("sun_crystal", 2.6, {
	rock = { color = WHITE, material = "SmoothPlastic" },
	["crystal-cores"] = { color = WHITE, material = "SmoothPlastic" },
	["crystal-shells"] = { color = { 255, 150, 30 }, material = "Neon" },
})

-- Frozen Peaks
ResourceVisualConfig.ice_shard.model = model("ice_shard", 2, plain("crystal-shard-body"))
local frozenParts = plain("boulders")
for index = 1, 5 do
	frozenParts[`tuft-{index}-blades`] = { exclude = true }
end
ResourceVisualConfig.frozen_stone.model = model("frozen_stone", 2.2, frozenParts)
ResourceVisualConfig.blue_crystal.model = model("blue_crystal", 2.4, {
	rock = { color = WHITE, material = "SmoothPlastic" },
	["sapphire-crystals"] = { color = { 60, 140, 255 }, material = "Neon", scale = 1.4 },
})
ResourceVisualConfig.ice_diamond.model = model("ice_diamond", 1.8, {
	diamond = { color = { 190, 250, 255 }, material = "Neon" },
})

-- Mystic World
ResourceVisualConfig.mystic_dust.model = model("mystic_dust", 1.8, plain("chips"))
ResourceVisualConfig.star_fragment.model = model("star_fragment", 1.8, plain("meteorite-body"))
ResourceVisualConfig.spectral_ore.model = model("spectral_ore", 2.2, plain("shell", "crystals"))
ResourceVisualConfig.mystic_core.model = model("mystic_core", 2.2, {
	cradle = { color = WHITE, material = "SmoothPlastic" },
	["orb-crystal"] = { color = { 230, 120, 255 }, material = "Neon" },
	shards = { color = { 255, 120, 230 }, material = "Neon" },
	fittings = { exclude = true },
	gems = { exclude = true },
})

return TableUtil.deepFreeze(ResourceVisualConfig)
