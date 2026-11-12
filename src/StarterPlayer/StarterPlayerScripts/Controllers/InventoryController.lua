--!strict
-- Affichage du sac : miroir de l'état envoyé par le serveur (StateUpdated).
-- Aucune autorité : le client n'ajoute jamais de ressource lui-même.
--
-- Interface minimale de T2, construite par code ; le HUD complet est prévu
-- en T5. Placée en haut au centre : hors des zones du stick et du saut.
-- T3 : solde de Coins, valeur vendable estimée (SaleValue, affichage
-- seulement) et confirmation du montant crédité par le serveur.
-- T4 : l'estimation applique le Multiplier reçu du serveur (affichage) ;
-- niveaux, mondes et vitesse sont relayés aux autres contrôleurs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local ResourceConfig = require(Shared:WaitForChild("Config"):WaitForChild("ResourceConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local SaleValue = require(Shared:WaitForChild("Util"):WaitForChild("SaleValue"))

local InventoryController = {}

export type State = {
	inventory: {
		resources: { [string]: number },
		used: number,
		capacity: number,
		free: number,
	},
	coins: number,
	collectIntervalSeconds: number,
	collectRangeStuds: number,
	upgrades: { [string]: number },
	worlds: { [string]: boolean },
	sellMultiplier: number,
	walkSpeed: number,
}

local COLOR_PANEL = Color3.fromRGB(24, 28, 36)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_BAR = Color3.fromRGB(96, 204, 78)
local COLOR_BAR_FULL = Color3.fromRGB(230, 80, 70)
local COLOR_GAIN = Color3.fromRGB(190, 255, 170)
local COLOR_WARNING = Color3.fromRGB(255, 200, 90)
local COLOR_COINS = Color3.fromRGB(255, 214, 92)
local COLOR_SUCCESS = Color3.fromRGB(120, 230, 140)
local COIN_COUNT_SECONDS = 0.5
local TOAST_HOLD_SECONDS = 0.7
local TOAST_FADE_SECONDS = 0.4

local localPlayer = Players.LocalPlayer :: Player
local state: State? = nil
local started = false

local titleLabel: TextLabel
local detailLabel: TextLabel
local coinsLabel: TextLabel
local displayedCoins = 0
local coinTween: Tween? = nil
local coinValue: NumberValue
local listeners: { (state: State) -> () } = {}
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
	-- Le sac monte dans la bande de la barre Roblox, au centre (libre),
	-- aligné sur ses boutons (décision du propriétaire, A-41).
	screenGui.IgnoreGuiInset = true

	local panel = Instance.new("Frame")
	panel.Name = "BagPanel"
	-- En haut au centre, dans la bande de la barre Roblox (décision du
	-- propriétaire, A-41). Largeur limitée à
	-- 45 % de l'écran pour réduire le recouvrement de la fenêtre du chat
	-- Roblox (en haut à gauche) quand elle est ouverte.
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.new(0.45, 0, 0, 82)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(170, 82)
	sizeLimit.MaxSize = Vector2.new(300, 82)
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

	coinsLabel = newLabel(panel, UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 60), 15)
	coinsLabel.Name = "Coins"
	coinsLabel.TextColor3 = COLOR_COINS
	-- Panneau étroit (téléphone en portrait) : réduire plutôt que tronquer.
	coinsLabel.TextScaled = true
	local coinsTextSize = Instance.new("UITextSizeConstraint")
	coinsTextSize.MinTextSize = 10
	coinsTextSize.MaxTextSize = 15
	coinsTextSize.Parent = coinsLabel

	-- Compteur animé du solde affiché (purement visuel).
	coinValue = Instance.new("NumberValue")
	coinValue.Name = "DisplayedCoins"
	coinValue.Parent = screenGui

	toastLabel = newLabel(screenGui, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 96), 22)
	toastLabel.Name = "Toast"
	toastLabel.TextTransparency = 1
	toastLabel.TextStrokeTransparency = 1
	toastLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local function renderCoins()
	local current = state
	if current == nil then
		coinsLabel.Text = ""
		return
	end
	local estimate = InventoryController.estimateSale()
	coinsLabel.Text = string.format(
		"%s %d   |   %s ~%d",
		translate("hud.coins"),
		displayedCoins,
		translate("hud.sell_value"),
		estimate
	)
end

local function render()
	local current = state
	if current == nil then
		titleLabel.Text = translate("hud.bag")
		detailLabel.Text = ""
		renderCoins()
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
	renderCoins()
end

-- Fait défiler le solde affiché jusqu'à `target` (à la hausse seulement).
local function setDisplayedCoins(target: number)
	if coinTween then
		coinTween:Cancel()
		coinTween = nil
	end
	if target <= displayedCoins then
		displayedCoins = target
		coinValue.Value = target
		renderCoins()
		return
	end
	coinValue.Value = displayedCoins
	local tween = TweenService:Create(coinValue, TweenInfo.new(COIN_COUNT_SECONDS), { Value = target })
	coinTween = tween
	tween:Play()
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
		and type(value.coins) == "number"
		and type(value.collectIntervalSeconds) == "number"
		and type(value.collectRangeStuds) == "number"
		and type(value.upgrades) == "table"
		and type(value.worlds) == "table"
		and type(value.sellMultiplier) == "number"
		and type(value.walkSpeed) == "number"
end

-- Dernier état reçu du serveur, ou nil avant le premier.
function InventoryController.getState(): State?
	return state
end

-- Valeur estimée du sac, Multiplier compris (affichage seulement : le
-- serveur recalcule le montant crédité).
function InventoryController.estimateSale(): number
	local current = state
	if current == nil then
		return 0
	end
	local base = SaleValue.quote(current.inventory.resources).total
	return SaleValue.applyMultiplier(base, current.sellMultiplier, GameConfig.Selling.maxSellMultiplier) or base
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

-- Message positif (achat ou déblocage confirmé par le serveur).
function InventoryController.showSuccess(key: string)
	showToast(translate(key), COLOR_SUCCESS)
	pulsePanel()
end

-- Retour visuel d'une vente confirmée par le serveur : seul `coinsEarned`
-- reçu du serveur est affiché, jamais l'estimation locale.
function InventoryController.showSale(coinsEarned: number)
	showToast(Localization.format("sell.gain", localPlayer.LocaleId, coinsEarned), COLOR_COINS)
	pulsePanel()
end

-- Appelé à chaque nouvel état reçu du serveur.
function InventoryController.onStateChanged(callback: (state: State) -> ())
	table.insert(listeners, callback)
end

function InventoryController.start()
	assert(not started, "InventoryController.start appelé deux fois")
	started = true
	buildInterface()
	coinValue.Changed:Connect(function(value: number)
		displayedCoins = math.floor(value + 0.5)
		renderCoins()
	end)
	render()
	Remotes.waitFor(Remotes.Name.StateUpdated).OnClientEvent:Connect(function(newState: any)
		if not isValidState(newState) then
			return
		end
		local first = state == nil
		state = newState
		render()
		if first then
			-- Arrivée : solde affiché tel quel, sans défilement.
			displayedCoins = newState.coins
			coinValue.Value = newState.coins
			renderCoins()
		else
			setDisplayedCoins(newState.coins)
		end
		for _, callback in ipairs(listeners) do
			task.spawn(callback, newState)
		end
	end)
end

return InventoryController
