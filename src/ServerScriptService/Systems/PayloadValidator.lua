--!strict
-- Lecture commune des payloads des RemoteEvents client -> serveur (T6).
--
-- Contrat inchangé (architecture 6.1, D-010, D-014, D-015) : chaque demande
-- est UNE table avec UN seul champ texte (`resourceId`, `sellZoneId`,
-- `upgradeId`, `worldId`). T6 ajoute :
--   * refus explicite des arguments supplémentaires après le payload ;
--   * jeu de caractères borné (lettres, chiffres, `_`, `-`) : les
--     identifiants du jeu n'en utilisent pas d'autres ;
--   * motif de refus pour la journalisation (jamais renvoyé au client : le
--     client reçoit toujours INVALID_TARGET).

local PayloadValidator = {}

PayloadValidator.Reason = table.freeze({
	ExtraArguments = "extra_arguments",
	NotTable = "not_table",
	MissingField = "missing_field",
	WrongType = "wrong_type",
	Empty = "empty",
	TooLong = "too_long",
	BadCharacters = "bad_characters",
	ExtraField = "extra_field",
})

local ID_PATTERN = "^[%w_%-]+$"

-- Lit l'identifiant `field` de `payload`. `extraArgumentCount` = nombre
-- d'arguments reçus après le payload (0 attendu ; nil = non contrôlé).
-- Retourne (identifiant, nil) ou (nil, motif).
function PayloadValidator.readId(
	payload: any,
	field: string,
	maxLength: number,
	extraArgumentCount: number?
): (string?, string?)
	local Reason = PayloadValidator.Reason
	if extraArgumentCount ~= nil and extraArgumentCount > 0 then
		return nil, Reason.ExtraArguments
	end
	if type(payload) ~= "table" then
		return nil, Reason.NotTable
	end
	local value = payload[field]
	if value == nil then
		return nil, Reason.MissingField
	end
	if type(value) ~= "string" then
		return nil, Reason.WrongType
	end
	if value == "" then
		return nil, Reason.Empty
	end
	if #value > maxLength then
		return nil, Reason.TooLong
	end
	if string.match(value, ID_PATTERN) == nil then
		return nil, Reason.BadCharacters
	end
	for key in pairs(payload) do
		if key ~= field then
			return nil, Reason.ExtraField
		end
	end
	return value, nil
end

return PayloadValidator
