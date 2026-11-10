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

return TableUtil
