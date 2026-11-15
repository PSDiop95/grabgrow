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
--   NodeId (texte), ResourceType (texte), WorldId (texte, T8),
--   Available (booléen).
-- Les identifiants sont attribués ici, par type, dans l'ordre des noms des
-- points de spawn : "green_leaf_001", "wood_001"...
--
-- T8 (D-021) : tous les mondes de WorldConfig sont acceptés ; le monde
-- d'un nœud est celui de sa ressource (ResourceConfig.worldId), jamais le
-- dossier du point de spawn. Créer un nœud ne le rend pas collectable par
-- tous : CollectionService exige que le joueur ait débloqué ce monde.
--
-- Modèles : formes simples provisoires (Shared/Config/ResourceVisualConfig,
-- avec un ParticleEmitter facultatif pour l'Épique, T8.3, et des pièces de
-- détail facultatives, T8.4 : enfants du Part du nœud, sans collision ni
-- requête, masquées avec lui),
-- à remplacer par des assets contrôlés (ASSET_MANIFEST) sans toucher à la
-- logique.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage.Shared.Config
local ResourceConfig = require(Config.ResourceConfig)
local ResourceVisualConfig = require(Config.ResourceVisualConfig)
local WorldConfig = require(Config.WorldConfig)
local ResourceSpawner = require(script.Parent.ResourceSpawner)

local ResourceNodes = {}

ResourceNodes.SPAWN_FOLDER_NAME = "ResourceSpawnPoints"
ResourceNodes.NODE_FOLDER_NAME = "ResourceNodes"

type Spawner = typeof(ResourceSpawner.new({} :: any))

local parts: { [string]: BasePart } = {}
local started = false

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

-- Conversion des données de ResourceVisualConfig ; nil si un nom d'Enum
-- est inconnu (le point de spawn est alors ignoré avec un avertissement).
local function readVisual(resourceType: string): (Enum.PartType?, Enum.Material?)
	local visual = ResourceVisualConfig[resourceType]
	if visual == nil then
		return nil, nil
	end
	local okShape, shape = pcall(function(): Enum.PartType
		return (Enum.PartType :: any)[visual.shape]
	end)
	local okMaterial, material = pcall(function(): Enum.Material
		return (Enum.Material :: any)[visual.material]
	end)
	-- T8.4 : une pièce de détail invalide écarte tout le nœud (avertissement).
	for _, detail in ipairs(visual.details or {}) do
		local okDetail = pcall(function()
			local _ = (Enum.PartType :: any)[detail.shape]
			local _ = (Enum.Material :: any)[detail.material]
		end)
		if not okDetail then
			return nil, nil
		end
	end
	return if okShape then shape else nil, if okMaterial then material else nil
end

local function createPart(
	nodeId: string,
	resourceType: string,
	worldId: string,
	origin: CFrame,
	shape: Enum.PartType,
	material: Enum.Material
): BasePart
	local visual = ResourceVisualConfig[resourceType]
	local size = vector(visual.size)
	local orientation = vector(visual.orientation)
	local part = Instance.new("Part")
	part.Name = nodeId
	part.Shape = shape
	part.Size = size
	part.Color = Color3.fromRGB(visual.color[1], visual.color[2], visual.color[3])
	part.Material = material
	part.Anchored = true
	-- Traversable ; CanQuery reste actif pour le toucher / clic du client.
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	local rotation = CFrame.Angles(math.rad(orientation.X), math.rad(orientation.Y), math.rad(orientation.Z))
	part.CFrame = origin * CFrame.new(0, size.Y / 2, 0) * rotation
	part:SetAttribute("NodeId", nodeId)
	part:SetAttribute("ResourceType", resourceType)
	part:SetAttribute("WorldId", worldId)
	part:SetAttribute("Available", true)
	-- T8.4 : pièces de détail (le Part du nœud reste la seule cible du
	-- client et la seule porteuse des attributs).
	local center = origin * CFrame.new(0, size.Y / 2, 0)
	for index, detail in ipairs(visual.details or {}) do
		local detailShape = (Enum.PartType :: any)[detail.shape]
		local detailMaterial = (Enum.Material :: any)[detail.material]
		local d = Instance.new("Part")
		d.Name = `Detail{index}`
		d.Shape = detailShape
		d.Size = vector(detail.size)
		d.Color = Color3.fromRGB(detail.color[1], detail.color[2], detail.color[3])
		d.Material = detailMaterial
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		local turn = vector(detail.orientation)
		d.CFrame = center
			* CFrame.new(vector(detail.offset))
			* CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))
		d.Parent = part
	end
	-- T8.3 : petit émetteur facultatif (Épique seulement, ConfigTests),
	-- sans lumière dynamique.
	local particles = visual.particles
	if particles ~= nil then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Sparkle"
		emitter.Color = ColorSequence.new(Color3.fromRGB(particles.color[1], particles.color[2], particles.color[3]))
		emitter.Rate = particles.rate
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(1, 2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.25, 0)
		emitter.LightEmission = 0.6
		emitter.Parent = part
	end
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
	local emitter = part:FindFirstChildOfClass("ParticleEmitter")
	if emitter ~= nil then
		emitter.Enabled = available
	end
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("BasePart") then
			child.Transparency = part.Transparency
		end
	end
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
		if type(resourceType) ~= "string" or definition == nil then
			warn(`[ResourceNodes] {spawnPoint:GetFullName()} : ResourceType invalide ({tostring(resourceType)}), ignoré`)
			continue
		end
		if WorldConfig[definition.worldId] == nil then
			warn(`[ResourceNodes] {spawnPoint:GetFullName()} : monde {definition.worldId} inconnu, ignoré`)
			continue
		end
		local shape, material = readVisual(resourceType)
		if shape == nil or material == nil then
			warn(`[ResourceNodes] {spawnPoint:GetFullName()} : apparence de {resourceType} absente ou invalide, ignoré`)
			continue
		end

		local index = (countByType[resourceType] or 0) + 1
		countByType[resourceType] = index
		local nodeId = string.format("%s_%03d", resourceType, index)
		local part = createPart(
			nodeId,
			resourceType,
			definition.worldId,
			spawnPoint.CFrame,
			shape :: Enum.PartType,
			material :: Enum.Material
		)
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
