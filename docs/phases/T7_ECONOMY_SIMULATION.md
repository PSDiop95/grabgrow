# T7 — Simulation économique

Date : 2026-11-14. Décision : D-020. Outil :
`lune run tools/simulate_progression.luau [current|bible|noach] [events]`.

**Projections théoriques, pas des résultats de tests joueurs.** L'outil
lit les vraies configurations (`UpgradeConfig`, `WorldConfig`,
`ResourceConfig`, `AchievementConfig`) : aucune valeur copiée.

## 1. Modèle

- Temps par unité = intervalle Grabber + d0 × (12 / portée Magnet) ×
  (16 / vitesse Boots).
- Aller-retour de vente = T0 × 16 / vitesse.
- Valeur d'un sac = floor(capacité × 1,78), puis Multiplier arrondi à
  l'inférieur (comme `SaleValue`).
- Achats après chaque vente ; monde débloqué dès que possible ; le
  Backpack requis par le monde suivant est favorisé (gain × 2).

| Profil | d0 | T0 | Stratégie | Jeu par jour | Origine |
|---|---|---|---|---|---|
| Occasionnel | 1,20 s | 30 s | Achète le moins cher abordable | ≈ 6 min (15 min × 3 / semaine) | Hypothèse |
| Régulier | 0,79 s | 20 s | Meilleur gain / coût | 30 min | d0 calé sur la **mesure** 39 collectes / min |
| Très actif | 0,50 s | 14 s | Meilleur gain / coût | 2 h | Hypothèse |

## 2. Résultats (temps de jeu ; jour calendaire entre parenthèses)

| Jalon | Occasionnel : Bible 1.0 → T7 | Régulier : Bible 1.0 → T7 | Très actif : Bible 1.0 → T7 |
|---|---|---|---|
| Revenu de départ | 41 Coins/min | 54 Coins/min | 69 Coins/min |
| Sac plein / temps entre deux ventes | 1,6 / 2,1 min | 1,3 / 1,6 min | 1,0 / 1,3 min |
| Première amélioration | 4,2 → **2,1 min** | 3,2 → **1,6 min** | 2,5 → **1,3 min** |
| Backpack 5 | 1,8 h → 88 min (j14) | 65 → 53 min (j2) | 60 → 51 min |
| Golden Desert | 2,4 → 2,1 h (j20) | 1,8 → 1,5 h (j4) | 84 → 63 min (j1) |
| Backpack 8 | 12,8 → 10,0 h (j93) | 10,6 → 8,4 h (j17) | 8,7 → 6,9 h (j4) |
| Frozen Peaks | 32,7 → 28,1 h | 22,1 → 18,5 h | 18,3 → 15,3 h |
| Mystic World | 189 → 185 h | 97,5 → 93,9 h | 78,1 → 75,0 h |
| Tout au maximum | 389 → 385 h | 312 → 309 h | 263 → 260 h |
| Revenu final | 214 Coins/min | 260 Coins/min | 307 Coins/min |

Coût cumulé : 4 383 775 Coins (− 25). Récompenses des succès : 30 200
Coins au total, uniques.

Récompenses perceptibles (achats + succès), joueur régulier :

| Fenêtre de jeu | Bible 1.0 | T7 |
|---|---|---|
| 0 à 10 min | 3 | 4 |
| 10 à 30 min | 3 | 6 |
| 30 à 60 min | 4 | 5 |
| 1 à 2 h | 4 | 9 |
| 2 à 5 h | 8 | 7 |
| 5 à 10 h | 5 | 7 |

## 3. Sensibilité (joueur régulier, T7)

| Variation | Golden Desert | Backpack 8 |
|---|---|---|
| Base | 1,5 h | 8,4 h |
| Collecte − 20 % / + 20 % | 1,7 h / 84 min | 9,1 h / 7,7 h |
| Valeur − 20 % / + 20 % | 1,9 h / 79 min | 10,4 h / 7,0 h |

Aucune variation de ± 20 % ne bloque ni n'accélère brutalement la
progression : le modèle n'est pas fragile (Bible 14.2).

## 4. Variantes écartées (étape A)

| Variante | Régulier : Backpack 8 | Régulier : Mystic World | Raison |
|---|---|---|---|
| P1 (coûts ≥ 2 000 × 0,6) | 7,2 h | 133 h (+ 35 h) | Plateau décalé, pas supprimé |
| P2 (Golden Desert dès Backpack 4) | inchangé | inchangé | Monde vide |

## 5. Limites

- Une seule mesure réelle (39 collectes / min, émulateur). Magnet, Boots,
  aller-retour de vente et comportements d'achat sont des hypothèses.
- Joueur seul : la concurrence pour les nœuds entre joueurs n'est pas
  modélisée.
- À mesurer en test privé (T8) : temps jusqu'à la 1re vente et au 1er
  achat, revenu par minute, `stats.playTimeSeconds` aux jalons.
