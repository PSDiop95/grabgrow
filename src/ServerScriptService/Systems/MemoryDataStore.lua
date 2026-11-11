--!strict
-- Magasin en mémoire exposant la même méthode que GlobalDataStore
-- (`UpdateAsync`). Deux usages, tous deux explicites :
--   * tests automatisés (injecté dans PlayerDataService) ;
--   * Studio, si DataConfig.Studio.useMemoryStore = true (voir Bootstrap).
-- Jamais utilisé hors Studio : Bootstrap ne le crée que si
-- RunService:IsStudio() est vrai.
--
-- Pour ne pas masquer des défauts que le DataStore réel révélerait :
--   * les valeurs sont copiées à l'entrée et à la sortie (pas de référence
--     partagée, comme après une sérialisation) ;
--   * une valeur non sérialisable en JSON provoque une erreur ;
--   * la fonction de transformation est appelée deux fois (le DataStore
--     réel peut la rejouer en cas de conflit) : elle doit être rejouable ;
--   * retourner nil annule l'écriture.
-- Non reproduit : quotas, latence et limites de taille réels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local MemoryDataStore = {}

local SIMULATED_FAILURE = "MemoryDataStore : échec simulé"

local function assertSerializable(value: any, path: string)
	local kind = type(value)
	if kind == "string" or kind == "boolean" then
		return
	end
	if kind == "number" then
		if value ~= value or math.abs(value) == math.huge then
			error(`{path} : nombre non sérialisable ({tostring(value)})`)
		end
		return
	end
	if kind ~= "table" then
		error(`{path} : type non sérialisable ({kind})`)
	end

	local total, stringKeys = 0, 0
	for key, child in pairs(value) do
		total += 1
		if type(key) == "string" then
			stringKeys += 1
		elseif type(key) ~= "number" then
			error(`{path} : clé non sérialisable ({type(key)})`)
		end
		assertSerializable(child, `{path}.{tostring(key)}`)
	end
	if stringKeys ~= 0 and stringKeys ~= total then
		error(`{path} : clés texte et numériques mélangées`)
	end
	if stringKeys == 0 and total ~= #value then
		error(`{path} : tableau non contigu`)
	end
end

function MemoryDataStore.new()
	local values: { [string]: any } = {}
	local failuresBeforeWrite = 0
	local failuresAfterWrite = 0
	local alwaysFail = false
	local beforeCall: ((key: string) -> ())? = nil
	local writeCount = 0
	local activeCalls = 0
	local maxActiveCalls = 0

	local store = {}

	local function update(key: string, transform: (any, any) -> ...any): any
		if alwaysFail then
			error(SIMULATED_FAILURE)
		end
		if failuresBeforeWrite > 0 then
			failuresBeforeWrite -= 1
			error(SIMULATED_FAILURE)
		end

		transform(TableUtil.deepCopy(values[key]), nil)
		local newValue = transform(TableUtil.deepCopy(values[key]), nil)
		if newValue == nil then
			return nil
		end

		assertSerializable(newValue, key)
		values[key] = TableUtil.deepCopy(newValue)
		writeCount += 1

		if failuresAfterWrite > 0 then
			failuresAfterWrite -= 1
			error(SIMULATED_FAILURE)
		end
		return TableUtil.deepCopy(newValue)
	end

	-- Même signature que GlobalDataStore:UpdateAsync.
	function store.UpdateAsync(_self: any, key: string, transform: (any, any) -> ...any): any
		activeCalls += 1
		maxActiveCalls = math.max(maxActiveCalls, activeCalls)
		-- Point de suspension : simule la latence réseau avant l'écriture.
		local ok, result = pcall(function(): any
			if beforeCall then
				beforeCall(key)
			end
			return update(key, transform)
		end)
		activeCalls -= 1
		if not ok then
			error(result, 0)
		end
		return result
	end

	-- Outils de test ------------------------------------------------------

	-- Place directement une valeur, comme si un autre serveur l'avait écrite.
	function store.seed(key: string, value: any)
		values[key] = TableUtil.deepCopy(value)
	end

	function store.peek(key: string): any
		return TableUtil.deepCopy(values[key])
	end

	-- Les `count` prochains appels échouent sans rien écrire.
	function store.failNext(count: number)
		failuresBeforeWrite = count
	end

	-- Les `count` prochaines écritures réussissent mais l'appel signale une
	-- erreur (réponse perdue après validation côté DataStore).
	function store.failAfterWriteNext(count: number)
		failuresAfterWrite = count
	end

	function store.setAlwaysFail(enabled: boolean)
		alwaysFail = enabled
	end

	-- Fonction appelée au début de chaque appel ; peut suspendre le fil.
	function store.setBeforeCall(callback: ((key: string) -> ())?)
		beforeCall = callback
	end

	function store.getWriteCount(): number
		return writeCount
	end

	function store.getMaxConcurrentCalls(): number
		return maxActiveCalls
	end

	return store
end

return MemoryDataStore
