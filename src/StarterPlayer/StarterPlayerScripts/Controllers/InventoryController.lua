--!strict
-- Affichage du sac : miroir de l'état envoyé par le serveur (StateUpdated).
-- Aucune autorité : le client n'ajoute jamais de ressource lui-même.
--
-- Interface construite par code, en haut au centre : hors des zones du
-- stick et du saut.
-- T3 : solde de Coins, valeur vendable estimée (SaleValue, affichage
-- seulement) et confirmation du montant crédité par le serveur.
-- T4 : l'estimation applique le Multiplier reçu du serveur (affichage) ;
-- niveaux, mondes et vitesse sont relayés aux autres contrôleurs.
-- T5.1 : sac en pastille puis en barre (BagDisplay : états et couleurs
-- déduits de `used` / `capacity` du serveur), ligne Coins mise en avant,
-- invitation à vendre quand le sac est plein.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local ResourceConfig = require(Shared:WaitForChild("Config"):WaitForChild("ResourceConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local SaleValue = require(Shared:WaitForChild("Util"):WaitForChild("SaleValue"))
local BagDisplay = require(Shared:WaitForChild("Util"):WaitForChild("BagDisplay"))

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
	-- T5.3 : statistiques persistantes pour le guidage (lecture seule).
	-- Facultatif : absent, le guidage reste masqué.
	progress: { resourcesCollected: number, sales: number, coinsSpent: number }?,
}

local COLOR_PANEL = Color3.fromRGB(24, 28, 36)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_MUTED = Color3.fromRGB(190, 198, 210)
local COLOR_TRACK = Color3.fromRGB(60, 66, 78)
local COLOR_GAIN = Color3.fromRGB(190, 255, 170)
local COLOR_WARNING = Color3.fromRGB(255, 200, 90)
local COLOR_COINS = Color3.fromRGB(255, 214, 92)
local COLOR_COIN_EDGE = Color3.fromRGB(196, 140, 36)
local COLOR_SUCCESS = Color3.fromRGB(120, 230, 140)
local COIN_COUNT_SECONDS = 0.5
local TOAST_HOLD_SECONDS = 0.7
local TOAST_FADE_SECONDS = 0.4

-- Panneau du HUD (T5.1), hauteur fixe, trois lignes :
--   1. sac : pastille compacte (sac presque vide) qui s'élargit en barre ;
--   2. Coins et valeur estimée du sac ;
--   3. détail des ressources, ou invitation à vendre quand le sac est plein.
local PANEL_HEIGHT = 82
local PANEL_PADDING = 8
local BAG_ROW_TOP = 6
local BAG_ROW_HEIGHT = 26
local COINS_ROW_TOP = 36
local COINS_ROW_HEIGHT = 22
local DETAIL_ROW_TOP = 60
local DETAIL_ROW_HEIGHT = 16
-- Largeur de la pastille compacte (px) ; la barre prend toute la ligne.
local BAG_COMPACT_WIDTH = 132
local BAG_ICON = "🎒"
-- Largeur réservée à l'icône, à gauche de la piste (px).
local BAG_ICON_SPACE = 28
-- Remplissage : coins modérément arrondis et largeur minimale, pour rester
-- une barre et non une pastille ronde à faible remplissage (A-30).
local FILL_CORNER = 6
local FILL_MIN_WIDTH = 6
local FILL_INSET = 3
local BAG_RESIZE_SECONDS = 0.25
local BAG_FILL_SECONDS = 0.15
local ALERT_STROKE = 2

local localPlayer = Players.LocalPlayer :: Player
local state: State? = nil
local started = false

local bagTrack: Frame
local bagStroke: UIStroke
local bagLabel: TextLabel
local barFill: Frame
local detailLabel: TextLabel
local coinsLabel: TextLabel
local valueLabel: TextLabel
local displayedCoins = 0
local coinTween: Tween? = nil
local coinValue: NumberValue
local listeners: { (state: State) -> () } = {}
local panelScale: UIScale
local toastLabel: TextLabel
local toastTween: Tween? = nil
local toastToken = 0
-- Animations du sac en cours : annulées avant d'en lancer d'autres.
local trackTween: Tween? = nil
local fillTween: Tween? = nil
local lastCompact: boolean? = nil
local lastTier: string? = nil
-- T5.2 : cible des pièces de la vente et mise en évidence du solde.
local coinIcon: Frame
local coinsRowScale: UIScale
local coinsHighlightToken = 0

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

local function toColor(rgb: BagDisplay.Rgb): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
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

-- Panneau étroit : texte réduit plutôt que tronqué.
local function fitText(label: TextLabel, minSize: number, maxSize: number)
	label.TextScaled = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
end

local function round(instance: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = instance
end

local function newRow(panel: Frame, name: string, top: number, height: number): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, PANEL_PADDING, 0, top)
	row.Size = UDim2.new(1, -2 * PANEL_PADDING, 0, height)
	row.Parent = panel
	return row
end

-- Ligne 1 : le sac. La piste est centrée et s'élargit depuis son centre :
-- passage pastille -> barre sans déplacement brusque.
local function buildBagRow(panel: Frame)
	local row = newRow(panel, "BagRow", BAG_ROW_TOP, BAG_ROW_HEIGHT)

	bagTrack = Instance.new("Frame")
	bagTrack.Name = "Bar"
	bagTrack.AnchorPoint = Vector2.new(0.5, 0)
	bagTrack.Position = UDim2.new(0.5, 0, 0, 0)
	bagTrack.Size = UDim2.new(0, BAG_COMPACT_WIDTH, 1, 0)
	bagTrack.BackgroundColor3 = COLOR_TRACK
	bagTrack.BorderSizePixel = 0
	bagTrack.Parent = row
	round(bagTrack, UDim.new(0, FILL_CORNER + FILL_INSET))

	bagStroke = Instance.new("UIStroke")
	bagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bagStroke.Thickness = 0
	bagStroke.Parent = bagTrack

	-- Zone du remplissage, en retrait de la piste, à droite de l'icône (le
	-- début de la barre ne passe pas sous le glyphe).
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.new(0, BAG_ICON_SPACE, 0, FILL_INSET)
	inner.Size = UDim2.new(1, -BAG_ICON_SPACE - FILL_INSET, 1, -2 * FILL_INSET)
	inner.Parent = bagTrack

	barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = toColor(BagDisplay.Colors.green)
	barFill.BorderSizePixel = 0
	barFill.Visible = false
	barFill.Parent = inner
	round(barFill, UDim.new(0, FILL_CORNER))
	local fillLimit = Instance.new("UISizeConstraint")
	fillLimit.MinSize = Vector2.new(FILL_MIN_WIDTH, 0)
	fillLimit.Parent = barFill

	local icon = newLabel(bagTrack, UDim2.new(0, 24, 1, 0), UDim2.new(0, 4, 0, 0), 16)
	icon.Name = "Icon"
	icon.Text = BAG_ICON
	icon.TextTruncate = Enum.TextTruncate.None
	icon.ZIndex = 2

	-- Compteur lisible sur toutes les couleurs de remplissage (contour noir).
	bagLabel = newLabel(bagTrack, UDim2.new(1, -BAG_ICON_SPACE - 8, 1, -4), UDim2.new(0, BAG_ICON_SPACE, 0, 2), 15)
	bagLabel.Name = "Title"
	bagLabel.ZIndex = 2
	bagLabel.TextStrokeTransparency = 0.35
	bagLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	fitText(bagLabel, 10, 15)
end

-- Ligne 2 : Coins (information principale) et valeur estimée du sac.
local function buildCoinsRow(panel: Frame)
	local row = newRow(panel, "CoinsRow", COINS_ROW_TOP, COINS_ROW_HEIGHT)

	-- Pièce dessinée (forme simple, aucun asset).
	local coin = Instance.new("Frame")
	coin.Name = "CoinIcon"
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 2, 0.5, 0)
	coin.Size = UDim2.new(0, 16, 0, 16)
	coin.BackgroundColor3 = COLOR_COINS
	coin.BorderSizePixel = 0
	coin.Parent = row
	round(coin, UDim.new(1, 0))
	local edge = Instance.new("UIStroke")
	edge.Color = COLOR_COIN_EDGE
	edge.Thickness = 2
	edge.Parent = coin

	coinIcon = coin
	-- T5.2 : impulsion de la ligne Coins après une vente confirmée.
	coinsRowScale = Instance.new("UIScale")
	coinsRowScale.Parent = row

	coinsLabel = newLabel(row, UDim2.new(0.55, -24, 1, 0), UDim2.new(0, 24, 0, 0), 18)
	coinsLabel.Name = "Coins"
	coinsLabel.Font = Enum.Font.GothamBlack
	coinsLabel.TextColor3 = COLOR_COINS
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	fitText(coinsLabel, 11, 18)

	valueLabel = newLabel(row, UDim2.new(0.45, 0, 1, 0), UDim2.new(0.55, 0, 0, 0), 13)
	valueLabel.Name = "SellValue"
	valueLabel.Font = Enum.Font.GothamMedium
	valueLabel.TextColor3 = COLOR_MUTED
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	fitText(valueLabel, 9, 13)
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
	panel.Size = UDim2.new(0.45, 0, 0, PANEL_HEIGHT)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(170, PANEL_HEIGHT)
	sizeLimit.MaxSize = Vector2.new(300, PANEL_HEIGHT)
	sizeLimit.Parent = panel

	round(panel, UDim.new(0, 12))

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	buildBagRow(panel)
	buildCoinsRow(panel)

	detailLabel = newLabel(
		panel,
		UDim2.new(1, -2 * PANEL_PADDING, 0, DETAIL_ROW_HEIGHT),
		UDim2.new(0, PANEL_PADDING, 0, DETAIL_ROW_TOP),
		13
	)
	detailLabel.Name = "Detail"
	detailLabel.Font = Enum.Font.GothamMedium
	fitText(detailLabel, 9, 13)

	-- Compteur animé du solde affiché (purement visuel).
	coinValue = Instance.new("NumberValue")
	coinValue.Name = "DisplayedCoins"
	coinValue.Parent = screenGui

	-- Messages dans un ScreenGui à part, au-dessus de la boutique
	-- (DisplayOrder 6) : le résultat d'un achat reste visible panneau ouvert.
	local notifications = Instance.new("ScreenGui")
	notifications.Name = "NotificationsUI"
	notifications.ResetOnSpawn = false
	notifications.DisplayOrder = 10
	notifications.IgnoreGuiInset = true
	notifications.Parent = localPlayer:WaitForChild("PlayerGui")

	toastLabel = newLabel(notifications, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 96), 22)
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
		valueLabel.Text = ""
		return
	end
	coinsLabel.Text = `{displayedCoins} {translate("hud.coins")}`
	valueLabel.Text = `{translate("hud.sell_value")} ~{InventoryController.estimateSale()}`
end

local function pulsePanel()
	panelScale.Scale = 1.08
	TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Pastille ou barre : la piste ne change de largeur qu'au changement de
-- forme, jamais à chaque collecte.
local function setCompact(compact: boolean, animate: boolean)
	if compact == lastCompact then
		return
	end
	lastCompact = compact
	local goal = if compact then UDim2.new(0, BAG_COMPACT_WIDTH, 1, 0) else UDim2.new(1, 0, 1, 0)
	if trackTween then
		trackTween:Cancel()
		trackTween = nil
	end
	if not animate then
		bagTrack.Size = goal
		return
	end
	local tween = TweenService:Create(
		bagTrack,
		TweenInfo.new(BAG_RESIZE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = goal }
	)
	trackTween = tween
	tween:Play()
end

local function renderBag(inventory: { used: number, capacity: number, resources: { [string]: number } }, animate: boolean)
	local view = BagDisplay.view(inventory.used, inventory.capacity)
	bagLabel.Text = `{translate(view.labelKey or "hud.bag")}  {inventory.used} / {inventory.capacity}`
	-- Toujours blanc, contour noir : lisible sur vert, jaune, orange et rouge.
	bagLabel.TextColor3 = COLOR_TEXT

	setCompact(view.compact, animate)

	local fillColor = toColor(view.fill)
	local fillSize = UDim2.new(view.ratio, 0, 1, 0)
	barFill.Visible = view.ratio > 0
	if fillTween then
		fillTween:Cancel()
		fillTween = nil
	end
	if animate then
		local tween = TweenService:Create(
			barFill,
			TweenInfo.new(BAG_FILL_SECONDS),
			{ Size = fillSize, BackgroundColor3 = fillColor }
		)
		fillTween = tween
		tween:Play()
	else
		barFill.Size = fillSize
		barFill.BackgroundColor3 = fillColor
	end

	-- Alerte : contour de la couleur du remplissage ; jamais la couleur
	-- seule, le mot d'état l'accompagne toujours (GDD 12.4).
	bagStroke.Thickness = if view.alert then ALERT_STROKE else 0
	bagStroke.Color = fillColor

	if view.hintKey then
		detailLabel.Text = translate(view.hintKey)
		detailLabel.TextColor3 = COLOR_WARNING
		detailLabel.Font = Enum.Font.GothamBold
	else
		-- T8 (D-021) : 20 ressources configurées ; seules celles présentes
		-- dans le sac sont listées. Sac vide : ressources du monde de départ
		-- à 0 (affichage MVP inchangé).
		local parts: { string } = {}
		for _, resourceId in ipairs(resourceOrder) do
			local quantity = inventory.resources[resourceId] or 0
			if quantity > 0 then
				table.insert(parts, `{translate(ResourceConfig[resourceId].displayNameKey)} {quantity}`)
			end
		end
		if #parts == 0 then
			for _, resourceId in ipairs(resourceOrder) do
				local definition = ResourceConfig[resourceId]
				if definition.worldId == GameConfig.StartingWorldId and definition.rarity == "Common" then
					table.insert(parts, `{translate(definition.displayNameKey)} 0`)
				end
			end
		end
		detailLabel.Text = table.concat(parts, "   ")
		detailLabel.TextColor3 = COLOR_TEXT
		detailLabel.Font = Enum.Font.GothamMedium
	end

	-- Entrée dans un état d'alerte : une impulsion, aucune boucle.
	if animate and view.alert and lastTier ~= nil and lastTier ~= view.tier then
		pulsePanel()
	end
	lastTier = view.tier
end

local function render(animate: boolean)
	local current = state
	if current == nil then
		bagLabel.Text = translate("hud.bag")
		detailLabel.Text = ""
		renderCoins()
		return
	end
	renderBag(current.inventory, animate)
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
	InventoryController.showSuccessText(translate(key))
end

-- Même retour, texte déjà localisé et mis en forme par l'appelant.
function InventoryController.showSuccessText(text: string)
	showToast(text, COLOR_SUCCESS)
	pulsePanel()
end

-- Retour visuel d'une vente confirmée par le serveur : seul `coinsEarned`
-- reçu du serveur est affiché, jamais l'estimation locale.
function InventoryController.showSale(coinsEarned: number)
	showToast(Localization.format("sell.gain", localPlayer.LocaleId, coinsEarned), COLOR_COINS)
	pulsePanel()
end

-- Icône de la pièce du HUD (cible de l'effet de vente, T5.2).
function InventoryController.getCoinIcon(): GuiObject
	return coinIcon
end

-- Mise en évidence temporaire du solde (T5.2) : impulsion de la ligne et
-- texte blanc qui revient à l'or. Purement visuel ; `subtle` : impulsion
-- réduite (préférence « Effets réduits »).
function InventoryController.highlightCoins(subtle: boolean)
	coinsHighlightToken += 1
	local token = coinsHighlightToken
	coinsRowScale.Scale = if subtle then 1.06 else 1.15
	TweenService:Create(coinsRowScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	coinsLabel.TextColor3 = COLOR_TEXT
	task.delay(0.15, function()
		if token ~= coinsHighlightToken then
			return
		end
		TweenService:Create(coinsLabel, TweenInfo.new(0.4), { TextColor3 = COLOR_COINS }):Play()
	end)
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
	render(false)
	Remotes.waitFor(Remotes.Name.StateUpdated).OnClientEvent:Connect(function(newState: any)
		if not isValidState(newState) then
			return
		end
		local first = state == nil
		state = newState
		-- Premier état : affiché sans animation.
		render(not first)
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
