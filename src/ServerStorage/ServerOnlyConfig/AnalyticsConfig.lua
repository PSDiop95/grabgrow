--!strict
-- Paramètres de l'instrumentation analytics (T9). Serveur uniquement
-- (ServerStorage, jamais répliqué). Catalogue des événements :
-- docs/analytics/ANALYTICS_EVENT_CATALOG.md.
--
-- Noms d'événements, de monnaie, de types de transaction et de parcours :
-- STABLES. Les renommer casse la continuité des graphiques du Creator
-- Dashboard ; ajouter un nom est sans risque (limite Roblox : 100 noms
-- d'événements personnalisés, 20 types de transaction, 100 SKU).
--
-- Budget : HYPOTHÈSE DE PRUDENCE. Limite Roblox documentée (2026-11-16) :
-- 120 + 20 × CCU requêtes par minute (économie, funnel, personnalisés).
-- Le service en vise la moitié et sacrifie d'abord les événements
-- personnalisés (priorité basse).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local AnalyticsConfig = {
	-- false : aucun appel à Roblox AnalyticsService ; le jeu est identique.
	enabled = true,

	Studio = {
		-- Roblox n'envoie aucun événement depuis Studio. "log" : chaque
		-- événement est écrit dans la fenêtre Output (vérification manuelle) ;
		-- "roblox" : appels réels (sans effet en Studio, utile pour vérifier
		-- qu'ils ne lèvent pas d'erreur) ; "off" : rien.
		sink = "log",
	},

	Budget = {
		-- Requêtes par minute et par serveur : base + perPlayer × joueurs.
		-- Priorité basse (événements personnalisés) au-delà de `soft`.
		softBasePerMinute = 30,
		softPerPlayerPerMinute = 6,
		-- Priorité haute (économie, onboarding, progression) au-delà de `hard`.
		hardBasePerMinute = 60,
		hardPerPlayerPerMinute = 10,
	},

	Collection = {
		-- Les collectes sont agrégées par joueur et par monde, puis envoyées
		-- par lot : à cet intervalle, à chaque vente et au départ du joueur.
		flushIntervalSeconds = 300,
		-- Période de vérification des lots arrivés à échéance.
		tickSeconds = 30,
	},

	Errors = {
		-- Au plus une ligne d'avertissement par méthode et par intervalle.
		logIntervalSeconds = 60,
	},

	-- Monnaie déclarée à LogEconomyEvent (limite Roblox : 10 monnaies).
	Currency = {
		Coins = "Coins",
	},

	-- Types de transaction : noms de Enum.AnalyticsEconomyTransactionType.
	TransactionType = {
		Sale = "Gameplay",
		Achievement = "Gameplay",
		Upgrade = "Shop",
		WorldUnlock = "ContextualPurchase",
	},

	-- Préfixes des SKU (le suffixe vient toujours d'une configuration
	-- serveur : monde, succès, amélioration).
	SkuPrefix = {
		Sale = "Sale",
		Achievement = "Achievement",
		Upgrade = "Upgrade",
		WorldUnlock = "World",
	},

	-- Funnel d'onboarding (une étape ne compte qu'une fois par joueur).
	Onboarding = {
		{ step = 1, name = "JoinedGame" },
		{ step = 2, name = "FirstCollection" },
		{ step = 3, name = "FirstSale" },
		{ step = 4, name = "FirstUpgrade" },
		{ step = 5, name = "FirstWorldUnlocked" },
	},

	-- Parcours de progression (LogProgressionCompleteEvent).
	Progression = {
		Worlds = "Worlds",
	},

	-- Événements personnalisés (LogCustomEvent).
	Event = {
		SessionEnded = "SessionEnded",
		ResourcesCollected = "ResourcesCollected",
		BackpackFull = "BackpackFull",
		WorldEntered = "WorldEntered",
		JournalDiscovery = "JournalDiscovery",
		UpgradePurchased = "UpgradePurchased",
	},

	-- Valeur des champs lorsque l'information n'est pas contrôlée.
	unknownValue = "Unknown",
}

return TableUtil.deepFreeze(AnalyticsConfig)
