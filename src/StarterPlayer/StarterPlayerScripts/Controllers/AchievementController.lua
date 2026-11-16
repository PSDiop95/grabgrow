--!strict
-- Affichage des succès obtenus (T7, D-020) et des premières découvertes du
-- journal de collection (T8.6, D-022). Client : affichage seulement.
--
-- Le serveur attribue les succès et crédite les Coins ; il envoie un
-- ActionResult { action = "Achievement", achievementId, coinsEarned } par
-- succès. Ce contrôleur n'affiche que ces réponses : aucun calcul, aucune
-- demande au serveur.
--
-- Bandeau court sous le message de collecte (NotificationsUI), dans une
-- file : plusieurs succès simultanés s'affichent l'un après l'autre. Le
-- son est joué par FeedbackController (FeedbackRules).
-- T8.6 : ActionResult { action = "Collect", ok, resourceType,
-- firstDiscovery = true } -> « Nouvelle découverte : X ! » dans la même
-- file, avec une autre couleur ; aucun son ajouté (le son de collecte reste
-- le seul).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AchievementConfig = require(Shared:WaitForChild("Config"):WaitForChild("AchievementConfig"))
local ResourceConfig = require(Shared:WaitForChild("Config"):WaitForChild("ResourceConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))

local AchievementController = {}

local HOLD_SECONDS = 3
local FADE_SECONDS = 0.35
-- Sous le message de collecte (InventoryController : y 96, hauteur 30).
local BANNER_TOP = 132
local BANNER_HEIGHT = 34
local BANNER_MAX_WIDTH = 440
local MAX_QUEUE = 6
local COLOR_PANEL = Color3.fromRGB(24, 28, 36)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)
local COLOR_ACCENT = Color3.fromRGB(255, 214, 92)
local COLOR_DISCOVERY = Color3.fromRGB(150, 215, 255)

type Message = { text: string, color: Color3 }

local localPlayer = Players.LocalPlayer :: Player
local banner: Frame
local label: TextLabel
local stroke: UIStroke
local queue: { Message } = {}
local showing = false
local started = false

local function build()
	local notifications = localPlayer:WaitForChild("PlayerGui"):WaitForChild("NotificationsUI")

	banner = Instance.new("Frame")
	banner.Name = "AchievementBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, BANNER_TOP)
	banner.Size = UDim2.new(0.9, 0, 0, BANNER_HEIGHT)
	banner.BackgroundColor3 = COLOR_PANEL
	banner.BackgroundTransparency = 1
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.Parent = notifications

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(BANNER_MAX_WIDTH, BANNER_HEIGHT)
	limit.Parent = banner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = banner
	stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_ACCENT
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = banner

	label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 10, 0, 0)
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = COLOR_TEXT
	label.TextScaled = true
	label.TextTransparency = 1
	label.Parent = banner
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MinTextSize = 10
	textLimit.MaxTextSize = 18
	textLimit.Parent = label
end

local function setVisible(alpha: number, seconds: number): Tween?
	local info = TweenInfo.new(seconds)
	if seconds <= 0 then
		banner.BackgroundTransparency = 0.15 + 0.85 * (1 - alpha)
		label.TextTransparency = 1 - alpha
		stroke.Transparency = 0.2 + 0.8 * (1 - alpha)
		return nil
	end
	TweenService:Create(banner, info, { BackgroundTransparency = 0.15 + 0.85 * (1 - alpha) }):Play()
	TweenService:Create(stroke, info, { Transparency = 0.2 + 0.8 * (1 - alpha) }):Play()
	local tween = TweenService:Create(label, info, { TextTransparency = 1 - alpha })
	tween:Play()
	return tween
end

local function showNext()
	if showing then
		return
	end
	local message = table.remove(queue, 1)
	if message == nil then
		banner.Visible = false
		return
	end
	showing = true
	label.Text = message.text
	stroke.Color = message.color
	banner.Visible = true
	setVisible(1, 0)
	task.delay(HOLD_SECONDS, function()
		local tween = setVisible(0, FADE_SECONDS)
		if tween then
			tween.Completed:Wait()
		end
		showing = false
		showNext()
	end)
end

local function enqueue(message: Message)
	if #queue >= MAX_QUEUE then
		table.remove(queue, 1)
	end
	table.insert(queue, message)
	showNext()
end

-- T8.6 : première découverte confirmée par le serveur.
local function onDiscovery(result: any)
	local definition = if type(result.resourceType) == "string" then ResourceConfig[result.resourceType] else nil
	if definition == nil then
		return
	end
	local text = Localization.fill("journal.new_discovery", localPlayer.LocaleId, {
		name = Localization.get(definition.displayNameKey, localPlayer.LocaleId),
	})
	enqueue({ text = text, color = COLOR_DISCOVERY })
end

local function onActionResult(result: any)
	if type(result) ~= "table" or result.ok ~= true then
		return
	end
	if result.action == Remotes.Action.Collect and result.firstDiscovery == true then
		onDiscovery(result)
		return
	end
	if result.action ~= Remotes.Action.Achievement then
		return
	end
	local definition = AchievementConfig[result.achievementId]
	local coins = result.coinsEarned
	if definition == nil or type(coins) ~= "number" or coins < 1 or coins % 1 ~= 0 then
		return
	end
	local text = Localization.fill("achievement.unlocked", localPlayer.LocaleId, {
		name = Localization.get(definition.nameKey, localPlayer.LocaleId),
		coins = string.format("%d", coins),
	})
	enqueue({ text = `🏆 {text}`, color = COLOR_ACCENT })
end

function AchievementController.start()
	assert(not started, "AchievementController.start appelé deux fois")
	started = true
	build()
	Remotes.waitFor(Remotes.Name.ActionResult).OnClientEvent:Connect(onActionResult)
end

return AchievementController
