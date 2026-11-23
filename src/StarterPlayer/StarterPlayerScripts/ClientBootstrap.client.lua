--!strict
-- Point d'entrée du client : démarre les contrôleurs.
-- T2 : affichage du sac et collecte. T3 : vente. T4 : boutique et mondes.
-- T5.2 : retours audio et visuels. T5.3 : guidage de première session.
-- T7 : succès permanents. T8.2 : voyage entre mondes. T8.6 : journal de
-- collection. T10.3 : gardiens et sites sacrés. T10.5b : reliques sacrées.
-- A-4 : panneau Crédits.

local Controllers = script.Parent:WaitForChild("Controllers")
local InventoryController = require(Controllers:WaitForChild("InventoryController"))
local NodeVisuals = require(Controllers:WaitForChild("NodeVisuals"))
local ResourceVFXController = require(Controllers:WaitForChild("ResourceVFXController"))
local CollectionController = require(Controllers:WaitForChild("CollectionController"))
local SellController = require(Controllers:WaitForChild("SellController"))
local TravelController = require(Controllers:WaitForChild("TravelController"))
local UpgradeController = require(Controllers:WaitForChild("UpgradeController"))
local FeedbackController = require(Controllers:WaitForChild("FeedbackController"))
local OnboardingController = require(Controllers:WaitForChild("OnboardingController"))
local AchievementController = require(Controllers:WaitForChild("AchievementController"))
local CollectionJournalController = require(Controllers:WaitForChild("CollectionJournalController"))
local GuardianController = require(Controllers:WaitForChild("GuardianController"))
local SacredCompassController = require(Controllers:WaitForChild("SacredCompassController"))
local CreditsController = require(Controllers:WaitForChild("CreditsController"))

InventoryController.start()
-- T10.1 : visuels des ressources (modèles importés, V-01, attente).
NodeVisuals.start()
-- T10.2 : effets de rareté, de collecte et de réapparition (pools).
ResourceVFXController.start()
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
-- T10.3 : gardiens et sites sacrés (après la collecte : cibles du bouton Grab).
GuardianController.start()
-- T10.5b : Boussole des sanctuaires (affichage, si l'amélioration est acquise).
SacredCompassController.start()
-- A-4 (option C) : crédits des modèles 3D (entrée dans les Paramètres de la Boutique).
CreditsController.start()
