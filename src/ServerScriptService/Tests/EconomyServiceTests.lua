--!strict
-- Tests d'EconomyService (T4) et du calcul du Multiplier (SaleValue).
-- Logique pure, sur des brouillons de profil : aucune API Roblox.

local EconomyServiceTests = {}

export type Modules = {
	EconomyService: any,
	SaleValue: any,
	DataSchema: any,
	UpgradeConfig: any,
	GameConfig: any,
}

function EconomyServiceTests.run(modules: Modules): ({ string }, number)
	local EconomyService = modules.EconomyService
	local SaleValue = modules.SaleValue
	local DataSchema = modules.DataSchema
	local Code = EconomyService.Code
	local MAX = EconomyService.MAX_SAFE_INTEGER
	local maxMultiplier = modules.GameConfig.Selling.maxSellMultiplier

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

	local function profileWith(coins: number): any
		local profile = DataSchema.newProfile()
		profile.currencies.coins = coins
		return profile
	end

	local function snapshot(profile: any): string
		return `{profile.currencies.coins}/{profile.stats.totalCoinsEarned}/{profile.stats.totalCoinsSpent}`
	end

	case("crédit valide", function(check)
		local draft = profileWith(10)
		local entry, code = EconomyService.credit(draft, 25, "Test")
		check(entry ~= nil and code == nil, `refusé : {tostring(code)}`)
		check(draft.currencies.coins == 35, "solde incorrect")
		check(draft.stats.totalCoinsEarned == 25, "totalCoinsEarned incorrect")
		check(draft.stats.totalCoinsSpent == 0, "totalCoinsSpent modifié par un crédit")
		check(entry ~= nil and entry.balanceAfter == 35 and entry.kind == "credit", "entrée de journal incorrecte")
	end)

	case("débit exact", function(check)
		local draft = profileWith(100)
		local entry, code = EconomyService.debit(draft, 100, "Test")
		check(entry ~= nil and code == nil, `refusé : {tostring(code)}`)
		check(draft.currencies.coins == 0, "solde final attendu : 0")
		check(draft.stats.totalCoinsSpent == 100, "totalCoinsSpent incorrect")
		check(draft.stats.totalCoinsEarned == 0, "totalCoinsEarned modifié par un débit")
	end)

	case("débit refusé si fonds insuffisants, rien ne change", function(check)
		local draft = profileWith(99)
		local before = snapshot(draft)
		local entry, code = EconomyService.debit(draft, 100, "Test")
		check(entry == nil and code == Code.InsufficientFunds, `code {tostring(code)}`)
		check(snapshot(draft) == before, "profil modifié par un refus")
	end)

	case("montants invalides refusés (0, négatif, décimal, NaN, infini, texte)", function(check)
		local invalid: { any } = { 0, -1, -100, 1.5, 0 / 0, math.huge, -math.huge, "10", MAX + 1 }
		for index, amount in ipairs(invalid) do
			local draft = profileWith(1_000)
			local before = snapshot(draft)
			local _, creditCode = EconomyService.credit(draft, amount, "Test")
			local _, debitCode = EconomyService.debit(draft, amount, "Test")
			check(creditCode == Code.InvalidAmount, `crédit n°{index} : {tostring(creditCode)}`)
			check(debitCode == Code.InvalidAmount, `débit n°{index} : {tostring(debitCode)}`)
			check(snapshot(draft) == before, `montant n°{index} : profil modifié`)
		end
	end)

	case("dépassement numérique refusé", function(check)
		local draft = profileWith(MAX - 5)
		local before = snapshot(draft)
		local _, code = EconomyService.credit(draft, 6, "Test")
		check(code == Code.Overflow, `solde : {tostring(code)}`)
		check(snapshot(draft) == before, "profil modifié")
		local spent = profileWith(10)
		spent.stats.totalCoinsSpent = MAX - 1
		local _, spentCode = EconomyService.debit(spent, 2, "Test")
		check(spentCode == Code.Overflow and spent.currencies.coins == 10, "totalCoinsSpent : dépassement accepté")
	end)

	case("profil illisible refusé", function(check)
		local draft = profileWith(10)
		draft.currencies.coins = -5
		local _, code = EconomyService.debit(draft, 1, "Test")
		check(code == Code.InvalidProfile, "solde négatif accepté")
		local _, nilCode = EconomyService.credit(nil, 1, "Test")
		check(nilCode == Code.InvalidProfile, "brouillon nil accepté")
	end)

	case("canAfford et balance", function(check)
		local profile = profileWith(50)
		check(EconomyService.balance(profile) == 50, "balance incorrect")
		check(EconomyService.canAfford(profile, 50), "50 doit être payable")
		check(not EconomyService.canAfford(profile, 51), "51 ne doit pas être payable")
		check(not EconomyService.canAfford(profile, -1), "montant négatif payable")
	end)

	case("journal : motif, montant, opération et solde", function(check)
		local draft = profileWith(10)
		local entry = EconomyService.debit(draft, 4, "Upgrade:Backpack")
		local line = EconomyService.describe(7, "Upgrade-1", entry)
		check(string.find(line, "-4 Coins", 1, true) ~= nil, "montant absent")
		check(string.find(line, "motif Upgrade:Backpack", 1, true) ~= nil, "motif absent")
		check(string.find(line, "opération Upgrade-1", 1, true) ~= nil, "opération absente")
		check(string.find(line, "solde 6", 1, true) ~= nil, "solde absent")
	end)

	-- Multiplier (D-015) : floor(total × multiplicateur), calcul entier.
	case("Multiplier : arrondi inférieur exact sur le total", function(check)
		local cases: { { number } } = {
			{ 100, 1.05, 105 },
			{ 20, 1.15, 23 }, -- 20 × 1,15 = 22,999… en flottant : 23 attendu
			{ 7, 1.05, 7 }, -- 7,35 -> 7
			{ 19, 1.10, 20 }, -- 20,9 -> 20
			{ 3, 1.50, 4 }, -- 4,5 -> 4
			{ 1, 1.00, 1 },
			{ 0, 1.30, 0 },
		}
		for _, row in ipairs(cases) do
			local result = SaleValue.applyMultiplier(row[1], row[2], maxMultiplier)
			check(result == row[3], `{row[1]} × {row[2]} = {tostring(result)}, attendu {row[3]}`)
		end
		for _, level in ipairs(modules.UpgradeConfig.Multiplier.levels) do
			local result = SaleValue.applyMultiplier(100, level.value, maxMultiplier)
			check(result == math.floor(level.value * 100 + 0.5), `x{level.value} sur 100 = {tostring(result)}`)
		end
	end)

	case("Multiplier : plafond global et entrées invalides", function(check)
		check(SaleValue.applyMultiplier(10, 9, maxMultiplier) == 10 * maxMultiplier, "plafond x5 non appliqué")
		check(SaleValue.applyMultiplier(10, 0.5, maxMultiplier) == nil, "multiplicateur < 1 accepté")
		check(SaleValue.applyMultiplier(10, 0 / 0, maxMultiplier) == nil, "NaN accepté")
		check(SaleValue.applyMultiplier(-1, 1.05, maxMultiplier) == nil, "total négatif accepté")
		check(SaleValue.applyMultiplier(1.5, 1.05, maxMultiplier) == nil, "total décimal accepté")
		check(SaleValue.applyMultiplier(MAX, 1.05, maxMultiplier) == nil, "dépassement accepté")
	end)

	return failures, caseCount
end

return EconomyServiceTests
