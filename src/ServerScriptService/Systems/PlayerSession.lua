--!strict
-- Branche PlayerDataService sur le cycle de vie Roblox : arrivée et départ
-- des joueurs, sauvegarde périodique, arrêt du serveur.
-- Aucune logique de données ici : tout passe par le service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local Localization = require(ReplicatedStorage.Shared.Util.Localization)
local PlayerDataService = require(script.Parent.Parent.Services.PlayerDataService)

local PlayerSession = {}

-- Messages d'expulsion (A-22) : clés de localisation, traduites dans la
-- langue du joueur (Player:Kick n'utilise pas les tables de localisation).
local KICK_LOAD_FAILED = "system.kick.load_failed"
local KICK_SESSION_LOCKED = "system.kick.session_locked"
local KICK_SESSION_LOST = "system.kick.session_lost"

local function kick(player: Player, key: string)
	player:Kick(Localization.get(key, player.LocaleId))
end

type Service = typeof(PlayerDataService.new({} :: any))

-- Points d'accroche des systèmes de jeu. Ne doivent pas suspendre le fil.
export type Hooks = {
	-- Profil chargé et utilisable.
	onProfileLoaded: ((player: Player) -> ())?,
	-- Juste avant la sauvegarde de sortie.
	onPlayerRemoving: ((player: Player) -> ())?,
}

local started = false

-- Message d'expulsion à utiliser quand un autre serveur reprend le verrou.
function PlayerSession.kickSessionLost(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		kick(player, KICK_SESSION_LOST)
	end
end

function PlayerSession.start(service: Service, hooks: Hooks?)
	assert(not started, "PlayerSession.start appelé deux fois")
	started = true

	local function onPlayerAdded(player: Player)
		local result = service.LoadPlayer(player.UserId)
		if result.ok then
			if hooks and hooks.onProfileLoaded then
				hooks.onProfileLoaded(player)
			end
			return
		end
		if result.code == PlayerDataService.Code.Cancelled then
			return
		end
		-- Pas de profil : le joueur ne doit pas entrer en jeu. Aucun profil
		-- vide n'est créé à la place.
		if result.code == PlayerDataService.Code.SessionLocked then
			kick(player, KICK_SESSION_LOCKED)
		else
			kick(player, KICK_LOAD_FAILED)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		if hooks and hooks.onPlayerRemoving then
			hooks.onPlayerRemoving(player)
		end
		service.ReleasePlayer(player.UserId)
	end)
	-- Joueurs déjà présents si le script démarre après eux (Studio).
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Sauvegarde périodique : écrit le profil et renouvelle le verrou.
	task.spawn(function()
		while true do
			task.wait(DataConfig.Save.autosaveIntervalSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				if service.IsLoaded(player.UserId) then
					task.spawn(service.SavePlayer, player.UserId, "auto")
				end
			end
		end
	end)

	-- Arrêt du serveur : Roblox accorde environ 30 s avant de couper.
	game:BindToClose(function()
		service.Shutdown()
	end)
end

return PlayerSession
