--!nocheck
-- Carte de Frozen Peaks (T8.4, D-021) en primitives scriptées : île
-- montagneuse enneigée, camp de base (arrivée, vente, portail de retour),
-- plateau enneigé, lac gelé et cascade gelée, grotte de cristaux bleus,
-- sommet panoramique du Diamant de glace.
--
-- Outil de développement, absent du jeu (non mappé dans
-- default.project.json). À exécuter dans Roblox Studio en mode Edit (barre
-- de commande ou serveur MCP). Rejouable : remplace ce qu'il a créé pour
-- Frozen Peaks, ne touche à rien d'autre (Green Valley, Golden Desert et
-- Lighting sont préservés). Résultat identique à chaque exécution (graine
-- fixe). Aucun asset externe, aucun texte ni logo dans le décor.
--
-- Crée (lus par le jeu) :
--   Workspace.Map.FrozenPeaks                     île, zones, décor
--     Portals.GreenValley.Field                   attribut `PortalWorldId`
--   Workspace.WorldArrivals.FrozenPeaks           attribut `ArrivalWorldId`
--   Workspace.ResourceSpawnPoints.FrozenPeaks     40 points, `ResourceType`
--   Workspace.SellZones.FrozenPeaks               `SellZonePad`, `SellZoneId`
-- Aucune SpawnLocation : l'apparition reste au hub de Green Valley (D5).
--
-- Valeurs, raretés et temps de réapparition : ResourceConfig (non lus ici,
-- sauf les poids de spawn pour le nombre de points). Apparence des nœuds :
-- ResourceVisualConfig (Systems/ResourceNodes).
--
-- Budget (audit T8) : ~1 200 parts de décor au plus, ~40 nœuds, aucune
-- lumière dynamique (la grotte est « éclairée » par des cristaux Neon),
-- CastShadow désactivé, décor ancré, collisions simples (feuillage, glace
-- décorative, cascade et champ du portail sans collision). Lighting
-- partagé par les quatre îles : non modifié (pas de brouillard).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)

local SEED = 20261116
local WORLD_ID = "FrozenPeaks"
local DECOR_BUDGET = 1200
-- Centre de l'île : à l'opposé de Golden Desert (3000 ; 0 ; 0), loin de
-- Green Valley (île et eau jusqu'à |x| = 700).
local CENTER = Vector3.new(-3000, 0, 0)

local TOTAL_SPAWN_POINTS = 40
local MIN_SPACING_STUDS = 6

-- Coordonnées locales (relatives à CENTER). +Z : nord (portail), -Z : sud.
-- ZONE A — arrivée et camp de base.
local PLAZA_RADIUS = 18
local ARRIVAL_POSITION = Vector3.new(0, 0.3, 6)
local PORTAL_POSITION = Vector3.new(0, 0, 26)
local SELL_ZONE_ID = "FrozenPeaks_Camp"
local SELL_POSITION = Vector3.new(14, 0, -12)
-- ZONE B — plateau enneigé (est, sud-est), ouvert depuis le camp.
local PLATEAU_REGION = { minX = 32, maxX = 116, minZ = -112, maxZ = 18 }
-- Éclats de glace : bord du plateau côté camp, à moins de 38 studs de la
-- vente (zone de base), à l'est de PLATEAU_EDGE_X.
local SHARD_FROM_SELL = { min = 11, max = 37 }
local PLATEAU_EDGE_X = 18
-- ZONE C — lac gelé (sud-ouest).
local LAKE_CENTER = Vector3.new(-48, 0, -58)
local LAKE_RADIUS = 22
-- Départ du chemin du lac (bord de la place) et arrivée sur la rive.
local LAKE_PATH_START = Vector3.new(-12, 0, -13)
local LAKE_PATH_END = LAKE_CENTER + (LAKE_PATH_START - LAKE_CENTER).Unit * (LAKE_RADIUS + 3)
local LAKE_ICE_TOP = 0.2
-- ZONE D — grotte de cristaux bleus (nord-ouest), entrée au sud.
local CAVE_CENTER = Vector3.new(-82, 0, 62)
local CAVE_HALF = Vector3.new(10, 0, 12) -- intérieur 20 × 24 studs
local CAVE_HEIGHT = 12
local CAVE_FLOOR_TOP = 0.4
-- ZONE E — sommet (nord-est) : épaulement à 12 studs, sommet à 24 studs.
local SHOULDER_CENTER = Vector3.new(72, 0, 92)
local SHOULDER_SIZE = Vector3.new(64, 12, 28) -- x 40..104, z 78..106
local SUMMIT_CENTER = Vector3.new(50, 0, 92)
local SUMMIT_SIZE = Vector3.new(16, 12, 16) -- x 42..58, z 84..100
local RAMP1_X = 96
local RAMP1_LENGTH = 48
local RAMP2_Z = 92
local CAP = 0.2 -- couche de neige au-dessus des blocs de roche
local PEDESTAL_HEIGHT = 1
-- Pont : sur le chemin camp → grotte, au-dessus du ruisseau gelé.
local BRIDGE_POINT = Vector3.new(-50, 0, 26)

local COLORS = {
	snow = Color3.fromRGB(234, 242, 250),
	snowShade = Color3.fromRGB(214, 228, 242),
	packed = Color3.fromRGB(196, 214, 232),
	ice = Color3.fromRGB(150, 214, 240),
	iceDeep = Color3.fromRGB(96, 170, 222),
	turquoise = Color3.fromRGB(80, 200, 210),
	deepBlue = Color3.fromRGB(46, 92, 160),
	rock = Color3.fromRGB(128, 136, 150),
	rockDark = Color3.fromRGB(96, 104, 120),
	rockLight = Color3.fromRGB(160, 168, 180),
	caveFloor = Color3.fromRGB(70, 86, 116),
	crystal = Color3.fromRGB(70, 150, 255),
	crystalLight = Color3.fromRGB(140, 200, 255),
	fir = Color3.fromRGB(48, 110, 76),
	firDark = Color3.fromRGB(36, 90, 64),
	trunk = Color3.fromRGB(110, 76, 52),
	wood = Color3.fromRGB(150, 104, 66),
	woodDark = Color3.fromRGB(118, 80, 52),
	canvasRed = Color3.fromRGB(214, 84, 70),
	canvasOrange = Color3.fromRGB(232, 146, 60),
	ember = Color3.fromRGB(255, 140, 50),
	sea = Color3.fromRGB(40, 110, 170),
	arrival = Color3.fromRGB(120, 200, 255),
	portal = Color3.fromRGB(116, 178, 92),
	gold = Color3.fromRGB(255, 196, 40),
}

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

-- Cristal Neon décoratif (sans collision) : la « lumière » de la grotte,
-- sans lumière dynamique.
local function crystalCluster(parent: Instance, name: string, base: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = name
	for index = 1, 3 do
		local height = (2.2 + index * 0.7) * scale
		local tilt = CFrame.Angles(math.rad(random:NextNumber(-22, 22)), math.rad(random:NextNumber(0, 90)), math.rad(random:NextNumber(-22, 22)))
		local offset = Vector3.new(random:NextNumber(-0.8, 0.8), 0, random:NextNumber(-0.8, 0.8)) * scale
		local p = part(model, `Shard{index}`, Vector3.new(0.8, height, 0.8) * Vector3.new(scale, 1, scale), CFrame.new(base + offset) * tilt * CFrame.new(0, height / 2 - 0.3, 0), if index == 2 then COLORS.crystalLight else COLORS.crystal, false)
		p.Material = Enum.Material.Neon
	end
	model.Parent = parent
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
-- Rectangle horizontal réservé (blocs de montagne, grotte).
local function reserveBox(center: Vector3, size: Vector3)
	local step = 4
	for x = -size.X / 2, size.X / 2, step do
		for z = -size.Z / 2, size.Z / 2, step do
			reserve(center + Vector3.new(x, 0, z), step * 0.75)
		end
	end
end

-- Bande plate entre deux points locaux (chemin de neige tassée ou glace).
local function strip(parent: Instance, name: string, from: Vector3, to: Vector3, width: number, color: Color3, thickness: number?)
	local t = thickness or 0.14
	local a, b = horizontal(from), horizontal(to)
	local length = (b - a).Magnitude
	local middle = (a + b) / 2 + Vector3.new(0, t / 2, 0)
	local p = part(parent, name, Vector3.new(width, t, length + 1), CFrame.lookAt(middle, b + Vector3.new(0, t / 2, 0)), color)
	for step = 0, math.ceil(length / 4) do
		reserve(a:Lerp(b, math.min(step * 4 / length, 1)), width / 2 + 0.5)
	end
	return p
end
local function pathSegment(parent: Instance, name: string, from: Vector3, to: Vector3, width: number)
	return strip(parent, name, from, to, width, COLORS.packed)
end

-- Sur l'une des trois dalles de l'île, à `margin` studs du bord au moins.
local function onIsland(position: Vector3, margin: number): boolean
	local ax, az = math.abs(position.X), math.abs(position.Z)
	return (ax < 120 - margin and az < 120 - margin)
		or (ax < 135 - margin and az < 90 - margin)
		or (ax < 90 - margin and az < 135 - margin)
end

-- Bloc de roche coiffé de neige (silhouette low-poly des montagnes).
local function cappedBlock(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3)
	part(parent, name, size, cframe, color)
	part(parent, `{name}Snow`, Vector3.new(size.X + 0.3, 0.6, size.Z + 0.3), cframe * CFrame.new(0, size.Y / 2, 0), COLORS.snow)
end

-- Pic de fond : couches de blocs tournés, de plus en plus étroites, roche
-- en bas, neige en haut. Infranchissable (solide), hors des zones de jeu.
local function peak(parent: Instance, name: string, base: Vector3, width: number, height: number)
	local model = Instance.new("Model")
	model.Name = name
	local layers = 4
	local y = 0
	for layer = 0, layers - 1 do
		local w = width * (1 - 0.22 * layer)
		local h = height / layers * (1 + 0.15 * layer)
		local color = if layer < 2 then (if layer == 0 then COLORS.rockDark else COLORS.rock) elseif layer == 2 then COLORS.snowShade else COLORS.snow
		part(model, `Layer{layer + 1}`, Vector3.new(w, h, w * random:NextNumber(0.8, 1)), CFrame.new(base + Vector3.new(random:NextNumber(-1, 1), y + h / 2, random:NextNumber(-1, 1))) * CFrame.Angles(0, math.rad(45 + layer * 14 + random:NextNumber(-6, 6)), 0), color)
		y += h * 0.92
	end
	model.Parent = parent
	reserve(base, width * 0.72)
end

-- CARTE ----------------------------------------------------------------------

local map = getFolder(Workspace, "Map")
replace(map, WORLD_ID)
local root = Instance.new("Folder")
root.Name = WORLD_ID

-- Île : trois dalles croisées (environ 270 × 270 studs) de neige, falaise
-- de roche dessous, mer froide autour (sans collision : une chute fait
-- réapparaître au hub de Green Valley, D5).
local island = newFolder(root, "Island")
for index, size in ipairs({ Vector3.new(240, 4, 240), Vector3.new(270, 4, 180), Vector3.new(180, 4, 270) }) do
	part(island, `Ground{index}`, size, CFrame.new(0, -2, 0), COLORS.snow)
	part(island, `Cliff{index}`, size + Vector3.new(4, 6, 4), CFrame.new(0, -6.9, 0), COLORS.rockDark)
end
part(island, "Sea", Vector3.new(1000, 1, 1000), CFrame.new(0, -8, 0), COLORS.sea, false).Transparency = 0.15

-- ZONE A — Arrivée et camp de base -----------------------------------------

local camp = newFolder(root, "ZoneA_Camp")
disk(camp, "Plaza", PLAZA_RADIUS * 2, 0.2, Vector3.new(0, 0.1, 0), COLORS.packed)

-- Portail de retour vers Green Valley (champ traversable lu par
-- TravelController) : piliers de roche coiffés de neige, linteau vert.
local portals = newFolder(root, "Portals")
do
	local model = Instance.new("Model")
	model.Name = "GreenValley"
	local p = PORTAL_POSITION
	part(model, "Step", Vector3.new(10, 0.6, 4), CFrame.new(p + Vector3.new(0, 0.3, 0)), COLORS.rockLight)
	part(model, "PillarLeft", Vector3.new(1.8, 10, 1.8), CFrame.new(p + Vector3.new(-4.2, 5.6, 0)), COLORS.rock)
	part(model, "PillarRight", Vector3.new(1.8, 10, 1.8), CFrame.new(p + Vector3.new(4.2, 5.6, 0)), COLORS.rock)
	part(model, "Lintel", Vector3.new(10, 1.6, 2), CFrame.new(p + Vector3.new(0, 11.4, 0)), COLORS.portal)
	part(model, "LintelSnow", Vector3.new(10.4, 0.5, 2.4), CFrame.new(p + Vector3.new(0, 12.4, 0)), COLORS.snow)
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

-- Camp : deux tentes (dièdres en WedgeParts), feu de camp (braises Neon,
-- aucune lumière), caisses, poteau indicateur à trois flèches de couleur
-- (bleu : grotte, turquoise : lac, blanc : sommet), sans texte.
local function tent(name: string, base: Vector3, yaw: number, color: Color3)
	local model = Instance.new("Model")
	model.Name = name
	local frame = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
	-- Deux pans inclinés dos à dos (bas au -Z local de chaque WedgePart).
	wedge(model, "SideA", Vector3.new(6, 4, 2.6), frame * CFrame.new(0, 2, -1.3), color)
	wedge(model, "SideB", Vector3.new(6, 4, 2.6), frame * CFrame.new(0, 2, 1.3) * CFrame.Angles(0, math.pi, 0), color)
	part(model, "Door", Vector3.new(0.2, 2.4, 1.6), frame * CFrame.new(3.05, 1.2, 0), COLORS.woodDark, false)
	model.Parent = camp
	reserve(base, 4.5)
end
tent("TentRed", Vector3.new(-12, 0, -27), 20, COLORS.canvasRed)
tent("TentOrange", Vector3.new(-26, 0, -18), -35, COLORS.canvasOrange)
do
	local fire = Instance.new("Model")
	fire.Name = "Campfire"
	local c = Vector3.new(-4, 0, -24)
	for index = 0, 5 do
		local angle = math.rad(index * 60)
		part(fire, `Stone{index + 1}`, Vector3.new(1, 0.7, 1), CFrame.new(c + Vector3.new(math.cos(angle) * 1.8, 0.35, math.sin(angle) * 1.8)), COLORS.rock)
	end
	for index = 0, 2 do
		part(fire, `Log{index + 1}`, Vector3.new(2.6, 0.5, 0.5), CFrame.new(c + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, math.rad(index * 60), 0), COLORS.trunk)
	end
	local ember = part(fire, "Embers", Vector3.new(1, 0.9, 1), CFrame.new(c + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, math.rad(45), 0), COLORS.ember, false)
	ember.Material = Enum.Material.Neon
	fire.Parent = camp
	reserve(c, 3)
	for index, offset in ipairs({ Vector3.new(-31, 0, -9), Vector3.new(-29, 0, -6), Vector3.new(-6, 0, -31) }) do
		part(camp, `Crate{index}`, Vector3.new(2, 2, 2), CFrame.new(offset + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(random:NextNumber(0, 40)), 0), COLORS.wood)
		reserve(offset, 2)
	end
end
-- Poteau indicateur sur la place.
local SIGN_POSITION = Vector3.new(-8, 0, -6)
local signTargets = {
	{ name = "ToCave", target = Vector3.new(CAVE_CENTER.X, 0, CAVE_CENTER.Z - CAVE_HALF.Z), color = COLORS.crystal, y = 5.2 },
	{ name = "ToLake", target = LAKE_CENTER, color = COLORS.turquoise, y = 4.2 },
	{ name = "ToSummit", target = Vector3.new(RAMP1_X, 0, 30), color = COLORS.snow, y = 3.2 },
}
do
	local sign = Instance.new("Model")
	sign.Name = "Signpost"
	part(sign, "Post", Vector3.new(0.6, 6, 0.6), CFrame.new(SIGN_POSITION + Vector3.new(0, 3, 0)), COLORS.woodDark)
	for _, info in ipairs(signTargets) do
		local from = SIGN_POSITION + Vector3.new(0, info.y, 0)
		local direction = (horizontal(info.target) - horizontal(SIGN_POSITION)).Unit
		local look = CFrame.lookAt(from + direction * 1.6, from + direction * 3)
		part(sign, info.name, Vector3.new(0.3, 0.7, 2.6), look, info.color)
		-- Pointe de flèche (WedgePart couché).
		part(sign, `{info.name}Tip`, Vector3.new(0.3, 0.7, 0.7), look * CFrame.new(0, 0, -1.6) * CFrame.Angles(0, 0, 0), info.color, true, "WedgePart")
	end
	sign.Parent = camp
	reserve(SIGN_POSITION, 1.5)
end

-- Chemins depuis la place : grotte (nord-ouest, par le pont), lac
-- (sud-ouest), sommet (nord-est), plateau (est).
local paths = newFolder(root, "Paths")
local CAVE_ENTRANCE = Vector3.new(CAVE_CENTER.X, 0, CAVE_CENTER.Z - CAVE_HALF.Z)
pathSegment(paths, "ToCave1", Vector3.new(-16, 0, 5), BRIDGE_POINT, 6)
pathSegment(paths, "ToCave2", BRIDGE_POINT, CAVE_ENTRANCE + Vector3.new(0, 0, 2), 6)
pathSegment(paths, "ToLake", LAKE_PATH_START, LAKE_PATH_END, 6)
pathSegment(paths, "ToSummit", Vector3.new(14, 0, 13), Vector3.new(RAMP1_X, 0, 30), 6)
pathSegment(paths, "ToPlateau1", Vector3.new(PLAZA_RADIUS, 0, 0), Vector3.new(60, 0, -22), 4)
pathSegment(paths, "ToPlateau2", Vector3.new(60, 0, -22), Vector3.new(88, 0, -62), 4)
pathSegment(paths, "ToPlateau3", Vector3.new(60, 0, -22), Vector3.new(100, 0, -6), 4)

-- ZONE B — Plateau enneigé : sapins et rochers placés avec le décor ;
-- congères (deux WedgeParts dos à dos) ici.
local plateau = newFolder(root, "ZoneB_Plateau")
local DRIFTS = {
	{ x = 48, z = -78, length = 18, height = 2 },
	{ x = 104, z = -88, length = 16, height = 2.4 },
	{ x = 76, z = 4, length = 14, height = 1.6 },
	{ x = 112, z = -40, length = 12, height = 2 },
	{ x = 30, z = -104, length = 16, height = 1.8 },
}
for index, info in ipairs(DRIFTS) do
	local model = Instance.new("Model")
	model.Name = `Drift{index}`
	local frame = CFrame.new(info.x, 0, info.z) * CFrame.Angles(0, math.rad(random:NextNumber(-30, 30)), 0)
	local windward, lee = info.height * 3, info.height * 1.6
	wedge(model, "Windward", Vector3.new(info.length, info.height, windward), frame * CFrame.new(0, info.height / 2, -windward / 2), COLORS.snowShade)
	wedge(model, "Lee", Vector3.new(info.length, info.height, lee), frame * CFrame.new(0, info.height / 2, lee / 2) * CFrame.Angles(0, math.pi, 0), COLORS.snowShade)
	model.Parent = plateau
	reserve(Vector3.new(info.x, 0, info.z), math.max(info.length / 2, windward) + 1)
end

-- ZONE C — Lac gelé ------------------------------------------------------

local lake = newFolder(root, "ZoneC_Lake")
disk(lake, "Shore", LAKE_RADIUS * 2 + 8, 0.16, LAKE_CENTER + Vector3.new(0, 0.08, 0), COLORS.snowShade)
-- Glace solide : on marche sur le lac.
disk(lake, "Ice", LAKE_RADIUS * 2, LAKE_ICE_TOP, LAKE_CENTER + Vector3.new(0, LAKE_ICE_TOP / 2, 0), COLORS.ice)
disk(lake, "IceDeep", LAKE_RADIUS, 0.06, LAKE_CENTER + Vector3.new(4, LAKE_ICE_TOP + 0.03, -3), COLORS.iceDeep, false)
-- Formations de glace sur la rive (hors arrivée du chemin et du ruisseau).
for index, angleDeg in ipairs({ 160, 200, 235, 275, 310, 345 }) do
	local angle = math.rad(angleDeg)
	local base = LAKE_CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (LAKE_RADIUS + 2.5)
	local model = Instance.new("Model")
	model.Name = `IceFormation{index}`
	for spike = 1, 2 do
		local height = random:NextNumber(4, 7) / spike
		local p = part(model, `Spike{spike}`, Vector3.new(1.6, height, 1.6) / Vector3.new(spike, 1, spike), CFrame.new(base + Vector3.new(spike - 1.5, 0, spike - 1.5) * 1.4) * CFrame.Angles(math.rad(random:NextNumber(-12, 12)), math.rad(45), math.rad(random:NextNumber(-12, 12))) * CFrame.new(0, height / 2 - 0.2, 0), COLORS.ice)
		p.Transparency = 0.1
	end
	model.Parent = lake
	reserve(base, 2.5)
end
-- Passage rocheux à l'arrivée du chemin.
do
	local a, b = LAKE_PATH_START, LAKE_PATH_END
	local normal = (b - a).Unit:Cross(Vector3.new(0, 1, 0))
	for side = -1, 1, 2 do
		for step = 0, 1 do
			local base = b + (a - b).Unit * (2 + step * 6) + normal * side * 5
			part(lake, `PassRock{side}_{step}`, Vector3.new(3.4, 3 + step, 3), CFrame.new(base + Vector3.new(0, (3 + step) / 2 - 0.3, 0)) * CFrame.Angles(0, math.rad(random:NextNumber(0, 60)), math.rad(random:NextNumber(-6, 6))), if step == 0 then COLORS.rock else COLORS.rockDark)
			reserve(base, 2.4)
		end
	end
end
-- Falaise et cascade gelée à l'ouest du lac, bassin gelé relié au lac.
do
	local falls = Instance.new("Model")
	falls.Name = "FrozenFalls"
	local cliff = CFrame.new(-104, 9, -88) * CFrame.Angles(0, math.rad(20), 0)
	cappedBlock(falls, "Cliff", Vector3.new(14, 18, 12), cliff, COLORS.rock)
	part(falls, "CliffSide", Vector3.new(8, 12, 8), cliff * CFrame.new(-2, -3, 9) * CFrame.Angles(0, math.rad(25), 0), COLORS.rockDark)
	for index, offset in ipairs({ -3, 0, 3 }) do
		local height = 15 - math.abs(offset)
		local ice = part(falls, `Fall{index}`, Vector3.new(1.4, height, 2.4), cliff * CFrame.new(7.4, height / 2 - 9 + 0.2, offset), if index == 2 then COLORS.crystalLight else COLORS.ice, false)
		ice.Transparency = 0.15
	end
	falls.Parent = lake
	reserve(Vector3.new(-104, 0, -88), 10)
	reserve((cliff * CFrame.new(-2, 0, 9)).Position, 6)
	local pool = horizontal((cliff * CFrame.new(12, 0, 0)).Position)
	disk(lake, "FallsPool", 10, 0.18, pool + Vector3.new(0, 0.09, 0), COLORS.ice)
	reserve(pool, 5)
	strip(lake, "FallsStream", pool, LAKE_CENTER + (pool - LAKE_CENTER).Unit * (LAKE_RADIUS - 1), 4, COLORS.ice, 0.16)
end

-- Ruisseau gelé : pied des pics du nord → pont → lac.
local stream = { Vector3.new(-34, 0, 72), BRIDGE_POINT, LAKE_CENTER + (BRIDGE_POINT - LAKE_CENTER).Unit * (LAKE_RADIUS - 1) }
for index = 1, #stream - 1 do
	strip(lake, `Stream{index}`, stream[index], stream[index + 1], 5, COLORS.ice, 0.12)
end

-- Pont de bois sur le ruisseau, dans l'axe du chemin de la grotte.
do
	local bridge = Instance.new("Model")
	bridge.Name = "Bridge"
	local direction = (horizontal(CAVE_ENTRANCE) - horizontal(Vector3.new(-16, 0, 5))).Unit
	local deckTop = 1.6
	local deck = CFrame.lookAt(BRIDGE_POINT + Vector3.new(0, deckTop - 0.3, 0), BRIDGE_POINT + direction + Vector3.new(0, deckTop - 0.3, 0))
	part(bridge, "Deck", Vector3.new(6, 0.6, 10), deck, COLORS.wood)
	-- Rampes d'accès : bas du WedgePart (-Z local) côté chemin.
	for side = -1, 1, 2 do
		local center = BRIDGE_POINT + direction * side * 7.5 + Vector3.new(0, deckTop / 2, 0)
		wedge(bridge, `Ramp{side}`, Vector3.new(6, deckTop, 5), CFrame.lookAt(center, center + direction * side), COLORS.woodDark)
	end
	for side = -1, 1, 2 do
		part(bridge, `Rail{side}`, Vector3.new(0.4, 0.4, 10), deck * CFrame.new(side * 3.1, 1.3, 0), COLORS.woodDark)
		for post = -1, 1, 2 do
			part(bridge, `Post{side}_{post}`, Vector3.new(0.5, 1.5, 0.5), deck * CFrame.new(side * 3.1, 0.75, post * 4.6), COLORS.woodDark)
		end
	end
	bridge.Parent = lake
	reserve(BRIDGE_POINT, 9)
end

-- ZONE D — Grotte de cristaux bleus ---------------------------------------

local cave = newFolder(root, "ZoneD_Cave")
do
	local c = CAVE_CENTER
	local hx, hz = CAVE_HALF.X, CAVE_HALF.Z
	part(cave, "Floor", Vector3.new(hx * 2, CAVE_FLOOR_TOP, hz * 2), CFrame.new(c + Vector3.new(0, CAVE_FLOOR_TOP / 2, 0)), COLORS.caveFloor)
	part(cave, "WallWest", Vector3.new(4, CAVE_HEIGHT, hz * 2 + 4), CFrame.new(c + Vector3.new(-hx - 2, CAVE_HEIGHT / 2, 2)), COLORS.rockDark)
	part(cave, "WallEast", Vector3.new(4, CAVE_HEIGHT, hz * 2 + 4), CFrame.new(c + Vector3.new(hx + 2, CAVE_HEIGHT / 2, 2)), COLORS.rockDark)
	part(cave, "WallBack", Vector3.new(hx * 2 + 8, CAVE_HEIGHT, 4), CFrame.new(c + Vector3.new(0, CAVE_HEIGHT / 2, hz + 2)), COLORS.rockDark)
	cappedBlock(cave, "Roof", Vector3.new(hx * 2 + 10, 4, hz * 2 + 8), CFrame.new(c + Vector3.new(0, CAVE_HEIGHT + 2, 2)), COLORS.rock)
	-- Masse de la montagne autour et au-dessus de la grotte.
	cappedBlock(cave, "MassBack", Vector3.new(40, 20, 14), CFrame.new(c + Vector3.new(-2, 10, hz + 11)) * CFrame.Angles(0, math.rad(4), 0), COLORS.rock)
	cappedBlock(cave, "MassWest", Vector3.new(12, 17, 30), CFrame.new(c + Vector3.new(-hx - 9, 8.5, 4)) * CFrame.Angles(0, math.rad(-6), 0), COLORS.rockDark)
	cappedBlock(cave, "MassEast", Vector3.new(9, 15, 24), CFrame.new(c + Vector3.new(hx + 7.5, 7.5, 7)) * CFrame.Angles(0, math.rad(8), 0), COLORS.rock)
	cappedBlock(cave, "RoofPeak1", Vector3.new(20, 6, 18), CFrame.new(c + Vector3.new(-2, CAVE_HEIGHT + 7, 6)) * CFrame.Angles(0, math.rad(30), 0), COLORS.rockLight)
	cappedBlock(cave, "RoofPeak2", Vector3.new(11, 6, 10), CFrame.new(c + Vector3.new(-3, CAVE_HEIGHT + 13, 8)) * CFrame.Angles(0, math.rad(55), 0), COLORS.rock)
	reserveBox(c + Vector3.new(-2, 0, 6), Vector3.new(hx * 2 + 22, 0, hz * 2 + 24))
	-- Entrée : rochers d'encadrement, stalactites de glace, grands cristaux
	-- de part et d'autre (repère visible depuis le pont).
	local front = c.Z - hz
	for side = -1, 1, 2 do
		part(cave, `EntranceRock{side}`, Vector3.new(5, 9, 4), CFrame.new(c.X + side * (hx + 1), 4.5, front - 1) * CFrame.Angles(0, math.rad(side * 12), math.rad(side * -4)), COLORS.rock)
		crystalCluster(cave, `EntranceCrystal{side}`, Vector3.new(c.X + side * (hx - 1.5), CAVE_FLOOR_TOP, front + 1.5), 1.5)
	end
	for index = 0, 5 do
		local x = c.X - hx + 2 + index * 3.2
		local length = random:NextNumber(1.6, 3)
		local icicle = part(cave, `Icicle{index + 1}`, Vector3.new(0.7, length, 0.7), CFrame.new(x, CAVE_HEIGHT - length / 2, front + 0.8) * CFrame.Angles(0, math.rad(45), 0), COLORS.ice, false)
		icicle.Transparency = 0.1
	end
	-- Cristaux intérieurs le long des parois (sans collision).
	for index, offset in ipairs({
		Vector3.new(-8.5, 0, -4), Vector3.new(-8.5, 0, 4), Vector3.new(-8.5, 0, 10),
		Vector3.new(8.5, 0, -2), Vector3.new(8.5, 0, 6), Vector3.new(8.5, 0, 10.5),
		Vector3.new(-3, 0, 10.5), Vector3.new(3, 0, 10.5),
	}) do
		crystalCluster(cave, `WallCrystal{index}`, c + offset + Vector3.new(0, CAVE_FLOOR_TOP, 0), random:NextNumber(0.9, 1.3))
	end
end
-- Cristaux bleus (ressource) : au centre de la grotte, à l'écart des parois.
local blueSpots = {
	CAVE_CENTER + Vector3.new(-4, CAVE_FLOOR_TOP, -6),
	CAVE_CENTER + Vector3.new(4, CAVE_FLOOR_TOP, -3),
	CAVE_CENTER + Vector3.new(-3, CAVE_FLOOR_TOP, 5),
	CAVE_CENTER + Vector3.new(4, CAVE_FLOOR_TOP, 6),
}

-- ZONE E — Sommet panoramique ---------------------------------------------

local summit = newFolder(root, "ZoneE_Summit")
local shoulderTop = SHOULDER_SIZE.Y
local summitTop = SHOULDER_SIZE.Y + SUMMIT_SIZE.Y
do
	part(summit, "Shoulder", SHOULDER_SIZE, CFrame.new(SHOULDER_CENTER + Vector3.new(0, SHOULDER_SIZE.Y / 2, 0)), COLORS.rock)
	part(summit, "ShoulderSnow", Vector3.new(SHOULDER_SIZE.X + 0.4, 0.4, SHOULDER_SIZE.Z + 0.4), CFrame.new(SHOULDER_CENTER + Vector3.new(0, shoulderTop + CAP - 0.2, 0)), COLORS.snow)
	part(summit, "Summit", SUMMIT_SIZE, CFrame.new(SUMMIT_CENTER + Vector3.new(0, shoulderTop + SUMMIT_SIZE.Y / 2, 0)), COLORS.rockLight)
	part(summit, "SummitSnow", Vector3.new(SUMMIT_SIZE.X + 0.4, 0.4, SUMMIT_SIZE.Z + 0.4), CFrame.new(SUMMIT_CENTER + Vector3.new(0, summitTop + CAP - 0.2, 0)), COLORS.snow)
	-- Rampe 1 (sud → épaulement) : bas au -Z local (sud).
	local ramp1End = SHOULDER_CENTER.Z - SHOULDER_SIZE.Z / 2
	wedge(summit, "Ramp1", Vector3.new(8, shoulderTop, RAMP1_LENGTH), CFrame.new(RAMP1_X, shoulderTop / 2, ramp1End - RAMP1_LENGTH / 2), COLORS.packed)
	for index = 0, 4 do
		local z = ramp1End - 6 - index * 10
		local rise = shoulderTop * (1 - (ramp1End - z) / RAMP1_LENGTH)
		part(summit, `Ramp1RockL{index}`, Vector3.new(2.4, 2 + rise, 3), CFrame.new(RAMP1_X - 5.4, (2 + rise) / 2, z), COLORS.rockDark)
		part(summit, `Ramp1RockR{index}`, Vector3.new(2.4, 2 + rise, 3), CFrame.new(RAMP1_X + 5.4, (2 + rise) / 2, z), COLORS.rock)
	end
	reserveBox(Vector3.new(RAMP1_X, 0, ramp1End - RAMP1_LENGTH / 2), Vector3.new(14, 0, RAMP1_LENGTH + 4))
	-- Rampe 2 (épaulement, est → sommet à l'ouest) : haut (+Z local) vers -X.
	local ramp2High = SUMMIT_CENTER.X + SUMMIT_SIZE.X / 2
	local ramp2Length = 40
	wedge(summit, "Ramp2", Vector3.new(8, SUMMIT_SIZE.Y, ramp2Length), CFrame.new(ramp2High + ramp2Length / 2, shoulderTop + SUMMIT_SIZE.Y / 2, RAMP2_Z) * CFrame.Angles(0, math.rad(-90), 0), COLORS.packed)
	for index = 0, 3 do
		local x = ramp2High + 5 + index * 10
		local rise = SUMMIT_SIZE.Y * (1 - (x - ramp2High) / ramp2Length)
		part(summit, `Ramp2Rock{index}`, Vector3.new(3, 2 + rise, 2.4), CFrame.new(x, shoulderTop + (2 + rise) / 2, RAMP2_Z + 5.4), COLORS.rockDark)
	end
	-- Blocs de falaise autour de l'épaulement (silhouette), hors rampe 1.
	for index, info in ipairs({
		{ offset = Vector3.new(-34, 0, 4), size = Vector3.new(10, 16, 14) },
		{ offset = Vector3.new(-20, 0, 16), size = Vector3.new(14, 18, 10) },
		{ offset = Vector3.new(4, 0, 17), size = Vector3.new(16, 15, 10) },
		{ offset = Vector3.new(26, 0, 16), size = Vector3.new(12, 13, 10) },
		{ offset = Vector3.new(34, 0, 2), size = Vector3.new(10, 11, 14) },
		{ offset = Vector3.new(-14, 0, -16), size = Vector3.new(14, 10, 8) },
		{ offset = Vector3.new(6, 0, -16), size = Vector3.new(12, 9, 8) },
	}) do
		local s = info.size
		cappedBlock(summit, `Cliff{index}`, s, CFrame.new(SHOULDER_CENTER + info.offset + Vector3.new(0, s.Y / 2, 0)) * CFrame.Angles(0, math.rad(random:NextNumber(-20, 20)), 0), if index % 2 == 0 then COLORS.rockDark else COLORS.rock)
	end
	reserveBox(SHOULDER_CENTER, SHOULDER_SIZE + Vector3.new(16, 0, 16))
	-- Belvédère : muret de pierres sur trois côtés (l'est reste ouvert pour
	-- la rampe), cairn et fanion bleu sans texte.
	local s = SUMMIT_CENTER + Vector3.new(0, summitTop + CAP, 0)
	local half = SUMMIT_SIZE.X / 2 - 0.6
	for index, info in ipairs({
		{ offset = Vector3.new(0, 0, -half), size = Vector3.new(14, 1.2, 1) },
		{ offset = Vector3.new(0, 0, half), size = Vector3.new(14, 1.2, 1) },
		{ offset = Vector3.new(-half, 0, 0), size = Vector3.new(1, 1.2, 14) },
	}) do
		part(summit, `Parapet{index}`, info.size, CFrame.new(s + info.offset + Vector3.new(0, 0.6, 0)), COLORS.rockLight)
	end
	for index = 0, 2 do
		local size = 1.8 - index * 0.5
		part(summit, `Cairn{index + 1}`, Vector3.new(size, 0.8, size), CFrame.new(s + Vector3.new(-5, 0.4 + index * 0.8, -5)) * CFrame.Angles(0, math.rad(index * 30), 0), COLORS.rock)
	end
	part(summit, "FlagPole", Vector3.new(0.3, 7, 0.3), CFrame.new(s + Vector3.new(-5, 3.5, 5)), COLORS.woodDark)
	part(summit, "Flag", Vector3.new(0.15, 1.6, 2.6), CFrame.new(s + Vector3.new(-5, 6, 6.4)), COLORS.crystal, false)
	-- Couronne de petits cristaux autour du piédestal (mise en valeur).
	disk(summit, "Pedestal", 4, PEDESTAL_HEIGHT, Vector3.new(s.X, s.Y + PEDESTAL_HEIGHT / 2, s.Z), COLORS.ice)
	for index = 0, 5 do
		local angle = math.rad(index * 60 + 30)
		crystalCluster(summit, `Crown{index + 1}`, s + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4), 0.6)
	end
end
local diamondSpot = SUMMIT_CENTER + Vector3.new(0, summitTop + CAP + PEDESTAL_HEIGHT, 0)

-- Pics de fond (infranchissables, bords de l'île).
local peaks = newFolder(root, "Peaks")
for index, info in ipairs({
	{ x = -14, z = 116, width = 34, height = 44 },
	{ x = 26, z = 122, width = 22, height = 30 },
	{ x = -124, z = -26, width = 22, height = 28 },
	{ x = 112, z = -108, width = 20, height = 24 },
	{ x = -104, z = -114, width = 18, height = 22 },
	{ x = 124, z = 42, width = 18, height = 22 },
	{ x = -122, z = 30, width = 16, height = 20 },
}) do
	peak(peaks, `Peak{index}`, Vector3.new(info.x, 0, info.z), info.width, info.height)
end

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
assert(counts.blue_crystal == #blueSpots, `Cristal bleu : {counts.blue_crystal} point(s), {#blueSpots} emplacements`)
assert(counts.ice_diamond == 1, `Diamant de glace : {counts.ice_diamond} point(s), 1 attendu`)

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
	for _ = 1, 800 do
		local candidate = sample()
		if onIsland(candidate, 8) and not inFootprint(candidate, 2.5) and isFree(candidate, MIN_SPACING_STUDS) then
			return candidate
		end
	end
	error(`aucune place libre pour {what}`)
end

local function distanceToSell(position: Vector3): number
	return (horizontal(position) - horizontal(SELL_POSITION)).Magnitude
end

-- Éclats de glace (Commune) : bord du plateau enneigé côté camp, à moins de
-- 38 studs de la vente.
for index = 1, counts.ice_shard do
	spawnPoint("ice_shard", index, randomPoint(function()
		for _ = 1, 50 do
			local angle = random:NextNumber(0, 2 * math.pi)
			local radius = random:NextNumber(SHARD_FROM_SELL.min, SHARD_FROM_SELL.max)
			local candidate = SELL_POSITION + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			if candidate.X > PLATEAU_EDGE_X and horizontal(candidate).Magnitude > PLAZA_RADIUS + 2 then
				return candidate
			end
		end
		return SELL_POSITION
	end, "ice_shard"))
end
-- Argent brut (Commune dans ResourceConfig) : lac gelé (8 sur la glace) et
-- pentes rocheuses de la rive (le reste, entre les formations de glace).
local SILVER_ON_ICE = 8
for index = 1, counts.silver_ore do
	local onIce = index <= SILVER_ON_ICE
	local position = randomPoint(function()
		local angle = random:NextNumber(0, 2 * math.pi)
		local radius = if onIce then random:NextNumber(5, LAKE_RADIUS - 3) else random:NextNumber(LAKE_RADIUS + 2, LAKE_RADIUS + 12)
		return LAKE_CENTER + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end, "silver_ore")
	spawnPoint("silver_ore", index, position + Vector3.new(0, if onIce then LAKE_ICE_TOP else 0, 0))
end
-- Pierres gelées (Peu commune dans ResourceConfig) : chemins de montagne
-- et zones rocheuses, au bord du chemin du sommet (5) et de celui de la
-- grotte (2), hors du chemin lui-même.
local STONE_TRAILS = {
	{ from = Vector3.new(14, 0, 13), to = Vector3.new(RAMP1_X, 0, 30), tMin = 0.35, count = 5 },
	{ from = BRIDGE_POINT, to = CAVE_ENTRANCE, tMin = 0.2, count = 2 },
}
do
	local index = 0
	for _, trail in ipairs(STONE_TRAILS) do
		local normal = (trail.to - trail.from).Unit:Cross(Vector3.new(0, 1, 0))
		for _ = 1, trail.count do
			index += 1
			spawnPoint("frozen_stone", index, randomPoint(function()
				local side = if random:NextNumber() < 0.5 then -1 else 1
				return trail.from:Lerp(trail.to, random:NextNumber(trail.tMin, 1)) + normal * side * random:NextNumber(5, 10)
			end, "frozen_stone"))
		end
	end
	assert(index == counts.frozen_stone, `Pierre gelée : {counts.frozen_stone} point(s), {index} prévus`)
end
for index, position in ipairs(blueSpots) do
	spawnPoint("blue_crystal", index, position)
end
spawnPoint("ice_diamond", 1, diamondSpot)
pointFolder.Parent = spawnRoot

-- DÉCOR (graine fixe, à l'écart des ressources, chemins et zones) -----------

local decor = newFolder(root, "Decor")

local function decorPosition(clearance: number, region: { minX: number, maxX: number, minZ: number, maxZ: number }?): Vector3?
	for _ = 1, 300 do
		local candidate = if region
			then Vector3.new(random:NextNumber(region.minX, region.maxX), 0, random:NextNumber(region.minZ, region.maxZ))
			else Vector3.new(random:NextNumber(-130, 130), 0, random:NextNumber(-130, 130))
		local flat = horizontal(candidate)
		local onLake = (flat - horizontal(LAKE_CENTER)).Magnitude < LAKE_RADIUS + 5
		if onIsland(candidate, 6) and flat.Magnitude > PLAZA_RADIUS + 6 and not onLake and not inFootprint(candidate, 2) and isFree(candidate, clearance) then
			return candidate
		end
	end
	return nil
end

-- Sapin enneigé : tronc solide, trois étages tournés à 45°, chapeau de neige
-- (feuillage sans collision).
local function fir(parent: Instance, name: string, base: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = name
	part(model, "Trunk", Vector3.new(0.9, 2.4, 0.9) * scale, CFrame.new(base + Vector3.new(0, 1.2 * scale, 0)), COLORS.trunk)
	local y = 2 * scale
	for tier = 1, 3 do
		local width = (5 - tier * 1.1) * scale
		local height = (2.4 - tier * 0.2) * scale
		part(model, `Tier{tier}`, Vector3.new(width, height, width), CFrame.new(base + Vector3.new(0, y + height / 2, 0)) * CFrame.Angles(0, math.rad(45 + tier * 15), 0), if tier == 2 then COLORS.firDark else COLORS.fir, false)
		y += height * 0.8
	end
	part(model, "SnowCap", Vector3.new(1.3, 0.8, 1.3) * scale, CFrame.new(base + Vector3.new(0, y + 0.3 * scale, 0)) * CFrame.Angles(0, math.rad(20), 0), COLORS.snow, false)
	model.Parent = parent
	reserve(base, 1.2 * scale)
end

local function rock(parent: Instance, name: string, base: Vector3, size: number)
	local s = Vector3.new(size, size * random:NextNumber(0.5, 0.9), size * random:NextNumber(0.7, 1))
	local turn = CFrame.Angles(math.rad(random:NextNumber(-10, 10)), math.rad(random:NextNumber(0, 90)), math.rad(random:NextNumber(-10, 10)))
	local cf = CFrame.new(base + Vector3.new(0, s.Y * 0.35, 0)) * turn
	part(parent, name, s, cf, if random:NextNumber() < 0.5 then COLORS.rock else COLORS.rockDark)
	if size > 2.5 then
		part(parent, `{name}Snow`, Vector3.new(s.X * 0.8, 0.3, s.Z * 0.8), cf * CFrame.new(0, s.Y / 2, 0), COLORS.snow, false)
	end
end

-- Buisson d'hiver (végétation) : boule verte et petite boule de neige.
local function bush(parent: Instance, name: string, base: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = name
	local b = part(model, "Leaves", Vector3.new(1.8, 1.8, 1.8) * scale, CFrame.new(base + Vector3.new(0, 0.7 * scale, 0)), COLORS.fir, false)
	b.Shape = Enum.PartType.Ball
	local s = part(model, "Snow", Vector3.new(1, 1, 1) * scale, CFrame.new(base + Vector3.new(0.2, 1.5 * scale, 0.1)), COLORS.snow, false)
	s.Shape = Enum.PartType.Ball
	model.Parent = parent
end

local firs, rocks, bushes = 0, 0, 0
-- Bosquets du plateau (zone B), puis sapins dispersés.
for index = 1, 22 do
	local position = decorPosition(6, PLATEAU_REGION)
	if position then
		fir(decor, `PlateauFir{index}`, position, random:NextNumber(1, 1.5))
		table.insert(placed, position)
		firs += 1
	end
end
for index = 1, 26 do
	local position = decorPosition(7)
	if position then
		fir(decor, `Fir{index}`, position, random:NextNumber(0.9, 1.4))
		table.insert(placed, position)
		firs += 1
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
-- Rochers bordant le chemin de la grotte (signalétique sans texte).
for index, segment in ipairs({ { Vector3.new(-16, 0, 5), BRIDGE_POINT }, { BRIDGE_POINT, CAVE_ENTRANCE } }) do
	local a, b = segment[1], segment[2]
	local normal = (b - a).Unit:Cross(Vector3.new(0, 1, 0))
	for _, t in ipairs({ 0.3, 0.75 }) do
		local middle = a:Lerp(b, t)
		if not inFootprint(middle + normal * 5, 0) then
			rock(decor, `TrailRockL{index}_{t * 100}`, middle + normal * 5, random:NextNumber(1.8, 2.8))
			rocks += 1
		end
		if not inFootprint(middle - normal * 5, 0) then
			rock(decor, `TrailRockR{index}_{t * 100}`, middle - normal * 5, random:NextNumber(1.8, 2.8))
			rocks += 1
		end
	end
end
-- Petites zones de végétation hivernale : autour du lac et du plateau.
local LAKE_REGION = { minX = LAKE_CENTER.X - 40, maxX = LAKE_CENTER.X + 40, minZ = LAKE_CENTER.Z - 40, maxZ = LAKE_CENTER.Z + 40 }
for index = 1, 18 do
	local position = decorPosition(3, if index % 2 == 0 then LAKE_REGION else PLATEAU_REGION)
	if position then
		bush(decor, `Bush{index}`, position, random:NextNumber(0.8, 1.2))
		bushes += 1
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

-- Station de vente du camp : comptoir de bois, toit enneigé, pièce dorée
-- (même lecture que les stations des autres mondes : dalle jaune, pièce).
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
stationPart("Counter", Vector3.new(6, 3, 2), Vector3.new(0, 1.9, -3.5), COLORS.wood)
stationPart("PostLeft", Vector3.new(0.8, 7, 0.8), Vector3.new(-2.8, 3.9, -4.2), COLORS.woodDark)
stationPart("PostRight", Vector3.new(0.8, 7, 0.8), Vector3.new(2.8, 3.9, -4.2), COLORS.woodDark)
stationPart("Roof", Vector3.new(7.4, 0.6, 3.6), Vector3.new(0, 7.6, -3.8), COLORS.deepBlue)
stationPart("RoofSnow", Vector3.new(7.6, 0.4, 3.8), Vector3.new(0, 8.1, -3.8), COLORS.snow)
stationPart("RoofTrim", Vector3.new(7.6, 0.5, 0.6), Vector3.new(0, 7.2, -1.9), COLORS.turquoise)
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
	assert(not descendant:IsA("Light") and not descendant:IsA("ParticleEmitter"), `{descendant:GetFullName()} : lumière ou particules dans le décor`)
end
assert(decorParts <= DECOR_BUDGET, `budget de décor dépassé : {decorParts} > {DECOR_BUDGET}`)

local nearestToSell, nearestByType, farthestByType = math.huge, {}, {}
for _, point in ipairs(pointFolder:GetChildren()) do
	local distance = distanceToSell(point.Position - CENTER)
	local resourceType = point:GetAttribute("ResourceType")
	nearestToSell = math.min(nearestToSell, distance)
	nearestByType[resourceType] = math.min(nearestByType[resourceType] or math.huge, distance)
	farthestByType[resourceType] = math.max(farthestByType[resourceType] or 0, distance)
end
local summary = {}
for resourceType, count in pairs(counts) do
	table.insert(summary, string.format("%s x%d (%.0f–%.0f studs)", resourceType, count, nearestByType[resourceType], farthestByType[resourceType]))
end
table.sort(summary)
return string.format(
	"Frozen Peaks : %d points [%s] ; décor %d parts (sapins %d, rochers %d, buissons %d) ; total créé %d parts ; ressource la plus proche de la vente : %.1f studs",
	#pointFolder:GetChildren(),
	table.concat(summary, ", "),
	decorParts,
	firs,
	rocks,
	bushes,
	partCount,
	nearestToSell
)
