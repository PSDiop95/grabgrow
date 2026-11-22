# T10.3 — Simulation économique des ressources sacrées

Date : 2026-11-22 — Statut : **SCÉNARIOS, aucune valeur fixée**.
`ResourceConfig`, `UpgradeConfig` et toute configuration économique sont
inchangés. Reproduire : `lune run tools/simulate_sacred_economy.luau`.

## 1. Méthode et limites

- Revenus de référence lus dans `tools/simulate_progression.luau` (joueur régulier, configuration actuelle) : **projections théoriques**, plus rapides que le jeu réel (réapparition des nœuds et concurrence ignorées).
- Joueur occasionnel ≈ −20 %, très actif ≈ +25 % de revenu au départ (même outil) : les rapports ci-dessous changent peu, car la valeur proposée est exprimée en minutes de revenu.
- Accès au site : Green Valley vers 26 min (hypothèse : 5 ressources découvertes), autres mondes dès leur déblocage.
- Ferme : combat 60 s + réapparition 45 s (`GuardianConfig`).
- Amélioration de référence : « Sac sacré 1 », 3 unités, +10 % de capacité ≈ **+9 % de revenu (estimation non simulée)**.
- Une unité sacrée = 5 places de sac (hypothèse).

## 2. Revenus de référence

| Monde | Accès au site | Revenu à l'accès | Revenu avant le monde suivant |
|---|---|---|---|
| Green Valley | 25,8 min | 99 Coins/min | 123 Coins/min |
| Golden Desert | 74,3 min | 434 Coins/min | 780 Coins/min |
| Frozen Peaks | 5,3 h | 2 920 Coins/min | 3 817 Coins/min |
| Mystic World | 9,8 h | 13 996 Coins/min | 16 138 Coins/min |

## 3. Valeurs de vente candidates (k minutes du revenu à l'accès)

| Monde | k = 0,5 | k = 1 | k = 2 | k = 4 |
|---|---|---|---|---|
| Green Valley | 50 | 99 | 198 | 396 |
| Golden Desert | 217 | 434 | 868 | 1 736 |
| Frozen Peaks | 1 460 | 2 920 | 5 840 | 11 680 |
| Mystic World | 6 998 | 13 996 | 27 992 | 55 984 |

Gain de la première victoire (3 unités vendues) : 1,5 / 3 / 6 / 12 min de
jeu selon k.

## 4. Régimes de récompense et risque de ferme

Rapport = revenu horaire tiré du gardien / revenu normal. Au-dessus de
1,00, combattre en boucle rapporte plus que la boucle Grab → Sell.

| Régime | k = 0,5 | k = 1 | k = 2 | k = 4 | Compatible option A |
|---|---|---|---|---|---|
| R1 — 3 unités à la 1re victoire seulement | 0 | 0 | 0 | 0 | Oui : la clé `sanctuary_*` rend l'attribution unique et définitive |
| R2 — R1 + 1 unité par 10 min de session | 0,05 | 0,10 | 0,20 | 0,40 | Partiel : limite réinitialisée par un changement de serveur |
| R3 — R1 + 1 unité par victoire | 0,29 | 0,57 | 1,14 | 2,29 | Oui, mais ferme dès k ≥ 2 |

## 5. Vendre ou améliorer

Seuil = temps de jeu après lequel le Sac sacré 1 rapporte plus que la vente
de ses 3 unités.

| Monde | k = 0,5 | k = 1 | k = 2 | k = 4 |
|---|---|---|---|---|
| Green Valley | 13 min | 27 min | 54 min | 1,8 h |
| Golden Desert | 9 min | 19 min | 37 min | 1,2 h |
| Frozen Peaks | 13 min | 26 min | 51 min | 1,7 h |
| Mystic World | 15 min | 29 min | 58 min | 1,9 h |

Lecture : une amélioration permanente finit toujours par dominer la vente.
Le choix n'est un vrai dilemme que si le seuil dépasse une session typique
(30 min/jour pour le joueur régulier), soit **k ≈ 2 à 4**, ou si
l'amélioration demande des unités de plusieurs mondes.

## 6. Scénarios proposés

| Scénario | k | Régime | Effet attendu | Risques |
|---|---|---|---|---|
| **S1 — Prudent** | 1 | R1 | Petit bonus (3 min de revenu) ; amélioration nettement plus intéressante après 30 min | Vente peu attractive : le double usage perd son sens |
| **S2 — Équilibré (recommandé pour test)** | 2 | R1 | Vente = 6 min de revenu immédiat ; amélioration rentable après ≈ 1 session : vrai choix | Aucune source répétée ; 3 unités par monde limitent les améliorations à ≈ 1 niveau par monde |
| S3 — Récurrent | 1 | R2 | Raison de revenir au gardien (+10 % au plus) | Contournable par changement de serveur ; demande un compteur pour être fiable (hors option A) |
| S4 — Généreux | 4 | R1 | Grosse récompense ponctuelle (12 min) ; vente souvent préférée en début de monde | Accélère le déblocage suivant d'environ 12 min ; à mesurer sur la durée totale |
| À exclure | ≥ 2 | R3 | — | Ferme du gardien plus rentable que la collecte |

Impact sur les jalons (joueur régulier, S2, tout vendu) : +6 min de revenu
par monde, soit environ −6 min sur l'accès à Golden Desert (74 min),
Frozen Peaks (5,3 h) et Mystic World (9,8 h) : impact < 2 % au-delà de
Green Valley, ≈ 8 % sur Golden Desert. Première vente, première
amélioration : inchangées (le site n'est accessible qu'ensuite).

## 7. À valider par le propriétaire

- [ ] Scénario (S1, S2, S3, S4 ou autre k).
- [ ] Nombre d'unités à la première victoire (3 simulées).
- [ ] Place dans le sac par unité (5 simulées).
- [ ] Liste et coûts des améliorations spéciales (rapport §8), à simuler ensuite avec un modèle de collecte complet.
- [ ] Nouvelle rareté « Sacrée » ou rattachement à une rareté existante.
