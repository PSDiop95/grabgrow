--!strict
-- Point d'entrée du client : démarre les contrôleurs.
-- T2 : affichage du sac et collecte. T3 : vente. T4 : boutique et mondes.
-- T5.2 : retours audio et visuels. T5.3 : guidage de première session.
-- T7 : succès permanents. T8.2 : voyage entre mondes. T8.6 : journal de
-- collection.

local Controllers = script.Parent:WaitForChild("Controllers")
local InventoryController = require(Controllers:WaitForChild("InventoryController"))
local CollectionController = require(Controllers:WaitForChild("CollectionController"))
local SellController = require(Controllers:WaitForChild("SellController"))
local TravelController = require(Controllers:WaitForChild("TravelController"))
local UpgradeController = require(Controllers:WaitForChild("UpgradeController"))
local FeedbackController = require(Controllers:WaitForChild("FeedbackController"))
local OnboardingController = require(Controllers:WaitForChild("OnboardingController"))
local AchievementController = require(Controllers:WaitForChild("AchievementController"))
local CollectionJournalController = require(Controllers:WaitForChild("CollectionJournalController"))

InventoryController.start()
CollectionController.start()
SellController.start()
-- T8.2 : voyage (portails) ; avant la boutique, qui affiche son état.
TravelController.start()
UpgradeController.start()
-- T5.2 : retours audio et visuels (après la boutique : section Paramètres).
FeedbackController.start()
-- T5.3 : après la Boutique et le sac (repères sur leurs éléments).
OnboardingController.start()
-- T7 : bandeau des succès (après le sac : NotificationsUI).
AchievementController.start()
-- T8.6 : après la Boutique (bouton placé sous le sien, même cadre de panneau).
CollectionJournalController.start()
