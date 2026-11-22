--!strict
-- Gardiens et sites sacrés côté client (T10.3) : affichage SEULEMENT.
--
-- Le serveur décide de tout (accès, combat, PV, touches, victoire). Ce
-- contrôleur :
--   * anime LOCALEMENT le modèle commun du gardien pour le combat du joueur
--     local (les autres joueurs voient leur propre état : modifier une Part
--     répliquée côté client ne se réplique pas) ;
--   * dessine les télégraphies d'attaque reçues (zones au sol, projectiles),
--     les éclats de faiblesse de SON combat, la barre de vie, les messages ;
--   * applique au personnage local la poussée annoncée par le serveur
--     (physique du personnage possédée par le client) ;
--   * fournit au bouton « Grab » (CollectionController) les cibles : éclats,
--     autel, nœuds sacrés. Seuls des identifiants sont envoyés.
-- Tout est créé dans des dossiers locaux et détruit à la fin du combat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuardianConfig = require(Shared:WaitForChild("Config"):WaitForChild("GuardianConfig"))
local SacredResourceConfig = require(Shared:WaitForChild("Config"):WaitForChild("SacredResourceConfig"))
local GuardianRules = require(Shared:WaitForChild("Util"):WaitForChild("GuardianRules"))
local Localization = require(Shared:WaitForChild("Util"):WaitForChild("Localization"))
local Remotes = require(Shared:WaitForChild("Remotes"):WaitForChild("Remotes"))
local CollectionController = require(script.Parent:WaitForChild("CollectionController"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))

local GuardianController = {}

local Combat = GuardianConfig.Combat
local Access = GuardianRules.Access
local ResultCode = Remotes.ResultCode

local SITES_TIMEOUT_SECONDS = 30
local RESPONSE_TIMEOUT_SECONDS = 1
local SEND_MARGIN_SECONDS = 0.03
local SHARD_HEIGHT = 2.4
local PROJECTILE_HEIGHT = 26
local STATUS_REFRESH_SECONDS = 0.5

type SiteView = {
	siteId: string,
	model: Model,
	center: BasePart,
	altar: BasePart,
	guardian: Model?,
	basePivot: CFrame?,
	nodes: { BasePart },
	status: TextLabel?,
}

type CombatView = {
	combatId: string,
	siteId: string,
	guardianId: string,
	state: string,
	health: number,
	maxHealth: number,
	phase: number,
}

local localPlayer = Players.LocalPlayer :: Player
local sites: { [string]: SiteView } = {}
local access: { [string]: { access: string, respawnUntil: number, rewardClaimed: boolean } } = {}
local combat: CombatView? = nil
local shards: { [string]: BasePart } = {}
local shardOf: { [BasePart]: string } = {}
local nodeOf: { [BasePart]: string } = {}
local altarOf: { [BasePart]: string } = {}
local fxFolder: Folder
local stunnedUntil = 0
local nextStrikeAt = 0
local strikePendingUntil = 0
local activatePendingUntil = 0
local sacredPendingUntil = 0
-- Animation locale du gardien du combat en cours.
local windupUntil = 0
local windupSeconds = 1
local slamUntil = 0
local flashUntil = 0
local defeatedSiteId: string? = nil

local requestActivate: RemoteEvent
local requestStrike: RemoteEvent
local requestSacred: RemoteEvent

local hud: ScreenGui
local hudFrame: Frame
local hudName: TextLabel
local hudFill: Frame
local hudPhase: TextLabel
local banner: TextLabel
local bannerUntil = 0
local vignette: Frame

local function translate(key: string): string
	return Localization.get(key, localPlayer.LocaleId)
end

local function fill(key: string, values: { [string]: string }): string
	return Localization.fill(key, localPlayer.LocaleId, values)
end

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function rootPart(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function showBanner(text: string, seconds: number?)
	banner.Text = text
	banner.Visible = true
	bannerUntil = os.clock() + (seconds or 2.5)
end

-- Pièce décorative locale : jamais de collision, de requête ni d'ombre.
local function fxPart(shape: Enum.PartType?, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	if shape then
		part.Shape = shape
	end
	return part
end

-- Carte ---------------------------------------------------------------------

local function buildStatusLabel(altar: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "GuardianAltarStatus"
	gui.Size = UDim2.fromOffset(240, 46)
	gui.StudsOffset = Vector3.new(0, altar.Size.Y / 2 + 4, 0)
	gui.MaxDistance = 70
	gui.AlwaysOnTop = false
	gui.Adornee = altar
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return label
end

local function registerSite(model: Instance)
	local siteId = model.Name
	if GuardianConfig.Sites[siteId] == nil or not model:IsA("Model") or sites[siteId] ~= nil then
		return
	end
	local center = model:WaitForChild("Center", 10)
	local altar = model:WaitForChild("Altar", 10)
	if center == nil or altar == nil or not center:IsA("BasePart") or not altar:IsA("BasePart") then
		return
	end
	local guardian = model:FindFirstChild("Guardian")
	local view: SiteView = {
		siteId = siteId,
		model = model,
		center = center,
		altar = altar,
		guardian = if guardian and guardian:IsA("Model") then guardian else nil,
		basePivot = if guardian and guardian:IsA("Model") then guardian:GetPivot() else nil,
		nodes = {},
		status = nil,
	}
	local zone = model:FindFirstChild("RewardZone")
	local children: { Instance } = if zone then zone:GetChildren() else {}
	for _, part in ipairs(children) do
		if part:IsA("BasePart") and type(part:GetAttribute("SacredNodeId")) == "string" then
			table.insert(view.nodes, part)
			nodeOf[part] = part:GetAttribute("SacredNodeId") :: string
		end
	end
	altarOf[altar] = siteId
	view.status = buildStatusLabel(altar)
	sites[siteId] = view
end

-- Animation locale du gardien ------------------------------------------------

local function setGuardianVisible(view: SiteView, visible: boolean)
	local guardian = view.guardian
	if guardian == nil then
		return
	end
	for _, descendant in ipairs(guardian:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if visible then 0 else 1
		end
	end
end

local function resetGuardian(view: SiteView)
	if view.guardian and view.basePivot then
		view.guardian:PivotTo(view.basePivot)
	end
	local highlight = if view.guardian then view.guardian:FindFirstChild("GuardianFlash") else nil
	if highlight then
		highlight:Destroy()
	end
	setGuardianVisible(view, true)
end

local function flashGuardian(view: SiteView)
	local guardian = view.guardian
	if guardian == nil then
		return
	end
	local highlight = guardian:FindFirstChild("GuardianFlash") :: Highlight?
	if highlight == nil then
		local created = Instance.new("Highlight")
		created.Name = "GuardianFlash"
		created.DepthMode = Enum.HighlightDepthMode.Occluded
		created.FillColor = Color3.new(1, 1, 1)
		created.OutlineTransparency = 1
		created.FillTransparency = 1
		created.Parent = guardian
		highlight = created
	end
	flashUntil = os.clock() + 0.15
	;(highlight :: Highlight).FillTransparency = 0.35
end

-- Pose du gardien à chaque image, pendant le combat du joueur local.
local function animateGuardian(now: number)
	local current = combat
	if current == nil then
		return
	end
	local view = sites[current.siteId]
	local root = rootPart()
	if view == nil or view.guardian == nil or view.basePivot == nil or root == nil then
		return
	end
	local base = view.basePivot :: CFrame
	local origin = base.Position
	local target = Vector3.new(root.Position.X, origin.Y, root.Position.Z)
	local facing = if (target - origin).Magnitude > 0.5 then CFrame.lookAt(origin, target) else base
	local rise = 0
	if current.state == "Awakening" then
		rise = math.sin(now * 8) * 0.25
	else
		rise = math.sin(now * 2) * 0.4
	end
	local lean = 0
	if now < windupUntil then
		-- Préparation : le gardien se penche en arrière (annonce visuelle).
		local progress = 1 - (windupUntil - now) / windupSeconds
		lean = -math.rad(14) * math.clamp(progress, 0, 1)
	elseif now < slamUntil then
		lean = math.rad(10)
	end
	view.guardian:PivotTo(CFrame.new(0, rise, 0) * facing * CFrame.Angles(lean, 0, 0))
	if now >= flashUntil then
		local highlight = view.guardian:FindFirstChild("GuardianFlash") :: Highlight?
		if highlight then
			highlight.FillTransparency = 1
		end
	end
end

local function playDefeat(view: SiteView, respawnSeconds: number)
	local guardian = view.guardian
	if guardian == nil or view.basePivot == nil then
		return
	end
	defeatedSiteId = view.siteId
	local base = view.basePivot :: CFrame
	local size = guardian:GetExtentsSize()
	task.spawn(function()
		local steps = 20
		for step = 1, steps do
			if defeatedSiteId ~= view.siteId then
				return
			end
			local progress = step / steps
			guardian:PivotTo(base * CFrame.new(0, -size.Y * 0.6 * progress, 0) * CFrame.Angles(math.rad(8) * progress, 0, 0))
			task.wait(0.06)
		end
		setGuardianVisible(view, false)
		task.wait(math.max(respawnSeconds - 1.2, 0))
		if defeatedSiteId == view.siteId then
			defeatedSiteId = nil
			resetGuardian(view)
		end
	end)
end

-- Télégraphies ---------------------------------------------------------------

local function groundY(view: SiteView): number
	return view.center.Position.Y + 0.15
end

local function disc(x: number, y: number, z: number, radius: number, color: Color3, transparency: number): Part
	local part = fxPart(Enum.PartType.Cylinder, color, transparency)
	part.Size = Vector3.new(0.2, radius * 2, radius * 2)
	part.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = fxFolder
	return part
end

local function strip(origin: Vector3, direction: Vector3, width: number, length: number, color: Color3, transparency: number): Part
	local part = fxPart(nil, color, transparency)
	part.Size = Vector3.new(width, 0.2, length)
	part.CFrame = CFrame.lookAt(origin + direction * (length / 2), origin + direction * length)
	part.Parent = fxFolder
	return part
end

-- Dessine une attaque annoncée ; retourne les pièces (zone) à animer.
local function drawAttack(view: SiteView, definition: any, plan: any): { Part }
	local y = groundY(view)
	local color = rgb(definition.color)
	local parts: { Part } = {}
	local origin = Vector3.new(plan.origin.X, y, plan.origin.Z)
	local direction = Vector3.new(plan.direction.X, 0, plan.direction.Z)
	if definition.shape == "ring" then
		table.insert(parts, disc(origin.X, y, origin.Z, definition.outerRadius, color, 0.75))
		if (definition.innerRadius or 0) > 0 then
			-- Refuge : disque sombre au centre, visible au-dessus de la zone.
			local safe = disc(origin.X, y + 0.05, origin.Z, definition.innerRadius, Color3.fromRGB(40, 60, 40), 0.4)
			safe.Material = Enum.Material.SmoothPlastic
		end
	elseif definition.shape == "circle" then
		for _, target in ipairs(plan.targets) do
			table.insert(parts, disc(target.X, y, target.Z, definition.radius, color, 0.75))
		end
	elseif definition.shape == "line" then
		table.insert(parts, strip(origin, direction, definition.width, definition.length, color, 0.75))
	elseif definition.shape == "cone" then
		-- Secteur approché par des bandes rayonnantes.
		local half = math.rad(definition.angleDegrees / 2)
		local count = 7
		for index = 0, count - 1 do
			local angle = -half + (2 * half) * (index + 0.5) / count
			local rotated = (CFrame.fromAxisAngle(Vector3.yAxis, angle) :: CFrame):VectorToWorldSpace(direction)
			local width = 2 * definition.radius * math.sin(half / count) + 0.5
			table.insert(parts, strip(origin, rotated, width, definition.radius, color, 0.75))
		end
	end
	return parts
end

local function fadeAndDestroy(parts: { Part }, seconds: number)
	for _, part in ipairs(parts) do
		local tween = TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 })
		tween.Completed:Connect(function()
			part:Destroy()
		end)
		tween:Play()
	end
end

local function playAttack(message: any)
	local current = combat
	if current == nil or message.combatId ~= current.combatId then
		return
	end
	local view = sites[current.siteId]
	local guardian = GuardianConfig.Guardians[current.guardianId]
	local definition = if guardian then guardian.attacks[message.attackId] else nil
	if view == nil or definition == nil or type(message.plan) ~= "table" then
		return
	end
	local telegraph = if type(message.telegraphSeconds) == "number" then message.telegraphSeconds else 1.5
	local linger = if type(message.lingerSeconds) == "number" then message.lingerSeconds else 0
	local now = os.clock()
	windupSeconds = telegraph
	windupUntil = now + telegraph
	slamUntil = windupUntil + 0.25

	local zone = drawAttack(view, definition, message.plan)
	-- La zone se densifie jusqu'à l'impact (compte à rebours visuel).
	for _, part in ipairs(zone) do
		TweenService:Create(part, TweenInfo.new(telegraph, Enum.EasingStyle.Linear), { Transparency = 0.35 }):Play()
	end
	-- Projectiles (disques visés) : une sphère tombe sur chaque cible.
	if definition.shape == "circle" and linger == 0 then
		for _, target in ipairs(message.plan.targets) do
			local orb = fxPart(Enum.PartType.Ball, rgb(definition.color), 0.1)
			orb.Size = Vector3.new(2.5, 2.5, 2.5)
			orb.Position = Vector3.new(target.X, groundY(view) + PROJECTILE_HEIGHT, target.Z)
			orb.Parent = fxFolder
			local fall = TweenService:Create(orb, TweenInfo.new(telegraph, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = Vector3.new(target.X, groundY(view) + 1, target.Z),
			})
			fall.Completed:Connect(function()
				orb:Destroy()
			end)
			fall:Play()
		end
	end
	task.delay(telegraph, function()
		for _, part in ipairs(zone) do
			if part.Parent then
				part.Transparency = 0
			end
		end
		task.delay(0.12, function()
			if linger > 0 then
				for _, part in ipairs(zone) do
					if part.Parent then
						part.Transparency = 0.45
					end
				end
				task.delay(linger, function()
					fadeAndDestroy(zone, 0.3)
				end)
			else
				fadeAndDestroy(zone, 0.35)
			end
		end)
	end)
end

-- Éclats -----------------------------------------------------------------------

local function removeShard(shardId: string)
	local part = shards[shardId]
	if part then
		shards[shardId] = nil
		shardOf[part] = nil
		part:Destroy()
	end
end

local function clearCombatFx()
	for shardId in pairs(shards) do
		removeShard(shardId)
	end
	fxFolder:ClearAllChildren()
	windupUntil = 0
	slamUntil = 0
end

local function addShard(message: any)
	local current = combat
	if current == nil or message.combatId ~= current.combatId or type(message.shardId) ~= "string" then
		return
	end
	local position = message.position
	if type(position) ~= "table" then
		return
	end
	local guardian = GuardianConfig.Guardians[current.guardianId]
	local part = fxPart(nil, rgb(guardian.accent), 0)
	part.Name = "WeaknessShard"
	-- Identifiant serveur (affichage et tests manuels ; aucune autorité).
	part:SetAttribute("ShardId", message.shardId)
	part.Size = Vector3.new(1.3, 2.6, 1.3)
	part.CFrame = CFrame.new(position.X, position.Y + SHARD_HEIGHT, position.Z) * CFrame.Angles(0, 0, math.rad(45))
	part.Parent = fxFolder
	shards[message.shardId] = part
	shardOf[part] = message.shardId
end

-- HUD ----------------------------------------------------------------------------

local function updateHud()
	local current = combat
	hudFrame.Visible = current ~= nil
	if current == nil then
		return
	end
	local guardian = GuardianConfig.Guardians[current.guardianId]
	hudName.Text = translate(guardian.nameKey)
	local fraction = if current.maxHealth > 0 then current.health / current.maxHealth else 0
	hudFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	hudFill.BackgroundColor3 = rgb(guardian.accent)
	hudPhase.Text = if current.state == "Awakening"
		then translate("guardian.awakening")
		else fill("guardian.phase", { phase = tostring(current.phase) })
end

local function buildHud()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	hud = Instance.new("ScreenGui")
	hud.Name = "GuardianHUD"
	hud.ResetOnSpawn = false
	hud.IgnoreGuiInset = false
	hud.DisplayOrder = 5

	hudFrame = Instance.new("Frame")
	hudFrame.AnchorPoint = Vector2.new(0.5, 0)
	hudFrame.Position = UDim2.new(0.5, 0, 0, 8)
	hudFrame.Size = UDim2.new(0.5, 0, 0, 58)
	hudFrame.BackgroundTransparency = 0.3
	hudFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	hudFrame.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 58)
	limit.Parent = hudFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = hudFrame
	hudFrame.Parent = hud

	hudName = Instance.new("TextLabel")
	hudName.BackgroundTransparency = 1
	hudName.Position = UDim2.fromOffset(10, 3)
	hudName.Size = UDim2.new(0.6, -10, 0, 22)
	hudName.Font = Enum.Font.GothamBold
	hudName.TextColor3 = Color3.new(1, 1, 1)
	hudName.TextScaled = true
	hudName.TextXAlignment = Enum.TextXAlignment.Left
	hudName.Parent = hudFrame

	hudPhase = Instance.new("TextLabel")
	hudPhase.BackgroundTransparency = 1
	hudPhase.AnchorPoint = Vector2.new(1, 0)
	hudPhase.Position = UDim2.new(1, -10, 0, 5)
	hudPhase.Size = UDim2.new(0.4, -10, 0, 18)
	hudPhase.Font = Enum.Font.Gotham
	hudPhase.TextColor3 = Color3.fromRGB(220, 220, 230)
	hudPhase.TextScaled = true
	hudPhase.TextXAlignment = Enum.TextXAlignment.Right
	hudPhase.Parent = hudFrame

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 10, 0, 30)
	bar.Size = UDim2.new(1, -20, 0, 18)
	bar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar
	bar.Parent = hudFrame
	hudFill = Instance.new("Frame")
	hudFill.Size = UDim2.fromScale(1, 1)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = hudFill
	hudFill.Parent = bar

	banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 74)
	banner.Size = UDim2.new(0.6, 0, 0, 34)
	banner.BackgroundTransparency = 0.25
	banner.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.Font = Enum.Font.GothamBold
	banner.TextScaled = true
	banner.Visible = false
	local bannerLimit = Instance.new("UISizeConstraint")
	bannerLimit.MaxSize = Vector2.new(460, 34)
	bannerLimit.Parent = banner
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 10)
	bannerCorner.Parent = banner
	banner.Parent = hud

	-- Bord rouge bref quand le joueur est touché.
	vignette = Instance.new("Frame")
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 0
	vignette.Parent = hud

	hud.Parent = playerGui
end

-- État des autels ---------------------------------------------------------------

local function refreshStatus(now: number)
	local state = InventoryController.getState()
	for siteId, view in pairs(sites) do
		local label = view.status
		if label == nil then
			continue
		end
		local definition = GuardianConfig.Sites[siteId]
		local entry = access[siteId]
		local text = translate(definition.nameKey)
		local line = ""
		if combat ~= nil and combat.siteId == siteId then
			line = translate("guardian.grab_hint")
		elseif entry == nil then
			line = ""
		elseif entry.respawnUntil > now then
			line = fill("guardian.altar.respawn", { seconds = tostring(math.ceil(entry.respawnUntil - now)) })
		elseif entry.access == Access.WorldLocked then
			line = translate("guardian.altar.world_locked")
		elseif entry.access == Access.DiscoveryRequired then
			local count, total = GuardianRules.discoveryProgress(definition.worldId, if state then state.discovered else nil)
			line = fill("guardian.altar.discovery", { count = tostring(count), total = tostring(total) })
		else
			line = translate("guardian.altar.wake")
			-- Récompense de première victoire pas encore réclamée (D-035).
			if entry.access == Access.Unlocked and not entry.rewardClaimed then
				line = `{line}\n{translate("sacred.reward_ready")}`
			end
		end
		label.Text = if line ~= "" then `{text}\n{line}` else text
	end
end

-- Messages du serveur -----------------------------------------------------------

local function onSites(message: any)
	if type(message.sites) ~= "table" then
		return
	end
	local now = os.clock()
	for siteId, entry in pairs(message.sites) do
		if GuardianConfig.Sites[siteId] ~= nil and type(entry) == "table" then
			access[siteId] = {
				access = tostring(entry.access),
				respawnUntil = now + (if type(entry.respawnSeconds) == "number" then entry.respawnSeconds else 0),
				rewardClaimed = entry.rewardClaimed == true,
			}
		end
	end
	refreshStatus(now)
end

local function onCombat(message: any)
	local previous = combat
	if previous ~= nil and previous.combatId ~= message.combatId then
		clearCombatFx()
	end
	if previous == nil then
		local view = sites[message.siteId]
		if view then
			defeatedSiteId = nil
			resetGuardian(view)
		end
	end
	combat = {
		combatId = tostring(message.combatId),
		siteId = tostring(message.siteId),
		guardianId = tostring(message.guardianId),
		state = tostring(message.state),
		health = tonumber(message.health) or 0,
		maxHealth = tonumber(message.maxHealth) or 1,
		phase = tonumber(message.phase) or 1,
	}
	if previous ~= nil and previous.combatId == message.combatId and (tonumber(message.health) or 0) < previous.health then
		local view = sites[message.siteId]
		if view then
			flashGuardian(view)
		end
	end
	if previous == nil then
		showBanner(translate("guardian.awakening"))
	elseif previous.state == "Awakening" and message.state == "Combat" then
		showBanner(translate("guardian.grab_hint"))
	end
	updateHud()
end

local function onHit(message: any)
	local now = os.clock()
	local stun = if type(message.stunSeconds) == "number" then message.stunSeconds else Combat.hit.stunSeconds
	stunnedUntil = now + stun
	showBanner(translate("guardian.hit"), stun)
	vignette.BackgroundTransparency = 0.6
	TweenService:Create(vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	local root = rootPart()
	local direction = message.direction
	if root and type(direction) == "table" then
		local push = Vector3.new(tonumber(direction.X) or 0, 0, tonumber(direction.Z) or 0)
		local strength = (if type(message.knockbackStuds) == "number" then message.knockbackStuds else 12) * 2.2
		root.AssemblyLinearVelocity = push * strength + Vector3.new(0, 22, 0)
	end
end

local function onEnded(message: any)
	local current = combat
	if current == nil or message.combatId ~= current.combatId then
		return
	end
	combat = nil
	clearCombatFx()
	local view = sites[current.siteId]
	if message.reason == "victory" then
		if view then
			playDefeat(view, if type(message.respawnSeconds) == "number" then message.respawnSeconds else Combat.respawnSeconds)
		end
	else
		if view then
			resetGuardian(view)
		end
		if message.reason == "left_arena" then
			showBanner(translate("guardian.ended.left_arena"), 3)
		else
			showBanner(translate("guardian.ended.no_character"), 3)
		end
	end
	updateHud()
end

local function onVictory(message: any)
	local site = GuardianConfig.Sites[message.siteId]
	local guardian = if site then GuardianConfig.Guardians[site.guardianId] else nil
	if guardian == nil then
		return
	end
	local text = fill("guardian.victory", { name = translate(guardian.nameKey) })
	if message.firstVictory == true then
		text ..= "  " .. translate("guardian.unlocked")
	end
	InventoryController.showSuccessText(text)
end

local RESULT_MESSAGES: { [string]: string } = {
	[ResultCode.TooFar] = "guardian.too_far",
	[ResultCode.WorldLocked] = "guardian.altar.world_locked",
	[ResultCode.RequirementNotMet] = "guardian.discovery_required",
	[ResultCode.AlreadyInCombat] = "guardian.in_combat",
	[ResultCode.GuardianRespawning] = "guardian.respawning",
}

local function onResult(message: any)
	if message.action == "Activate" then
		activatePendingUntil = 0
		local key = RESULT_MESSAGES[message.code]
		if message.ok ~= true and key then
			showBanner(translate(key))
		end
	elseif message.action == "Strike" then
		strikePendingUntil = 0
		if message.code == ResultCode.TooFar then
			showBanner(translate("guardian.too_far"), 1.2)
		end
	elseif message.action == "SacredCollect" then
		sacredPendingUntil = 0
		local definition = if type(message.resourceId) == "string"
			then SacredResourceConfig.Resources[message.resourceId]
			else nil
		if message.ok == true and definition then
			showBanner(fill("sacred.claimed", {
				amount = tostring(message.amount),
				name = translate(definition.nameKey),
			}))
		elseif message.code == ResultCode.InventoryFull then
			local siteResource = if type(message.siteId) == "string" then SacredResourceConfig.BySite[message.siteId] else nil
			local units = if siteResource then SacredResourceConfig.Resources[siteResource].rewardUnits else 0
			showBanner(fill("sacred.bag_full", { amount = tostring(units) }))
		elseif message.code == ResultCode.AlreadyClaimed then
			showBanner(translate("sacred.already_claimed"))
		elseif message.code == ResultCode.RequirementNotMet then
			showBanner(translate("sacred.locked"))
		end
	end
end

local function onEvent(message: any)
	if type(message) ~= "table" then
		return
	end
	local kind = message.type
	if kind == "sites" then
		onSites(message)
	elseif kind == "combat" then
		onCombat(message)
	elseif kind == "shard" then
		addShard(message)
	elseif kind == "shardRemoved" then
		strikePendingUntil = 0
		removeShard(tostring(message.shardId))
	elseif kind == "attack" then
		playAttack(message)
	elseif kind == "hit" then
		onHit(message)
	elseif kind == "ended" then
		onEnded(message)
	elseif kind == "victory" then
		onVictory(message)
	elseif kind == "result" then
		onResult(message)
	end
end

-- Cibles du bouton « Grab » -------------------------------------------------------

local function nearest(parts: { BasePart }, origin: Vector3, range: number): (BasePart?, number)
	local best: BasePart? = nil
	local bestDistance = range
	for _, part in ipairs(parts) do
		local distance = (part.Position - origin).Magnitude
		if distance <= bestDistance then
			best = part
			bestDistance = distance
		end
	end
	return best, bestDistance
end

local function findTarget(origin: Vector3): (BasePart?, number)
	local now = os.clock()
	local current = combat
	if current ~= nil then
		if current.state ~= "Combat" or now < stunnedUntil then
			return nil, math.huge
		end
		local list: { BasePart } = {}
		for part in pairs(shardOf) do
			table.insert(list, part)
		end
		-- Éclat à SHARD_HEIGHT au-dessus du sol : portée comptée large.
		return nearest(list, origin, Combat.shards.grabRangeStuds + SHARD_HEIGHT)
	end
	local candidates: { BasePart } = {}
	for siteId, view in pairs(sites) do
		local entry = access[siteId]
		local open = entry ~= nil and (entry.access == Access.Eligible or entry.access == Access.Unlocked)
		if open and entry.respawnUntil <= now and defeatedSiteId ~= siteId then
			table.insert(candidates, view.altar)
		end
		-- Nœuds de la terrasse : seulement tant que la récompense est due.
		if entry ~= nil and entry.access == Access.Unlocked and not entry.rewardClaimed then
			for _, node in ipairs(view.nodes) do
				table.insert(candidates, node)
			end
		end
	end
	return nearest(candidates, origin, Combat.arena.altarRangeStuds)
end

local function owns(part: BasePart): boolean
	return shardOf[part] ~= nil or altarOf[part] ~= nil or nodeOf[part] ~= nil
end

local function activate(part: BasePart)
	local now = os.clock()
	local shardId = shardOf[part]
	if shardId then
		if now < nextStrikeAt or now < strikePendingUntil or now < stunnedUntil then
			return
		end
		nextStrikeAt = now + Combat.shards.minIntervalSeconds + SEND_MARGIN_SECONDS
		strikePendingUntil = now + RESPONSE_TIMEOUT_SECONDS
		requestStrike:FireServer({ shardId = shardId })
		part.Transparency = 0.5
		return
	end
	local siteId = altarOf[part]
	if siteId then
		if now < activatePendingUntil then
			return
		end
		activatePendingUntil = now + RESPONSE_TIMEOUT_SECONDS
		requestActivate:FireServer({ siteId = siteId })
		return
	end
	local nodeId = nodeOf[part]
	if nodeId and now >= sacredPendingUntil then
		sacredPendingUntil = now + RESPONSE_TIMEOUT_SECONDS
		requestSacred:FireServer({ nodeId = nodeId })
	end
end

local function label(part: BasePart): string
	if shardOf[part] then
		return translate("guardian.shard")
	end
	local siteId = altarOf[part]
	if siteId then
		return translate("guardian.altar.wake")
	end
	local resourceId = part:GetAttribute("SacredResourceId")
	local definition = if type(resourceId) == "string" then SacredResourceConfig.Resources[resourceId] else nil
	return if definition then fill("sacred.claim", { name = translate(definition.nameKey) }) else ""
end

-- Démarrage ----------------------------------------------------------------------

function GuardianController.start()
	requestActivate = Remotes.waitFor(Remotes.Name.RequestGuardianActivate)
	requestStrike = Remotes.waitFor(Remotes.Name.RequestGuardianStrike)
	requestSacred = Remotes.waitFor(Remotes.Name.RequestSacredCollect)

	local folder = Instance.new("Folder")
	folder.Name = "GuardianFxLocal"
	folder.Parent = Workspace
	fxFolder = folder

	buildHud()
	Remotes.waitFor(Remotes.Name.GuardianEvent).OnClientEvent:Connect(onEvent)

	CollectionController.addTargetSource({
		find = findTarget,
		owns = owns,
		activate = activate,
		label = label,
	})

	task.spawn(function()
		local siteFolder = Workspace:WaitForChild(GuardianConfig.MapFolderName, SITES_TIMEOUT_SECONDS)
		if siteFolder == nil then
			warn(`[Guardian] Workspace.{GuardianConfig.MapFolderName} introuvable : sites sacrés désactivés`)
			return
		end
		siteFolder.ChildAdded:Connect(registerSite)
		for _, child in ipairs(siteFolder:GetChildren()) do
			task.spawn(registerSite, child)
		end
	end)

	local sinceStatus = 0
	RunService.RenderStepped:Connect(function(deltaTime: number)
		local now = os.clock()
		animateGuardian(now)
		for _, part in pairs(shards) do
			part.CFrame = part.CFrame * CFrame.Angles(0, deltaTime * 2, 0)
		end
		if banner.Visible and now >= bannerUntil then
			banner.Visible = false
		end
		sinceStatus += deltaTime
		if sinceStatus >= STATUS_REFRESH_SECONDS then
			sinceStatus = 0
			refreshStatus(now)
			-- Avertissement : le joueur quitte l'arène pendant son combat.
			local current = combat
			local root = rootPart()
			local view = if current then sites[current.siteId] else nil
			if view and root and not GuardianRules.isInsideArena(
				{ X = view.center.Position.X, Z = view.center.Position.Z },
				{ X = root.Position.X, Z = root.Position.Z },
				Combat.arena.radius
			) then
				showBanner(translate("guardian.leaving"), 0.6)
			end
		end
	end)
end

return GuardianController
