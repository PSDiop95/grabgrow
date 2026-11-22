--!strict
-- Retours audio et visuels du client (T5.2). Purement sensoriel : aucune
-- règle de jeu, aucun envoi au serveur, aucune valeur économique calculée.
--
-- Sources (événements existants, aucun nouveau RemoteEvent) :
--   * ActionResult (réponses du serveur) -> FeedbackRules.fromResult ;
--   * StateUpdated, via InventoryController.onStateChanged -> entrée dans
--     les états « presque plein » / « plein » du sac (BagDisplay).
-- Un retour positif n'est produit que pour une réponse `ok == true` ; le
-- montant de vente affiché est `coinsEarned` reçu du serveur.
--
-- Effets temporaires uniquement, détruits après usage : éclat de collecte
-- (copie de toutes les pièces du nœud via NodeVisuals, T10.1 V-01 ;
-- particules prêtées par ResourceVFXController, T10.2), pièces vers le solde, anneau autour de l'icône
-- d'amélioration, confettis de déblocage. Le Magnet garde son
-- anneau de portée (RangeRing, A-40) : aucun second anneau ici.
--
-- Préférences (D-6) : « Son » et « Effets réduits », dans la boutique
-- (section Paramètres). Stockées en attributs du ScreenGui FeedbackFX
-- (SoundEnabled, ReducedEffects), pour la session seulement : aucune
-- persistance sans changement serveur (voir docs/phases/T5_PREFLIGHT.md).
-- Compteurs de contrôle (Studio) : attributs Sound_*, Visual_*, Duplicates,
-- LastSaleAmount du même ScreenGui.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedbackConfig = require(Shared:WaitForChild("Config"):WaitForChild("FeedbackConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local BagDisplay = require(Shared:WaitForChild("Util"):WaitForChild("BagDisplay"))
local FeedbackRules = require(Shared:WaitForChild("Util"):WaitForChild("FeedbackRules"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))
local NodeVisuals = require(script.Parent:WaitForChild("NodeVisuals"))
local ResourceVFXController = require(script.Parent:WaitForChild("ResourceVFXController"))

local FeedbackController = {}

local FX_GUI_NAME = "FeedbackFX"
local EFFECTS_FOLDER_NAME = "ClientFeedbackEffects"
local NODE_FOLDER_NAME = "ResourceNodes"
local SHOP_GUI_NAME = "ShopUI"
local SHOP_WAIT_SECONDS = 15
local SETTINGS_ORDER = 1000

local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_CARD = Color3.fromRGB(40, 46, 58)
local COLOR_ON = Color3.fromRGB(76, 186, 92)
local COLOR_OFF = Color3.fromRGB(80, 86, 98)
local COLOR_COIN = Color3.fromRGB(255, 214, 92)
local COLOR_COIN_EDGE = Color3.fromRGB(196, 140, 36)
local COLOR_GLOW = Color3.fromRGB(255, 226, 120)
local COLOR_LEVEL_UP = Color3.fromRGB(120, 230, 140)
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 214, 92),
	Color3.fromRGB(120, 230, 140),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(245, 138, 52),
	Color3.fromRGB(230, 120, 200),
}

local localPlayer = Players.LocalPlayer :: Player
local started = false
local random = Random.new()

local fxGui: ScreenGui
local effectsFolder: Folder
local masterGroup: SoundGroup
local sfxGroup: SoundGroup
local voices: { [string]: { Sound } } = {}
local nextVoice: { [string]: number } = {}
local deduper = FeedbackRules.newDeduper()
local collectBudget = FeedbackRules.newBudget(FeedbackConfig.MaxCollectEffects)
local sellBusy = false
local lastTier: string? = nil
local settingsRefreshers: { () -> () } = {}

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

local function prefs(): FeedbackRules.Prefs
	return {
		soundEnabled = fxGui:GetAttribute("SoundEnabled") ~= false,
		reducedEffects = fxGui:GetAttribute("ReducedEffects") == true,
	}
end

local function bump(attribute: string)
	local value = fxGui:GetAttribute(attribute)
	fxGui:SetAttribute(attribute, (if type(value) == "number" then value else 0) + 1)
end

-- Appareil modeste ou mouvement réduit demandé dans Roblox : « Effets
-- réduits » activé par défaut (le joueur peut le désactiver).
local function detectReducedDefault(): boolean
	local okMotion, reducedMotion = pcall(function(): any
		return (GuiService :: any).ReducedMotionEnabled
	end)
	if okMotion and reducedMotion == true then
		return true
	end
	local okQuality, quality = pcall(function(): any
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if okQuality and typeof(quality) == "EnumItem" then
		local level = quality :: EnumItem
		return level ~= Enum.SavedQualitySetting.Automatic and level.Value <= 3
	end
	return false
end

-- Audio ---------------------------------------------------------------

local function buildAudio()
	-- SoundService/SFX (CLAUDE.md 6.2) ; groupes Master (global) > SFX.
	masterGroup = Instance.new("SoundGroup")
	masterGroup.Name = "GrabGrowMaster"
	masterGroup.Volume = 1
	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "SFX"
	sfxGroup.Volume = FeedbackConfig.EffectsVolume
	sfxGroup.Parent = masterGroup
	masterGroup.Parent = SoundService

	local folder = Instance.new("Folder")
	folder.Name = "SFX"
	for key, definition in pairs(FeedbackConfig.Sounds) do
		local list: { Sound } = {}
		for index = 1, definition.voices do
			local sound = Instance.new("Sound")
			sound.Name = `{key}_{index}`
			sound.SoundId = `rbxassetid://{definition.assetId}`
			sound.Volume = definition.volume
			sound.SoundGroup = sfxGroup
			sound.Parent = folder
			table.insert(list, sound)
		end
		voices[key] = list
	end
	folder.Parent = SoundService
end

local function applySoundPreference()
	local current = prefs()
	masterGroup.Volume = if current.soundEnabled then 1 else 0
	if not current.soundEnabled then
		for _, list in pairs(voices) do
			for _, sound in ipairs(list) do
				sound:Stop()
			end
		end
	end
end

-- Joue un son existant (aucune instance créée) ; rien si le son est coupé.
local function playSound(key: string)
	local current = prefs()
	local list = voices[key]
	local definition = FeedbackConfig.Sounds[key]
	if not current.soundEnabled or list == nil or definition == nil then
		return
	end
	local index = (nextVoice[key] or 0) % #list + 1
	nextVoice[key] = index
	local sound = list[index]
	-- Volume relatif au groupe SFX ; FeedbackRules.soundVolume donne le
	-- volume final (groupe compris).
	sound.Volume = FeedbackRules.soundVolume(key, current) / FeedbackConfig.EffectsVolume
	sound.PlaybackSpeed = 1 + random:NextNumber(-definition.pitchJitter, definition.pitchJitter)
	sound.TimePosition = 0
	sound:Play()
	bump(`Sound_{key}`)
end

-- Effets visuels -------------------------------------------------------

local function characterRoot(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Centre d'un objet GUI dans le repère de FeedbackFX.
local function centerInFx(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize / 2 - fxGui.AbsolutePosition
end

local function collectEffect(cue: FeedbackRules.Cue)
	local folder = Workspace:FindFirstChild(NODE_FOLDER_NAME)
	local node = if folder and cue.id then folder:FindFirstChild(cue.id) else nil
	if node == nil or not node:IsA("BasePart") then
		return
	end
	if not collectBudget:tryAcquire() then
		return
	end
	local current = prefs()
	local settings = FeedbackConfig.Collect
	local seconds = FeedbackRules.pick(settings.seconds, settings.reducedSeconds, current)

	-- Copie locale de toutes les pièces visibles du nœud (Part + détails, ou
	-- modèle importé : T10.1, V-01) ; le serveur a déjà masqué le nœud.
	local flash = NodeVisuals.createFlash(node, effectsFolder, function(color: Color3): Color3
		return color:Lerp(COLOR_TEXT, 0.3)
	end)
	if flash == nil then
		collectBudget:release()
		return
	end

	-- Particules : éclat réutilisé (pool), dimensionné par rareté et orienté
	-- vers le joueur (T10.2, ResourceVFXController).
	ResourceVFXController.playCollect(node, flash.center, flash.color)

	-- Mouvement vers le joueur (GDD 13.4), absent en effets réduits.
	local startCFrame = flash.center
	local goalCFrame = startCFrame
	local root = characterRoot()
	if root and not current.reducedEffects then
		local goal = startCFrame.Position:Lerp(root.Position + Vector3.new(0, 1.5, 0), settings.travelFraction)
		goalCFrame = CFrame.new(goal) * startCFrame.Rotation
	end
	local shrink = if current.reducedEffects then 0.5 else 0.2
	local driver = Instance.new("NumberValue")
	driver.Changed:Connect(function(alpha: number)
		flash.setPose(startCFrame:Lerp(goalCFrame, alpha), 1 + (shrink - 1) * alpha, alpha)
	end)
	TweenService:Create(driver, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Value = 1,
	}):Play()
	bump("Visual_collect")

	task.delay(seconds + 0.05, function()
		driver:Destroy()
		flash.destroy()
		collectBudget:release()
	end)
end

local function sellEffect(cue: FeedbackRules.Cue)
	local current = prefs()
	fxGui:SetAttribute("LastSaleAmount", cue.amount)
	if sellBusy then
		-- Une seule volée de pièces à la fois ; le solde est mis en évidence.
		InventoryController.highlightCoins(current.reducedEffects)
		return
	end
	sellBusy = true
	local settings = FeedbackConfig.Sell
	local count = FeedbackRules.pick(settings.coins, settings.reducedCoins, current)
	local flight = FeedbackRules.pick(settings.flightSeconds, settings.reducedFlightSeconds, current)
	local target = centerInFx(InventoryController.getCoinIcon())

	-- Départ : le personnage à l'écran, sinon le centre de l'écran.
	local start = fxGui.AbsoluteSize / 2
	local camera = Workspace.CurrentCamera
	local root = characterRoot()
	if camera and root then
		local point, visible = camera:WorldToViewportPoint(root.Position)
		if visible then
			-- Viewport et FeedbackFX (IgnoreGuiInset) : même origine, le haut
			-- de l'écran ; AbsolutePosition des GUI est, elle, décalée de
			-- l'encart (d'où la soustraction dans centerInFx seulement).
			start = Vector2.new(point.X, point.Y)
		end
	end

	for index = 1, count do
		local coin = Instance.new("Frame")
		coin.Name = "SaleCoin"
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Size = UDim2.fromOffset(settings.coinSize, settings.coinSize)
		coin.BackgroundColor3 = COLOR_COIN
		coin.BorderSizePixel = 0
		local spread = Vector2.new(random:NextNumber(-30, 30), random:NextNumber(-20, 10))
		coin.Position = UDim2.fromOffset(start.X + spread.X, start.Y + spread.Y)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = coin
		local edge = Instance.new("UIStroke")
		edge.Color = COLOR_COIN_EDGE
		edge.Thickness = 2
		edge.Parent = coin
		coin.Visible = false
		coin.Parent = fxGui
		task.delay((index - 1) * settings.staggerSeconds, function()
			coin.Visible = true
			local tween = TweenService:Create(
				coin,
				TweenInfo.new(flight, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(10, 10) }
			)
			tween.Completed:Once(function()
				coin:Destroy()
			end)
			tween:Play()
		end)
	end
	bump("Visual_sell")

	task.delay(flight + (count - 1) * settings.staggerSeconds, function()
		InventoryController.highlightCoins(current.reducedEffects)
		sellBusy = false
	end)
end

local function shopList(): Instance?
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local shop = if playerGui then playerGui:FindFirstChild(SHOP_GUI_NAME) else nil
	local panel = if shop then shop:FindFirstChild("ShopPanel") else nil
	return if panel then panel:FindFirstChild("List") else nil
end

local function upgradeEffect(cue: FeedbackRules.Cue)
	local list = shopList()
	local card = if list and cue.id then list:FindFirstChild(cue.id) else nil
	local icon = if card then card:FindFirstChild("Icon") else nil
	if card == nil or icon == nil or not icon:IsA("GuiObject") then
		return
	end
	local current = prefs()
	local settings = FeedbackConfig.Upgrade
	local seconds = FeedbackRules.pick(settings.seconds, settings.reducedSeconds, current)

	-- Impulsion de l'icône.
	local scale = icon:FindFirstChild("FeedbackScale")
	if scale == nil then
		local created = Instance.new("UIScale")
		created.Name = "FeedbackScale"
		created.Parent = icon
		scale = created
	end
	local iconScale = scale :: UIScale
	iconScale.Scale = FeedbackRules.pick(settings.pulseScale, settings.reducedPulseScale, current)
	TweenService:Create(iconScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- Éclat : anneau qui s'agrandit autour de l'icône (effets normaux).
	if not current.reducedEffects then
		local ring = Instance.new("Frame")
		ring.Name = "UpgradeGlow"
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.new(
			icon.Position.X.Scale,
			icon.Position.X.Offset + icon.Size.X.Offset / 2,
			icon.Position.Y.Scale,
			icon.Position.Y.Offset + icon.Size.Y.Offset / 2
		)
		ring.Size = icon.Size
		ring.BackgroundTransparency = 1
		ring.ZIndex = icon.ZIndex + 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.Color = COLOR_GLOW
		stroke.Thickness = 3
		stroke.Parent = ring
		ring.Parent = card
		local grow = settings.ringGrowPixels
		TweenService:Create(ring, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(icon.Size.X.Offset + grow, icon.Size.Y.Offset + grow),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		task.delay(seconds + 0.05, function()
			ring:Destroy()
		end)
	end

	-- Nouveau niveau mis en évidence (texte vert qui revient à sa couleur).
	local level = card:FindFirstChild("Level")
	if level and level:IsA("TextLabel") then
		local base = level:GetAttribute("BaseColor")
		if typeof(base) ~= "Color3" then
			base = level.TextColor3
			level:SetAttribute("BaseColor", base)
		end
		level.TextColor3 = COLOR_LEVEL_UP
		TweenService:Create(level, TweenInfo.new(0.8), { TextColor3 = base :: Color3 }):Play()
	end
	bump("Visual_upgrade")
end

local function worldEffect(cue: FeedbackRules.Cue)
	local current = prefs()
	local settings = FeedbackConfig.World
	local seconds = FeedbackRules.pick(settings.seconds, settings.reducedSeconds, current)
	local list = shopList()
	local row = if list and cue.id then list:FindFirstChild(cue.id) else nil

	-- Mise en évidence de la ligne du monde.
	local origin = fxGui.AbsoluteSize / 2
	if row and row:IsA("GuiObject") then
		local glow = Instance.new("UIStroke")
		glow.Name = "UnlockGlow"
		glow.Color = COLOR_GLOW
		glow.Thickness = 3
		glow.Parent = row
		TweenService:Create(glow, TweenInfo.new(seconds * 1.5), { Transparency = 1 }):Play()
		task.delay(seconds * 1.5 + 0.05, function()
			glow:Destroy()
		end)
		if row.AbsoluteSize.X > 0 then
			origin = centerInFx(row)
		end
	end

	-- Confettis courts depuis la ligne (ou le centre de l'écran).
	local count = FeedbackRules.pick(settings.confetti, settings.reducedConfetti, current)
	for index = 1, count do
		local piece = Instance.new("Frame")
		piece.Name = "Confetti"
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromOffset(8, 14)
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLORS[(index - 1) % #CONFETTI_COLORS + 1]
		piece.Rotation = random:NextNumber(0, 180)
		piece.Position = UDim2.fromOffset(origin.X, origin.Y)
		piece.Parent = fxGui
		local angle = random:NextNumber(0, 2 * math.pi)
		local distance = random:NextNumber(0.5, 1) * settings.spreadPixels
		local goal = origin + Vector2.new(math.cos(angle) * distance, math.sin(angle) * distance * 0.6 + 30)
		TweenService:Create(piece, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(goal.X, goal.Y),
			Rotation = piece.Rotation + random:NextNumber(90, 270),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(seconds + 0.05, function()
			piece:Destroy()
		end)
	end
	bump("Visual_world")
end

local VISUALS: { [string]: (cue: FeedbackRules.Cue) -> () } = {
	collect = collectEffect,
	sell = sellEffect,
	upgrade = upgradeEffect,
	world = worldEffect,
}

local function dispatch(cues: { FeedbackRules.Cue })
	local now = os.clock()
	for _, cue in ipairs(cues) do
		if not deduper:accept(cue.key, now) then
			bump("Duplicates")
			continue
		end
		local sound = cue.sound
		if sound then
			if cue.delay > 0 then
				task.delay(cue.delay, playSound, sound)
			else
				playSound(sound)
			end
		end
		local visual = if cue.visual then VISUALS[cue.visual] else nil
		if visual then
			visual(cue)
		end
	end
end

-- Paramètres (section de la boutique) ---------------------------------------

local function buildToggle(list: Instance, order: number, labelKey: string, attribute: string, invert: boolean)
	local row = Instance.new("Frame")
	row.Name = `Setting_{attribute}`
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 60)
	row.BackgroundColor3 = COLOR_CARD
	row.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = row

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 12, 0, 0)
	label.Size = UDim2.new(1, -152, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = COLOR_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = translate(labelKey)
	label.Parent = row

	local button = Instance.new("TextButton")
	button.Name = "Toggle"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.new(0, 124, 0, 44)
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 16
	button.TextColor3 = COLOR_TEXT
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Parent = row
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = button

	-- « Son » : attribut vrai = activé ; « Effets réduits » : idem.
	local function isOn(): boolean
		local value = fxGui:GetAttribute(attribute)
		return if invert then value ~= false else value == true
	end
	local function refresh()
		local on = isOn()
		button.Text = translate(if on then "settings.on" else "settings.off")
		button.BackgroundColor3 = if on then COLOR_ON else COLOR_OFF
	end
	button.Activated:Connect(function()
		fxGui:SetAttribute(attribute, not isOn())
	end)
	table.insert(settingsRefreshers, refresh)
	refresh()
	row.Parent = list
end

local function buildSettings()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local shop = playerGui:WaitForChild(SHOP_GUI_NAME, SHOP_WAIT_SECONDS)
	local panel = if shop then shop:WaitForChild("ShopPanel", SHOP_WAIT_SECONDS) else nil
	local list = if panel then panel:WaitForChild("List", SHOP_WAIT_SECONDS) else nil
	if list == nil then
		warn("[Feedback] ShopUI introuvable : paramètres audio non affichés")
		return
	end
	local title = Instance.new("TextLabel")
	title.Name = "SettingsTitle"
	title.LayoutOrder = SETTINGS_ORDER
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -8, 0, 30)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = COLOR_TEXT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = translate("settings.title")
	title.Parent = list
	buildToggle(list, SETTINGS_ORDER + 1, "settings.sound", "SoundEnabled", true)
	buildToggle(list, SETTINGS_ORDER + 2, "settings.reduced_effects", "ReducedEffects", false)
end

-- Démarrage ------------------------------------------------------------

function FeedbackController.start()
	assert(not started, "FeedbackController.start appelé deux fois")
	started = true

	fxGui = Instance.new("ScreenGui")
	fxGui.Name = FX_GUI_NAME
	fxGui.ResetOnSpawn = false
	fxGui.IgnoreGuiInset = true
	-- Au-dessus de la boutique (6), sous les messages (10).
	fxGui.DisplayOrder = 9
	fxGui:SetAttribute("SoundEnabled", true)
	fxGui:SetAttribute("ReducedEffects", detectReducedDefault())
	fxGui.Parent = localPlayer:WaitForChild("PlayerGui")

	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = EFFECTS_FOLDER_NAME
	effectsFolder.Parent = Workspace

	buildAudio()
	applySoundPreference()
	fxGui:GetAttributeChangedSignal("SoundEnabled"):Connect(function()
		applySoundPreference()
		for _, refresh in ipairs(settingsRefreshers) do
			refresh()
		end
	end)
	fxGui:GetAttributeChangedSignal("ReducedEffects"):Connect(function()
		for _, refresh in ipairs(settingsRefreshers) do
			refresh()
		end
	end)

	Remotes.waitFor(Remotes.Name.ActionResult).OnClientEvent:Connect(function(result: any)
		dispatch(FeedbackRules.fromResult(result))
	end)
	InventoryController.onStateChanged(function(state)
		local tier = BagDisplay.view(state.inventory.used, state.inventory.capacity).tier
		local cues = FeedbackRules.fromBagTier(lastTier, tier)
		lastTier = tier
		dispatch(cues)
	end)

	task.spawn(buildSettings)
end

return FeedbackController
