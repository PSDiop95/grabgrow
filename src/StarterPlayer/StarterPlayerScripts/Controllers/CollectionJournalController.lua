--!strict
-- Journal de collection (T8.6, D-022), côté client. Affichage seulement.
--
-- Données : l'ensemble `discovered` du dernier état serveur (StateUpdated,
-- via InventoryController). Catalogue, totaux et pourcentages :
-- CollectionJournalRules (dérivés de ResourceConfig et WorldConfig). Le
-- client n'envoie AUCUNE demande : il ne peut ni déclarer, ni modifier, ni
-- réinitialiser une découverte.
--
-- Vues :
--   * principale : progression globale et une carte par monde (nom, couleur,
--     barre, « 3 / 5 — 60 % », mention « Monde verrouillé ») ;
--   * monde : ses ressources ; découverte = vignette colorée, nom, rareté,
--     valeur ; inconnue = silhouette grise et « Inconnue », sans nom, valeur,
--     rareté ni lieu.
-- Vignettes 2D (couleur de ResourceVisualConfig) : aucun modèle 3D chargé.
--
-- Entrées :
--   * mobile  : bouton « Journal » sous le bouton Boutique (à sa gauche si
--               la place manque) ;
--   * PC      : touche J ou clic ;
--   * manette : croix bas pour ouvrir/fermer, B pour revenir puis fermer.
-- Panneau : même emplacement et même taille que celui de la Boutique ; un
-- seul des deux est ouvert à la fois.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ResourceConfig = require(Config:WaitForChild("ResourceConfig"))
local ResourceVisualConfig = require(Config:WaitForChild("ResourceVisualConfig"))
local WorldConfig = require(Config:WaitForChild("WorldConfig"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local CollectionJournalRules = require(Shared:WaitForChild("Util"):WaitForChild("CollectionJournalRules"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))
local UpgradeController = require(script.Parent:WaitForChild("UpgradeController"))

local CollectionJournalController = {}

local TOGGLE_KEY = Enum.KeyCode.J
local TOGGLE_GAMEPAD = Enum.KeyCode.DPadDown
local BUTTON_WIDTH = 96
local BUTTON_HEIGHT = 52
local BUTTON_GAP = 8
local BUTTON_EDGE = 8
-- Sans bouton Boutique trouvé : bord droit, sous la position de repli de la
-- Boutique (UpgradeController : 0.38).
local BUTTON_FALLBACK = UDim2.new(1, -12, 0.38, BUTTON_HEIGHT + BUTTON_GAP)
local SHOP_UI_NAME = "ShopUI"
local SHOP_BUTTON_NAME = "ShopButton"
local SHOP_PANEL_NAME = "ShopPanel"
local GRAB_HUD_NAME = "CollectionHUD"
local GRAB_BUTTON_NAME = "GrabButton"
local WAIT_SECONDS = 10
local CARD_HEIGHT = 76
local ENTRY_HEIGHT = 64
local TILE_SIZE = 48

local COLOR_PANEL = Color3.fromRGB(24, 28, 36)
local COLOR_CARD = Color3.fromRGB(40, 46, 58)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_MUTED = Color3.fromRGB(170, 178, 192)
local COLOR_TRACK = Color3.fromRGB(60, 66, 78)
local COLOR_ACCENT = Color3.fromRGB(150, 215, 255)
local COLOR_COINS = Color3.fromRGB(255, 214, 92)
local COLOR_UNKNOWN = Color3.fromRGB(70, 76, 88)
local COLOR_LOCKED = Color3.fromRGB(255, 160, 120)

-- Identité visuelle de chaque monde (affichage seulement).
local WORLD_COLORS: { [string]: Color3 } = {
	GreenValley = Color3.fromRGB(96, 196, 92),
	GoldenDesert = Color3.fromRGB(232, 184, 72),
	FrozenPeaks = Color3.fromRGB(120, 196, 240),
	MysticWorld = Color3.fromRGB(176, 120, 232),
}
local WORLD_FALLBACK_COLOR = Color3.fromRGB(150, 150, 150)

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(200, 206, 216),
	Uncommon = Color3.fromRGB(120, 220, 120),
	Rare = Color3.fromRGB(100, 170, 255),
	Epic = Color3.fromRGB(200, 130, 255),
}

type WorldCard = {
	button: TextButton,
	progress: TextLabel,
	fill: Frame,
	locked: TextLabel,
}

type EntryRow = {
	frame: Frame,
	tile: Frame,
	stroke: UIStroke,
	name: TextLabel,
	detail: TextLabel,
}

local localPlayer = Players.LocalPlayer :: Player
local started = false
-- Interface construite (les références ci-dessous sont valides).
local built = false

local panel: Frame
local journalButton: TextButton
local titleLabel: TextLabel
local totalLabel: TextLabel
local backButton: TextButton
local closeButton: TextButton
local mainList: ScrollingFrame
local detailList: ScrollingFrame
local cards: { [string]: WorldCard } = {}
local entries: { EntryRow } = {}
-- Monde affiché en détail, ou nil pour la vue principale.
local selectedWorldId: string? = nil

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

local function fill(key: string, values: { [string]: string }): string
	return Localization.fill(key, localPlayer.LocaleId, values)
end

local function toColor(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function newLabel(parent: Instance, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = parent
	return label
end

local function newButton(parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 16
	button.TextColor3 = COLOR_TEXT
	button.BorderSizePixel = 0
	button.Parent = parent
	round(button, 10)
	return button
end

local function newList(name: string): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Name = name
	list.Position = UDim2.new(0, 12, 0, 66)
	list.Size = UDim2.new(1, -24, 1, -76)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

local function discoveredSet(): { [string]: boolean }
	local state = InventoryController.getState()
	local discovered = if state then (state :: any).discovered else nil
	return if type(discovered) == "table" then discovered else {}
end

local function isUnlocked(worldId: string): boolean
	local state = InventoryController.getState()
	return state ~= nil and state.worlds[worldId] == true
end

local function progressText(discovered: number, total: number, percent: number): string
	return fill("journal.world_progress", {
		discovered = tostring(discovered),
		total = tostring(total),
		percent = tostring(percent),
	})
end

local function buildCard(worldId: string, order: number)
	local button = newButton(mainList)
	button.Name = worldId
	button.LayoutOrder = order
	button.Size = UDim2.new(1, -8, 0, CARD_HEIGHT)
	button.BackgroundColor3 = COLOR_CARD
	button.Text = ""

	local stripe = Instance.new("Frame")
	stripe.Name = "Identity"
	stripe.Position = UDim2.new(0, 0, 0, 0)
	stripe.Size = UDim2.new(0, 10, 1, 0)
	stripe.BackgroundColor3 = WORLD_COLORS[worldId] or WORLD_FALLBACK_COLOR
	stripe.BorderSizePixel = 0
	stripe.Parent = button
	round(stripe, 10)

	local name = newLabel(button, 18, COLOR_TEXT)
	name.Name = "WorldName"
	name.Position = UDim2.new(0, 22, 0, 8)
	name.Size = UDim2.new(0.6, -22, 0, 24)
	name.Text = translate(WorldConfig[worldId].displayNameKey)

	local locked = newLabel(button, 13, COLOR_LOCKED)
	locked.Name = "Locked"
	locked.AnchorPoint = Vector2.new(1, 0)
	locked.Position = UDim2.new(1, -12, 0, 10)
	locked.Size = UDim2.new(0.4, -12, 0, 20)
	locked.TextXAlignment = Enum.TextXAlignment.Right
	locked.Text = translate("journal.locked")

	local progress = newLabel(button, 14, COLOR_MUTED)
	progress.Name = "Progress"
	progress.Position = UDim2.new(0, 22, 0, 34)
	progress.Size = UDim2.new(1, -34, 0, 18)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 22, 1, -16)
	track.Size = UDim2.new(1, -34, 0, 8)
	track.BackgroundColor3 = COLOR_TRACK
	track.BorderSizePixel = 0
	track.Parent = button
	round(track, 4)
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = WORLD_COLORS[worldId] or WORLD_FALLBACK_COLOR
	barFill.BorderSizePixel = 0
	barFill.Parent = track
	round(barFill, 4)

	button.Activated:Connect(function()
		selectedWorldId = worldId
		CollectionJournalController.render()
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = backButton
		end
	end)

	cards[worldId] = { button = button, progress = progress, fill = barFill, locked = locked }
end

local function buildEntry(order: number)
	local frame = Instance.new("Frame")
	frame.Name = `Entry{order}`
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, ENTRY_HEIGHT)
	frame.BackgroundColor3 = COLOR_CARD
	frame.BorderSizePixel = 0
	frame.Parent = detailList
	round(frame, 10)

	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.new(0, 8, 0.5, 0)
	tile.Size = UDim2.new(0, TILE_SIZE, 0, TILE_SIZE)
	tile.BorderSizePixel = 0
	tile.Parent = frame
	round(tile, TILE_SIZE // 2)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = tile

	local name = newLabel(frame, 16, COLOR_TEXT)
	name.Name = "ResourceName"
	name.Position = UDim2.new(0, TILE_SIZE + 20, 0, 10)
	name.Size = UDim2.new(1, -(TILE_SIZE + 28), 0, 22)

	local detail = newLabel(frame, 14, COLOR_MUTED)
	detail.Name = "Detail"
	detail.Position = UDim2.new(0, TILE_SIZE + 20, 0, 34)
	detail.Size = UDim2.new(1, -(TILE_SIZE + 28), 0, 18)

	table.insert(entries, { frame = frame, tile = tile, stroke = stroke, name = name, detail = detail })
end

local function renderMain(summary: CollectionJournalRules.Summary)
	titleLabel.Text = translate("journal.title")
	for _, world in ipairs(summary.worlds) do
		local card = cards[world.worldId]
		if card then
			card.progress.Text = progressText(world.discovered, world.total, world.percent)
			card.fill.Size = UDim2.new(if world.total > 0 then world.discovered / world.total else 0, 0, 1, 0)
			card.locked.Visible = not isUnlocked(world.worldId)
		end
	end
end

local function renderDetail(worldId: string, summary: CollectionJournalRules.Summary)
	local discovered = discoveredSet()
	local resourceIds: { string } = {}
	for _, world in ipairs(CollectionJournalRules.catalog()) do
		if world.worldId == worldId then
			resourceIds = world.resourceIds
		end
	end
	local worldText = translate(WorldConfig[worldId].displayNameKey)
	for _, world in ipairs(summary.worlds) do
		if world.worldId == worldId then
			worldText = `{worldText} · {progressText(world.discovered, world.total, world.percent)}`
		end
	end
	titleLabel.Text = worldText

	for index, entry in ipairs(entries) do
		local resourceId = resourceIds[index]
		entry.frame.Visible = resourceId ~= nil
		if resourceId ~= nil then
			local definition = ResourceConfig[resourceId]
			if CollectionJournalRules.isDiscovered(discovered, resourceId) then
				local visual = ResourceVisualConfig[resourceId]
				local rarityColor = RARITY_COLORS[definition.rarity] or COLOR_MUTED
				entry.tile.BackgroundColor3 = if visual then toColor(visual.color) else COLOR_UNKNOWN
				entry.stroke.Color = rarityColor
				entry.stroke.Transparency = 0
				entry.name.Text = translate(definition.displayNameKey)
				entry.name.TextColor3 = COLOR_TEXT
				local rarity = translate(`rarity.{string.lower(definition.rarity)}`)
				entry.detail.Text = `{rarity} · {fill("journal.value", { value = tostring(definition.sellValue) })}`
				entry.detail.TextColor3 = rarityColor
			else
				-- Silhouette : aucune donnée de la ressource (nom, valeur,
				-- rareté, couleur, lieu).
				entry.tile.BackgroundColor3 = COLOR_UNKNOWN
				entry.stroke.Color = COLOR_TRACK
				entry.stroke.Transparency = 0
				entry.name.Text = translate("journal.unknown")
				entry.name.TextColor3 = COLOR_MUTED
				entry.detail.Text = ""
			end
		end
	end
end

-- Rendu complet à partir du dernier état serveur (au plus 20 ressources).
function CollectionJournalController.render()
	if not built then
		return
	end
	local summary = CollectionJournalRules.summarize(discoveredSet())
	totalLabel.Text = fill("journal.total", {
		discovered = tostring(summary.discovered),
		total = tostring(summary.total),
		percent = tostring(summary.percent),
	})
	local worldId = selectedWorldId
	mainList.Visible = worldId == nil
	detailList.Visible = worldId ~= nil
	backButton.Visible = worldId ~= nil
	if worldId == nil then
		renderMain(summary)
	else
		renderDetail(worldId, summary)
	end
end

local function setOpen(open: boolean)
	if open then
		UpgradeController.close()
		selectedWorldId = nil
		CollectionJournalController.render()
	end
	panel.Visible = open
	if open and UserInputService.GamepadEnabled then
		local first = CollectionJournalRules.catalog()[1]
		local card = if first then cards[first.worldId] else nil
		GuiService.SelectedObject = if card then card.button else closeButton
	elseif not open and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject = nil
	end
end

function CollectionJournalController.isOpen(): boolean
	return built and panel.Visible
end

-- Retour : vue détaillée -> vue principale -> fermeture.
local function back()
	if selectedWorldId ~= nil then
		selectedWorldId = nil
		CollectionJournalController.render()
		if UserInputService.GamepadEnabled then
			local card = cards[CollectionJournalRules.catalog()[1].worldId]
			GuiService.SelectedObject = if card then card.button else closeButton
		end
	else
		setOpen(false)
	end
end

local function buildInterface(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "JournalUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 6

	journalButton = newButton(screenGui)
	journalButton.Name = "JournalButton"
	journalButton.AnchorPoint = Vector2.new(1, 0.5)
	journalButton.Position = BUTTON_FALLBACK
	journalButton.Size = UDim2.new(0, BUTTON_WIDTH, 0, BUTTON_HEIGHT)
	journalButton.BackgroundColor3 = COLOR_PANEL
	journalButton.BackgroundTransparency = 0.15
	journalButton.TextColor3 = COLOR_ACCENT
	local hint = if UserInputService.TouchEnabled then "" else ` [{TOGGLE_KEY.Name}]`
	journalButton.Text = `{translate("journal.open")}{hint}`
	journalButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)

	panel = Instance.new("Frame")
	panel.Name = "JournalPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.new(0.9, 0, 0.82, 0)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui
	round(panel, 14)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(560, 640)
	sizeLimit.Parent = panel

	titleLabel = newLabel(panel, 20, COLOR_TEXT)
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.new(0, 16, 0, 10)
	titleLabel.Size = UDim2.new(1, -196, 0, 24)

	totalLabel = newLabel(panel, 14, COLOR_COINS)
	totalLabel.Name = "Total"
	totalLabel.Position = UDim2.new(0, 16, 0, 38)
	totalLabel.Size = UDim2.new(1, -196, 0, 18)

	closeButton = newButton(panel)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 10)
	closeButton.Size = UDim2.new(0, 64, 0, 44)
	closeButton.BackgroundColor3 = COLOR_CARD
	closeButton.Text = "X"
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	backButton = newButton(panel)
	backButton.Name = "Back"
	backButton.AnchorPoint = Vector2.new(1, 0)
	backButton.Position = UDim2.new(1, -82, 0, 10)
	backButton.Size = UDim2.new(0, 104, 0, 44)
	backButton.BackgroundColor3 = COLOR_CARD
	backButton.Text = translate("journal.back")
	backButton.Visible = false
	backButton.Activated:Connect(back)

	mainList = newList("Worlds")
	detailList = newList("Resources")
	detailList.Visible = false

	for index, world in ipairs(CollectionJournalRules.catalog()) do
		buildCard(world.worldId, index)
	end
	local maxEntries = 0
	for _, world in ipairs(CollectionJournalRules.catalog()) do
		maxEntries = math.max(maxEntries, #world.resourceIds)
	end
	for index = 1, maxEntries do
		buildEntry(index)
	end

	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	built = true
	return screenGui
end

-- Le bouton se place sous le bouton Boutique, ou à sa gauche si la place
-- manque (bas de l'écran, bouton « Prendre » juste dessous sur mobile).
-- Recalcul par événements seulement.
local function followShop(screenGui: ScreenGui)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local shopUi = playerGui:WaitForChild(SHOP_UI_NAME, WAIT_SECONDS)
	local shopInstance = if shopUi then shopUi:WaitForChild(SHOP_BUTTON_NAME, WAIT_SECONDS) else nil
	if shopInstance == nil or not shopInstance:IsA("GuiObject") then
		return
	end
	local shop = shopInstance :: GuiObject
	local grabHud = playerGui:FindFirstChild(GRAB_HUD_NAME)
	local grabInstance = if grabHud then grabHud:FindFirstChild(GRAB_BUTTON_NAME) else nil
	local grab: GuiObject? = if grabInstance and grabInstance:IsA("GuiObject") then grabInstance else nil

	-- Le rectangle (coin haut gauche, taille) toucherait-il « Prendre » ?
	local function hitsGrab(topLeft: Vector2, origin: Vector2): boolean
		if grab == nil or not grab.Visible then
			return false
		end
		local grabTopLeft = grab.AbsolutePosition - origin
		local grabBottomRight = grabTopLeft + grab.AbsoluteSize
		local bottomRight = topLeft + Vector2.new(BUTTON_WIDTH, BUTTON_HEIGHT)
		return topLeft.X < grabBottomRight.X
			and grabTopLeft.X < bottomRight.X
			and topLeft.Y < grabBottomRight.Y
			and grabTopLeft.Y < bottomRight.Y
	end

	local function place()
		local origin = screenGui.AbsolutePosition
		local screen = screenGui.AbsoluteSize
		local shopTopLeft = shop.AbsolutePosition - origin
		local shopSize = shop.AbsoluteSize
		local below = Vector2.new(
			shopTopLeft.X + shopSize.X / 2 - BUTTON_WIDTH / 2,
			shopTopLeft.Y + shopSize.Y + BUTTON_GAP
		)
		journalButton.AnchorPoint = Vector2.new(0, 0)
		if below.Y + BUTTON_HEIGHT <= screen.Y - BUTTON_EDGE and not hitsGrab(below, origin) then
			journalButton.Position = UDim2.fromOffset(below.X, below.Y)
		else
			-- À gauche de la Boutique, même hauteur.
			local x = math.max(shopTopLeft.X - BUTTON_GAP - BUTTON_WIDTH, BUTTON_EDGE)
			journalButton.Position = UDim2.fromOffset(x, shopTopLeft.Y + shopSize.Y / 2 - BUTTON_HEIGHT / 2)
		end
	end

	shop:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	shop:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	if grab then
		grab:GetPropertyChangedSignal("Visible"):Connect(place)
		grab:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	end
	place()
end

-- Même cadre que le panneau de la Boutique (qui évite déjà le panneau du
-- sac) ; ouvrir la Boutique ferme le Journal.
local function followShopPanel()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local shopUi = playerGui:WaitForChild(SHOP_UI_NAME, WAIT_SECONDS)
	local shopInstance = if shopUi then shopUi:WaitForChild(SHOP_PANEL_NAME, WAIT_SECONDS) else nil
	if shopInstance == nil or not shopInstance:IsA("GuiObject") then
		return
	end
	local shopPanel = shopInstance :: GuiObject
	local function mirror()
		panel.AnchorPoint = shopPanel.AnchorPoint
		panel.Position = shopPanel.Position
		panel.Size = shopPanel.Size
	end
	shopPanel:GetPropertyChangedSignal("Position"):Connect(mirror)
	shopPanel:GetPropertyChangedSignal("Size"):Connect(mirror)
	-- T9 : le bouton Journal, placé près de « Boutique », recouvrait le
	-- panneau de la Boutique sur mobile ; il est masqué tant qu'elle est ouverte.
	local function syncWithShop()
		journalButton.Visible = not shopPanel.Visible
		if shopPanel.Visible and panel.Visible then
			setOpen(false)
		end
	end
	shopPanel:GetPropertyChangedSignal("Visible"):Connect(syncWithShop)
	mirror()
	syncWithShop()
end

function CollectionJournalController.start()
	assert(not started, "CollectionJournalController.start appelé deux fois")
	started = true
	local screenGui = buildInterface()
	CollectionJournalController.render()
	task.spawn(followShop, screenGui)
	task.spawn(followShopPanel)

	-- Rendu seulement panneau ouvert ; à l'ouverture, rendu complet.
	InventoryController.onStateChanged(function()
		if panel.Visible then
			CollectionJournalController.render()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == TOGGLE_GAMEPAD then
			-- Panneau ouvert avec une sélection manette : la croix bas
			-- navigue dans la liste ; B revient ou ferme.
			local selected = GuiService.SelectedObject
			if not (panel.Visible and selected ~= nil and selected:IsDescendantOf(panel)) then
				setOpen(not panel.Visible)
			end
		elseif processed then
			return
		elseif input.KeyCode == TOGGLE_KEY then
			setOpen(not panel.Visible)
		elseif input.KeyCode == Enum.KeyCode.ButtonB and panel.Visible then
			back()
		end
	end)
end

return CollectionJournalController
