--!nocheck
-- Carte de test minimale de Green Valley (T2) : sol, point d'apparition et
-- points de spawn des ressources. OBSOLÈTE depuis T8.2 : remplacée par
-- build_green_valley.luau (le relancer écraserait la carte de T8.2).
-- Conservée comme référence des tests T2 à T7.
--
-- Outil de développement, absent du jeu (non mappé dans
-- default.project.json). À exécuter dans Roblox Studio en mode Edit : coller
-- dans la barre de commande, ou lancer par le serveur MCP Roblox Studio.
-- Rejouable : remplace ce qu'il a créé, ne touche à rien d'autre.
-- Résultat identique à chaque exécution (graine fixe).
--
-- Crée :
--   Workspace.Map.GreenValley.Ground
--   Workspace.SpawnLocations.GreenValleySpawn
--   Workspace.ResourceSpawnPoints.GreenValley.<Spawn_type_nn>
--   Workspace.SellZones.GreenValley (T3) : station de vente provisoire,
--     zone `SellZonePad` avec l'attribut `SellZoneId`, lue par
--     Systems/SellZones (serveur) et SellController (client)
-- Chaque point de spawn porte l'attribut `ResourceType`, lu par
-- Systems/ResourceNodes. Le nombre de points par ressource suit
-- ResourceConfig.spawnWeight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)

local SEED = 20261111
local WORLD_ID = "GreenValley"
local TOTAL_SPAWN_POINTS = 36
local GROUND_SIZE = 240
local MIN_SPACING_STUDS = 6
-- Anneau de dispersion autour du point d'apparition, par ressource (studs).
-- Les ressources de plus grande valeur sont plus loin.
local RINGS = {
	green_leaf = { min = 12, max = 45 },
	wood = { min = 25, max = 65 },
	stone = { min = 45, max = 90 },
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

-- Sol
local map = getFolder(Workspace, "Map")
replace(map, WORLD_ID)
local world = Instance.new("Folder")
world.Name = WORLD_ID
local ground = Instance.new("Part")
ground.Name = "Ground"
ground.Size = Vector3.new(GROUND_SIZE, 2, GROUND_SIZE)
ground.Position = Vector3.new(0, -1, 0)
ground.Anchored = true
ground.Material = Enum.Material.SmoothPlastic
ground.Color = Color3.fromRGB(116, 178, 92)
ground.TopSurface = Enum.SurfaceType.Smooth
ground.Parent = world
world.Parent = map

-- Point d'apparition
local spawnLocations = getFolder(Workspace, "SpawnLocations")
replace(spawnLocations, "GreenValleySpawn")
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "GreenValleySpawn"
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.Position = Vector3.new(0, 0.5, 0)
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Material = Enum.Material.SmoothPlastic
spawnLocation.Color = Color3.fromRGB(240, 226, 180)
spawnLocation.TopSurface = Enum.SurfaceType.Smooth
spawnLocation.Parent = spawnLocations

-- Points de spawn des ressources
local resourceTypes = {}
local totalWeight = 0
-- T8 (D-021) : seules les ressources dotées d'un anneau (carte MVP à
-- 36 points) sont placées ; Fruit sauvage et Cristal vert le seront par la
-- carte de Green Valley (T8.2). Carte produite inchangée.
for resourceType, definition in pairs(ResourceConfig) do
	if definition.worldId == WORLD_ID and RINGS[resourceType] ~= nil then
		table.insert(resourceTypes, resourceType)
		totalWeight += definition.spawnWeight
	end
end
table.sort(resourceTypes)

local random = Random.new(SEED)
local placed: { Vector3 } = {}
local spawnPoints = getFolder(Workspace, "ResourceSpawnPoints")
replace(spawnPoints, WORLD_ID)
local pointFolder = Instance.new("Folder")
pointFolder.Name = WORLD_ID

local summary = {}
for _, resourceType in ipairs(resourceTypes) do
	local ring = RINGS[resourceType]
	assert(ring, `anneau non défini pour {resourceType}`)
	local count = math.floor(TOTAL_SPAWN_POINTS * ResourceConfig[resourceType].spawnWeight / totalWeight + 0.5)
	for index = 1, count do
		local position: Vector3
		for _ = 1, 200 do
			local angle = random:NextNumber(0, 2 * math.pi)
			local radius = random:NextNumber(ring.min, ring.max)
			position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local free = true
			for _, other in ipairs(placed) do
				if (other - position).Magnitude < MIN_SPACING_STUDS then
					free = false
					break
				end
			end
			if free then
				break
			end
		end
		table.insert(placed, position)

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
	end
	table.insert(summary, `{resourceType} x{count}`)
end
pointFolder.Parent = spawnPoints

-- Station de vente (T3). Primitives provisoires, sans texte ni logo :
-- l'étiquette « Sell / Vente » est affichée par le client (localisée).
-- Emplacement choisi hors des points de spawn (point le plus proche :
-- Spawn_green_leaf_03, environ 15 studs).
local SELL_ZONE_ID = "GreenValley_Main"
local SELL_POSITION = Vector3.new(-12, 0, -16)
local sellZones = getFolder(Workspace, "SellZones")
replace(sellZones, WORLD_ID)
local station = Instance.new("Model")
station.Name = WORLD_ID

local function stationPart(name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Position = SELL_POSITION + offset
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanQuery = false
	part.Parent = station
	return part
end

local pad = stationPart("SellZonePad", Vector3.new(10, 0.4, 10), Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 214, 92))
pad:SetAttribute("SellZoneId", SELL_ZONE_ID)
local wood = Color3.fromRGB(150, 98, 56)
stationPart("Counter", Vector3.new(6, 3, 2), Vector3.new(0, 1.9, -3.5), wood)
stationPart("PostLeft", Vector3.new(0.8, 7, 0.8), Vector3.new(-2.8, 3.9, -4.2), wood)
stationPart("PostRight", Vector3.new(0.8, 7, 0.8), Vector3.new(2.8, 3.9, -4.2), wood)
stationPart("Roof", Vector3.new(7.4, 0.8, 3.6), Vector3.new(0, 7.6, -3.8), Color3.fromRGB(230, 80, 70))
local coin = stationPart("Coin", Vector3.new(0.6, 2.6, 2.6), Vector3.new(0, 4.6, -3.5), Color3.fromRGB(255, 196, 40), Enum.PartType.Cylinder)
coin.Orientation = Vector3.new(0, 90, 0)
coin.Material = Enum.Material.Neon
station.PrimaryPart = pad
station.Parent = sellZones

local nearest = math.huge
for _, point in ipairs(placed) do
	nearest = math.min(nearest, (point - SELL_POSITION).Magnitude)
end
table.insert(summary, `vente {SELL_ZONE_ID} (point de spawn le plus proche : {string.format("%.1f", nearest)} studs)`)

return `Carte de test {WORLD_ID} : {table.concat(summary, ", ")}`
