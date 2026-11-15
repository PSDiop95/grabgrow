--!strict
-- Tests des règles d'affichage du voyage (T8.2) : île courante, état d'un
-- monde (boutique, portail), demandes envoyées ou bloquées côté client,
-- messages de refus, textes EN/FR. Logique pure : aucune API Roblox. Le
-- rendu des portails et de la boutique se vérifie dans Studio.

local TravelRulesTests = {}

export type Modules = {
	TravelRules: any,
	Localization: any,
	WorldConfig: any,
	Remotes: any,
}

function TravelRulesTests.run(modules: Modules): ({ string }, number)
	local TravelRules = modules.TravelRules
	local Localization = modules.Localization
	local WorldConfig = modules.WorldConfig
	local Code = modules.Remotes.ResultCode
	local State = TravelRules.State

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

	local POINTS = {
		{ worldId = "GreenValley", X = 0, Z = 12 },
		{ worldId = "GoldenDesert", X = 3000, Z = 0 },
	}

	local function info(unlocked: boolean, available: boolean, current: boolean, pending: boolean): any
		return { unlocked = unlocked, available = available, current = current, pending = pending }
	end

	case("île courante : point d'arrivée le plus proche", function(check)
		check(TravelRules.currentWorld({ X = 90, Z = -60 }, POINTS) == "GreenValley", "Green Valley non reconnue")
		check(TravelRules.currentWorld({ X = 2960, Z = 30 }, POINTS) == "GoldenDesert", "Golden Desert non reconnu")
		check(TravelRules.currentWorld({ X = 1400, Z = 6 }, POINTS) == "GreenValley", "entre deux îles : point le plus proche attendu")
	end)

	case("île courante : sans position ou sans point d'arrivée", function(check)
		check(TravelRules.currentWorld(nil, POINTS) == nil, "position absente")
		check(TravelRules.currentWorld({ X = 0, Z = 0 }, {}) == nil, "aucun point d'arrivée")
	end)

	case("île courante : égalité résolue par ordre alphabétique", function(check)
		local points = { { worldId = "MysticWorld", X = 10, Z = 0 }, { worldId = "FrozenPeaks", X = -10, Z = 0 } }
		check(TravelRules.currentWorld({ X = 0, Z = 0 }, points) == "FrozenPeaks", "résultat instable")
	end)

	case("état d'un monde : priorités", function(check)
		check(TravelRules.rowState(info(false, true, false, false)) == State.Locked, "verrouillé")
		-- Verrouillé l'emporte, même si le joueur s'y trouve (miroir en retard).
		check(TravelRules.rowState(info(false, true, true, true)) == State.Locked, "verrou prioritaire")
		check(TravelRules.rowState(info(true, true, true, false)) == State.Here, "île courante")
		check(TravelRules.rowState(info(true, false, false, false)) == State.ComingSoon, "sans île")
		check(TravelRules.rowState(info(true, true, false, true)) == State.Pending, "en attente")
		check(TravelRules.rowState(info(true, true, false, false)) == State.Travel, "voyage possible")
	end)

	case("demande envoyée seulement si le voyage est possible", function(check)
		for _, state in pairs(State) do
			check(TravelRules.shouldRequest(state) == (state == State.Travel), `état {state}`)
		end
	end)

	case("messages sans demande : verrouillé, à venir ; rien sinon", function(check)
		check(TravelRules.blockedMessage(State.Locked) == "travel.locked", "verrouillé")
		check(TravelRules.blockedMessage(State.ComingSoon) == "world.coming_soon", "à venir")
		check(TravelRules.blockedMessage(State.Here) == nil, "île courante : message inutile")
		check(TravelRules.blockedMessage(State.Pending) == nil, "en attente : message inutile")
	end)

	case("messages de refus du serveur", function(check)
		check(TravelRules.refusalMessage(Code.WorldLocked, Code) == "travel.locked", "WORLD_LOCKED")
		check(TravelRules.refusalMessage(Code.WorldUnavailable, Code) == "world.coming_soon", "WORLD_UNAVAILABLE")
		check(TravelRules.refusalMessage(Code.NoCharacter, Code) == "travel.no_character", "NO_CHARACTER")
		check(TravelRules.refusalMessage(Code.RateLimited, Code) == "travel.wait", "RATE_LIMITED")
		check(TravelRules.refusalMessage(Code.InvalidTarget, Code) == nil, "INVALID_TARGET silencieux")
		check(TravelRules.refusalMessage(nil, Code) == nil, "code absent")
	end)

	case("textes EN/FR des messages et des boutons", function(check)
		local keys = { "travel.go", "travel.here", "travel.arrived", "travel.locked", "travel.wait", "travel.no_character", "world.coming_soon", "world.locked" }
		for _, key in ipairs(keys) do
			for _, language in ipairs({ "en", "fr" }) do
				check(Localization.has(key, language), `{key} absent en {language}`)
			end
		end
		for worldId, world in pairs(WorldConfig) do
			local text = Localization.fill("travel.arrived", "fr-fr", { world = Localization.get(world.displayNameKey, "fr-fr") })
			check(string.find(text, "{", 1, true) == nil, `{worldId} : motif non remplacé`)
		end
		check(Localization.get("travel.go", "fr-fr") == "Voyager", "bouton FR")
		check(Localization.get("travel.go", "en-us") == "Travel", "bouton EN")
	end)

	return failures, caseCount
end

return TravelRulesTests
