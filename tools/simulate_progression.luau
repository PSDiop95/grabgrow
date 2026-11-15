--!nocheck
-- Simulateur de progression économique (T7, D-020 ; quatre mondes T8, D-021).
-- Usage (racine du dépôt) :
--   lune run tools/simulate_progression.luau            -> configuration actuelle
--   lune run tools/simulate_progression.luau bible      -> Backpack 2 = 100, sans succès
--   lune run tools/simulate_progression.luau noach      -> actuelle, sans succès
--   lune run tools/simulate_progression.luau current events -> détail des achats
--   option `t7` (ex. `current t7`) : hypothèses de T7 (carte de test de
--     Green Valley seule, mondes 2 à 4 sans contenu) ; reproduit
--     docs/phases/T7_ECONOMY_SIMULATION.md.
--
-- Outil de développement : absent du jeu (non mappé dans
-- default.project.json). Lit les VRAIES tables UpgradeConfig, WorldConfig,
-- ResourceConfig et AchievementConfig : aucune valeur économique copiée ici.
--
-- PROJECTIONS THÉORIQUES, PAS DES MESURES. Hypothèses (profils ci-dessous) :
--   * temps par unité = intervalle Grabber + d0 × (12 / portée) × (16 / vitesse) ;
--     d0 = déplacement par unité. Repère MESURÉ (émulateur, T2) : maintien,
--     39 collectes / 60 s à 0,75 s -> d0 ≈ 0,79 s (joueur régulier) ;
--   * aller-retour de vente = T0 × 16 / vitesse ;
--   * valeur d'un sac = floor(capacité × valeur moyenne par nœud du monde
--     joué), puis Multiplier arrondi à l'inférieur ;
--   * T8 : carte prévue de NODES_PER_WORLD nœuds par monde, répartis selon
--     ResourceConfig.spawnWeight (plus forts restes) ; le joueur passe au
--     monde suivant dès son déblocage et n'y collecte que ses ressources ;
--     rareté due aux temps de réapparition et concurrence entre joueurs
--     IGNORÉES (le jeu réel sera plus lent) ;
--   * achats après chaque vente ; mondes débloqués dès que possible.
-- Résultats et limites : docs/phases/T7_ECONOMY_SIMULATION.md.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local VARIANT = process.args[1] or "current"
local FLAGS = {}
for index = 2, #process.args do
	FLAGS[process.args[index]] = true
end
local SHOW_EVENTS = FLAGS.events == true
local T7_MODE = FLAGS.t7 == true
local SHARED = "src/ReplicatedStorage/Shared"

-- Chargeur minimal des modules de configuration (seule dépendance :
-- Util/TableUtil via script.Parent.Parent).
local cache = {}
local function load(path)
	if cache[path] then
		return cache[path]
	end
	local environment = {
		script = { Parent = { Parent = { Util = { TableUtil = "__TableUtil" } } } },
		require = function(target)
			if target == "__TableUtil" then
				return load(`{SHARED}/Util/TableUtil.lua`)
			end
			error("require inattendu dans une configuration")
		end,
	}
	setmetatable(environment, { __index = _G })
	local value = luau.load(fs.readFile(path), { debugName = path, environment = environment })()
	cache[path] = value
	return value
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

local Upgrades = deepCopy(load(`{SHARED}/Config/UpgradeConfig.lua`))
local Worlds = load(`{SHARED}/Config/WorldConfig.lua`)
local Resources = load(`{SHARED}/Config/ResourceConfig.lua`)
local Achievements = load(`{SHARED}/Config/AchievementConfig.lua`)

local useAchievements = true
if VARIANT == "bible" then
	Upgrades.Backpack.levels[2].cost = 100
	useAchievements = false
elseif VARIANT == "noach" then
	useAchievements = false
elseif VARIANT ~= "current" then
	error(`variante inconnue : {VARIANT} (current, bible, noach)`)
end

-- Carte de test (docs/COLLECTION.md) : 16 feuilles, 12 bois, 8 pierres.
local NODE_COUNT = { green_leaf = 16, wood = 12, stone = 8 }
local nodes, value = 0, 0
for resourceId, count in NODE_COUNT do
	nodes += count
	value += count * Resources[resourceId].sellValue
end
local T7_VALUE_PER_UNIT = value / nodes

-- T8 (D-021 D8, hypothèse) : nœuds prévus par monde.
local NODES_PER_WORLD = 40

-- Répartition de `total` nœuds selon les poids (plus forts restes, ordre
-- stable) ; retourne la valeur moyenne par nœud et le détail.
local function plannedValue(worldId)
	local ids, totalWeight = {}, 0
	for id, definition in Resources do
		if definition.worldId == worldId then
			table.insert(ids, id)
			totalWeight += definition.spawnWeight
		end
	end
	table.sort(ids)
	local counts, used, remainders = {}, 0, {}
	for _, id in ids do
		local exact = NODES_PER_WORLD * Resources[id].spawnWeight / totalWeight
		counts[id] = math.floor(exact)
		used += counts[id]
		table.insert(remainders, { id = id, rest = exact - counts[id] })
	end
	table.sort(remainders, function(a, b)
		if a.rest ~= b.rest then
			return a.rest > b.rest
		end
		return a.id < b.id
	end)
	for index = 1, NODES_PER_WORLD - used do
		local id = remainders[index].id
		counts[id] += 1
	end
	local sum, parts = 0, {}
	for _, id in ids do
		sum += counts[id] * Resources[id].sellValue
		table.insert(parts, `{id} {counts[id]}`)
	end
	return sum / NODES_PER_WORLD, table.concat(parts, ", ")
end

-- Valeur moyenne par unité selon le monde joué.
local WORLD_VALUES = {}
local WORLD_LAYOUTS = {}
for worldId in Worlds do
	WORLD_VALUES[worldId], WORLD_LAYOUTS[worldId] = plannedValue(worldId)
end
if T7_MODE then
	-- T7 : carte de test seule ; débloquer un monde ne change pas la valeur.
	for worldId in Worlds do
		WORLD_VALUES[worldId] = T7_VALUE_PER_UNIT
	end
end
local VALUE_PER_UNIT = WORLD_VALUES.GreenValley

-- Profils (HYPOTHÈSES). strategy : "roi" = meilleur gain/coût (attend s'il
-- faut économiser) ; "cheap" = achète le moins cher abordable.
local PROFILES = {
	{ name = "Occasionnel", d0 = 1.20, T0 = 30, strategy = "cheap", minutesPerDay = 15 * 3 / 7 },
	{ name = "Régulier", d0 = 0.79, T0 = 20, strategy = "roi", minutesPerDay = 30 },
	{ name = "Très actif", d0 = 0.50, T0 = 14, strategy = "roi", minutesPerDay = 120 },
}

local ORDER = { "Backpack", "Grabber", "Magnet", "Boots", "Multiplier" }
local WORLD_ORDER = { "GoldenDesert", "FrozenPeaks", "MysticWorld" }
local ACHIEVEMENT_IDS = {}
for id in Achievements do
	table.insert(ACHIEVEMENT_IDS, id)
end
table.sort(ACHIEVEMENT_IDS, function(a, b)
	return Achievements[a].order < Achievements[b].order
end)

local function statOf(levels, id)
	local definition = Upgrades[id]
	return definition.levels[levels[id] - definition.startLevel + 1].value
end

local function nextCost(levels, id)
	local definition = Upgrades[id]
	local row = definition.levels[levels[id] - definition.startLevel + 2]
	return if row then row.cost else nil
end

local function cycle(profile, levels, scale)
	local capacity = statOf(levels, "Backpack")
	local unitSeconds = statOf(levels, "Grabber")
		+ profile.d0 * (scale or 1) * (12 / statOf(levels, "Magnet")) * (16 / statOf(levels, "Boots"))
	local fill = capacity * unitSeconds
	local sell = profile.T0 * 16 / statOf(levels, "Boots")
	local base = math.floor(capacity * VALUE_PER_UNIT * (profile.valueScale or 1))
	local multiplier = math.floor(statOf(levels, "Multiplier") * 100 + 0.5)
	local bag = math.floor(base * multiplier / 100)
	return { fill = fill, sell = sell, value = bag, perMinute = bag / (fill + sell) * 60, capacity = capacity }
end

local function simulate(profile, capHours, scale)
	VALUE_PER_UNIT = WORLD_VALUES.GreenValley
	local levels = {}
	for _, id in ORDER do
		levels[id] = Upgrades[id].startLevel
	end
	local state = { coins = 0, t = 0, worlds = 1, spent = 0 }
	local metrics = { resourcesCollected = 0, sales = 0, coinsEarned = 0, upgradesBought = 0, worldsUnlocked = 1 }
	local earned = {}
	local events = {}

	local function push(what, cost)
		table.insert(events, { t = state.t, what = what, cost = cost, perMinute = cycle(profile, levels, scale).perMinute })
	end

	local function checkAchievements()
		if not useAchievements then
			return
		end
		local again = true
		while again do
			again = false
			for _, id in ACHIEVEMENT_IDS do
				local definition = Achievements[id]
				if not earned[id] and metrics[definition.metric] >= definition.goal then
					earned[id] = true
					state.coins += definition.reward
					metrics.coinsEarned += definition.reward
					push(`Succès {id}`, -definition.reward)
					again = true
				end
			end
		end
	end

	local function tryWorld()
		local worldId = WORLD_ORDER[state.worlds]
		if worldId == nil then
			return false
		end
		local world = Worlds[worldId]
		if levels.Backpack < world.requiredBackpackLevel or state.coins < world.unlockCost then
			return false
		end
		state.coins -= world.unlockCost
		state.spent += world.unlockCost
		state.worlds += 1
		metrics.worldsUnlocked = state.worlds
		VALUE_PER_UNIT = WORLD_VALUES[worldId]
		push(`Monde {worldId}`, world.unlockCost)
		checkAchievements()
		return true
	end

	local function choose()
		local current = cycle(profile, levels, scale).perMinute
		local best, bestRatio, cheapest, cheapestCost
		for _, id in ORDER do
			local cost = nextCost(levels, id)
			if cost then
				levels[id] += 1
				local gain = cycle(profile, levels, scale).perMinute - current
				levels[id] -= 1
				-- Le joueur poursuit le Backpack requis par le monde suivant.
				local worldId = WORLD_ORDER[state.worlds]
				if id == "Backpack" and worldId and levels.Backpack < Worlds[worldId].requiredBackpackLevel then
					gain *= 2
				end
				local ratio = gain / cost
				if best == nil or ratio > bestRatio then
					best, bestRatio = id, ratio
				end
				if cheapest == nil or cost < cheapestCost then
					cheapest, cheapestCost = id, cost
				end
			end
		end
		return if profile.strategy == "cheap" then cheapest else best
	end

	local firstSale
	while state.t < capHours * 3600 do
		local current = cycle(profile, levels, scale)
		state.t += current.fill
		metrics.resourcesCollected += current.capacity
		checkAchievements()
		state.t += current.sell
		state.coins += current.value
		metrics.sales += 1
		metrics.coinsEarned += current.value
		firstSale = firstSale or state.t
		checkAchievements()
		for _ = 1, 50 do
			if not tryWorld() then
				local id = choose()
				local cost = if id then nextCost(levels, id) else nil
				if cost == nil or state.coins < cost then
					break
				end
				state.coins -= cost
				state.spent += cost
				levels[id] += 1
				metrics.upgradesBought += 1
				push(`{id} {levels[id]}`, cost)
				checkAchievements()
			end
		end
		local done = state.worlds == 4
		for _, id in ORDER do
			if nextCost(levels, id) then
				done = false
			end
		end
		if done then
			break
		end
	end
	return { events = events, t = state.t, levels = levels, worlds = state.worlds, spent = state.spent, firstSale = firstSale }
end

local function fmt(seconds)
	if seconds == nil then
		return "—"
	end
	local minutes = seconds / 60
	if minutes < 1 then
		return string.format("%.0f s", seconds)
	elseif minutes < 90 then
		return string.format("%.1f min", minutes)
	end
	return string.format("%.1f h", minutes / 60)
end

local MILESTONES = {
	"Backpack 2", "Backpack 3", "Backpack 4", "Backpack 5", "Monde GoldenDesert",
	"Backpack 6", "Backpack 8", "Monde FrozenPeaks", "Backpack 10", "Monde MysticWorld", "Backpack 16",
}
local WINDOWS = { { 0, 10 }, { 10, 30 }, { 30, 60 }, { 60, 120 }, { 120, 300 }, { 300, 600 }, { 600, 1200 } }
local CAP_HOURS = 400

print(`# Simulation de progression — variante « {VARIANT} » (succès : {if useAchievements then "oui" else "non"})`)
if T7_MODE then
	print(`Mode t7 : carte de test de Green Valley seule ({string.format("%.3f", T7_VALUE_PER_UNIT)} Coins par nœud), mondes 2 à 4 sans contenu. PROJECTIONS THÉORIQUES.`)
else
	print(`Carte prévue (T8) : {NODES_PER_WORLD} nœuds par monde. PROJECTIONS THÉORIQUES.`)
	for _, worldId in { "GreenValley", "GoldenDesert", "FrozenPeaks", "MysticWorld" } do
		print(`- {worldId} : {string.format("%.2f", WORLD_VALUES[worldId])} Coins par nœud ({WORLD_LAYOUTS[worldId]})`)
	end
end

for _, profile in PROFILES do
	local startLevels = {}
	for _, id in ORDER do
		startLevels[id] = Upgrades[id].startLevel
	end
	VALUE_PER_UNIT = WORLD_VALUES.GreenValley
	local start = cycle(profile, startLevels)
	local result = simulate(profile, CAP_HOURS)
	local at = {}
	local purchases, lastPurchase, longestGap, gapBefore = 0, 0, 0, ""
	local rewards = 0
	for _, event in result.events do
		at[event.what] = at[event.what] or event.t
		if event.cost > 0 then
			purchases += 1
			if event.t - lastPurchase > longestGap then
				longestGap, gapBefore = event.t - lastPurchase, event.what
			end
			lastPurchase = event.t
		else
			rewards += 1
		end
	end
	print(`\n## {profile.name} (d0 {profile.d0} s, T0 {profile.T0} s, {profile.strategy}, {string.format("%.0f", profile.minutesPerDay)} min/jour)`)
	print(string.format("Départ : %.0f Coins/min ; sac plein en %s ; vente toutes les %s ; 1re vente à %s",
		start.perMinute, fmt(start.fill), fmt(start.fill + start.sell), fmt(result.firstSale)))
	print("| Jalon | Temps de jeu | Jour calendaire |")
	print("|---|---|---|")
	for _, name in MILESTONES do
		local t = at[name]
		local day = if t then math.max(1, math.ceil(t / 60 / profile.minutesPerDay)) else nil
		print(`| {name} | {fmt(t)} | {if day then tostring(day) else "—"} |`)
	end
	local line = "Récompenses perceptibles (achats + succès) par fenêtre de jeu :"
	for _, window in WINDOWS do
		local count = 0
		for _, event in result.events do
			local minutes = event.t / 60
			if minutes >= window[1] and minutes < window[2] then
				count += 1
			end
		end
		line ..= ` [{window[1]}-{window[2]} min] {count} ;`
	end
	print(line)
	print(`Achats : {purchases} ; succès : {rewards} ; plus longue attente entre deux achats : {fmt(longestGap)} (avant {gapBefore})`)
	print(`Fin : {fmt(result.t)} ; dépensé {result.spent} Coins ; revenu final {string.format("%.0f", cycle(profile, result.levels).perMinute)} Coins/min`)
end

print("\n## Sensibilité (joueur régulier) : Golden Desert / Backpack 8")
local regular = PROFILES[2]
for _, sample in { { "base", 1, 1 }, { "collecte -20 %", 1.2, 1 }, { "collecte +20 %", 0.8, 1 }, { "valeur -20 %", 1, 0.8 }, { "valeur +20 %", 1, 1.2 } } do
	regular.valueScale = sample[3]
	local result = simulate(regular, CAP_HOURS, sample[2])
	local desert, backpack8
	for _, event in result.events do
		if event.what == "Monde GoldenDesert" then
			desert = event.t
		elseif event.what == "Backpack 8" then
			backpack8 = event.t
		end
	end
	print(`- {sample[1]} : Golden Desert {fmt(desert)} ; Backpack 8 {fmt(backpack8)}`)
end
regular.valueScale = nil

if SHOW_EVENTS then
	print("\n## Détail — joueur régulier (25 premières heures)")
	local result = simulate(regular, 25)
	local last = 0
	for _, event in result.events do
		if event.cost > 0 then
			print(string.format("- %s (+%s) %s : %d Coins -> %.0f Coins/min", fmt(event.t), fmt(event.t - last), event.what, event.cost, event.perMinute))
			last = event.t
		else
			print(string.format("- %s %s : +%d Coins", fmt(event.t), event.what, -event.cost))
		end
	end
end
