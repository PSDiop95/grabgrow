--!strict
-- Tests du guidage de première session (T5.3).
--
-- Deux niveaux :
--   * règles pures (OnboardingRules) : étapes, indications, refus, doublons,
--     masquage, appareils, textes EN/FR ;
--   * parcours avec de vrais services (PlayerDataService, InventoryService,
--     CollectionService, SellService, UpgradeService, WorldUnlockService),
--     un magasin en mémoire et une horloge simulée : l'étape est calculée
--     comme dans OnboardingController, à partir de l'état client
--     (GetClientState) et des réponses serveur telles que Bootstrap les
--     envoie. Déconnexion = ReleasePlayer puis chargement sur un nouveau
--     serveur partageant le magasin.
-- Aucune API Roblox ; le rendu se vérifie dans Studio.

local OnboardingTests = {}

export type Modules = {
	OnboardingRules: any,
	OnboardingConfig: any,
	Localization: any,
	UpgradeMath: any,
	UpgradeConfig: any,
	DataSchema: any,
	PlayerDataService: any,
	InventoryService: any,
	CollectionService: any,
	SellService: any,
	UpgradeService: any,
	WorldUnlockService: any,
	ResourceSpawner: any,
	MemoryDataStore: any,
	Remotes: any,
}

local USER_A = 6001
local USER_B = 6002
local ZONE = "GreenValley_Main"
local LEAF = "green_leaf_onb"
local UNLIMITED = {
	Allow = function(): boolean
		return true
	end,
	Clear = function() end,
}

-- Longueur maximale d'un texte de guidage (carte de ~210 px, 3 lignes).
local MAX_TEXT_LENGTH = 72
local MAX_CONTROLS_LENGTH = 48

function OnboardingTests.run(modules: Modules): ({ string }, number)
	local Rules = modules.OnboardingRules
	local OnboardingConfig = modules.OnboardingConfig
	local Localization = modules.Localization
	local UpgradeMath = modules.UpgradeMath
	local UpgradeConfig = modules.UpgradeConfig
	local DataSchema = modules.DataSchema
	local PlayerDataService = modules.PlayerDataService
	local InventoryService = modules.InventoryService
	local CollectionService = modules.CollectionService
	local SellService = modules.SellService
	local UpgradeService = modules.UpgradeService
	local WorldUnlockService = modules.WorldUnlockService
	local ResourceSpawner = modules.ResourceSpawner
	local MemoryDataStore = modules.MemoryDataStore
	local Remotes = modules.Remotes
	local Code = Remotes.ResultCode
	local Action = Remotes.Action
	local Step = Rules.Step

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

	local interval = UpgradeConfig.Grabber.levels[1].value
	local backpackCost = UpgradeMath.nextCost("Backpack", 1)
	local threshold = OnboardingConfig.sellHintMinItems

	-- Serveur simulé. `store` : magasin partagé (reconnexion).
	local function newEnv(userIds: { number }, store: any?)
		local env = {
			now = 1000,
			store = store or MemoryDataStore.new(),
			positions = {} :: { [number]: any },
			timers = {} :: { () -> () },
		}
		local function clock(): number
			return env.now
		end
		local function getPosition(userId: number): any
			return env.positions[userId]
		end
		local function log() end
		env.playerData = PlayerDataService.new({
			store = env.store,
			serverId = "S",
			clock = function(): number
				return 1_000_000
			end,
			wait = function() end,
			spawn = function(callback: () -> ())
				callback()
			end,
			log = log,
		})
		env.inventory = InventoryService.new({ playerData = env.playerData })
		env.spawner = ResourceSpawner.new({
			schedule = function(_: number, callback: () -> ())
				table.insert(env.timers, callback)
			end,
		})
		env.spawner.Register(LEAF, "green_leaf", { X = 1, Y = 0, Z = 0 })
		env.collection = CollectionService.new({
			playerData = env.playerData,
			inventory = env.inventory,
			spawner = env.spawner,
			rateLimit = UNLIMITED,
			clock = clock,
			getCharacterPosition = getPosition,
			log = log,
		})
		env.sell = SellService.new({
			playerData = env.playerData,
			rateLimit = UNLIMITED,
			getSellZone = function(zoneId: string): any
				return if zoneId == ZONE then { position = { X = 0, Y = 0, Z = 0 } } else nil
			end,
			getCharacterPosition = getPosition,
			clock = clock,
			log = log,
		})
		env.upgrade = UpgradeService.new({
			playerData = env.playerData,
			rateLimit = UNLIMITED,
			clock = clock,
			log = log,
		})
		env.world = WorldUnlockService.new({
			playerData = env.playerData,
			rateLimit = UNLIMITED,
			clock = clock,
			log = log,
		})
		for _, userId in ipairs(userIds) do
			assert(env.playerData.LoadPlayer(userId).ok, "chargement du joueur de test")
			env.positions[userId] = { X = 0, Y = 0, Z = 0 }
		end

		-- Réponses au format envoyé par Bootstrap (ActionResult).
		function env.collect(userId: number): any
			env.now += interval + 0.05
			-- Réapparitions en attente : exécutées tout de suite.
			local pending = env.timers
			env.timers = {}
			for _, callback in ipairs(pending) do
				callback()
			end
			local result = env.collection.HandleRequest(userId, { resourceId = LEAF })
			return { action = Action.Collect, ok = result.ok, code = result.code, resourceType = result.resourceType, amount = result.amount }
		end
		function env.sellAll(userId: number): any
			env.now += 5
			local result = env.sell.HandleRequest(userId, { sellZoneId = ZONE })
			return { action = Action.Sell, ok = result.ok, code = result.code, coinsEarned = result.coinsEarned }
		end
		function env.buy(userId: number, upgradeId: string): any
			env.now += 5
			local result = env.upgrade.HandleRequest(userId, { upgradeId = upgradeId })
			return { action = Action.Upgrade, ok = result.ok, code = result.code, upgradeId = result.upgradeId, level = result.level }
		end
		function env.state(userId: number): any
			return env.collection.GetClientState(userId)
		end
		function env.prepare(userId: number, mutate: (draft: any) -> ())
			local result = env.playerData.Update(userId, function(draft: any): boolean?
				mutate(draft)
				return nil
			end)
			assert(result.ok, "préparation du profil")
		end
		return env
	end

	-- Client simulé : même enchaînement que OnboardingController.
	local function newClient()
		local client = { step = nil :: string?, events = {} :: { string } }
		function client.onState(state: any)
			client.step = Rules.merge(client.step, Rules.fromState(state))
		end
		function client.onResult(result: any)
			if client.step == nil then
				return
			end
			local newStep, event = Rules.afterResult(client.step, result)
			client.step = newStep
			if event then
				table.insert(client.events, event)
			end
		end
		-- Une action serveur : réponse puis état (ordre de Bootstrap).
		function client.apply(env: any, userId: number, result: any)
			client.onResult(result)
			if result.ok then
				client.onState(env.state(userId))
			end
		end
		return client
	end

	-- 1. NOUVEAU JOUEUR ------------------------------------------------------

	case("nouveau joueur : accueil puis collecte", function(check)
		local env = newEnv({ USER_A })
		local state = env.state(USER_A)
		check(type(state.progress) == "table", "progression absente de l'état client")
		check(Rules.fromState(state) == Step.Collect, "étape déduite incorrecte")
		local client = newClient()
		client.onState(state)
		check(client.step == Step.Intro, `accueil attendu, reçu {tostring(client.step)}`)
		local intro = Rules.hint(Step.Intro, state, false)
		check(intro.titleKey == "onboarding.welcome_title" and intro.target == nil, "accueil incorrect")
		-- Un second état (ex. inventaire) ne termine pas l'accueil.
		client.onState(state)
		check(client.step == Step.Intro, "accueil terminé par un état")
		client.step = Rules.endIntro(client.step)
		check(client.step == Step.Collect, "fin d'accueil incorrecte")
		local hint = Rules.hint(Step.Collect, state, false)
		check(hint.key == "onboarding.collect" and hint.target == "resource" and hint.controls == "collect", "indication de collecte")
		check(hint.stepNumber == 1, "numéro d'étape")
	end)

	-- 2. PREMIÈRE COLLECTE ---------------------------------------------------

	case("première collecte confirmée par le serveur", function(check)
		local env = newEnv({ USER_A })
		local client = newClient()
		client.onState(env.state(USER_A))
		local result = env.collect(USER_A)
		check(result.ok and result.code == Code.Success, `collecte refusée ({tostring(result.code)})`)
		client.apply(env, USER_A, result)
		check(client.step == Step.Sell, `étape Vendre attendue, reçu {tostring(client.step)}`)
		check(client.events[1] == "collected" and #client.events == 1, "événement de collecte")
		check(env.state(USER_A).progress.resourcesCollected == 1, "miroir des statistiques")
		-- Peu de ressources : continuer à collecter, pas encore la station.
		local hint = Rules.hint(Step.Sell, env.state(USER_A), false)
		check(hint.key == "onboarding.keep_collecting" and hint.target == "resource", "indication avant le seuil")
		for _ = 2, threshold do
			client.apply(env, USER_A, env.collect(USER_A))
		end
		hint = Rules.hint(Step.Sell, env.state(USER_A), false)
		check(hint.key == "onboarding.sell" and hint.target == "sell" and hint.controls == "sell", "station non montrée au seuil")
		check(#client.events == 1, "collectes suivantes comptées comme étapes")
	end)

	case("demande de collecte sans confirmation : aucune étape", function(check)
		local client = newClient()
		client.step = Step.Collect
		-- Une demande cliente n'est pas une réponse serveur.
		client.onResult({ resourceId = LEAF })
		client.onResult({ action = Action.Collect, ok = true, code = Code.Success })
		client.onResult({ action = Action.Collect, ok = true, code = Code.Success, amount = 0 })
		check(client.step == Step.Collect and #client.events == 0, "étape validée sans collecte confirmée")
	end)

	-- 3. PREMIÈRE VENTE ------------------------------------------------------

	case("première vente confirmée, Coins affichés depuis le serveur", function(check)
		local env = newEnv({ USER_A })
		local client = newClient()
		client.onState(env.state(USER_A))
		for _ = 1, 3 do
			client.apply(env, USER_A, env.collect(USER_A))
		end
		-- Vente avant le seuil pédagogique : reconnue.
		local sale = env.sellAll(USER_A)
		check(sale.ok and sale.coinsEarned > 0, `vente refusée ({tostring(sale.code)})`)
		client.apply(env, USER_A, sale)
		check(client.step == Step.Upgrade, `étape Améliorer attendue, reçu {tostring(client.step)}`)
		check(client.events[2] == "sold", "événement de vente")
		local state = env.state(USER_A)
		check(state.progress.sales == 1, "totalSales non reflété")
		local hint = Rules.hint(Step.Upgrade, state, false)
		check(hint.key == "onboarding.earn_more", "indication sans achat possible")
		check(hint.value == backpackCost - state.coins, `Coins manquants : {tostring(hint.value)}`)
		check(hint.target == "resource", "cible : collecter de nouveau (sac vide)")
	end)

	-- 4. PREMIER ACHAT -------------------------------------------------------

	case("premier achat confirmé : guidage terminé", function(check)
		local env = newEnv({ USER_A })
		local client = newClient()
		client.onState(env.state(USER_A))
		client.apply(env, USER_A, env.collect(USER_A))
		client.apply(env, USER_A, env.sellAll(USER_A))
		env.prepare(USER_A, function(draft: any)
			draft.currencies.coins = backpackCost
		end)
		local state = env.state(USER_A)
		client.onState(state)
		local hint = Rules.hint(Step.Upgrade, state, false)
		check(hint.key == "onboarding.upgrade" and hint.target == "shop" and hint.controls == "shop", "Boutique non montrée")
		local open = Rules.hint(Step.Upgrade, state, true)
		check(open.target == "cards", "cartes non marquées, boutique ouverte")
		check(table.find(Rules.affordable(state), "Backpack") ~= nil, "Backpack non marqué achetable")
		local purchase = env.buy(USER_A, "Backpack")
		check(purchase.ok and purchase.level == 2, `achat refusé ({tostring(purchase.code)})`)
		client.apply(env, USER_A, purchase)
		check(client.step == Step.Completed, "guidage non terminé")
		check(client.events[3] == "upgraded" and #client.events == 3, "événements du parcours")
		check(Rules.hint(Step.Completed, env.state(USER_A), false) == nil, "indication après la fin")
		check(Rules.fromState(env.state(USER_A)) == Step.Completed, "fin non déduite de l'état")
	end)

	case("plusieurs améliorations payables : toutes marquées, aucune imposée", function(check)
		local state = {
			coins = 10_000,
			upgrades = { Backpack = 1, Grabber = 1, Magnet = 0, Boots = 1, Multiplier = 1 },
			inventory = { used = 0, capacity = 50 },
		}
		check(#Rules.affordable(state) == #UpgradeMath.ids(), "achetables incomplets")
		state.coins = backpackCost
		local list = Rules.affordable(state)
		for _, upgradeId in ipairs(list) do
			local level = state.upgrades[upgradeId]
			check(UpgradeMath.nextCost(upgradeId, level) <= state.coins, `{upgradeId} marqué sans être payable`)
		end
	end)

	-- 5-7. JOUEURS DÉJÀ AVANCÉS ---------------------------------------------

	case("collecte déjà faite avant activation : pas d'accueil, étape Vendre", function(check)
		local env = newEnv({ USER_A })
		env.prepare(USER_A, function(draft: any)
			draft.stats.totalResourcesCollected = 12
			draft.inventory.resources.green_leaf = 12
		end)
		local client = newClient()
		client.onState(env.state(USER_A))
		check(client.step == Step.Sell, `reçu {tostring(client.step)}`)
	end)

	case("joueur ayant déjà vendu : étape Améliorer", function(check)
		local env = newEnv({ USER_A })
		env.prepare(USER_A, function(draft: any)
			draft.stats.totalResourcesCollected = 40
			draft.stats.totalSales = 1
		end)
		local client = newClient()
		client.onState(env.state(USER_A))
		check(client.step == Step.Upgrade, `reçu {tostring(client.step)}`)
	end)

	case("joueur ayant déjà acheté : aucun guidage", function(check)
		local env = newEnv({ USER_A })
		env.prepare(USER_A, function(draft: any)
			draft.stats.totalCoinsSpent = 100
		end)
		check(Rules.fromState(env.state(USER_A)) == Step.Completed, "dépense passée ignorée")
		-- Niveau acquis sans dépense enregistrée (ex. profil ancien) : terminé.
		local other = newEnv({ USER_B })
		other.prepare(USER_B, function(draft: any)
			draft.upgrades.magnetLevel = 1
		end)
		check(Rules.fromState(other.state(USER_B)) == Step.Completed, "amélioration acquise ignorée")
		local client = newClient()
		client.onState(env.state(USER_A))
		check(client.step == Step.Completed and Rules.hint(client.step, env.state(USER_A), false) == nil, "guidage affiché")
	end)

	case("déblocage d'un monde : guidage terminé", function(check)
		local client = newClient()
		client.step = Step.Upgrade
		client.onResult({ action = Action.UnlockWorld, ok = true, code = Code.Success, worldId = "GoldenDesert" })
		check(client.step == Step.Completed, "déblocage non reconnu")
	end)

	-- 8-11. DÉCONNEXIONS ET RECONNEXION -------------------------------------

	local function reconnect(env: any, userId: number): any
		assert(env.playerData.ReleasePlayer(userId).ok, "sauvegarde de sortie")
		return newEnv({ userId }, env.store)
	end

	case("déconnexion pendant l'étape collecte", function(check)
		local env = newEnv({ USER_A })
		local client = newClient()
		client.onState(env.state(USER_A))
		check(client.step == Step.Intro, "accueil")
		local after = reconnect(env, USER_A)
		local fresh = newClient()
		fresh.onState(after.state(USER_A))
		check(fresh.step == Step.Intro, "joueur sans collecte : accueil de nouveau")
	end)

	case("déconnexion pendant l'étape vente", function(check)
		local env = newEnv({ USER_A })
		local client = newClient()
		client.onState(env.state(USER_A))
		for _ = 1, 4 do
			client.apply(env, USER_A, env.collect(USER_A))
		end
		check(client.step == Step.Sell, "étape avant déconnexion")
		local after = reconnect(env, USER_A)
		local fresh = newClient()
		fresh.onState(after.state(USER_A))
		check(fresh.step == Step.Sell, `restauration : {tostring(fresh.step)}`)
		check(after.state(USER_A).inventory.used == 4, "sac non restauré")
	end)

	case("déconnexion pendant l'étape amélioration", function(check)
		local env = newEnv({ USER_A })
		local client = newClient()
		client.onState(env.state(USER_A))
		client.apply(env, USER_A, env.collect(USER_A))
		client.apply(env, USER_A, env.sellAll(USER_A))
		check(client.step == Step.Upgrade, "étape avant déconnexion")
		local after = reconnect(env, USER_A)
		local fresh = newClient()
		fresh.onState(after.state(USER_A))
		check(fresh.step == Step.Upgrade, `restauration : {tostring(fresh.step)}`)
	end)

	case("reconnexion après la fin : aucun guidage, jamais réinitialisé", function(check)
		local env = newEnv({ USER_A })
		env.prepare(USER_A, function(draft: any)
			draft.currencies.coins = backpackCost
			draft.stats.totalSales = 1
		end)
		check(env.buy(USER_A, "Backpack").ok, "achat")
		local after = reconnect(env, USER_A)
		local fresh = newClient()
		fresh.onState(after.state(USER_A))
		check(fresh.step == Step.Completed, "guidage relancé après reconnexion")
		-- Un état plus ancien ou incomplet ne fait jamais reculer l'étape.
		fresh.onState({ progress = { resourcesCollected = 0, sales = 0, coinsSpent = 0 }, upgrades = {} })
		fresh.onState({ inventory = {} })
		check(fresh.step == Step.Completed, "étape revenue en arrière")
	end)

	-- 12-13. DOUBLONS ET REFUS ----------------------------------------------

	case("double événement de confirmation : une seule validation", function(check)
		local client = newClient()
		client.step = Step.Sell
		local sale = { action = Action.Sell, ok = true, code = Code.Success, coinsEarned = 30 }
		client.onResult(sale)
		client.onResult(sale)
		client.onResult({ action = Action.Sell, ok = true, code = Code.Success, coinsEarned = 12 })
		check(client.step == Step.Upgrade, "étape incorrecte")
		check(#client.events == 1 and client.events[1] == "sold", `validations : {#client.events}`)
		local purchase = { action = Action.Upgrade, ok = true, code = Code.Success, upgradeId = "Backpack", level = 2 }
		client.onResult(purchase)
		client.onResult(purchase)
		check(#client.events == 2, "achat validé deux fois")
		-- Collecte tardive après la fin : rien.
		client.onResult({ action = Action.Collect, ok = true, code = Code.Success, amount = 1 })
		check(client.step == Step.Completed and #client.events == 2, "retour en arrière")
	end)

	case("événements refusés par le serveur : aucune étape", function(check)
		local env = newEnv({ USER_A })
		local client = newClient()
		client.onState(env.state(USER_A))
		client.step = Rules.endIntro(client.step)
		-- Vente d'un sac vide : refus réel du serveur.
		local empty = env.sellAll(USER_A)
		check(not empty.ok and empty.code == Code.NothingToSell, "vente vide acceptée")
		client.apply(env, USER_A, empty)
		-- Achat sans Coins : refus réel.
		local poor = env.buy(USER_A, "Backpack")
		check(not poor.ok and poor.code == Code.InsufficientFunds, "achat sans Coins accepté")
		client.apply(env, USER_A, poor)
		-- Trop loin : refus réel.
		env.positions[USER_A] = { X = 500, Y = 0, Z = 0 }
		client.apply(env, USER_A, env.collect(USER_A))
		check(client.step == Step.Collect and #client.events == 0, `étape après refus : {tostring(client.step)}`)
		-- Réponses falsifiées ou incohérentes.
		local forgedResults: { any } = {
			{ action = Action.Sell, ok = true, code = Code.NothingToSell, coinsEarned = 50 },
			{ action = Action.Sell, ok = "true", code = Code.Success, coinsEarned = 50 },
			{ action = Action.Upgrade, ok = true, code = Code.Success },
			{ action = "Unknown", ok = true, code = Code.Success },
			"SUCCESS",
		}
		for _, forged in ipairs(forgedResults) do
			client.onResult(forged)
		end
		check(client.step == Step.Collect and #client.events == 0, "réponse falsifiée acceptée")
		local profile = env.playerData.GetData(USER_A)
		check(profile.currencies.coins == 0 and profile.stats.totalCoinsSpent == 0, "profil modifié par le guidage")
	end)

	case("progression illisible : guidage masqué", function(check)
		check(Rules.fromState(nil) == nil, "état nil")
		check(Rules.fromState({ coins = 0 }) == nil, "sans progress")
		check(Rules.fromState({ progress = { resourcesCollected = -1, sales = 0, coinsSpent = 0 } }) == nil, "négatif")
		check(Rules.fromState({ progress = { resourcesCollected = 0 / 0, sales = 0, coinsSpent = 0 } }) == nil, "NaN")
		check(Rules.merge(nil, nil) == nil, "étape inventée")
	end)

	-- 14. MASQUAGE ----------------------------------------------------------

	case("fermeture temporaire du guidage", function(check)
		local step, hidden = Rules.onHide(Step.Intro)
		check(step == Step.Collect and hidden == false, "fermer l'accueil montre la collecte")
		step, hidden = Rules.onHide(Step.Sell)
		check(step == Step.Sell and hidden == true, "masquage d'une étape")
		local card, pill = Rules.visibility(Step.Sell, true, true, false)
		check(not card and pill, "masqué : bouton Guide seul")
		card, pill = Rules.visibility(Step.Sell, true, false, false)
		check(card and not pill, "visible : carte seule")
		card, pill = Rules.visibility(Step.Upgrade, true, false, true)
		check(not card and not pill, "boutique ouverte : rien")
		card, pill = Rules.visibility(Step.Completed, false, true, false)
		check(not card and not pill, "terminé : rien")
		-- Masqué, le joueur progresse quand même.
		local client = newClient()
		client.step = Step.Sell
		client.onResult({ action = Action.Sell, ok = true, code = Code.Success, coinsEarned = 5 })
		check(client.step == Step.Upgrade, "progression bloquée par le masquage")
	end)

	-- 15. LOCALISATION, APPAREILS --------------------------------------------

	case("textes EN/FR complets, courts et cohérents", function(check)
		local keys = {
			"onboarding.welcome_title",
			"onboarding.welcome_body",
			"onboarding.step",
			"onboarding.collect",
			"onboarding.keep_collecting",
			"onboarding.sell",
			"onboarding.sold",
			"onboarding.upgrade",
			"onboarding.upgrade_pick",
			"onboarding.earn_more",
			"onboarding.done",
			"onboarding.show",
		}
		for _, controls in ipairs({ "collect", "sell", "shop" }) do
			for _, device in ipairs({ "touch", "keyboard", "gamepad" }) do
				table.insert(keys, Rules.controlsKey(controls, device))
			end
		end
		local withNumber = { ["onboarding.step"] = true, ["onboarding.sold"] = true, ["onboarding.earn_more"] = true }
		for _, language in ipairs(Localization.languages()) do
			local localeId = if language == "fr" then "fr-fr" else "en-us"
			for _, key in ipairs(keys) do
				check(Localization.has(key, language), `texte manquant ({language}) : {key}`)
				local text = Localization.get(key, localeId)
				local limit = if string.find(key, "ctrl", 1, true) then MAX_CONTROLS_LENGTH else MAX_TEXT_LENGTH
				check(utf8.len(text) ~= nil and (utf8.len(text) :: number) <= limit, `{language} {key} trop long ({utf8.len(text)})`)
				local hasNumber = string.find(text, "%d", 1, true) ~= nil
				check(hasNumber == (withNumber[key] == true), `{language} {key} : motif %d`)
			end
			local done = Localization.get("onboarding.done", localeId)
			check(
				string.find(done, "{name}", 1, true) ~= nil and string.find(done, "{level}", 1, true) ~= nil,
				`{language} : onboarding.done incomplet`
			)
			local filled = Localization.fill("onboarding.done", localeId, { name = "Backpack", level = "2" })
			check(string.find(filled, "{", 1, true) == nil, `{language} : motif non rempli`)
		end
		check(Localization.get("onboarding.collect", "fr-fr") == "Collecte tes premières ressources !", "texte FR de la collecte")
		check(Localization.get("onboarding.welcome_title", "en-us") == "Welcome to Grab & Grow!", "titre EN")
		-- Chaque indication produite pointe vers une clé existante.
		for _, step in ipairs({ Step.Intro, Step.Collect, Step.Sell, Step.Upgrade }) do
			for _, coins in ipairs({ 0, 10_000 }) do
				for _, used in ipairs({ 0, 1, threshold, 50 }) do
					local state = {
						coins = coins,
						upgrades = { Backpack = 1, Grabber = 1, Magnet = 0, Boots = 1, Multiplier = 1 },
						inventory = { used = used, capacity = 50 },
					}
					for _, shopOpen in ipairs({ false, true }) do
						local hint = Rules.hint(step, state, shopOpen)
						check(hint ~= nil and Localization.has(hint.key, "fr") and Localization.has(hint.key, "en"), `{step} : clé`)
					end
				end
			end
		end
	end)

	case("indications de contrôle selon l'appareil", function(check)
		check(Rules.deviceOf("Gamepad1", false) == "gamepad", "manette")
		check(Rules.deviceOf("Touch", false) == "touch", "tactile")
		check(Rules.deviceOf("Keyboard", true) == "keyboard", "clavier")
		check(Rules.deviceOf("MouseMovement", true) == "keyboard", "souris")
		check(Rules.deviceOf("None", true) == "touch", "repli tactile")
		check(Rules.deviceOf(nil, false) == "keyboard", "repli clavier")
		-- Touches réellement configurées (Collection E/X, Vente F/Y, Boutique B/croix haut).
		check(string.find(Localization.get("onboarding.ctrl.collect.keyboard", "en"), "E", 1, true) ~= nil, "touche E")
		check(string.find(Localization.get("onboarding.ctrl.sell.keyboard", "en"), "F", 1, true) ~= nil, "touche F")
		check(string.find(Localization.get("onboarding.ctrl.shop.keyboard", "en"), "B", 1, true) ~= nil, "touche B")
		check(string.find(Localization.get("onboarding.ctrl.collect.gamepad", "en"), "X", 1, true) ~= nil, "bouton X")
		check(string.find(Localization.get("onboarding.ctrl.sell.gamepad", "en"), "Y", 1, true) ~= nil, "bouton Y")
	end)

	case("sac plus petit que le seuil : station montrée quand il est plein", function(check)
		local state = { inventory = { used = 5, capacity = 5 } }
		check(Rules.readyToSell(state), "sac plein non vendable")
		check(not Rules.readyToSell({ inventory = { used = 0, capacity = 5 } }), "sac vide vendable")
		local profile = DataSchema.newProfile()
		check(InventoryService.describe(profile).used == 0, "profil neuf non vide")
	end)

	return failures, caseCount
end

return OnboardingTests
