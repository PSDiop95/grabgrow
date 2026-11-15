--!nocheck
-- Carte de Mystic World (T8.5, D-021) en primitives scriptées : archipel
-- d'îles flottantes reliées par des ponts suspendus. Île d'arrivée (vente,
-- portail de retour, repère du monde), forêt mystique, îles flottantes,
-- grotte spectrale, sanctuaire du Cœur mystique.
--
-- Outil de développement, absent du jeu (non mappé dans
-- default.project.json). À exécuter dans Roblox Studio en mode Edit (barre
-- de commande ou serveur MCP). Rejouable : remplace ce qu'il a créé pour
-- Mystic World, ne touche à rien d'autre (Green Valley, Golden Desert,
-- Frozen Peaks et Lighting sont préservés). Résultat identique à chaque
-- exécution (graine fixe). Aucun asset externe, aucun texte ni logo.
--
-- Crée (lus par le jeu) :
--   Workspace.Map.MysticWorld                     îles, ponts, zones, décor
--     Portals.GreenValley.Field                   attribut `PortalWorldId`
--   Workspace.WorldArrivals.MysticWorld           attribut `ArrivalWorldId`
--   Workspace.ResourceSpawnPoints.MysticWorld     40 points, `ResourceType`
--   Workspace.SellZones.MysticWorld               `SellZonePad`, `SellZoneId`
-- Aucune SpawnLocation : l'apparition reste au hub de Green Valley (D5).
-- Aucune surface sous l'archipel : une chute fait réapparaître au hub
-- (FallenPartsDestroyHeight, D5), comme la mer des autres îles. Les ponts
-- ont des garde-corps et l'île d'arrivée un muret de bord.
--
-- Valeurs, raretés et temps de réapparition : ResourceConfig (non lus ici,
-- sauf les poids de spawn pour le nombre de points). Apparence des nœuds :
-- ResourceVisualConfig (Systems/ResourceNodes).
--
-- Budget (audit T8) : ~1 200 parts de décor au plus, ~40 nœuds, aucune
-- lumière dynamique (plantes et cristaux en Neon), aucun émetteur dans le
-- décor, CastShadow désactivé, décor ancré, collisions simples (feuillage,
-- chapeaux de champignons, cascades, rochers flottants et champ du portail
-- sans collision). Lighting partagé par les quatre îles : non modifié.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)

local SEED = 20261117
local WORLD_ID = "MysticWorld"
local DECOR_BUDGET = 1200
-- Centre de l'archipel : au nord, loin de Green Valley (île et eau jusqu'à
-- |x|, |z| = 700) et des deux autres îles (x = ±3000).
local CENTER = Vector3.new(0, 0, 3000)

local TOTAL_SPAWN_POINTS = 40
local MIN_SPACING_STUDS = 6

-- Coordonnées locales (relatives à CENTER). +Z : nord, -Z : sud.
-- Îles : centre, rayon du dessus, hauteur du dessus. Ensemble contenu dans
-- environ 255 × 216 studs (cible audit : ~260 × 260).
local ISLANDS = {
	A = { name = "ZoneA_Arrival", center = Vector3.new(0, 0, -60), radius = 44, top = 0 },
	B = { name = "ZoneB_Forest", center = Vector3.new(-90, 0, -36), radius = 34, top = 0 },
	C1 = { name = "ZoneC_Isle1", center = Vector3.new(82, 0, -42), radius = 22, top = 0 },
	C2 = { name = "ZoneC_Isle2", center = Vector3.new(110, 0, 6), radius = 18, top = 0 },
	C3 = { name = "ZoneC_Isle3", center = Vector3.new(80, 0, 52), radius = 18, top = 0 },
	D = { name = "ZoneD_Cave", center = Vector3.new(-74, 0, 52), radius = 30, top = 0 },
	E = { name = "ZoneE_Sanctuary", center = Vector3.new(10, 0, 82), radius = 30, top = 4 },
}
local ISLAND_ORDER = { "A", "B", "C1", "C2", "C3", "D", "E" }
-- Boucle de ponts : A → forêt → grotte → sanctuaire → îles flottantes → A.
-- Le sanctuaire n'est pas relié directement à l'arrivée (découverte).
local BRIDGES = { { "A", "B" }, { "B", "D" }, { "D", "E" }, { "E", "C3" }, { "C3", "C2" }, { "C2", "C1" }, { "C1", "A" } }
local BRIDGE_WIDTH = 8

-- ZONE A — arrivée.
local PLAZA_CENTER = Vector3.new(0, 0, -66)
local PLAZA_RADIUS = 16
local ARRIVAL_POSITION = Vector3.new(0, 0.3, -56)
local PORTAL_POSITION = Vector3.new(0, 0, -90)
local SELL_ZONE_ID = "MysticWorld_Arrival"
local SELL_POSITION = Vector3.new(22, 0, -64)
local MARKER_POSITION = Vector3.new(-20, 0, -50)
-- Poudre mystique (Commune) : île d'arrivée, à moins de 38 studs de la vente.
local DUST_FROM_SELL = { min = 11, max = 37 }
-- Éclats d'étoile (Commune) posés sur l'île d'arrivée ; le reste en forêt.
local STAR_ON_ARRIVAL = 4
-- ZONE D — grotte spectrale : entrée au sud.
local CAVE_CENTER = Vector3.new(-78, 0, 60)
local CAVE_HALF = Vector3.new(9, 0, 10) -- intérieur 18 × 20 studs
local CAVE_HEIGHT = 11
local CAVE_FLOOR_TOP = 0.4
-- ZONE E — sanctuaire : estrade circulaire, rampe au sud.
local DAIS_CENTER = Vector3.new(10, 0, 86)
local DAIS_RADIUS = 13
local DAIS_HEIGHT = 3
local DAIS_RAMP_LENGTH = 14
local DAIS_RAMP_WIDTH = 10
local PEDESTAL_HEIGHT = 1

local COLORS = {
	grass = Color3.fromRGB(122, 196, 150), -- vert émeraude doux
	grassLavender = Color3.fromRGB(186, 166, 230),
	grassTeal = Color3.fromRGB(96, 196, 186),
	path = Color3.fromRGB(226, 214, 246),
	stone = Color3.fromRGB(150, 140, 190),
	stoneLight = Color3.fromRGB(206, 198, 236),
	stoneDark = Color3.fromRGB(92, 80, 140),
	rockDeep = Color3.fromRGB(70, 58, 118),
	rockNight = Color3.fromRGB(48, 44, 96),
	caveFloor = Color3.fromRGB(58, 50, 100),
	violet = Color3.fromRGB(128, 72, 255),
	violetLight = Color3.fromRGB(206, 140, 255),
	blue = Color3.fromRGB(70, 120, 255),
	cyan = Color3.fromRGB(80, 230, 240),
	turquoise = Color3.fromRGB(60, 200, 190),
	magenta = Color3.fromRGB(240, 80, 200),
	pink = Color3.fromRGB(255, 160, 220),
	white = Color3.fromRGB(246, 240, 255),
	trunk = Color3.fromRGB(110, 74, 120),
	water = Color3.fromRGB(120, 210, 250),
	wood = Color3.fromRGB(150, 110, 150),
	arrival = Color3.fromRGB(190, 150, 255),
	portal = Color3.fromRGB(116, 178, 92),
	gold = Color3.fromRGB(255, 196, 40),
}

local function getFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function replace(parent: Instance, name: string)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local function newFolder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local random = Random.new(SEED)
local partCount = 0

local function world(position: Vector3): Vector3
	return CENTER + position
end

local function horizontal(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
end

-- Part ancrée, sans ombre ; cframe en coordonnées locales. `solid = false` :
-- traversable, ignorée par les requêtes.
local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, solid: boolean?, class: string?): BasePart
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(CENTER) * cframe
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	if solid == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	partCount += 1
	return p
end

local function neon(p: BasePart): BasePart
	p.Material = Enum.Material.Neon
	return p
end

-- Disque plat (cylindre vertical), centre local.
local function disk(parent: Instance, name: string, diameter: number, thickness: number, center: Vector3, color: Color3, solid: boolean?): BasePart
	local p = part(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Colonne (cylindre vertical) posée sur `base`.
local function column(parent: Instance, name: string, diameter: number, height: number, base: Vector3, color: Color3, solid: boolean?): BasePart
	return disk(parent, name, diameter, height, base + Vector3.new(0, height / 2, 0), color, solid)
end

-- Rampe (WedgePart) : bas en `low`, haut en `high` (horizontaux), sol à
-- `baseY`, montée `rise`. Le bas d'un WedgePart est au -Z local.
local function ramp(parent: Instance, name: string, low: Vector3, high: Vector3, baseY: number, rise: number, width: number, color: Color3): BasePart
	local a, b = horizontal(low), horizontal(high)
	local center = (a + b) / 2 + Vector3.new(0, baseY + rise / 2, 0)
	return part(parent, name, Vector3.new(width, rise, (b - a).Magnitude), CFrame.lookAt(center, center + (a - b)), color, true, "WedgePart")
end

-- Footprints (cercles horizontaux) des volumes solides et des passages :
-- aucune ressource ni décor ne s'y pose.
local footprints: { { center: Vector3, radius: number } } = {}
local function reserve(center: Vector3, radius: number)
	table.insert(footprints, { center = horizontal(center), radius = radius })
end
local function inFootprint(position: Vector3, margin: number): boolean
	local flat = horizontal(position)
	for _, footprint in ipairs(footprints) do
		if (flat - footprint.center).Magnitude < footprint.radius + margin then
			return true
		end
	end
	return false
end
local function reserveLine(from: Vector3, to: Vector3, radius: number)
	local a, b = horizontal(from), horizontal(to)
	local length = (b - a).Magnitude
	for step = 0, math.ceil(length / 3) do
		reserve(a:Lerp(b, math.min(step * 3 / math.max(length, 0.01), 1)), radius)
	end
end

-- Île qui contient `position` à `margin` studs du bord au moins (ou nil).
local function islandAt(position: Vector3, margin: number)
	local flat = horizontal(position)
	for _, key in ipairs(ISLAND_ORDER) do
		local island = ISLANDS[key]
		if (flat - horizontal(island.center)).Magnitude < island.radius - margin then
			return island
		end
	end
	return nil
end

-- Bande plate (chemin) entre deux points locaux, posée sur le dessus `y`.
local function strip(parent: Instance, name: string, from: Vector3, to: Vector3, width: number, color: Color3, y: number)
	local t = 0.14
	local a, b = horizontal(from), horizontal(to)
	local middle = (a + b) / 2 + Vector3.new(0, y + t / 2, 0)
	part(parent, name, Vector3.new(width, t, (b - a).Magnitude + 1), CFrame.lookAt(middle, b + Vector3.new(0, y + t / 2, 0)), color)
	reserveLine(a, b, width / 2 + 0.5)
end

-- Grappe de cristaux Neon décoratifs (sans collision ni lumière).
local function crystalCluster(parent: Instance, name: string, base: Vector3, scale: number, colorA: Color3, colorB: Color3)
	local model = Instance.new("Model")
	model.Name = name
	for index = 1, 3 do
		local height = (2.2 + index * 0.7) * scale
		local tilt = CFrame.Angles(math.rad(random:NextNumber(-22, 22)), math.rad(random:NextNumber(0, 90)), math.rad(random:NextNumber(-22, 22)))
		local offset = Vector3.new(random:NextNumber(-0.8, 0.8), 0, random:NextNumber(-0.8, 0.8)) * scale
		neon(part(model, `Shard{index}`, Vector3.new(0.8 * scale, height, 0.8 * scale), CFrame.new(base + offset) * tilt * CFrame.new(0, height / 2 - 0.3, 0), if index == 2 then colorB else colorA, false))
	end
	model.Parent = parent
end

-- CORPS DES ÎLES ---------------------------------------------------------------

local map = getFolder(Workspace, "Map")
replace(map, WORLD_ID)
local root = Instance.new("Folder")
root.Name = WORLD_ID

local islandFolders = {}
local TOP_COLORS = { A = COLORS.grass, B = COLORS.grass, C1 = COLORS.grassTeal, C2 = COLORS.grassLavender, C3 = COLORS.grassTeal, D = COLORS.grassLavender, E = COLORS.grassLavender }
for _, key in ipairs(ISLAND_ORDER) do
	local island = ISLANDS[key]
	local folder = newFolder(root, island.name)
	islandFolders[key] = folder
	local c, r, top = island.center, island.radius, island.top
	-- Dessus (herbe), bord de pierre claire, puis dessous en couches
	-- octogonales de roche de plus en plus étroites (silhouette flottante).
	disk(folder, "Top", r * 2, 3, c + Vector3.new(0, top - 1.5, 0), TOP_COLORS[key])
	disk(folder, "Rim", r * 2 + 1.2, 2, c + Vector3.new(0, top - 3.4, 0), COLORS.stoneLight)
	local y = top - 4.4
	for layer, info in ipairs({ { 0.86, 5, COLORS.stone }, { 0.6, 6, COLORS.stoneDark }, { 0.34, 7, COLORS.rockDeep }, { 0.14, 6, COLORS.rockNight } }) do
		local width = r * 2 * info[1] / math.sqrt(2) * 1.25
		local height = info[2]
		for turn = 0, 1 do
			part(folder, `Under{layer}_{turn + 1}`, Vector3.new(width, height, width), CFrame.new(c + Vector3.new(0, y - height / 2, 0)) * CFrame.Angles(0, math.rad(turn * 45 + layer * 11), 0), info[3])
		end
		y -= height * 0.9
	end
end

-- PONTS SUSPENDUS ------------------------------------------------------------------

-- Pont entre deux îles : tablier de pierre (incliné si les hauteurs
-- diffèrent), bande centrale, garde-corps pleins des deux côtés, poteaux à
-- lanternes Neon et cordes décoratives (sans collision).
local bridgeHeads = {} -- [islandKey] = { point local sur l'île }
local bridgeFolder = newFolder(root, "Bridges")
for _, pair in ipairs(BRIDGES) do
	local from, to = ISLANDS[pair[1]], ISLANDS[pair[2]]
	local dir = (horizontal(to.center) - horizontal(from.center)).Unit
	local a = horizontal(from.center) + dir * (from.radius - 1.5) + Vector3.new(0, from.top, 0)
	local b = horizontal(to.center) - dir * (to.radius - 1.5) + Vector3.new(0, to.top, 0)
	local model = Instance.new("Model")
	model.Name = `Bridge_{pair[1]}_{pair[2]}`
	local deckThickness = 0.8
	local down = Vector3.new(0, deckThickness / 2, 0)
	local deck = CFrame.lookAt((a + b) / 2 - down, b - down)
	local length = (b - a).Magnitude
	part(model, "Deck", Vector3.new(BRIDGE_WIDTH, deckThickness, length), deck, COLORS.stoneLight)
	part(model, "Runner", Vector3.new(2.4, 0.1, length - 2), deck * CFrame.new(0, deckThickness / 2 + 0.05, 0), COLORS.violetLight)
	-- Garde-corps sur la portée au-dessus du vide (hors des îles).
	local span = length - 3
	for side = -1, 1, 2 do
		part(model, `Rail{side}`, Vector3.new(0.6, 1.4, span), deck * CFrame.new(side * (BRIDGE_WIDTH / 2 - 0.3), deckThickness / 2 + 0.7, 0), COLORS.stone)
		for endIndex = -1, 1, 2 do
			-- Poteaux verticaux, même sur un tablier incliné.
			local foot = (deck * CFrame.new(side * (BRIDGE_WIDTH / 2 - 0.3), deckThickness / 2, endIndex * (span / 2))).Position
			part(model, `Post{side}_{endIndex}`, Vector3.new(0.9, 6, 0.9), CFrame.new(foot + Vector3.new(0, 3, 0)), COLORS.stoneDark)
			local lantern = neon(part(model, `Lantern{side}_{endIndex}`, Vector3.new(1, 1, 1), CFrame.new(foot + Vector3.new(0, 6.5, 0)), if endIndex < 0 then COLORS.cyan else COLORS.magenta, false))
			lantern.Shape = Enum.PartType.Ball
			-- Corde : du haut du poteau vers le milieu du garde-corps.
			local top = foot + Vector3.new(0, 6, 0)
			local middle = (deck * CFrame.new(side * (BRIDGE_WIDTH / 2 - 0.3), deckThickness / 2 + 1.6, 0)).Position
			part(model, `Rope{side}_{endIndex}`, Vector3.new(0.2, 0.2, (middle - top).Magnitude), CFrame.lookAt((top + middle) / 2, middle), COLORS.wood, false)
		end
	end
	model.Parent = bridgeFolder
	bridgeHeads[pair[1]] = bridgeHeads[pair[1]] or {}
	bridgeHeads[pair[2]] = bridgeHeads[pair[2]] or {}
	table.insert(bridgeHeads[pair[1]], a)
	table.insert(bridgeHeads[pair[2]], b)
	-- Accès du pont dégagé (8 studs à l'intérieur de chaque île).
	reserveLine(a - dir * 8, b + dir * 8, BRIDGE_WIDTH / 2 + 1)
end

-- ZONE A — Île d'arrivée -----------------------------------------------------------

local zoneA = islandFolders.A
disk(zoneA, "Plaza", PLAZA_RADIUS * 2, 0.2, PLAZA_CENTER + Vector3.new(0, 0.1, 0), COLORS.path)
disk(zoneA, "PlazaInlay", 8, 0.06, PLAZA_CENTER + Vector3.new(0, 0.23, 0), COLORS.violetLight, false)
reserve(PLAZA_CENTER, PLAZA_RADIUS)
reserve(ARRIVAL_POSITION, 4)
reserve(SELL_POSITION, 9)

-- Portail de retour vers Green Valley (champ traversable lu par
-- TravelController) : piliers de pierre mystique, linteau vert, cristaux.
local portals = newFolder(root, "Portals")
do
	local model = Instance.new("Model")
	model.Name = "GreenValley"
	local p = PORTAL_POSITION
	part(model, "Step", Vector3.new(10, 0.6, 4), CFrame.new(p + Vector3.new(0, 0.3, 0)), COLORS.stoneLight)
	part(model, "PillarLeft", Vector3.new(1.8, 10, 1.8), CFrame.new(p + Vector3.new(-4.2, 5.6, 0)), COLORS.stone)
	part(model, "PillarRight", Vector3.new(1.8, 10, 1.8), CFrame.new(p + Vector3.new(4.2, 5.6, 0)), COLORS.stone)
	part(model, "Lintel", Vector3.new(10, 1.6, 2), CFrame.new(p + Vector3.new(0, 11.4, 0)), COLORS.portal)
	neon(part(model, "LintelGem", Vector3.new(1.2, 1.2, 1.2), CFrame.new(p + Vector3.new(0, 12.8, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0), COLORS.cyan, false))
	local field = part(model, "Field", Vector3.new(6.8, 9.6, 0.4), CFrame.new(p + Vector3.new(0, 5.4, 0)), COLORS.portal, false)
	field.Transparency = 0.35
	field.CanQuery = true
	field:SetAttribute("PortalWorldId", "GreenValley")
	model.PrimaryPart = field
	model.Parent = portals
	reserve(p, 7)
end

-- Repère du monde : obélisque de cristal violet sur socle, pierres en
-- orbite (sans texte ni logo), visible depuis l'arrivée.
do
	local model = Instance.new("Model")
	model.Name = "WorldMarker"
	local m = MARKER_POSITION
	column(model, "Plinth", 6, 1.2, m, COLORS.stoneLight)
	column(model, "PlinthTop", 4.4, 0.6, m + Vector3.new(0, 1.2, 0), COLORS.stone)
	neon(part(model, "Obelisk", Vector3.new(1.8, 9, 1.8), CFrame.new(m + Vector3.new(0, 6.3, 0)) * CFrame.Angles(0, math.rad(45), 0), COLORS.violet))
	neon(part(model, "ObeliskTip", Vector3.new(1.3, 1.3, 1.3), CFrame.new(m + Vector3.new(0, 11.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), COLORS.pink, false))
	for index = 0, 3 do
		local angle = math.rad(index * 90 + 20)
		part(model, `Orbit{index + 1}`, Vector3.new(1.2, 0.9, 1.2), CFrame.new(m + Vector3.new(math.cos(angle) * 3.2, 5 + index * 1.2, math.sin(angle) * 3.2)) * CFrame.Angles(0, angle, math.rad(20)), COLORS.stoneDark, false)
	end
	model.Parent = zoneA
	reserve(m, 4)
end

-- Poteau indicateur à trois flèches de couleur (violet : grotte, cyan :
-- îles flottantes, magenta : sanctuaire), sans texte.
local SIGN_POSITION = Vector3.new(-9, 0, -56)
do
	local sign = Instance.new("Model")
	sign.Name = "Signpost"
	part(sign, "Post", Vector3.new(0.6, 6, 0.6), CFrame.new(SIGN_POSITION + Vector3.new(0, 3, 0)), COLORS.trunk)
	for _, info in ipairs({
		{ name = "ToForestCave", target = ISLANDS.B.center, color = COLORS.violet, y = 5.2 },
		{ name = "ToIsles", target = ISLANDS.C1.center, color = COLORS.cyan, y = 4.2 },
		{ name = "ToSanctuary", target = ISLANDS.E.center, color = COLORS.magenta, y = 3.2 },
	}) do
		local from = SIGN_POSITION + Vector3.new(0, info.y, 0)
		local direction = (horizontal(info.target) - horizontal(SIGN_POSITION)).Unit
		local look = CFrame.lookAt(from + direction * 1.6, from + direction * 3)
		part(sign, info.name, Vector3.new(0.3, 0.7, 2.6), look, info.color)
		part(sign, `{info.name}Tip`, Vector3.new(0.3, 0.7, 0.7), look * CFrame.new(0, 0, -1.6), info.color, true, "WedgePart")
	end
	sign.Parent = zoneA
	reserve(SIGN_POSITION, 1.5)
end

-- Chemins de l'île d'arrivée : place → têtes de pont (ouest, est).
for index, head in ipairs(bridgeHeads.A) do
	strip(zoneA, `Path{index}`, PLAZA_CENTER + (horizontal(head) - PLAZA_CENTER).Unit * (PLAZA_RADIUS - 1), head, 6, COLORS.path, 0)
end

-- Muret de bord de l'île d'arrivée (1,6 stud), ouvert aux têtes de pont.
local function nearBridgeHead(key: string, position: Vector3, clearance: number): boolean
	for _, head in ipairs(bridgeHeads[key] or {}) do
		if (horizontal(head) - horizontal(position)).Magnitude < clearance then
			return true
		end
	end
	return false
end
do
	local a = ISLANDS.A
	local segments = 36
	for index = 0, segments - 1 do
		local angle = (index + 0.5) * 2 * math.pi / segments
		local position = a.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (a.radius - 0.8)
		if not nearBridgeHead("A", position, BRIDGE_WIDTH / 2 + 3) then
			local length = 2 * math.pi * (a.radius - 0.8) / segments + 0.2
			part(zoneA, `EdgeWall{index + 1}`, Vector3.new(1.2, 1.6, length), CFrame.lookAt(position + Vector3.new(0, 0.8, 0), a.center + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.rad(90), 0), if index % 2 == 0 then COLORS.stoneLight else COLORS.stone)
		end
	end
end

-- ZONE E — Sanctuaire mystique ------------------------------------------------------

local zoneE = islandFolders.E
local eTop = ISLANDS.E.top
local daisTop = eTop + DAIS_HEIGHT
do
	disk(zoneE, "Dais", DAIS_RADIUS * 2, DAIS_HEIGHT, DAIS_CENTER + Vector3.new(0, eTop + DAIS_HEIGHT / 2, 0), COLORS.stoneLight)
	disk(zoneE, "DaisInlay", DAIS_RADIUS * 2 - 4, 0.08, DAIS_CENTER + Vector3.new(0, daisTop + 0.04, 0), COLORS.path, false)
	disk(zoneE, "DaisRing", 10, 0.1, DAIS_CENTER + Vector3.new(0, daisTop + 0.1, 0), COLORS.violetLight, false)
	-- Rampe d'accès au sud (environ 12°), large de 10 studs.
	local rampHigh = DAIS_CENTER + Vector3.new(0, 0, -DAIS_RADIUS + 1)
	local rampLow = rampHigh + Vector3.new(0, 0, -DAIS_RAMP_LENGTH)
	ramp(zoneE, "DaisRamp", rampLow, rampHigh, eTop, DAIS_HEIGHT, DAIS_RAMP_WIDTH, COLORS.stone)
	reserve(DAIS_CENTER, DAIS_RADIUS + 3)
	reserveLine(rampLow + Vector3.new(0, 0, -4), rampHigh, DAIS_RAMP_WIDTH / 2 + 1.5)
	-- Chemin du pied de la rampe vers les deux têtes de pont.
	for index, head in ipairs(bridgeHeads.E) do
		strip(zoneE, `Path{index}`, head, rampLow + Vector3.new(0, 0, -2), 6, COLORS.path, eTop)
	end
	-- Grande arche au sommet de la rampe.
	local archZ = DAIS_CENTER.Z - DAIS_RADIUS + 2.5
	for side = -1, 1, 2 do
		local base = Vector3.new(DAIS_CENTER.X + side * 6.5, daisTop, archZ)
		part(zoneE, `ArchPillar{side}`, Vector3.new(2, 11, 2), CFrame.new(base + Vector3.new(0, 5.5, 0)), COLORS.stone)
		part(zoneE, `ArchFoot{side}`, Vector3.new(2.8, 1, 2.8), CFrame.new(base + Vector3.new(0, 0.5, 0)), COLORS.stoneDark)
	end
	part(zoneE, "ArchLintel", Vector3.new(16, 1.8, 2.4), CFrame.new(DAIS_CENTER.X, daisTop + 11.9, archZ), COLORS.stoneLight)
	neon(part(zoneE, "ArchGem", Vector3.new(1.6, 1.6, 1.6), CFrame.new(DAIS_CENTER.X, daisTop + 13.6, archZ) * CFrame.Angles(math.rad(45), math.rad(45), 0), COLORS.magenta, false))
	-- Couronne de colonnes (le sud reste ouvert pour l'arche), coiffées de
	-- cristaux Neon ; deux colonnes brisées (ruines).
	for index = 0, 7 do
		-- 270° = sud ; les indices 0 et 7 (de part et d'autre de l'arche)
		-- sont omis : passage dégagé.
		local angle = math.rad(270 + 22.5 + index * 45)
		local base = DAIS_CENTER + Vector3.new(math.cos(angle) * (DAIS_RADIUS - 1.6), daisTop, math.sin(angle) * (DAIS_RADIUS - 1.6))
		if index ~= 0 and index ~= 7 then
			local broken = index == 2 or index == 5
			local height = if broken then 4.5 else 9
			column(zoneE, `Column{index}`, 1.8, height, base, COLORS.stone)
			part(zoneE, `ColumnCap{index}`, Vector3.new(2.4, 0.8, 2.4), CFrame.new(base + Vector3.new(0, height + 0.4, 0)), COLORS.stoneLight)
			if not broken then
				neon(part(zoneE, `ColumnGem{index}`, Vector3.new(1, 1.6, 1), CFrame.new(base + Vector3.new(0, height + 1.6, 0)) * CFrame.Angles(0, math.rad(45), 0), if index % 2 == 0 then COLORS.cyan else COLORS.violet, false))
			end
		end
	end
	-- Piédestal du Cœur mystique et couronne de cristaux.
	local s = DAIS_CENTER + Vector3.new(0, daisTop, 0)
	column(zoneE, "Pedestal", 4, PEDESTAL_HEIGHT, s, COLORS.white)
	column(zoneE, "PedestalBase", 5.6, 0.4, s, COLORS.stoneDark)
	for index = 0, 5 do
		local angle = math.rad(index * 60 + 30)
		crystalCluster(zoneE, `Crown{index + 1}`, s + Vector3.new(math.cos(angle) * 4.2, 0, math.sin(angle) * 4.2), 0.6, if index % 2 == 0 then COLORS.violet else COLORS.magenta, COLORS.cyan)
	end
	-- Pierres suspendues au-dessus du piédestal (statiques, sans collision).
	for index = 0, 4 do
		local angle = math.rad(index * 72)
		part(zoneE, `HaloStone{index + 1}`, Vector3.new(1.1, 0.8, 1.1), CFrame.new(s + Vector3.new(math.cos(angle) * 3.4, 6.5, math.sin(angle) * 3.4)) * CFrame.Angles(math.rad(20), angle, 0), COLORS.stoneLight, false)
	end
	-- Point de vue panoramique au nord : terrasse et muret bas.
	local view = ISLANDS.E.center + Vector3.new(0, 0, ISLANDS.E.radius - 5)
	for index = -3, 3 do
		local angle = math.rad(90 + index * 9)
		local position = ISLANDS.E.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (ISLANDS.E.radius - 1)
		part(zoneE, `ViewWall{index + 4}`, Vector3.new(1, 1.4, 4.9), CFrame.lookAt(position + Vector3.new(0, eTop + 0.7, 0), ISLANDS.E.center + Vector3.new(0, eTop + 0.7, 0)) * CFrame.Angles(0, math.rad(90), 0), COLORS.stoneLight)
	end
	disk(zoneE, "ViewTerrace", 12, 0.12, view + Vector3.new(0, eTop + 0.06, 0), COLORS.path)
	reserve(view, 6)
	-- Grands cristaux aux abords de l'estrade.
	for index, offset in ipairs({ Vector3.new(-17, 0, -2), Vector3.new(17, 0, -2), Vector3.new(-10, 0, 15), Vector3.new(12, 0, 15) }) do
		crystalCluster(zoneE, `GreatCrystal{index}`, DAIS_CENTER + offset + Vector3.new(0, eTop, 0), 1.6, if index <= 2 then COLORS.violet else COLORS.blue, COLORS.pink)
		reserve(DAIS_CENTER + offset, 3)
	end
end
local coreSpot = DAIS_CENTER + Vector3.new(0, daisTop + PEDESTAL_HEIGHT, 0)

-- ZONE D — Grotte spectrale ---------------------------------------------------------

local zoneD = islandFolders.D
local purpleSpots = {}
do
	local c = CAVE_CENTER
	local hx, hz = CAVE_HALF.X, CAVE_HALF.Z
	part(zoneD, "CaveFloor", Vector3.new(hx * 2, CAVE_FLOOR_TOP, hz * 2), CFrame.new(c + Vector3.new(0, CAVE_FLOOR_TOP / 2, 0)), COLORS.caveFloor)
	part(zoneD, "WallWest", Vector3.new(4, CAVE_HEIGHT, hz * 2 + 4), CFrame.new(c + Vector3.new(-hx - 2, CAVE_HEIGHT / 2, 2)), COLORS.rockDeep)
	part(zoneD, "WallEast", Vector3.new(4, CAVE_HEIGHT, hz * 2 + 4), CFrame.new(c + Vector3.new(hx + 2, CAVE_HEIGHT / 2, 2)), COLORS.rockDeep)
	part(zoneD, "WallBack", Vector3.new(hx * 2 + 8, CAVE_HEIGHT, 4), CFrame.new(c + Vector3.new(0, CAVE_HEIGHT / 2, hz + 2)), COLORS.rockDeep)
	part(zoneD, "Roof", Vector3.new(hx * 2 + 10, 4, hz * 2 + 8), CFrame.new(c + Vector3.new(0, CAVE_HEIGHT + 2, 2)), COLORS.stoneDark)
	-- Masse rocheuse au-dessus (silhouette), colonnes et formations.
	part(zoneD, "MassTop1", Vector3.new(20, 7, 18), CFrame.new(c + Vector3.new(-1, CAVE_HEIGHT + 7, 4)) * CFrame.Angles(0, math.rad(30), 0), COLORS.rockDeep)
	part(zoneD, "MassTop2", Vector3.new(11, 7, 10), CFrame.new(c + Vector3.new(-2, CAVE_HEIGHT + 13, 6)) * CFrame.Angles(0, math.rad(55), math.rad(6)), COLORS.stoneDark)
	neon(part(zoneD, "MassCrystal", Vector3.new(2, 7, 2), CFrame.new(c + Vector3.new(-2, CAVE_HEIGHT + 19, 6)) * CFrame.Angles(math.rad(10), math.rad(45), 0), COLORS.violet, false))
	local front = c.Z - hz
	for side = -1, 1, 2 do
		-- Colonnes rocheuses d'entrée et cristaux d'encadrement (repère).
		part(zoneD, `EntranceRock{side}`, Vector3.new(4, 10, 4), CFrame.new(c.X + side * (hx + 1.5), 5, front - 1) * CFrame.Angles(0, math.rad(side * 12), math.rad(side * -4)), COLORS.stoneDark)
		crystalCluster(zoneD, `EntranceCrystal{side}`, Vector3.new(c.X + side * (hx + 4.5), 0, front - 3), 1.5, COLORS.violet, COLORS.cyan)
	end
	part(zoneD, "EntranceLintel", Vector3.new(hx * 2 + 8, 2, 3), CFrame.new(c.X, CAVE_HEIGHT - 1, front - 0.5), COLORS.rockDeep)
	-- Stalactites cristallines (sans collision).
	for index = 0, 4 do
		local x = c.X - hx + 2 + index * 3.5
		local length = random:NextNumber(1.4, 2.6)
		neon(part(zoneD, `Stalactite{index + 1}`, Vector3.new(0.6, length, 0.6), CFrame.new(x, CAVE_HEIGHT - 2 - length / 2, front + 1) * CFrame.Angles(0, math.rad(45), 0), if index % 2 == 0 then COLORS.violetLight else COLORS.cyan, false))
	end
	-- Cristaux et plantes bioluminescentes le long des parois.
	for index, offset in ipairs({
		Vector3.new(-7.5, 0, -3), Vector3.new(-7.5, 0, 4), Vector3.new(-7.5, 0, 8.5),
		Vector3.new(7.5, 0, -1), Vector3.new(7.5, 0, 6), Vector3.new(0, 0, 8.5),
	}) do
		crystalCluster(zoneD, `WallCrystal{index}`, c + offset + Vector3.new(0, CAVE_FLOOR_TOP, 0), random:NextNumber(0.9, 1.3), if index % 2 == 0 then COLORS.violet else COLORS.blue, COLORS.cyan)
	end
	-- Plateformes de collecte (dalles basses) sous les cristaux violets.
	for index, offset in ipairs({ Vector3.new(-3.5, 0, -5), Vector3.new(3.5, 0, -2), Vector3.new(-3, 0, 4), Vector3.new(3.5, 0, 5) }) do
		local base = c + offset
		disk(zoneD, `Platform{index}`, 3.6, 0.3, base + Vector3.new(0, CAVE_FLOOR_TOP + 0.15, 0), COLORS.stoneLight)
		table.insert(purpleSpots, base + Vector3.new(0, CAVE_FLOOR_TOP + 0.3, 0))
	end
	-- Toute la grotte réservée (murs, intérieur) ; chemin d'entrée.
	for x = -hx - 4, hx + 4, 4 do
		for z = -hz - 2, hz + 4, 4 do
			reserve(c + Vector3.new(x, 0, z), 3)
		end
	end
	for side = -1, 1, 2 do
		reserve(Vector3.new(c.X + side * (hx + 4.5), 0, front - 3), 3)
	end
	strip(zoneD, "PathCave", bridgeHeads.D[1], Vector3.new(c.X, 0, front - 1), 6, COLORS.path, 0)
	strip(zoneD, "PathSanctuary", Vector3.new(c.X + 8, 0, front - 6), bridgeHeads.D[2], 6, COLORS.path, 0)
end

-- CHEMINS DES AUTRES ÎLES (têtes de pont reliées entre elles) ----------------------

for _, key in ipairs({ "B", "C1", "C2", "C3" }) do
	local heads = bridgeHeads[key]
	local island = ISLANDS[key]
	for index, head in ipairs(heads) do
		strip(islandFolders[key], `Path{index}`, head, island.center, 5, COLORS.path, 0)
	end
	disk(islandFolders[key], "Clearing", 9, 0.16, island.center + Vector3.new(0, 0.08, 0), COLORS.path)
	reserve(island.center, 4.5)
end

-- CASCADES : bassin, ruisseau jusqu'au bord, chute dans le vide -----------------------

local function waterfall(key: string, angleDeg: number, poolFraction: number, name: string)
	local island = ISLANDS[key]
	local folder = islandFolders[key]
	local dir = Vector3.new(math.cos(math.rad(angleDeg)), 0, math.sin(math.rad(angleDeg)))
	local pool = island.center + dir * (island.radius * poolFraction)
	local edge = island.center + dir * (island.radius + 1.4)
	disk(folder, `{name}Pool`, 7, 0.18, pool + Vector3.new(0, island.top + 0.09, 0), COLORS.water)
	strip(folder, `{name}Stream`, pool, island.center + dir * (island.radius - 0.2), 3, COLORS.water, island.top + 0.02)
	local fallHeight = 34
	local fall = part(folder, `{name}Fall`, Vector3.new(3, fallHeight, 0.8), CFrame.lookAt(edge + Vector3.new(0, island.top - fallHeight / 2 + 0.2, 0), edge + dir + Vector3.new(0, island.top - fallHeight / 2 + 0.2, 0)), COLORS.water, false)
	fall.Transparency = 0.2
	reserve(pool, 4.5)
end
waterfall("B", 200, 0.55, "Falls")
waterfall("C2", 10, 0.5, "Falls")
waterfall("E", 150, 0.75, "Falls")

-- POINTS DE SPAWN ------------------------------------------------------------------

-- 40 points répartis selon spawnWeight (plus forts restes) : 16/12/7/4/1.
local counts = {}
do
	local types, totalWeight = {}, 0
	for resourceType, definition in pairs(ResourceConfig) do
		if definition.worldId == WORLD_ID then
			table.insert(types, resourceType)
			totalWeight += definition.spawnWeight
		end
	end
	table.sort(types)
	local assigned, remainders = 0, {}
	for _, resourceType in ipairs(types) do
		local exact = TOTAL_SPAWN_POINTS * ResourceConfig[resourceType].spawnWeight / totalWeight
		counts[resourceType] = math.floor(exact)
		assigned += counts[resourceType]
		table.insert(remainders, { id = resourceType, rest = exact - math.floor(exact) })
	end
	table.sort(remainders, function(a, b)
		if a.rest ~= b.rest then
			return a.rest > b.rest
		end
		return a.id < b.id
	end)
	for index = 1, TOTAL_SPAWN_POINTS - assigned do
		counts[remainders[index].id] += 1
	end
end
assert(counts.purple_crystal == #purpleSpots, `Cristal violet : {counts.purple_crystal} point(s), {#purpleSpots} emplacements`)
assert(counts.mystic_core == 1, `Cœur mystique : {counts.mystic_core} point(s), 1 attendu`)

local placed: { Vector3 } = {}
local function isFree(position: Vector3, spacing: number): boolean
	for _, other in ipairs(placed) do
		if (horizontal(other) - horizontal(position)).Magnitude < spacing then
			return false
		end
	end
	return true
end

local spawnRoot = getFolder(Workspace, "ResourceSpawnPoints")
replace(spawnRoot, WORLD_ID)
local pointFolder = Instance.new("Folder")
pointFolder.Name = WORLD_ID

local function spawnPoint(resourceType: string, index: number, position: Vector3)
	local point = Instance.new("Part")
	point.Name = string.format("Spawn_%s_%02d", resourceType, index)
	point.Size = Vector3.new(1, 0.2, 1)
	point.Position = world(position)
	point.Anchored = true
	point.Transparency = 1
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point:SetAttribute("ResourceType", resourceType)
	point.Parent = pointFolder
	table.insert(placed, position)
end

-- Point libre sur l'île `key` (marge 6 studs du bord), hauteur du dessus.
local function islandPoint(key: string, accept: ((Vector3) -> boolean)?, what: string): Vector3
	local island = ISLANDS[key]
	for _ = 1, 1500 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local radius = math.sqrt(random:NextNumber()) * (island.radius - 6)
		local candidate = island.center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if islandAt(candidate, 6) == island and not inFootprint(candidate, 2.5) and isFree(candidate, MIN_SPACING_STUDS) and (accept == nil or accept(candidate)) then
			return candidate + Vector3.new(0, island.top, 0)
		end
	end
	error(`aucune place libre pour {what}`)
end

local function distanceToSell(position: Vector3): number
	return (horizontal(position) - horizontal(SELL_POSITION)).Magnitude
end

-- Poudre mystique (Commune) : île d'arrivée, à moins de 38 studs de la vente.
for index = 1, counts.mystic_dust do
	spawnPoint("mystic_dust", index, islandPoint("A", function(candidate)
		local distance = distanceToSell(candidate)
		return distance >= DUST_FROM_SELL.min and distance <= DUST_FROM_SELL.max
	end, "mystic_dust"))
end
-- Éclats d'étoile (Commune) : moitié ouest de l'île d'arrivée (au-delà de
-- la zone de la Poudre) et moitié est de la forêt, côté pont, pour rester
-- près de la vente.
for index = 1, counts.star_fragment do
	local onArrival = index <= STAR_ON_ARRIVAL
	spawnPoint("star_fragment", index, if onArrival
		then islandPoint("A", function(candidate)
			return candidate.X < -6 and distanceToSell(candidate) > DUST_FROM_SELL.max
		end, "star_fragment")
		else islandPoint("B", function(candidate)
			return candidate.X > ISLANDS.B.center.X - 4
		end, "star_fragment"))
end
-- Minerai spectral (Peu commune) : îles flottantes (3 / 2 / 2).
do
	local plan = { { "C1", 3 }, { "C2", 2 }, { "C3", 2 } }
	local index = 0
	for _, entry in ipairs(plan) do
		for _ = 1, entry[2] do
			index += 1
			spawnPoint("spectral_ore", index, islandPoint(entry[1], nil, "spectral_ore"))
		end
	end
	assert(index == counts.spectral_ore, `Minerai spectral : {counts.spectral_ore} point(s), {index} prévus`)
end
-- Cristaux violets (Rare) : plateformes de la grotte spectrale.
for index, position in ipairs(purpleSpots) do
	spawnPoint("purple_crystal", index, position)
end
-- Cœur mystique (Épique) : piédestal du sanctuaire.
spawnPoint("mystic_core", 1, coreSpot)
pointFolder.Parent = spawnRoot

-- DÉCOR (graine fixe, à l'écart des ressources, chemins et zones) -----------------

local decor = newFolder(root, "Decor")

local function decorPoint(key: string, clearance: number, margin: number?): Vector3?
	local island = ISLANDS[key]
	for _ = 1, 400 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local radius = math.sqrt(random:NextNumber()) * (island.radius - (margin or 4))
		local candidate = island.center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if islandAt(candidate, margin or 4) == island and not inFootprint(candidate, 2) and isFree(candidate, clearance) then
			return candidate + Vector3.new(0, island.top, 0)
		end
	end
	return nil
end

-- Arbre fantastique : tronc incliné, deux à trois houppiers ronds (sans
-- collision), fruits lumineux Neon.
local CANOPY_COLORS = { COLORS.magenta, COLORS.turquoise, COLORS.violetLight, COLORS.pink }
local function tree(parent: Instance, name: string, base: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = name
	local lean = CFrame.Angles(math.rad(random:NextNumber(-8, 8)), 0, math.rad(random:NextNumber(-8, 8)))
	local trunkHeight = 6 * scale
	local trunk = CFrame.new(base) * lean * CFrame.new(0, trunkHeight / 2, 0)
	part(model, "Trunk", Vector3.new(1.1 * scale, trunkHeight, 1.1 * scale), trunk * CFrame.Angles(0, math.rad(45), 0), COLORS.trunk)
	local top = (trunk * CFrame.new(0, trunkHeight / 2, 0)).Position
	local color = CANOPY_COLORS[random:NextInteger(1, #CANOPY_COLORS)]
	for index = 1, 2 do
		local size = (5.2 - index * 1.3) * scale
		local canopy = part(model, `Canopy{index}`, Vector3.new(size, size, size), CFrame.new(top + Vector3.new(random:NextNumber(-0.8, 0.8), (index - 1) * 2.4 * scale, random:NextNumber(-0.8, 0.8))), if index == 1 then color else COLORS.violetLight, false)
		canopy.Shape = Enum.PartType.Ball
	end
	local fruit = neon(part(model, "Glow", Vector3.new(0.8, 0.8, 0.8) * scale, CFrame.new(top + Vector3.new(1.6 * scale, -1.2 * scale, 0.4)), COLORS.cyan, false))
	fruit.Shape = Enum.PartType.Ball
	model.Parent = parent
	reserve(base, 1.4 * scale)
end

-- Champignon stylisé : pied solide, chapeau plat sans collision, point Neon.
local function mushroom(parent: Instance, name: string, base: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = name
	local height = 3.2 * scale
	column(model, "Stem", 1 * scale, height, base, COLORS.white)
	disk(model, "Cap", 4.2 * scale, 1 * scale, base + Vector3.new(0, height + 0.3 * scale, 0), if random:NextNumber() < 0.5 then COLORS.magenta else COLORS.violet, false)
	neon(part(model, "Spot", Vector3.new(0.7, 0.3, 0.7) * scale, CFrame.new(base + Vector3.new(0.6 * scale, height + 0.9 * scale, 0.3 * scale)), COLORS.pink, false))
	model.Parent = parent
	reserve(base, 0.9 * scale)
end

-- Plante lumineuse : tige et bulbe Neon (sans collision).
local BULB_COLORS = { COLORS.cyan, COLORS.pink, COLORS.violetLight }
local function glowPlant(parent: Instance, name: string, base: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = name
	local height = random:NextNumber(1.2, 2.2) * scale
	part(model, "Stem", Vector3.new(0.25, height, 0.25), CFrame.new(base + Vector3.new(0, height / 2, 0)), COLORS.turquoise, false)
	local bulb = neon(part(model, "Bulb", Vector3.new(0.7, 0.7, 0.7) * scale, CFrame.new(base + Vector3.new(0, height + 0.2, 0)), BULB_COLORS[random:NextInteger(1, #BULB_COLORS)], false))
	bulb.Shape = Enum.PartType.Ball
	model.Parent = parent
end

-- Ruine : colonne brisée et bloc tombé.
local function ruin(parent: Instance, name: string, base: Vector3)
	local model = Instance.new("Model")
	model.Name = name
	local height = random:NextNumber(2.5, 5)
	column(model, "Column", 1.6, height, base, COLORS.stoneLight)
	part(model, "Block", Vector3.new(2.2, 1.2, 1.6), CFrame.new(base + Vector3.new(2, 0.6, 0.8)) * CFrame.Angles(0, math.rad(random:NextNumber(0, 60)), math.rad(8)), COLORS.stone)
	model.Parent = parent
	reserve(base, 2.4)
end

local function edgeRock(parent: Instance, name: string, base: Vector3, size: number)
	local s = Vector3.new(size, size * random:NextNumber(0.5, 0.8), size * random:NextNumber(0.7, 1))
	part(parent, name, s, CFrame.new(base + Vector3.new(0, s.Y * 0.35, 0)) * CFrame.Angles(0, math.rad(random:NextNumber(0, 90)), 0), if random:NextNumber() < 0.5 then COLORS.stone else COLORS.stoneDark)
end

local counters = { trees = 0, mushrooms = 0, plants = 0, ruins = 0, crystals = 0, floating = 0, edgeRocks = 0 }
local function place(key: string, clearance: number, build: (Vector3) -> ())
	local position = decorPoint(key, clearance)
	if position then
		build(position)
		table.insert(placed, position)
		return true
	end
	return false
end

-- Forêt mystique (zone B) : arbres, champignons géants, plantes.
for index = 1, 12 do
	if place("B", 6, function(p) tree(decor, `ForestTree{index}`, p, random:NextNumber(1, 1.5)) end) then counters.trees += 1 end
end
for index = 1, 6 do
	if place("B", 5, function(p) mushroom(decor, `GiantMushroom{index}`, p, random:NextNumber(1.8, 2.6)) end) then counters.mushrooms += 1 end
end
for index = 1, 12 do
	if place("B", 2.5, function(p) glowPlant(decor, `ForestPlant{index}`, p, random:NextNumber(1, 1.4)) end) then counters.plants += 1 end
end
for index = 1, 2 do
	if place("B", 5, function(p) ruin(decor, `ForestRuin{index}`, p) end) then counters.ruins += 1 end
end
-- Île d'arrivée : quelques arbres et plantes en bordure (lecture dégagée).
for index = 1, 5 do
	if place("A", 8, function(p) tree(decor, `ArrivalTree{index}`, p, random:NextNumber(0.9, 1.2)) end) then counters.trees += 1 end
end
for index = 1, 8 do
	if place("A", 3, function(p) glowPlant(decor, `ArrivalPlant{index}`, p, 1) end) then counters.plants += 1 end
end
for index = 1, 3 do
	if place("A", 5, function(p) mushroom(decor, `ArrivalMushroom{index}`, p, random:NextNumber(0.8, 1.1)) end) then counters.mushrooms += 1 end
end
-- Îles flottantes (zone C) : végétation lumineuse, ruines, cristaux.
for _, key in ipairs({ "C1", "C2", "C3" }) do
	for index = 1, 2 do
		if place(key, 6, function(p) tree(decor, `{key}Tree{index}`, p, random:NextNumber(0.9, 1.2)) end) then counters.trees += 1 end
	end
	for index = 1, 5 do
		if place(key, 2.5, function(p) glowPlant(decor, `{key}Plant{index}`, p, random:NextNumber(1, 1.3)) end) then counters.plants += 1 end
	end
	if place(key, 5, function(p) ruin(decor, `{key}Ruin`, p) end) then counters.ruins += 1 end
	if place(key, 4, function(p) crystalCluster(decor, `{key}Crystal`, p, 1.2, COLORS.blue, COLORS.cyan) end) then counters.crystals += 1 end
end
-- Île de la grotte (zone D) : champignons, plantes, cristaux.
for index = 1, 3 do
	if place("D", 5, function(p) mushroom(decor, `CaveMushroom{index}`, p, random:NextNumber(1.2, 1.8)) end) then counters.mushrooms += 1 end
end
for index = 1, 6 do
	if place("D", 2.5, function(p) glowPlant(decor, `CavePlant{index}`, p, 1.2) end) then counters.plants += 1 end
end
for index = 1, 3 do
	if place("D", 4, function(p) crystalCluster(decor, `CaveIslandCrystal{index}`, p, 1.3, COLORS.violet, COLORS.cyan) end) then counters.crystals += 1 end
end
-- Sanctuaire (zone E) : plantes lumineuses autour de l'estrade.
for index = 1, 6 do
	if place("E", 2.5, function(p) glowPlant(decor, `SanctuaryPlant{index}`, p, 1.2) end) then counters.plants += 1 end
end
for index = 1, 2 do
	if place("E", 6, function(p) tree(decor, `SanctuaryTree{index}`, p, 1.1) end) then counters.trees += 1 end
end

-- Rochers de bord (repères des limites) sur les îles sans muret.
for _, key in ipairs({ "B", "C1", "C2", "C3", "D", "E" }) do
	local island = ISLANDS[key]
	local count = math.floor(island.radius / 3)
	for index = 1, count do
		local angle = (index + random:NextNumber(-0.3, 0.3)) * 2 * math.pi / count
		local position = island.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (island.radius - 1.6)
		if not nearBridgeHead(key, position, BRIDGE_WIDTH / 2 + 3) and not inFootprint(position, 0) and isFree(position, 3) then
			edgeRock(decor, `EdgeRock{key}_{index}`, position + Vector3.new(0, island.top, 0), random:NextNumber(1.6, 2.8))
			counters.edgeRocks += 1
		end
	end
end

-- Rochers flottants dans le vide (sans collision), hors des îles et des ponts.
local function nearBridge(position: Vector3, clearance: number): boolean
	local flat = horizontal(position)
	for _, pair in ipairs(BRIDGES) do
		local a, b = horizontal(ISLANDS[pair[1]].center), horizontal(ISLANDS[pair[2]].center)
		local ab = b - a
		local t = math.clamp((flat - a):Dot(ab) / ab:Dot(ab), 0, 1)
		if (flat - (a + ab * t)).Magnitude < clearance then
			return true
		end
	end
	return false
end
local floatingFolder = newFolder(root, "FloatingRocks")
for index = 1, 18 do
	for _ = 1, 200 do
		local candidate = Vector3.new(random:NextNumber(-150, 150), 0, random:NextNumber(-125, 135))
		local clear = true
		for _, key in ipairs(ISLAND_ORDER) do
			if (horizontal(candidate) - horizontal(ISLANDS[key].center)).Magnitude < ISLANDS[key].radius + 8 then
				clear = false
			end
		end
		if clear and not nearBridge(candidate, 12) then
			local size = random:NextNumber(3, 8)
			local y = random:NextNumber(-14, 22)
			local frame = CFrame.new(candidate + Vector3.new(0, y, 0)) * CFrame.Angles(math.rad(random:NextNumber(-15, 15)), math.rad(random:NextNumber(0, 90)), math.rad(random:NextNumber(-15, 15)))
			part(floatingFolder, `Rock{index}`, Vector3.new(size, size * 0.6, size * 0.85), frame, if index % 2 == 0 then COLORS.stoneDark else COLORS.stone, false)
			part(floatingFolder, `Rock{index}Grass`, Vector3.new(size * 0.9, 0.4, size * 0.75), frame * CFrame.new(0, size * 0.3, 0), if index % 3 == 0 then COLORS.grassLavender else COLORS.grass, false)
			if index % 3 == 0 then
				neon(part(floatingFolder, `Rock{index}Crystal`, Vector3.new(0.9, size * 0.5, 0.9), frame * CFrame.new(0, size * 0.3 + size * 0.25, 0) * CFrame.Angles(0, math.rad(45), 0), if index % 2 == 0 then COLORS.violet else COLORS.cyan, false))
			end
			counters.floating += 1
			break
		end
	end
end
root.Parent = map

-- ARRIVÉE ET VENTE ------------------------------------------------------------------

local arrivals = getFolder(Workspace, "WorldArrivals")
replace(arrivals, WORLD_ID)
local arrival = Instance.new("Part")
arrival.Name = WORLD_ID
arrival.Size = Vector3.new(6, 0.2, 6)
arrival.Position = world(ARRIVAL_POSITION)
arrival.Anchored = true
arrival.Material = Enum.Material.SmoothPlastic
arrival.Color = COLORS.arrival
arrival.Transparency = 0.3
arrival.CanCollide = false
arrival.CanQuery = false
arrival.CanTouch = false
arrival.CastShadow = false
arrival:SetAttribute("ArrivalWorldId", WORLD_ID)
arrival.Parent = arrivals
partCount += 1

-- Station de vente : comptoir mystique, auvent violet et cyan, pierres
-- flottantes et cristaux décoratifs, pièce dorée (même lecture que les
-- stations des autres mondes : dalle jaune, pièce).
local sellRoot = getFolder(Workspace, "SellZones")
replace(sellRoot, WORLD_ID)
local station = Instance.new("Model")
station.Name = WORLD_ID
local function stationPart(name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?): BasePart
	local p = part(station, name, size, CFrame.new(SELL_POSITION + offset), color)
	p.Shape = shape or Enum.PartType.Block
	p.CanQuery = false
	return p
end
local pad = stationPart("SellZonePad", Vector3.new(10, 0.4, 10), Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 214, 92))
pad:SetAttribute("SellZoneId", SELL_ZONE_ID)
stationPart("Counter", Vector3.new(6, 3, 2), Vector3.new(0, 1.9, -3.5), COLORS.stoneLight)
stationPart("CounterTop", Vector3.new(6.4, 0.4, 2.4), Vector3.new(0, 3.6, -3.5), COLORS.violet)
stationPart("PostLeft", Vector3.new(0.8, 7, 0.8), Vector3.new(-2.8, 3.9, -4.2), COLORS.stoneDark)
stationPart("PostRight", Vector3.new(0.8, 7, 0.8), Vector3.new(2.8, 3.9, -4.2), COLORS.stoneDark)
stationPart("Roof", Vector3.new(7.4, 0.6, 3.6), Vector3.new(0, 7.6, -3.8), COLORS.violet)
stationPart("RoofTrim", Vector3.new(7.6, 0.5, 0.6), Vector3.new(0, 7.2, -1.9), COLORS.cyan)
local coin = stationPart("Coin", Vector3.new(0.6, 2.6, 2.6), Vector3.new(0, 4.6, -3.5), COLORS.gold, Enum.PartType.Cylinder)
coin.CFrame = CFrame.new(world(SELL_POSITION + Vector3.new(0, 4.6, -3.5))) * CFrame.Angles(0, math.rad(90), 0)
coin.Material = Enum.Material.Neon
for index, offset in ipairs({ Vector3.new(-4.2, 9.4, -3.8), Vector3.new(4.2, 9, -3.8), Vector3.new(0, 10.2, -4.6) }) do
	local stone = stationPart(`FloatingStone{index}`, Vector3.new(1, 0.8, 1), offset, COLORS.stoneLight)
	stone.CanCollide = false
	stone.CFrame *= CFrame.Angles(math.rad(20), math.rad(index * 40), 0)
end
for side = -1, 1, 2 do
	local gem = stationPart(`Gem{side}`, Vector3.new(0.8, 2.2, 0.8), Vector3.new(side * 4.4, 1.1, -4.4), if side < 0 then COLORS.violet else COLORS.cyan)
	gem.Material = Enum.Material.Neon
	gem.CanCollide = false
	gem.CFrame *= CFrame.Angles(0, math.rad(45), math.rad(side * 10))
end
station.PrimaryPart = pad
station.Parent = sellRoot

-- RÉSUMÉ -----------------------------------------------------------------------

local decorParts = 0
for _, descendant in ipairs(root:GetDescendants()) do
	if descendant:IsA("BasePart") then
		decorParts += 1
		assert(descendant.Anchored and not descendant.CastShadow, `{descendant:GetFullName()} : ancrage ou ombre`)
	end
	assert(not descendant:IsA("Light") and not descendant:IsA("ParticleEmitter") and not descendant:IsA("BaseScript"), `{descendant:GetFullName()} : lumière, particules ou script dans le décor`)
end
assert(decorParts <= DECOR_BUDGET, `budget de décor dépassé : {decorParts} > {DECOR_BUDGET}`)
assert(#pointFolder:GetChildren() == TOTAL_SPAWN_POINTS, "nombre de points de spawn")

local nearestByType, farthestByType = {}, {}
for _, point in ipairs(pointFolder:GetChildren()) do
	local distance = distanceToSell(point.Position - CENTER)
	local resourceType = point:GetAttribute("ResourceType")
	nearestByType[resourceType] = math.min(nearestByType[resourceType] or math.huge, distance)
	farthestByType[resourceType] = math.max(farthestByType[resourceType] or 0, distance)
end
local summary = {}
for resourceType, count in pairs(counts) do
	table.insert(summary, string.format("%s x%d (%.0f–%.0f studs)", resourceType, count, nearestByType[resourceType], farthestByType[resourceType]))
end
table.sort(summary)
return string.format(
	"Mystic World : %d points [%s] ; décor %d parts (arbres %d, champignons %d, plantes %d, ruines %d, cristaux %d, rochers flottants %d, rochers de bord %d) ; total créé %d parts",
	#pointFolder:GetChildren(),
	table.concat(summary, ", "),
	decorParts,
	counters.trees,
	counters.mushrooms,
	counters.plants,
	counters.ruins,
	counters.crystals,
	counters.floating,
	counters.edgeRocks,
	partCount
)
