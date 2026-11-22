--!strict
-- Représentation visuelle des nœuds de ressources, côté client (T10.1,
-- D-027 ; T10.2, D-032). Purement visuel : aucune règle de collecte,
-- aucun envoi au serveur.
--
-- Le Part du nœud (créé par le serveur, attributs NodeId, ResourceType,
-- Available) reste la cible du client (raycast, surlignage) et la vérité
-- du serveur. Il est masqué localement (LocalTransparencyModifier) et
-- remplacé, pour CE joueur, par un visuel local :
--   * « modèle » : clone de ReplicatedStorage.ResourceModels.<type>
--     (Systems/ResourceModelLoader), quand il existe ;
--   * « primitive » : copie locale du Part et de ses pièces de détail
--     (T8.4), pour les ressources sans modèle (T10.2 : les 20 ressources
--     ont ainsi la même présence).
--
-- États (Available vient du serveur, jamais d'ici) :
--   * attente : flottement, rotation, pulsation, pirouette Épique
--     (ResourceVFXConfig), nœuds les plus proches de la caméra seulement
--     (24 au plus, 60 studs, 30 Hz, une seule boucle), coupée en « Effets
--     réduits » ;
--   * demande locale (notifyLocalRequest) : léger écrasement immédiat, le
--     nœud reste visible ; la disparition attend le serveur ;
--   * disparition : masquage immédiat si le joueur local vient de le
--     demander (l'éclat de collecte suit), sinon rétrécissement bref (pris
--     par un autre joueur) ;
--   * réapparition : reconstruction (rebond) de TOUTES les pièces (V-01),
--     signalée à ResourceVFXController (onRespawn) pour sa bouffée.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ResourceConfig = require(Config:WaitForChild("ResourceConfig"))
local ResourceVisualConfig = require(Config:WaitForChild("ResourceVisualConfig"))
local ResourceVFXConfig = require(Config:WaitForChild("ResourceVFXConfig"))
local ResourceFxRules = require(Shared:WaitForChild("Util"):WaitForChild("ResourceFxRules"))

local NodeVisuals = {}

local NODE_FOLDER_NAME = "ResourceNodes"
local MODEL_FOLDER_NAME = "ResourceModels"
local VISUAL_FOLDER_NAME = "ClientResourceVisuals"
local FX_GUI_NAME = "FeedbackFX"
local WAIT_SECONDS = 30
-- Échelle minimale d'un rétrécissement (une taille nulle est refusée).
local MIN_SCALE = 0.05

type Piece = {
	part: BasePart,
	offset: CFrame, -- repère du centre, à l'échelle 1
	size: Vector3, -- taille de repos
}

type Visual = {
	node: BasePart,
	nodeId: string,
	resourceType: string,
	rarity: string?,
	isModel: boolean,
	model: Model?,
	center: CFrame, -- centre de repos (repère des pièces)
	ground: Vector3, -- point au sol sous le nœud
	color: Color3, -- couleur dominante (particules)
	pieces: { Piece },
	idle: ResourceFxRules.Idle?,
	phase: number,
	available: boolean,
	visible: boolean,
	scale: number, -- échelle courante (écrasement, rebond, rétrécissement)
	appliedScale: number, -- échelle des tailles actuellement posées
	animated: boolean,
	scaleToken: number,
	claimedUntil: number?,
	connection: RBXScriptConnection,
}

export type NodeInfo = {
	node: BasePart,
	nodeId: string,
	resourceType: string,
	rarity: string?,
	available: boolean,
	center: CFrame,
	ground: Vector3,
	color: Color3,
}

export type Flash = {
	root: Instance,
	parts: { BasePart },
	center: CFrame,
	color: Color3,
	setPose: (centerCFrame: CFrame, scale: number, transparency: number) -> (),
	destroy: () -> (),
}

local localPlayer = Players.LocalPlayer :: Player
local visuals: { [BasePart]: Visual } = {}
local respawnListeners: { (info: NodeInfo) -> () } = {}
local disappearListeners: { (info: NodeInfo) -> () } = {}
local started = false
local modelFolder: Instance? = nil
local visualFolder: Folder

local function reducedEffects(): boolean
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local fxGui = if playerGui then playerGui:FindFirstChild(FX_GUI_NAME) else nil
	return fxGui ~= nil and fxGui:GetAttribute("ReducedEffects") == true
end

local function rarityOf(resourceType: string): string?
	local definition = ResourceConfig[resourceType]
	return if definition then definition.rarity else nil
end

local function idleFor(rarity: string?): ResourceFxRules.Idle?
	local visual = if rarity then ResourceVFXConfig.Rarities[rarity] else nil
	if visual == nil then
		return nil
	end
	return {
		bob = visual.bob,
		bobPeriod = visual.bobPeriod,
		spin = visual.spin,
		pulse = visual.pulse,
		pulsePeriod = visual.pulsePeriod,
		special = visual.special,
	}
end

local function infoOf(visual: Visual): NodeInfo
	return {
		node = visual.node,
		nodeId = visual.nodeId,
		resourceType = visual.resourceType,
		rarity = visual.rarity,
		available = visual.available,
		center = visual.center,
		ground = visual.ground,
		color = visual.color,
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

-- Pose de repos à l'échelle courante (sauf si l'attente pose déjà).
local function poseRest(visual: Visual)
	if not visual.animated then
		poseVisual(visual, visual.center, visual.scale)
	end
end

local function setVisible(visual: Visual, visible: boolean)
	visual.visible = visible
	for _, piece in ipairs(visual.pieces) do
		piece.part.Transparency = if visible then 0 else 1
	end
end

-- Pièces serveur du nœud (Part + détails), dans l'ordre.
local function serverParts(node: BasePart): { BasePart }
	local list: { BasePart } = { node }
	for _, child in ipairs(node:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	return list
end

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Copie locale d'un nœud primitif : un Part neuf par pièce serveur (ni
-- attributs, ni enfants, ni émetteur).
local function primitiveClone(node: BasePart): Model
	local model = Instance.new("Model")
	for index, source in ipairs(serverParts(node)) do
		local part = Instance.new("Part")
		part.Name = if index == 1 then "Body" else source.Name
		if source:IsA("Part") then
			part.Shape = source.Shape
		end
		part.Size = source.Size
		part.Color = source.Color
		part.Material = source.Material
		part.Reflectance = source.Reflectance
		part.CFrame = source.CFrame
		prepare(part)
		part.Parent = model
	end
	return model
end

-- Construit (ou reconstruit) le visuel local du nœud.
local function build(visual: Visual, template: Model?)
	if visual.model then
		visual.model:Destroy()
	end
	local node = visual.node
	local config = ResourceVisualConfig[visual.resourceType]
	local halfHeight = if config then config.size[2] / 2 else node.Size.Y / 2
	visual.ground = node.Position - Vector3.new(0, halfHeight, 0)
	local clone: Model
	if template then
		-- Modèle : posé au sol, lacet propre au nœud.
		visual.center = CFrame.new(visual.ground)
			* CFrame.Angles(0, math.rad(ResourceFxRules.baseYawFor(visual.nodeId)), 0)
		clone = template:Clone()
		clone:PivotTo(visual.center)
	else
		-- Primitive : centre du Part, sans rotation (la rotation des pièces
		-- est dans leur décalage) ; la rotation d'attente se fait en lacet.
		visual.center = CFrame.new(node.Position)
		clone = primitiveClone(node)
	end
	clone.Name = visual.nodeId
	local pieces: { Piece } = {}
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			prepare(descendant)
			table.insert(pieces, {
				part = descendant,
				offset = visual.center:ToObjectSpace(descendant.CFrame),
				size = descendant.Size,
			})
		end
	end
	-- Masque local des pièces serveur (la cible reste active pour le raycast).
	for _, part in ipairs(serverParts(node)) do
		part.LocalTransparencyModifier = 1
	end
	visual.isModel = template ~= nil
	visual.model = clone
	visual.pieces = pieces
	visual.color = if template and pieces[1] then pieces[1].part.Color else node.Color
	visual.appliedScale = 1
	visual.scale = 1
	visual.animated = false
	setVisible(visual, visual.available)
	clone.Parent = visualFolder
end

local function templateFor(resourceType: string): Model?
	local folder = modelFolder
	local template = if folder then folder:FindFirstChild(resourceType) else nil
	return if template and template:IsA("Model") then template else nil
end

-- Anime l'échelle du visuel de `from` à `to` ; un nouvel appel (ou un
-- changement d'état) annule le précédent. `onDone` seulement si non annulé.
local function animateScale(
	visual: Visual,
	from: number,
	to: number,
	seconds: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	onDone: (() -> ())?
)
	visual.scaleToken += 1
	local token = visual.scaleToken
	local function alive(): boolean
		return visual.scaleToken == token and visuals[visual.node] == visual
	end
	local driver = Instance.new("NumberValue")
	driver.Value = from
	visual.scale = from
	poseRest(visual)
	driver.Changed:Connect(function(value: number)
		if alive() then
			visual.scale = value
			poseRest(visual)
		end
	end)
	local tween = TweenService:Create(driver, TweenInfo.new(seconds, style, direction), { Value = to })
	tween.Completed:Once(function()
		if alive() then
			visual.scale = to
			poseRest(visual)
			if onDone then
				onDone()
			end
		end
		driver:Destroy()
	end)
	tween:Play()
end

local function cancelScale(visual: Visual)
	visual.scaleToken += 1
	visual.scale = 1
	poseRest(visual)
end

local function onAvailableChanged(visual: Visual)
	local available = visual.node:GetAttribute("Available") == true
	if available == visual.available then
		return
	end
	visual.available = available
	if available then
		-- Réapparition décidée par le serveur : reconstruction, puis bouffée.
		visual.claimedUntil = nil
		setVisible(visual, true)
		animateScale(
			visual,
			ResourceVFXConfig.RespawnStartScale,
			1,
			ResourceVFXConfig.RespawnSeconds,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out,
			nil
		)
		local info = infoOf(visual)
		for _, listener in ipairs(respawnListeners) do
			task.spawn(listener, info)
		end
		return
	end
	-- Disparition décidée par le serveur.
	local gone = infoOf(visual)
	for _, listener in ipairs(disappearListeners) do
		task.spawn(listener, gone)
	end
	local kind = ResourceFxRules.disappearance(os.clock(), visual.claimedUntil)
	visual.claimedUntil = nil
	if kind == "claimed" or reducedEffects() or not visual.visible then
		-- L'éclat de collecte local prend le relais (FeedbackController).
		cancelScale(visual)
		setVisible(visual, false)
		return
	end
	-- Pris par un autre joueur : rétrécissement bref, puis masquage.
	animateScale(
		visual,
		visual.scale,
		MIN_SCALE,
		ResourceVFXConfig.PopSeconds,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In,
		function()
			setVisible(visual, false)
			visual.scale = 1
			poseRest(visual)
		end
	)
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
	local rarity = rarityOf(resourceType)
	local visual: Visual
	visual = {
		node = child,
		nodeId = nodeId,
		resourceType = resourceType,
		rarity = rarity,
		isModel = false,
		model = nil,
		center = child.CFrame,
		ground = child.Position,
		color = child.Color,
		pieces = {},
		idle = idleFor(rarity),
		phase = ResourceFxRules.phaseFor(nodeId),
		available = child:GetAttribute("Available") == true,
		visible = false,
		scale = 1,
		appliedScale = 1,
		animated = false,
		scaleToken = 0,
		claimedUntil = nil,
		connection = child:GetAttributeChangedSignal("Available"):Connect(function()
			onAvailableChanged(visual)
		end),
	}
	visuals[child] = visual
	build(visual, templateFor(resourceType))
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
	visual.scaleToken += 1
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
	for _, visual in pairs(visuals) do
		if not visual.isModel and visual.resourceType == template.Name then
			visual.scaleToken += 1
			build(visual, template)
		end
	end
end

-- Animation d'attente des nœuds proches (30 Hz, 24 nœuds au plus).
local function startIdleLoop()
	local frameInterval = 1 / ResourceVFXConfig.AnimationHz
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
		if sinceSelection >= ResourceVFXConfig.SelectionRefreshSeconds then
			sinceSelection = 0
			local candidates: { ResourceFxRules.Candidate } = {}
			if not reduced then
				local origin = camera.CFrame.Position
				for node, visual in pairs(visuals) do
					if visual.available and visual.idle then
						table.insert(candidates, { id = visual.nodeId, distance = (node.Position - origin).Magnitude })
					end
				end
			end
			selected = ResourceFxRules.selectAnimated(
				candidates,
				ResourceVFXConfig.MaxAnimatedNodes,
				ResourceVFXConfig.AnimationRadiusStuds
			)
		end
		local now = os.clock()
		for _, visual in pairs(visuals) do
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

-- Ce que le surlignage doit entourer : le visuel local s'il existe.
function NodeVisuals.adorneeFor(node: BasePart): Instance
	local visual = visuals[node]
	if visual and visual.model then
		return visual.model
	end
	return node
end

-- Demande de collecte envoyée par le joueur local (après l'envoi : rien
-- n'est retardé). Retour immédiat (écrasement) ; la disparition qui suit
-- éventuellement est attribuée à cette demande (pas de double effet).
function NodeVisuals.notifyLocalRequest(node: BasePart)
	local visual = visuals[node]
	if visual == nil or not visual.available then
		return
	end
	visual.claimedUntil = os.clock() + ResourceVFXConfig.LocalClaimSeconds
	if reducedEffects() then
		return
	end
	animateScale(
		visual,
		ResourceVFXConfig.PressScale,
		1,
		ResourceVFXConfig.PressSeconds,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out,
		nil
	)
end

-- Réapparitions (après le rebond lancé) : ResourceVFXController.
function NodeVisuals.onRespawn(listener: (info: NodeInfo) -> ())
	table.insert(respawnListeners, listener)
end

-- Disparitions (Available devenu faux) : ResourceVFXController libère
-- aussitôt l'émetteur et l'aura du nœud.
function NodeVisuals.onDisappear(listener: (info: NodeInfo) -> ())
	table.insert(disappearListeners, listener)
end

-- Instantané des nœuds suivis (attribution des émetteurs et auras).
function NodeVisuals.snapshot(): { NodeInfo }
	local list: { NodeInfo } = {}
	for _, visual in pairs(visuals) do
		table.insert(list, infoOf(visual))
	end
	return list
end

function NodeVisuals.infoFor(node: BasePart): NodeInfo?
	local visual = visuals[node]
	return if visual then infoOf(visual) else nil
end

-- Copie locale de TOUTES les pièces du visuel (V-01), pour l'éclat de
-- collecte. `colorize` transforme chaque couleur ; matériau Neon.
-- nil si le nœud n'est pas suivi.
function NodeVisuals.createFlash(node: BasePart, parent: Instance, colorize: (Color3) -> Color3): Flash?
	local visual = visuals[node]
	if visual == nil or #visual.pieces == 0 then
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
		prepare(copy)
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
		color = visual.color,
		setPose = function(centerCFrame: CFrame, scale: number, transparency: number)
			applyPieces(copies, centerCFrame, math.max(scale, MIN_SCALE), true)
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
