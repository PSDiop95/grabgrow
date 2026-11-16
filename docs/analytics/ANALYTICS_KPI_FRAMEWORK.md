# Cadre des indicateurs (KPI) — GRAB & GROW

Version : T9 (2026-11-16). Aucune valeur n'est mesurée à ce jour : le jeu
n'est pas publié et aucun événement n'a encore été reçu par Roblox. Les
cibles éventuelles sont à fixer **après** les premières données réelles
(test fermé), jamais à partir de projections.

Sources : **CD** = Creator Dashboard natif (sans code) ; **EV** = événement
du catalogue (`ANALYTICS_EVENT_CATALOG.md`) ; **CA** = calcul à partir des
événements (export ou lecture manuelle) ; **ND** = non disponible.

## A. Acquisition et activité

| Indicateur | Source | Définition |
|---|---|---|
| Nouveaux joueurs | CD (Engagement / Acquisition) | Premiers visiteurs par jour |
| Joueurs actifs (DAU, MAU) | CD | Utilisateurs uniques par jour / mois |
| Sessions par joueur | CD | Sessions / DAU |
| Durée moyenne de session | CD ; EV `SessionEnded` (moyenne) | Le CD fait foi ; `SessionEnded` sert de contrôle (temps après chargement du profil) |
| Retours des joueurs | CD (rétention, joueurs récurrents) | — |

## B. Activation

| Indicateur | Source | Calcul |
|---|---|---|
| Taux de première collecte | EV onboarding | Étape 2 / étape 1 |
| Taux de première vente | EV onboarding | Étape 3 / étape 1 |
| Taux de première amélioration | EV onboarding | Étape 4 / étape 1 |
| Achèvement de l'onboarding du jeu | EV onboarding | Étape 4 / étape 1 (onboarding du jeu en 3 actions) |
| Entrée dans la progression des mondes | EV onboarding | Étape 5 / étape 1 |

Le funnel ne compte que les joueurs arrivés **après** l'activation de T9 et
ayant commencé sans progression (étape 1).

## C. Économie

| Indicateur | Source | Calcul |
|---|---|---|
| Coins gagnés | EV économie `Source` | Somme ; détail ventes (`Sale:*`) / succès (`Achievement:*`) |
| Coins dépensés | EV économie `Sink` | Somme |
| Répartition des dépenses | EV économie | Par SKU : `Upgrade:*` / `World:*` |
| Solde moyen | CD (Economy) | Fourni par Roblox à partir du solde final |
| Progression des améliorations | EV `UpgradePurchased` | Achats par amélioration et par niveau |
| Temps pour débloquer chaque monde | ND directement ; CA approchée | Roblox n'agrège pas un délai par joueur ; approximation : comparaison des cohortes ou ajout ultérieur d'une valeur (décision à prendre) |

## D. Progression

| Indicateur | Source | Calcul |
|---|---|---|
| Déblocages par monde | EV progression `Worlds` | Joueurs par niveau 2 à 4 |
| Répartition des joueurs par monde | EV `WorldEntered` | Entrées par monde (approximation : pas de temps passé par monde) |
| Fréquence des déplacements | EV `WorldEntered` | Total / sessions |
| Progression du Collection Journal | EV `JournalDiscovery` | Découvertes par monde et rareté ; moyenne par joueur |
| Ressources les plus collectées | EV `ResourcesCollected` | Par **monde** seulement (choix de cardinalité) ; par ressource : ND |
| Saturation du sac | EV `BackpackFull` | Épisodes par session |

## E. Rétention

| Indicateur | Source |
|---|---|
| D1, D7, D30 | CD (Retention) uniquement |

## F. Indicateurs non disponibles

- Temps passé par monde, trajets dans la carte, positions.
- Ouverture de la boutique et consultation des cartes.
- Collecte par ressource individuelle (agrégée par monde).
- Causes de départ du joueur ; ressenti.

## Calendrier de lecture (après publication autorisée)

1. Jour 0 : « View Events » (quasi temps réel) pour vérifier noms et valeurs.
2. Jour 1 à 2 : graphiques Economy, Funnel, Custom (environ 24 h de délai).
3. Fin du test fermé : premier relevé A à E, sans conclusion d'équilibrage
   tant que l'échantillon est faible.
