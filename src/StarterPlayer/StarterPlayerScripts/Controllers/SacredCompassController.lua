--!strict
-- Boussole des sanctuaires (T10.5b, D-038), côté client : signale les
-- ressources Rare et Epic disponibles autour du joueur. Affichage seulement :
-- aucune demande au serveur, aucun effet sur la collecte (validée par le
-- serveur comme toujours).
--
-- Active seulement si l'état serveur indique l'amélioration
-- `sacred_compass`. Recherche périodique (SacredResourceConfig.Compass),
-- jamais à chaque image ; pool fixe de marqueurs (BillboardGui) réutilisés.
-- Nœuds : Parts de Workspace.ResourceNodes (attributs ResourceType,
-- Available), présents ou non selon le streaming.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ResourceConfig = require(Config:WaitForChild("ResourceConfig"))
local SacredResourceConfig = require(Config:WaitForChild("SacredResourceConfig"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))

local SacredCompassController = {}

local UPGRADE_ID = "sacred_compass"
local NODE_FOLDER_NAME = "ResourceNodes"
local NODE_FOLDER_TIMEOUT_SECONDS = 30

local RARITY_COLORS: { [string]: Color3 } = {
	Rare = Color3.fromRGB(90, 170, 255),
	Epic = Color3.fromRGB(196, 120, 255),
}

type Marker = { gui: BillboardGui, label: TextLabel }

local localPlayer = Players.LocalPlayer :: Player
local started = false
local markers: { Marker } = {}

local function isActive(): boolean
	local state = InventoryController.getState()
	local owned = if state then state.sacredUpgrades else nil
	return type(owned) == "table" and owned[UPGRADE_ID] == true
end

local function newMarker(parent: Instance): Marker
	local gui = Instance.new("BillboardGui")
	gui.Name = "SacredCompassMarker"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.new(0, 140, 0, 26)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.Enabled = false
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return { gui = gui, label = label }
end

local function hideAll()
	for _, marker in ipairs(markers) do
		marker.gui.Enabled = false
		marker.gui.Adornee = nil :: any -- l'API déclare Adornee non nul
	end
end

type Candidate = { part: BasePart, distance: number, definition: any }

local function refresh(folder: Instance)
	if not isActive() then
		hideAll()
		return
	end
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		hideAll()
		return
	end
	local settings = SacredResourceConfig.Compass
	local origin = root.Position
	local candidates: { Candidate } = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("Available") == true then
			local resourceType = child:GetAttribute("ResourceType")
			local definition = if type(resourceType) == "string" then ResourceConfig[resourceType] else nil
			if definition and settings.rarities[definition.rarity] then
				local distance = (child.Position - origin).Magnitude
				if distance <= settings.radiusStuds then
					table.insert(candidates, { part = child, distance = distance, definition = definition })
				end
			end
		end
	end
	table.sort(candidates, function(a: Candidate, b: Candidate): boolean
		return a.distance < b.distance
	end)
	for index, marker in ipairs(markers) do
		local candidate = candidates[index]
		if candidate then
			marker.gui.Adornee = candidate.part
			marker.label.Text = `✦ {Localization.get(candidate.definition.displayNameKey, localPlayer.LocaleId)}`
			marker.label.TextColor3 = RARITY_COLORS[candidate.definition.rarity] or Color3.new(1, 1, 1)
			marker.gui.Enabled = true
		else
			marker.gui.Enabled = false
			marker.gui.Adornee = nil :: any -- l'API déclare Adornee non nul
		end
	end
end

function SacredCompassController.start()
	assert(not started, "SacredCompassController.start appelé deux fois")
	started = true
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	for _ = 1, SacredResourceConfig.Compass.maxMarkers do
		table.insert(markers, newMarker(playerGui))
	end
	task.spawn(function()
		local folder = Workspace:WaitForChild(NODE_FOLDER_NAME, NODE_FOLDER_TIMEOUT_SECONDS)
		if folder == nil then
			warn("[SacredCompass] dossier ResourceNodes introuvable")
			return
		end
		while true do
			refresh(folder)
			task.wait(SacredResourceConfig.Compass.refreshSeconds)
		end
	end)
end

return SacredCompassController
