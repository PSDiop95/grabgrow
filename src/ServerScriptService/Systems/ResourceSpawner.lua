--!strict
-- Registre et cycle de vie des ressources collectables (logique pure).
--
-- Chaque nœud a un identifiant stable attribué par le serveur
-- (ex. "green_leaf_001") et un état explicite :
--
--   ACTIVE -> COLLECTED -> RESPAWNING -> ACTIVE
--
-- `TryCollect` est la seule transition qui sort de ACTIVE. Elle ne suspend
-- jamais le fil : deux demandes sur le même nœud ne peuvent pas réussir
-- toutes les deux. COLLECTED est l'instant de la collecte ; le nœud passe
-- aussitôt en RESPAWNING, puis sa réapparition est programmée.
--
-- Aucune Instance ici : l'affichage est branché par `onStateChanged`
-- (Systems/ResourceNodes). Horloge et minuterie injectées, donc testable
-- sans Roblox.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)

local ResourceSpawner = {}

ResourceSpawner.State = table.freeze({
	Active = "ACTIVE",
	Collected = "COLLECTED",
	Respawning = "RESPAWNING",
})

export type Position = { X: number, Y: number, Z: number }

-- Vue d'un nœud : copie, sans effet sur le registre.
export type Node = {
	id: string,
	resourceType: string,
	position: Position,
	state: string,
}

export type Dependencies = {
	-- Appelle `callback` après `delaySeconds` (task.delay en production).
	schedule: (delaySeconds: number, callback: () -> ()) -> (),
	onStateChanged: ((nodeId: string, state: string) -> ())?,
}

type InternalNode = {
	id: string,
	resourceType: string,
	position: Position,
	state: string,
	-- Incrémenté à chaque collecte : une minuterie périmée est ignorée.
	cycle: number,
}

function ResourceSpawner.new(dependencies: Dependencies)
	local schedule = dependencies.schedule
	local onStateChanged = dependencies.onStateChanged

	local nodes: { [string]: InternalNode } = {}
	local count = 0

	local spawner = {}

	local function setState(node: InternalNode, state: string)
		node.state = state
		if onStateChanged then
			onStateChanged(node.id, state)
		end
	end

	-- Ajoute un nœud ACTIVE. Refuse un identifiant déjà utilisé ou un type
	-- absent de ResourceConfig. Retourne (true) ou (false, raison).
	function spawner.Register(nodeId: string, resourceType: string, position: Position): (boolean, string?)
		if type(nodeId) ~= "string" or nodeId == "" then
			return false, "identifiant de nœud invalide"
		end
		if nodes[nodeId] ~= nil then
			return false, `nœud {nodeId} déjà enregistré`
		end
		if ResourceConfig[resourceType] == nil then
			return false, `type de ressource inconnu : {tostring(resourceType)}`
		end
		nodes[nodeId] = {
			id = nodeId,
			resourceType = resourceType,
			position = { X = position.X, Y = position.Y, Z = position.Z },
			state = ResourceSpawner.State.Active,
			cycle = 0,
		}
		count += 1
		return true, nil
	end

	-- Retire un nœud. Sa réapparition en attente, s'il y en a une, est ignorée.
	function spawner.Unregister(nodeId: string): boolean
		if nodes[nodeId] == nil then
			return false
		end
		nodes[nodeId] = nil
		count -= 1
		return true
	end

	function spawner.GetNode(nodeId: string): Node?
		local node = nodes[nodeId]
		if node == nil then
			return nil
		end
		return {
			id = node.id,
			resourceType = node.resourceType,
			position = node.position,
			state = node.state,
		}
	end

	function spawner.Count(): number
		return count
	end

	-- Consomme un nœud ACTIVE et programme sa réapparition.
	-- false : nœud inconnu ou déjà consommé (rien ne change).
	function spawner.TryCollect(nodeId: string): boolean
		local node = nodes[nodeId]
		if node == nil or node.state ~= ResourceSpawner.State.Active then
			return false
		end

		node.cycle += 1
		local cycle = node.cycle
		setState(node, ResourceSpawner.State.Collected)
		setState(node, ResourceSpawner.State.Respawning)

		local respawnSeconds = ResourceConfig[node.resourceType].respawnSeconds
		schedule(respawnSeconds, function()
			-- Nœud retiré, ou minuterie d'un cycle précédent : ne rien faire.
			if nodes[nodeId] ~= node or node.cycle ~= cycle then
				return
			end
			if node.state == ResourceSpawner.State.Respawning then
				setState(node, ResourceSpawner.State.Active)
			end
		end)
		return true
	end

	-- Retire tous les nœuds. Les minuteries en attente deviennent sans effet.
	function spawner.Destroy()
		nodes = {}
		count = 0
	end

	return spawner
end

return ResourceSpawner
