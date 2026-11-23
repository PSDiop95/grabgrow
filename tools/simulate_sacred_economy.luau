--!nocheck
-- Simulation des ressources sacrées (T10.3, T10-D03) : vente ou
-- améliorations spéciales. Usage (racine du dépôt) :
--   lune run tools/simulate_sacred_economy.luau
--
-- Outil de développement, absent du jeu. Aucune valeur n'est fixée ni
-- écrite dans une configuration : les scénarios sont des HYPOTHÈSES à
-- valider par le propriétaire.
--
-- Revenus de référence : lus dans la sortie de
-- tools/simulate_progression.luau (joueur régulier, configuration
-- actuelle). Projections théoriques, pas des mesures (le jeu réel sera
-- plus lent : réapparition, concurrence). Rien n'est copié des tables
-- économiques.
--
-- Hypothèses propres à cette simulation (toutes à valider) :
--   * accès au site de Green Valley vers 20 min de jeu (5 ressources
--     découvertes) ; aux autres sites dès le déblocage du monde ;
--   * cycle de ferme : combat 60 s + réapparition 45 s (GuardianConfig) ;
--   * une ressource sacrée occupe 1 place de sac (D-035 ; reflète
--     SacredResourceConfig.bagSlotsPerUnit, non lisible depuis Lune) ;
--   * gain de revenu des améliorations spéciales estimé (paramètres
--     UPGRADE_GAINS) faute de modèle de collecte dans cet outil.

local process = require("@lune/process")

local exec = process.exec or process.spawn
local result = exec("lune", { "run", "tools/simulate_progression.luau", "current", "events" })
if not result.ok then
	error(`simulate_progression a échoué : {result.stderr}`)
end

-- Lignes « - 74.3 min (+14.6 min) Monde GoldenDesert : 1500 Coins -> 434 Coins/min »
local events = {}
local inDetail = false
for line in string.gmatch(result.stdout, "[^\n]+") do
	if string.find(line, "^## Détail") then
		inDetail = true
	elseif string.find(line, "^## ") then
		inDetail = false
	elseif inDetail then
		local amount, unit, name, rate = string.match(line, "^%- ([%d%.]+) (%a+) %(.-%) (.-) : %d+ Coins %-> (%d+) Coins/min")
		if amount then
			local minutes = tonumber(amount) * (if unit == "h" then 60 else 1)
			table.insert(events, { minutes = minutes, name = name, rate = tonumber(rate) })
		end
	end
end
assert(#events > 10, "sortie de simulate_progression illisible")

local WORLDS = {
	{ id = "GreenValley", site = "RootSanctuary", resource = "sacred_heartwood_seed", unlock = nil, accessMinutes = 20 },
	{ id = "GoldenDesert", site = "SunTemple", resource = "sacred_sun_relic", unlock = "Monde GoldenDesert" },
	{ id = "FrozenPeaks", site = "FrostAltar", resource = "sacred_frost_heart", unlock = "Monde FrozenPeaks" },
	{ id = "MysticWorld", site = "AstralSanctuary", resource = "sacred_astral_essence", unlock = "Monde MysticWorld" },
}

local function eventIndex(name)
	for index, event in ipairs(events) do
		if event.name == name then
			return index
		end
	end
	return nil
end

-- Revenu bas (à l'accès au site) et haut (juste avant le monde suivant).
for index, world in ipairs(WORLDS) do
	local first
	if world.unlock then
		first = eventIndex(world.unlock)
	else
		for i, event in ipairs(events) do
			if event.minutes >= world.accessMinutes then
				first = i
				break
			end
		end
	end
	local nextWorld = WORLDS[index + 1]
	local last = if nextWorld then (eventIndex(nextWorld.unlock) :: number) - 1 else #events
	world.accessMinutes = events[first].minutes
	world.low = events[first].rate
	world.high = events[last].rate
end

local VALUE_MINUTES = { 0.5, 1, 2, 4 } -- valeur = k minutes du revenu bas
local CYCLE_SECONDS = 60 + 45
local BAG_SLOTS = 1 -- D-035 (anomalie A-3 de T10.4 corrigée)
local FIRST_VICTORY_UNITS = 3
local REGIMES = {
	{ id = "R1", label = "1re victoire seulement (3 unités)", perHour = 0 },
	{ id = "R2", label = "3 puis 1 unité / 10 min de session", perHour = 6 },
	{ id = "R3", label = "3 puis 1 unité / victoire (sans limite)", perHour = 3600 / CYCLE_SECONDS },
}
-- Amélioration de référence : Sac sacré 1, coût 3 unités, +10 % de
-- capacité ≈ +9 % de revenu (hypothèse).
local UPGRADE_UNITS = 3
local UPGRADE_GAIN = 0.09
-- R-1 (D-037) : une amélioration à un niveau par monde, coût = les 3 unités
-- du monde. Gains de revenu ESTIMÉS (aucun modèle de collecte ici).
local R1_UPGRADES = {
	GreenValley = { id = "sacred_magnet", gain = 0.03 },
	GoldenDesert = { id = "sacred_grabber", gain = 0.05 },
	FrozenPeaks = { id = "sacred_backpack", gain = 0.09 },
	MysticWorld = { id = "sacred_compass", gain = 0 },
}

local function fmt(n)
	if n >= 100 then
		return string.format("%d", math.floor(n + 0.5))
	end
	return string.format("%.1f", n)
end

local function minutesText(m)
	if m >= 120 then
		return `{fmt(m / 60)} h`
	end
	return `{fmt(m)} min`
end

print("# Ressources sacrées — scénarios (HYPOTHÈSES, joueur régulier)\n")
print("| Monde | Accès au site | Revenu à l'accès | Revenu avant le monde suivant |")
print("|---|---|---|---|")
for _, world in ipairs(WORLDS) do
	print(`| {world.id} | {minutesText(world.accessMinutes)} | {world.low} Coins/min | {world.high} Coins/min |`)
end

print("\n## Valeur de vente candidate (k minutes du revenu à l'accès)\n")
print("| Monde | k = 0,5 | k = 1 | k = 2 | k = 4 |")
print("|---|---|---|---|---|")
for _, world in ipairs(WORLDS) do
	local cells = {}
	for _, k in ipairs(VALUE_MINUTES) do
		table.insert(cells, `{math.floor(world.low * k + 0.5)}`)
	end
	print(`| {world.id} | {table.concat(cells, " | ")} |`)
end

print("\n## Ferme : revenu horaire tiré du gardien / revenu normal\n")
print("Rapport = (unités par heure × valeur) / (revenu à l'accès × 60). 1,00 = autant que la collecte normale.\n")
print("| Régime | k = 0,5 | k = 1 | k = 2 | k = 4 |")
print("|---|---|---|---|---|")
for _, regime in ipairs(REGIMES) do
	local cells = {}
	for _, k in ipairs(VALUE_MINUTES) do
		-- valeur = k × revenu bas -> rapport indépendant du monde
		table.insert(cells, string.format("%.2f", regime.perHour * k / 60))
	end
	print(`| {regime.id} {regime.label} | {table.concat(cells, " | ")} |`)
end

print("\n## Gain unique de la 1re victoire (3 unités vendues)\n")
print("| k | Équivalent en minutes de jeu |")
print("|---|---|")
for _, k in ipairs(VALUE_MINUTES) do
	print(`| {k} | {fmt(FIRST_VICTORY_UNITS * k)} min |`)
end

print("\n## Vendre ou améliorer : Sac sacré 1 (3 unités, +9 % de revenu estimé)\n")
print("Seuil = temps de jeu après lequel l'amélioration rapporte plus que la vente des 3 unités.\n")
print("| Monde | k = 0,5 | k = 1 | k = 2 | k = 4 |")
print("|---|---|---|---|---|")
for _, world in ipairs(WORLDS) do
	local cells = {}
	for _, k in ipairs(VALUE_MINUTES) do
		local forgone = UPGRADE_UNITS * k * world.low
		table.insert(cells, minutesText(forgone / (UPGRADE_GAIN * world.high)))
	end
	print(`| {world.id} | {table.concat(cells, " | ")} |`)
end

print("\n## Place dans le sac\n")
print(`Une unité = {BAG_SLOTS} places ; 3 unités = {3 * BAG_SLOTS} places.`)

print("\n## R-1 : amélioration du monde contre vente de ses 3 unités (gains estimés)\n")
print("Seuil = temps de jeu après lequel l'amélioration rapporte plus que la vente.\n")
print("| Monde | Amélioration | Gain estimé | k = 0,5 | k = 1 | k = 2 | k = 4 |")
print("|---|---|---|---|---|---|---|")
for _, world in ipairs(WORLDS) do
	local upgrade = R1_UPGRADES[world.id]
	if upgrade then
		local cells = {}
		for _, k in ipairs(VALUE_MINUTES) do
			if upgrade.gain <= 0 then
				table.insert(cells, "jamais (sans effet économique)")
			else
				local forgone = UPGRADE_UNITS * k * world.low
				table.insert(cells, minutesText(forgone / (upgrade.gain * world.high)))
			end
		end
		print(`| {world.id} | {upgrade.id} | {math.floor(upgrade.gain * 100 + 0.5)} % | {table.concat(cells, " | ")} |`)
	end
end
