# GRAB & GROW — Roadmap

Dernière mise à jour : 2026-11-15

Phasage du MVP repris de l'architecture technique (section 20, T0 à T8),
modifié par D-021 (2026-11-14) : T8 = mondes et contenu ; la préparation
de publication devient T9.
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
| T8 | Mondes et contenu (D-021) : quatre îles, ressources par monde, voyage serveur | Quatre mondes jouables, collecte et vente par monde, multijoueur et performance mobile vérifiés | **En cours** — T8.0 à T8.5 validées ; T8.6 et T8.7 soumis à validation |
| T9 | Préparation publication, `AnalyticsService` (D-020 D5, D-021) | Tests privés concluants | À faire (ne pas commencer avant validation de T8) |

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
`phases/T7_IMPLEMENTATION_REPORT.md`).

## T8 — Mondes et contenu (en cours, D-021)

| Lot | Contenu | État |
|---|---|---|
| T8.0 | D-021, harmonisation des documents, Bible 1.1, `assets/ASSET_MANIFEST.md` | Validé (2026-11-14) |
| T8.1 | Architecture : ressources des quatre mondes, `ResourceNodes` générique, collecte refusée dans un monde verrouillé, `WorldTravelService` et `TravelToWorld`, simulateur quatre mondes, tests | Validé sous réserve du test multijoueur, puis test Local Server réussi (2026-11-14) |
| T8.2 | Green Valley : zones, hub, Fruit sauvage et Cristal vert, portails, interface de voyage | Validé (2026-11-15, `phases/T8_IMPLEMENTATION_REPORT.md`) |
| T8.3 | Golden Desert : oasis (vente, portail de retour), dunes, ruines et arche, crête, recoin du Cristal solaire ; particules réservées à l'Épique | Validé (2026-11-15, `phases/T8_3_GOLDEN_DESERT_REPORT.md`) |
| T8.4 | Frozen Peaks : camp de base (vente, portail de retour), plateau enneigé, lac gelé et cascade, grotte de cristaux bleus, sommet panoramique ; particules du Diamant de glace | Validé (2026-11-15, `phases/T8_4_FROZEN_PEAKS_REPORT.md`) |
| T8.5 | Mystic World : archipel de 7 îles flottantes et 7 ponts suspendus ; île d'arrivée (vente, portail de retour, repère), forêt mystique, îles flottantes, grotte spectrale, sanctuaire du Cœur mystique ; particules du Cœur mystique | Validé (2026-11-15) (`phases/T8_5_MYSTIC_WORLD_REPORT.md`) |
| T8.6 | (Journal de collection : reporté, D-021 D6) | Non retenu |
| T8.7 | Validation multijoueur et performance, rapport | En attente |

## Après le MVP (ne pas commencer avant validation de T0 à T9)

- Achats x10 / x100 / MAX (Magnet, Boots, Multiplier faits en T4, D-015).
- Grab Combo. (Wild Fruit, Green Crystal et le contenu des mondes 2 à 4
  passent en T8, D-021.)
- Journal de collection et schéma v3 (reportés, D-021 D6) ; événements
  environnementaux (D-021 D9).
- Gems, Stars et Prestige.
- Pets et œufs ; quêtes et succès ; événements coopératifs.
- Monétisation (Game Pass, Developer Products).
- Classements et fonctions sociales.
