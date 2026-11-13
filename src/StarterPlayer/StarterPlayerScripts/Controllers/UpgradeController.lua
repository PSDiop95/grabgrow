--!strict
-- Boutique d'améliorations et progression des mondes (T4), côté client.
-- Affichage seulement : niveaux, solde et mondes viennent du dernier état
-- serveur (InventoryController). Le client n'envoie qu'un identifiant
-- (RequestUpgrade { upgradeId } / RequestUnlockWorld { worldId }) ; prix,
-- niveaux et effets affichés sont lus dans les configurations partagées
-- et ne sont jamais une preuve.
--
-- Entrées :
--   * mobile  : bouton « Boutique » placé juste au-dessus du bouton
--               « Prendre » (lui-même au-dessus du saut), ou à sa gauche
--               si la hauteur manque ; boutons d'achat de 48 px de haut ;
--   * PC      : touche B ou clic ;
--   * manette : croix haut pour ouvrir/fermer, navigation native des
--               boutons, B pour fermer.
-- Déblocage d'un monde : premier appui = « Confirmer ? », second appui
-- dans les 3 s = demande au serveur.
--
-- Interface minimale construite par code ; refonte prévue en T5.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local UpgradeConfig = require(Config:WaitForChild("UpgradeConfig"))
local WorldConfig = require(Config:WaitForChild("WorldConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local UpgradeMath = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeMath"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))
local RangeRing = require(script.Parent:WaitForChild("RangeRing"))

local UpgradeController = {}

local TOGGLE_KEY = Enum.KeyCode.B
local TOGGLE_GAMEPAD = Enum.KeyCode.DPadUp
-- Sans réponse du serveur après ce délai, une nouvelle demande est permise.
local RESPONSE_TIMEOUT_SECONDS = 2
local CONFIRM_SECONDS = 3
local SHOP_BUTTON_WIDTH = 96
local SHOP_BUTTON_HEIGHT = 52
-- Écart avec le bouton « Prendre » et marge minimale aux bords (px).
local SHOP_BUTTON_GAP = 12
local SHOP_BUTTON_EDGE = 8
-- Sans bouton « Prendre » visible (PC, manette) : bord droit, au-dessus du milieu.
local SHOP_BUTTON_FALLBACK = UDim2.new(1, -12, 0.38, 0)
-- Panneau ouvert : écart sous le panneau du sac et marge au bas de la zone
-- sûre (px).
local SHOP_PANEL_GAP = 8
local SHOP_PANEL_BOTTOM_MARGIN = 8
local GRAB_HUD_NAME = "CollectionHUD"
local GRAB_BUTTON_NAME = "GrabButton"
local GRAB_WAIT_SECONDS = 10
local INVENTORY_HUD_NAME = "InventoryHUD"
local BAG_PANEL_NAME = "BagPanel"

local COLOR_PANEL = Color3.fromRGB(24, 28, 36)
local COLOR_CARD = Color3.fromRGB(40, 46, 58)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_MUTED = Color3.fromRGB(170, 178, 192)
local COLOR_BUY = Color3.fromRGB(76, 186, 92)
local COLOR_DISABLED = Color3.fromRGB(80, 86, 98)
local COLOR_MAX = Color3.fromRGB(214, 168, 54)
local COLOR_COINS = Color3.fromRGB(255, 214, 92)
local COLOR_WARNING = Color3.fromRGB(255, 140, 120)
local COLOR_SUCCESS = Color3.fromRGB(120, 230, 140)

-- Icône par amélioration (glyphe simple, aucun asset externe).
local ICONS: { [string]: { glyph: string, color: Color3 } } = {
	Backpack = { glyph = "🎒", color = Color3.fromRGB(96, 160, 230) },
	Grabber = { glyph = "✋", color = Color3.fromRGB(232, 150, 70) },
	Magnet = { glyph = "🧲", color = Color3.fromRGB(220, 80, 90) },
	Boots = { glyph = "👢", color = Color3.fromRGB(150, 110, 80) },
	Multiplier = { glyph = "×", color = Color3.fromRGB(214, 168, 54) },
}

type Card = {
	level: TextLabel,
	effect: TextLabel,
	button: TextButton,
	stroke: UIStroke,
}

type WorldRow = {
	status: TextLabel,
	button: TextButton,
}

local localPlayer = Players.LocalPlayer :: Player
local requestUpgrade: RemoteEvent
local requestUnlock: RemoteEvent
local started = false

local panel: Frame
local shopButton: TextButton
local badge: Frame
local headerLabel: TextLabel
local cards: { [string]: Card } = {}
local worldRows: { [string]: WorldRow } = {}
local upgradeIds: { string } = UpgradeMath.ids()
local worldIds: { string } = {}

-- Demande en attente de réponse : identifiant -> échéance.
local pendingUntil: { [string]: number } = {}
-- Monde en attente de confirmation et échéance.
local confirmWorldId: string? = nil
local confirmUntil = 0

for worldId in pairs(WorldConfig) do
	table.insert(worldIds, worldId)
end
table.sort(worldIds, function(a: string, b: string): boolean
	return WorldConfig[a].order < WorldConfig[b].order
end)

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

local function formatKey(key: string, value: number): string
	return Localization.format(key, localPlayer.LocaleId, value)
end

-- Nombre lisible : entier tel quel, sinon deux décimales au plus ; virgule
-- décimale en français.
local function formatNumber(value: number): string
	local text = if value % 1 == 0 then string.format("%d", value) else string.format("%.2f", value)
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
	end
	if Localization.languageOf(localPlayer.LocaleId) == "fr" then
		text = string.gsub(text, "%.", ",")
	end
	return text
end

-- Unité affichée par statistique (clés de localisation).
local UNIT_KEYS: { [string]: string } = {
	collectIntervalSeconds = "unit.seconds",
	collectRangeStuds = "unit.studs",
	walkSpeed = "unit.speed",
	sellMultiplier = "unit.multiplier",
}

-- Effet affiché d'un niveau, avec son unité.
local function formatEffect(upgradeId: string, level: number): string
	local value = UpgradeMath.valueAt(upgradeId, level)
	if value == nil then
		return "-"
	end
	local unitKey = UNIT_KEYS[UpgradeConfig[upgradeId].stat]
	if unitKey == nil then
		return formatNumber(value)
	end
	return Localization.fill(unitKey, localPlayer.LocaleId, { value = formatNumber(value) })
end

-- Message d'achat « valeur avant → valeur après » (A-40), unité à la fin :
-- « Portée 12 → 14 studs ». `level` est le nouveau niveau renvoyé par le
-- serveur ; les valeurs viennent de UpgradeConfig. Nil si incohérent.
local function gainText(upgradeId: string, level: number): string?
	local definition = UpgradeConfig[upgradeId]
	local before = UpgradeMath.valueAt(upgradeId, level - 1)
	if definition == nil or before == nil or UpgradeMath.valueAt(upgradeId, level) == nil then
		return nil
	end
	local from = if definition.stat == "sellMultiplier"
		then Localization.fill("unit.multiplier", localPlayer.LocaleId, { value = formatNumber(before) })
		else formatNumber(before)
	return Localization.fill(`{definition.displayNameKey}.gain`, localPlayer.LocaleId, {
		from = from,
		to = formatEffect(upgradeId, level),
	})
end

local function newLabel(parent: Instance, text: string, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = parent
	return label
end

local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function newButton(parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 16
	button.TextColor3 = COLOR_TEXT
	button.TextScaled = false
	button.BorderSizePixel = 0
	button.Parent = parent
	round(button, 10)
	return button
end

local function setOpen(open: boolean)
	panel.Visible = open
	confirmWorldId = nil
	if open and UserInputService.GamepadEnabled then
		local first = cards[upgradeIds[1]]
		if first then
			GuiService.SelectedObject = first.button
		end
	elseif not open and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject = nil
	end
end

local function isPending(id: string): boolean
	return os.clock() < (pendingUntil[id] or 0)
end

-- Rendu complet à partir du dernier état serveur.
local function render()
	local state = InventoryController.getState()
	local coins = if state then state.coins else 0
	local affordable = false

	for _, upgradeId in ipairs(upgradeIds) do
		local card = cards[upgradeId]
		local level = if state then state.upgrades[upgradeId] else nil
		if level == nil then
			card.level.Text = ""
			card.effect.Text = ""
			card.button.Text = translate("shop.pending")
			card.button.BackgroundColor3 = COLOR_DISABLED
			continue
		end
		local cost = UpgradeMath.nextCost(upgradeId, level)
		if cost == nil then
			card.level.Text = `{formatKey("shop.level", level)}  ·  {translate("shop.max")}`
			card.effect.Text = formatEffect(upgradeId, level)
			card.button.Text = translate("shop.max")
			card.button.BackgroundColor3 = COLOR_MAX
			card.stroke.Color = COLOR_MAX
		else
			card.level.Text = `{formatKey("shop.level", level)} → {formatKey("shop.level", level + 1)}`
			card.effect.Text = `{formatEffect(upgradeId, level)} → {formatEffect(upgradeId, level + 1)}`
			card.stroke.Color = COLOR_CARD
			if isPending(upgradeId) then
				card.button.Text = translate("shop.pending")
				card.button.BackgroundColor3 = COLOR_DISABLED
			elseif coins >= cost then
				affordable = true
				card.button.Text = formatKey("shop.price", cost)
				card.button.BackgroundColor3 = COLOR_BUY
			else
				card.button.Text = formatKey("shop.need", cost - coins)
				card.button.BackgroundColor3 = COLOR_DISABLED
			end
		end
	end

	local unlockedCount = 0
	for _, worldId in ipairs(worldIds) do
		local world = WorldConfig[worldId]
		local row = worldRows[worldId]
		local unlocked = state ~= nil and state.worlds[worldId] == true
		if unlocked then
			unlockedCount += 1
			row.status.Text = if world.order == 1
				then translate("world.unlocked")
				else `{translate("world.unlocked")}  ·  {translate("world.coming_soon")}`
			row.status.TextColor3 = COLOR_SUCCESS
			row.button.Visible = false
			continue
		end
		row.button.Visible = true
		local previousUnlocked = true
		for _, otherId in ipairs(worldIds) do
			if WorldConfig[otherId].order == world.order - 1 then
				previousUnlocked = state ~= nil and state.worlds[otherId] == true
			end
		end
		local backpack = if state then state.upgrades.Backpack or 0 else 0
		local ready = previousUnlocked and backpack >= world.requiredBackpackLevel and coins >= world.unlockCost
		if not previousUnlocked then
			row.status.Text = translate("world.requires_previous")
			row.status.TextColor3 = COLOR_MUTED
		else
			row.status.Text =
				`{formatKey("world.requires_backpack", world.requiredBackpackLevel)}  ·  {formatKey("shop.price", world.unlockCost)}`
			row.status.TextColor3 = if ready then COLOR_TEXT else COLOR_WARNING
		end
		if isPending(worldId) then
			row.button.Text = translate("shop.pending")
			row.button.BackgroundColor3 = COLOR_DISABLED
		elseif confirmWorldId == worldId and os.clock() < confirmUntil then
			row.button.Text = translate("world.confirm")
			row.button.BackgroundColor3 = COLOR_MAX
		else
			row.button.Text = translate("world.unlock")
			row.button.BackgroundColor3 = if ready then COLOR_BUY else COLOR_DISABLED
		end
	end

	headerLabel.Text = `{translate("hud.coins")} {coins}   |   {translate("hud.worlds")} {unlockedCount}/{#worldIds}`
	badge.Visible = affordable
end

local function requestPurchase(upgradeId: string)
	if isPending(upgradeId) then
		return
	end
	pendingUntil[upgradeId] = os.clock() + RESPONSE_TIMEOUT_SECONDS
	requestUpgrade:FireServer({ upgradeId = upgradeId })
	render()
	-- Si le serveur ne répond pas, le bouton redevient utilisable.
	task.delay(RESPONSE_TIMEOUT_SECONDS + 0.05, render)
end

local function requestWorld(worldId: string)
	if isPending(worldId) then
		return
	end
	if confirmWorldId ~= worldId or os.clock() >= confirmUntil then
		confirmWorldId = worldId
		confirmUntil = os.clock() + CONFIRM_SECONDS
		render()
		task.delay(CONFIRM_SECONDS + 0.05, render)
		return
	end
	confirmWorldId = nil
	pendingUntil[worldId] = os.clock() + RESPONSE_TIMEOUT_SECONDS
	requestUnlock:FireServer({ worldId = worldId })
	render()
	task.delay(RESPONSE_TIMEOUT_SECONDS + 0.05, render)
end

local function flash(stroke: UIStroke, color: Color3)
	stroke.Color = color
	stroke.Thickness = 3
	task.delay(0.4, function()
		stroke.Thickness = 2
		render()
	end)
end

local function onActionResult(result: any)
	if type(result) ~= "table" then
		return
	end
	local code = result.code
	if result.action == Remotes.Action.Upgrade then
		if type(result.upgradeId) == "string" then
			pendingUntil[result.upgradeId] = nil
		end
		local card = if type(result.upgradeId) == "string" then cards[result.upgradeId] else nil
		if result.ok == true then
			local level = result.level
			local text = if type(result.upgradeId) == "string" and type(level) == "number"
				then gainText(result.upgradeId, level)
				else nil
			if text then
				InventoryController.showSuccessText(text)
			else
				InventoryController.showSuccess("shop.bought")
			end
			if result.upgradeId == "Magnet" and type(level) == "number" then
				local range = UpgradeMath.valueAt("Magnet", level)
				if range then
					RangeRing.show(range)
				end
			end
			if card then
				flash(card.stroke, COLOR_SUCCESS)
			end
		elseif code == Remotes.ResultCode.InsufficientFunds then
			InventoryController.showMessage("shop.insufficient")
		elseif code == Remotes.ResultCode.MaxLevel then
			InventoryController.showMessage("shop.max_reached")
		elseif code == Remotes.ResultCode.InternalError or code == Remotes.ResultCode.ProfileNotLoaded then
			InventoryController.showMessage("shop.failed")
			if card then
				flash(card.stroke, COLOR_WARNING)
			end
		end
		render()
	elseif result.action == Remotes.Action.UnlockWorld then
		if type(result.worldId) == "string" then
			pendingUntil[result.worldId] = nil
		end
		if result.ok == true then
			-- T5.2 : message nommé ; effet et son par FeedbackController.
			local world = if type(result.worldId) == "string" then WorldConfig[result.worldId] else nil
			if world then
				InventoryController.showSuccessText(Localization.fill("world.unlocked_named", localPlayer.LocaleId, {
					world = translate(world.displayNameKey),
				}))
			else
				InventoryController.showSuccess("world.unlocked_toast")
			end
		elseif code == Remotes.ResultCode.InsufficientFunds then
			InventoryController.showMessage("shop.insufficient")
		elseif code == Remotes.ResultCode.RequirementNotMet then
			InventoryController.showMessage("world.locked")
		elseif code == Remotes.ResultCode.InternalError or code == Remotes.ResultCode.ProfileNotLoaded then
			InventoryController.showMessage("world.failed")
		end
		render()
	end
	-- RATE_LIMITED, INVALID_TARGET : silencieux.
end

local function buildCard(list: Instance, upgradeId: string, order: number)
	local card = Instance.new("Frame")
	card.Name = upgradeId
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 72)
	card.BackgroundColor3 = COLOR_CARD
	card.BorderSizePixel = 0
	card.Parent = list
	round(card, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = COLOR_CARD
	stroke.Parent = card

	local iconInfo = ICONS[upgradeId] or { glyph = "?", color = COLOR_DISABLED }
	local icon = Instance.new("TextLabel")
	-- Nom lu par FeedbackController (éclat à l'achat, T5.2).
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 52, 0, 52)
	icon.Position = UDim2.new(0, 10, 0.5, -26)
	icon.BackgroundColor3 = iconInfo.color
	icon.Font = Enum.Font.GothamBlack
	icon.TextSize = 28
	icon.TextColor3 = COLOR_TEXT
	icon.Text = iconInfo.glyph
	icon.Parent = card
	round(icon, 12)

	local name = newLabel(card, translate(UpgradeConfig[upgradeId].displayNameKey), 17, COLOR_TEXT)
	name.Position = UDim2.new(0, 72, 0, 8)
	name.Size = UDim2.new(1, -212, 0, 20)

	local level = newLabel(card, "", 13, COLOR_MUTED)
	level.Name = "Level"
	level.Position = UDim2.new(0, 72, 0, 29)
	level.Size = UDim2.new(1, -212, 0, 16)

	local effect = newLabel(card, "", 14, COLOR_COINS)
	effect.Position = UDim2.new(0, 72, 0, 47)
	effect.Size = UDim2.new(1, -212, 0, 18)

	local button = newButton(card)
	button.Name = "Buy"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.new(0, 124, 0, 48)
	button.Activated:Connect(function()
		requestPurchase(upgradeId)
	end)

	cards[upgradeId] = { level = level, effect = effect, button = button, stroke = stroke }
end

local function buildWorldRow(list: Instance, worldId: string, order: number)
	local row = Instance.new("Frame")
	row.Name = worldId
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 60)
	row.BackgroundColor3 = COLOR_CARD
	row.BorderSizePixel = 0
	row.Parent = list
	round(row, 10)

	local name = newLabel(row, translate(WorldConfig[worldId].displayNameKey), 16, COLOR_TEXT)
	name.Position = UDim2.new(0, 12, 0, 8)
	name.Size = UDim2.new(1, -152, 0, 20)

	local status = newLabel(row, "", 13, COLOR_MUTED)
	status.Position = UDim2.new(0, 12, 0, 32)
	status.Size = UDim2.new(1, -152, 0, 18)

	local button = newButton(row)
	button.Name = "Unlock"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.new(0, 124, 0, 44)
	button.Activated:Connect(function()
		requestWorld(worldId)
	end)

	worldRows[worldId] = { status = status, button = button }
end

local function buildInterface(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 6

	-- Bouton d'ouverture : bord droit, au-dessus du milieu (le saut et le
	-- bouton Grab occupent le bas à droite).
	shopButton = newButton(screenGui)
	shopButton.Name = "ShopButton"
	shopButton.AnchorPoint = Vector2.new(1, 0.5)
	shopButton.Position = SHOP_BUTTON_FALLBACK
	shopButton.Size = UDim2.new(0, SHOP_BUTTON_WIDTH, 0, SHOP_BUTTON_HEIGHT)
	shopButton.BackgroundColor3 = COLOR_PANEL
	shopButton.BackgroundTransparency = 0.15
	shopButton.TextColor3 = COLOR_COINS
	local hint = if UserInputService.TouchEnabled then "" else ` [{TOGGLE_KEY.Name}]`
	shopButton.Text = `{translate("shop.open")}{hint}`
	shopButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)

	-- Pastille : au moins une amélioration achetable.
	badge = Instance.new("Frame")
	badge.Name = "Affordable"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.new(0, 14, 0, 14)
	badge.BackgroundColor3 = COLOR_BUY
	badge.BorderSizePixel = 0
	badge.Visible = false
	badge.Parent = shopButton
	round(badge, 7)

	panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	-- Centré ; T5.1 : recentré sous le panneau du sac par avoidBagPanel.
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

	local title = newLabel(panel, translate("shop.title"), 20, COLOR_TEXT)
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -90, 0, 24)

	headerLabel = newLabel(panel, "", 14, COLOR_COINS)
	headerLabel.Position = UDim2.new(0, 16, 0, 36)
	headerLabel.Size = UDim2.new(1, -90, 0, 18)

	local close = newButton(panel)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.new(0, 64, 0, 44)
	close.BackgroundColor3 = COLOR_CARD
	close.Text = "X"
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.new(0, 12, 0, 62)
	list.Size = UDim2.new(1, -24, 1, -72)
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

	for index, upgradeId in ipairs(upgradeIds) do
		buildCard(list, upgradeId, index)
	end
	local worldsTitle = newLabel(list, translate("shop.worlds"), 18, COLOR_TEXT)
	worldsTitle.LayoutOrder = #upgradeIds + 1
	worldsTitle.Size = UDim2.new(1, -8, 0, 30)
	for index, worldId in ipairs(worldIds) do
		buildWorldRow(list, worldId, #upgradeIds + 1 + index)
	end

	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	return screenGui
end

-- Mobile : le bouton « Prendre » suit le bouton de saut (A-35). Le bouton
-- Boutique se place au-dessus de lui, ou à sa gauche si la hauteur manque
-- ou si le panneau du sac gêne (paysage), sans jamais le chevaucher.
-- Recalcul par événements seulement.
local function followGrabButton(screenGui: ScreenGui)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild(GRAB_HUD_NAME, GRAB_WAIT_SECONDS)
	local grab = if hud then hud:WaitForChild(GRAB_BUTTON_NAME, GRAB_WAIT_SECONDS) else nil
	if grab == nil or not grab:IsA("GuiObject") then
		return
	end
	local grabButton = grab :: GuiObject
	-- Panneau du sac (en haut au centre) : à éviter aussi. Facultatif.
	local inventoryHud = playerGui:WaitForChild(INVENTORY_HUD_NAME, GRAB_WAIT_SECONDS)
	local bagInstance = if inventoryHud then inventoryHud:WaitForChild(BAG_PANEL_NAME, GRAB_WAIT_SECONDS) else nil
	local bagPanel: GuiObject? = if bagInstance and bagInstance:IsA("GuiObject") then bagInstance else nil

	-- Le bouton, centré en `x` et posé au-dessus de `bottom`, toucherait-il
	-- le panneau du sac (écart compris) ?
	local function hitsBag(x: number, bottom: number, origin: Vector2): boolean
		if bagPanel == nil or not bagPanel.Visible then
			return false
		end
		local bagTopLeft = bagPanel.AbsolutePosition - origin
		local bagBottomRight = bagTopLeft + bagPanel.AbsoluteSize
		local left = x - SHOP_BUTTON_WIDTH / 2
		local right = x + SHOP_BUTTON_WIDTH / 2
		local top = bottom - SHOP_BUTTON_HEIGHT - SHOP_BUTTON_GAP
		return left < bagBottomRight.X and bagTopLeft.X < right and top < bagBottomRight.Y and bagTopLeft.Y < bottom
	end

	local function place()
		if not grabButton.Visible then
			shopButton.AnchorPoint = Vector2.new(1, 0.5)
			shopButton.Position = SHOP_BUTTON_FALLBACK
			return
		end
		local origin = screenGui.AbsolutePosition
		local screen = screenGui.AbsoluteSize
		local topLeft = grabButton.AbsolutePosition - origin
		local size = grabButton.AbsoluteSize
		local centerX = topLeft.X + size.X / 2
		local aboveTop = topLeft.Y - SHOP_BUTTON_GAP - SHOP_BUTTON_HEIGHT
		local x = math.clamp(
			centerX,
			SHOP_BUTTON_WIDTH / 2 + SHOP_BUTTON_EDGE,
			screen.X - SHOP_BUTTON_WIDTH / 2 - SHOP_BUTTON_EDGE
		)
		if aboveTop >= SHOP_BUTTON_EDGE and not hitsBag(x, topLeft.Y - SHOP_BUTTON_GAP, origin) then
			-- Au-dessus, centré sur « Prendre », sans sortir de l'écran.
			shopButton.AnchorPoint = Vector2.new(0.5, 1)
			shopButton.Position = UDim2.fromOffset(x, topLeft.Y - SHOP_BUTTON_GAP)
		else
			-- À gauche, aligné sur le centre vertical de « Prendre ».
			shopButton.AnchorPoint = Vector2.new(1, 0.5)
			shopButton.Position = UDim2.fromOffset(topLeft.X - SHOP_BUTTON_GAP, topLeft.Y + size.Y / 2)
		end
	end

	grabButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	grabButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	grabButton:GetPropertyChangedSignal("Visible"):Connect(place)
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
end

-- T5.1 : le panneau ouvert ne recouvre pas le panneau du sac (dessiné dans
-- la bande de la barre Roblox, A-41) : il occupe la zone sûre située sous
-- le sac, centré dans cette zone. Recalcul par événements seulement ; la
-- taille maximale (UISizeConstraint) reste celle de T4.
local function avoidBagPanel(screenGui: ScreenGui)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local inventoryHud = playerGui:WaitForChild(INVENTORY_HUD_NAME, GRAB_WAIT_SECONDS)
	local bagInstance = if inventoryHud then inventoryHud:WaitForChild(BAG_PANEL_NAME, GRAB_WAIT_SECONDS) else nil
	if bagInstance == nil or not bagInstance:IsA("GuiObject") then
		return
	end
	local bagPanel = bagInstance :: GuiObject
	local bagScale = bagPanel:FindFirstChildWhichIsA("UIScale")

	local function fit()
		-- Bas du sac hors impulsion (UIScale) : pas de mouvement du panneau.
		local scale = if bagScale and bagScale.Scale > 0 then bagScale.Scale else 1
		local bagBottom = bagPanel.AbsolutePosition.Y + bagPanel.AbsoluteSize.Y / scale
		local top = math.max(math.ceil(bagBottom - screenGui.AbsolutePosition.Y) + SHOP_PANEL_GAP, 0)
		local reserved = top + SHOP_PANEL_BOTTOM_MARGIN
		panel.Size = UDim2.new(0.9, 0, 1, -reserved)
		panel.Position = UDim2.new(0.5, 0, 0.5, math.floor((top - SHOP_PANEL_BOTTOM_MARGIN) / 2))
	end

	bagPanel:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	screenGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
	fit()
end

function UpgradeController.start()
	assert(not started, "UpgradeController.start appelé deux fois")
	started = true

	requestUpgrade = Remotes.waitFor(Remotes.Name.RequestUpgrade)
	requestUnlock = Remotes.waitFor(Remotes.Name.RequestUnlockWorld)
	local screenGui = buildInterface()
	render()
	task.spawn(followGrabButton, screenGui)
	task.spawn(avoidBagPanel, screenGui)

	Remotes.waitFor(Remotes.Name.ActionResult).OnClientEvent:Connect(onActionResult)
	InventoryController.onStateChanged(function()
		render()
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == TOGGLE_GAMEPAD then
			setOpen(not panel.Visible)
		elseif processed then
			return
		elseif input.KeyCode == TOGGLE_KEY then
			setOpen(not panel.Visible)
		elseif input.KeyCode == Enum.KeyCode.ButtonB and panel.Visible then
			setOpen(false)
		end
	end)
end

return UpgradeController
