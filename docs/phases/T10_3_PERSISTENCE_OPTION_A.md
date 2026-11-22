# T10.3 — Persistance : victoires et récompense sacrée (option A, schéma v3)

Date : 2026-11-22 — Statut : **IMPLÉMENTÉE** (autorisation du
propriétaire le 2026-11-22) ; tests P1 à P15 écrits et exécutés (Lune et
Studio : OK). Option A, v3, aucune migration v4 (D-029, D-035).

## 1. Principe

Deux clés par site dans la section existante `achievements`, valeur `true`
seulement, jamais retirées :

```text
achievements["sanctuary_<siteId>"]        = true  -- victoire : accès permanent (T10-D01)
achievements["sanctuary_reward_<siteId>"] = true  -- récompense de 3 unités réclamée (D-035)
```

Les unités réclamées vont dans la section existante `inventory.resources`
sous leur identifiant sacré (`sacred_heartwood_seed`, …). `DataSchema`
conserve déjà les identifiants inconnus de `ResourceConfig` ; `SellService`
ne les vend jamais (D-012, D-014) : elles restent dans le sac jusqu'à une
vente ou une consommation dédiées (lot ultérieur).

- Longueur maximale : `sanctuary_reward_AstralSanctuary` = 32 caractères (limite 64).
- `schemaVersion` inchangé (3), aucune migration, aucune section nouvelle.
- États par site : aucune clé (jamais gagné) ; victoire seule (récompense due) ; victoire + récompense (réclamée). Récompense sans victoire : impossible par construction (§3).

## 2. Audit de compatibilité (code actuel)

| Composant | Comportement avec une clé `sanctuary_*` | Risque |
|---|---|---|
| `DataSchema.validate` | Accepte toute clé texte ≤ 64 de valeur `true` ; clés inconnues conservées (commentaire v2, D-008) | Aucun |
| Migrations v1 → v2 → v3 | Ne touchent pas une section `achievements` existante (test « section déjà présente conservée ») | Aucun |
| `AchievementRules.pending` / `ids` | Parcourent `AchievementConfig` uniquement : clé ignorée | Aucun |
| `AchievementService.Evaluate` | N'écrit que des identifiants de `AchievementConfig` | Aucun |
| `AnalyticsService.AchievementGranted` | Appelé sur les succès attribués seulement | Aucun |
| `ProfileAudit` | Ne lit pas `achievements` ; compte les unités sacrées dans `used` | Aucun (3 unités, voir synthèse §3) |
| `SellService` | Ne vend pas les identifiants inconnus de `ResourceConfig` | Aucun : c'est le comportement voulu |
| `CollectionJournalRules` | Ne compte que `ResourceConfig` | Aucun : Journal à 20/20 |
| `AchievementController` (client) | Ne reçoit que les `ActionResult` de succès | Aucun |
| Ancienne version du serveur (retour arrière) | Conserve et ignore les clés et les unités | Aucun |
| Futur affichage « n succès sur N » | Compterait les clés `sanctuary_*` si on comptait la table brute | Faible : compter via `AchievementConfig` (déjà la règle) |

Limites de l'option A : booléens seulement (pas de date ni de compteur).
Suffisant pour R1 (récompense unique) ; R2 et R3 sont écartés.

## 3. Implémentation proposée (après autorisation)

1. `GuardianRules.victoryKey(siteId)` → `"sanctuary_" .. siteId` ; `rewardKey(siteId)` → `"sanctuary_reward_" .. siteId`.
2. Contrôle de configuration : aucun identifiant de `AchievementConfig` ne commence par `sanctuary_` ; aucun `siteId` ne commence par `reward_`.
3. Victoire — `SacredSiteService` reçoit un `VictoryStore` persistant (interface existante) :
   - `Has` : clé de victoire dans le profil **ou** victoire de session ;
   - `Record` : `playerData.Update` qui pose la clé si absente, puis `RequestSave(userId, "guardian_victory")` ;
   - profil non chargé ou `Update` en échec : victoire gardée en session, `warn`, nouvelle écriture à la victoire suivante ou à la réclamation.
4. Réclamation — `SacredResourceService.HandleCollect` (Remote existant `RequestSacredCollect {nodeId}`, l'un des 3 nœuds de la terrasse) :
   1. limite de fréquence → profil chargé → payload → nœud connu → victoire (`Has`) → distance → `MovementValidator` ;
   2. **une seule** mutation `playerData.Update`, sans attente :
      - clé de récompense présente → refus `ALREADY_CLAIMED` (code à ajouter), rien modifié ;
      - places libres < 3 → refus `INVENTORY_FULL`, rien modifié, **droit conservé** ;
      - sinon : `inventory.resources[sacredId] += 3`, clé de récompense posée, clé de victoire posée si absente ;
   3. succès : `RequestSave(userId, "sacred_reward")`, message au seul joueur, vue `sites` mise à jour.

   Atomicité : `Update` applique tout ou rien et ne suspend pas le fil ; deux demandes sont traitées l'une après l'autre, la seconde voit la clé et reçoit `ALREADY_CLAIMED`.
5. Affichage : l'autel et la terrasse indiquent « récompense à réclamer » tant que la clé de récompense est absente.
6. `Bootstrap` : branche le magasin persistant et la réclamation. Aucun autre service modifié.

Écritures : au plus 1 `Update` par première victoire et 1 par réclamation
réussie, par site (8 au maximum par profil).

## 4. Tests P1 à P15 (spécifications, non écrites)

Statut : **écrits et exécutés le 2026-11-22 : 23 cas OK** (Lune et Studio).
Fichier `Tests/GuardianPersistenceTests.lua` (Lune et Studio via `RunTests`).
Outils existants : `MemoryDataStore` (`seed`, `peek`, `failNext`,
`setAlwaysFail`, `getWriteCount`), `newServer`, `existingProfile`,
`deepEqual` (`PlayerDataServiceTests`), environnement de combat de
`GuardianTests` (`winFight`, `atAltar`, `advance`). Profils construits dans
le test, aucune donnée de production. Notation : `V(s)` = clé de victoire,
`R(s)` = clé de récompense, `Q(id)` = `inventory.resources[id]`.

### Victoire et accès

| # | Préparation | Action | Vérifications |
|---|---|---|---|
| P1 | Nouveau profil chargé, store vide | `winFight(Root)` | `V(Root)` = true ; `R(Root)` absent ; `Q(heartwood)` absent ; 1 seul `RequestSave("guardian_victory")` ; vue : `Root = unlocked`, récompense due ; aucune autre clé modifiée |
| P2 | Après P1 | 2e victoire après réapparition | Aucune écriture, aucune sauvegarde ; journal `first=false` ; aucune unité |
| P3 | Après P1, sortie et sauvegarde | Nouveau `newServer`, même store, chargement | `Root = unlocked` sans combat ; récompense toujours due ; activation acceptée |
| P4 | Après P1 | Défaite ou abandon (`left_arena`, `no_character`, `player_left`) | `V(Root)` conservé ; accès conservé ; aucune écriture |

### Préservation des données

| # | Préparation | Action | Vérifications |
|---|---|---|---|
| P5 | `seed` profil v1, puis v2 avec `collect_100 = true`, `V(Sun)`, `R(Sun)` et `Q(sun_relic) = 3` | Chargement (migrations jusqu'à v3) | `schemaVersion` = 3 ; les 4 valeurs conservées ; entrée stockée intacte avant sauvegarde |
| P6 | Profils v3 `J_full` et `J_partial` sérialisés | Victoire, réclamation, sauvegarde, rechargement | Profil rechargé = profil initial + `V(Root)`, `R(Root)`, `Q(heartwood) = 3` uniquement ; Journal 20/20 inchangé ; succès et Coins inchangés |
| P7 | `seed` avec `V(Root) = false`, puis `R(Root) = 1` ; puis `Q(heartwood) = -3` | Chargement | Clés invalides : validation refusée, store non écrasé (`peek` identique), aucune action sans profil. Quantité négative : **réparée à 0** au chargement (règle existante du schéma pour toutes les quantités), entrée stockée intacte, réclamation normale ensuite |
| P8 | Profil non chargé ; puis `Update` forcé en échec | Victoire | Rien écrit ; victoire de session ; `warn` ; écriture à la tentative suivante |
| P9 | `failNext(2)`, puis `setAlwaysFail(true)` | Victoire, réclamation, sortie | Reprises normales ; clés et unités présentes en mémoire ; sauvegarde existante non écrasée en cas d'échec total |
| P10 | Profil avec `V` et `R` des 4 sites et 12 unités | `AchievementService.Evaluate`, `ProfileAudit` | Aucun succès, Coin ni appel analytics ; aucun constat d'audit |
| P11 | Deux joueurs | Victoires et réclamations dans le même `Tick` | Chaque profil : ses clés et ses 3 unités seulement ; 2 sauvegardes distinctes |
| P12 | Site inconnu, nœud inconnu, `guardianId` incohérent | `RecordVictory`, réclamation | Aucune écriture ; refus journalisé |

### Réclamation de la récompense

| # | Préparation | Action | Vérifications |
|---|---|---|---|
| P13 | Victoire Root, sac avec ≥ 3 places | Réclamation sur un nœud de la terrasse | Une mutation : `Q(heartwood)` = 3, `R(Root)` = true ; `RequestSave("sacred_reward")` ; message au seul joueur ; vue : récompense réclamée. Nouvelle réclamation : `ALREADY_CLAIMED`, rien modifié |
| P13b | Joueur sans victoire, à côté d'un vainqueur | Réclamation | `REQUIREMENT_NOT_MET` ; aucune unité ; la réclamation de l'un n'agit jamais sur le profil de l'autre |
| P13c | Victoire de session seule (écriture de victoire en échec, P8) | Réclamation | `V(Root)` et `R(Root)` posées ensemble avec 3 unités ; jamais `R` sans `V` |
| P14 | Victoire ; sac à 0, 1 et 2 places libres | Réclamation | `INVENTORY_FULL` ; profil identique (`deepEqual`) ; `R(Root)` absent ; vue : récompense toujours due |
| P14b | Après P14 (2 places), le joueur vend son sac | Nouvelle réclamation | Succès comme P13 (réclamation différée) |
| P14c | Après P14, sortie, nouveau serveur, sac vidé | Réclamation | Succès : le droit survit à la reconnexion et au changement de serveur |
| P14d | Sac à exactement 3 places libres | Réclamation | Succès ; sac plein ensuite ; aucun dépassement (`used` = `capacity`) |
| P15 | Victoire, sac libre | 2 demandes dans la même frame (deux nœuds) | 1 succès + 1 `ALREADY_CLAIMED` (ou `RATE_LIMITED`) ; `Q(heartwood)` = 3 exactement ; 1 seule sauvegarde |
| P15b | Réclamation réussie et sauvegardée sur un 1er serveur | Chargement sur un 2e serveur, nouvelle réclamation | `R(Root)` présent ; `ALREADY_CLAIMED` ; jamais 6 unités |
| P15c | Réclamation réussie, sauvegarde en échec total, sortie | Rechargement de l'ancienne sauvegarde, nouvelle réclamation | État cohérent : soit `R` et 3 unités, soit ni l'un ni l'autre ; une seule attribution visible dans le profil chargé |
| P15d | Payload falsifié : `amount`, `resourceId`, argument en trop | Réclamation | `invalid_payload` ; quantité toujours 3, fixée par le serveur |

Contrôles de configuration associés : préfixes réservés (§3, point 2) ;
définitions sacrées hors `ResourceConfig` ; Journal toujours à 20
ressources.

Tests manuels Studio (Play, DataStore de Studio, profil de test) : P1, P3,
P13, P14, P14b, P14c. Les cas multijoueurs réels restent M1 à M14
(`docs/tests/T10_3_TEST_PLAN.md`).

## 5. À autoriser

- [x] Option A comme solution cible (2026-11-22).
- [x] Récompense, sac, rareté, configuration dédiée, réclamation (D-035).
- [x] Implémentation (§3), dont le code `ALREADY_CLAIMED` (2026-11-22).
- [x] Spécifications P1 à P15 validées (2026-11-22).
- [x] Écriture et exécution des tests P1 à P15 (2026-11-22, OK).
- [x] Mise à jour de `docs/DATA_PERSISTENCE.md`.
