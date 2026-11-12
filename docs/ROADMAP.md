# GRAB & GROW — Roadmap

Dernière mise à jour : 2026-11-12

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
| T5 | HUD et feedback mobile | Boucle complète utilisable sur téléphone | **En cours** — T5.1 HUD PARTIEL (tests automatisés et Studio OK ; téléphone réel à faire) ; T5.2 à T5.5 à faire |
| T6 | Tests multijoueurs et anti-exploit | Aucun exploit simple, aucune fuite de données | À faire |
| T7 | Équilibrage MVP | Première session compréhensible et satisfaisante | À faire |
| T8 | Préparation publication | Tests privés concluants | À faire |

## Phases terminées : T2, T3, T4

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

## Phase en cours : T5

HUD et feedback mobile : périmètre et décisions validés (D-016,
`phases/T5_PREFLIGHT.md`). Lot T5.1 (HUD) implémenté : sac en pastille
puis barre, états presque plein et plein, ligne Coins, panneau Boutique
sous le sac ; tests Studio OK ; téléphone réel en attente. T5.2 non commencé.

## Après le MVP (ne pas commencer avant validation de T0 à T8)

- Achats x10 / x100 / MAX (Magnet, Boots, Multiplier faits en T4, D-015).
- Wild Fruit, Green Crystal ; Grab Combo.
- Contenu réel de Golden Desert, Frozen Peaks, Mystic World (déblocage seul en T4).
- Gems, Stars et Prestige.
- Pets et œufs ; quêtes et succès ; événements coopératifs.
- Monétisation (Game Pass, Developer Products).
- Classements et fonctions sociales.
