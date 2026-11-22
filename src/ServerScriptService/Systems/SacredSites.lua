--!strict
-- Sites sacrés de la carte (T10.3) : lit Workspace.SacredSites une fois au
-- démarrage et fournit au serveur les positions de référence (centre de
-- l'arène, autel, nœuds sacrés). Aucune règle ici.
--
-- Structure (créée par tools/studio/build_sacred_sites.luau) :
--   Workspace.SacredSites.<siteId>        (Model, attribut SiteId)
--     Center   (Part invisible : position du gardien, centre de l'arène)
--     Altar    (Part : point d'activation)
--     Guardian (Model statique, commun à tous ; animé localement par chaque
--               client pour SON combat)
--     RewardZone/SacredNode_<n> (Parts, attributs SacredNodeId, SacredResourceId)
-- Positions lues sur le serveur : jamais fournies par un client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)

local SacredSites = {}

export type Position = { X: number, Y: number, Z: number }

export type Site = {
	siteId: string,
	guardianId: string,
	center: Position,
	altar: Position,
}

export type Node = {
	nodeId: string,
	siteId: string,
	resourceId: string,
	position: Position,
}

local function toPosition(vector: Vector3): Position
	return { X = vector.X, Y = vector.Y, Z = vector.Z }
end

-- Retourne (getSite, getNode, nombre de sites). Sites incomplets ignorés
-- avec un avertissement : le jeu démarre sans eux.
function SacredSites.start(): ((siteId: string) -> Site?, (nodeId: string) -> Node?, number)
	local sites: { [string]: Site } = {}
	local nodes: { [string]: Node } = {}
	local count = 0

	local folder = Workspace:FindFirstChild(GuardianConfig.MapFolderName)
	if folder == nil then
		warn(`[SacredSites] Workspace.{GuardianConfig.MapFolderName} absent : aucun site sacré`)
	else
		for siteId, definition in pairs(GuardianConfig.Sites) do
			local model = folder:FindFirstChild(siteId)
			local center = if model then model:FindFirstChild("Center") else nil
			local altar = if model then model:FindFirstChild("Altar") else nil
			if center == nil or altar == nil or not center:IsA("BasePart") or not altar:IsA("BasePart") then
				warn(`[SacredSites] site {siteId} incomplet (Center ou Altar manquant) : ignoré`)
				continue
			end
			sites[siteId] = {
				siteId = siteId,
				guardianId = definition.guardianId,
				center = toPosition(center.Position),
				altar = toPosition(altar.Position),
			}
			count += 1
			local zone = (model :: Instance):FindFirstChild("RewardZone")
			local children: { Instance } = if zone then zone:GetChildren() else {}
			for _, part in ipairs(children) do
				local nodeId = part:GetAttribute("SacredNodeId")
				local resourceId = part:GetAttribute("SacredResourceId")
				if part:IsA("BasePart") and type(nodeId) == "string" and type(resourceId) == "string" then
					nodes[nodeId] = {
						nodeId = nodeId,
						siteId = siteId,
						resourceId = resourceId,
						position = toPosition(part.Position),
					}
				end
			end
		end
	end

	local function getSite(siteId: string): Site?
		return sites[siteId]
	end
	local function getNode(nodeId: string): Node?
		return nodes[nodeId]
	end
	return getSite, getNode, count
end

return SacredSites
