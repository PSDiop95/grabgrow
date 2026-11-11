--!nocheck
-- Carte de test minimale de Green Valley (T2) : sol, point d'apparition et
-- points de spawn des ressources. Provisoire : remplacée par la vraie carte.
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
for resourceType, definition in pairs(ResourceConfig) do
	if definition.worldId == WORLD_ID then
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

return `Carte de test {WORLD_ID} : {table.concat(summary, ", ")}`
