--!strict
-- Retours audio et visuels du client (T5.2). Paramètres d'interface
-- seulement : aucun effet sur le jeu, l'économie ou le serveur.
--
-- Sons : audios publiés par le compte Roblox (userId 1) sur le Creator
-- Store, vérifiés par MarketplaceService:GetProductInfo (créateur Roblox,
-- IsPublicDomain = true) et chargés dans Studio le 2026-11-12. Provenance,
-- conditions et durées : docs/assets/SOUND_MANIFEST.md. Ne jamais ajouter
-- un identifiant sans l'y consigner.
--
-- Volumes, durées et nombres de particules : hypothèses de confort, à
-- valider sur appareil réel.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type SoundDefinition = {
	assetId: number,
	-- Volume de base (0 à 1), avant le groupe SFX et les préférences.
	volume: number,
	-- Variation aléatoire de hauteur (± fraction), pour les sons répétés.
	pitchJitter: number,
	-- Nombre d'instances Sound réutilisées (chevauchement maximal).
	voices: number,
}

local FeedbackConfig = {
	Sounds = {
		-- Collecte réussie : « Roblox GUI - Pickup », 0,90 s.
		collect = { assetId = 17208319162, volume = 0.35, pitchJitter = 0.06, voices = 2 },
		-- Entrée dans l'état « presque plein » : « Roblox GUI - Notification High », 1,52 s.
		bag_warning = { assetId = 17208361335, volume = 0.25, pitchJitter = 0, voices = 1 },
		-- Sac plein (entrée dans l'état ou collecte refusée) : « Roblox GUI - Negative », 0,38 s.
		bag_full = { assetId = 17208353912, volume = 0.35, pitchJitter = 0, voices = 1 },
		-- Vente confirmée : « CoinTransfer_01 », 1,66 s.
		sell = { assetId = 127645268874265, volume = 0.45, pitchJitter = 0, voices = 1 },
		-- Coins crédités (fin du défilement du solde) : « Roblox GUI - Bubble », 0,55 s.
		coins = { assetId = 17208204604, volume = 0.25, pitchJitter = 0, voices = 1 },
		-- Amélioration achetée : « Roblox GUI - Purchase », 0,87 s.
		upgrade = { assetId = 17208380755, volume = 0.45, pitchJitter = 0, voices = 1 },
		-- Refus (fonds insuffisants, niveau max, monde verrouillé, rien à
		-- vendre) : « Roblox GUI - Negative », 0,38 s, plus discret.
		refuse = { assetId = 17208353912, volume = 0.25, pitchJitter = 0, voices = 1 },
		-- Monde débloqué : « victory.wav », 1,21 s (distinct des achats).
		world = { assetId = 12222253, volume = 0.5, pitchJitter = 0, voices = 1 },
	} :: { [string]: SoundDefinition },

	-- Volume du groupe des effets (SoundGroup SFX) ; le groupe Master
	-- porte le réglage global (1, ou 0 quand le son est désactivé).
	EffectsVolume = 0.8,
	-- « Effets réduits » : multiplicateur de volume des effets.
	ReducedVolumeFactor = 0.6,

	-- Délai avant les sons d'état du sac, pour ne pas couvrir le son de
	-- la collecte qui les déclenche (s).
	BagSoundDelaySeconds = 0.25,
	-- Délai du tintement des Coins : fin du défilement du solde (s).
	CoinsChimeDelaySeconds = 0.5,

	-- Fenêtre anti-doublon : un même événement (action, cible, code) reçu
	-- deux fois dans cette fenêtre ne produit qu'un retour (s).
	DedupeWindowSeconds = 0.3,
	-- Sac plein : un seul son de refus par fenêtre (s), même si le joueur
	-- maintient « Prendre ».
	BagFullRepeatSeconds = 1.5,

	-- Effets de collecte simultanés au maximum (au-delà : son seul).
	MaxCollectEffects = 6,

	-- Particules de collecte : par rareté, ResourceVFXConfig (T10.2).
	Collect = {
		seconds = 0.3,
		reducedSeconds = 0.18,
		-- Part de la distance nœud -> joueur parcourue par l'éclat.
		travelFraction = 0.6,
	},
	Sell = {
		coins = 6,
		reducedCoins = 3,
		coinSize = 18,
		flightSeconds = 0.45,
		reducedFlightSeconds = 0.3,
		staggerSeconds = 0.05,
	},
	Upgrade = {
		ringGrowPixels = 26,
		seconds = 0.45,
		reducedSeconds = 0.25,
		pulseScale = 1.18,
		reducedPulseScale = 1.08,
	},
	World = {
		confetti = 12,
		reducedConfetti = 5,
		seconds = 0.8,
		reducedSeconds = 0.5,
		spreadPixels = 140,
	},
}

return TableUtil.deepFreeze(FeedbackConfig)
