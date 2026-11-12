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
| T3 | Vente et Coins | Transaction fiable, inventaire vidé correctement | **PARTIEL** (2026-11-12) — tests automatisés OK ; E1–E9 et rendu 3D validés ; A-34 corrigé et validé ; place sauvegardé (version 24) ; commit local, non poussé ; clôture en attente du propriétaire |
| T4 | Améliorations (Backpack, Grabber) | Achats validés côté serveur | À faire |
| T5 | HUD et feedback mobile | Boucle complète utilisable sur téléphone | À faire |
| T6 | Tests multijoueurs et anti-exploit | Aucun exploit simple, aucune fuite de données | À faire |
| T7 | Équilibrage MVP | Première session compréhensible et satisfaisante | À faire |
| T8 | Préparation publication | Tests privés concluants | À faire |

## Phase terminée : T2

Collecte et inventaire (`COLLECTION.md`), validée et clôturée le
2026-11-11.

## Phase en cours : T3

Vente et Coins (`SELLING.md`) : `SellService`, transaction unique, zone de
vente provisoire, HUD Coins. D-014 validée le 2026-11-11 (pas
d'`EconomyService` avant T4 ; paramètres de sécurité provisoires, à
réévaluer en T6). Tests E1–E9 validés, place sauvegardé, commit local
(2026-11-12). T3 reste PARTIEL jusqu'à la clôture par le propriétaire.

## Prochaine phase : T4

Améliorations Backpack et Grabber (premier débit de Coins, extraction de
`CreditCurrency` / `DebitCurrency`). Ne commence qu'après la clôture de T3
et l'accord explicite du propriétaire.

## Après le MVP (ne pas commencer avant validation de T0 à T8)

- Magnet, Boots, Multiplier ; achats x10 / x100 / MAX.
- Wild Fruit, Green Crystal ; Grab Combo.
- Golden Desert (contenu réel ; seule l'entrée verrouillée existe), Frozen Peaks, Mystic World.
- Gems, Stars et Prestige.
- Pets et œufs ; quêtes et succès ; événements coopératifs.
- Monétisation (Game Pass, Developer Products).
- Classements et fonctions sociales.
