--!strict
-- Affichage du sac : miroir de l'état envoyé par le serveur (StateUpdated).
-- Aucune autorité : le client n'ajoute jamais de ressource lui-même.
--
-- Interface minimale de T2, construite par code ; le HUD complet est prévu
-- en T5. Placée en haut au centre : hors des zones du stick et du saut.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ResourceConfig = require(Shared:WaitForChild("Config"):WaitForChild("ResourceConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))

local InventoryController = {}

export type State = {
	inventory: {
		resources: { [string]: number },
		used: number,
		capacity: number,
		free: number,
	},
	collectIntervalSeconds: number,
	collectRangeStuds: number,
}

local COLOR_PANEL = Color3.fromRGB(24, 28, 36)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_BAR = Color3.fromRGB(96, 204, 78)
local COLOR_BAR_FULL = Color3.fromRGB(230, 80, 70)
local COLOR_GAIN = Color3.fromRGB(190, 255, 170)
local COLOR_WARNING = Color3.fromRGB(255, 200, 90)
local TOAST_HOLD_SECONDS = 0.7
local TOAST_FADE_SECONDS = 0.4

local localPlayer = Players.LocalPlayer :: Player
local state: State? = nil
local started = false

local titleLabel: TextLabel
local detailLabel: TextLabel
local barFill: Frame
local panelScale: UIScale
local toastLabel: TextLabel
local toastTween: Tween? = nil
local toastToken = 0

-- Ressources dans un ordre stable (valeur de vente croissante).
local resourceOrder: { string } = {}
for resourceId in pairs(ResourceConfig) do
	table.insert(resourceOrder, resourceId)
end
table.sort(resourceOrder, function(a: string, b: string): boolean
	local va, vb = ResourceConfig[a].sellValue, ResourceConfig[b].sellValue
	if va ~= vb then
		return va < vb
	end
	return a < b
end)

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

local function newLabel(parent: Instance, size: UDim2, position: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = COLOR_TEXT
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = parent
	return label
end

local function buildInterface()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InventoryHUD"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 5

	local panel = Instance.new("Frame")
	panel.Name = "BagPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.new(0.6, 0, 0, 62)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(200, 62)
	sizeLimit.MaxSize = Vector2.new(320, 62)
	sizeLimit.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	titleLabel = newLabel(panel, UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 5), 16)
	titleLabel.Name = "Title"

	local barBack = Instance.new("Frame")
	barBack.Name = "Bar"
	barBack.Position = UDim2.new(0, 10, 0, 28)
	barBack.Size = UDim2.new(1, -20, 0, 10)
	barBack.BackgroundColor3 = Color3.fromRGB(60, 66, 78)
	barBack.BorderSizePixel = 0
	barBack.Parent = panel
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBack

	barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = COLOR_BAR
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = barFill

	detailLabel = newLabel(panel, UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 42), 13)
	detailLabel.Name = "Detail"
	detailLabel.Font = Enum.Font.GothamMedium

	toastLabel = newLabel(screenGui, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 76), 22)
	toastLabel.Name = "Toast"
	toastLabel.TextTransparency = 1
	toastLabel.TextStrokeTransparency = 1
	toastLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local function render()
	local current = state
	if current == nil then
		titleLabel.Text = translate("hud.bag")
		detailLabel.Text = ""
		return
	end
	local inventory = current.inventory
	local full = inventory.used >= inventory.capacity
	local title = `{translate("hud.bag")}  {inventory.used} / {inventory.capacity}`
	if full then
		title = `{translate("hud.bag_full")}  {inventory.used} / {inventory.capacity}`
	end
	titleLabel.Text = title
	titleLabel.TextColor3 = if full then COLOR_WARNING else COLOR_TEXT

	local ratio = if inventory.capacity > 0 then math.clamp(inventory.used / inventory.capacity, 0, 1) else 0
	barFill.BackgroundColor3 = if full then COLOR_BAR_FULL else COLOR_BAR
	TweenService:Create(barFill, TweenInfo.new(0.15), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()

	local parts: { string } = {}
	for _, resourceId in ipairs(resourceOrder) do
		local quantity = inventory.resources[resourceId] or 0
		table.insert(parts, `{translate(ResourceConfig[resourceId].displayNameKey)} {quantity}`)
	end
	detailLabel.Text = table.concat(parts, "   ")
end

local function showToast(text: string, color: Color3)
	toastToken += 1
	local token = toastToken
	if toastTween then
		toastTween:Cancel()
	end
	toastLabel.Text = text
	toastLabel.TextColor3 = color
	toastLabel.TextTransparency = 0
	toastLabel.TextStrokeTransparency = 0.4
	task.delay(TOAST_HOLD_SECONDS, function()
		if token ~= toastToken then
			return
		end
		local tween = TweenService:Create(
			toastLabel,
			TweenInfo.new(TOAST_FADE_SECONDS),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		toastTween = tween
		tween:Play()
	end)
end

local function pulsePanel()
	panelScale.Scale = 1.08
	TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Forme attendue de l'état serveur. Un état illisible est ignoré.
local function isValidState(value: any): boolean
	if type(value) ~= "table" or type(value.inventory) ~= "table" then
		return false
	end
	local inventory = value.inventory
	return type(inventory.resources) == "table"
		and type(inventory.used) == "number"
		and type(inventory.capacity) == "number"
		and type(value.collectIntervalSeconds) == "number"
		and type(value.collectRangeStuds) == "number"
end

-- Dernier état reçu du serveur, ou nil avant le premier.
function InventoryController.getState(): State?
	return state
end

function InventoryController.isFull(): boolean
	local current = state
	return current ~= nil and current.inventory.used >= current.inventory.capacity
end

-- Retour visuel d'une collecte confirmée par le serveur.
function InventoryController.showGain(resourceType: string, amount: number)
	local definition = ResourceConfig[resourceType]
	local name = if definition then translate(definition.displayNameKey) else resourceType
	showToast(`+{amount} {name}`, COLOR_GAIN)
	pulsePanel()
end

function InventoryController.showMessage(key: string)
	showToast(translate(key), COLOR_WARNING)
end

function InventoryController.start()
	assert(not started, "InventoryController.start appelé deux fois")
	started = true
	buildInterface()
	render()
	Remotes.waitFor(Remotes.Name.StateUpdated).OnClientEvent:Connect(function(newState: any)
		if not isValidState(newState) then
			return
		end
		state = newState
		render()
	end)
end

return InventoryController
