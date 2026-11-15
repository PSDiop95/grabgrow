--!nocheck
-- Fixture TEMPORAIRE du test multijoueur T8.1 (Local Server) : point
-- d'arrivée de Green Valley, mini-île Golden Desert (sol, point d'arrivée,
-- 5 points de spawn, un par ressource du désert).
--
-- Outil de développement, absent du jeu. À exécuter dans Studio en mode
-- Edit AVANT de lancer le Local Server (ResourceNodes lit les points de
-- spawn au démarrage du serveur), puis à RETIRER après le test
-- (MODE = "remove"). Ne touche qu'aux instances nommées « T8Fixture_* ».
-- Ne pas enregistrer le place avec la fixture. Remplacée par les vraies
-- îles (T8.2 pour Green Valley, T8.3 pour Golden Desert).
-- OBSOLÈTE depuis T8.3 : l'île réelle occupe le même emplacement
-- (3000 ; 0 ; 0). Ne plus construire cette fixture.

local MODE = "build" -- "build" ou "remove"

local Workspace = game:GetService("Workspace")

local PREFIX = "T8Fixture_"
local DESERT_CENTER = Vector3.new(3000, 0, 0)

local function getFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function removeFixture(): number
	local removed = 0
	for _, folderName in ipairs({ "Map", "ResourceSpawnPoints", "WorldArrivals" }) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if string.sub(child.Name, 1, #PREFIX) == PREFIX then
					child:Destroy()
					removed += 1
				end
			end
			-- Dossier créé par la fixture et resté vide.
			if folderName == "WorldArrivals" and #folder:GetChildren() == 0 then
				folder:Destroy()
			end
		end
	end
	return removed
end

local removed = removeFixture()
if MODE == "remove" then
	return `Fixture T8 retirée ({removed} élément(s))`
end

local function part(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Sol de la mini-île Golden Desert.
local map = getFolder(Workspace, "Map")
part(PREFIX .. "GoldenDesertGround", Vector3.new(80, 2, 80), DESERT_CENTER - Vector3.new(0, 1, 0), Color3.fromRGB(230, 196, 120), map)

-- Points d'arrivée (lus par Systems/WorldArrivals).
local arrivals = getFolder(Workspace, "WorldArrivals")
local function arrival(worldId: string, position: Vector3)
	local p = part(PREFIX .. worldId, Vector3.new(6, 0.2, 6), position, Color3.fromRGB(120, 200, 255), arrivals)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 0.5
	p:SetAttribute("ArrivalWorldId", worldId)
end
arrival("GreenValley", Vector3.new(0, 0.1, 20))
arrival("GoldenDesert", DESERT_CENTER + Vector3.new(0, 0.1, 0))

-- Points de spawn du désert : un par ressource, à 6-20 studs de l'arrivée.
local spawnPoints = getFolder(Workspace, "ResourceSpawnPoints")
local folder = Instance.new("Folder")
folder.Name = PREFIX .. "GoldenDesert"
local offsets = {
	sandstone = Vector3.new(6, 0, 0),
	copper_ore = Vector3.new(-6, 0, 4),
	fossil = Vector3.new(0, 0, 10),
	gold_nugget = Vector3.new(12, 0, -10),
	sun_crystal = Vector3.new(-14, 0, -14),
}
for resourceType, offset in pairs(offsets) do
	local p = Instance.new("Part")
	p.Name = `Spawn_{resourceType}_01`
	p.Size = Vector3.new(1, 0.2, 1)
	p.Position = DESERT_CENTER + offset
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p:SetAttribute("ResourceType", resourceType)
	p.Parent = folder
end
folder.Parent = spawnPoints

return "Fixture T8 construite : 2 points d'arrivée, île Golden Desert, 5 points de spawn"
