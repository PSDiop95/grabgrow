--!strict
-- Collecte côté client : ciblage, entrées et retour visuel.
-- Le client ne décide jamais si une collecte est valide : il envoie un
-- identifiant de nœud (RequestCollect) et affiche la réponse du serveur.
--
-- Entrées :
--   * mobile  : bouton d'action (maintenir pour enchaîner) ou toucher la ressource ;
--   * PC      : touche E (maintenir pour enchaîner) ou clic sur la ressource ;
--   * manette : bouton X.
-- La cible est la ressource disponible la plus proche, à portée.
--
-- Les nœuds sont des Parts de Workspace.ResourceNodes créés par le serveur
-- (attributs NodeId, ResourceType, Available). Ils peuvent apparaître et
-- disparaître à tout moment (streaming) : suivi par ChildAdded/ChildRemoved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ResourceConfig = require(Config:WaitForChild("ResourceConfig"))
local UpgradeConfig = require(Config:WaitForChild("UpgradeConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))

local CollectionController = {}

local NODE_FOLDER_NAME = "ResourceNodes"
local NODE_FOLDER_TIMEOUT_SECONDS = 30
-- Recherche de cible : 10 fois par seconde suffit, pas à chaque image.
local TARGET_REFRESH_SECONDS = 0.1
-- Sans réponse du serveur après ce délai, une nouvelle demande est permise.
local RESPONSE_TIMEOUT_SECONDS = 1
-- Marge ajoutée à l'intervalle nominal pour ne pas arriver en avance.
local SEND_MARGIN_SECONDS = 0.03
local TAP_RAY_LENGTH_STUDS = 300
local COLLECT_KEY = Enum.KeyCode.E
local COLLECT_GAMEPAD_BUTTON = Enum.KeyCode.ButtonX
-- Bouton tactile de collecte (pixels), placé au-dessus du saut de Roblox.
local GRAB_BUTTON_SIZE = 90
local GRAB_BUTTON_GAP = 12
local JUMP_BUTTON_NAME = "JumpButton"
-- Sans bouton de saut (pas encore créé) : en bas à droite, au-dessus de
-- son emplacement habituel.
local GRAB_BUTTON_FALLBACK_POSITION = UDim2.new(1, -60, 1, -172)

type TrackedNode = {
	available: boolean,
	fullSize: Vector3,
	connection: RBXScriptConnection,
}

local localPlayer = Players.LocalPlayer :: Player
local requestCollect: RemoteEvent
local tracked: { [BasePart]: TrackedNode } = {}
local target: BasePart? = nil
local holding = false
local nextSendAt = 0
local pendingUntil = 0
local started = false

local highlight: Highlight
local billboard: BillboardGui
local billboardLabel: TextLabel

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

-- Valeurs d'affichage ; le serveur applique les siennes.
local function collectInterval(): number
	local state = InventoryController.getState()
	return if state then state.collectIntervalSeconds else UpgradeConfig.Grabber.levels[1].value
end

local function collectRange(): number
	local state = InventoryController.getState()
	return if state then state.collectRangeStuds else GameConfig.Collection.baseRangeStuds
end

local function setTarget(part: BasePart?)
	if part == target then
		return
	end
	target = part
	highlight.Adornee = part
	-- Les types de l'API déclarent Adornee non nul ; nil retire l'ancrage.
	billboard.Adornee = part :: any
	billboard.Enabled = part ~= nil
	if part then
		local resourceType = part:GetAttribute("ResourceType")
		local definition = if type(resourceType) == "string" then ResourceConfig[resourceType] else nil
		local name = if definition then translate(definition.displayNameKey) else ""
		local hint = if UserInputService.TouchEnabled then "" else `  [{COLLECT_KEY.Name}]`
		billboardLabel.Text = name .. hint
	end
end

local function findTarget(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local origin = root.Position
	local best: BasePart? = nil
	local bestDistance = collectRange()
	for part, node in pairs(tracked) do
		if node.available then
			local distance = (part.Position - origin).Magnitude
			if distance <= bestDistance then
				best = part
				bestDistance = distance
			end
		end
	end
	return best
end

-- Envoie une demande pour `part`, au plus une à la fois et sans dépasser
-- la cadence nominale. Seul l'identifiant du nœud est transmis.
local function request(part: BasePart)
	local now = os.clock()
	if now < pendingUntil or now < nextSendAt then
		return
	end
	local nodeId = part:GetAttribute("NodeId")
	if type(nodeId) ~= "string" then
		return
	end
	pendingUntil = now + RESPONSE_TIMEOUT_SECONDS
	nextSendAt = now + collectInterval() + SEND_MARGIN_SECONDS
	requestCollect:FireServer({ resourceId = nodeId })
end

local function requestTarget()
	local part = target
	if part then
		request(part)
	end
end

local function setHolding(value: boolean)
	holding = value
	if value then
		requestTarget()
	end
end

local function onAvailableChanged(part: BasePart)
	local node = tracked[part]
	if node == nil then
		return
	end
	local available = part:GetAttribute("Available") == true
	local reappeared = available and not node.available
	node.available = available
	if reappeared then
		-- Réapparition : petit rebond local, purement visuel.
		part.Size = node.fullSize * 0.3
		TweenService:Create(
			part,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = node.fullSize }
		):Play()
	elseif not available and target == part then
		setTarget(nil)
	end
end

local function track(child: Instance)
	if not child:IsA("BasePart") or tracked[child] ~= nil then
		return
	end
	if type(child:GetAttribute("NodeId")) ~= "string" then
		return
	end
	tracked[child] = {
		available = child:GetAttribute("Available") == true,
		fullSize = child.Size,
		connection = child:GetAttributeChangedSignal("Available"):Connect(function()
			onAvailableChanged(child)
		end),
	}
end

local function untrack(child: Instance)
	if not child:IsA("BasePart") then
		return
	end
	local node = tracked[child]
	if node == nil then
		return
	end
	node.connection:Disconnect()
	tracked[child] = nil
	if target == child then
		setTarget(nil)
	end
end

local function onActionResult(result: any)
	if type(result) ~= "table" or result.action ~= Remotes.Action.Collect then
		return
	end
	pendingUntil = 0
	local code = result.code
	if result.ok == true then
		if type(result.resourceType) == "string" and type(result.amount) == "number" then
			InventoryController.showGain(result.resourceType, result.amount)
		end
	elseif code == Remotes.ResultCode.InventoryFull then
		-- Inutile d'enchaîner : le joueur doit vider son sac.
		holding = false
		-- T3 : invite à vendre.
		InventoryController.showMessage("sell.go_sell")
	elseif code == Remotes.ResultCode.TooFar then
		InventoryController.showMessage("collect.too_far")
	end
	-- Les autres refus (cadence, ressource déjà prise...) restent silencieux.
end

-- Toucher ou clic : collecte la ressource visée, si c'en est une.
local function onPointerPressed(input: InputObject, nodeFolder: Instance)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { nodeFolder }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * TAP_RAY_LENGTH_STUDS, params)
	if hit and hit.Instance:IsA("BasePart") and tracked[hit.Instance] ~= nil then
		request(hit.Instance)
	end
end

-- Place le bouton de collecte au-dessus du bouton de saut de Roblox
-- (TouchGui), quelle que soit la taille ou l'orientation de l'écran. Suit
-- ses déplacements par événements ; position de repli s'il n'existe pas.
local function anchorAboveJumpButton(playerGui: Instance, screenGui: ScreenGui, button: GuiObject)
	local jumpConnections: { RBXScriptConnection } = {}

	local function disconnectJump()
		for _, connection in ipairs(jumpConnections) do
			connection:Disconnect()
		end
		table.clear(jumpConnections)
	end

	local function place(jump: GuiObject?)
		if jump == nil or jump.Parent == nil or jump.AbsoluteSize.X <= 0 then
			button.Position = GRAB_BUTTON_FALLBACK_POSITION
			return
		end
		local relative = jump.AbsolutePosition - screenGui.AbsolutePosition
		button.Position = UDim2.fromOffset(
			math.floor(relative.X + jump.AbsoluteSize.X / 2),
			math.floor(relative.Y - GRAB_BUTTON_GAP)
		)
	end

	local function follow(jump: GuiObject)
		disconnectJump()
		local function update()
			place(jump)
		end
		table.insert(jumpConnections, jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
		table.insert(jumpConnections, jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
		table.insert(jumpConnections, screenGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
		table.insert(jumpConnections, jump.AncestryChanged:Connect(function()
			if jump.Parent == nil then
				disconnectJump()
				place(nil)
			end
		end))
		update()
	end

	local function consider(instance: Instance)
		if instance.Name == JUMP_BUTTON_NAME and instance:IsA("GuiObject") then
			follow(instance)
		end
	end

	playerGui.DescendantAdded:Connect(consider)
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		consider(descendant)
	end
end

local function buildInterface()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local effects = Instance.new("Folder")
	effects.Name = "ClientCollectionEffects"
	effects.Parent = Workspace

	highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = effects

	billboard = Instance.new("BillboardGui")
	billboard.Name = "CollectionTarget"
	billboard.Size = UDim2.new(0, 170, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	billboardLabel = Instance.new("TextLabel")
	billboardLabel.BackgroundTransparency = 1
	billboardLabel.Size = UDim2.new(1, 0, 1, 0)
	billboardLabel.Font = Enum.Font.GothamBold
	billboardLabel.TextSize = 18
	billboardLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	billboardLabel.TextStrokeTransparency = 0.4
	billboardLabel.Text = ""
	billboardLabel.Parent = billboard

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CollectionHUD"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui

	-- Bouton tactile : juste au-dessus du bouton de saut, sous le pouce
	-- droit (A-35 : décalé depuis le bord droit, il entrait dans la zone du
	-- stick gauche sur un écran étroit).
	local button = Instance.new("TextButton")
	button.Name = "GrabButton"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = GRAB_BUTTON_FALLBACK_POSITION
	button.Size = UDim2.new(0, GRAB_BUTTON_SIZE, 0, GRAB_BUTTON_SIZE)
	button.BackgroundColor3 = Color3.fromRGB(96, 204, 78)
	button.BackgroundTransparency = 0.15
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = translate("collect.action")
	button.Visible = UserInputService.TouchEnabled
	button.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHolding(true)
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHolding(false)
		end
	end)

	anchorAboveJumpButton(playerGui, screenGui, button)
end

function CollectionController.start()
	assert(not started, "CollectionController.start appelé deux fois")
	started = true

	requestCollect = Remotes.waitFor(Remotes.Name.RequestCollect)
	buildInterface()
	Remotes.waitFor(Remotes.Name.ActionResult).OnClientEvent:Connect(onActionResult)

	local nodeFolder = Workspace:WaitForChild(NODE_FOLDER_NAME, NODE_FOLDER_TIMEOUT_SECONDS)
	if nodeFolder == nil then
		warn(`[Collection] Workspace.{NODE_FOLDER_NAME} introuvable : collecte désactivée`)
		return
	end
	nodeFolder.ChildAdded:Connect(track)
	nodeFolder.ChildRemoved:Connect(untrack)
	for _, child in ipairs(nodeFolder:GetChildren()) do
		track(child)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == COLLECT_KEY or input.KeyCode == COLLECT_GAMEPAD_BUTTON then
			setHolding(true)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onPointerPressed(input, nodeFolder)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == COLLECT_KEY or input.KeyCode == COLLECT_GAMEPAD_BUTTON then
			setHolding(false)
		end
	end)

	local sinceRefresh = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceRefresh += deltaTime
		if sinceRefresh < TARGET_REFRESH_SECONDS then
			return
		end
		sinceRefresh = 0
		setTarget(findTarget())
		if holding then
			requestTarget()
		end
	end)
end

return CollectionController
