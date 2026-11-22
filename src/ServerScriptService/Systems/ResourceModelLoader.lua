--!strict
-- Modèles 3D importés des ressources (T10.1, D-025 à D-027).
--
-- Pour chaque ressource dont ResourceVisualConfig déclare un `model`,
-- récupère la source : modèle du place (`template`, sous
-- ServerStorage.ResourceTemplates, import manuel Studio) ou asset Roblox
-- (`assetId`, InsertService:LoadAsset, asset du créateur de
-- l'expérience). La source n'est jamais modifiée : le gabarit normalisé
-- est une copie, publiée dans
-- ReplicatedStorage.ResourceModels.<resourceType>. Le client
-- (Controllers/NodeVisuals) en fait des clones locaux.
--
-- Purement visuel : aucun nœud, identifiant, position ni règle de collecte
-- n'est modifié. En cas d'échec, rien n'est publié pour cette ressource et
-- le client garde la forme primitive (repli, D-025).
--
-- Normalisation : pièces ancrées, sans collision, requête, contact ni
-- ombre ; échelle uniforme pour que la plus grande dimension vaille
-- `model.targetSize` studs ; pivot au centre du bas de la boîte
-- englobante ; couleurs, matériaux, agrandissement et exclusion
-- facultatifs par nom de pièce (`model.parts`). Provenance et licence : docs/assets/ASSET_MANIFEST.md.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ResourceVisualConfig = require(ReplicatedStorage.Shared.Config.ResourceVisualConfig)
local ResourceFxRules = require(ReplicatedStorage.Shared.Util.ResourceFxRules)

local ResourceModelLoader = {}

ResourceModelLoader.FOLDER_NAME = "ResourceModels"
ResourceModelLoader.TEMPLATE_FOLDER_NAME = "ResourceTemplates"

local ATTEMPTS = 3
local RETRY_SECONDS = 2

local started = false

local function loadAsset(assetId: number): (Model?, string?)
	local lastError = "inconnue"
	for attempt = 1, ATTEMPTS do
		local ok, result = pcall(function(): Model
			return InsertService:LoadAsset(assetId)
		end)
		if ok then
			return result, nil
		end
		lastError = tostring(result)
		if attempt < ATTEMPTS then
			task.wait(RETRY_SECONDS * attempt)
		end
	end
	return nil, lastError
end

-- Source du modèle : (conteneur, à détruire après usage ?) ou nil + raison.
local function loadSource(model: any): (Instance?, boolean, string?)
	if type(model.template) == "string" then
		local folder = ServerStorage:FindFirstChild(ResourceModelLoader.TEMPLATE_FOLDER_NAME)
		local source = if folder then folder:FindFirstChild(model.template) else nil
		if source == nil then
			return nil, false, `modèle ServerStorage.{ResourceModelLoader.TEMPLATE_FOLDER_NAME}.{model.template} absent`
		end
		return source, false, nil
	end
	local container, loadError = loadAsset(model.assetId)
	return container, true, loadError
end

-- Construit le gabarit à partir du conteneur chargé. nil + raison si
-- aucune pièce exploitable.
local function normalize(resourceType: string, container: Instance, model: any): (Model?, string?)
	local template = Instance.new("Model")
	template.Name = resourceType
	local count = 0
	for _, descendant in ipairs(container:GetDescendants()) do
		local override = if model.parts then model.parts[descendant.Name] else nil
		-- Pièces invisibles de la source (ex. RootPart ajouté par l'importeur
		-- 3D) et pièces exclues par la config : ignorées.
		local excluded = override ~= nil and override.exclude == true
		if descendant:IsA("BasePart") and descendant.Transparency < 1 and not excluded then
			local part = descendant:Clone()
			-- Pas de scripts, sons ni effets hérités de l'asset.
			for _, child in ipairs(part:GetChildren()) do
				if not child:IsA("SurfaceAppearance") and not child:IsA("Attachment") then
					child:Destroy()
				end
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.CFrame = descendant.CFrame
			if override then
				if override.color then
					part.Color = Color3.fromRGB(override.color[1], override.color[2], override.color[3])
				end
				if override.material then
					local okMaterial, material = pcall(function(): Enum.Material
						return (Enum.Material :: any)[override.material]
					end)
					if okMaterial then
						part.Material = material
					end
				end
				-- Agrandit la pièce autour de son centre, avant l'ajustement
				-- global à `targetSize` (ex. cristaux de l'améthyste).
				if override.scale then
					part.Size = part.Size * override.scale
				end
			end
			part.Parent = template
			count += 1
		end
	end
	if count == 0 then
		template:Destroy()
		return nil, "aucune pièce"
	end
	local boxCFrame, boxSize = template:GetBoundingBox()
	local scale = ResourceFxRules.fitScale({ boxSize.X, boxSize.Y, boxSize.Z }, model.targetSize)
	if scale == nil then
		template:Destroy()
		return nil, "boîte englobante vide"
	end
	template.WorldPivot = CFrame.new(boxCFrame.Position - Vector3.new(0, boxSize.Y / 2, 0))
	template:ScaleTo(scale)
	-- Pivot recalé au bas de la boîte après mise à l'échelle.
	local scaledCFrame, scaledSize = template:GetBoundingBox()
	template.WorldPivot = CFrame.new(scaledCFrame.Position - Vector3.new(0, scaledSize.Y / 2, 0))
	if model.assetId then
		template:SetAttribute("SourceAssetId", model.assetId)
	else
		template:SetAttribute("SourceTemplate", model.template)
	end
	template:SetAttribute("SourceScale", scale)
	return template, nil
end

-- Lance les chargements (asynchrones). Retourne le nombre de modèles
-- demandés ; le dossier est créé tout de suite pour le client.
function ResourceModelLoader.start(): number
	assert(not started, "ResourceModelLoader.start appelé deux fois")
	started = true

	local folder = Instance.new("Folder")
	folder.Name = ResourceModelLoader.FOLDER_NAME
	folder.Parent = ReplicatedStorage

	local requested = 0
	for resourceType, visual in pairs(ResourceVisualConfig) do
		local model = (visual :: any).model
		if model == nil or (type(model.assetId) ~= "number" and type(model.template) ~= "string") then
			continue
		end
		local sourceLabel = if model.template then `modèle {model.template}` else `asset {model.assetId}`
		requested += 1
		task.spawn(function()
			local container, owned, loadError = loadSource(model)
			if container == nil then
				warn(`[ResourceModelLoader] {resourceType} : {sourceLabel} non chargé ({loadError}) ; forme primitive conservée`)
				return
			end
			local template, reason = normalize(resourceType, container, model)
			if owned then
				container:Destroy()
			end
			if template == nil then
				warn(`[ResourceModelLoader] {resourceType} : {sourceLabel} inutilisable ({reason}) ; forme primitive conservée`)
				return
			end
			template.Parent = folder
		end)
	end
	return requested
end

return ResourceModelLoader
