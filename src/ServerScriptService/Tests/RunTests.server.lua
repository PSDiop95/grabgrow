--!strict
-- Lance les tests automatisés au démarrage du serveur, dans Studio uniquement.
-- Résultats dans la fenêtre Output. N'exécute rien en production.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local ConfigTests = require(script.Parent.ConfigTests)

local failures = ConfigTests.run({
	GameConfig = require(Config.GameConfig),
	ResourceConfig = require(Config.ResourceConfig),
	UpgradeConfig = require(Config.UpgradeConfig),
	WorldConfig = require(Config.WorldConfig),
})

if #failures == 0 then
	print("[Tests] ConfigTests : OK")
else
	for _, message in ipairs(failures) do
		warn(`[Tests] ConfigTests ÉCHEC : {message}`)
	end
	warn(`[Tests] ConfigTests : {#failures} échec(s)`)
end
