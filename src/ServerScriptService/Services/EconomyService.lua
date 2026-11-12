--!strict
-- Opérations sur les Coins (T4, décisions D-014 et D-015). Serveur uniquement.
--
-- Fonctions appliquées au BROUILLON d'un PlayerDataService.Update, jamais
-- au profil directement : l'appelant les combine avec ses autres
-- modifications (retrait de ressources, hausse de niveau, déblocage) dans
-- la même mutation. L'opération entière est donc atomique : tout ou rien,
-- sans suspension du fil, donc sans double débit ni lecture concurrente.
-- Aucune sauvegarde DataStore n'est déclenchée ici.
--
-- Règles :
--   * montant = entier >= 1 (0, négatif, décimal, NaN, infini refusés) ;
--   * solde jamais négatif : débit refusé si coins < montant ;
--   * aucun résultat au-delà de MAX_SAFE_INTEGER (solde ou statistique) ;
--   * crédit -> stats.totalCoinsEarned ; débit -> stats.totalCoinsSpent ;
--   * un refus ne modifie rien.
--
-- Le journal (Bible 13.3) est écrit par l'appelant après le succès de
-- l'Update, avec `describe` : un refus de schéma annule aussi l'entrée.

local EconomyService = {}

EconomyService.MAX_SAFE_INTEGER = 9_007_199_254_740_991

EconomyService.Code = table.freeze({
	InvalidAmount = "InvalidAmount",
	InsufficientFunds = "InsufficientFunds",
	Overflow = "Overflow",
	InvalidProfile = "InvalidProfile",
})

export type Entry = {
	kind: string, -- "credit" | "debit"
	amount: number,
	currency: string,
	reason: string,
	balanceAfter: number,
}

local function isAmount(value: any): boolean
	-- NaN et l'infini échouent au test du modulo.
	return type(value) == "number" and value % 1 == 0 and value >= 1 and value <= EconomyService.MAX_SAFE_INTEGER
end

local function isBalance(value: any): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 0 and value <= EconomyService.MAX_SAFE_INTEGER
end

-- Sections du brouillon utilisées, ou nil si le profil est illisible.
local function sections(draft: any): (any?, any?)
	if type(draft) ~= "table" or type(draft.currencies) ~= "table" or type(draft.stats) ~= "table" then
		return nil, nil
	end
	local currencies, stats = draft.currencies, draft.stats
	if not isBalance(currencies.coins) or not isBalance(stats.totalCoinsEarned) or not isBalance(stats.totalCoinsSpent) then
		return nil, nil
	end
	return currencies, stats
end

-- Solde de Coins d'un profil (copie ou brouillon), ou nil.
function EconomyService.balance(profile: any): number?
	local currencies = sections(profile)
	return if currencies then currencies.coins else nil
end

-- Le profil peut-il payer `amount` ? Lecture seule.
function EconomyService.canAfford(profile: any, amount: number): boolean
	local balance = EconomyService.balance(profile)
	return balance ~= nil and isAmount(amount) and balance >= amount
end

-- Crédite `amount` Coins dans le brouillon. Retourne (entrée, nil) ou (nil, code).
function EconomyService.credit(draft: any, amount: number, reason: string): (Entry?, string?)
	if not isAmount(amount) then
		return nil, EconomyService.Code.InvalidAmount
	end
	local currencies, stats = sections(draft)
	if currencies == nil or stats == nil then
		return nil, EconomyService.Code.InvalidProfile
	end
	if currencies.coins > EconomyService.MAX_SAFE_INTEGER - amount
		or stats.totalCoinsEarned > EconomyService.MAX_SAFE_INTEGER - amount
	then
		return nil, EconomyService.Code.Overflow
	end
	currencies.coins += amount
	stats.totalCoinsEarned += amount
	return { kind = "credit", amount = amount, currency = "Coins", reason = reason, balanceAfter = currencies.coins }, nil
end

-- Débite `amount` Coins du brouillon. Retourne (entrée, nil) ou (nil, code).
function EconomyService.debit(draft: any, amount: number, reason: string): (Entry?, string?)
	if not isAmount(amount) then
		return nil, EconomyService.Code.InvalidAmount
	end
	local currencies, stats = sections(draft)
	if currencies == nil or stats == nil then
		return nil, EconomyService.Code.InvalidProfile
	end
	if currencies.coins < amount then
		return nil, EconomyService.Code.InsufficientFunds
	end
	if stats.totalCoinsSpent > EconomyService.MAX_SAFE_INTEGER - amount then
		return nil, EconomyService.Code.Overflow
	end
	currencies.coins -= amount
	stats.totalCoinsSpent += amount
	return { kind = "debit", amount = amount, currency = "Coins", reason = reason, balanceAfter = currencies.coins }, nil
end

-- Ligne de journal d'une opération réussie (Bible 13.3). `operationId`
-- identifie l'opération côté serveur ; aucune donnée personnelle.
function EconomyService.describe(userId: number, operationId: string, entry: Entry): string
	local sign = if entry.kind == "credit" then "+" else "-"
	return `joueur {userId} : {sign}{entry.amount} {entry.currency} (motif {entry.reason}, opération {operationId}, solde {entry.balanceAfter})`
end

return EconomyService
