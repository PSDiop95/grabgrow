--!strict
-- Guidage de première session (T5.3) : Collecter -> Vendre -> Améliorer.
-- Système d'interface seulement : aucune requête au serveur, aucun
-- RemoteEvent ajouté, aucun effet sur l'inventaire, les Coins ou les
-- niveaux. Les étapes (OnboardingRules) avancent uniquement sur :
--   * l'état serveur (StateUpdated, statistiques persistantes `progress`) ;
--   * une réponse serveur positive (ActionResult `ok`, `SUCCESS`).
--
-- Jamais bloquant : aucune fenêtre modale, aucun déplacement forcé, aucun
-- achat. Une carte compacte en haut à gauche (hors du sac, du stick, du
-- saut, de « Prendre », de la Boutique et du prompt de vente), un repère
-- au-dessus de la cible et une flèche au bord de l'écran si la cible est
-- hors champ. Le joueur peut masquer la carte (bouton ×) ; elle revient à
-- l'étape suivante ou par le bouton « Guide ».
--
-- Rien n'est sauvegardé par ce contrôleur : l'étape est recalculée à
-- chaque connexion depuis les statistiques du profil (D-2 = b).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local OnboardingConfig = require(Config:WaitForChild("OnboardingConfig"))
local UpgradeConfig = require(Config:WaitForChild("UpgradeConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local OnboardingRules = require(Shared:WaitForChild("Util"):WaitForChild("OnboardingRules"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))

local OnboardingController = {}

local Step = OnboardingRules.Step

local NODE_FOLDER_NAME = "ResourceNodes"
local ZONE_FOLDER_NAME = "SellZones"
local ZONE_ATTRIBUTE = "SellZoneId"
local SHOP_GUI_NAME = "ShopUI"
local SHOP_BUTTON_NAME = "ShopButton"
local SHOP_PANEL_NAME = "ShopPanel"
local INVENTORY_HUD_NAME = "InventoryHUD"
local BAG_PANEL_NAME = "BagPanel"
local WAIT_SECONDS = 10
local ARROW_NAME = "OnboardingArrow"

-- Carte (px).
local CARD_EDGE = 8
local CARD_GAP = 8
local CARD_MIN_WIDTH = 200
local CARD_MAX_WIDTH = 300
local CARD_WIDTH_SCALE = 0.32
local CLOSE_SIZE = 40
local PILL_WIDTH = 92
local PILL_HEIGHT = 40
-- Repères.
local MARKER_RESOURCE_OFFSET = 4.5
local MARKER_SELL_OFFSET = 12
local EDGE_ARROW_SIZE = 44
local EDGE_ARROW_INSET = 40

local COLOR_PANEL = Color3.fromRGB(24, 28, 36)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_MUTED = Color3.fromRGB(190, 198, 210)
local COLOR_ACCENT = Color3.fromRGB(255, 214, 92)
local COLOR_SUCCESS = Color3.fromRGB(120, 230, 140)

-- Glyphes vérifiés dans Studio (Gotham) : × ▶ ▼ → et les emoji ; ✕ ➤ ✔
-- s'affichent mal (carré ou gris).
type Message = { text: string, untilClock: number, color: Color3, glyph: string }

local localPlayer = Players.LocalPlayer :: Player
local started = false

local step: string? = nil
local hidden = false
local message: Message? = nil
local messageToken = 0
local device: OnboardingRules.Device = "touch"
local shopOpen = false
local markerLoopRunning = false
local currentHint: OnboardingRules.Hint? = nil

local screenGui: ScreenGui
local card: Frame
local chipLabel: TextLabel
local titleLabel: TextLabel
local bodyLabel: TextLabel
local controlsLabel: TextLabel
local pill: TextButton
local edgeArrow: TextLabel
local marker: BillboardGui
local markerTween: Tween? = nil
local markerGlyph: TextLabel

-- Éléments d'autres contrôleurs, trouvés par nom (facultatifs).
local shopButton: GuiObject? = nil
local shopPanel: GuiObject? = nil
local bagPanel: GuiObject? = nil

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function newText(parent: Instance, name: string, textSize: number, font: Enum.Font, color: Color3, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.LayoutOrder = order
	label.Text = ""
	label.Parent = parent
	return label
end

local function characterRoot(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Cible du repère pour le type demandé, la plus proche du personnage.
-- Retourne la Part et la distance en deçà de laquelle le repère s'efface
-- (le contrôle natif prend le relais : surbrillance de collecte, prompt).
local function findTarget(kind: OnboardingRules.Target, origin: Vector3): (BasePart?, number)
	local best: BasePart? = nil
	local bestDistance = math.huge
	if kind == "resource" then
		local folder = Workspace:FindFirstChild(NODE_FOLDER_NAME)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("BasePart") and child:GetAttribute("Available") == true then
					local distance = (child.Position - origin).Magnitude
					if distance < bestDistance then
						best, bestDistance = child, distance
					end
				end
			end
		end
		local state = InventoryController.getState()
		local range = if state then state.collectRangeStuds else 0
		return best, range
	elseif kind == "sell" then
		local folder = Workspace:FindFirstChild(ZONE_FOLDER_NAME)
		if folder then
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") and type(descendant:GetAttribute(ZONE_ATTRIBUTE)) == "string" then
					local distance = (descendant.Position - origin).Magnitude
					if distance < bestDistance then
						best, bestDistance = descendant, distance
					end
				end
			end
		end
		return best, GameConfig.Selling.interactRangeStuds
	end
	return nil, 0
end

local function setMarker(part: BasePart?, offset: number)
	if part == nil then
		marker.Enabled = false
		marker.Adornee = nil :: any
		if markerTween then
			markerTween:Cancel()
			markerTween = nil
		end
		return
	end
	marker.Adornee = part
	marker.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	marker.Enabled = true
	if markerTween == nil then
		markerGlyph.Position = UDim2.new(0, 0, 0, 0)
		local tween = TweenService:Create(
			markerGlyph,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.new(0, 0, 0, 10) }
		)
		markerTween = tween
		tween:Play()
	end
end

-- Flèche au bord de l'écran vers une cible hors champ.
local function updateEdgeArrow(position: Vector3?)
	local camera = Workspace.CurrentCamera
	if position == nil or camera == nil then
		edgeArrow.Visible = false
		return
	end
	local point, onScreen = camera:WorldToViewportPoint(position)
	local viewport = camera.ViewportSize
	if onScreen and point.Z > 0 then
		edgeArrow.Visible = false
		return
	end
	local center = viewport / 2
	local direction = Vector2.new(point.X, point.Y) - center
	if point.Z < 0 then
		direction = -direction
	end
	if direction.Magnitude < 1 then
		direction = Vector2.new(0, 1)
	end
	direction = direction.Unit
	local halfX = math.max(center.X - EDGE_ARROW_INSET, 1)
	local halfY = math.max(center.Y - EDGE_ARROW_INSET, 1)
	local scale = math.min(halfX / math.max(math.abs(direction.X), 1e-3), halfY / math.max(math.abs(direction.Y), 1e-3))
	local spot = center + direction * scale
	edgeArrow.Position = UDim2.fromOffset(spot.X, spot.Y)
	-- Le glyphe → pointe vers la droite.
	edgeArrow.Rotation = math.deg(math.atan2(direction.Y, direction.X))
	edgeArrow.Visible = true
end

local function worldTarget(): OnboardingRules.Target?
	local hint = currentHint
	if hint == nil or hidden or step == nil then
		return nil
	end
	if hint.target == "resource" or hint.target == "sell" then
		return hint.target
	end
	return nil
end

local function refreshMarker()
	local kind = worldTarget()
	local root = characterRoot()
	if kind == nil or root == nil then
		setMarker(nil, 0)
		updateEdgeArrow(nil)
		return
	end
	local part, nearDistance = findTarget(kind, root.Position)
	if part == nil or (part.Position - root.Position).Magnitude <= nearDistance then
		setMarker(nil, 0)
		updateEdgeArrow(nil)
		return
	end
	setMarker(part, if kind == "sell" then MARKER_SELL_OFFSET else MARKER_RESOURCE_OFFSET)
	updateEdgeArrow(part.Position)
end

-- Boucle légère (4 Hz) active seulement tant qu'un repère du monde est
-- demandé ; elle s'arrête d'elle-même ensuite.
local function ensureMarkerLoop()
	if markerLoopRunning or worldTarget() == nil then
		refreshMarker()
		return
	end
	markerLoopRunning = true
	task.spawn(function()
		while worldTarget() ~= nil do
			refreshMarker()
			task.wait(OnboardingConfig.markerRefreshSeconds)
		end
		markerLoopRunning = false
		refreshMarker()
	end)
end

-- Flèche animée attachée à un élément d'interface (bouton Boutique, carte).
local function setArrow(parent: GuiObject, enabled: boolean, position: UDim2)
	local existing = parent:FindFirstChild(ARROW_NAME)
	if not enabled then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local arrow = Instance.new("TextLabel")
	arrow.Name = ARROW_NAME
	arrow.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Position = position
	arrow.Size = UDim2.fromOffset(26, 26)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextSize = 24
	arrow.TextColor3 = COLOR_ACCENT
	arrow.TextStrokeTransparency = 0.3
	arrow.Text = "▶"
	arrow.Active = false
	arrow.ZIndex = 5
	arrow.Parent = parent
	TweenService:Create(
		arrow,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = position + UDim2.fromOffset(-8, 0) }
	):Play()
end

local function refreshShopArrows()
	local hint = currentHint
	local target = if hint and not hidden then hint.target else nil
	local button = shopButton
	if button then
		setArrow(button, target == "shop", UDim2.new(0, -4, 0.5, 0))
	end
	local panelObject = shopPanel
	local list = if panelObject then panelObject:FindFirstChild("List") else nil
	if list == nil then
		return
	end
	local marked: { [string]: boolean } = {}
	if target == "cards" then
		for _, upgradeId in ipairs(OnboardingRules.affordable(InventoryController.getState())) do
			marked[upgradeId] = true
		end
	end
	for upgradeId in pairs(UpgradeConfig) do
		local cardFrame = list:FindFirstChild(upgradeId)
		if cardFrame and cardFrame:IsA("GuiObject") then
			-- À gauche du bouton d'achat (124 px, marge 10 px).
			setArrow(cardFrame, marked[upgradeId] == true, UDim2.new(1, -138, 0.5, 0))
		end
	end
end

-- Place la carte en haut à gauche, sous la barre Roblox, sans toucher le
-- panneau du sac ; plus étroite ou sous le sac si la place manque.
local function placeCard()
	local screen = screenGui.AbsoluteSize
	-- Hauteur de la barre Roblox. GetGuiInset vaut 0 tant que la barre
	-- n'est pas prête (constaté dans Studio) : TopbarInset est suivi aussi.
	local inset = GuiService:GetGuiInset()
	local topbar = math.max(inset.Y, GuiService.TopbarInset.Max.Y)
	local width = math.clamp(math.floor(screen.X * CARD_WIDTH_SCALE), CARD_MIN_WIDTH, CARD_MAX_WIDTH)
	local top = topbar + CARD_GAP
	local bag = bagPanel
	if bag and bag.Visible then
		local bagLeft = bag.AbsolutePosition.X - screenGui.AbsolutePosition.X
		local bagBottom = bag.AbsolutePosition.Y - screenGui.AbsolutePosition.Y + bag.AbsoluteSize.Y
		if top < bagBottom and CARD_EDGE + width > bagLeft - CARD_GAP then
			local room = bagLeft - CARD_GAP - CARD_EDGE
			if room >= CARD_MIN_WIDTH then
				width = room
			else
				top = bagBottom + CARD_GAP
			end
		end
	end
	card.Position = UDim2.fromOffset(CARD_EDGE, top)
	card.Size = UDim2.fromOffset(width, 0)
	pill.Position = UDim2.fromOffset(CARD_EDGE, top)
end

local function render()
	local current = step
	local state = InventoryController.getState()
	local hint = if current then OnboardingRules.hint(current, state, shopOpen) else nil
	currentHint = hint
	local activeMessage = message
	if activeMessage and os.clock() >= activeMessage.untilClock then
		activeMessage = nil
		message = nil
	end

	-- Boutique ouverte : la carte s'efface, seules les cartes sont marquées.
	card.Visible, pill.Visible = OnboardingRules.visibility(current, hint ~= nil or activeMessage ~= nil, hidden, shopOpen)

	if activeMessage then
		chipLabel.Text = activeMessage.glyph
		chipLabel.TextColor3 = activeMessage.color
		titleLabel.Visible = false
		bodyLabel.Text = activeMessage.text
		-- Indication de l'étape suivante sous le message.
		if hint and hint.key ~= "onboarding.welcome_body" then
			controlsLabel.Text = if hint.value
				then Localization.format(hint.key, localPlayer.LocaleId, hint.value)
				else translate(hint.key)
			controlsLabel.Visible = true
		else
			controlsLabel.Visible = false
		end
	elseif hint then
		local number = hint.stepNumber
		chipLabel.Text = if number then Localization.format("onboarding.step", localPlayer.LocaleId, number) else "👋"
		chipLabel.TextColor3 = COLOR_ACCENT
		local titleKey = hint.titleKey
		titleLabel.Visible = titleKey ~= nil
		titleLabel.Text = if titleKey then translate(titleKey) else ""
		bodyLabel.Text = if hint.value
			then Localization.format(hint.key, localPlayer.LocaleId, hint.value)
			else translate(hint.key)
		local controls = hint.controls
		controlsLabel.Visible = controls ~= nil
		controlsLabel.Text = if controls then translate(OnboardingRules.controlsKey(controls, device)) else ""
	end

	refreshShopArrows()
	ensureMarkerLoop()
end

local function showMessage(text: string, seconds: number, color: Color3, glyph: string)
	messageToken += 1
	local token = messageToken
	message = { text = text, untilClock = os.clock() + seconds, color = color, glyph = glyph }
	hidden = false
	render()
	task.delay(seconds, function()
		if token == messageToken then
			message = nil
			render()
		end
	end)
end

local function setStep(newStep: string?)
	if newStep == step then
		return
	end
	local previous = step
	step = newStep
	-- Nouvelle étape : la carte masquée revient.
	if previous ~= nil then
		hidden = false
	end
	if newStep == Step.Intro then
		-- Le compte à rebours ne commence qu'une fois le jeu chargé et le
		-- personnage présent : sinon l'accueil s'écoule pendant le
		-- chargement (constaté dans Studio, probable sur appareil lent).
		task.spawn(function()
			if not game:IsLoaded() then
				game.Loaded:Wait()
			end
			if localPlayer.Character == nil then
				localPlayer.CharacterAdded:Wait()
			end
			task.wait(OnboardingConfig.introSeconds)
			if step == Step.Intro then
				setStep(Step.Collect)
				render()
			end
		end)
	end
end

local function onState(state: InventoryController.State)
	local derived = OnboardingRules.fromState(state)
	local first = step == nil
	setStep(OnboardingRules.merge(step, derived))
	if first then
		-- Diagnostic (console développeur, une fois par session) : un joueur
		-- déjà avancé ne voit volontairement aucun guidage.
		local progress = state.progress
		print(
			`[Onboarding] étape de départ : {tostring(step)} (collectes {progress and progress.resourcesCollected or "?"}, ventes {progress and progress.sales or "?"}, Coins dépensés {progress and progress.coinsSpent or "?"})`
		)
	end
	render()
end

local function upgradeName(upgradeId: string): string
	local definition = UpgradeConfig[upgradeId]
	return if definition then translate(definition.displayNameKey) else upgradeId
end

local function onActionResult(result: any)
	local current = step
	if current == nil or current == Step.Completed then
		return
	end
	local newStep, event = OnboardingRules.afterResult(current, result)
	if event == nil then
		return
	end
	setStep(newStep)
	if event == "sold" then
		showMessage(
			Localization.format("onboarding.sold", localPlayer.LocaleId, result.coinsEarned),
			OnboardingConfig.soldMessageSeconds,
			COLOR_ACCENT,
			"💰"
		)
	elseif event == "upgraded" and result.action == Remotes.Action.Upgrade then
		-- Le toast de la Boutique montre déjà le gain (« Sac 50 → 75 »).
		local text = Localization.fill("onboarding.done", localPlayer.LocaleId, {
			name = upgradeName(result.upgradeId),
			level = tostring(result.level),
		})
		showMessage(text, OnboardingConfig.doneMessageSeconds, COLOR_SUCCESS, "🎉")
	else
		render()
	end
end

local function hide()
	local current = step
	if current == nil then
		return
	end
	if message ~= nil then
		-- Fermer un message de confirmation : l'étape suivante s'affiche.
		messageToken += 1
		message = nil
	else
		local newStep, newHidden = OnboardingRules.onHide(current)
		setStep(newStep)
		hidden = newHidden
	end
	render()
end

local function updateDevice()
	local newDevice =
		OnboardingRules.deviceOf(UserInputService:GetLastInputType().Name, UserInputService.TouchEnabled)
	if newDevice ~= device then
		device = newDevice
		render()
	end
end

local function buildInterface()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "OnboardingUI"
	screenGui.ResetOnSpawn = false
	-- Sous la Boutique (6) : le panneau ouvert la recouvre.
	screenGui.DisplayOrder = 4
	-- Coordonnées de la fenêtre entière (flèche de bord, WorldToViewportPoint).
	screenGui.IgnoreGuiInset = true

	card = Instance.new("Frame")
	card.Name = "GuideCard"
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = COLOR_PANEL
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = screenGui
	round(card, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_ACCENT
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = card
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, CLOSE_SIZE + 4)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = card

	chipLabel = newText(card, "Step", 12, Enum.Font.GothamBold, COLOR_ACCENT, 1)
	titleLabel = newText(card, "Title", 16, Enum.Font.GothamBlack, COLOR_TEXT, 2)
	bodyLabel = newText(card, "Body", 15, Enum.Font.GothamBold, COLOR_TEXT, 3)
	controlsLabel = newText(card, "Controls", 12, Enum.Font.Gotham, COLOR_MUTED, 4)

	-- Masquer : en haut à droite de la carte, hors de sa liste verticale.
	local close = Instance.new("TextButton")
	close.Name = "Hide"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE)
	close.BackgroundTransparency = 1
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.TextColor3 = COLOR_MUTED
	close.Text = "×"
	close.Activated:Connect(hide)
	-- UIListLayout placerait le bouton dans la liste : il vit dans un cadre
	-- transparent superposé, qui suit la carte.
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Parent = screenGui
	close.Parent = overlay
	local function followCard()
		overlay.Visible = card.Visible
		close.Position = UDim2.fromOffset(
			card.AbsolutePosition.X - screenGui.AbsolutePosition.X + card.AbsoluteSize.X - 2,
			card.AbsolutePosition.Y - screenGui.AbsolutePosition.Y + 2
		)
	end
	card:GetPropertyChangedSignal("AbsolutePosition"):Connect(followCard)
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(followCard)
	card:GetPropertyChangedSignal("Visible"):Connect(followCard)

	pill = Instance.new("TextButton")
	pill.Name = "ShowGuide"
	pill.Size = UDim2.fromOffset(PILL_WIDTH, PILL_HEIGHT)
	pill.BackgroundColor3 = COLOR_PANEL
	pill.BackgroundTransparency = 0.15
	pill.BorderSizePixel = 0
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = 15
	pill.TextColor3 = COLOR_ACCENT
	pill.Text = `? {translate("onboarding.show")}`
	pill.Visible = false
	pill.Parent = screenGui
	round(pill, 12)
	pill.Activated:Connect(function()
		hidden = false
		render()
	end)

	edgeArrow = Instance.new("TextLabel")
	edgeArrow.Name = "EdgeArrow"
	edgeArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	edgeArrow.Size = UDim2.fromOffset(EDGE_ARROW_SIZE, EDGE_ARROW_SIZE)
	edgeArrow.BackgroundTransparency = 1
	edgeArrow.Font = Enum.Font.GothamBlack
	edgeArrow.TextSize = 36
	edgeArrow.TextColor3 = COLOR_ACCENT
	edgeArrow.TextStrokeTransparency = 0.2
	edgeArrow.Text = "→"
	edgeArrow.Active = false
	edgeArrow.Visible = false
	edgeArrow.Parent = screenGui

	marker = Instance.new("BillboardGui")
	marker.Name = "OnboardingMarker"
	marker.Size = UDim2.fromOffset(40, 50)
	marker.AlwaysOnTop = true
	marker.Enabled = false
	marker.ResetOnSpawn = false
	marker.Parent = playerGui
	markerGlyph = Instance.new("TextLabel")
	markerGlyph.BackgroundTransparency = 1
	markerGlyph.Size = UDim2.fromOffset(40, 40)
	markerGlyph.Font = Enum.Font.GothamBlack
	markerGlyph.TextSize = 34
	markerGlyph.TextColor3 = COLOR_ACCENT
	markerGlyph.TextStrokeTransparency = 0.2
	markerGlyph.Text = "▼"
	markerGlyph.Parent = marker

	screenGui.Parent = playerGui
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeCard)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeCard)
	placeCard()
	followCard()
end

-- Repères dans les interfaces des autres contrôleurs (créées en parallèle).
local function findOtherInterfaces()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	task.spawn(function()
		local hud = playerGui:WaitForChild(INVENTORY_HUD_NAME, WAIT_SECONDS)
		local bag = if hud then hud:WaitForChild(BAG_PANEL_NAME, WAIT_SECONDS) else nil
		if bag and bag:IsA("GuiObject") then
			bagPanel = bag
			bag:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeCard)
			bag:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeCard)
			placeCard()
		end
	end)
	task.spawn(function()
		local shop = playerGui:WaitForChild(SHOP_GUI_NAME, WAIT_SECONDS)
		if shop == nil then
			return
		end
		local button = shop:WaitForChild(SHOP_BUTTON_NAME, WAIT_SECONDS)
		if button and button:IsA("GuiObject") then
			shopButton = button
		end
		local panelInstance = shop:WaitForChild(SHOP_PANEL_NAME, WAIT_SECONDS)
		if panelInstance and panelInstance:IsA("GuiObject") then
			local panelObject = panelInstance :: GuiObject
			shopPanel = panelObject
			shopOpen = panelObject.Visible
			panelObject:GetPropertyChangedSignal("Visible"):Connect(function()
				shopOpen = panelObject.Visible
				render()
			end)
		end
		render()
	end)
end

function OnboardingController.start()
	assert(not started, "OnboardingController.start appelé deux fois")
	started = true
	buildInterface()
	updateDevice()
	UserInputService.LastInputTypeChanged:Connect(updateDevice)
	findOtherInterfaces()
	Remotes.waitFor(Remotes.Name.ActionResult).OnClientEvent:Connect(onActionResult)
	InventoryController.onStateChanged(onState)
	local state = InventoryController.getState()
	if state then
		onState(state)
	end
end

return OnboardingController
