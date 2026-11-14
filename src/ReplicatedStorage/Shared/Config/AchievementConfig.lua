--!strict
-- Succès permanents (T7, décision D-020, proposition P3).
--
-- Chaque succès est obtenu UNE seule fois par profil, attribué par le
-- serveur (AchievementService) à partir de compteurs qu'il tient déjà :
-- aucune donnée du client. Pas de quête quotidienne, de série de connexion
-- ni de pénalité d'absence.
--
-- Récompenses : HYPOTHÈSES de départ issues de la simulation T7
-- (docs/phases/T7_ECONOMY_SIMULATION.md), à mesurer en test privé.
-- Ordre de grandeur : 5 à 15 minutes de revenu au moment où le succès
-- est atteint par un joueur régulier.
--
-- Les identifiants (clés) sont persistés dans profile.achievements : ne
-- pas les renommer sans migration. Longueur maximale : 64 caractères.
--
-- metric (Shared/Util/AchievementRules) :
--   resourcesCollected = stats.totalResourcesCollected
--   sales              = stats.totalSales
--   coinsEarned        = stats.totalCoinsEarned (récompenses de succès comprises)
--   upgradesBought     = niveaux achetés, toutes améliorations confondues
--   worldsUnlocked     = mondes débloqués, Green Valley compris

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type AchievementDefinition = {
	order: number,
	metric: string,
	goal: number,
	reward: number, -- Coins, entier >= 1
	nameKey: string,
}

local AchievementConfig: { [string]: AchievementDefinition } = {
	collect_100 = { order = 1, metric = "resourcesCollected", goal = 100, reward = 50, nameKey = "achievement.collect_100" },
	sales_10 = { order = 2, metric = "sales", goal = 10, reward = 100, nameKey = "achievement.sales_10" },
	collect_1000 = { order = 3, metric = "resourcesCollected", goal = 1_000, reward = 300, nameKey = "achievement.collect_1000" },
	upgrades_10 = { order = 4, metric = "upgradesBought", goal = 10, reward = 500, nameKey = "achievement.upgrades_10" },
	sales_50 = { order = 5, metric = "sales", goal = 50, reward = 750, nameKey = "achievement.sales_50" },
	world_2 = { order = 6, metric = "worldsUnlocked", goal = 2, reward = 1_000, nameKey = "achievement.world_2" },
	earned_10000 = { order = 7, metric = "coinsEarned", goal = 10_000, reward = 1_000, nameKey = "achievement.earned_10000" },
	collect_5000 = { order = 8, metric = "resourcesCollected", goal = 5_000, reward = 1_500, nameKey = "achievement.collect_5000" },
	sales_200 = { order = 9, metric = "sales", goal = 200, reward = 4_000, nameKey = "achievement.sales_200" },
	upgrades_25 = { order = 10, metric = "upgradesBought", goal = 25, reward = 5_000, nameKey = "achievement.upgrades_25" },
	collect_20000 = { order = 11, metric = "resourcesCollected", goal = 20_000, reward = 6_000, nameKey = "achievement.collect_20000" },
	earned_100000 = { order = 12, metric = "coinsEarned", goal = 100_000, reward = 10_000, nameKey = "achievement.earned_100000" },
}

return TableUtil.deepFreeze(AchievementConfig)
