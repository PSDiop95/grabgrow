--!strict
-- Vente côté client (T3) : interaction avec les stations, estimation et
-- retour visuel. Le client ne calcule jamais le montant crédité : il envoie
-- l'identifiant de zone (RequestSell) et affiche la réponse du serveur.
--
-- Entrées (ProximityPrompt local, un par zone) :
--   * PC      : touche F (E reste la collecte) ;
--   * mobile  : toucher le bouton du prompt ;
--   * manette : bouton Y (X reste la collecte).
-- Le prompt n'apparaît qu'à portée : c'est l'indication de proximité. Il
-- affiche la valeur estimée (Multiplier compris) ou « Sac vide ». Une étiquette
-- « Vente » flotte au-dessus de chaque station, visible de loin et masquée
-- tant que le prompt est affiché (A-34).
--
-- Zones : BaseParts de Workspace.SellZones portant l'attribut SellZoneId
-- (créées dans Studio, voir Systems/SellZones côté serveur).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))

local SellController = {}

local ZONE_FOLDER_NAME = "SellZones"
local ZONE_ATTRIBUTE = "SellZoneId"
local ZONE_FOLDER_TIMEOUT_SECONDS = 30
-- Sans réponse du serveur après ce délai, une nouvelle demande est permise.
local RESPONSE_TIMEOUT_SECONDS = 2
local SELL_KEY = Enum.KeyCode.F
local SELL_GAMEPAD_BUTTON = Enum.KeyCode.ButtonY
local LABEL_MAX_DISTANCE_STUDS = 120

local localPlayer = Players.LocalPlayer :: Player
local requestSell: RemoteEvent
local prompts: { [BasePart]: ProximityPrompt } = {}
local pendingUntil = 0
local started = false

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

-- Texte du prompt d'après le dernier état serveur (estimation seulement).
local function promptObjectText(): string
	local state = InventoryController.getState()
	if state == nil then
		return ""
	end
	local estimate = InventoryController.estimateSale()
	if estimate <= 0 then
		return translate("sell.empty")
	end
	return Localization.format("sell.estimate", localPlayer.LocaleId, estimate)
end

local function refreshPrompts()
	local text = promptObjectText()
	for _, prompt in pairs(prompts) do
		prompt.ObjectText = text
	end
end

local function requestSale(zoneId: string)
	local now = os.clock()
	if now < pendingUntil then
		return
	end
	pendingUntil = now + RESPONSE_TIMEOUT_SECONDS
	requestSell:FireServer({ sellZoneId = zoneId })
end

local function addZone(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local existing: ProximityPrompt? = prompts[part]
	if existing ~= nil then
		return
	end
	local zoneId = part:GetAttribute(ZONE_ATTRIBUTE)
	if type(zoneId) ~= "string" or zoneId == "" then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = translate("sell.action")
	prompt.ObjectText = promptObjectText()
	prompt.KeyboardKeyCode = SELL_KEY
	prompt.GamepadKeyCode = SELL_GAMEPAD_BUTTON
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	-- Le serveur accepte jusqu'à cette distance plus une marge.
	prompt.MaxActivationDistance = GameConfig.Selling.interactRangeStuds
	prompt.Triggered:Connect(function()
		requestSale(zoneId)
	end)
	prompt.Parent = part
	prompts[part] = prompt

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SellLabel"
	billboard.Size = UDim2.new(0, 160, 0, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	billboard.MaxDistance = LABEL_MAX_DISTANCE_STUDS
	billboard.AlwaysOnTop = false
	billboard.Adornee = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 214, 92)
	label.TextStrokeTransparency = 0.2
	label.Text = translate("sell.station")
	label.Parent = billboard
	billboard.Parent = localPlayer:WaitForChild("PlayerGui")

	-- A-34 : de près, l'étiquette se projette derrière le panneau du sac.
	-- À portée, le prompt identifie déjà la station : l'étiquette se masque
	-- tant qu'il est affiché.
	prompt.PromptShown:Connect(function()
		billboard.Enabled = false
	end)
	prompt.PromptHidden:Connect(function()
		billboard.Enabled = true
	end)

	part.AncestryChanged:Connect(function()
		if part.Parent == nil then
			prompts[part] = nil
			billboard:Destroy()
		end
	end)
end

local function onActionResult(result: any)
	if type(result) ~= "table" or result.action ~= Remotes.Action.Sell then
		return
	end
	pendingUntil = 0
	local code = result.code
	if result.ok == true then
		if type(result.coinsEarned) == "number" then
			InventoryController.showSale(result.coinsEarned)
		end
	elseif code == Remotes.ResultCode.NothingToSell then
		InventoryController.showMessage("sell.nothing")
	elseif code == Remotes.ResultCode.TooFar then
		InventoryController.showMessage("sell.too_far")
	elseif code == Remotes.ResultCode.InternalError or code == Remotes.ResultCode.ProfileNotLoaded then
		InventoryController.showMessage("sell.failed")
	end
	-- RATE_LIMITED, INVALID_TARGET, NO_CHARACTER : silencieux.
end

function SellController.start()
	assert(not started, "SellController.start appelé deux fois")
	started = true

	requestSell = Remotes.waitFor(Remotes.Name.RequestSell)
	Remotes.waitFor(Remotes.Name.ActionResult).OnClientEvent:Connect(onActionResult)
	InventoryController.onStateChanged(refreshPrompts)

	local folder = Workspace:WaitForChild(ZONE_FOLDER_NAME, ZONE_FOLDER_TIMEOUT_SECONDS)
	if folder == nil then
		warn(`[Sell] Workspace.{ZONE_FOLDER_NAME} introuvable : vente désactivée`)
		return
	end
	folder.DescendantAdded:Connect(addZone)
	for _, descendant in ipairs(folder:GetDescendants()) do
		addZone(descendant)
	end
end

return SellController
