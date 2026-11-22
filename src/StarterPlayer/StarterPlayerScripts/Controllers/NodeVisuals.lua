--!strict
-- Représentation visuelle des nœuds de ressources, côté client (T10.1,
-- D-027). Purement visuel : aucune règle de collecte, aucun envoi.
--
-- Le Part du nœud (créé par le serveur, attributs NodeId, ResourceType,
-- Available) reste la cible du client et la vérité du serveur. Ce module
-- gère ce que le joueur VOIT :
--   * « primitive » : le Part et ses pièces de détail (T8.4) ;
--   * « modèle » : clone local de ReplicatedStorage.ResourceModels.<type>
--     (Systems/ResourceModelLoader), quand il existe ; le Part et ses
--     détails sont alors masqués localement (LocalTransparencyModifier).
--
-- V-01 : la réapparition (rebond) et l'éclat de collecte s'appliquent à
-- TOUTES les pièces du visuel (Part + détails, ou modèle entier), mises à
-- l'échelle autour du centre du nœud.
--
-- Animation d'attente (flottement, rotation, pulsation par rareté,
-- RarityVisualConfig) : modèles seulement, nœuds les plus proches de la
-- caméra (24 au plus, 60 studs, 30 Hz), coupée en « Effets réduits ».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ResourceConfig = require(Config:WaitForChild("ResourceConfig"))
local ResourceVisualConfig = require(Config:WaitForChild("ResourceVisualConfig"))
local RarityVisualConfig = require(Config:WaitForChild("RarityVisualConfig"))
local ResourceFxRules = require(Shared:WaitForChild("Util"):WaitForChild("ResourceFxRules"))

local NodeVisuals = {}

local NODE_FOLDER_NAME = "ResourceNodes"
local MODEL_FOLDER_NAME = "ResourceModels"
local VISUAL_FOLDER_NAME = "ClientResourceVisuals"
local FX_GUI_NAME = "FeedbackFX"
local WAIT_SECONDS = 30
local RESPAWN_START_SCALE = 0.3
local RESPAWN_SECONDS = 0.25

type Piece = {
	part: BasePart,
	offset: CFrame, -- repère du centre, à l'échelle 1
	size: Vector3, -- taille de repos
}

type Visual = {
	node: BasePart,
	nodeId: string,
	isModel: boolean,
	model: Model?,
	center: CFrame, -- centre de repos (repère des pièces)
	pieces: { Piece },
	hiddenPieces: { BasePart }, -- pièces serveur masquées localement (modèle)
	idle: ResourceFxRules.Idle?,
	phase: number,
	available: boolean,
	scale: number, -- échelle courante (rebond)
	appliedScale: number, -- échelle des tailles actuellement posées
	animated: boolean,
	respawnToken: number,
	connection: RBXScriptConnection,
}

export type Flash = {
	root: Instance,
	parts: { BasePart },
	center: CFrame,
	setPose: (centerCFrame: CFrame, scale: number, transparency: number) -> (),
	destroy: () -> (),
}

local localPlayer = Players.LocalPlayer :: Player
local visuals: { [BasePart]: Visual } = {}
local started = false
local modelFolder: Instance? = nil
local visualFolder: Folder

local function reducedEffects(): boolean
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local fxGui = if playerGui then playerGui:FindFirstChild(FX_GUI_NAME) else nil
	return fxGui ~= nil and fxGui:GetAttribute("ReducedEffects") == true
end

local function idleFor(resourceType: string): ResourceFxRules.Idle?
	local definition = ResourceConfig[resourceType]
	local rarity = if definition then RarityVisualConfig.Rarities[definition.rarity] else nil
	if rarity == nil then
		return nil
	end
	return {
		bob = rarity.bob,
		bobPeriod = rarity.bobPeriod,
		spin = rarity.spin,
		pulse = rarity.pulse,
		pulsePeriod = rarity.pulsePeriod,
	}
end

-- Pose toutes les pièces : centre `center`, échelle `scale` (V-01).
local function applyPieces(pieces: { Piece }, center: CFrame, scale: number, resize: boolean)
	local parts: { BasePart } = table.create(#pieces)
	local cframes: { CFrame } = table.create(#pieces)
	for index, piece in ipairs(pieces) do
		local offset = piece.offset
		parts[index] = piece.part
		cframes[index] = center * (offset - offset.Position + offset.Position * scale)
		if resize then
			piece.part.Size = piece.size * scale
		end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Pose le visuel ; ne retaille les pièces que si l'échelle a changé.
local function poseVisual(visual: Visual, center: CFrame, scale: number)
	applyPieces(visual.pieces, center, scale, scale ~= visual.appliedScale)
	visual.appliedScale = scale
end

local function setModelVisible(visual: Visual, visible: boolean)
	for _, piece in ipairs(visual.pieces) do
		piece.part.Transparency = if visible then 0 else 1
	end
end

-- Capture des pièces d'un nœud primitif (Part + détails), avant toute
-- modification locale.
local function primitivePieces(node: BasePart, center: CFrame): { Piece }
	local pieces: { Piece } = { { part = node, offset = CFrame.identity, size = node.Size } }
	for _, child in ipairs(node:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(pieces, { part = child, offset = center:ToObjectSpace(child.CFrame), size = child.Size })
		end
	end
	return pieces
end

-- Centre de repos d'un modèle : au sol du point de spawn (bas du Part du
-- nœud, taille de config), lacet propre au nœud.
local function modelCenter(node: BasePart, resourceType: string, nodeId: string): CFrame
	local visual = ResourceVisualConfig[resourceType]
	local halfHeight = if visual then visual.size[2] / 2 else node.Size.Y / 2
	local ground = node.Position - Vector3.new(0, halfHeight, 0)
	return CFrame.new(ground) * CFrame.Angles(0, math.rad(ResourceFxRules.baseYawFor(nodeId)), 0)
end

local function buildModel(visual: Visual, template: Model)
	local clone = template:Clone()
	clone.Name = visual.nodeId
	clone:PivotTo(visual.center)
	local pieces: { Piece } = {}
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			table.insert(pieces, {
				part = descendant,
				offset = visual.center:ToObjectSpace(descendant.CFrame),
				size = descendant.Size,
			})
		end
	end
	-- Masque local du Part serveur et de ses détails (la cible reste active).
	local hidden: { BasePart } = { visual.node }
	for _, child in ipairs(visual.node:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(hidden, child)
		end
	end
	for _, part in ipairs(hidden) do
		part.LocalTransparencyModifier = 1
	end
	local emitter = visual.node:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		-- L'émetteur serveur reste attaché au Part : il suit le nœud.
		emitter.Enabled = visual.available
	end
	visual.isModel = true
	visual.model = clone
	visual.pieces = pieces
	visual.appliedScale = 1
	visual.hiddenPieces = hidden
	visual.idle = idleFor(visual.node:GetAttribute("ResourceType") :: string)
	setModelVisible(visual, visual.available)
	clone.Parent = visualFolder
end

local function templateFor(resourceType: string): Model?
	local folder = modelFolder
	local template = if folder then folder:FindFirstChild(resourceType) else nil
	return if template and template:IsA("Model") then template else nil
end

local function playRespawn(visual: Visual)
	visual.respawnToken += 1
	local token = visual.respawnToken
	local driver = Instance.new("NumberValue")
	driver.Value = RESPAWN_START_SCALE
	local function step()
		if visual.respawnToken ~= token or visuals[visual.node] ~= visual then
			return
		end
		visual.scale = driver.Value
		if not visual.animated or not visual.isModel then
			poseVisual(visual, visual.center, visual.scale)
		end
	end
	driver.Changed:Connect(step)
	step()
	local tween = TweenService:Create(
		driver,
		TweenInfo.new(RESPAWN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	tween.Completed:Once(function()
		if visual.respawnToken == token and visuals[visual.node] == visual then
			visual.scale = 1
			if not visual.animated or not visual.isModel then
				poseVisual(visual, visual.center, 1)
			end
		end
		driver:Destroy()
	end)
	tween:Play()
end

local function onAvailableChanged(visual: Visual)
	local available = visual.node:GetAttribute("Available") == true
	local reappeared = available and not visual.available
	visual.available = available
	if visual.isModel then
		setModelVisible(visual, available)
	end
	if reappeared then
		playRespawn(visual)
	elseif not available then
		-- Disparition : le serveur masque déjà le Part ; annuler un rebond
		-- en cours et revenir à la taille de repos pour le prochain cycle.
		visual.respawnToken += 1
		visual.scale = 1
		if not visual.isModel then
			poseVisual(visual, visual.center, 1)
		end
	end
end

local function track(child: Instance)
	if not child:IsA("BasePart") or visuals[child] ~= nil then
		return
	end
	local nodeId = child:GetAttribute("NodeId")
	local resourceType = child:GetAttribute("ResourceType")
	if type(nodeId) ~= "string" or type(resourceType) ~= "string" then
		return
	end
	local visual: Visual
	visual = {
		node = child,
		nodeId = nodeId,
		isModel = false,
		model = nil,
		center = child.CFrame,
		pieces = primitivePieces(child, child.CFrame),
		hiddenPieces = {},
		idle = nil,
		phase = ResourceFxRules.phaseFor(nodeId),
		available = child:GetAttribute("Available") == true,
		scale = 1,
		appliedScale = 1,
		animated = false,
		respawnToken = 0,
		connection = child:GetAttributeChangedSignal("Available"):Connect(function()
			onAvailableChanged(visual)
		end),
	}
	visuals[child] = visual
	local template = templateFor(resourceType)
	if template then
		visual.center = modelCenter(child, resourceType, nodeId)
		buildModel(visual, template)
	end
end

local function untrack(child: Instance)
	if not child:IsA("BasePart") then
		return
	end
	local visual = visuals[child]
	if visual == nil then
		return
	end
	visual.connection:Disconnect()
	visual.respawnToken += 1
	if visual.model then
		visual.model:Destroy()
	end
	visuals[child] = nil
end

-- Un modèle arrive après les nœuds (chargement serveur asynchrone) :
-- passage du visuel primitif au modèle.
local function onTemplateAdded(template: Instance)
	if not template:IsA("Model") then
		return
	end
	for node, visual in pairs(visuals) do
		if not visual.isModel and node:GetAttribute("ResourceType") == template.Name then
			poseVisual(visual, visual.center, 1)
			visual.center = modelCenter(node, template.Name, visual.nodeId)
			buildModel(visual, template)
		end
	end
end

-- Animation d'attente des modèles proches (30 Hz, 24 nœuds au plus).
local function startIdleLoop()
	local frameInterval = 1 / RarityVisualConfig.AnimationHz
	local accumulator = 0
	local sinceSelection = math.huge
	local selected: { [string]: boolean } = {}
	RunService.RenderStepped:Connect(function(deltaTime: number)
		accumulator += deltaTime
		sinceSelection += deltaTime
		if accumulator < frameInterval then
			return
		end
		accumulator = 0
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local reduced = reducedEffects()
		if sinceSelection >= RarityVisualConfig.SelectionRefreshSeconds then
			sinceSelection = 0
			local candidates: { ResourceFxRules.Candidate } = {}
			if not reduced then
				local origin = camera.CFrame.Position
				for node, visual in pairs(visuals) do
					if visual.isModel and visual.available and visual.idle then
						table.insert(candidates, { id = visual.nodeId, distance = (node.Position - origin).Magnitude })
					end
				end
			end
			selected = ResourceFxRules.selectAnimated(
				candidates,
				RarityVisualConfig.MaxAnimatedNodes,
				RarityVisualConfig.AnimationRadiusStuds
			)
		end
		local now = os.clock()
		for _, visual in pairs(visuals) do
			if not visual.isModel then
				continue
			end
			local animate = selected[visual.nodeId] == true and visual.available
			if animate then
				visual.animated = true
				local pose = ResourceFxRules.idlePose(visual.idle, now, visual.phase, reduced)
				local center = visual.center
					* CFrame.new(0, pose.offsetY, 0)
					* CFrame.Angles(0, math.rad(pose.yawDegrees), 0)
				poseVisual(visual, center, visual.scale * pose.scale)
			elseif visual.animated then
				-- Sortie du budget : retour à la pose de repos, une fois.
				visual.animated = false
				poseVisual(visual, visual.center, visual.scale)
			end
		end
	end)
end

-- Ce que le surlignage doit entourer : le modèle s'il existe, sinon le Part.
function NodeVisuals.adorneeFor(node: BasePart): Instance
	local visual = visuals[node]
	if visual and visual.model then
		return visual.model
	end
	return node
end

-- Copie locale de TOUTES les pièces visibles du nœud (V-01), pour l'éclat
-- de collecte. `colorize` transforme chaque couleur ; matériau Neon.
-- nil si le nœud n'est pas suivi.
function NodeVisuals.createFlash(node: BasePart, parent: Instance, colorize: (Color3) -> Color3): Flash?
	local visual = visuals[node]
	if visual == nil then
		return nil
	end
	local root = Instance.new("Model")
	root.Name = "CollectFlash"
	local copies: { Piece } = {}
	local parts: { BasePart } = {}
	for _, piece in ipairs(visual.pieces) do
		local source = piece.part
		local copy: BasePart
		if source:IsA("MeshPart") or not source:IsA("Part") then
			copy = source:Clone()
			copy:ClearAllChildren()
		else
			local p = Instance.new("Part")
			p.Shape = source.Shape
			copy = p
		end
		for name in pairs(copy:GetAttributes()) do
			copy:SetAttribute(name, nil)
		end
		copy.Name = "FlashPiece"
		copy.Size = piece.size
		copy.Color = colorize(source.Color)
		copy.Material = Enum.Material.Neon
		copy.Transparency = 0
		copy.LocalTransparencyModifier = 0
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = false
		copy.Parent = root
		table.insert(copies, { part = copy, offset = piece.offset, size = piece.size })
		table.insert(parts, copy)
	end
	applyPieces(copies, visual.center, 1, false)
	root.Parent = parent
	local flash: Flash = {
		root = root,
		parts = parts,
		center = visual.center,
		setPose = function(centerCFrame: CFrame, scale: number, transparency: number)
			applyPieces(copies, centerCFrame, scale, true)
			for _, part in ipairs(parts) do
				part.Transparency = transparency
			end
		end,
		destroy = function()
			root:Destroy()
		end,
	}
	return flash
end

function NodeVisuals.start()
	if started then
		return
	end
	started = true

	visualFolder = Instance.new("Folder")
	visualFolder.Name = VISUAL_FOLDER_NAME
	visualFolder.Parent = Workspace

	task.spawn(function()
		local models = ReplicatedStorage:WaitForChild(MODEL_FOLDER_NAME, WAIT_SECONDS)
		if models == nil then
			return
		end
		modelFolder = models
		models.ChildAdded:Connect(onTemplateAdded)
		for _, template in ipairs(models:GetChildren()) do
			onTemplateAdded(template)
		end
	end)

	task.spawn(function()
		local folder = Workspace:WaitForChild(NODE_FOLDER_NAME, WAIT_SECONDS)
		if folder == nil then
			warn("[NodeVisuals] Workspace.ResourceNodes absent")
			return
		end
		folder.ChildAdded:Connect(track)
		folder.ChildRemoved:Connect(untrack)
		for _, child in ipairs(folder:GetChildren()) do
			track(child)
		end
	end)

	startIdleLoop()
end

return NodeVisuals
