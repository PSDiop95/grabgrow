--!strict
-- Points d'arrivée des mondes (T8, D-021) : lit la carte et fournit au
-- serveur la position où placer un joueur qui voyage. Aucune règle d'accès
-- ici (WorldTravelService).
--
-- Points : BaseParts sous Workspace.WorldArrivals portant l'attribut texte
-- `ArrivalWorldId` (clé de WorldConfig). Édités dans Studio ou créés par les
-- scripts de construction des mondes (T8.2+). Ce ne sont PAS des
-- SpawnLocation : l'apparition reste dans le hub de Green Valley (D-021 D5).
-- Lu à chaque demande (quelques Parts, demandes limitées en fréquence) :
-- position serveur, jamais modifiable par un client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)

local WorldArrivals = {}

WorldArrivals.FOLDER_NAME = "WorldArrivals"
WorldArrivals.ATTRIBUTE = "ArrivalWorldId"

export type Position = { X: number, Y: number, Z: number }

-- Position d'arrivée du monde `worldId`, `heightStuds` au-dessus du dessus
-- du point ; nil si le monde est inconnu ou n'a pas de point d'arrivée.
-- Plusieurs points pour un même monde : le premier par nom (ordre stable).
function WorldArrivals.find(worldId: string, heightStuds: number): Position?
	if WorldConfig[worldId] == nil then
		return nil
	end
	local folder = Workspace:FindFirstChild(WorldArrivals.FOLDER_NAME)
	if folder == nil then
		return nil
	end
	local best: BasePart? = nil
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute(WorldArrivals.ATTRIBUTE) == worldId then
			local current = best
			if current == nil or descendant.Name < current.Name then
				best = descendant
			end
		end
	end
	if best == nil then
		return nil
	end
	local part = best :: BasePart
	local top = part.Position + Vector3.new(0, part.Size.Y / 2 + heightStuds, 0)
	return { X = top.X, Y = top.Y, Z = top.Z }
end

return WorldArrivals
