--!strict
-- Zones de vente dans le monde (T3) : lit les zones éditées dans Studio et
-- fournit leur position à SellService. Aucune règle de vente ici.
--
-- Zones : BaseParts sous Workspace.SellZones portant l'attribut texte
-- `SellZoneId` (unique). Carte de test : tools/studio/build_test_map.luau.
-- La position est lue sur le Part à chaque demande : c'est la position
-- serveur (le client ne peut pas la modifier pour le serveur).

local Workspace = game:GetService("Workspace")

local SellZones = {}

SellZones.FOLDER_NAME = "SellZones"
SellZones.ATTRIBUTE = "SellZoneId"

export type Zone = { position: { X: number, Y: number, Z: number } }

-- Enregistre les zones présentes. Retourne (getZone, nombre de zones).
function SellZones.start(): ((sellZoneId: string) -> Zone?, number)
	local parts: { [string]: BasePart } = {}
	local count = 0

	local folder = Workspace:FindFirstChild(SellZones.FOLDER_NAME)
	if folder == nil then
		warn(`[SellZones] Workspace.{SellZones.FOLDER_NAME} introuvable : aucune vente possible`)
	else
		for _, descendant in ipairs(folder:GetDescendants()) do
			local zoneId = descendant:GetAttribute(SellZones.ATTRIBUTE)
			if descendant:IsA("BasePart") and type(zoneId) == "string" and zoneId ~= "" then
				local existing: BasePart? = parts[zoneId]
				if existing ~= nil then
					warn(`[SellZones] identifiant en double ignoré : {zoneId} ({descendant:GetFullName()})`)
				else
					parts[zoneId] = descendant
					count += 1
				end
			end
		end
	end

	local function getZone(sellZoneId: string): Zone?
		local part: BasePart? = parts[sellZoneId]
		if part == nil or part.Parent == nil then
			return nil
		end
		local position = part.Position
		return { position = { X = position.X, Y = position.Y, Z = position.Z } }
	end

	return getZone, count
end

return SellZones
