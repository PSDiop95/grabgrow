# T10.3 — Règles complémentaires : audit et propositions (ressources sacrées)

Date : 2026-11-22 — Branche `t10-3-guardians` (HEAD `981e2d4`).
Statut : **toutes les décisions VALIDÉES** (D-037, D-038, 2026-11-22).
Côté serveur implémenté en T10.5a (`T10_5A_SACRED_TRANSACTIONS_REPORT.md`) ;
écarts : aucune condition de proximité pour la vente (§5 étape 3),
Multiplier non appliqué. Référence : règles complémentaires A à G
transmises le 2026-11-22 (reprennent l'addendum T10-D01 à T10-D03).

## 1. Conformité du code actuel (A à G)

| Règle | État | Preuve |
|---|---|---|
| A — combats individuels, serveur autoritaire, aucun état global | **Conforme** | `GuardianCombatService` : un état par `UserId` ; tests « deux joueurs… », « quatre joueurs… », « combats simultanés : un état par joueur, jamais global » ; Local Server 2 joueurs M3–M6 (T10.4 §5) |
| A — présentation sans multiplier les modèles | **Conforme** | 1 modèle statique ancré par site, animé et masqué localement (`LocalTransparencyModifier`) par `GuardianController` |
| B — déblocage persistant, jamais révoqué, gardien réapparaît | **Conforme** | `achievements["sanctuary_<site>"]` (option A, v3) ; P1–P4 ; « gardien déjà vaincu… accès conservé » ; réapparition 45 s par joueur |
| C — une ressource sacrée par monde, distincte des 20 | **Conforme** | `SacredResourceConfig` (4 identifiants, hors `ResourceConfig`) |
| C — vente et consommation | **Non implémentées** (valeurs non validées) | §3, §4 |
| D — améliorations spéciales | Conception seulement | §4 ; **conflit** relevé §2 |
| E — transactions atomiques | **Inexistantes** (vente, achat) ; la réclamation l'est déjà | §5 |
| F — persistance | Victoire et récompense : faites (option A autorisée). Améliorations : **nouvelle donnée persistante à autoriser** | §6 |
| G — tests | 9 sur 14 couverts ; 5 à écrire avec le lot | §7 |

Audit technique (A) — options Roblox pour présenter un gardien commun :

| Option | Coût | Retenue |
|---|---|---|
| 1 modèle serveur ancré, animation et masquage par client | 1 modèle par site, aucune réplication d'état d'autrui | **Oui** (actuel) |
| Modèle créé côté client depuis `ReplicatedStorage` | 1 modèle par client, invisible au serveur ; aucun gain mesurable ici | Non |
| Copie physique serveur par joueur | N modèles répliqués à tous, collisions croisées | Non (T10-D02) |

## 2. Conflit à résoudre : offre sacrée et coûts d'amélioration

D-035 fixe l'offre à **3 unités par site, une seule fois** (R1) : 12 unités
au total, 3 par monde. Les coûts du rapport T10.3 §8 sont **impossibles à
payer** : Sac sacré 5 et 8 unités d'un seul monde, Grabber 6, Magnet 6.

| Résolution | Effet | Risque |
|---|---|---|
| **R-1 (recommandée)** : une amélioration à un seul niveau par monde, coût = les 3 unités du monde | Choix net par monde : vendre ou améliorer ; aucune source répétée ; aucun risque de ferme | 4 améliorations au maximum, contenu limité |
| R-2 : source renouvelable plafonnée (R2, 1 unité / 10 min) | Permet des niveaux multiples | Compteur persistant requis (nouvelle donnée), contournable par changement de serveur sinon |
| R-3 : R3 (1 unité par victoire) | Simple | Ferme du gardien dès k ≥ 2 (simulation §4) : exclue |

La suite de ce document suppose **R-1**.

## 3. Proposition C — ressources sacrées

Valeurs = hypothèse S2 (k = 2 minutes de revenu à l'accès au site,
`T10_3_SACRED_ECONOMY_SIMULATION.md`). Non définitives.

| Identifiant (existant) | Nom EN / FR | Monde | Rareté | Vente proposée (Coins/unité) | Amélioration possible | Coût proposé | Place dans le sac | Obtention |
|---|---|---|---|---|---|---|---|---|
| `sacred_heartwood_seed` | Heartwood Seed / Graine de Cœur-de-Bois | GreenValley | Sacrée | 198 | Magnet sacré | 3 | 1 / unité | 1re victoire sur le gardien de RootSanctuary, réclamation à la terrasse, une fois par profil |
| `sacred_sun_relic` | Sun Relic / Relique solaire | GoldenDesert | Sacrée | 868 | Grabber sacré | 3 | 1 / unité | Idem, SunTemple |
| `sacred_frost_heart` | Frost Heart / Cœur de givre | FrozenPeaks | Sacrée | 5 840 | Sac sacré | 3 | 1 / unité | Idem, FrostAltar |
| `sacred_astral_essence` | Astral Essence / Essence astrale | MysticWorld | Sacrée | 27 992 | Boussole des sanctuaires | 3 | 1 / unité | Idem, AstralSanctuary |

Noms : ceux des clés `sacred.*` déjà présentes dans `Localization` (FR :
« Graine de Cœur-de-Bois »).

## 4. Proposition D — améliorations spéciales (R-1)

Non autorisées : effet, coût et impact à valider séparément.

| Identifiant proposé | Effet proposé | Coût | Impact estimé | Seuil « améliorer > vendre » |
|---|---|---|---|---|
| `sacred_magnet` | +2 studs de portée de collecte, cumulable avec Magnet | 3 graines (GV) | Confort, revenu ≈ +2 à 4 % (non simulé) | À simuler |
| `sacred_grabber` | −5 % d'intervalle de collecte | 3 reliques (GD) | Revenu ≈ +5 % au plus si la collecte est limitante (non simulé) | À simuler |
| `sacred_backpack` | +10 % de capacité courante | 3 cœurs (FP) | Revenu ≈ +9 % (estimation T10.3, non simulée) | ≈ 51 min (simulation k = 2) |
| `sacred_compass` (exploration) | Signale les ressources Rare/Epic proches du monde courant (affichage seul) | 3 essences (MW) | Aucun effet économique direct | Sans objet |

Seuils R-1 (`lune run tools/simulate_sacred_economy.luau`, gains
**estimés**, joueur régulier) — temps de jeu après lequel l'amélioration
rapporte plus que la vente des 3 unités :

| Amélioration | Gain estimé | k = 1 | k = 2 | k = 4 |
|---|---|---|---|---|
| `sacred_magnet` (GV) | 3 % | 80 min | 2,7 h | 5,4 h |
| `sacred_grabber` (GD) | 5 % | 33 min | 67 min | 2,2 h |
| `sacred_backpack` (FP) | 9 % | 26 min | 51 min | 102 min |
| `sacred_compass` (MW) | 0 % | jamais | jamais | jamais |

Lecture : avec k = 2, Grabber et Sac donnent un vrai dilemme (≈ 1 à
2 sessions) ; le Magnet est faible face à la vente ; la Boussole ne se
justifie que par le confort (la vente MW vaut ≈ 84 000 Coins). Gains non
mesurés : un modèle de collecte complet reste nécessaire avant de fixer les
effets. Anomalie A-3 corrigée (1 place par unité).

## 5. Proposition E — transactions

Les deux opérations reposent sur **une seule** mutation
`PlayerDataService.Update` : copie du profil, contrôle `DataSchema.validate`,
remplacement seulement si tout réussit (comportement actuel). Un refus
renvoie `false` : aucune modification partielle.

Vente (`SacredSell { resourceId, quantity }`) :

1. Limite de fréquence (`RateLimitService`), payload strict (aucun champ en trop).
2. `resourceId` connu de `SacredResourceConfig` ; `quantity` entier 1–3.
3. Proximité d'une zone de vente du monde de la ressource (même contrôle que `SellService`).
4. Dans la mutation : quantité possédée ≥ `quantity`, sinon `INSUFFICIENT_RESOURCES` ; retrait ; crédit = `quantity × valeur serveur` via les règles d'`EconomyService` (`stats.totalCoinsEarned`) ; `stats.totalSales` : **à décider** (recommandé : inchangé, la vente du sac reste seule comptée).
5. Après confirmation : journal de transaction (motif `sacred_sale`), analytics serveur (D-024), sauvegarde « opération importante ».

Amélioration (`SacredUpgrade { upgradeId }`) :

1. Limite de fréquence, payload strict, `upgradeId` connu.
2. Dans la mutation : déjà acquise → `MAX_LEVEL` ; quantité < coût → `INSUFFICIENT_RESOURCES` ; retrait des unités ; pose de l'acquisition (§6).
3. Effet calculé par le serveur à partir du profil (jamais du client) ; miroir HUD seulement.
4. Journal (`sacred_upgrade`), analytics, sauvegarde.

Double demande : la seconde mutation voit l'état déjà modifié (quantité ou
acquisition) et est refusée. Déconnexion : la mutation est synchrone ; la
sortie sauvegarde l'état confirmé ou rien.

## 6. Proposition F — persistance

Vente : **aucune nouvelle donnée** (`inventory.resources`, `currencies.coins`,
`stats` existants).

Améliorations : il faut mémoriser l'acquisition. Avec R-1, une amélioration
n'a qu'un niveau, donc un booléen suffit.

| Option | Structure | Migration | Recommandation |
|---|---|---|---|
| **U-A** | `achievements["sacred_upgrade_<id>"] = true` (v3) | Aucune ; même mécanisme que l'option A (D-035) ; nouveau préfixe réservé | **Recommandée** |
| U-B | `upgrades.sacredMagnetLevel`… | Bornes à ajouter dans `DataSchema` (règle d'intégrité modifiée) | Non : mélange avec la boutique |
| U-C | v4, section `sacred.upgrades` | Migration 3 → 4 et tests | Non : v4 exclue (D-029) |

Audit U-A à refaire avant implémentation : `AchievementService`,
`AchievementRules`, `AnalyticsService`, `ProfileAudit`,
`CollectionService` ignorent les identifiants inconnus d'`AchievementConfig`
(constaté pour `sanctuary_*`, P10) ; ajouter le préfixe au test « préfixes
réservés ». Aucune modification de `DataSchema` ni de version.

## 7. Proposition G — tests

| Test exigé | Couvert aujourd'hui |
|---|---|
| Deux joueurs combattent simultanément | Oui (Lune + Local Server M3) |
| Dégâts indépendants | Oui (Lune + M4) |
| Victoires indépendantes | Oui (Lune + M5) |
| Déblocages indépendants | Oui (Lune, P11) |
| Récompenses indépendantes | Oui (Lune + M12) |
| Reconnexion après déblocage | Lune/Studio oui (P3) ; DataStore réel non |
| Nouvelle défaite après déblocage | Oui (P4) |
| Sac plein (réclamation) | Oui (P14–P14d) |
| Déconnexion pendant transaction (réclamation) | Oui (P9, P15c) |
| Vente de ressources sacrées | **À écrire** |
| Consommation pour amélioration | **À écrire** |
| Double vente / double achat | **À écrire** (même frame, deux serveurs) |
| Ressources insuffisantes | **À écrire** |
| Déconnexion pendant vente ou achat | **À écrire** |

Suite proposée : `SacredTransactionTests` (vente, achat, refus, atomicité
avec écriture en échec, payload falsifié, ressources d'autrui, deux joueurs).

## 8. Décisions attendues

1. ~~Résolution du conflit §2~~ : **R-1 validée** (D-037).
2. Valeurs de vente §3 (S2, k = 2, ou autre k).
3. Effets des améliorations §4 (coût fixé par R-1 : 3 unités du monde).
4. ~~Persistance des améliorations §6~~ : **U-A validée** (D-037).
5. `stats.totalSales` lors d'une vente sacrée.

Aucune intégration avant ces approbations.
