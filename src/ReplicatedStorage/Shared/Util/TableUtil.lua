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

return TableUtil
