--!strict
-- Ressources dans le monde : lit les points de spawn, crée un modèle
-- provisoire par point et reflète l'état décidé par ResourceSpawner.
-- Aucune règle de collecte ici.
--
-- Points de spawn : BaseParts dans Workspace.ResourceSpawnPoints, avec
-- l'attribut `ResourceType` (clé de ResourceConfig). Édités dans Studio ;
-- carte de test : tools/studio/build_test_map.luau.
--
-- Nœuds créés dans Workspace.ResourceNodes, un Part chacun, avec les
-- attributs lus par le client :
--   NodeId (texte), ResourceType (texte), Available (booléen).
-- Les identifiants sont attribués ici, par type, dans l'ordre des noms des
-- points de spawn : "green_leaf_001", "wood_001"...
--
-- Modèles : formes simples provisoires, à remplacer par des assets
-- contrôlés (ASSET_MANIFEST) sans toucher à la logique.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage.Shared.Config
local GameConfig = require(Config.GameConfig)
local ResourceConfig = require(Config.ResourceConfig)
local ResourceSpawner = require(script.Parent.ResourceSpawner)

local ResourceNodes = {}

ResourceNodes.SPAWN_FOLDER_NAME = "ResourceSpawnPoints"
ResourceNodes.NODE_FOLDER_NAME = "ResourceNodes"

type Spawner = typeof(ResourceSpawner.new({} :: any))

type Visual = {
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	-- Orientation en degrés, appliquée après celle du point de spawn.
	orientation: Vector3,
}

-- Silhouettes et couleurs distinctes (GDD : formes lisibles).
local VISUALS: { [string]: Visual } = {
	green_leaf = {
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.8, 1.8, 1.8),
		color = Color3.fromRGB(96, 204, 78),
		orientation = Vector3.zero,
	},
	wood = {
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(2.6, 1.4, 1.4),
		color = Color3.fromRGB(150, 98, 56),
		orientation = Vector3.new(0, 35, 0),
	},
	stone = {
		shape = Enum.PartType.Block,
		size = Vector3.new(2, 1.6, 2),
		color = Color3.fromRGB(138, 142, 150),
		orientation = Vector3.new(0, 20, 8),
	},
}

local parts: { [string]: BasePart } = {}
local started = false

local function createPart(nodeId: string, resourceType: string, origin: CFrame): BasePart
	local visual = VISUALS[resourceType]
	local part = Instance.new("Part")
	part.Name = nodeId
	part.Shape = visual.shape
	part.Size = visual.size
	part.Color = visual.color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	-- Traversable ; CanQuery reste actif pour le toucher / clic du client.
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	local rotation = CFrame.Angles(math.rad(visual.orientation.X), math.rad(visual.orientation.Y), math.rad(visual.orientation.Z))
	part.CFrame = origin * CFrame.new(0, visual.size.Y / 2, 0) * rotation
	part:SetAttribute("NodeId", nodeId)
	part:SetAttribute("ResourceType", resourceType)
	part:SetAttribute("Available", true)
	return part
end

-- À passer à ResourceSpawner comme `onStateChanged`.
function ResourceNodes.applyState(nodeId: string, state: string)
	local part: BasePart? = parts[nodeId]
	if part == nil then
		return
	end
	local available = state == ResourceSpawner.State.Active
	part.Transparency = if available then 0 else 1
	part.CanQuery = available
	part:SetAttribute("Available", available)
end

-- Crée les nœuds à partir des points de spawn et les enregistre.
-- Retourne le nombre de nœuds créés.
function ResourceNodes.start(spawner: Spawner): number
	assert(not started, "ResourceNodes.start appelé deux fois")
	started = true

	local nodeFolder = Instance.new("Folder")
	nodeFolder.Name = ResourceNodes.NODE_FOLDER_NAME

	local spawnFolder = Workspace:FindFirstChild(ResourceNodes.SPAWN_FOLDER_NAME)
	if spawnFolder == nil then
		warn(`[ResourceNodes] Workspace.{ResourceNodes.SPAWN_FOLDER_NAME} absent : aucune ressource créée`)
		nodeFolder.Parent = Workspace
		return 0
	end

	local spawnPoints: { BasePart } = {}
	for _, child in ipairs(spawnFolder:GetDescendants()) do
		if child:IsA("BasePart") then
			table.insert(spawnPoints, child)
		end
	end
	-- Ordre stable : les identifiants ne dépendent pas de l'ordre de chargement.
	table.sort(spawnPoints, function(a: BasePart, b: BasePart): boolean
		if a.Name ~= b.Name then
			return a.Name < b.Name
		end
		local pa, pb = a.Position, b.Position
		if pa.X ~= pb.X then
			return pa.X < pb.X
		end
		return pa.Z < pb.Z
	end)

	local countByType: { [string]: number } = {}
	local created = 0
	for _, spawnPoint in ipairs(spawnPoints) do
		local resourceType = spawnPoint:GetAttribute("ResourceType")
		local definition = if type(resourceType) == "string" then ResourceConfig[resourceType] else nil
		if type(resourceType) ~= "string" or definition == nil or VISUALS[resourceType] == nil then
			warn(`[ResourceNodes] {spawnPoint:GetFullName()} : ResourceType invalide ({tostring(resourceType)}), ignoré`)
			continue
		end
		if definition.worldId ~= GameConfig.StartingWorldId then
			warn(`[ResourceNodes] {spawnPoint:GetFullName()} : monde {definition.worldId} hors MVP, ignoré`)
			continue
		end

		local index = (countByType[resourceType] or 0) + 1
		countByType[resourceType] = index
		local nodeId = string.format("%s_%03d", resourceType, index)
		local part = createPart(nodeId, resourceType, spawnPoint.CFrame)
		local position = part.Position
		local ok, reason = spawner.Register(nodeId, resourceType, { X = position.X, Y = position.Y, Z = position.Z })
		if not ok then
			warn(`[ResourceNodes] {nodeId} non enregistré : {tostring(reason)}`)
			part:Destroy()
			continue
		end
		parts[nodeId] = part
		part.Parent = nodeFolder
		created += 1
	end

	nodeFolder.Parent = Workspace
	return created
end

return ResourceNodes
