--!strict
-- Tests d'InventoryService par-dessus un vrai PlayerDataService et un
-- magasin en mémoire : aucun appel au DataStore réel.

local InventoryServiceTests = {}

export type Modules = {
	InventoryService: any,
	PlayerDataService: any,
	MemoryDataStore: any,
	DataSchema: any,
	ResourceConfig: any,
	UpgradeConfig: any,
}

local USER_A = 2001
local USER_B = 2002
local KEY_A = "Player_2001"

-- Retourne (liste des échecs, nombre de cas exécutés).
function InventoryServiceTests.run(modules: Modules): ({ string }, number)
	local InventoryService = modules.InventoryService
	local PlayerDataService = modules.PlayerDataService
	local MemoryDataStore = modules.MemoryDataStore
	local DataSchema = modules.DataSchema
	local UpgradeConfig = modules.UpgradeConfig
	local Code = InventoryService.Code

	local failures: { string } = {}
	local caseCount = 0

	local function case(name: string, body: (check: (condition: boolean, message: string) -> ()) -> ())
		caseCount += 1
		local ok, err = pcall(body :: any, function(condition: boolean, message: string)
			if not condition then
				table.insert(failures, `{name} : {message}`)
			end
		end)
		if not ok then
			table.insert(failures, `{name} : erreur {tostring(err)}`)
		end
	end

	local function newServer(store: any, serverId: string)
		local playerData = PlayerDataService.new({
			store = store,
			serverId = serverId,
			clock = function(): number
				return 1_000_000
			end,
			wait = function() end,
			spawn = function(callback: () -> ())
				callback()
			end,
			log = function() end,
		})
		return {
			playerData = playerData,
			inventory = InventoryService.new({ playerData = playerData }),
		}
	end

	-- Serveur avec le joueur A chargé. `prepare` modifie le profil stocké
	-- avant le chargement.
	local function newLoaded(prepare: ((profile: any) -> ())?)
		local store = MemoryDataStore.new()
		if prepare then
			local profile = DataSchema.newProfile()
			prepare(profile)
			store.seed(KEY_A, { profile = profile })
		end
		local server = newServer(store, "A")
		assert(server.playerData.LoadPlayer(USER_A).ok, "chargement du joueur de test")
		return server, store
	end

	local baseCapacity = UpgradeConfig.Backpack.levels[1].value

	case("inventaire vide", function(check)
		local server = newLoaded()
		local state = server.inventory.GetState(USER_A)
		check(state ~= nil, "état absent")
		check(state.used == 0, `used = {state.used}`)
		check(state.capacity == baseCapacity, `capacity = {state.capacity}`)
		check(state.free == baseCapacity, `free = {state.free}`)
		check(next(state.resources) == nil, "ressources non vides")
		check(server.inventory.GetCapacity(USER_A) == baseCapacity, "GetCapacity incorrect")
		check(server.inventory.GetFreeSpace(USER_A) == baseCapacity, "GetFreeSpace incorrect")
	end)

	case("profil non chargé", function(check)
		local server = newServer(MemoryDataStore.new(), "A")
		check(server.inventory.GetState(USER_A) == nil, "état retourné sans profil")
		check(server.inventory.GetCapacity(USER_A) == nil, "capacité retournée sans profil")
		local result = server.inventory.AddResource(USER_A, "green_leaf", 1)
		check(not result.ok and result.code == Code.NotLoaded, `code {tostring(result.code)}`)
		check(result.granted == 0, "quantité accordée sans profil")
	end)

	case("ajout d'une ressource", function(check)
		local server = newLoaded()
		local result = server.inventory.AddResource(USER_A, "green_leaf", 1)
		check(result.ok, `refus : {tostring(result.code)}`)
		check(result.granted == 1, `granted = {result.granted}`)
		check(result.state ~= nil and result.state.used == 1, "état retourné incorrect")
		local profile = server.playerData.GetData(USER_A)
		check(profile.inventory.resources.green_leaf == 1, "quantité absente du profil")
		check(profile.stats.totalResourcesCollected == 1, "statistique non mise à jour")
		check(profile.currencies.coins == 0, "des Coins ont été crédités")
	end)

	case("ajout de plusieurs ressources", function(check)
		local server = newLoaded()
		check(server.inventory.AddResource(USER_A, "green_leaf", 3).ok, "feuilles refusées")
		check(server.inventory.AddResource(USER_A, "wood", 2).ok, "bois refusé")
		check(server.inventory.AddResource(USER_A, "stone", 4).ok, "pierre refusée")
		check(server.inventory.AddResource(USER_A, "green_leaf", 1).ok, "second ajout refusé")
		local state = server.inventory.GetState(USER_A)
		check(state.resources.green_leaf == 4, `green_leaf = {tostring(state.resources.green_leaf)}`)
		check(state.resources.wood == 2, `wood = {tostring(state.resources.wood)}`)
		check(state.resources.stone == 4, `stone = {tostring(state.resources.stone)}`)
		check(state.used == 10 and state.free == baseCapacity - 10, "occupation incorrecte")
		check(server.playerData.GetData(USER_A).stats.totalResourcesCollected == 10, "statistique incorrecte")
	end)

	case("capacité selon le niveau du sac", function(check)
		for level, definition in ipairs(UpgradeConfig.Backpack.levels) do
			check(InventoryService.capacityForLevel(level) == definition.value, `niveau {level}`)
		end
		check(InventoryService.capacityForLevel(0) == nil, "niveau 0 accepté")
		check(InventoryService.capacityForLevel(#UpgradeConfig.Backpack.levels + 1) == nil, "niveau hors table accepté")

		local server = newLoaded(function(profile)
			profile.upgrades.backpackLevel = 3
		end)
		check(server.inventory.GetCapacity(USER_A) == UpgradeConfig.Backpack.levels[3].value, "capacité du niveau 3")
	end)

	case("inventaire presque plein : quantité limitée à l'espace libre", function(check)
		local server = newLoaded(function(profile)
			profile.inventory.resources.wood = baseCapacity - 2
		end)
		local result = server.inventory.AddResource(USER_A, "stone", 5)
		check(result.ok, `refus : {tostring(result.code)}`)
		check(result.granted == 2, `granted = {result.granted}`)
		local state = server.inventory.GetState(USER_A)
		check(state.used == baseCapacity and state.free == 0, "le sac devrait être exactement plein")
		check(state.resources.stone == 2, "quantité créditée incorrecte")
	end)

	case("inventaire plein", function(check)
		local server = newLoaded(function(profile)
			profile.inventory.resources.green_leaf = baseCapacity
		end)
		local before = server.playerData.GetData(USER_A)
		local result = server.inventory.AddResource(USER_A, "wood", 1)
		check(not result.ok and result.code == Code.InventoryFull, `code {tostring(result.code)}`)
		check(result.granted == 0, "quantité accordée sac plein")
		local after = server.playerData.GetData(USER_A)
		check(after.inventory.resources.wood == nil, "ressource ajoutée sac plein")
		check(after.stats.totalResourcesCollected == before.stats.totalResourcesCollected, "statistique modifiée")
		check(server.inventory.GetState(USER_A).used == baseCapacity, "capacité dépassée")
	end)

	case("refus d'une quantité invalide", function(check)
		local server = newLoaded()
		local invalid: { any } = { 0, 1.5, 0 / 0, math.huge, "3", true, {} }
		for _, amount in ipairs(invalid) do
			local result = server.inventory.AddResource(USER_A, "green_leaf", amount)
			check(not result.ok and result.code == Code.InvalidAmount, `{tostring(amount)} : code {tostring(result.code)}`)
		end
		local missing = server.inventory.AddResource(USER_A, "green_leaf", nil :: any)
		check(missing.code == Code.InvalidAmount, "quantité absente acceptée")
		check(server.inventory.GetState(USER_A).used == 0, "inventaire modifié par une quantité invalide")
	end)

	case("refus d'une quantité négative", function(check)
		local server = newLoaded(function(profile)
			profile.inventory.resources.wood = 5
		end)
		for _, amount in ipairs({ -1, -5, -math.huge }) do
			local result = server.inventory.AddResource(USER_A, "wood", amount)
			check(not result.ok and result.code == Code.InvalidAmount, `{amount} : code {tostring(result.code)}`)
		end
		check(server.inventory.GetState(USER_A).resources.wood == 5, "quantité diminuée")
	end)

	case("refus d'une ressource inconnue", function(check)
		local server = newLoaded()
		local invalid: { any } = { "gold", "", "Green_Leaf", 12, {} }
		for _, resourceId in ipairs(invalid) do
			local result = server.inventory.AddResource(USER_A, resourceId, 1)
			check(not result.ok and result.code == Code.InvalidResource, `{tostring(resourceId)} : code {tostring(result.code)}`)
		end
		check(server.inventory.GetState(USER_A).used == 0, "inventaire modifié")
	end)

	case("ressources stockées inconnues comptées dans l'occupation", function(check)
		local server = newLoaded(function(profile)
			profile.inventory.resources.retired_resource = 7
		end)
		local state = server.inventory.GetState(USER_A)
		check(state.used == 7 and state.free == baseCapacity - 7, "ressource inconnue ignorée")
	end)

	case("l'état retourné est une copie", function(check)
		local server = newLoaded()
		server.inventory.AddResource(USER_A, "wood", 2)
		local state = server.inventory.GetState(USER_A)
		state.resources.wood = 999
		state.used = 999
		check(server.inventory.GetState(USER_A).resources.wood == 2, "le profil a été modifié par la copie")
	end)

	case("inventaires indépendants entre joueurs", function(check)
		local server = newLoaded()
		check(server.playerData.LoadPlayer(USER_B).ok, "chargement de B")
		server.inventory.AddResource(USER_A, "stone", 3)
		check(server.inventory.GetState(USER_B).used == 0, "l'inventaire de B a changé")
		server.inventory.AddResource(USER_B, "wood", 1)
		check(server.inventory.GetState(USER_A).resources.wood == nil, "l'inventaire de A a reçu la ressource de B")
		check(server.inventory.GetState(USER_A).resources.stone == 3, "l'inventaire de A a changé")
	end)

	case("persistance des quantités après reconnexion", function(check)
		local server, store = newLoaded()
		server.inventory.AddResource(USER_A, "green_leaf", 4)
		server.inventory.AddResource(USER_A, "stone", 2)
		check(store.getWriteCount() == 1, "une collecte a déclenché une écriture DataStore")
		check(server.playerData.ReleasePlayer(USER_A).ok, "libération en échec")

		local stored = store.peek(KEY_A)
		check(stored.profile.inventory.resources.green_leaf == 4, "feuilles non sauvegardées")
		check(stored.profile.inventory.resources.stone == 2, "pierres non sauvegardées")

		local other = newServer(store, "B")
		check(other.playerData.LoadPlayer(USER_A).ok, "rechargement en échec")
		local state = other.inventory.GetState(USER_A)
		check(state.resources.green_leaf == 4 and state.resources.stone == 2, "inventaire non restauré")
		check(state.used == 6, `used = {state.used}`)
	end)

	return failures, caseCount
end

return InventoryServiceTests
