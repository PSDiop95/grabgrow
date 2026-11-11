--!strict
-- Branche PlayerDataService sur le cycle de vie Roblox : arrivée et départ
-- des joueurs, sauvegarde périodique, arrêt du serveur.
-- Aucune logique de données ici : tout passe par le service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local PlayerDataService = require(script.Parent.Parent.Services.PlayerDataService)

local PlayerSession = {}

-- Messages d'expulsion. Texte brut : Player:Kick ne passe pas par les
-- tables de localisation (à traiter avec l'interface, T5).
local KICK_LOAD_FAILED = "Your data could not be loaded. Nothing was lost. Please rejoin in a few minutes."
local KICK_SESSION_LOCKED = "Your data is still in use by another server. Please rejoin in a few minutes."
local KICK_SESSION_LOST = "Your session was opened on another server."

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
		player:Kick(KICK_SESSION_LOST)
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
			player:Kick(KICK_SESSION_LOCKED)
		else
			player:Kick(KICK_LOAD_FAILED)
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
