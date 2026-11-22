# T10.3 — Synthèse décisionnelle : ressources sacrées

Date : 2026-11-22 — Statut : **DÉCISIONS 1 à 6 VALIDÉES (D-035)**, non
implémentées ; valeurs provisoires (S2, k = 2).
Cadre retenu par le propriétaire : option A (v3), régime R1 (récompense
unique à la première victoire), scénario prioritaire S2 (k = 2). Aucun
changement de code, de schéma ni de `ResourceConfig`. Sources :
`T10_3_SACRED_ECONOMY_SIMULATION.md`, `T10_3_PERSISTENCE_OPTION_A.md`,
lecture du code (`InventoryService`, `SellService`,
`CollectionJournalRules`, `GuardianRules`, `ProfileAudit`, `DataSchema`).

## 1. Paramètres recommandés

| Paramètre | Recommandation | Alternatives écartées |
|---|---|---|
| Unités à la 1re victoire | **3 par site** (offre totale et définitive : 12 unités) | 1 : choix binaire, une seule amélioration possible par monde. 5 : 10 min de revenu, proche de S4 |
| Place dans le sac | **1 place par unité** (règle actuelle : `used` = somme des quantités) | 5 places : nouvelle règle de poids dans `InventoryService`, `ProfileAudit`, HUD et tests, pour un effet négligeable (§3) |
| Rareté | **Catégorie « Sacrée » distincte**, hors des raretés d'apparition | « Epic » : valeur 23 à 58 fois l'Épique du monde, jamais sur un nœud, hors Journal : libellé trompeur |
| Stockage de la définition | **Configuration dédiée** (ex. `SacredResourceConfig`), **pas** `ResourceConfig` | `ResourceConfig` : voir §4 (vente automatique, Journal, accès au site) |
| Attribution | **Réclamation à la terrasse** : 2e clé `achievements["sanctuary_reward_<siteId>"]`, posée dans la même mutation que l'ajout des 3 unités ; refus `INVENTORY_FULL` sans rien poser | Plus simple : exiger 3 places libres à l'activation ; mais le sac peut changer avant la victoire, et une victoire sans récompense ne se rattrape pas |
| Valeur de vente | **k = 2 à examiner** : 198 / 868 / 5 840 / 27 992 Coins (GV / GD / FP / MW) | Non fixée : à confirmer en test réel |

## 2. Rareté « Sacrée » et raretés existantes

| Monde | Rare (`sellValue`) | Épique (`sellValue`) | Sacrée k = 2 | Rapport Sacrée / meilleure rareté |
|---|---|---|---|---|
| Green Valley | 12 | — | 198 | × 16,5 (Rare) |
| Golden Desert | 17 | 38 | 868 | × 23 |
| Frozen Peaks | 62 | 140 | 5 840 | × 42 |
| Mystic World | 230 | 480 | 27 992 | × 58 |

| Critère | Common à Epic (existantes) | Sacrée (proposée) |
|---|---|---|
| Origine | Nœuds, `spawnWeight` | Victoire contre le gardien, une seule fois |
| Journal (`RARITY_ORDER`) | Comptée | Non comptée |
| Vente normale | Oui, avec le sac | Non : action dédiée et confirmée (T10-D03) |
| Effets visuels | `ResourceVFXConfig` par rareté | Entrée propre à ajouter (lot visuel) |
| Usage | Coins | Coins **ou** amélioration spéciale |

Conclusion : un 5e palier d'apparition serait incohérent (pas de
`spawnWeight`, pas de nœud). « Sacrée » est une catégorie d'objet de
progression, affichée à part.

## 3. Impact sur le sac

Capacité au moment de l'accès au site (joueur régulier, simulation) et
place prise par les 3 unités :

| Monde | Backpack à l'accès | 3 unités à 1 place | 3 unités à 5 places |
|---|---|---|---|
| Green Valley | 140 | 2,1 % | 10,7 % |
| Golden Desert | 180 | 1,7 % | 8,3 % |
| Frozen Peaks | 420 | 0,7 % | 3,6 % |
| Mystic World | 700 | 0,4 % | 2,1 % |

- Les unités restent dans le sac jusqu'à une vente ou une consommation confirmée (T10-D03). Avec 1 place, la gêne est négligeable ; avec 5, elle n'est sensible qu'en Green Valley, sans intérêt de jeu démontré.
- `ProfileAudit` : `InventoryOverCapacity` reste juste (les unités comptent dans `used`) ; `InventoryExceedsCollected` ne se déclenche pas après une session normale (3 unités contre des centaines collectées).
- Le HUD du sac devra afficher ces identifiants (lot d'interface, après validation).

## 4. Impact sur le Journal

| Choix | Effet |
|---|---|
| **Configuration dédiée (recommandée)** | Journal inchangé : 20 ressources, 5 par monde, progression actuelle conservée. Règle d'accès au site (5 ressources du monde découvertes) inchangée. Aucun profil existant affecté |
| Ajout à `ResourceConfig` | Journal à 24 : les joueurs à 20/20 redescendent sous 100 %. Règle d'accès circulaire (il faudrait la ressource sacrée pour accéder au site qui la donne). `SellService` vendrait les unités avec le sac, sans choix |

Une page « Reliques » ou une mention dans le Journal reste possible plus
tard, hors du compte 20/20 (à décider séparément).

## 5. Impact économique (S2, R1, 3 unités, tout vendu)

| Monde | Gain unique | En minutes de revenu à l'accès | Effet sur le palier suivant |
|---|---|---|---|
| Green Valley | 594 | 6 min | Golden Desert ≈ 6 min plus tôt sur 74 min (≈ −8 %) |
| Golden Desert | 2 604 | 6 min | Frozen Peaks ≈ −2 % |
| Frozen Peaks | 17 520 | 6 min | Mystic World ≈ −1 % |
| Mystic World | 83 976 | 6 min | Fin de progression : ≈ −1 % |

- Total : au plus 24 min de revenu sur ≈ 13 h de progression (≈ 3 %), une seule fois par profil.
- Première vente et première amélioration : inchangées (sites accessibles plus tard).
- Revenu par minute : inchangé (aucune source répétée, R2 et R3 écartés). Aucun risque de ferme.
- Joueur occasionnel : même gain en minutes, effet relatif plus sensible sur Golden Desert (≈ −7 %). Joueur très actif : effet plus faible.
- Choix vendre / améliorer : le Sac sacré 1 dépasse la vente après ≈ 37 à 58 min de jeu (selon le monde), soit environ une à deux sessions : vrai dilemme. Offre totale de 12 unités : au plus 4 améliorations à 3 unités, ou moins si leurs coûts croissent.

## 6. Décisions (validées le 2026-11-22, D-035)

1. 3 unités par site, une seule fois, à la première victoire.
2. 1 place de sac par unité.
3. Catégorie « Sacrée » distincte.
4. Configuration dédiée hors `ResourceConfig` ; Journal à 20/20 ; accès aux sites inchangé.
5. Réclamation à la terrasse ; sac plein → `INVENTORY_FULL`, droit conservé, nouvel essai possible ; attribution atomique et unique.
6. S2 (k = 2) comme hypothèse de test ; valeurs provisoires.

Ces décisions n'autorisent aucune modification du code, du schéma, de
`ResourceConfig` ni de l'économie. Tests P1 à P15 :
`T10_3_PERSISTENCE_OPTION_A.md` §4. Critères de validation de T10.3 :
M1 à M14 et L1 à L7 (`docs/tests/T10_3_TEST_PLAN.md`), non exécutés.
