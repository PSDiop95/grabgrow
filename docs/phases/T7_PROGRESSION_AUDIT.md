# T7 — Audit de la progression et diagnostic A-36

Date : 2026-11-14. Décision : D-020. Étape A (aucun fichier modifié),
validée par le propriétaire le 2026-11-14 (« Oui, comme recommandé »).
Simulation : `T7_ECONOMY_SIMULATION.md`. Implémentation :
`T7_IMPLEMENTATION_REPORT.md`.

## 1. Prérequis

- T6 validée et clôturée le 2026-11-14 (D-019, `T6_SECURITY_REPORT.md`).
- Documents lus : `CLAUDE.md`, `PROJECT_STATUS.md`, `ROADMAP.md`, GDD
  (4.2, 4.3, 11), Bible économique (2, 3.6, 4, 5, 6, 8, 14, 15),
  `TECHNICAL_DECISIONS.md`, `PROGRESSION.md`, `UPGRADES.md`.

## 2. Données disponibles

| Élément | Valeur | Source |
|---|---|---|
| Ressources | Feuille 1, Bois 2, Pierre 3 Coins ; réapparition 2 / 3 / 4 s | `ResourceConfig` |
| Carte de test | 36 nœuds (16 / 12 / 8) : 1,78 Coins par unité en moyenne | `COLLECTION.md` |
| Offre de la carte | ≈ 14 unités/s, contre ≈ 1,3/s collectées par joueur : la réapparition ne limite pas un joueur seul | Calcul |
| Coût total des améliorations | 4 097 300 Coins (Backpack 2 464 650) ; mondes 286 500 | `UpgradeConfig`, `WorldConfig` |
| **Seule mesure réelle** | Maintien de la collecte : 39 collectes en 60 s (émulateur, T2) | `PROJECT_STATUS.md`, A-28 |
| Temps de jeu | `stats.playTimeSeconds` présent dans le schéma v1, non alimenté | A-21 |

## 3. Diagnostic A-36 (configuration Bible 1.0)

Projections, joueur régulier (hypothèses dans `T7_ECONOMY_SIMULATION.md`) :

| Période de jeu | Attente entre deux achats | Gain par achat |
|---|---|---|
| 0 à 1 h | 2 à 10 min | +3 à +8 % |
| 1 à 3 h | 12 à 25 min | +2 à +5 % |
| 3 à 6 h | 27 à 43 min | +2 à +5 % |
| 6 à 12 h | environ 1 h | +2 à +4 % |
| Au-delà de 12 h | 2 à 3,4 h | +1 à +4 % |

- **Cause :** en Green Valley, le revenu va de 54 à 260 Coins/min (× 4,8)
  quand les prix vont de 75 à 1 000 000 (× 2 à 2,5 par niveau). La Bible
  finance les niveaux avancés par les mondes suivants (valeur × 9 par
  monde), encore vides dans le MVP.
- **Paliers de ralentissement :** au-delà du niveau 5 ou 6 de chaque
  amélioration ; Backpack au-delà de 4 (collecte limitante, pas les
  allers-retours) ; Multiplier : + 5 % par niveau, imperceptible sur un
  sac de 89 Coins.
- **Mondes :** Golden Desert vers 1,4 à 2,4 h de jeu (cible du GDD 4.3 :
  « 5 à 10 min : nouvelle zone OU objectif intermédiaire ») ; Frozen Peaks
  18 à 33 h ; Mystic World 78 à 189 h. Golden Desert n'a pas de contenu.
- **Première session (A-19) :** premier sac ≈ 88 Coins, Backpack 2 à 100 :
  première amélioration à la 2e vente (2,5 à 4,2 min), cible 30 à 60 s.
- **Magnet et Boots :** effet modélisé par hypothèse seulement.
- **Conclusion :** A-36 est structurel. Baisser les prix décale de 30 %
  environ sans supprimer le plateau, et fausse la courbe des mondes
  futurs. La progression motivante en MVP couvre environ 2 à 4 h.

## 4. Propositions et décisions

| # | Proposition | Décision (D-020) |
|---|---|---|
| P0 | Backpack 2 : 100 -> 75 | Retenue |
| P1 | Coûts ≥ 2 000 × 0,6 | Écartée (gain modéré, Mystic World retardé de 35 h, courbe future faussée) |
| P2 | Golden Desert dès Backpack 4 | Écartée (monde vide) |
| P3 | 12 succès permanents en Coins | Retenue |
| A-21 | Temps de jeu serveur, ajouté avant chaque écriture | Retenue |
| — | `AnalyticsService` (entonnoir, économie) | Reportée à T8 |

## 5. Indicateurs de rétention

| Indicateur | Source |
|---|---|
| Durée des sessions, rétention J1 / J7, utilisateurs actifs | Creator Hub (natif, sans code) |
| Temps de jeu cumulé par profil | `stats.playTimeSeconds` (T7) |
| Première collecte, vente, achat ; progression des niveaux ; mondes | Compteurs du profil ; entonnoir `AnalyticsService` en T8 (à valider) |
| Points de blocage | Distribution des niveaux en test privé (T8) |

Aucune donnée personnelle, aucun service externe.
