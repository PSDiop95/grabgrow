# GRAB & GROW — Progression économique (T4)

Dernière mise à jour : 2026-11-12.

**Projections théoriques**, pas des résultats de playtest. Valeurs :
`UpgradeConfig` et `WorldConfig` (Bible 5 et 6, inchangées). Aucune
valeur n'a été modifiée. Toute correction attend l'accord du propriétaire
(T7).

## Modèle

Revenu par minute =
`60 × floor(capacité × v × multiplicateur) / (capacité × intervalle / e + T)`

| Hypothèse | Valeur | Source |
|---|---|---|
| Valeur moyenne d'une unité `v` | 1,78 Coins | Trois ressources du MVP (D-003, A-02) |
| Efficacité de collecte `e` | 0,6 | Hypothèse : déplacements entre nœuds |
| Aller-retour de vente `T` | 20 s | Hypothèse |
| Magnet et Boots | Non modélisés | Ils réduisent les déplacements : gain dépendant de la carte, à mesurer |

Revenu de départ projeté : **≈ 65 Coins/min** (joueur actif). La Bible
vise 120 à 250 Coins/min en Green Valley (4.2) : écart attendu, car la
valeur moyenne du MVP est plus faible (1,78 contre 2,24) et le modèle
compte les déplacements.

Repère mesuré dans Studio (2026-11-12, un joueur, script) : sac de 18 à
19 unités vendu 32 à 33 Coins, limité par les 36 nœuds de la carte de
test. Ce n'est pas un playtest.

## Tableaux par amélioration

« Gain » : hausse du revenu par minute par rapport au niveau précédent,
les autres améliorations au départ. « Rentabilisé » : coût / gain par
minute.

### Backpack (capacité)

| Niveau | Capacité | Coût | Cumulé | Gain | Rentabilisé |
|---|---|---|---|---|---|
| 1 | 50 | 0 | 0 | — | — |
| 2 | 75 | 100 | 100 | +8,4 % | 18 min |
| 3 | 100 | 250 | 350 | +5,0 % | 71 min |
| 4 | 140 | 600 | 950 | +4,0 % | 3,4 h |
| 5 | 180 | 1 200 | 2 150 | +2,3 % | 11 h |
| 6 | 240 | 2 500 | 4 650 | +2,2 % | 25 h |
| 7 | 320 | 5 000 | 9 650 | +1,5 % | 68 h |
| 8 | 420 | 10 000 | 19 650 | +1,2 % | 175 h |
| 9 | 550 | 20 000 | 39 650 | +1,0 % | 424 h |
| 10 | 700 | 40 000 | 79 650 | +0,6 % | 1 318 h |
| 11 à 16 | 850 à 2 000 | 75 000 à 1 000 000 | 2 464 650 | < 0,5 % | > 3 000 h |

### Grabber (intervalle)

| Niveau | Intervalle | Coût | Cumulé | Gain | Rentabilisé |
|---|---|---|---|---|---|
| 1 | 0,75 s | 0 | 0 | — | — |
| 2 | 0,70 s | 150 | 150 | +5,3 % | 44 min |
| 3 | 0,65 s | 400 | 550 | +5,6 % | 1,7 h |
| 4 | 0,60 s | 900 | 1 450 | +6,0 % | 3,5 h |
| 5 | 0,55 s | 2 000 | 3 450 | +6,3 % | 6,9 h |
| 6 | 0,50 s | 5 000 | 8 450 | +6,8 % | 15 h |
| 7 | 0,46 s | 12 000 | 20 450 | +5,7 % | 40 h |
| 8 | 0,42 s | 30 000 | 50 450 | +6,1 % | 90 h |
| 9 | 0,39 s | 70 000 | 120 450 | +4,8 % | 252 h |
| 10 | 0,36 s | 150 000 | 270 450 | +5,0 % | 492 h |

### Multiplier (vente)

| Niveau | Bonus | Coût | Cumulé | Gain | Rentabilisé |
|---|---|---|---|---|---|
| 1 | x1,00 | 0 | 0 | — | — |
| 2 | x1,05 | 300 | 300 | +4,5 % | 1,7 h |
| 3 | x1,10 | 800 | 1 100 | +4,3 % | 4,6 h |
| 4 | x1,15 | 1 800 | 2 900 | +5,2 % | 8,3 h |
| 5 | x1,20 | 4 000 | 6 900 | +3,9 % | 23 h |
| 6 | x1,25 | 9 000 | 15 900 | +4,7 % | 41 h |
| 7 | x1,30 | 22 000 | 37 900 | +3,6 % | 126 h |
| 8 | x1,35 | 55 000 | 92 900 | +4,3 % | 252 h |
| 9 | x1,40 | 130 000 | 222 900 | +3,3 % | 745 h |
| 10 | x1,50 | 300 000 | 522 900 | +7,3 % | 764 h |

Gains irréguliers : l'arrondi inférieur s'applique par sac.

### Magnet (portée) et Boots (vitesse)

| Niveau | Magnet | Coût | Cumulé | Niveau | Boots | Coût | Cumulé |
|---|---|---|---|---|---|---|---|
| 0 | 12 studs | 0 | 0 | 1 | 16 | 0 | 0 |
| 1 | 14 | 200 | 200 | 2 | 16,5 | 250 | 250 |
| 2 | 16 | 500 | 700 | 3 | 17 | 650 | 900 |
| 3 | 18 | 1 200 | 1 900 | 4 | 17,5 | 1 500 | 2 400 |
| 4 | 20 | 3 000 | 4 900 | 5 | 18 | 3 500 | 5 900 |
| 5 | 22 | 7 500 | 12 400 | 6 | 18,5 | 8 000 | 13 900 |
| 6 | 24 | 18 000 | 30 400 | 7 | 19 | 20 000 | 33 900 |
| 7 | 26 | 45 000 | 75 400 | 8 | 19,5 | 50 000 | 83 900 |
| 8 | 28 | 100 000 | 175 400 | 9 | 20 | 110 000 | 193 900 |
| 9 | 30 | 220 000 | 395 400 | 10 | 20,5 | 250 000 | 443 900 |

Gain non modélisé : à mesurer en playtest (temps entre deux collectes,
temps d'un aller-retour de vente).

## Parcours simulés

Stratégie : acheter l'amélioration (Backpack, Grabber, Multiplier) au
meilleur rapport gain / coût. Joueur occasionnel = moitié du revenu.

| Jalon | Joueur actif | Joueur occasionnel |
|---|---|---|
| Première vente | ≈ 1,4 min | ≈ 2,8 min |
| Première amélioration (Backpack 2) | ≈ 1,5 min | ≈ 3,1 min |
| Backpack 5 atteint | ≈ 71 min | ≈ 2,4 h |
| Golden Desert débloquable | ≈ 85 min | ≈ 2,8 h |
| Trois améliorations au maximum | ≈ 222 h | ≈ 445 h |
| Revenu final en Green Valley | ≈ 263/min | ≈ 131/min |

Coût cumulé de tous les maximums : 4 097 300 Coins (Backpack 2 464 650,
Grabber 270 450, Magnet 395 400, Boots 443 900, Multiplier 522 900).
Mondes : 286 500 Coins.

## Risques

1. **Progression bloquée après les premiers paliers.** Au-delà du niveau
   5 environ, chaque niveau se rentabilise en dizaines ou centaines
   d'heures en Green Valley. La Bible prévoit que ces niveaux se paient
   avec les revenus des mondes suivants (Golden Desert : x9 en valeur).
   Tant que Green Valley est le seul monde jouable, un joueur actif
   plafonne après 1 à 2 h. Acceptable pour un MVP ; à surveiller.
2. **Backpack peu rentable au-delà du niveau 4** dans ce modèle : la
   collecte, et non les allers-retours de vente, limite le revenu. Dépend
   fortement de `T` et de la densité de la carte.
3. **Golden Desert à ≈ 85 min (actif)** : probablement long pour un
   premier objectif de session (cible de rétention non définie dans la
   Bible). À mesurer en T7.
4. **Revenu de départ sous la cible de la Bible** (65 contre 120 à
   250/min) : conséquence de la valeur moyenne du MVP (A-02).
5. **Magnet et Boots** : utilité perçue inconnue, aucun modèle de gain.

Aucune de ces projections ne justifie à elle seule une modification de
valeur : décision du propriétaire, après playtest (T7).
