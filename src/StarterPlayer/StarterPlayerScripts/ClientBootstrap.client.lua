--!strict
-- Point d'entrée du client : démarre les contrôleurs.
-- T2 : affichage du sac et collecte. T3 : vente. T4 : boutique et mondes.

local Controllers = script.Parent:WaitForChild("Controllers")
local InventoryController = require(Controllers:WaitForChild("InventoryController"))
local CollectionController = require(Controllers:WaitForChild("CollectionController"))
local SellController = require(Controllers:WaitForChild("SellController"))
local UpgradeController = require(Controllers:WaitForChild("UpgradeController"))

InventoryController.start()
CollectionController.start()
SellController.start()
UpgradeController.start()
