--!strict
-- Valeur de vente d'un inventaire (T3). Formule unique, partagée :
--   * le serveur (SellService) l'applique au profil autoritatif ;
--   * le client l'utilise seulement pour afficher une estimation.
--
-- Formule (Bible économique 3.1) : base = somme(quantité × sellValue).
-- T4 (D-015) : montant crédité = applyMultiplier(base, Multiplier), arrondi
-- à l'entier inférieur, une fois par vente. Aucun bonus ni taxe.
--
-- Vendable = identifiant présent dans ResourceConfig, avec un sellValue
-- entier >= 1, et une quantité entière >= 1. Les ressources inconnues de
-- ResourceConfig (conservées par D-008) ne sont jamais vendues ni
-- valorisées : elles sont seulement comptées à part (D-014).
--
-- Logique pure : aucun appel réseau, aucun état.

local ResourceConfig = require(script.Parent.Parent.Config.ResourceConfig)

local SaleValue = {}

-- Au-delà, un nombre flottant ne représente plus tous les entiers. Même
-- borne que DataSchema (contrôlé par les tests).
SaleValue.MAX_SAFE_INTEGER = 9_007_199_254_740_991

export type Quote = {
	-- Coins que rapporterait la vente (0 si rien n'est vendable).
	total: number,
	-- Quantités vendues par ressource connue.
	items: { [string]: number },
	-- Nombre total d'unités vendues.
	quantity: number,
	-- Unités non vendables (ressources inconnues) laissées dans le sac.
	unsellableQuantity: number,
	-- true : le calcul dépasserait MAX_SAFE_INTEGER ; la vente doit être refusée.
	overflow: boolean,
}

local function isCount(value: any): boolean
	-- NaN et l'infini échouent au test du modulo.
	return type(value) == "number" and value % 1 == 0 and value >= 1 and value <= SaleValue.MAX_SAFE_INTEGER
end

-- Prix unitaire d'une ressource vendable, ou nil.
function SaleValue.unitPrice(resourceId: string): number?
	local definition = ResourceConfig[resourceId]
	if definition == nil then
		return nil
	end
	local price = definition.sellValue
	if not isCount(price) then
		return nil
	end
	return price
end

-- Devis d'un inventaire `{ [resourceId] = quantité }`. Ne modifie pas `resources`.
function SaleValue.quote(resources: { [string]: number }): Quote
	local quote: Quote = {
		total = 0,
		items = {},
		quantity = 0,
		unsellableQuantity = 0,
		overflow = false,
	}
	if type(resources) ~= "table" then
		return quote
	end
	for resourceId, quantity in pairs(resources) do
		if isCount(quantity) then
			local price = if type(resourceId) == "string" then SaleValue.unitPrice(resourceId) else nil
			if price == nil then
				quote.unsellableQuantity += quantity
			elseif quantity > math.floor(SaleValue.MAX_SAFE_INTEGER / price) then
				quote.overflow = true
			else
				local value = quantity * price
				if quote.total > SaleValue.MAX_SAFE_INTEGER - value
					or quote.quantity > SaleValue.MAX_SAFE_INTEGER - quantity
				then
					quote.overflow = true
				else
					quote.total += value
					quote.quantity += quantity
					quote.items[resourceId] = quantity
				end
			end
		end
	end
	return quote
end

-- Multiplicateur de vente exprimé en centièmes entiers (1,05 -> 105), borné
-- à [1, maxMultiplier]. Le calcul en centièmes évite les erreurs de
-- flottant (20 × 1,15 = 22,999… en double précision). nil si invalide.
function SaleValue.multiplierHundredths(multiplier: number, maxMultiplier: number): number?
	if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 or multiplier == math.huge then
		return nil
	end
	local capped = math.min(multiplier, maxMultiplier)
	return math.floor(capped * 100 + 0.5)
end

-- Montant final d'une vente (D-015) : floor(total × multiplicateur), calculé
-- une seule fois sur le total, en entiers. nil si le calcul dépasserait
-- MAX_SAFE_INTEGER ou si une entrée est invalide.
function SaleValue.applyMultiplier(total: number, multiplier: number, maxMultiplier: number): number?
	if type(total) ~= "number" or total % 1 ~= 0 or total < 0 or total > SaleValue.MAX_SAFE_INTEGER then
		return nil
	end
	local hundredths = SaleValue.multiplierHundredths(multiplier, maxMultiplier)
	if hundredths == nil then
		return nil
	end
	if total > math.floor(SaleValue.MAX_SAFE_INTEGER / hundredths) then
		return nil
	end
	return (total * hundredths) // 100
end

-- a + b reste-t-il un entier exact ? (a, b >= 0)
function SaleValue.canAdd(a: number, b: number): boolean
	return a <= SaleValue.MAX_SAFE_INTEGER - b
end

return SaleValue
