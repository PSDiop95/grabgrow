--!strict
-- Panneau « Crédits » (anomalie A-4, option C validée le 2026-11-23).
-- Affichage seulement : aucune règle de jeu, aucun envoi au serveur.
--
-- Entrée : ligne « Crédits » dans la section Paramètres de la Boutique
-- (sous Son et Effets réduits, FeedbackController). Le panneau liste les
-- attributions de CreditsConfig, défilable, bouton Fermer de 48 px.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreditsConfig = require(Shared:WaitForChild("Config"):WaitForChild("CreditsConfig"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))

local CreditsController = {}

local GUI_NAME = "CreditsUI"
local SHOP_GUI_NAME = "ShopUI"
local SHOP_WAIT_SECONDS = 15
-- Après les réglages de FeedbackController (SETTINGS_ORDER 1000 à 1002).
local ROW_ORDER = 1003
local BUTTON_HEIGHT = 48

local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_MUTED = Color3.fromRGB(200, 206, 218)
local COLOR_CARD = Color3.fromRGB(40, 46, 58)
local COLOR_PANEL = Color3.fromRGB(28, 32, 42)
local COLOR_BUTTON = Color3.fromRGB(80, 86, 98)

local localPlayer = Players.LocalPlayer :: Player
local started = false
local panel: Frame

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function newButton(parent: Instance, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 124, 0, BUTTON_HEIGHT)
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 16
	button.TextColor3 = COLOR_TEXT
	button.BackgroundColor3 = COLOR_BUTTON
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = text
	corner(button, 10)
	button.Parent = parent
	return button
end

function CreditsController.setOpen(open: boolean)
	if panel then
		panel.Visible = open
	end
end

local function buildPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	-- Au-dessus de la Boutique (6), sous les effets (9) et les messages (10).
	gui.DisplayOrder = 8

	panel = Instance.new("Frame")
	panel.Name = "CreditsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.8)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BorderSizePixel = 0
	panel.Visible = false
	corner(panel, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 520)
	limit.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -136, 0, BUTTON_HEIGHT)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = COLOR_TEXT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = translate("credits.title")
	title.Parent = panel

	local close = newButton(panel, translate("credits.close"))
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.Activated:Connect(function()
		CreditsController.setOpen(false)
	end)

	local intro = Instance.new("TextLabel")
	intro.Name = "Intro"
	intro.BackgroundTransparency = 1
	intro.Position = UDim2.new(0, 0, 0, BUTTON_HEIGHT + 6)
	intro.Size = UDim2.new(1, 0, 0, 24)
	intro.Font = Enum.Font.GothamMedium
	intro.TextSize = 15
	intro.TextColor3 = COLOR_MUTED
	intro.TextXAlignment = Enum.TextXAlignment.Left
	intro.TextWrapped = true
	intro.Text = translate("credits.intro")
	intro.Parent = panel

	local top = BUTTON_HEIGHT + 36
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.new(0, 0, 0, top)
	list.Size = UDim2.new(1, 0, 1, -top)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	for index, line in ipairs(CreditsConfig.lines()) do
		local label = Instance.new("TextLabel")
		label.Name = `Credit_{index}`
		label.LayoutOrder = index
		label.BackgroundColor3 = COLOR_CARD
		label.BorderSizePixel = 0
		label.Size = UDim2.new(1, -10, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextColor3 = COLOR_TEXT
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		label.Text = line
		corner(label, 8)
		local labelPadding = Instance.new("UIPadding")
		labelPadding.PaddingTop = UDim.new(0, 6)
		labelPadding.PaddingBottom = UDim.new(0, 6)
		labelPadding.PaddingLeft = UDim.new(0, 8)
		labelPadding.PaddingRight = UDim.new(0, 8)
		labelPadding.Parent = label
		label.Parent = list
	end

	panel.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

-- Ligne « Crédits » de la section Paramètres de la Boutique.
local function buildShopRow()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local shop = playerGui:WaitForChild(SHOP_GUI_NAME, SHOP_WAIT_SECONDS)
	local shopPanel = if shop then shop:WaitForChild("ShopPanel", SHOP_WAIT_SECONDS) else nil
	local list = if shopPanel then shopPanel:WaitForChild("List", SHOP_WAIT_SECONDS) else nil
	if list == nil then
		warn("[Credits] ShopUI introuvable : entrée Crédits non affichée")
		return
	end
	local row = Instance.new("Frame")
	row.Name = "Setting_Credits"
	row.LayoutOrder = ROW_ORDER
	row.Size = UDim2.new(1, -8, 0, 60)
	row.BackgroundColor3 = COLOR_CARD
	row.BorderSizePixel = 0
	corner(row, 10)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 12, 0, 0)
	label.Size = UDim2.new(1, -152, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = COLOR_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = translate("settings.credits")
	label.Parent = row

	local open = newButton(row, translate("settings.credits_open"))
	open.Name = "Open"
	open.AnchorPoint = Vector2.new(1, 0.5)
	open.Position = UDim2.new(1, -10, 0.5, 0)
	open.Activated:Connect(function()
		CreditsController.setOpen(not panel.Visible)
	end)
	row.Parent = list
end

function CreditsController.start()
	assert(not started, "CreditsController.start appelé deux fois")
	started = true
	buildPanel()
	task.spawn(buildShopRow)
end

return CreditsController
