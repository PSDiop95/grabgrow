--!strict
-- Tests des retours audio et visuels (T5.2) : règles (FeedbackRules) et
-- configuration (FeedbackConfig). Logique pure : aucune API Roblox.
-- Ces tests prouvent QUEL retour est demandé ; ils ne prouvent pas le
-- rendu réel d'un son ou d'un effet, vérifié dans Studio et sur appareil.

local FeedbackTests = {}

export type Modules = {
	FeedbackRules: any,
	FeedbackConfig: any,
	Remotes: any,
	Localization: any,
	BagDisplay: any,
}

function FeedbackTests.run(modules: Modules): ({ string }, number)
	local Rules = modules.FeedbackRules
	local Config = modules.FeedbackConfig
	local Remotes = modules.Remotes
	local Localization = modules.Localization
	local BagDisplay = modules.BagDisplay
	local Action = Remotes.Action
	local Code = Remotes.ResultCode

	local failures: { string } = {}
	local caseCount = 0

	local function case(name: string, body: (check: (condition: boolean, message: string) -> ()) -> ())
		caseCount += 1
		local ok, err = pcall(body :: any, function(condition: boolean, message: string)
			if not condition then
				table.insert(failures, `{name} : {message}`)
			end
		end)
		if not ok then
			table.insert(failures, `{name} : erreur {tostring(err)}`)
		end
	end

	local function hasPositive(cues: { any }): boolean
		for _, cue in ipairs(cues) do
			if cue.positive or cue.visual ~= nil then
				return true
			end
		end
		return false
	end

	local function find(cues: { any }, field: string, value: any): any
		for _, cue in ipairs(cues) do
			if cue[field] == value then
				return cue
			end
		end
		return nil
	end

	local ON = { soundEnabled = true, reducedEffects = false }
	local MUTED = { soundEnabled = false, reducedEffects = false }
	local REDUCED = { soundEnabled = true, reducedEffects = true }

	-- 1. Collecte réussie.
	case("1 collecte réussie", function(check)
		for _, resourceType in ipairs({ "green_leaf", "wood", "stone" }) do
			local cues = Rules.fromResult({
				action = Action.Collect,
				ok = true,
				code = Code.Success,
				resourceId = `{resourceType}_001`,
				resourceType = resourceType,
				amount = 1,
			})
			local collect = find(cues, "visual", "collect")
			check(collect ~= nil, `{resourceType} : effet de collecte attendu`)
			check(collect ~= nil and collect.sound == "collect", `{resourceType} : son de collecte attendu`)
			check(collect ~= nil and collect.id == `{resourceType}_001`, `{resourceType} : nœud ciblé`)
		end
	end)

	-- 2. Collecte refusée : aucun retour positif.
	case("2 collecte refusée", function(check)
		for _, code in ipairs({
			Code.InvalidTarget,
			Code.TooFar,
			Code.Cooldown,
			Code.InventoryFull,
			Code.ResourceUnavailable,
			Code.RateLimited,
			Code.InternalError,
		}) do
			local cues = Rules.fromResult({ action = Action.Collect, ok = false, code = code, resourceId = "stone_001" })
			check(not hasPositive(cues), `{code} : aucun retour positif`)
		end
		local full = Rules.fromResult({ action = Action.Collect, ok = false, code = Code.InventoryFull })
		check(#full == 1 and full[1].sound == "bag_full", "sac plein : son de refus")
		-- Succès incohérent (type inconnu, montant nul ou falsifié) : rien.
		check(#Rules.fromResult({ action = Action.Collect, ok = true, resourceId = "x", resourceType = "gold", amount = 1 }) == 0, "type inconnu")
		check(#Rules.fromResult({ action = Action.Collect, ok = true, resourceId = "x", resourceType = "wood", amount = 0 }) == 0, "montant nul")
		check(#Rules.fromResult({ action = Action.Collect, ok = true, resourceId = "x", resourceType = "wood", amount = 1.5 }) == 0, "montant non entier")
		check(#Rules.fromResult({ action = Action.Collect, ok = "true", resourceId = "x", resourceType = "wood", amount = 1 }) == 0, "ok non booléen")
		check(#Rules.fromResult(nil) == 0 and #Rules.fromResult("Collect") == 0, "payload illisible")
	end)

	-- 3 et 4. Vente réussie, montant identique à la confirmation serveur.
	case("3-4 vente réussie et montant", function(check)
		for _, earned in ipairs({ 1, 86, 12345 }) do
			local cues = Rules.fromResult({ action = Action.Sell, ok = true, code = Code.Success, coinsEarned = earned, quantitySold = 3 })
			local sell = find(cues, "visual", "sell")
			check(sell ~= nil and sell.sound == "sell", `{earned} : effet et son de vente`)
			check(sell ~= nil and sell.amount == earned, `{earned} : montant affiché = coinsEarned`)
			local coins = find(cues, "sound", "coins")
			check(coins ~= nil and coins.amount == earned and coins.delay > 0, `{earned} : tintement des Coins après défilement`)
		end
	end)

	-- 5. Vente refusée : aucun retour positif.
	case("5 vente refusée", function(check)
		for _, code in ipairs({ Code.NothingToSell, Code.TooFar, Code.RateLimited, Code.InternalError, Code.ProfileNotLoaded }) do
			local cues = Rules.fromResult({ action = Action.Sell, ok = false, code = code, coinsEarned = 50 })
			check(not hasPositive(cues), `{code} : aucun retour positif`)
		end
		check(#Rules.fromResult({ action = Action.Sell, ok = true, coinsEarned = 0 }) == 0, "succès à 0 Coins : rien")
		check(#Rules.fromResult({ action = Action.Sell, ok = true, coinsEarned = -5 }) == 0, "montant négatif : rien")
		check(#Rules.fromResult({ action = Action.Sell, ok = true }) == 0, "montant absent : rien")
	end)

	-- 6. Achat réussi.
	case("6 achat réussi", function(check)
		for _, upgradeId in ipairs({ "Backpack", "Grabber", "Magnet", "Boots", "Multiplier" }) do
			local cues = Rules.fromResult({ action = Action.Upgrade, ok = true, code = Code.Success, upgradeId = upgradeId, level = 2, coinsSpent = 100 })
			local upgrade = find(cues, "visual", "upgrade")
			check(upgrade ~= nil and upgrade.sound == "upgrade", `{upgradeId} : effet et son`)
			check(upgrade ~= nil and upgrade.level == 2, `{upgradeId} : nouveau niveau du serveur`)
		end
		-- Le Magnet n'a pas de visuel 3D supplémentaire (anneau A-40 seul) :
		-- le seul visuel demandé est celui de la boutique.
		local magnet = Rules.fromResult({ action = Action.Upgrade, ok = true, upgradeId = "Magnet", level = 3 })
		check(#magnet == 1, "Magnet : un seul retour (pas de second anneau)")
	end)

	-- 7. Achat refusé.
	case("7 achat refusé", function(check)
		for _, code in ipairs({ Code.InsufficientFunds, Code.MaxLevel, Code.InvalidTarget, Code.RateLimited, Code.InternalError }) do
			local cues = Rules.fromResult({ action = Action.Upgrade, ok = false, code = code, upgradeId = "Backpack" })
			check(not hasPositive(cues), `{code} : aucun retour positif`)
		end
		local poor = Rules.fromResult({ action = Action.Upgrade, ok = false, code = Code.InsufficientFunds, upgradeId = "Boots" })
		check(#poor == 1 and poor[1].sound == "refuse", "fonds insuffisants : son de refus")
		check(#Rules.fromResult({ action = Action.Upgrade, ok = true, upgradeId = "Rocket", level = 2 }) == 0, "amélioration inconnue")
		check(#Rules.fromResult({ action = Action.Upgrade, ok = true, upgradeId = "Boots" }) == 0, "niveau absent")
	end)

	-- 8. Déblocage confirmé.
	case("8 déblocage de monde", function(check)
		local cues = Rules.fromResult({ action = Action.UnlockWorld, ok = true, code = Code.Success, worldId = "GoldenDesert", coinsSpent = 1500 })
		local world = find(cues, "visual", "world")
		check(world ~= nil and world.sound == "world" and world.id == "GoldenDesert", "effet et son de monde")
		check(world ~= nil and world.sound ~= "upgrade", "son distinct des achats")
		for _, code in ipairs({ Code.RequirementNotMet, Code.InsufficientFunds, Code.AlreadyUnlocked, Code.InternalError }) do
			check(not hasPositive(Rules.fromResult({ action = Action.UnlockWorld, ok = false, code = code, worldId = "GoldenDesert" })), `{code} : aucun retour positif`)
		end
		check(#Rules.fromResult({ action = Action.UnlockWorld, ok = true, worldId = "Atlantis" }) == 0, "monde inconnu")
		check(Config.Sounds.world.assetId ~= Config.Sounds.upgrade.assetId, "identifiants de son distincts")
	end)

	-- 9. Son désactivé.
	case("9 son désactivé", function(check)
		for key in pairs(Config.Sounds) do
			check(Rules.soundVolume(key, MUTED) == 0, `{key} : volume nul`)
			check(Rules.soundVolume(key, ON) > 0, `{key} : audible si activé`)
		end
		check(Rules.soundVolume("inconnu", ON) == 0, "son inconnu : muet")
	end)

	-- 10. Effets réduits.
	case("10 effets réduits", function(check)
		for key in pairs(Config.Sounds) do
			local normal, reduced = Rules.soundVolume(key, ON), Rules.soundVolume(key, REDUCED)
			check(reduced > 0 and reduced < normal, `{key} : volume plus faible mais audible`)
		end
		local c = Config.Collect
		check(Rules.pick(c.particles, c.reducedParticles, REDUCED) < Rules.pick(c.particles, c.reducedParticles, ON), "moins de particules")
		check(Rules.pick(c.particles, c.reducedParticles, REDUCED) >= 1, "éclat toujours visible")
		check(Rules.pick(Config.Sell.coins, Config.Sell.reducedCoins, REDUCED) >= 1, "au moins une pièce")
		check(Rules.pick(Config.World.confetti, Config.World.reducedConfetti, REDUCED) >= 1, "au moins un confetti")
		check(Rules.pick(c.seconds, c.reducedSeconds, REDUCED) < c.seconds, "animation plus courte")
		-- Le retour essentiel n'est pas supprimé : mêmes visuels demandés.
		local cues = Rules.fromResult({ action = Action.Sell, ok = true, coinsEarned = 10 })
		check(find(cues, "visual", "sell") ~= nil, "visuel de vente conservé (décidé hors préférences)")
	end)

	-- 11. Nettoyage : chaque effet réservé est rendu ; budget borné.
	case("11 budget des effets", function(check)
		local budget = Rules.newBudget(Config.MaxCollectEffects)
		for _ = 1, Config.MaxCollectEffects do
			check(budget:tryAcquire(), "réservation sous la limite")
		end
		check(not budget:tryAcquire(), "limite atteinte : effet refusé")
		for _ = 1, Config.MaxCollectEffects + 3 do
			budget:release()
		end
		check(budget:active() == 0, "tous les effets rendus, jamais négatif")
		check(budget:tryAcquire(), "réservation possible après nettoyage")
	end)

	-- 12. Absence de duplication.
	case("12 doublons", function(check)
		local deduper = Rules.newDeduper()
		local result = { action = Action.Collect, ok = true, resourceId = "wood_003", resourceType = "wood", amount = 1 }
		local key = Rules.fromResult(result)[1].key
		check(deduper:accept(key, 10), "premier événement accepté")
		check(not deduper:accept(key, 10.01), "même événement reçu deux fois : ignoré")
		check(deduper:accept(Rules.fromResult({ action = Action.Collect, ok = true, resourceId = "wood_004", resourceType = "wood", amount = 1 })[1].key, 10.02), "autre nœud accepté")
		check(deduper:accept(key, 10 + Config.DedupeWindowSeconds + 0.01), "même nœud après la fenêtre (réapparition) accepté")
		-- Deux achats successifs du même objet : niveaux différents, deux retours.
		local up2 = Rules.fromResult({ action = Action.Upgrade, ok = true, upgradeId = "Boots", level = 2 })[1].key
		local up3 = Rules.fromResult({ action = Action.Upgrade, ok = true, upgradeId = "Boots", level = 3 })[1].key
		check(up2 ~= up3 and deduper:accept(up2, 20) and deduper:accept(up3, 20.05), "achats successifs distincts")
		-- Sac plein : un refus par fenêtre, entrée dans l'état comprise.
		local enter = Rules.fromBagTier("nearly_full", "full")[1]
		local refused = Rules.fromResult({ action = Action.Collect, ok = false, code = Code.InventoryFull })[1]
		check(enter.key == refused.key, "même clé pour l'entrée et le refus")
		check(deduper:accept(enter.key, 30), "entrée dans « plein »")
		check(not deduper:accept(refused.key, 30.5), "refus immédiat : pas de second son")
		check(deduper:accept(refused.key, 30 + Config.BagFullRepeatSeconds + 0.01), "refus après la fenêtre")
	end)

	case("sac presque plein et plein (états du sac)", function(check)
		local function tier(used: number): string
			return BagDisplay.view(used, 50).tier
		end
		local warning = Rules.fromBagTier(tier(39), tier(40))
		check(#warning == 1 and warning[1].sound == "bag_warning" and warning[1].delay > 0, "entrée dans « presque plein »")
		check(#Rules.fromBagTier(tier(40), tier(41)) == 0, "reste presque plein : silence")
		local full = Rules.fromBagTier(tier(49), tier(50))
		check(#full == 1 and full[1].sound == "bag_full", "entrée dans « plein »")
		check(#Rules.fromBagTier(tier(50), tier(0)) == 0, "vente (baisse) : silence")
		check(#Rules.fromBagTier(nil, tier(50)) == 0, "premier état : silence")
		check(#Rules.fromBagTier(tier(10), tier(50)) == 1, "saut direct à plein : un seul son")
	end)

	case("configuration des sons", function(check)
		local count = 0
		for key, definition in pairs(Config.Sounds) do
			count += 1
			check(type(definition.assetId) == "number" and definition.assetId > 0 and definition.assetId % 1 == 0, `{key} : identifiant entier`)
			check(definition.volume > 0 and definition.volume <= 1, `{key} : volume dans ]0, 1]`)
			check(definition.voices >= 1 and definition.voices <= 3, `{key} : 1 à 3 voix`)
			check(definition.pitchJitter >= 0 and definition.pitchJitter < 0.2, `{key} : variation de hauteur modérée`)
		end
		check(count == 8, "8 sons configurés")
		for _, key in ipairs({ "collect", "bag_warning", "bag_full", "sell", "coins", "upgrade", "refuse", "world" }) do
			check(Config.Sounds[key] ~= nil, `son {key} configuré`)
		end
		check(Config.EffectsVolume > 0 and Config.EffectsVolume <= 1, "volume des effets")
		check(Config.ReducedVolumeFactor > 0 and Config.ReducedVolumeFactor < 1, "facteur réduit")
		check(table.isfrozen(Config) and table.isfrozen(Config.Sounds), "configuration gelée")
	end)

	case("textes EN/FR", function(check)
		for _, key in ipairs({
			"settings.title",
			"settings.sound",
			"settings.reduced_effects",
			"settings.on",
			"settings.off",
			"world.unlocked_named",
		}) do
			for _, language in ipairs(Localization.languages()) do
				check(Localization.has(key, language), `{key} absent en {language}`)
			end
		end
		check(
			Localization.fill("world.unlocked_named", "fr-fr", { world = "Golden Desert" })
				== `Golden Desert débloqué{Localization.NBSP}!`,
			"message FR"
		)
		check(Localization.fill("world.unlocked_named", "en-us", { world = "Golden Desert" }) == "Golden Desert unlocked!", "message EN")
	end)

	return failures, caseCount
end

return FeedbackTests
