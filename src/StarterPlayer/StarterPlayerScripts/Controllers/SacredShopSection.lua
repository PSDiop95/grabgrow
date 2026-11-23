--!strict
-- Section « Reliques sacrées » de la Boutique (T10.5b, D-037, D-038), côté
-- client. Affichage seulement : unités et améliorations acquises viennent du
-- dernier état serveur (InventoryController). Le client n'envoie qu'un
-- identifiant (RequestSacredSell { resourceId } / RequestSacredUpgrade
-- { upgradeId }) ; prix, coûts et effets affichés sont lus dans
-- SacredResourceConfig et ne sont jamais une preuve.
--
-- Une carte par amélioration (une par monde), visible seulement si le joueur
-- possède des unités de la ressource du monde ou l'amélioration. Deux
-- boutons de 48 px : « Vendre » et « Utiliser ». Les deux actions sont
-- définitives : premier appui = « Confirmer ? », second appui dans les 3 s
-- = demande au serveur.
--
-- Construite dans la liste de la Boutique par UpgradeController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SacredResourceConfig = require(Shared:WaitForChild("Config"):WaitForChild("SacredResourceConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))

local SacredShopSection = {}

local RESPONSE_TIMEOUT_SECONDS = 2
local CONFIRM_SECONDS = 3
local CARD_HEIGHT = 128
local BUTTON_HEIGHT = 48
-- Nombre d'éléments de liste occupés (titre, aide, 4 cartes).
SacredShopSection.ITEM_COUNT = 2 + #SacredResourceConfig.UpgradeOrder

local COLOR_CARD = Color3.fromRGB(40, 46, 58)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_MUTED = Color3.fromRGB(170, 178, 192)
local COLOR_SACRED = Color3.fromRGB(196, 150, 255)
local COLOR_COINS = Color3.fromRGB(255, 214, 92)
local COLOR_BUY = Color3.fromRGB(76, 186, 92)
local COLOR_SELL = Color3.fromRGB(214, 150, 40)
local COLOR_DISABLED = Color3.fromRGB(80, 86, 98)
local COLOR_MAX = Color3.fromRGB(214, 168, 54)
local COLOR_CONFIRM = Color3.fromRGB(230, 110, 70)
local COLOR_SUCCESS = Color3.fromRGB(120, 230, 140)

-- Icône par amélioration (glyphe simple, aucun asset externe).
local ICONS: { [string]: string } = {
	sacred_magnet = "🌱",
	sacred_grabber = "☀",
	sacred_backpack = "❄",
	sacred_compass = "✦",
}

type Card = {
	frame: Frame,
	units: TextLabel,
	sell: TextButton,
	use: TextButton,
	stroke: UIStroke,
}

local localPlayer = Players.LocalPlayer :: Player
local requestSell: RemoteEvent
local requestUpgrade: RemoteEvent
local built = false
local started = false

local cards: { [string]: Card } = {}
local emptyLabel: TextLabel
-- Demande en attente (clé « sell:<id> » ou « use:<id> ») -> échéance.
local pendingUntil: { [string]: number } = {}
local confirmKey: string? = nil
local confirmUntil = 0

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

local function fill(key: string, values: { [string]: string }): string
	return Localization.fill(key, localPlayer.LocaleId, values)
end

local function resourceName(resourceId: string): string
	local definition = SacredResourceConfig.Resources[resourceId]
	return if definition then translate(definition.nameKey) else resourceId
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
	button.TextSize = 15
	button.TextColor3 = COLOR_TEXT
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.BorderSizePixel = 0
	button.Parent = parent
	round(button, 10)
	return button
end

local function isPending(key: string): boolean
	return os.clock() < (pendingUntil[key] or 0)
end

local function isConfirming(key: string): boolean
	return confirmKey == key and os.clock() < confirmUntil
end

local function unitsOf(state: any, resourceId: string): number
	local quantity = if state then state.inventory.resources[resourceId] else nil
	return if type(quantity) == "number" and quantity > 0 then quantity else 0
end

local function owns(state: any, upgradeId: string): boolean
	local owned = if state then state.sacredUpgrades else nil
	return type(owned) == "table" and owned[upgradeId] == true
end

function SacredShopSection.render()
	if not built then
		return
	end
	local state = InventoryController.getState()
	local visibleCount = 0
	for _, upgradeId in ipairs(SacredResourceConfig.UpgradeOrder) do
		local definition = SacredResourceConfig.Upgrades[upgradeId]
		local resource = SacredResourceConfig.Resources[definition.resourceId]
		local card = cards[upgradeId]
		local units = unitsOf(state, definition.resourceId)
		local owned = owns(state, upgradeId)
		card.frame.Visible = units > 0 or owned
		if not card.frame.Visible then
			continue
		end
		visibleCount += 1
		card.units.Text = `{resourceName(definition.resourceId)}  ·  {fill("sacred.have", { count = tostring(units) })}`
		card.stroke.Color = if owned then COLOR_MAX else COLOR_CARD

		-- Vendre : toutes les unités, valeur indicative (le serveur décide).
		local sellKey = `sell:{definition.resourceId}`
		card.sell.Visible = units > 0
		if isPending(sellKey) then
			card.sell.Text = translate("shop.pending")
			card.sell.BackgroundColor3 = COLOR_DISABLED
		elseif isConfirming(sellKey) then
			card.sell.Text = translate("sacred.confirm")
			card.sell.BackgroundColor3 = COLOR_CONFIRM
		else
			card.sell.Text = fill("sacred.sell", { coins = tostring(units * resource.sellValue) })
			card.sell.BackgroundColor3 = COLOR_SELL
		end

		-- Utiliser : coût fixe en unités du monde (R-1).
		local useKey = `use:{upgradeId}`
		if owned then
			card.use.Text = translate("sacred.active")
			card.use.BackgroundColor3 = COLOR_MAX
		elseif isPending(useKey) then
			card.use.Text = translate("shop.pending")
			card.use.BackgroundColor3 = COLOR_DISABLED
		elseif isConfirming(useKey) then
			card.use.Text = translate("sacred.confirm")
			card.use.BackgroundColor3 = COLOR_CONFIRM
		else
			card.use.Text = fill("sacred.use", { count = tostring(definition.cost) })
			card.use.BackgroundColor3 = if units >= definition.cost then COLOR_BUY else COLOR_DISABLED
		end
	end
	emptyLabel.Visible = visibleCount == 0
end

-- Premier appui : confirmation ; second appui : demande au serveur.
local function press(key: string, send: () -> ())
	if isPending(key) then
		return
	end
	if not isConfirming(key) then
		confirmKey = key
		confirmUntil = os.clock() + CONFIRM_SECONDS
		SacredShopSection.render()
		task.delay(CONFIRM_SECONDS + 0.05, SacredShopSection.render)
		return
	end
	confirmKey = nil
	pendingUntil[key] = os.clock() + RESPONSE_TIMEOUT_SECONDS
	send()
	SacredShopSection.render()
	task.delay(RESPONSE_TIMEOUT_SECONDS + 0.05, SacredShopSection.render)
end

local function flash(stroke: UIStroke, color: Color3)
	stroke.Color = color
	stroke.Thickness = 3
	task.delay(0.4, function()
		stroke.Thickness = 2
		SacredShopSection.render()
	end)
end

local function upgradeOfResource(resourceId: any): string?
	for _, upgradeId in ipairs(SacredResourceConfig.UpgradeOrder) do
		if SacredResourceConfig.Upgrades[upgradeId].resourceId == resourceId then
			return upgradeId
		end
	end
	return nil
end

local function onActionResult(result: any)
	if type(result) ~= "table" then
		return
	end
	local Code = Remotes.ResultCode
	if result.action == Remotes.Action.SacredSell then
		if type(result.resourceId) == "string" then
			pendingUntil[`sell:{result.resourceId}`] = nil
		end
		local upgradeId = upgradeOfResource(result.resourceId)
		local card = if upgradeId then cards[upgradeId] else nil
		if result.ok == true and type(result.coinsEarned) == "number" then
			-- Montant reçu du serveur, jamais l'estimation locale.
			InventoryController.showSale(result.coinsEarned)
			if card then
				flash(card.stroke, COLOR_SUCCESS)
			end
		elseif result.code == Code.NothingToSell then
			InventoryController.showMessage("sacred.nothing")
		elseif result.code == Code.InternalError or result.code == Code.ProfileNotLoaded then
			InventoryController.showMessage("sacred.failed")
		end
		SacredShopSection.render()
	elseif result.action == Remotes.Action.SacredUpgrade then
		local upgradeId = if type(result.upgradeId) == "string" then result.upgradeId else nil
		local definition = if upgradeId then SacredResourceConfig.Upgrades[upgradeId] else nil
		if upgradeId then
			pendingUntil[`use:{upgradeId}`] = nil
		end
		if result.ok == true and definition then
			InventoryController.showSuccessText(fill("sacred.upgraded", { name = translate(definition.nameKey) }))
			flash(cards[upgradeId :: string].stroke, COLOR_SUCCESS)
		elseif result.code == Code.InsufficientResources and definition then
			InventoryController.showWarningText(fill("sacred.need", {
				count = tostring(definition.cost),
				name = resourceName(definition.resourceId),
			}))
		elseif result.code == Code.MaxLevel then
			InventoryController.showMessage("shop.max_reached")
		elseif result.code == Code.InternalError or result.code == Code.ProfileNotLoaded then
			InventoryController.showMessage("sacred.failed")
		end
		SacredShopSection.render()
	end
	-- RATE_LIMITED, INVALID_TARGET : silencieux.
end

local function buildCard(list: Instance, upgradeId: string, order: number)
	local definition = SacredResourceConfig.Upgrades[upgradeId]
	local frame = Instance.new("Frame")
	frame.Name = upgradeId
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, CARD_HEIGHT)
	frame.BackgroundColor3 = COLOR_CARD
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = list
	round(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = COLOR_CARD
	stroke.Parent = frame

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 52, 0, 52)
	icon.Position = UDim2.new(0, 10, 0, 10)
	icon.BackgroundColor3 = COLOR_SACRED
	icon.Font = Enum.Font.GothamBlack
	icon.TextSize = 28
	icon.TextColor3 = COLOR_TEXT
	icon.Text = ICONS[upgradeId] or "?"
	icon.Parent = frame
	round(icon, 12)

	local name = newLabel(frame, translate(definition.nameKey), 17, COLOR_TEXT)
	name.Position = UDim2.new(0, 72, 0, 8)
	name.Size = UDim2.new(1, -82, 0, 20)

	local effect = newLabel(frame, translate(`{definition.nameKey}.desc`), 14, COLOR_COINS)
	effect.Position = UDim2.new(0, 72, 0, 30)
	effect.Size = UDim2.new(1, -82, 0, 18)

	local units = newLabel(frame, "", 13, COLOR_MUTED)
	units.Name = "Units"
	units.Position = UDim2.new(0, 72, 0, 50)
	units.Size = UDim2.new(1, -82, 0, 16)

	local sell = newButton(frame)
	sell.Name = "Sell"
	sell.AnchorPoint = Vector2.new(0, 1)
	sell.Position = UDim2.new(0, 10, 1, -10)
	sell.Size = UDim2.new(0.5, -15, 0, BUTTON_HEIGHT)
	sell.Activated:Connect(function()
		press(`sell:{definition.resourceId}`, function()
			requestSell:FireServer({ resourceId = definition.resourceId })
		end)
	end)

	local use = newButton(frame)
	use.Name = "Use"
	use.AnchorPoint = Vector2.new(1, 1)
	use.Position = UDim2.new(1, -10, 1, -10)
	use.Size = UDim2.new(0.5, -15, 0, BUTTON_HEIGHT)
	use.Activated:Connect(function()
		local state = InventoryController.getState()
		if owns(state, upgradeId) then
			return
		end
		if unitsOf(state, definition.resourceId) < definition.cost then
			InventoryController.showWarningText(fill("sacred.need", {
				count = tostring(definition.cost),
				name = resourceName(definition.resourceId),
			}))
			return
		end
		press(`use:{upgradeId}`, function()
			requestUpgrade:FireServer({ upgradeId = upgradeId })
		end)
	end)

	cards[upgradeId] = { frame = frame, units = units, sell = sell, use = use, stroke = stroke }
end

-- Construit la section dans `list` à partir de l'ordre `firstOrder` ; occupe
-- SacredShopSection.ITEM_COUNT positions.
function SacredShopSection.build(list: Instance, firstOrder: number)
	assert(not built, "SacredShopSection.build appelé deux fois")
	local title = newLabel(list, translate("shop.sacred"), 18, COLOR_SACRED)
	title.LayoutOrder = firstOrder
	title.Size = UDim2.new(1, -8, 0, 30)

	emptyLabel = newLabel(list, translate("sacred.none"), 13, COLOR_MUTED)
	emptyLabel.LayoutOrder = firstOrder + 1
	emptyLabel.Size = UDim2.new(1, -8, 0, 22)
	emptyLabel.TextWrapped = true

	for index, upgradeId in ipairs(SacredResourceConfig.UpgradeOrder) do
		buildCard(list, upgradeId, firstOrder + 1 + index)
	end
	built = true
end

function SacredShopSection.start()
	assert(built, "SacredShopSection.start avant build")
	assert(not started, "SacredShopSection.start appelé deux fois")
	started = true
	requestSell = Remotes.waitFor(Remotes.Name.RequestSacredSell)
	requestUpgrade = Remotes.waitFor(Remotes.Name.RequestSacredUpgrade)
	Remotes.waitFor(Remotes.Name.ActionResult).OnClientEvent:Connect(onActionResult)
	InventoryController.onStateChanged(function()
		SacredShopSection.render()
	end)
	SacredShopSection.render()
end

return SacredShopSection
