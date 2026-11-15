--!nocheck
-- Carte de Green Valley (T8.2, D-021) en primitives scriptées : île, hub
-- central, portails, zone de base, zone avancée (3 Fruits sauvages,
-- 1 Cristal vert), point d'arrivée, station de vente et décor low-poly.
-- Remplace la carte de test T2 (build_test_map.luau).
--
-- Outil de développement, absent du jeu (non mappé dans
-- default.project.json). À exécuter dans Roblox Studio en mode Edit (barre
-- de commande ou serveur MCP). Rejouable : remplace ce qu'il a créé, ne
-- touche à rien d'autre. Résultat identique à chaque exécution (graine
-- fixe). Aucun asset externe, aucun texte ni logo dans le décor (étiquettes
-- localisées par le client).
--
-- Crée (lus par le jeu) :
--   Workspace.Map.GreenValley                     île, hub, portails, décor
--     Portals.<Monde>.Field                       attribut `PortalWorldId`
--   Workspace.SpawnLocations.GreenValleySpawn     apparition (hub, D5)
--   Workspace.WorldArrivals.GreenValley           attribut `ArrivalWorldId`
--   Workspace.ResourceSpawnPoints.GreenValley     40 points, `ResourceType`
--   Workspace.SellZones.GreenValley               `SellZonePad`, `SellZoneId`
--
-- Budget (audit T8, étape A) : ~1 200 parts de décor par île au plus,
-- ~40 nœuds, aucune lumière dynamique, CastShadow désactivé, collisions
-- simples (feuillages, fleurs et champs de portail sans collision).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)

local SEED = 20261114
local WORLD_ID = "GreenValley"
local DECOR_BUDGET = 1200

-- Nombre de points par ressource : 40 nœuds répartis selon spawnWeight
-- (plus forts restes), comme le simulateur de progression : 16/12/8/3/1.
local TOTAL_SPAWN_POINTS = 40
local MIN_SPACING_STUDS = 6

-- Hub (centre de l'île).
local HUB_RADIUS = 24
local SPAWN_POSITION = Vector3.new(0, 0.5, 0)
local ARRIVAL_POSITION = Vector3.new(0, 0.3, 12)
local SELL_ZONE_ID = "GreenValley_Main" -- inchangé depuis T3
local SELL_POSITION = Vector3.new(-12, 0, -16) -- inchangé depuis T3
local PORTAL_Z = 32
local PORTALS = {
	{ worldId = "GoldenDesert", x = -16, color = Color3.fromRGB(236, 190, 84) },
	{ worldId = "FrozenPeaks", x = 0, color = Color3.fromRGB(150, 210, 245) },
	{ worldId = "MysticWorld", x = 16, color = Color3.fromRGB(170, 116, 230) },
}

-- Zone de base : anneaux autour du hub (studs). Valeur croissante avec la
-- distance.
local BASE_RINGS = {
	green_leaf = { min = 30, max = 62 },
	wood = { min = 45, max = 85 },
	stone = { min = 65, max = 105 },
}

-- Zone avancée : clairière clôturée à l'ouest, au bout d'un chemin.
local ADVANCED_CENTER = Vector3.new(-140, 0, 0)
local ADVANCED_RADIUS = 26
-- Fruits sauvages près de trois arbres fruitiers ; Cristal vert au centre.
local FRUIT_ANGLES = { 60, 180, 300 } -- degrés, autour du centre
local FRUIT_TREE_RADIUS = 14
local CRYSTAL_OFFSET = Vector3.new(0, 0, 0)

local COLORS = {
	grass = Color3.fromRGB(116, 178, 92),
	grassDark = Color3.fromRGB(96, 156, 78),
	cliff = Color3.fromRGB(122, 98, 72),
	water = Color3.fromRGB(78, 160, 214),
	plaza = Color3.fromRGB(226, 214, 180),
	path = Color3.fromRGB(196, 164, 112),
	trunk = Color3.fromRGB(128, 86, 52),
	stoneGray = Color3.fromRGB(150, 150, 146),
	fence = Color3.fromRGB(170, 118, 70),
	arrival = Color3.fromRGB(120, 200, 255),
	pillar = Color3.fromRGB(205, 196, 178),
}
local FOLIAGE = {
	Color3.fromRGB(82, 160, 72),
	Color3.fromRGB(64, 140, 64),
	Color3.fromRGB(104, 176, 76),
}
local FLOWERS = {
	Color3.fromRGB(250, 236, 110),
	Color3.fromRGB(245, 140, 160),
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(180, 150, 240),
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

local random = Random.new(SEED)
local partCount = 0

-- Part ancrée, sans ombre. `solid = false` : traversable, ignorée par les
-- requêtes (feuillages, fleurs, champs).
local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
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

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Disque plat (cylindre vertical).
local function disk(parent: Instance, name: string, diameter: number, thickness: number, center: Vector3, color: Color3): Part
	local p = part(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function horizontal(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
end

-- CARTE ----------------------------------------------------------------------

local map = getFolder(Workspace, "Map")
replace(map, WORLD_ID)
local world = Instance.new("Folder")
world.Name = WORLD_ID

-- Île : trois dalles croisées (silhouette aux angles coupés), falaise
-- sombre dessous, eau autour (sans collision : une chute fait réapparaître
-- au hub).
local island = Instance.new("Folder")
island.Name = "Island"
island.Parent = world
for index, size in ipairs({ Vector3.new(300, 4, 300), Vector3.new(340, 4, 220), Vector3.new(220, 4, 340) }) do
	part(island, `Ground{index}`, size, at(0, -2, 0), COLORS.grass)
	part(island, `Cliff{index}`, size + Vector3.new(4, 6, 4), at(0, -6.9, 0), COLORS.cliff)
end
part(island, "Water", Vector3.new(1400, 1, 1400), at(0, -8, 0), COLORS.water, false).Transparency = 0.15

-- Hub : place centrale, apparition, arrivée, chemin vers la zone avancée.
local hub = Instance.new("Folder")
hub.Name = "Hub"
hub.Parent = world
disk(hub, "Plaza", HUB_RADIUS * 2, 0.2, Vector3.new(0, 0.1, 0), COLORS.plaza)
for index = 0, 7 do
	local x = -HUB_RADIUS - 4 - index * 12
	part(hub, `Path{index + 1}`, Vector3.new(10, 0.16, 6), at(x, 0.08, 0), COLORS.path)
end

-- Portails : arche, marche et champ traversable (attribut PortalWorldId,
-- lu par TravelController). Monde verrouillé ou sans île : le client
-- l'indique et le serveur refuse le voyage.
local portals = Instance.new("Folder")
portals.Name = "Portals"
portals.Parent = world
for _, info in ipairs(PORTALS) do
	local model = Instance.new("Model")
	model.Name = info.worldId
	local x = info.x
	part(model, "Step", Vector3.new(10, 0.6, 4), at(x, 0.3, PORTAL_Z), COLORS.pillar)
	part(model, "PillarLeft", Vector3.new(1.6, 10, 1.6), at(x - 4.2, 5.6, PORTAL_Z), COLORS.pillar)
	part(model, "PillarRight", Vector3.new(1.6, 10, 1.6), at(x + 4.2, 5.6, PORTAL_Z), COLORS.pillar)
	part(model, "Lintel", Vector3.new(10, 1.6, 2), at(x, 11.4, PORTAL_Z), info.color)
	local field = part(model, "Field", Vector3.new(6.8, 9.6, 0.4), at(x, 5.4, PORTAL_Z), info.color, false)
	field.Transparency = 0.35
	-- Le prompt local (TravelController) a besoin d'une part interrogeable.
	field.CanQuery = true
	field:SetAttribute("PortalWorldId", info.worldId)
	model.PrimaryPart = field
	model.Parent = portals
end

-- Zone avancée : clairière, clôture ouverte vers le hub.
local advanced = Instance.new("Folder")
advanced.Name = "AdvancedZone"
advanced.Parent = world
disk(advanced, "Clearing", ADVANCED_RADIUS * 2 + 4, 0.16, ADVANCED_CENTER + Vector3.new(0, 0.08, 0), COLORS.grassDark)
local postPositions = {}
for angle = 0, 330, 30 do
	-- Ouverture à l'est (angle 0 : direction du hub).
	if angle ~= 0 then
		local radians = math.rad(angle)
		local position = ADVANCED_CENTER + Vector3.new(math.cos(radians), 0, math.sin(radians)) * (ADVANCED_RADIUS + 2)
		table.insert(postPositions, position)
		part(advanced, `Post{#postPositions}`, Vector3.new(0.8, 3, 0.8), CFrame.new(position + Vector3.new(0, 1.5, 0)), COLORS.fence)
	end
end
for index = 1, #postPositions - 1 do
	local a, b = postPositions[index], postPositions[index + 1]
	local middle = (a + b) / 2 + Vector3.new(0, 2, 0)
	local length = (b - a).Magnitude
	part(advanced, `Rail{index}`, Vector3.new(0.4, 0.4, length), CFrame.lookAt(middle, b + Vector3.new(0, 2, 0)), COLORS.fence)
end

-- Arbre low-poly : tronc solide, deux blocs de feuillage traversables.
local function tree(parent: Instance, name: string, base: Vector3, scale: number, foliage: Color3)
	local model = Instance.new("Model")
	model.Name = name
	local height = 6 * scale
	part(model, "Trunk", Vector3.new(1.6, height, 1.6) * Vector3.new(scale, 1, scale), CFrame.new(base + Vector3.new(0, height / 2, 0)), COLORS.trunk)
	local turn = math.rad(random:NextNumber(0, 90))
	part(model, "Leaves", Vector3.new(6, 4, 6) * scale, CFrame.new(base + Vector3.new(0, height + 1, 0)) * CFrame.Angles(0, turn, 0), foliage, false)
	part(model, "Top", Vector3.new(3.6, 2.6, 3.6) * scale, CFrame.new(base + Vector3.new(0, height + 3.6 * scale, 0)) * CFrame.Angles(0, turn + math.rad(45), 0), foliage, false)
	model.Parent = parent
end

local function rock(parent: Instance, name: string, base: Vector3, size: number)
	local s = Vector3.new(size, size * random:NextNumber(0.5, 0.8), size * random:NextNumber(0.7, 1))
	local turn = CFrame.Angles(math.rad(random:NextNumber(-10, 10)), math.rad(random:NextNumber(0, 90)), math.rad(random:NextNumber(-10, 10)))
	part(parent, name, s, CFrame.new(base + Vector3.new(0, s.Y * 0.35, 0)) * turn, COLORS.stoneGray)
end

-- Arbres fruitiers et rochers de la zone avancée (positions fixes).
local fruitPoints = {}
for index, angle in ipairs(FRUIT_ANGLES) do
	local radians = math.rad(angle)
	local direction = Vector3.new(math.cos(radians), 0, math.sin(radians))
	local treeBase = ADVANCED_CENTER + direction * FRUIT_TREE_RADIUS
	tree(advanced, `FruitTree{index}`, treeBase, 1.2, FOLIAGE[1])
	-- Point de spawn du fruit : 3,5 studs devant l'arbre, côté centre.
	table.insert(fruitPoints, treeBase - direction * 3.5)
end
local crystalPoint = ADVANCED_CENTER + CRYSTAL_OFFSET
for index = 0, 3 do
	local radians = math.rad(45 + index * 90)
	rock(advanced, `CrystalRock{index + 1}`, crystalPoint + Vector3.new(math.cos(radians), 0, math.sin(radians)) * 4.5, 2.2)
end

-- POINTS DE SPAWN ------------------------------------------------------------

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
	-- Plus forts restes : total exact, ordre stable.
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
assert(counts.wild_fruit == #FRUIT_ANGLES, `Fruit sauvage : {counts.wild_fruit} point(s) attendu(s) {#FRUIT_ANGLES}`)
assert(counts.green_crystal == 1, `Cristal vert : {counts.green_crystal} point(s), 1 attendu`)

local placed: { Vector3 } = {}

-- Zones interdites aux ressources de base : portails, station de vente.
local function blockedForBase(position: Vector3): boolean
	if position.Z > PORTAL_Z - 8 and position.Z < PORTAL_Z + 8 and math.abs(position.X) < 26 then
		return true
	end
	if (horizontal(position) - horizontal(SELL_POSITION)).Magnitude < 10 then
		return true
	end
	return (horizontal(position) - horizontal(ADVANCED_CENTER)).Magnitude < ADVANCED_RADIUS + 8
end

local function isFree(position: Vector3, spacing: number): boolean
	for _, other in ipairs(placed) do
		if (other - position).Magnitude < spacing then
			return false
		end
	end
	return true
end

local spawnPoints = getFolder(Workspace, "ResourceSpawnPoints")
replace(spawnPoints, WORLD_ID)
local pointFolder = Instance.new("Folder")
pointFolder.Name = WORLD_ID

local function spawnPoint(resourceType: string, index: number, position: Vector3)
	local point = Instance.new("Part")
	point.Name = string.format("Spawn_%s_%02d", resourceType, index)
	point.Size = Vector3.new(1, 0.2, 1)
	point.Position = position
	point.Anchored = true
	point.Transparency = 1
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point:SetAttribute("ResourceType", resourceType)
	point.Parent = pointFolder
	table.insert(placed, position)
end

for _, resourceType in ipairs({ "green_leaf", "wood", "stone" }) do
	local ring = BASE_RINGS[resourceType]
	for index = 1, counts[resourceType] do
		local position = nil
		for _ = 1, 400 do
			local angle = random:NextNumber(0, 2 * math.pi)
			local radius = random:NextNumber(ring.min, ring.max)
			local candidate = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			if not blockedForBase(candidate) and isFree(candidate, MIN_SPACING_STUDS) then
				position = candidate
				break
			end
		end
		assert(position, `aucune place libre pour {resourceType} {index}`)
		spawnPoint(resourceType, index, position)
	end
end
for index, position in ipairs(fruitPoints) do
	spawnPoint("wild_fruit", index, position)
end
spawnPoint("green_crystal", 1, crystalPoint)
pointFolder.Parent = spawnPoints

-- DÉCOR (graine fixe, à l'écart des ressources et des zones de passage) -----

local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = world

local function decorFree(position: Vector3, clearance: number): boolean
	local flat = horizontal(position)
	if flat.Magnitude < HUB_RADIUS + 6 then
		return false
	end
	if position.Z > PORTAL_Z - 10 and position.Z < PORTAL_Z + 12 and math.abs(position.X) < 30 then
		return false
	end
	-- Chemin vers la zone avancée.
	if math.abs(position.Z) < 7 and position.X < -HUB_RADIUS and position.X > ADVANCED_CENTER.X then
		return false
	end
	if (flat - horizontal(ADVANCED_CENTER)).Magnitude < ADVANCED_RADIUS + 5 then
		return false
	end
	for _, point in ipairs(placed) do
		if (horizontal(point) - flat).Magnitude < clearance then
			return false
		end
	end
	return true
end

-- Position au hasard sur l'île (marge au bord), libre ; nil si introuvable.
local function decorPosition(minRadius: number, maxRadius: number, clearance: number): Vector3?
	for _ = 1, 200 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local radius = random:NextNumber(minRadius, maxRadius)
		local candidate = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		-- Sur l'une des trois dalles de l'île, à 6 studs du bord au moins.
		local ax, az = math.abs(candidate.X), math.abs(candidate.Z)
		local inside = (ax < 144 and az < 144) or (ax < 164 and az < 104) or (ax < 104 and az < 164)
		if inside and decorFree(candidate, clearance) then
			return candidate
		end
	end
	return nil
end

local decorPlaced: { Vector3 } = {}
local function remember(position: Vector3)
	table.insert(placed, position)
	table.insert(decorPlaced, position)
end

local summary = {}
local trees, rocks, bushes, flowers = 0, 0, 0, 0
for index = 1, 46 do
	local position = decorPosition(36, 160, 7)
	if position then
		tree(decor, `Tree{index}`, position, random:NextNumber(0.85, 1.3), FOLIAGE[random:NextInteger(1, #FOLIAGE)])
		remember(position)
		trees += 1
	end
end
for index = 1, 28 do
	local position = decorPosition(34, 165, 5)
	if position then
		rock(decor, `Rock{index}`, position, random:NextNumber(1.6, 4.5))
		remember(position)
		rocks += 1
	end
end
for index = 1, 32 do
	local position = decorPosition(30, 160, 4)
	if position then
		local size = random:NextNumber(2.2, 3.6)
		part(decor, `Bush{index}`, Vector3.new(size, size * 0.65, size), CFrame.new(position + Vector3.new(0, size * 0.3, 0)) * CFrame.Angles(0, math.rad(random:NextNumber(0, 90)), 0), FOLIAGE[random:NextInteger(1, #FOLIAGE)], false)
		remember(position)
		bushes += 1
	end
end
for index = 1, 48 do
	local position = decorPosition(28, 160, 2)
	if position then
		part(decor, `Flower{index}`, Vector3.new(0.7, 0.5, 0.7), CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, math.rad(45), 0), FLOWERS[random:NextInteger(1, #FLOWERS)], false)
		table.insert(decorPlaced, position)
		flowers += 1
	end
end
world.Parent = map

-- APPARITION, ARRIVÉE, VENTE ------------------------------------------------

local spawnLocations = getFolder(Workspace, "SpawnLocations")
replace(spawnLocations, "GreenValleySpawn")
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "GreenValleySpawn"
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.Position = SPAWN_POSITION
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Material = Enum.Material.SmoothPlastic
spawnLocation.Color = Color3.fromRGB(240, 226, 180)
spawnLocation.TopSurface = Enum.SurfaceType.Smooth
spawnLocation.CastShadow = false
spawnLocation.Parent = spawnLocations
partCount += 1

-- Point d'arrivée (Systems/WorldArrivals) : ce n'est pas une SpawnLocation.
local arrivals = getFolder(Workspace, "WorldArrivals")
replace(arrivals, WORLD_ID)
local arrival = Instance.new("Part")
arrival.Name = WORLD_ID
arrival.Size = Vector3.new(6, 0.2, 6)
arrival.Position = ARRIVAL_POSITION
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

-- Station de vente (T3), même identifiant et même emplacement.
local sellZones = getFolder(Workspace, "SellZones")
replace(sellZones, WORLD_ID)
local station = Instance.new("Model")
station.Name = WORLD_ID
local function stationPart(name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = part(station, name, size, CFrame.new(SELL_POSITION + offset), color)
	p.Shape = shape or Enum.PartType.Block
	p.CanQuery = false
	return p
end
local pad = stationPart("SellZonePad", Vector3.new(10, 0.4, 10), Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 214, 92))
pad:SetAttribute("SellZoneId", SELL_ZONE_ID)
local woodColor = Color3.fromRGB(150, 98, 56)
stationPart("Counter", Vector3.new(6, 3, 2), Vector3.new(0, 1.9, -3.5), woodColor)
stationPart("PostLeft", Vector3.new(0.8, 7, 0.8), Vector3.new(-2.8, 3.9, -4.2), woodColor)
stationPart("PostRight", Vector3.new(0.8, 7, 0.8), Vector3.new(2.8, 3.9, -4.2), woodColor)
stationPart("Roof", Vector3.new(7.4, 0.8, 3.6), Vector3.new(0, 7.6, -3.8), Color3.fromRGB(230, 80, 70))
local coin = stationPart("Coin", Vector3.new(0.6, 2.6, 2.6), Vector3.new(0, 4.6, -3.5), Color3.fromRGB(255, 196, 40), Enum.PartType.Cylinder)
coin.CFrame = CFrame.new(SELL_POSITION + Vector3.new(0, 4.6, -3.5)) * CFrame.Angles(0, math.rad(90), 0)
coin.Material = Enum.Material.Neon
station.PrimaryPart = pad
station.Parent = sellZones

-- RÉSUMÉ ---------------------------------------------------------------------

local decorParts = 0
for _, descendant in ipairs(world:GetDescendants()) do
	if descendant:IsA("BasePart") then
		decorParts += 1
	end
end
assert(decorParts <= DECOR_BUDGET, `budget de décor dépassé : {decorParts} > {DECOR_BUDGET}`)

local nearestToSell = math.huge
for _, point in ipairs(pointFolder:GetChildren()) do
	nearestToSell = math.min(nearestToSell, (horizontal(point.Position) - horizontal(SELL_POSITION)).Magnitude)
end
for resourceType, count in pairs(counts) do
	table.insert(summary, `{resourceType} x{count}`)
end
table.sort(summary)
return string.format(
	"Green Valley : %d points (%s) ; décor %d parts (arbres %d, rochers %d, buissons %d, fleurs %d) ; total créé %d parts ; ressource la plus proche de la vente : %.1f studs",
	#pointFolder:GetChildren(),
	table.concat(summary, ", "),
	decorParts,
	trees,
	rocks,
	bushes,
	flowers,
	partCount,
	nearestToSell
)
