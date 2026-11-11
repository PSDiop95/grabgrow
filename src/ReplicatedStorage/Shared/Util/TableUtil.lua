--!strict
-- Utilitaires de tables partagés client/serveur.

local TableUtil = {}

-- Gèle récursivement une table de configuration pour empêcher toute
-- modification accidentelle à l'exécution (les configs sont partagées).
function TableUtil.deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, child in pairs(value :: any) do
			TableUtil.deepFreeze(child)
		end
		table.freeze(value :: any)
	end
	return value
end

-- Copie récursive, non gelée, sans référence partagée avec l'original.
-- Réservé aux données simples (pas de cycle, pas de métatable).
function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value :: any) do
		copy[key] = TableUtil.deepCopy(child)
	end
	return copy :: any
end

-- Égalité structurelle de données simples (tables comparées par contenu).
function TableUtil.deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not TableUtil.deepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

return TableUtil
