# GRAB & GROW — Roadmap

Dernière mise à jour : 2026-11-14

Phasage du MVP repris de l'architecture technique (section 20, T0 à T8).
Le calendrier 10 semaines du GDD (section 20) reste la cible commerciale,
mais son ordre (Pets avant sauvegarde) n'est pas suivi : voir
`decisions/TECHNICAL_DECISIONS.md`, D-004.

Un lot n'est « terminé » que si ses critères ont été vérifiés par un test
réellement exécuté. État détaillé : `PROJECT_STATUS.md`.

## MVP

| Phase | Livrable | Critère de validation | État |
|---|---|---|---|
| T0 | Structure du projet et configurations | Projet organisé, lancement sans erreur dans Studio | Terminé le 2026-11-10 — analyse Luau propre, `ConfigTests : OK` dans Studio |
| T1 | Profil joueur et sauvegarde | Chargement, sauvegarde, reconnexion, pas d'écrasement | **Validé avec réserves** le 2026-11-11 — V-01, V-02, V-03, V-05 validés sur DataStore réel ; V-04 partiel ; copie D-008 non vérifiée sur DataStore réel (`PROJECT_STATUS.md`, R-01 à R-04) |
| T2 | Collecte et inventaire | Collecte validée serveur, sac limité | **Validé et clôturé** le 2026-11-11 — tests automatisés, Studio à 1 et 2 joueurs, émulateur mobile, reconnexion sur DataStore de test ; commit local. Risques ouverts pour T6 : A-26, A-27 (`PROJECT_STATUS.md`) |
| T3 | Vente et Coins | Transaction fiable, inventaire vidé correctement | **Terminé** (clôturé le 2026-11-12) — E1–E7, E9 et rendu 3D validés, E8 partiel accepté (manette physique reportée) ; A-34 et A-35 corrigés ; place version 25 ; commits locaux, non poussés |
| T4 | Améliorations (5) et progression des mondes | Achats validés côté serveur | **Terminé** (clôturé le 2026-11-12) — U1–U9b validés (Studio, émulateur, téléphone réel), U10 manette reporté ; A-39, A-40, A-41 corrigés ; commits locaux 69fb421 et e63039d, non poussés. Ouvertes : A-36 (T7), A-37 (T6), A-38 (T5) |
| T5 | HUD et feedback mobile | Boucle complète utilisable sur téléphone | **Terminé** (clôturé le 2026-11-13, D-018, avec réserves : manette, tablette réelle, performance non chiffrée) — T5.1 HUD **terminé** (clôturé le 2026-11-12 : tests automatisés, Studio, téléphone réel OK ; commit local 5d4f339) ; T5.2 feedback **terminé** (clôturé le 2026-11-12 : tests automatisés, Studio, téléphone réel OK) ; T5.3 première session **terminé** (2026-11-13 : tests automatisés, Studio et émulateur OK ; D-017 acceptée ; commit local) ; T5.4 textes EN/FR **terminé** (2026-11-13 : validé ; commit local) ; T5.5 validation **terminée avec réserves** (2026-11-13 : technique, émulateur, téléphone réel et PC validés par le propriétaire ; manette reportée, tablette réelle non testée)  |
| T6 | Tests multijoueurs et anti-exploit | Aucun exploit simple, aucune fuite de données | **Terminé** (clôturé le 2026-11-14, D-019, `phases/T6_SECURITY_REPORT.md`) — tests automatisés, Studio un joueur, Local Server 2 joueurs (propriétaire) OK ; commit local c199d85, non poussé. Réserves : A-27 (mobile réel), A-42, seuils R4 à calibrer |
| T7 | Équilibrage MVP | Première session compréhensible et satisfaisante | **Terminé** (clôturé le 2026-11-14, test réel du propriétaire) — D-020 : Backpack 2 à 75, temps de jeu, schéma v2, succès permanents, simulateur ; `phases/T7_IMPLEMENTATION_REPORT.md` ; tests automatisés et Studio OK ; commit et push autorisés le 2026-11-14 |
| T8 | Préparation publication | Tests privés concluants | À faire |

## Phases terminées : T2, T3, T4, T5, T6

T2 — Collecte et inventaire (`COLLECTION.md`), clôturée le 2026-11-11.

T3 — Vente et Coins (`SELLING.md`) : `SellService`, transaction unique,
zone de vente provisoire, HUD Coins. D-014 validée (pas d'`EconomyService`
avant T4 ; paramètres de sécurité provisoires, à réévaluer en T6).
Clôturée le 2026-11-12 ; réserve : E8 sur manette physique reporté.

T4 — Améliorations et progression (`UPGRADES.md`, `PROGRESSION.md`,
D-015) : `EconomyService`, `UpgradeService` (cinq améliorations, achat x1),
`WorldUnlockService` (quatre mondes, sans contenu), boutique client, retour
visuel des achats (A-40). Clôturée le 2026-11-12 ; réserve : U10 sur
manette reporté.

## T5 — HUD et feedback mobile (clôturée le 2026-11-13, D-018)

HUD et feedback mobile : périmètre et décisions validés (D-016,
`phases/T5_PREFLIGHT.md`). Lot T5.1 (HUD) implémenté : sac en pastille
puis barre, états presque plein et plein, ligne Coins, panneau Boutique
sous le sac ; clôturé le 2026-11-12. Lot T5.2 (feedback audio et visuel)
implémenté : `FeedbackController`, 8 sons du compte Roblox
(`assets/SOUND_MANIFEST.md`), préférences Son / Effets réduits ; clôturé
le 2026-11-12 (téléphone réel validé). Lot T5.3 (première session)
implémenté le 2026-11-13 : guidage Collecter → Vendre → Améliorer, étapes
déduites des statistiques persistantes (`ONBOARDING.md`) ; validé sur
émulateur, D-017 acceptée, clôturé. Lot T5.4 (textes) implémenté le
2026-11-13 : vouvoiement, A-22, unités localisées, tests de couverture
EN/FR (`LOCALIZATION.md`) ; validé, clôturé. Lot T5.5 (validation) : terminé avec
réserves le 2026-11-13 (`tests/T5_MULTIPLATFORM_REPORT.md`) ; aucune
P0/P1 ; T55-01 corrigée ; place version 56. T5 clôturée (D-018).

T6 — Tests multijoueurs et anti-exploit (`phases/T6_SECURITY_REPORT.md`,
`phases/T6_MULTIPLAYER_TEST_REPORT.md`, D-019) : clôturée le 2026-11-14.

T7 — Équilibrage MVP : validée et clôturée par le propriétaire le 2026-11-14 après test réel
(`phases/T7_PROGRESSION_AUDIT.md`, `phases/T7_ECONOMY_SIMULATION.md`,
`phases/T7_IMPLEMENTATION_REPORT.md`). T8 non commencée.

## Après le MVP (ne pas commencer avant validation de T0 à T8)

- Achats x10 / x100 / MAX (Magnet, Boots, Multiplier faits en T4, D-015).
- Wild Fruit, Green Crystal ; Grab Combo.
- Contenu réel de Golden Desert, Frozen Peaks, Mystic World (déblocage seul en T4).
- Gems, Stars et Prestige.
- Pets et œufs ; quêtes et succès ; événements coopératifs.
- Monétisation (Game Pass, Developer Products).
- Classements et fonctions sociales.
