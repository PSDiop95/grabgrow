--!nocheck
-- Carte de Golden Desert (T8.3, D-021) en primitives scriptées : île
-- désertique, oasis (arrivée, vente, portail de retour), dunes, ruines et
-- arche rocheuse, crête rocheuse avec point de vue, recoin secret du
-- Cristal solaire.
--
-- Outil de développement, absent du jeu (non mappé dans
-- default.project.json). À exécuter dans Roblox Studio en mode Edit (barre
-- de commande ou serveur MCP). Rejouable : remplace ce qu'il a créé pour
-- Golden Desert, ne touche à rien d'autre (Green Valley et les autres
-- mondes sont préservés). Résultat identique à chaque exécution (graine
-- fixe). Aucun asset externe, aucun texte ni logo dans le décor.
--
-- Crée (lus par le jeu) :
--   Workspace.Map.GoldenDesert                    île, zones, décor
--     Portals.GreenValley.Field                   attribut `PortalWorldId`
--   Workspace.WorldArrivals.GoldenDesert          attribut `ArrivalWorldId`
--   Workspace.ResourceSpawnPoints.GoldenDesert    40 points, `ResourceType`
--   Workspace.SellZones.GoldenDesert              `SellZonePad`, `SellZoneId`
-- Aucune SpawnLocation : l'apparition reste au hub de Green Valley (D5).
--
-- Valeurs, raretés et temps de réapparition : ResourceConfig (non lus ici,
-- sauf les poids de spawn pour le nombre de points). Apparence des nœuds :
-- ResourceVisualConfig (Systems/ResourceNodes).
--
-- Budget (audit T8) : ~1 200 parts de décor au plus, ~40 nœuds, aucune
-- lumière dynamique, CastShadow désactivé, décor ancré, collisions simples
-- (palmes, eau, champ du portail sans collision).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)

local SEED = 20261115
local WORLD_ID = "GoldenDesert"
local DECOR_BUDGET = 1200
-- Centre de l'île : loin de Green Valley (île et eau jusqu'à |x| = 700).
local CENTER = Vector3.new(3000, 0, 0)

local TOTAL_SPAWN_POINTS = 40
local MIN_SPACING_STUDS = 6

-- Coordonnées locales (relatives à CENTER). +Z : nord (portail), -Z : sud.
-- ZONE A — arrivée et oasis.
local PLAZA_RADIUS = 18
local ARRIVAL_POSITION = Vector3.new(0, 0.3, 6)
local PORTAL_POSITION = Vector3.new(0, 0, 26)
local SELL_ZONE_ID = "GoldenDesert_Oasis"
local SELL_POSITION = Vector3.new(-16, 0, -12)
local OASIS_CENTER = Vector3.new(28, 0, -8)
local OASIS_RADIUS = 11
-- Communes de l'oasis : anneau autour de la place.
local BASE_RING = { min = 22, max = 46 }
-- ZONE B — dunes (sud).
local DUNE_REGION = { minX = -110, maxX = 115, minZ = -125, maxZ = -48 }
-- ZONE C — ruines (ouest), arche à l'entrée côté oasis.
local RUINS_CENTER = Vector3.new(-82, 0, 6)
local RUINS_HALF = 17
local ARCH_X = -56
-- ZONE D — crête rocheuse (nord-est), plateau à RIDGE_HEIGHT studs, rampe
-- au sud.
local RIDGE_CENTER = Vector3.new(66, 0, 74)
local RIDGE_SIZE = Vector3.new(44, 0, 28)
local RIDGE_HEIGHT = 10
local RAMP_X = 78 -- côté est du plateau (le point de vue est à l'ouest)
local RAMP_LENGTH = 44
-- ZONE E — recoin secret (nord-ouest), atteint par un sentier depuis les
-- ruines.
local SECRET_CENTER = Vector3.new(-96, 0, 98)
local SECRET_RADIUS = 9
local PEDESTAL_HEIGHT = 1

local COLORS = {
	sand = Color3.fromRGB(232, 204, 142),
	sandLight = Color3.fromRGB(242, 222, 170),
	sandDark = Color3.fromRGB(214, 178, 112),
	ochre = Color3.fromRGB(214, 158, 72),
	orange = Color3.fromRGB(226, 136, 62),
	earth = Color3.fromRGB(150, 100, 62),
	cliff = Color3.fromRGB(176, 118, 70),
	rock = Color3.fromRGB(190, 132, 82),
	rockDark = Color3.fromRGB(158, 104, 66),
	ruin = Color3.fromRGB(226, 206, 160),
	ruinDark = Color3.fromRGB(196, 174, 130),
	water = Color3.fromRGB(64, 200, 200),
	sea = Color3.fromRGB(70, 170, 200),
	grass = Color3.fromRGB(132, 182, 84),
	palmTrunk = Color3.fromRGB(150, 104, 62),
	cactus = Color3.fromRGB(96, 156, 84),
	path = Color3.fromRGB(204, 166, 100),
	arrival = Color3.fromRGB(120, 200, 255),
	portal = Color3.fromRGB(116, 178, 92),
	gold = Color3.fromRGB(255, 196, 40),
}
local PALM_LEAVES = { Color3.fromRGB(86, 160, 70), Color3.fromRGB(70, 140, 62), Color3.fromRGB(108, 172, 76) }
local DUNE_COLORS = { COLORS.sand, COLORS.sandDark, COLORS.ochre }

local function getFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function replace(parent: Instance, name: string)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local function newFolder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local random = Random.new(SEED)
local partCount = 0

local function world(position: Vector3): Vector3
	return CENTER + position
end

local function horizontal(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
end

-- Part ancrée, sans ombre ; cframe en coordonnées locales. `solid = false` :
-- traversable, ignorée par les requêtes.
local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, solid: boolean?, class: string?): BasePart
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(CENTER) * cframe
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	if solid == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	partCount += 1
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): BasePart
	return part(parent, name, size, cframe, color, true, "WedgePart")
end

-- Disque plat (cylindre vertical), centre local.
local function disk(parent: Instance, name: string, diameter: number, thickness: number, center: Vector3, color: Color3, solid: boolean?): BasePart
	local p = part(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Footprints (cercles horizontaux) des volumes solides : aucune ressource
-- ni décor ne s'y pose.
local footprints: { { center: Vector3, radius: number } } = {}
local function reserve(center: Vector3, radius: number)
	table.insert(footprints, { center = horizontal(center), radius = radius })
end
local function inFootprint(position: Vector3, margin: number): boolean
	local flat = horizontal(position)
	for _, footprint in ipairs(footprints) do
		if (flat - footprint.center).Magnitude < footprint.radius + margin then
			return true
		end
	end
	return false
end

-- Dalle de chemin entre deux points locaux (au sol).
local function pathSegment(parent: Instance, name: string, from: Vector3, to: Vector3, width: number)
	local a, b = horizontal(from), horizontal(to)
	local length = (b - a).Magnitude
	local middle = (a + b) / 2 + Vector3.new(0, 0.07, 0)
	part(parent, name, Vector3.new(width, 0.14, length + 1), CFrame.lookAt(middle, b + Vector3.new(0, 0.07, 0)), COLORS.path)
	-- Chemin dégagé : ni décor ni ressource dessus.
	for step = 0, math.ceil(length / 4) do
		reserve(a:Lerp(b, math.min(step * 4 / length, 1)), width / 2 + 0.5)
	end
end

-- Sur l'une des trois dalles de l'île, à `margin` studs du bord au moins.
local function onIsland(position: Vector3, margin: number): boolean
	local ax, az = math.abs(position.X), math.abs(position.Z)
	return (ax < 120 - margin and az < 120 - margin)
		or (ax < 135 - margin and az < 90 - margin)
		or (ax < 90 - margin and az < 135 - margin)
end

-- CARTE ----------------------------------------------------------------------

local map = getFolder(Workspace, "Map")
replace(map, WORLD_ID)
local root = Instance.new("Folder")
root.Name = WORLD_ID

-- Île : trois dalles croisées (environ 270 × 270 studs), falaise ocre
-- dessous, mer autour (sans collision : une chute fait réapparaître au hub
-- de Green Valley, D5).
local island = newFolder(root, "Island")
for index, size in ipairs({ Vector3.new(240, 4, 240), Vector3.new(270, 4, 180), Vector3.new(180, 4, 270) }) do
	part(island, `Ground{index}`, size, CFrame.new(0, -2, 0), COLORS.sand)
	part(island, `Cliff{index}`, size + Vector3.new(4, 6, 4), CFrame.new(0, -6.9, 0), COLORS.cliff)
end
part(island, "Sea", Vector3.new(1000, 1, 1000), CFrame.new(0, -8, 0), COLORS.sea, false).Transparency = 0.15

-- ZONE A — Arrivée et oasis -------------------------------------------------

local oasis = newFolder(root, "ZoneA_Oasis")
disk(oasis, "Plaza", PLAZA_RADIUS * 2, 0.2, Vector3.new(0, 0.1, 0), COLORS.sandLight)
-- Bassin turquoise (traversable, on y marche dans l'eau), rive d'herbe.
disk(oasis, "Shore", OASIS_RADIUS * 2 + 8, 0.16, OASIS_CENTER + Vector3.new(0, 0.08, 0), COLORS.grass)
disk(oasis, "Pond", OASIS_RADIUS * 2, 0.3, OASIS_CENTER + Vector3.new(0, 0.12, 0), COLORS.water, false).Transparency = 0.1
reserve(OASIS_CENTER, OASIS_RADIUS + 2)

-- Palmier low-poly : tronc en trois segments inclinés (solide en bas
-- seulement), cinq palmes et des noix, sans collision au-dessus.
local function palm(parent: Instance, name: string, base: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = name
	local lean = math.rad(random:NextNumber(6, 14))
	local yaw = math.rad(random:NextNumber(0, 360))
	local frame = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local top = frame
	for segment = 1, 3 do
		local height = 3.2 * scale
		local cf = top * CFrame.Angles(lean, 0, 0) * CFrame.new(0, height / 2, 0)
		part(model, `Trunk{segment}`, Vector3.new(1.1, height, 1.1) * Vector3.new(scale, 1, scale), cf, COLORS.palmTrunk, segment == 1)
		top = cf * CFrame.new(0, height / 2, 0)
	end
	for leaf = 1, 5 do
		local angle = math.rad(leaf * 72)
		local cf = top * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, -2.4 * scale)
		part(model, `Leaf{leaf}`, Vector3.new(1.6, 0.3, 5) * scale, cf, PALM_LEAVES[(leaf % #PALM_LEAVES) + 1], false)
	end
	part(model, "Nuts", Vector3.new(1, 1, 1) * scale, top * CFrame.new(0, -0.6, 0), COLORS.earth, false)
	model.Parent = parent
	reserve(base, 1.5)
end

for index = 1, 8 do
	local angle = math.rad(index * 45 + 20)
	local radius = OASIS_RADIUS + random:NextNumber(2, 4)
	palm(oasis, `OasisPalm{index}`, OASIS_CENTER + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), random:NextNumber(1, 1.3))
end

-- Portail de retour vers Green Valley (champ traversable lu par
-- TravelController) : arche de grès et linteau vert.
local portals = newFolder(root, "Portals")
do
	local model = Instance.new("Model")
	model.Name = "GreenValley"
	local p = PORTAL_POSITION
	part(model, "Step", Vector3.new(10, 0.6, 4), CFrame.new(p + Vector3.new(0, 0.3, 0)), COLORS.ruin)
	part(model, "PillarLeft", Vector3.new(1.8, 10, 1.8), CFrame.new(p + Vector3.new(-4.2, 5.6, 0)), COLORS.ruin)
	part(model, "PillarRight", Vector3.new(1.8, 10, 1.8), CFrame.new(p + Vector3.new(4.2, 5.6, 0)), COLORS.ruin)
	part(model, "Lintel", Vector3.new(10, 1.6, 2), CFrame.new(p + Vector3.new(0, 11.4, 0)), COLORS.portal)
	local field = part(model, "Field", Vector3.new(6.8, 9.6, 0.4), CFrame.new(p + Vector3.new(0, 5.4, 0)), COLORS.portal, false)
	field.Transparency = 0.35
	field.CanQuery = true
	field:SetAttribute("PortalWorldId", "GreenValley")
	model.PrimaryPart = field
	model.Parent = portals
	reserve(p, 7)
end
reserve(ARRIVAL_POSITION, 4)
reserve(SELL_POSITION, 9)

-- Chemins depuis la place : ruines (ouest), crête (nord-est), dunes (sud).
local paths = newFolder(root, "Paths")
pathSegment(paths, "ToRuins", Vector3.new(-PLAZA_RADIUS, 0, 2), Vector3.new(RUINS_CENTER.X + RUINS_HALF, 0, RUINS_CENTER.Z), 6)
pathSegment(paths, "ToRidge1", Vector3.new(12, 0, 13), Vector3.new(RAMP_X, 0, 12), 6)
pathSegment(paths, "ToDunes", Vector3.new(4, 0, -PLAZA_RADIUS), Vector3.new(10, 0, -52), 6)
-- Sentier sinueux ruines → recoin secret.
local secretTrail = {
	Vector3.new(RUINS_CENTER.X - 6, 0, RUINS_CENTER.Z + RUINS_HALF),
	Vector3.new(-74, 0, 46),
	Vector3.new(-104, 0, 64),
	Vector3.new(-90, 0, 80),
	SECRET_CENTER + Vector3.new(0, 0, -SECRET_RADIUS),
}
for index = 1, #secretTrail - 1 do
	pathSegment(paths, `ToSecret{index}`, secretTrail[index], secretTrail[index + 1], 4)
end

-- ZONE B — Dunes ------------------------------------------------------------

-- Dune : deux WedgeParts dos à dos (pente douce au vent, pente raide sous le
-- vent), crête orientée. Le bas d'un WedgePart est à son -Z local.
local dunes = newFolder(root, "ZoneB_Dunes")
local DUNES = {
	{ x = -40, z = -78, length = 34, height = 6 },
	{ x = 30, z = -96, length = 40, height = 8 },
	{ x = 78, z = -66, length = 30, height = 5 },
	{ x = -86, z = -104, length = 30, height = 7 },
	{ x = 100, z = -30, length = 26, height = 5 },
	{ x = 92, z = -108, length = 24, height = 6 },
	{ x = -10, z = -122, length = 36, height = 5 },
	{ x = -100, z = -52, length = 22, height = 4 },
	{ x = 118, z = 20, length = 20, height = 4 },
	{ x = -112, z = -6, length = 18, height = 4 },
}
for index, info in ipairs(DUNES) do
	local model = Instance.new("Model")
	model.Name = `Dune{index}`
	local yaw = math.rad(random:NextNumber(-25, 25))
	local frame = CFrame.new(info.x, 0, info.z) * CFrame.Angles(0, yaw, 0)
	local windward, lee = info.height * 3, info.height * 1.4
	local color = DUNE_COLORS[random:NextInteger(1, #DUNE_COLORS)]
	wedge(model, "Windward", Vector3.new(info.length, info.height, windward), frame * CFrame.new(0, info.height / 2, -windward / 2), color)
	wedge(model, "Lee", Vector3.new(info.length, info.height, lee), frame * CFrame.new(0, info.height / 2, lee / 2) * CFrame.Angles(0, math.pi, 0), color)
	model.Parent = dunes
	-- Empreinte : couvre la dune entière.
	reserve(Vector3.new(info.x, 0, info.z), math.max(info.length / 2, windward) + 1)
end
-- Petit point d'eau dans les dunes.
local DUNE_POOL = Vector3.new(50, 0, -40)
disk(dunes, "PoolShore", 14, 0.14, DUNE_POOL + Vector3.new(0, 0.07, 0), COLORS.grass)
disk(dunes, "Pool", 9, 0.28, DUNE_POOL + Vector3.new(0, 0.1, 0), COLORS.water, false).Transparency = 0.1
reserve(DUNE_POOL, 6)
palm(dunes, "PoolPalm1", DUNE_POOL + Vector3.new(6, 0, 3), 1.1)
palm(dunes, "PoolPalm2", DUNE_POOL + Vector3.new(-5, 0, -5), 0.95)

-- ZONE C — Ruines et arche rocheuse ---------------------------------------

local ruins = newFolder(root, "ZoneC_Ruins")
part(ruins, "Floor", Vector3.new(RUINS_HALF * 2, 0.4, RUINS_HALF * 2), CFrame.new(RUINS_CENTER + Vector3.new(0, 0.2, 0)), COLORS.ruinDark)
-- Les fossiles ont des emplacements fixes : l'empreinte n'écarte que le décor.
reserve(RUINS_CENTER, RUINS_HALF + 3)

-- Arche monumentale (blocs de roche empilés) au-dessus du chemin.
do
	local arch = Instance.new("Model")
	arch.Name = "RockArch"
	for side = -1, 1, 2 do
		local base = Vector3.new(ARCH_X, 0, RUINS_CENTER.Z + side * 9)
		part(arch, `Leg{side}A`, Vector3.new(7, 8, 6), CFrame.new(base + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(8 * side), 0), COLORS.rock)
		part(arch, `Leg{side}B`, Vector3.new(6, 7, 5), CFrame.new(base + Vector3.new(0.5, 11, -side * 0.5)) * CFrame.Angles(0, math.rad(-6 * side), math.rad(3)), COLORS.rockDark)
		reserve(base, 4.5)
	end
	part(arch, "Span", Vector3.new(8, 4.5, 26), CFrame.new(ARCH_X, 16.5, RUINS_CENTER.Z) * CFrame.Angles(math.rad(2), 0, 0), COLORS.orange)
	part(arch, "Cap", Vector3.new(6, 2.5, 16), CFrame.new(ARCH_X + 0.5, 19.8, RUINS_CENTER.Z - 1), COLORS.rock)
	arch.Parent = ruins
end

-- Colonnes (entières ou brisées) en deux rangées, une colonne couchée, murs
-- bas.
local fossilSpots = {}
do
	local index = 0
	for row = -1, 1, 2 do
		for column = 0, 3 do
			index += 1
			local position = RUINS_CENTER + Vector3.new(-12 + column * 8, 0.4, row * 11)
			local broken = (index % 3) == 0
			local height = if broken then random:NextNumber(3, 5) else 9
			part(ruins, `Base{index}`, Vector3.new(2.6, 0.8, 2.6), CFrame.new(position + Vector3.new(0, 0.4, 0)), COLORS.ruin)
			part(ruins, `Shaft{index}`, Vector3.new(1.8, height, 1.8), CFrame.new(position + Vector3.new(0, 0.8 + height / 2, 0)) * CFrame.Angles(0, math.rad(random:NextNumber(0, 10)), 0), COLORS.ruin)
			if not broken then
				part(ruins, `Capital{index}`, Vector3.new(2.8, 0.8, 2.8), CFrame.new(position + Vector3.new(0, 1.2 + height, 0)), COLORS.ruinDark)
			end
			reserve(position, 1.8)
		end
	end
	-- Linteau sur deux colonnes entières de la rangée nord
	-- (colonnes 7 et 8, entières ; les colonnes 3 et 6 sont brisées).
	part(ruins, "Lintel", Vector3.new(10, 1.2, 2.4), CFrame.new(RUINS_CENTER + Vector3.new(8, 11.4, 11)), COLORS.ruinDark)
	local fallen = part(ruins, "FallenColumn", Vector3.new(9, 1.8, 1.8), CFrame.new(RUINS_CENTER + Vector3.new(4, 1.3, -1)) * CFrame.Angles(0, math.rad(25), 0), COLORS.ruin)
	fallen.Shape = Enum.PartType.Cylinder
	reserve(RUINS_CENTER + Vector3.new(4, 0, -1), 5)
	for wall = 1, 4 do
		local x = RUINS_CENTER.X - RUINS_HALF + 1
		local z = RUINS_CENTER.Z - 14 + wall * 6
		if wall ~= 2 then
			part(ruins, `Wall{wall}`, Vector3.new(1.6, random:NextNumber(2, 4), 5), CFrame.new(x, 1.8, z), COLORS.ruinDark)
			reserve(Vector3.new(x, 0, z), 3)
		end
	end
	-- Fossiles : entre les colonnes et au pied des murs (sol des ruines à 0,4).
	for _, offset in ipairs({
		Vector3.new(-8, 0.4, 5),
		Vector3.new(0, 0.4, 5),
		Vector3.new(8, 0.4, 5),
		Vector3.new(-8, 0.4, -5),
		Vector3.new(10, 0.4, -6),
		Vector3.new(-13, 0.4, -14),
		Vector3.new(15, 0.4, -14),
	}) do
		table.insert(fossilSpots, RUINS_CENTER + offset)
	end
end

-- ZONE D — Crête rocheuse et point de vue -------------------------------

local ridge = newFolder(root, "ZoneD_Ridge")
local ridgeTop = RIDGE_HEIGHT
part(ridge, "Plateau", Vector3.new(RIDGE_SIZE.X, RIDGE_HEIGHT, RIDGE_SIZE.Z), CFrame.new(RIDGE_CENTER + Vector3.new(0, RIDGE_HEIGHT / 2, 0)), COLORS.rock)
-- Blocs de falaise autour du plateau (silhouette irrégulière).
for index, offset in ipairs({
	Vector3.new(-24, 0, 6), Vector3.new(24, 0, -4), Vector3.new(10, 0, 16), Vector3.new(-12, 0, 16),
	Vector3.new(26, 0, 12), Vector3.new(-26, 0, -8),
}) do
	local height = RIDGE_HEIGHT + random:NextNumber(-3, 4)
	part(ridge, `Cliff{index}`, Vector3.new(random:NextNumber(8, 12), height, random:NextNumber(8, 12)), CFrame.new(RIDGE_CENTER + offset + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, math.rad(random:NextNumber(0, 40)), 0), if index % 2 == 0 then COLORS.rockDark else COLORS.cliff)
end
-- Rampe (sentier progressif) au sud du plateau, montée vers le nord.
local rampEnd = RIDGE_CENTER.Z - RIDGE_SIZE.Z / 2
local rampCenter = Vector3.new(RAMP_X, RIDGE_HEIGHT / 2, rampEnd - RAMP_LENGTH / 2)
-- WedgePart : bas au -Z local (sud), haut au +Z (plateau).
wedge(ridge, "Ramp", Vector3.new(8, RIDGE_HEIGHT, RAMP_LENGTH), CFrame.new(rampCenter), COLORS.sandDark)
for index = 0, 3 do
	local z = rampEnd - 6 - index * 10
	local rise = RIDGE_HEIGHT * (1 - (rampEnd - z) / RAMP_LENGTH)
	part(ridge, `RampRockL{index}`, Vector3.new(2.4, 2 + rise, 3), CFrame.new(RAMP_X - 5.4, (2 + rise) / 2, z), COLORS.rockDark)
	part(ridge, `RampRockR{index}`, Vector3.new(2.4, 2 + rise, 3), CFrame.new(RAMP_X + 5.4, (2 + rise) / 2, z), COLORS.rock)
end
reserve(Vector3.new(RAMP_X, 0, rampEnd - RAMP_LENGTH / 2), 8)
reserve(Vector3.new(RAMP_X, 0, rampEnd - RAMP_LENGTH + 6), 8)
reserve(RIDGE_CENTER, 28)
-- Point de vue : muret et pierres dressées côté oasis (sud-ouest du plateau).
local viewpoint = RIDGE_CENTER + Vector3.new(-16, ridgeTop, -10)
for index = 0, 2 do
	part(ridge, `Lookout{index}`, Vector3.new(1.6, 2.4 + index * 0.8, 1.6), CFrame.new(viewpoint + Vector3.new(-3 + index * 3, 1.2 + index * 0.4, -3)), COLORS.ruin)
end
part(ridge, "LookoutWall", Vector3.new(8, 1.2, 1), CFrame.new(viewpoint + Vector3.new(0, 0.6, -4.5)), COLORS.ruinDark)
-- Pépites d'or sur le plateau.
local goldSpots = {
	RIDGE_CENTER + Vector3.new(-6, ridgeTop, 4),
	RIDGE_CENTER + Vector3.new(6, ridgeTop, 8),
	RIDGE_CENTER + Vector3.new(10, ridgeTop, -2),
	RIDGE_CENTER + Vector3.new(0, ridgeTop, -6),
}

-- ZONE E — Recoin secret du Cristal solaire ----------------------------

local secret = newFolder(root, "ZoneE_Secret")
disk(secret, "Floor", SECRET_RADIUS * 2 + 2, 0.2, SECRET_CENTER + Vector3.new(0, 0.1, 0), COLORS.sandLight)
-- Anneau de pierres dressées, ouverture au sud (arrivée du sentier).
for index = 0, 11 do
	local angle = math.rad(index * 30)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	-- Angles 240 à 300° : ouverture côté sud (-Z).
	if not (index >= 8 and index <= 10) then
		local height = random:NextNumber(5, 9)
		part(secret, `Stone{index + 1}`, Vector3.new(2.6, height, 2.2), CFrame.lookAt(SECRET_CENTER + direction * SECRET_RADIUS + Vector3.new(0, height / 2, 0), SECRET_CENTER + Vector3.new(0, height / 2, 0)), if index % 2 == 0 then COLORS.rock else COLORS.orange)
	end
end
disk(secret, "Pedestal", 4, PEDESTAL_HEIGHT, SECRET_CENTER + Vector3.new(0, PEDESTAL_HEIGHT / 2, 0), COLORS.ruin)
disk(secret, "SunDisk", 7, 0.12, SECRET_CENTER + Vector3.new(0, 0.26, 0), COLORS.gold, false)
reserve(SECRET_CENTER, SECRET_RADIUS + 2)
local sunSpot = SECRET_CENTER + Vector3.new(0, PEDESTAL_HEIGHT, 0)

-- POINTS DE SPAWN ------------------------------------------------------------

-- 40 points répartis selon spawnWeight (plus forts restes) : 16/12/7/4/1.
local counts = {}
do
	local types, totalWeight = {}, 0
	for resourceType, definition in pairs(ResourceConfig) do
		if definition.worldId == WORLD_ID then
			table.insert(types, resourceType)
			totalWeight += definition.spawnWeight
		end
	end
	table.sort(types)
	local assigned, remainders = 0, {}
	for _, resourceType in ipairs(types) do
		local exact = TOTAL_SPAWN_POINTS * ResourceConfig[resourceType].spawnWeight / totalWeight
		counts[resourceType] = math.floor(exact)
		assigned += counts[resourceType]
		table.insert(remainders, { id = resourceType, rest = exact - math.floor(exact) })
	end
	table.sort(remainders, function(a, b)
		if a.rest ~= b.rest then
			return a.rest > b.rest
		end
		return a.id < b.id
	end)
	for index = 1, TOTAL_SPAWN_POINTS - assigned do
		counts[remainders[index].id] += 1
	end
end
assert(counts.fossil == #fossilSpots, `Fossile : {counts.fossil} point(s), {#fossilSpots} emplacements`)
assert(counts.gold_nugget == #goldSpots, `Pépite d'or : {counts.gold_nugget} point(s), {#goldSpots} emplacements`)
assert(counts.sun_crystal == 1, `Cristal solaire : {counts.sun_crystal} point(s), 1 attendu`)

local placed: { Vector3 } = {}
local function isFree(position: Vector3, spacing: number): boolean
	for _, other in ipairs(placed) do
		if (horizontal(other) - horizontal(position)).Magnitude < spacing then
			return false
		end
	end
	return true
end

local spawnRoot = getFolder(Workspace, "ResourceSpawnPoints")
replace(spawnRoot, WORLD_ID)
local pointFolder = Instance.new("Folder")
pointFolder.Name = WORLD_ID

local function spawnPoint(resourceType: string, index: number, position: Vector3)
	local point = Instance.new("Part")
	point.Name = string.format("Spawn_%s_%02d", resourceType, index)
	point.Size = Vector3.new(1, 0.2, 1)
	point.Position = world(position)
	point.Anchored = true
	point.Transparency = 1
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point:SetAttribute("ResourceType", resourceType)
	point.Parent = pointFolder
	table.insert(placed, position)
end

local function randomPoint(sample: () -> Vector3, what: string): Vector3
	for _ = 1, 600 do
		local candidate = sample()
		if onIsland(candidate, 8) and not inFootprint(candidate, 2.5) and isFree(candidate, MIN_SPACING_STUDS) then
			return candidate
		end
	end
	error(`aucune place libre pour {what}`)
end

-- Grès : anneau de l'oasis (zone A), hors bassin, vente, portail, chemins
-- (les chemins sont plats : une ressource peut s'y trouver).
for index = 1, counts.sandstone do
	spawnPoint("sandstone", index, randomPoint(function()
		local angle = random:NextNumber(0, 2 * math.pi)
		local radius = random:NextNumber(BASE_RING.min, BASE_RING.max)
		return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end, "sandstone"))
end
-- Cuivre brut : entre les dunes (zone B).
for index = 1, counts.copper_ore do
	spawnPoint("copper_ore", index, randomPoint(function()
		return Vector3.new(random:NextNumber(DUNE_REGION.minX, DUNE_REGION.maxX), 0, random:NextNumber(DUNE_REGION.minZ, DUNE_REGION.maxZ))
	end, "copper_ore"))
end
for index, position in ipairs(fossilSpots) do
	spawnPoint("fossil", index, position)
end
for index, position in ipairs(goldSpots) do
	spawnPoint("gold_nugget", index, position)
end
spawnPoint("sun_crystal", 1, sunSpot)
pointFolder.Parent = spawnRoot

-- DÉCOR (graine fixe, à l'écart des ressources, chemins et zones) -----------

local decor = newFolder(root, "Decor")

local function decorPosition(clearance: number): Vector3?
	for _ = 1, 300 do
		local candidate = Vector3.new(random:NextNumber(-130, 130), 0, random:NextNumber(-130, 130))
		local flat = horizontal(candidate)
		if onIsland(candidate, 6) and flat.Magnitude > PLAZA_RADIUS + 6 and not inFootprint(candidate, 2) and isFree(candidate, clearance) then
			return candidate
		end
	end
	return nil
end

local function cactus(parent: Instance, name: string, base: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = name
	local height = 5 * scale
	part(model, "Stem", Vector3.new(1.4, height, 1.4) * Vector3.new(scale, 1, scale), CFrame.new(base + Vector3.new(0, height / 2, 0)), COLORS.cactus)
	local side = if random:NextNumber() < 0.5 then -1 else 1
	part(model, "ArmOut", Vector3.new(1.6, 0.9, 0.9) * scale, CFrame.new(base + Vector3.new(side * 1.1 * scale, height * 0.5, 0)), COLORS.cactus)
	part(model, "ArmUp", Vector3.new(0.9, 2 * scale, 0.9 * scale), CFrame.new(base + Vector3.new(side * 1.6 * scale, height * 0.5 + scale, 0)), COLORS.cactus)
	model.Parent = parent
end

local function rock(parent: Instance, name: string, base: Vector3, size: number)
	local s = Vector3.new(size, size * random:NextNumber(0.5, 0.9), size * random:NextNumber(0.7, 1))
	local turn = CFrame.Angles(math.rad(random:NextNumber(-10, 10)), math.rad(random:NextNumber(0, 90)), math.rad(random:NextNumber(-10, 10)))
	part(parent, name, s, CFrame.new(base + Vector3.new(0, s.Y * 0.35, 0)) * turn, if random:NextNumber() < 0.5 then COLORS.rock else COLORS.rockDark)
end

local palms, cacti, rocks, tufts = 0, 0, 0, 0
for index = 1, 10 do
	local position = decorPosition(7)
	if position then
		palm(decor, `Palm{index}`, position, random:NextNumber(0.9, 1.2))
		table.insert(placed, position)
		palms += 1
	end
end
for index = 1, 26 do
	local position = decorPosition(5)
	if position then
		cactus(decor, `Cactus{index}`, position, random:NextNumber(0.8, 1.3))
		table.insert(placed, position)
		cacti += 1
	end
end
for index = 1, 36 do
	local position = decorPosition(5)
	if position then
		rock(decor, `Rock{index}`, position, random:NextNumber(1.6, 5))
		table.insert(placed, position)
		rocks += 1
	end
end
-- Rochers bordant le sentier secret (signalétique sans texte).
for index = 1, #secretTrail - 1 do
	local a, b = secretTrail[index], secretTrail[index + 1]
	local middle = (a + b) / 2
	local normal = (b - a).Unit:Cross(Vector3.new(0, 1, 0))
	rock(decor, `TrailRockL{index}`, middle + normal * 4.5, random:NextNumber(1.8, 2.8))
	rock(decor, `TrailRockR{index}`, middle - normal * 4.5, random:NextNumber(1.8, 2.8))
	rocks += 2
end
-- Touffes d'herbe sèche (traversables).
for index = 1, 30 do
	local position = decorPosition(3)
	if position then
		part(decor, `Tuft{index}`, Vector3.new(1.2, 0.6, 1.2), CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(45), 0), COLORS.ochre, false)
		tufts += 1
	end
end
root.Parent = map

-- ARRIVÉE ET VENTE ------------------------------------------------------------

local arrivals = getFolder(Workspace, "WorldArrivals")
replace(arrivals, WORLD_ID)
local arrival = Instance.new("Part")
arrival.Name = WORLD_ID
arrival.Size = Vector3.new(6, 0.2, 6)
arrival.Position = world(ARRIVAL_POSITION)
arrival.Anchored = true
arrival.Material = Enum.Material.SmoothPlastic
arrival.Color = COLORS.arrival
arrival.Transparency = 0.3
arrival.CanCollide = false
arrival.CanQuery = false
arrival.CanTouch = false
arrival.CastShadow = false
arrival:SetAttribute("ArrivalWorldId", WORLD_ID)
arrival.Parent = arrivals
partCount += 1

-- Station de vente de l'oasis : comptoir de grès, auvent turquoise et
-- orange, pièce dorée (même lecture que la station de Green Valley).
local sellRoot = getFolder(Workspace, "SellZones")
replace(sellRoot, WORLD_ID)
local station = Instance.new("Model")
station.Name = WORLD_ID
local function stationPart(name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?): BasePart
	local p = part(station, name, size, CFrame.new(SELL_POSITION + offset), color)
	p.Shape = shape or Enum.PartType.Block
	p.CanQuery = false
	return p
end
local pad = stationPart("SellZonePad", Vector3.new(10, 0.4, 10), Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 214, 92))
pad:SetAttribute("SellZoneId", SELL_ZONE_ID)
stationPart("Counter", Vector3.new(6, 3, 2), Vector3.new(0, 1.9, -3.5), COLORS.ruin)
stationPart("PostLeft", Vector3.new(0.8, 7, 0.8), Vector3.new(-2.8, 3.9, -4.2), COLORS.palmTrunk)
stationPart("PostRight", Vector3.new(0.8, 7, 0.8), Vector3.new(2.8, 3.9, -4.2), COLORS.palmTrunk)
stationPart("Awning", Vector3.new(7.4, 0.6, 3.6), Vector3.new(0, 7.6, -3.8), COLORS.water)
stationPart("AwningTrim", Vector3.new(7.6, 0.5, 0.6), Vector3.new(0, 7.2, -1.9), COLORS.orange)
local coin = stationPart("Coin", Vector3.new(0.6, 2.6, 2.6), Vector3.new(0, 4.6, -3.5), COLORS.gold, Enum.PartType.Cylinder)
coin.CFrame = CFrame.new(world(SELL_POSITION + Vector3.new(0, 4.6, -3.5))) * CFrame.Angles(0, math.rad(90), 0)
coin.Material = Enum.Material.Neon
station.PrimaryPart = pad
station.Parent = sellRoot

-- RÉSUMÉ ---------------------------------------------------------------------

local decorParts = 0
for _, descendant in ipairs(root:GetDescendants()) do
	if descendant:IsA("BasePart") then
		decorParts += 1
		assert(descendant.Anchored and not descendant.CastShadow, `{descendant:GetFullName()} : ancrage ou ombre`)
	end
end
assert(decorParts <= DECOR_BUDGET, `budget de décor dépassé : {decorParts} > {DECOR_BUDGET}`)

local function distanceToSell(point: BasePart): number
	return (horizontal(point.Position - CENTER) - horizontal(SELL_POSITION)).Magnitude
end
local nearestToSell, nearestByType = math.huge, {}
for _, point in ipairs(pointFolder:GetChildren()) do
	local distance = distanceToSell(point)
	local resourceType = point:GetAttribute("ResourceType")
	nearestToSell = math.min(nearestToSell, distance)
	nearestByType[resourceType] = math.min(nearestByType[resourceType] or math.huge, distance)
end
local summary = {}
for resourceType, count in pairs(counts) do
	table.insert(summary, string.format("%s x%d (%.0f studs)", resourceType, count, nearestByType[resourceType]))
end
table.sort(summary)
return string.format(
	"Golden Desert : %d points [%s] ; décor %d parts (palmiers %d, cactus %d, rochers %d, touffes %d) ; total créé %d parts ; ressource la plus proche de la vente : %.1f studs",
	#pointFolder:GetChildren(),
	table.concat(summary, ", "),
	decorParts,
	palms,
	cacti,
	rocks,
	tufts,
	partCount,
	nearestToSell
)
