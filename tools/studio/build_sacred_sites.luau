--!nocheck
-- Quatre sites sacrés (T10.3, D-034) en primitives scriptées : une
-- plateforme d'arène par monde, reliée à l'île par un pont, avec autel
-- (point d'activation), gardien (modèle COMMUN, statique côté serveur,
-- animé localement par chaque client pour son propre combat), terrasse de
-- récompense et nœuds sacrés (inactifs tant que T10-D03 n'est pas validée).
--
-- Outil de développement, absent du jeu (non mappé dans
-- default.project.json). À exécuter dans Roblox Studio en mode Edit (barre
-- de commande ou serveur MCP). Rejouable : remplace seulement
-- Workspace.SacredSites ; ne touche ni à Workspace.Map, ni aux points de
-- spawn, de vente ou d'arrivée. Aucun asset externe, aucun texte ni logo,
-- aucune lumière dynamique, aucun émetteur, CastShadow coupé, tout ancré.
--
-- Crée (lu par le jeu, Systems/SacredSites et GuardianController) :
--   Workspace.SacredSites.<siteId>  (Model, attribut SiteId)
--     Center    Part invisible : centre de l'arène, au niveau du sol
--     Altar     Part : point d'activation (attribut SacredAltar)
--     Guardian  Model (PrimaryPart GuardianRoot au sol, face vers -Z)
--     RewardZone/SacredNode_<n>  attributs SacredNodeId, SacredResourceId
--     Arena, Decor, Bridge        décor
-- Gardiens en primitives : repli en attendant les modèles Polyfork
-- (sélection T10.0 ; import manuel requis, non fait dans ce lot).
--
-- Budget : ≤ 300 BaseParts par site (contrôlé à la fin).

local Workspace = game:GetService("Workspace")

local FOLDER_NAME = "SacredSites"
local PART_BUDGET = 300
local PLATFORM_RADIUS = 32
local ARENA_RADIUS = 28
local ALTAR_DISTANCE = 23
local REWARD_DISTANCE = 46
local REWARD_RADIUS = 10

local rng = Random.new(20261122)

local THEMES = {
	{
		siteId = "RootSanctuary",
		guardianId = "ForestGuardian",
		sacredId = "sacred_heartwood_seed",
		kind = "forest",
		center = Vector3.new(-175, 0, 175),
		-- Point de départ du pont, sur l'île.
		bridgeFrom = Vector3.new(-140, 0, 140),
		floor = { color = Color3.fromRGB(86, 140, 62), material = Enum.Material.Grass },
		edge = { color = Color3.fromRGB(110, 84, 58), material = Enum.Material.Rock },
		accent = Color3.fromRGB(120, 220, 90),
		floating = false,
	},
	{
		siteId = "SunTemple",
		guardianId = "SandGuardian",
		sacredId = "sacred_sun_relic",
		kind = "sand",
		center = Vector3.new(2850, 0, 150),
		bridgeFrom = Vector3.new(2890, 0, 110),
		floor = { color = Color3.fromRGB(222, 190, 128), material = Enum.Material.Sandstone },
		edge = { color = Color3.fromRGB(180, 140, 90), material = Enum.Material.Sandstone },
		accent = Color3.fromRGB(255, 190, 60),
		floating = false,
	},
	{
		siteId = "FrostAltar",
		guardianId = "IceGuardian",
		sacredId = "sacred_frost_heart",
		kind = "ice",
		center = Vector3.new(-2850, 0, 150),
		bridgeFrom = Vector3.new(-2884, 0, 116),
		floor = { color = Color3.fromRGB(200, 228, 245), material = Enum.Material.Glacier },
		edge = { color = Color3.fromRGB(150, 175, 195), material = Enum.Material.Slate },
		accent = Color3.fromRGB(120, 220, 255),
		floating = false,
	},
	{
		siteId = "AstralSanctuary",
		guardianId = "MysticGuardian",
		sacredId = "sacred_astral_essence",
		kind = "mystic",
		center = Vector3.new(10, 4, 3168),
		bridgeFrom = Vector3.new(10, 4, 3106),
		floor = { color = Color3.fromRGB(70, 52, 110), material = Enum.Material.Slate },
		edge = { color = Color3.fromRGB(48, 36, 80), material = Enum.Material.Slate },
		accent = Color3.fromRGB(205, 130, 255),
		floating = true,
	},
}

local function newPart(parent: Instance, props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className)
	part.Anchored = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "ClassName" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Disque horizontal (cylindre couché) : dessus à `top`.
local function disc(parent, name, center: Vector3, radius: number, thickness: number, top: number, look)
	return newPart(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center.X, top - thickness / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = look.color,
		Material = look.material,
	})
end

-- Bloc entre deux points au sol (pont, allée) : dessus à `top`.
local function span(parent, name, from: Vector3, to: Vector3, width: number, thickness: number, top: number, look)
	local a = Vector3.new(from.X, top - thickness / 2, from.Z)
	local b = Vector3.new(to.X, top - thickness / 2, to.Z)
	local length = (b - a).Magnitude
	return newPart(parent, {
		Name = name,
		Size = Vector3.new(width, thickness, length),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = look.color,
		Material = look.material,
	})
end

-- Gardiens -------------------------------------------------------------------
-- Construits en coordonnées locales (origine au sol, face vers -Z), puis
-- placés au centre. Aucune collision : le combat ne dépend pas du modèle.

local function guardianPart(model, root: CFrame, props)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	if props.localCFrame then
		props.CFrame = root * props.localCFrame
		props.localCFrame = nil
	end
	return newPart(model, props)
end

local function buildForest(model, root, accent)
	local wood = { Color = Color3.fromRGB(112, 78, 48), Material = Enum.Material.Wood }
	local moss = { Color = Color3.fromRGB(78, 150, 60), Material = Enum.Material.Grass }
	local function p(name, size, cf, look, shape)
		guardianPart(model, root, {
			Name = name, Size = size, localCFrame = cf, Color = look.Color, Material = look.Material, Shape = shape,
		})
	end
	p("LegL", Vector3.new(3, 6, 3), CFrame.new(-2.6, 3, 0), wood)
	p("LegR", Vector3.new(3, 6, 3), CFrame.new(2.6, 3, 0), wood)
	p("RootFootL", Vector3.new(4.5, 1.2, 5), CFrame.new(-2.8, 0.6, -0.6), wood)
	p("RootFootR", Vector3.new(4.5, 1.2, 5), CFrame.new(2.8, 0.6, -0.6), wood)
	p("Torso", Vector3.new(9, 7, 5.5), CFrame.new(0, 9.5, 0), wood)
	p("MossBack", Vector3.new(9.4, 2, 6), CFrame.new(0, 13.2, 0.3), moss)
	p("Head", Vector3.new(4.5, 4, 4), CFrame.new(0, 15.2, -0.6), wood)
	guardianPart(model, root, {
		Name = "EyeL", Size = Vector3.new(0.9, 0.9, 0.4), localCFrame = CFrame.new(-1, 15.6, -2.65),
		Color = Color3.fromRGB(255, 190, 70), Material = Enum.Material.Neon,
	})
	guardianPart(model, root, {
		Name = "EyeR", Size = Vector3.new(0.9, 0.9, 0.4), localCFrame = CFrame.new(1, 15.6, -2.65),
		Color = Color3.fromRGB(255, 190, 70), Material = Enum.Material.Neon,
	})
	p("ArmL", Vector3.new(7.5, 2.4, 2.4), CFrame.new(-6, 9.5, -0.5) * CFrame.Angles(0, 0, math.rad(70)), wood, Enum.PartType.Cylinder)
	p("ArmR", Vector3.new(7.5, 2.4, 2.4), CFrame.new(6, 9.5, -0.5) * CFrame.Angles(0, 0, math.rad(-70)), wood, Enum.PartType.Cylinder)
	p("FistL", Vector3.new(3.4, 3.4, 3.4), CFrame.new(-7.2, 5.6, -0.8), moss)
	p("FistR", Vector3.new(3.4, 3.4, 3.4), CFrame.new(7.2, 5.6, -0.8), moss)
	p("LeafL", Vector3.new(4, 4, 4), CFrame.new(-5, 13.6, 0), moss, Enum.PartType.Ball)
	p("LeafR", Vector3.new(4, 4, 4), CFrame.new(5, 13.6, 0), moss, Enum.PartType.Ball)
	p("Crown", Vector3.new(5, 3, 5), CFrame.new(0, 17.8, 0), moss, Enum.PartType.Ball)
	guardianPart(model, root, {
		Name = "HeartCore", Size = Vector3.new(1.6, 1.6, 0.4), localCFrame = CFrame.new(0, 10.4, -2.85),
		Color = accent, Material = Enum.Material.Neon,
	})
end

local function buildSand(model, root, accent)
	local stone = { Color = Color3.fromRGB(205, 165, 105), Material = Enum.Material.Sandstone }
	local dark = { Color = Color3.fromRGB(150, 112, 72), Material = Enum.Material.Slate }
	local function p(name, size, cf, look, shape)
		guardianPart(model, root, {
			Name = name, Size = size, localCFrame = cf, Color = look.Color, Material = look.Material, Shape = shape,
		})
	end
	p("Base", Vector3.new(8, 2, 6), CFrame.new(0, 1, 0), dark)
	p("LegL", Vector3.new(3.2, 5, 3.2), CFrame.new(-2.4, 4.5, 0), stone)
	p("LegR", Vector3.new(3.2, 5, 3.2), CFrame.new(2.4, 4.5, 0), stone)
	p("Hips", Vector3.new(8, 2.4, 5), CFrame.new(0, 8, 0), dark)
	p("Chest", Vector3.new(10, 6, 6), CFrame.new(0, 12, 0), stone)
	p("ShoulderL", Vector3.new(4, 3, 4), CFrame.new(-6.6, 14, 0), dark)
	p("ShoulderR", Vector3.new(4, 3, 4), CFrame.new(6.6, 14, 0), dark)
	p("ArmL", Vector3.new(2.8, 6, 2.8), CFrame.new(-7, 9.5, -0.4), stone)
	p("ArmR", Vector3.new(2.8, 6, 2.8), CFrame.new(7, 9.5, -0.4), stone)
	p("FistL", Vector3.new(4.2, 4, 4.2), CFrame.new(-7.2, 5.4, -0.6), dark)
	p("FistR", Vector3.new(4.2, 4, 4.2), CFrame.new(7.2, 5.4, -0.6), dark)
	p("Head", Vector3.new(4, 3.6, 4), CFrame.new(0, 17, -0.4), stone)
	p("Crest", Vector3.new(5, 1, 1.2), CFrame.new(0, 19.3, -0.4), dark)
	guardianPart(model, root, {
		Name = "Visor", Size = Vector3.new(3, 0.7, 0.4), localCFrame = CFrame.new(0, 17.4, -2.5),
		Color = accent, Material = Enum.Material.Neon,
	})
	guardianPart(model, root, {
		Name = "SunCrack", Size = Vector3.new(0.6, 4, 0.3), localCFrame = CFrame.new(0, 12, -3.1),
		Color = accent, Material = Enum.Material.Neon,
	})
	guardianPart(model, root, {
		Name = "SunCrack2", Size = Vector3.new(4, 0.6, 0.3), localCFrame = CFrame.new(0, 12.6, -3.1),
		Color = accent, Material = Enum.Material.Neon,
	})
end

local function buildIce(model, root, accent)
	local ice = { Color = Color3.fromRGB(170, 215, 240), Material = Enum.Material.Ice }
	local deep = { Color = Color3.fromRGB(110, 160, 205), Material = Enum.Material.Glacier }
	local function p(name, size, cf, look, shape)
		guardianPart(model, root, {
			Name = name, Size = size, localCFrame = cf, Color = look.Color, Material = look.Material, Shape = shape,
		})
	end
	p("LegL", Vector3.new(3.6, 6, 3.6), CFrame.new(-2.8, 3, 0), deep)
	p("LegR", Vector3.new(3.6, 6, 3.6), CFrame.new(2.8, 3, 0), deep)
	p("Body", Vector3.new(10, 8, 7), CFrame.new(0, 10, 0.4), ice)
	p("Belly", Vector3.new(7, 4, 1), CFrame.new(0, 9, -3.3), deep)
	p("Head", Vector3.new(5, 4, 4.6), CFrame.new(0, 15.6, -1), ice)
	p("Jaw", Vector3.new(4.4, 1.4, 3), CFrame.new(0, 13.6, -2), deep)
	guardianPart(model, root, {
		Name = "EyeL", Size = Vector3.new(1, 0.8, 0.4), localCFrame = CFrame.new(-1.2, 16.2, -3.35),
		Color = accent, Material = Enum.Material.Neon,
	})
	guardianPart(model, root, {
		Name = "EyeR", Size = Vector3.new(1, 0.8, 0.4), localCFrame = CFrame.new(1.2, 16.2, -3.35),
		Color = accent, Material = Enum.Material.Neon,
	})
	p("ArmL", Vector3.new(3.4, 8, 3.4), CFrame.new(-7, 9.2, -0.2) * CFrame.Angles(0, 0, math.rad(-8)), deep)
	p("ArmR", Vector3.new(3.4, 8, 3.4), CFrame.new(7, 9.2, -0.2) * CFrame.Angles(0, 0, math.rad(8)), deep)
	p("FistL", Vector3.new(4.4, 4, 4.4), CFrame.new(-7.6, 4.6, -0.4), ice)
	p("FistR", Vector3.new(4.4, 4, 4.4), CFrame.new(7.6, 4.6, -0.4), ice)
	for index, x in ipairs({ -4, -1.4, 1.4, 4 }) do
		guardianPart(model, root, {
			Name = `Spike{index}`, Size = Vector3.new(1.4, 4.5, 1.4),
			localCFrame = CFrame.new(x, 15.4, 2.6) * CFrame.Angles(math.rad(-25), 0, math.rad(x * 4)),
			Color = accent, Material = Enum.Material.Neon,
		})
	end
end

local function buildMystic(model, root, accent)
	local robe = { Color = Color3.fromRGB(88, 60, 150), Material = Enum.Material.Fabric }
	local dark = { Color = Color3.fromRGB(45, 32, 85), Material = Enum.Material.Slate }
	local function p(name, size, cf, look, shape)
		guardianPart(model, root, {
			Name = name, Size = size, localCFrame = cf, Color = look.Color, Material = look.Material, Shape = shape,
		})
	end
	-- Silhouette flottante : robe en trois étages, sans jambes.
	p("RobeLow", Vector3.new(4, 7, 7), CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)), dark, Enum.PartType.Cylinder)
	p("RobeMid", Vector3.new(5, 6, 6), CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(90)), robe, Enum.PartType.Cylinder)
	p("Chest", Vector3.new(7, 4.5, 4.5), CFrame.new(0, 13, 0), robe)
	p("Hood", Vector3.new(4.6, 4.6, 4.6), CFrame.new(0, 17, 0.2), dark, Enum.PartType.Ball)
	guardianPart(model, root, {
		Name = "Face", Size = Vector3.new(2.6, 2.6, 2.6), localCFrame = CFrame.new(0, 16.8, -1.2),
		Color = accent, Material = Enum.Material.Neon, Shape = Enum.PartType.Ball,
	})
	p("SleeveL", Vector3.new(6, 2.2, 2.2), CFrame.new(-5, 12.4, -0.6) * CFrame.Angles(0, 0, math.rad(35)), robe, Enum.PartType.Cylinder)
	p("SleeveR", Vector3.new(6, 2.2, 2.2), CFrame.new(5, 12.4, -0.6) * CFrame.Angles(0, 0, math.rad(-35)), robe, Enum.PartType.Cylinder)
	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2
		guardianPart(model, root, {
			Name = `HaloStar{index}`, Size = Vector3.new(0.9, 0.9, 0.9),
			localCFrame = CFrame.new(math.cos(angle) * 3.4, 19.6 + math.sin(angle * 2) * 0.3, math.sin(angle) * 3.4),
			Color = accent, Material = Enum.Material.Neon, Shape = Enum.PartType.Ball,
		})
	end
	for index, x in ipairs({ -7.5, 7.5 }) do
		guardianPart(model, root, {
			Name = `Orb{index}`, Size = Vector3.new(2.2, 2.2, 2.2), localCFrame = CFrame.new(x, 9.5, -1.5),
			Color = accent, Material = Enum.Material.Neon, Shape = Enum.PartType.Ball,
		})
	end
end

local GUARDIAN_BUILDERS = { forest = buildForest, sand = buildSand, ice = buildIce, mystic = buildMystic }

-- Décor par thème --------------------------------------------------------------

local function decorate(theme, decor: Folder, center: Vector3, top: number, toBridge: Vector3)
	local accent = theme.accent
	local count = 10
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + 0.2
		local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (ARENA_RADIUS + 1.5)
		-- Laisser libre le passage vers le pont et vers la terrasse.
		local direction = (position - center).Unit
		if math.abs(direction:Dot(toBridge)) > 0.93 then
			continue
		end
		if theme.kind == "forest" then
			newPart(decor, {
				Name = `MossStone{index}`, Size = Vector3.new(3, 6 + rng:NextNumber(0, 3), 3),
				CFrame = CFrame.new(position.X, top + 3, position.Z) * CFrame.Angles(0, angle, math.rad(rng:NextNumber(-6, 6))),
				Color = Color3.fromRGB(105, 115, 95), Material = Enum.Material.Rock,
			})
			newPart(decor, {
				Name = `MossCap{index}`, Size = Vector3.new(3.4, 1, 3.4),
				CFrame = CFrame.new(position.X, top + 7.2, position.Z), Color = Color3.fromRGB(80, 150, 60),
				Material = Enum.Material.Grass, CanCollide = false,
			})
		elseif theme.kind == "sand" then
			local height = if index % 3 == 0 then 5 else 11
			newPart(decor, {
				Name = `Column{index}`, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 3, 3),
				CFrame = CFrame.new(position.X, top + height / 2, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(225, 196, 140), Material = Enum.Material.Sandstone,
			})
			if height > 6 then
				newPart(decor, {
					Name = `Capital{index}`, Size = Vector3.new(4, 1, 4),
					CFrame = CFrame.new(position.X, top + height + 0.5, position.Z),
					Color = Color3.fromRGB(240, 180, 70), Material = Enum.Material.Sandstone,
				})
			end
		elseif theme.kind == "ice" then
			newPart(decor, {
				Name = `IceSpike{index}`, Size = Vector3.new(2.6, 9 + rng:NextNumber(0, 5), 2.6),
				CFrame = CFrame.new(position.X, top + 5, position.Z) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), angle, math.rad(rng:NextNumber(-10, 10))),
				Color = Color3.fromRGB(175, 220, 245), Material = Enum.Material.Ice,
			})
			newPart(decor, {
				Name = `SnowDrift{index}`, Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5),
				CFrame = CFrame.new(position.X, top - 1, position.Z), Color = Color3.fromRGB(245, 250, 255),
				Material = Enum.Material.Snow, CanCollide = false,
			})
		else
			newPart(decor, {
				Name = `StarPylon{index}`, Size = Vector3.new(1.6, 8, 1.6),
				CFrame = CFrame.new(position.X, top + 4, position.Z) * CFrame.Angles(0, angle, 0),
				Color = Color3.fromRGB(60, 45, 100), Material = Enum.Material.Slate,
			})
			newPart(decor, {
				Name = `StarOrb{index}`, Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8),
				CFrame = CFrame.new(position.X, top + 9.2, position.Z), Color = accent,
				Material = Enum.Material.Neon, CanCollide = false,
			})
		end
	end

	-- Éléments propres à chaque environnement.
	if theme.kind == "forest" then
		-- Racines géantes en arches au-dessus du bord de l'arène.
		for index = 1, 4 do
			local angle = index * math.pi / 2 + math.pi / 4
			local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (PLATFORM_RADIUS - 2)
			newPart(decor, {
				Name = `GiantRoot{index}`, Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 3, 3),
				CFrame = CFrame.new(position.X, top + 4, position.Z) * CFrame.Angles(0, angle, math.rad(60)),
				Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood, CanCollide = false,
			})
			newPart(decor, {
				Name = `Glowshroom{index}`, Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2),
				CFrame = CFrame.new(position.X, top + 0.8, position.Z), Color = accent,
				Material = Enum.Material.Neon, CanCollide = false,
			})
		end
	elseif theme.kind == "sand" then
		newPart(decor, {
			Name = "SunDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 10, 10),
			CFrame = CFrame.new(center.X, top + 0.05, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(240, 175, 60), Material = Enum.Material.Sandstone, CanCollide = false,
		})
	elseif theme.kind == "ice" then
		newPart(decor, {
			Name = "FrozenPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 12, 12),
			CFrame = CFrame.new(center.X, top + 0.05, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(140, 200, 235), Material = Enum.Material.Ice, CanCollide = false,
		})
	else
		-- Anneaux d'étoiles flottants (sans collision).
		for index = 1, 3 do
			newPart(decor, {
				Name = `AstralRing{index}`, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 10 + index * 6, 10 + index * 6),
				CFrame = CFrame.new(center.X, top + 26 + index * 1.5, center.Z) * CFrame.Angles(math.rad(index * 12), 0, math.rad(90)),
				Color = accent, Material = Enum.Material.Neon, Transparency = 0, CanCollide = false,
			})
		end
	end
end

-- Construction ------------------------------------------------------------------

local existing = Workspace:FindFirstChild(FOLDER_NAME)
if existing then
	existing:Destroy()
end
local root = Instance.new("Folder")
root.Name = FOLDER_NAME
root.Parent = Workspace

local report = {}

for _, theme in ipairs(THEMES) do
	local center = theme.center
	local top = center.Y
	local site = Instance.new("Model")
	site.Name = theme.siteId
	site:SetAttribute("SiteId", theme.siteId)

	local toBridge = Vector3.new(theme.bridgeFrom.X - center.X, 0, theme.bridgeFrom.Z - center.Z).Unit

	local arena = folder(site, "Arena")
	disc(arena, "Platform", center, PLATFORM_RADIUS, 4, top + 0.04, theme.edge)
	disc(arena, "Floor", center, PLATFORM_RADIUS - 1.5, 0.4, top + 0.08, theme.floor)
	-- Bord de l'arène : anneau Neon fin au sol (limite visible du combat).
	newPart(arena, {
		Name = "ArenaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, ARENA_RADIUS * 2, ARENA_RADIUS * 2),
		CFrame = CFrame.new(center.X, top + 0.1, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = theme.accent, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false,
	})
	disc(arena, "ArenaInner", center, ARENA_RADIUS - 0.6, 0.12, top + 0.13, theme.floor)
	if theme.floating then
		for index, radius in ipairs({ 26, 18, 10 }) do
			disc(arena, `Under{index}`, center, radius, 6, top - 4 - (index - 1) * 6, theme.edge)
		end
	end

	-- Pont vers l'île (et garde-corps pour le site flottant).
	local bridge = folder(site, "Bridge")
	local bridgeEnd = center + toBridge * (PLATFORM_RADIUS - 3)
	span(bridge, "Deck", theme.bridgeFrom, bridgeEnd, 10, 2, top + 0.05, theme.edge)
	if theme.floating then
		local side = Vector3.new(-toBridge.Z, 0, toBridge.X)
		for index, sign in ipairs({ -1, 1 }) do
			local a = theme.bridgeFrom + side * 5 * sign
			local b = bridgeEnd + side * 5 * sign
			span(bridge, `Rail{index}`, a, b, 0.6, 2.4, top + 2.4, { color = theme.accent, material = Enum.Material.Neon })
		end
	end

	-- Centre de l'arène (référence serveur) et collision fixe du gardien.
	newPart(site, {
		Name = "Center", Size = Vector3.new(1, 0.1, 1), CFrame = CFrame.new(center.X, top + 0.05, center.Z),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	newPart(arena, {
		Name = "GuardianCollider", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 8, 8),
		CFrame = CFrame.new(center.X, top + 7, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 1, CanQuery = false, CanTouch = false,
	})

	-- Autel (point d'activation), côté pont.
	local altarPosition = center + toBridge * ALTAR_DISTANCE
	newPart(arena, {
		Name = "AltarBase", Size = Vector3.new(6, 1, 6), CFrame = CFrame.new(altarPosition.X, top + 0.5, altarPosition.Z),
		Color = theme.edge.color, Material = theme.edge.material,
	})
	local altar = newPart(site, {
		Name = "Altar", Size = Vector3.new(3.2, 3, 3.2), CFrame = CFrame.new(altarPosition.X, top + 2.5, altarPosition.Z),
		Color = theme.floor.color, Material = theme.floor.material,
	})
	altar:SetAttribute("SacredAltar", theme.siteId)
	newPart(arena, {
		Name = "AltarRune", Size = Vector3.new(2.4, 0.3, 2.4), CFrame = CFrame.new(altarPosition.X, top + 4.15, altarPosition.Z) * CFrame.Angles(0, math.rad(45), 0),
		Color = theme.accent, Material = Enum.Material.Neon, CanCollide = false,
	})

	-- Gardien commun (statique ici ; animé localement par chaque client).
	local guardian = Instance.new("Model")
	guardian.Name = "Guardian"
	guardian:SetAttribute("GuardianId", theme.guardianId)
	-- Face vers l'autel : -Z local orienté vers le pont.
	local rootCFrame = CFrame.lookAt(Vector3.new(center.X, top + 0.1, center.Z), Vector3.new(altarPosition.X, top + 0.1, altarPosition.Z))
	local guardianRoot = newPart(guardian, {
		Name = "GuardianRoot", Size = Vector3.new(1, 0.2, 1), CFrame = rootCFrame,
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	guardian.PrimaryPart = guardianRoot
	local rootForBuild = rootCFrame + Vector3.new(0, if theme.kind == "mystic" then 1.5 else 0, 0)
	GUARDIAN_BUILDERS[theme.kind](guardian, rootForBuild, theme.accent)
	guardian.Parent = site

	-- Terrasse de récompense, à l'opposé du pont, hors de l'arène.
	local reward = folder(site, "RewardZone")
	local rewardCenter = center - toBridge * REWARD_DISTANCE
	disc(reward, "Terrace", rewardCenter, REWARD_RADIUS, 4, top + 0.04, theme.edge)
	disc(reward, "TerraceFloor", rewardCenter, REWARD_RADIUS - 1, 0.4, top + 0.1, theme.floor)
	if theme.floating then
		disc(reward, "TerraceUnder", rewardCenter, REWARD_RADIUS - 3, 5, top - 3.9, theme.edge)
	end
	span(reward, "Walkway", center - toBridge * (PLATFORM_RADIUS - 2), rewardCenter + toBridge * (REWARD_RADIUS - 2), 7, 2, top + 0.05, theme.edge)
	local side = Vector3.new(-toBridge.Z, 0, toBridge.X)
	for index = 1, 3 do
		local offset = (index - 2) * 5
		local position = rewardCenter + side * offset - toBridge * (if index == 2 then 2 else 0)
		newPart(reward, {
			Name = `Pedestal{index}`, Size = Vector3.new(2.6, 2, 2.6), CFrame = CFrame.new(position.X, top + 1.1, position.Z),
			Color = theme.edge.color, Material = theme.edge.material,
		})
		local node = newPart(reward, {
			Name = `SacredNode_{index}`, Size = Vector3.new(1.4, 2.2, 1.4),
			CFrame = CFrame.new(position.X, top + 3.4, position.Z) * CFrame.Angles(0, math.rad(45), math.rad(20)),
			Color = theme.accent, Material = Enum.Material.Neon, CanCollide = false,
		})
		node:SetAttribute("SacredNodeId", `{theme.siteId}_Sacred_{index}`)
		node:SetAttribute("SacredResourceId", theme.sacredId)
	end

	local decor = folder(site, "Decor")
	decorate(theme, decor, center, top, toBridge)

	site.Parent = root

	-- Contrôles : budget, ancrage, aucun script, lumière ni émetteur.
	local parts, unanchored, forbidden = 0, 0, 0
	for _, descendant in ipairs(site:GetDescendants()) do
		if descendant:IsA("BasePart") then
			parts += 1
			if not descendant.Anchored then
				unanchored += 1
			end
		elseif descendant:IsA("Light") or descendant:IsA("ParticleEmitter") or descendant:IsA("Script") then
			forbidden += 1
		end
	end
	assert(parts <= PART_BUDGET, `{theme.siteId} : {parts} parts > {PART_BUDGET}`)
	assert(unanchored == 0 and forbidden == 0, `{theme.siteId} : pièces non ancrées ou objets interdits`)

	-- Chevauchements avec la carte existante (hors île de départ du pont).
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root }
	local overlaps = {}
	for _, hit in ipairs(Workspace:GetPartBoundsInRadius(Vector3.new(center.X, top + 8, center.Z), PLATFORM_RADIUS, params)) do
		if hit.Size.Magnitude < 900 then
			overlaps[hit:GetFullName()] = true
		end
	end
	local names = {}
	for name in pairs(overlaps) do
		table.insert(names, name)
	end
	table.insert(report, `{theme.siteId} : {parts} parts ; chevauchements : {#names} {table.concat(names, ", ")}`)
end

return table.concat(report, "\n")
