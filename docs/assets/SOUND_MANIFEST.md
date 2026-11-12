# Manifeste des sons — GRAB & GROW

Dernière mise à jour : 2026-11-12 (T5.2). Source de configuration :
`src/ReplicatedStorage/Shared/Config/FeedbackConfig.lua` (aucun autre
identifiant de son dans le code).

## Règle de sélection

Seuls des audios **publiés par le compte Roblox** (utilisateur Roblox,
`userId 1`) sur le Creator Store sont utilisés. Les résultats de recherche
d'autres créateurs ont été écartés : la plupart sont des imports
d'utilisateurs, souvent tirés de jeux commerciaux (droits incertains).

## Vérifications réalisées (2026-11-12)

1. Recherche dans le Creator Store filtrée sur le créateur Roblox
   (`toolbox-service/v2/assets:search`, `creator=user/1`, lecture seule).
2. `MarketplaceService:GetProductInfo` dans Studio pour chaque identifiant :
   type 3 (Audio), créateur `Roblox` (`User`, `CreatorTargetId = 1`),
   `IsPublicDomain = true` (gratuit à prendre).
3. Chargement réel dans Studio (`ContentProvider:PreloadAsync`, puis Play) :
   statut `Success`, durée lue (`TimeLength`).
4. Conditions : la documentation Roblox (« Audio assets », section « Find
   audio ») décrit les audios du Creator Store faits par Roblox comme
   gratuits pour les créateurs, à utiliser dans leurs expériences.
   Utilisation limitée aux expériences Roblox ; aucune attribution exigée
   dans la fiche. Pas de licence séparée consultée au-delà de cette page et
   des Conditions d'utilisation Roblox.

## Sons intégrés

| Effet (clé) | Asset ID | Nom Creator Store | Créateur | Action associée | Volume de base | Durée | Statut |
|---|---|---|---|---|---|---|---|
| `collect` | 17208319162 | Roblox GUI - Pickup | Roblox (userId 1) | Collecte réussie (2 voix, hauteur ± 6 %) | 0,35 | 0,90 s | Vérifié, intégré |
| `bag_warning` | 17208361335 | Roblox GUI - Notification High | Roblox (userId 1) | Entrée dans « presque plein » | 0,25 | 1,52 s | Vérifié, intégré |
| `bag_full` | 17208353912 | Roblox GUI - Negative | Roblox (userId 1) | Entrée dans « plein » ; collecte refusée sac plein (1 fois / 1,5 s) | 0,35 | 0,38 s | Vérifié, intégré |
| `sell` | 127645268874265 | CoinTransfer_01 | Roblox (userId 1) | Vente confirmée | 0,45 | 1,66 s | Vérifié, intégré |
| `coins` | 17208204604 | Roblox GUI - Bubble | Roblox (userId 1) | Coins crédités (fin du défilement, +0,5 s) | 0,25 | 0,55 s | Vérifié, intégré |
| `upgrade` | 17208380755 | Roblox GUI - Purchase | Roblox (userId 1) | Amélioration achetée | 0,45 | 0,87 s | Vérifié, intégré |
| `refuse` | 17208353912 | Roblox GUI - Negative | Roblox (userId 1) | Fonds insuffisants, niveau max, monde verrouillé, rien à vendre | 0,25 | 0,38 s | Vérifié, intégré |
| `world` | 12222253 | victory.wav | Roblox (userId 1) | Monde débloqué (distinct des achats) | 0,50 | 1,21 s | Vérifié, intégré |

Volume final = volume de base × groupe `SFX` (0,8) × 0,6 si « Effets
réduits » ; 0 si le son est désactivé (groupe `GrabGrowMaster` à 0).
Volumes : hypothèses de confort, **à valider à l'écoute sur appareil
réel** (non écoutés par Claude : aucun rendu audio vérifiable par l'outil).

## Candidats examinés, non retenus

| Asset ID | Nom | Raison |
|---|---|---|
| 15675062723 | Roblox_UI_Whistle_Low | Créateur Roblox, vérifié ; non nécessaire (refus unifiés sur `Negative`) |
| 15675043410 | Roblox_UI_Tonal_Stinger | Créateur Roblox, vérifié ; `victory.wav` préféré pour le déblocage |
| Divers (ex. « Coin Collect », « Subway Surfers Coin… ») | Imports d'utilisateurs | Provenance ou droits incertains : écartés |

## Pour ajouter un son

Consigner ici l'identifiant, le créateur, la vérification `GetProductInfo`,
le chargement dans Studio et la page de conditions consultée, **avant**
de l'ajouter à `FeedbackConfig`.
