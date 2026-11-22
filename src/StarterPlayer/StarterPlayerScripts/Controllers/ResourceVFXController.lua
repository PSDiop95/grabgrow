--!strict
-- Effets de rareté, de collecte et de réapparition des ressources, côté
-- client (T10.2, D-032). Purement visuel : aucune règle de collecte,
-- aucun envoi au serveur ; ne fait que suivre l'état décidé par le serveur
-- (attribut Available, réponses ActionResult reçues par FeedbackController).
--
-- Tout est réutilisé (aucune instance créée par nœud ni par cycle) :
--   * pool d'émetteurs d'attente (Peu commun et plus ; anneau pour
--     l'Épique) : prêtés aux nœuds disponibles les plus rares puis les plus
--     proches de la caméra, MaxIdleEmitters selon le niveau d'effets ;
--   * pool d'auras (disques Neon opaques au sol, Épique) ;
--   * pool d'éclats (`:Emit()`) pour la collecte (cône vers le joueur) et
--     la réapparition (bouffée vers le haut).
-- Une seule boucle de réattribution, toutes les SelectionRefreshSeconds ;
-- aucune lumière dynamique, aucune ombre, aucune transparence partielle
-- sur les pièces (seules les particules sont transparentes).
--
-- Niveau d'effets (ResourceFxRules.effectLevel) : « Effets réduits »
-- (attribut ReducedEffects de FeedbackFX), puis qualité graphique Roblox
-- (UserGameSettings.SavedQualityLevel).
--
-- Compteurs de contrôle (Studio) : attributs du dossier ClientResourceVFX
-- (EffectLevel, IdleEmitters, Auras, ActiveBursts, Bursts_collect,
-- Bursts_respawn, BurstsSkipped, ParticleEstimate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ResourceVisualConfig = require(Config:WaitForChild("ResourceVisualConfig"))
local ResourceVFXConfig = require(Config:WaitForChild("ResourceVFXConfig"))
local ResourceFxRules = require(Shared:WaitForChild("Util"):WaitForChild("ResourceFxRules"))
local NodeVisuals = require(script.Parent:WaitForChild("NodeVisuals"))

local ResourceVFXController = {}

local FOLDER_NAME = "ClientResourceVFX"
local FX_GUI_NAME = "FeedbackFX"
local WHITE = Color3.fromRGB(255, 255, 255)
-- Hauteur des émetteurs d'attente au-dessus du sol (fraction de la hauteur).
local IDLE_HEIGHT_FRACTION = 0.5
local RESPAWN_SPEED = NumberRange.new(3, 6)
-- Hors de vue : position de rangement des pièces porteuses.
local PARKED = CFrame.new(0, -10000, 0)

type Slot = {
	carrier: Part,
	emitter: ParticleEmitter,
	nodeId: string?,
}

type Burst = {
	carrier: Part,
	emitter: ParticleEmitter,
	busyUntil: number,
}

local localPlayer = Players.LocalPlayer :: Player
local started = false
local folder: Folder
local idleSlots: { Slot } = {}
local auraSlots: { { part: Part, nodeId: string? } } = {}
local bursts: { Burst } = {}
local qualityLevel: number? = nil

local function bump(attribute: string)
	local value = folder:GetAttribute(attribute)
	folder:SetAttribute(attribute, (if type(value) == "number" then value else 0) + 1)
end

local function reducedEffects(): boolean
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local fxGui = if playerGui then playerGui:FindFirstChild(FX_GUI_NAME) else nil
	return fxGui ~= nil and fxGui:GetAttribute("ReducedEffects") == true
end

local function currentLevel(): ResourceFxRules.EffectLevel
	return ResourceFxRules.effectLevel(reducedEffects(), qualityLevel, ResourceVFXConfig.LowQualityMax)
end

local function readQuality()
	local ok, level = pcall(function(): any
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if ok and typeof(level) == "EnumItem" then
		local item = level :: EnumItem
		qualityLevel = if item == Enum.SavedQualitySetting.Automatic then nil else item.Value
	else
		qualityLevel = nil
	end
end

local function carrierPart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = PARKED
	part.Parent = folder
	return part
end

local function range(values: { number }): NumberRange
	return NumberRange.new(values[1], values[2])
end

-- Couleur des particules d'un nœud : couleur `particles` de la config
-- (Épique), sinon couleur du visuel éclaircie.
local function particleColor(info: NodeVisuals.NodeInfo): Color3
	local config = ResourceVisualConfig[info.resourceType]
	local particles = if config then config.particles else nil
	if particles then
		return Color3.fromRGB(particles.color[1], particles.color[2], particles.color[3])
	end
	return info.color:Lerp(WHITE, 0.45)
end

local function nodeHeight(info: NodeVisuals.NodeInfo): number
	local config = ResourceVisualConfig[info.resourceType]
	return if config then config.size[2] else 2
end

-- Pools ---------------------------------------------------------------

local function buildPools()
	for index = 1, ResourceVFXConfig.MaxIdleEmitters.full do
		local carrier = carrierPart(`Idle{index}`)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false
		emitter.LightEmission = 0.6
		emitter.Transparency = NumberSequence.new(0.1, 1)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = carrier
		table.insert(idleSlots, { carrier = carrier, emitter = emitter, nodeId = nil })
	end
	for index = 1, ResourceVFXConfig.MaxAuras do
		local disc = Instance.new("Part")
		disc.Name = `Aura{index}`
		disc.Shape = Enum.PartType.Cylinder
		disc.Material = Enum.Material.Neon
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanQuery = false
		disc.CanTouch = false
		disc.CastShadow = false
		disc.Transparency = 1
		disc.CFrame = PARKED
		disc.Parent = folder
		table.insert(auraSlots, { part = disc, nodeId = nil })
	end
	for index = 1, ResourceVFXConfig.BurstPoolSize do
		local carrier = carrierPart(`Burst{index}`)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false
		emitter.Rate = 0
		emitter.LightEmission = 0.5
		emitter.Size = NumberSequence.new(0.35, 0)
		emitter.Transparency = NumberSequence.new(0, 1)
		emitter.Lifetime = range(ResourceVFXConfig.BurstLifetime)
		emitter.Drag = 4
		emitter.EmissionDirection = Enum.NormalId.Front
		emitter.Parent = carrier
		table.insert(bursts, { carrier = carrier, emitter = emitter, busyUntil = 0 })
	end
end

-- Émetteur d'attente prêté à un nœud.
local function assignIdle(slot: Slot, info: NodeVisuals.NodeInfo, style: ResourceVFXConfig.IdleParticles)
	local emitter = slot.emitter
	local height = nodeHeight(info)
	slot.carrier.CFrame = CFrame.new(info.ground + Vector3.new(0, height * IDLE_HEIGHT_FRACTION, 0))
	emitter.Color = ColorSequence.new(particleColor(info))
	emitter.Rate = style.rate
	emitter.Size = NumberSequence.new(style.size, 0)
	emitter.Lifetime = range(style.lifetime)
	emitter.Speed = range(style.speed)
	if style.shape == "Ring" then
		-- Anneau d'aura : particules émises sur un cercle autour du nœud,
		-- qui montent.
		slot.carrier.Size = Vector3.new(height * 1.1, 0.2, height * 1.1)
		slot.carrier.CFrame = CFrame.new(info.ground + Vector3.new(0, 0.2, 0))
		emitter.Shape = Enum.ParticleEmitterShape.Cylinder
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(10, 10)
	else
		slot.carrier.Size = Vector3.new(height, height, height)
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(180, 180)
	end
	emitter:Clear()
	emitter.Enabled = true
	slot.nodeId = info.nodeId
end

local function releaseIdle(slot: Slot)
	slot.emitter.Enabled = false
	slot.carrier.CFrame = PARKED
	slot.nodeId = nil
end

-- Réattribution des émetteurs d'attente et des auras (boucle unique).
local function refresh()
	local level = currentLevel()
	folder:SetAttribute("EffectLevel", level)
	local camera = Workspace.CurrentCamera
	local origin = if camera then camera.CFrame.Position else Vector3.zero
	local infos: { [string]: NodeVisuals.NodeInfo } = {}
	local emitterCandidates: { ResourceFxRules.EmitterCandidate } = {}
	local auraCandidates: { ResourceFxRules.EmitterCandidate } = {}
	for _, info in ipairs(NodeVisuals.snapshot()) do
		local rarity = if info.rarity then ResourceVFXConfig.Rarities[info.rarity] else nil
		if rarity == nil or not info.available then
			continue
		end
		infos[info.nodeId] = info
		local distance = (info.ground - origin).Magnitude
		local style = rarity.idleParticles
		if style and (level == "full" or (level == "low" and style.lowQuality)) then
			table.insert(emitterCandidates, { id = info.nodeId, distance = distance, priority = rarity.priority })
		end
		if rarity.aura then
			table.insert(auraCandidates, { id = info.nodeId, distance = distance, priority = rarity.priority })
		end
	end

	local wanted = ResourceFxRules.allocateEmitters(
		emitterCandidates,
		ResourceVFXConfig.MaxIdleEmitters[level] or 0,
		ResourceVFXConfig.IdleParticleRadiusStuds
	)
	-- Garde les prêts encore voulus (pas de réinitialisation visible).
	local kept: { [string]: boolean } = {}
	for _, slot in ipairs(idleSlots) do
		local nodeId = slot.nodeId
		if nodeId and wanted[nodeId] then
			kept[nodeId] = true
		elseif nodeId then
			releaseIdle(slot)
		end
	end
	local particleEstimate = 0
	for nodeId in pairs(wanted) do
		if not kept[nodeId] then
			for _, slot in ipairs(idleSlots) do
				if slot.nodeId == nil then
					local info = infos[nodeId]
					local rarity = ResourceVFXConfig.Rarities[info.rarity :: string]
					assignIdle(slot, info, rarity.idleParticles :: ResourceVFXConfig.IdleParticles)
					break
				end
			end
		end
	end
	local active = 0
	for _, slot in ipairs(idleSlots) do
		if slot.nodeId then
			active += 1
			particleEstimate += slot.emitter.Rate * slot.emitter.Lifetime.Max
		end
	end

	local auras = ResourceFxRules.allocateEmitters(auraCandidates, ResourceVFXConfig.MaxAuras, ResourceVFXConfig.AuraRadiusStuds)
	local auraKept: { [string]: boolean } = {}
	for _, slot in ipairs(auraSlots) do
		local nodeId = slot.nodeId
		if nodeId and auras[nodeId] then
			auraKept[nodeId] = true
		elseif nodeId then
			slot.part.Transparency = 1
			slot.part.CFrame = PARKED
			slot.nodeId = nil
		end
	end
	local auraCount = 0
	for nodeId in pairs(auras) do
		if not auraKept[nodeId] then
			for _, slot in ipairs(auraSlots) do
				if slot.nodeId == nil then
					local info = infos[nodeId]
					local aura = (ResourceVFXConfig.Rarities[info.rarity :: string].aura) :: { diameter: number, height: number }
					slot.part.Size = Vector3.new(aura.height, aura.diameter, aura.diameter)
					-- Cylindre couché : axe X vertical.
					slot.part.CFrame = CFrame.new(info.ground + Vector3.new(0, aura.height / 2, 0))
						* CFrame.Angles(0, 0, math.rad(90))
					slot.part.Color = particleColor(info)
					slot.part.Transparency = 0
					slot.nodeId = nodeId
					break
				end
			end
		end
	end
	for _, slot in ipairs(auraSlots) do
		if slot.nodeId then
			auraCount += 1
		end
	end

	local now = os.clock()
	local activeBursts = 0
	for _, burst in ipairs(bursts) do
		if burst.busyUntil > now then
			activeBursts += 1
		end
	end
	folder:SetAttribute("IdleEmitters", active)
	folder:SetAttribute("Auras", auraCount)
	folder:SetAttribute("ActiveBursts", activeBursts)
	folder:SetAttribute("ParticleEstimate", math.floor(particleEstimate + 0.5))
end

-- Libère sans attendre l'émetteur et l'aura d'un nœud qui disparaît.
local function releaseNode(nodeId: string)
	for _, slot in ipairs(idleSlots) do
		if slot.nodeId == nodeId then
			releaseIdle(slot)
		end
	end
	for _, slot in ipairs(auraSlots) do
		if slot.nodeId == nodeId then
			slot.part.Transparency = 1
			slot.part.CFrame = PARKED
			slot.nodeId = nil
		end
	end
end

-- Éclats ---------------------------------------------------------------

local function acquireBurst(): Burst?
	local now = os.clock()
	for _, burst in ipairs(bursts) do
		if burst.busyUntil <= now then
			burst.busyUntil = now + ResourceVFXConfig.BurstLifetime[2] + 0.05
			return burst
		end
	end
	bump("BurstsSkipped")
	return nil
end

local function rarityOf(info: NodeVisuals.NodeInfo): ResourceVFXConfig.RarityVisual?
	return if info.rarity then ResourceVFXConfig.Rarities[info.rarity] else nil
end

-- Éclat de collecte : cône de particules du nœud vers le joueur local.
-- Appelé par FeedbackController après une réponse `ok` du serveur.
function ResourceVFXController.playCollect(node: BasePart, origin: CFrame, color: Color3)
	if not started then
		return
	end
	local info = NodeVisuals.infoFor(node)
	local rarity = if info then rarityOf(info) else nil
	if rarity == nil then
		return
	end
	local count = ResourceFxRules.burstCount(rarity.collectParticles, rarity.reducedCollectParticles, currentLevel())
	if count <= 0 then
		return
	end
	local burst = acquireBurst()
	if burst == nil then
		return
	end
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local position = origin.Position
	local target = if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 1.5, 0) else position + Vector3.new(0, 3, 0)
	if (target - position).Magnitude < 0.1 then
		target = position + Vector3.new(0, 3, 0)
	end
	burst.carrier.Size = Vector3.new(0.2, 0.2, 0.2)
	burst.carrier.CFrame = CFrame.lookAt(position, target)
	local emitter = burst.emitter
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.SpreadAngle = Vector2.new(ResourceVFXConfig.CollectSpreadDegrees, ResourceVFXConfig.CollectSpreadDegrees)
	emitter.Speed = range(ResourceVFXConfig.CollectSpeed)
	emitter.Color = ColorSequence.new(color:Lerp(WHITE, 0.5))
	emitter:Emit(count)
	bump("Bursts_collect")
end

-- Bouffée de reconstruction, à la réapparition décidée par le serveur.
local function playRespawn(info: NodeVisuals.NodeInfo)
	local rarity = rarityOf(info)
	if rarity == nil then
		return
	end
	local count = ResourceFxRules.burstCount(rarity.respawnParticles, rarity.reducedRespawnParticles, currentLevel())
	if count <= 0 then
		return
	end
	local burst = acquireBurst()
	if burst == nil then
		return
	end
	local height = nodeHeight(info)
	burst.carrier.Size = Vector3.new(height, 0.2, height)
	burst.carrier.CFrame = CFrame.new(info.ground + Vector3.new(0, 0.2, 0))
	local emitter = burst.emitter
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Speed = RESPAWN_SPEED
	emitter.Color = ColorSequence.new(particleColor(info))
	emitter:Emit(count)
	bump("Bursts_respawn")
end

function ResourceVFXController.start()
	assert(not started, "ResourceVFXController.start appelé deux fois")
	started = true

	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	buildPools()

	readQuality()
	pcall(function()
		UserSettings():GetService("UserGameSettings"):GetPropertyChangedSignal("SavedQualityLevel"):Connect(readQuality)
	end)

	NodeVisuals.onRespawn(function(info: NodeVisuals.NodeInfo)
		playRespawn(info)
		-- Émetteur et aura rendus au prochain rafraîchissement.
	end)
	NodeVisuals.onDisappear(function(info: NodeVisuals.NodeInfo)
		releaseNode(info.nodeId)
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(function(): any
				refresh()
				return nil
			end)
			if not ok then
				warn(`[ResourceVFX] rafraîchissement : {tostring(err)}`)
			end
			task.wait(ResourceVFXConfig.SelectionRefreshSeconds)
		end
	end)
end

return ResourceVFXController
