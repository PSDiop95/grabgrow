--!strict
-- Succès permanents (T7, décision D-020). Serveur uniquement.
--
-- `Evaluate(userId)` est appelé par le serveur après une action validée
-- (collecte, vente, achat, déblocage) et au chargement du profil. Aucune
-- demande du client : pas de RemoteEvent, pas d'argument à valider.
--
-- Transaction : dans un seul PlayerDataService.Update, chaque succès
-- atteint est marqué obtenu ET sa récompense créditée par EconomyService
-- (stats.totalCoinsEarned compris). Tout ou rien, sans suspension du fil :
-- deux évaluations simultanées ne peuvent pas attribuer deux fois le même
-- succès (la seconde voit profile.achievements déjà à jour).
--
-- Une récompense peut faire atteindre un succès « Coins gagnés » : la
-- boucle s'arrête quand plus rien n'est atteint (au plus un tour par succès).
-- Aucune sauvegarde DataStore déclenchée : cycle normal (60 s et sortie).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementConfig = require(ReplicatedStorage.Shared.Config.AchievementConfig)
local AchievementRules = require(ReplicatedStorage.Shared.Util.AchievementRules)
local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local AchievementService = {}

export type Grant = {
	achievementId: string,
	reward: number,
	-- T9 : solde de Coins après ce crédit (analytics).
	balanceAfter: number,
}

export type Dependencies = {
	playerData: any,
	log: ((level: string, message: string) -> ())?,
}

local function defaultLog(level: string, message: string)
	if level == "info" then
		print(`[Achievement] {message}`)
	else
		warn(`[Achievement] {level} : {message}`)
	end
end

local ACHIEVEMENT_COUNT = 0
for _ in pairs(AchievementConfig) do
	ACHIEVEMENT_COUNT += 1
end

function AchievementService.new(dependencies: Dependencies)
	local playerData = dependencies.playerData
	local log = dependencies.log or defaultLog
	local operationCount = 0

	local service = {}

	-- Attribue les succès atteints. Retourne la liste des succès obtenus
	-- par cet appel (vide si rien de nouveau ou profil non chargé).
	function service.Evaluate(userId: number): { Grant }
		local granted: { Grant } = {}
		local entries: { EconomyService.Entry } = {}
		local failure: string? = nil

		local result = playerData.Update(userId, function(draft: any): boolean?
			granted, entries, failure = {}, {}, nil
			if type(draft.achievements) ~= "table" then
				failure = "section achievements absente"
				return false
			end
			for _ = 1, ACHIEVEMENT_COUNT do
				local pending = AchievementRules.pending(draft)
				if #pending == 0 then
					break
				end
				for _, achievementId in ipairs(pending) do
					local reward = AchievementConfig[achievementId].reward
					local entry, code = EconomyService.credit(draft, reward, `Achievement:{achievementId}`)
					if entry == nil then
						failure = `{achievementId} : crédit refusé ({tostring(code)})`
						return false
					end
					draft.achievements[achievementId] = true
					table.insert(
						granted,
						{ achievementId = achievementId, reward = reward, balanceAfter = entry.balanceAfter }
					)
					table.insert(entries, entry)
				end
			end
			if #granted == 0 then
				return false -- rien de nouveau : aucune modification
			end
			return nil
		end)

		if not result.ok then
			if failure ~= nil then
				log("error", `joueur {userId} : succès non attribués ({failure})`)
			elseif result.code ~= PlayerDataService.Code.Aborted and result.code ~= PlayerDataService.Code.NotLoaded then
				log("error", `joueur {userId} : succès non attribués ({tostring(result.code)} : {tostring(result.message)})`)
			end
			return {}
		end

		for index, entry in ipairs(entries) do
			operationCount += 1
			log(
				"info",
				`{EconomyService.describe(userId, `Achievement-{operationCount}`, entry)} ; succès {granted[index].achievementId}`
			)
		end
		return granted
	end

	return service
end

return AchievementService
