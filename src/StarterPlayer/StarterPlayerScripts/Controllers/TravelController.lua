--!strict
-- Voyage entre mondes côté client (T8.2, D-021) : portails et état affiché
-- par la boutique. Le client n'envoie qu'un identifiant
-- (TravelToWorld { worldId }) ; le serveur vérifie le déblocage, choisit le
-- point d'arrivée et déplace le personnage. Le miroir d'état ne sert qu'à
-- ne pas envoyer de demande vouée au refus et à choisir le texte affiché.
--
-- Portails : BaseParts sous Workspace.Map portant l'attribut texte
-- `PortalWorldId` (clé de WorldConfig), créés par les scripts de
-- construction des îles. Un ProximityPrompt local par portail :
--   * PC      : touche F (E reste la collecte) ;
--   * mobile  : toucher le bouton du prompt ;
--   * manette : bouton Y.
-- Île courante : point d'arrivée le plus proche (Workspace.WorldArrivals),
-- un monde « disponible » est un monde qui a un point d'arrivée.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared:WaitForChild("Config"):WaitForChild("WorldConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local TravelRules = require(Shared:WaitForChild("Util"):WaitForChild("TravelRules"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))

local TravelController = {}

local ARRIVAL_FOLDER_NAME = "WorldArrivals"
local ARRIVAL_ATTRIBUTE = "ArrivalWorldId"
local MAP_FOLDER_NAME = "Map"
local PORTAL_ATTRIBUTE = "PortalWorldId"
-- Sans réponse du serveur après ce délai, une nouvelle demande est permise.
local RESPONSE_TIMEOUT_SECONDS = 2
local PORTAL_KEY = Enum.KeyCode.F
local PORTAL_GAMEPAD_BUTTON = Enum.KeyCode.ButtonY
local PORTAL_RANGE_STUDS = 10

local State = TravelRules.State

local localPlayer = Players.LocalPlayer :: Player
local requestTravel: RemoteEvent? = nil
local started = false

local pendingUntil: { [string]: number } = {}
local arrivalParts: { [BasePart]: string } = {}
local prompts: { [BasePart]: { prompt: ProximityPrompt, worldId: string } } = {}
local listeners: { () -> () } = {}

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

local function worldName(worldId: string): string
	local world = WorldConfig[worldId]
	return if world then translate(world.displayNameKey) else worldId
end

local function arrivalPoints(): { TravelRules.Point }
	local points = {}
	for part, worldId in pairs(arrivalParts) do
		table.insert(points, { worldId = worldId, X = part.Position.X, Z = part.Position.Z })
	end
	return points
end

local function isAvailable(worldId: string): boolean
	for _, id in pairs(arrivalParts) do
		if id == worldId then
			return true
		end
	end
	return false
end

-- Monde de l'île où se trouve le personnage (nil sans personnage).
function TravelController.currentWorld(): string?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return TravelRules.currentWorld({ X = root.Position.X, Z = root.Position.Z }, arrivalPoints())
end

-- État affiché d'un monde (TravelRules.State).
function TravelController.stateOf(worldId: string): string
	local state = InventoryController.getState()
	return TravelRules.rowState({
		unlocked = state ~= nil and state.worlds[worldId] == true,
		available = isAvailable(worldId),
		current = TravelController.currentWorld() == worldId,
		pending = os.clock() < (pendingUntil[worldId] or 0),
	})
end

-- Appelé quand l'état affiché peut avoir changé (boutique).
function TravelController.onChanged(callback: () -> ())
	table.insert(listeners, callback)
end

local function refresh()
	for _, entry in pairs(prompts) do
		local state = TravelController.stateOf(entry.worldId)
		entry.prompt.ObjectText = worldName(entry.worldId)
		entry.prompt.ActionText = if state == State.Locked
			then translate("world.locked")
			elseif state == State.ComingSoon then translate("world.coming_soon")
			else translate("travel.go")
	end
	for _, callback in ipairs(listeners) do
		task.spawn(callback)
	end
end

-- Demande de voyage (portail ou boutique).
function TravelController.request(worldId: string)
	local state = TravelController.stateOf(worldId)
	if not TravelRules.shouldRequest(state) then
		local key = TravelRules.blockedMessage(state)
		if key then
			InventoryController.showMessage(key)
		end
		return
	end
	local remote = requestTravel
	if remote == nil then
		return
	end
	pendingUntil[worldId] = os.clock() + RESPONSE_TIMEOUT_SECONDS
	remote:FireServer({ worldId = worldId })
	refresh()
	task.delay(RESPONSE_TIMEOUT_SECONDS + 0.05, refresh)
end

local function onActionResult(result: any)
	if type(result) ~= "table" or result.action ~= Remotes.Action.Travel then
		return
	end
	local worldId = if type(result.worldId) == "string" then result.worldId else nil
	if worldId then
		pendingUntil[worldId] = nil
	else
		-- Limitation : la réponse ne nomme pas le monde.
		table.clear(pendingUntil)
	end
	if result.ok == true and worldId then
		InventoryController.showSuccessText(Localization.fill("travel.arrived", localPlayer.LocaleId, {
			world = worldName(worldId),
		}))
	else
		local key = TravelRules.refusalMessage(result.code, Remotes.ResultCode)
		if key then
			InventoryController.showMessage(key)
		end
	end
	-- Le personnage vient d'être déplacé : île courante à relire.
	task.delay(0.2, refresh)
end

local function addArrival(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local worldId = instance:GetAttribute(ARRIVAL_ATTRIBUTE)
	if type(worldId) ~= "string" or WorldConfig[worldId] == nil then
		return
	end
	arrivalParts[instance] = worldId
	instance.AncestryChanged:Connect(function()
		if instance.Parent == nil then
			arrivalParts[instance] = nil
			refresh()
		end
	end)
	refresh()
end

local function addPortal(instance: Instance)
	if not instance:IsA("BasePart") or prompts[instance] ~= nil then
		return
	end
	local worldId = instance:GetAttribute(PORTAL_ATTRIBUTE)
	if type(worldId) ~= "string" or WorldConfig[worldId] == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TravelPrompt"
	prompt.KeyboardKeyCode = PORTAL_KEY
	prompt.GamepadKeyCode = PORTAL_GAMEPAD_BUTTON
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = PORTAL_RANGE_STUDS
	prompt.Triggered:Connect(function()
		TravelController.request(worldId)
	end)
	prompt.Parent = instance
	prompts[instance] = { prompt = prompt, worldId = worldId }
	instance.AncestryChanged:Connect(function()
		if instance.Parent == nil then
			prompts[instance] = nil
		end
	end)
	refresh()
end

-- Surveille un dossier de Workspace, même s'il apparaît plus tard.
local function watchFolder(name: string, handler: (Instance) -> ())
	local function attach(folder: Instance)
		folder.DescendantAdded:Connect(handler)
		for _, descendant in ipairs(folder:GetDescendants()) do
			handler(descendant)
		end
	end
	local folder = Workspace:FindFirstChild(name)
	if folder then
		attach(folder)
	end
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == name then
			attach(child)
		end
	end)
end

function TravelController.start()
	assert(not started, "TravelController.start appelé deux fois")
	started = true

	requestTravel = Remotes.waitFor(Remotes.Name.TravelToWorld)
	Remotes.waitFor(Remotes.Name.ActionResult).OnClientEvent:Connect(onActionResult)
	InventoryController.onStateChanged(function()
		refresh()
	end)
	-- Réapparition : toujours au hub de Green Valley (D-021 D5).
	localPlayer.CharacterAdded:Connect(function()
		task.delay(0.5, refresh)
	end)
	watchFolder(ARRIVAL_FOLDER_NAME, addArrival)
	watchFolder(MAP_FOLDER_NAME, addPortal)
end

return TravelController
