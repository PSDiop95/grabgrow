--!strict
-- Point d'entrée du client : démarre les contrôleurs.
-- T2 : affichage du sac et collecte. T3 : vente. T4 : boutique et mondes.
-- T5.2 : retours audio et visuels. T5.3 : guidage de première session.

local Controllers = script.Parent:WaitForChild("Controllers")
local InventoryController = require(Controllers:WaitForChild("InventoryController"))
local CollectionController = require(Controllers:WaitForChild("CollectionController"))
local SellController = require(Controllers:WaitForChild("SellController"))
local UpgradeController = require(Controllers:WaitForChild("UpgradeController"))
local FeedbackController = require(Controllers:WaitForChild("FeedbackController"))
local OnboardingController = require(Controllers:WaitForChild("OnboardingController"))

InventoryController.start()
CollectionController.start()
SellController.start()
UpgradeController.start()
-- T5.2 : retours audio et visuels (après la boutique : section Paramètres).
FeedbackController.start()
-- T5.3 : après la Boutique et le sac (repères sur leurs éléments).
OnboardingController.start()
