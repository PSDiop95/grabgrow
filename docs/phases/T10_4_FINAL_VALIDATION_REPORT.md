# T10.4 — Validation globale World Enrichment : rapport final

Date : 2026-11-22 — Branche : `t10-3-guardians` (HEAD `981e2d4`).
Statut proposé : **PARTIAL**. En attente de la validation officielle du
propriétaire. Aucune fonctionnalité ajoutée, aucun code modifié, aucun
commit, `GrabAndGrow.rbxl` non touché, aucune publication ni changement de
visibilité.

Addendum T10-D01 à T10-D03 (rappelé par le propriétaire le 2026-11-22, déjà
consigné en D-034) appliqué comme grille de conformité (§3).

## 1. Résumé exécutif

- Code et données : **aucune régression détectée**. 24 suites Lune OK
  (ConfigTests + 496 cas), mêmes résultats au démarrage du Play Studio ;
  LSP strict 0 erreur ; Rojo build OK ; simulateur de progression
  inchangé (ses entrées `ResourceConfig`, `UpgradeConfig`, `WorldConfig`,
  `DataSchema` n'ont pas changé depuis T9, `e1d4d94`).
- Contenu : 20/20 ressources en modèle Polyfork, 20 identifiants d'origine,
  valeurs et raretés inchangées ; VFX communs ; 4 gardiens et 4 sites
  présents et conformes au budget (48–60 pièces, tout ancré, 0 lumière,
  0 émetteur).
- Sécurité : sondes client relancées en Studio, toutes refusées côté
  serveur (§6).
- Multijoueur réel : session Local Server à 2 joueurs exécutée (§5) ;
  8 des 10 scénarios du prompt et 12 des 14 points M1–M14 OK, aucun KO.
  NOT TESTED en réel : arrivée pendant un combat, déconnexion en combat
  (M8), reconnexion (M10).
- Non réalisé : **mesures Galaxy A23** et mobile, captures, DataStore réel,
  **vente et consommation des ressources sacrées** (T10-D03 : non conçues,
  aucune valeur validée). D'où PARTIAL.

## 2. Fichiers

Créés : `docs/phases/T10_4_FINAL_VALIDATION_REPORT.md`.

Modifiés (documentation seulement) : `CLAUDE.md`, `docs/PROJECT_STATUS.md`,
`docs/ROADMAP.md`, `docs/assets/ASSET_MANIFEST.md`,
`docs/tests/TEST_STRATEGY.md`, `docs/tests/T10_3_TEST_PLAN.md`, `docs/decisions/TECHNICAL_DECISIONS.md`
(D-034 corrigée, D-036 ajoutée), `docs/gameplay/T10_GUARDIANS_DESIGN.md`,
`docs/phases/T10_3_SACRED_ECONOMY_SIMULATION.md`.

Aucun fichier `src/`, `tools/`, place ou asset modifié.

## 3. Conformité à l'addendum T10-D01 à T10-D03

| Règle | État | Preuve |
|---|---|---|
| D01 déblocage individuel et persistant | Conforme | `achievements["sanctuary_<siteId>"]` (option A, v3, D-035) ; `GuardianPersistenceTests` |
| D01 maintenu après reconnexion | Conforme en Lune et Studio (MemoryDataStore) ; **NOT TESTED** sur DataStore réel | P1–P15 |
| D01 jamais retiré par une défaite | Conforme | `GuardianTests` « nouvelle défaite après déblocage » |
| D01 réapparition et retour sans redéblocage | Conforme | réapparition 45 s par joueur ; accès prioritaire si victoire |
| D02 état, PV, dégâts, victoire, déblocage, récompense par joueur | Conforme | `GuardianCombatService` (un état par `UserId`) ; tests 2 et 4 joueurs (Lune) |
| D02 pas de copie physique par joueur | Conforme | 1 modèle statique par site, animé localement |
| D02 aucun PvP, Kill & Loot, perte de sac | Conforme | touche = étourdissement 1,5 s ; sac et Coins intacts |
| D03 une ressource sacrée par monde | Conforme | `SacredResourceConfig` (4 identifiants) |
| D03 vente contre Coins | **Non implémentée** | aucune valeur validée (interdit de la fixer) |
| D03 consommation pour améliorations | **Non implémentée** | coûts proposés, non validés |
| D03 vente/consommation atomiques, anti-double | **NOT TESTED** (inexistant) | conception §8 du rapport T10.3 |
| §2 aucune modification de `DataSchema` sans autorisation | Conforme | `DataSchema.lua` inchangé depuis T9 ; option A autorisée |
| §3 pas de victoire ni récompense d'autrui ou de proximité | Conforme | tests « joueur non participant », « éclat d'un autre joueur » |
| §3 pas de consommation des ressources d'autrui | Sans objet | consommation non implémentée |
| §3 unités sacrées conservées jusqu'à vente/consommation | Conforme | identifiants hors `ResourceConfig` : jamais vendus ni supprimés (`SaleValue`, `SellService`, D-008) |

## 4. Audit fonctionnel

| Élément | Résultat | Méthode |
|---|---|---|
| 20 ressources visuelles | OK : 20 gabarits `ServerStorage.ResourceTemplates` (1 à 7 pièces) | Studio Edit |
| 20 identifiants d'origine | OK : inchangés (`ResourceConfig` non modifié depuis T9) | Git |
| Valeurs et raretés | OK : inchangées (Bible 1.1) | Git + `ConfigTests` |
| Règles de collecte | OK : `CollectionServiceTests` 27 cas ; 160 nœuds au démarrage | Lune + Play |
| VFX | OK (logique) : `ResourceFxTests` 18 cas ; 14 émetteurs dans Workspace, 0 actif à l'arrêt | Lune + Play |
| 4 gardiens | OK : présents, `GuardianTests` 26 cas | Studio + Lune |
| 4 sites sacrés | OK : 57 / 48 / 53 / 60 pièces, 0 non ancrée | Studio Edit |
| Ressources spéciales | Récompense (3 unités, réclamation) OK ; vente et consommation absentes | Lune |
| Récompenses | OK : une fois par site, `ALREADY_CLAIMED` | Lune + Studio (T10.3) |
| Sauvegardes | OK en MemoryDataStore ; DataStore réel NOT TESTED | Lune + Studio |
| Déplacements entre mondes | OK : `WorldTravelServiceTests` 25 cas, `TravelRulesTests` 8 | Lune |

## 5. Tests multijoueur

Session Local Server à 2 joueurs (2026-11-22), lancée par le propriétaire,
pilotée par MCP (un harnais client : déplacements par `Humanoid:MoveTo`,
envois de remotes, lecture de `GuardianEvent` et `ActionResult` ; Output
du serveur). Mémoire Studio (MemoryDataStore). Site : Sanctuaire des
racines. Player1 et Player2 en `J_full`, sauf Player2 nouveau profil en M1.

| # | Scénario | Résultat |
|---|---|---|
| 1 | Collecte simultanée d'une même ressource | **OK (réel)** : `green_leaf_014`, envois à 4 ms d'écart (heure serveur) ; une réussite (Player2), un refus `RESOURCE_UNAVAILABLE` (Player1) |
| 2 | Combats simultanés | **OK (réel)** : c1/c2 puis c4/c5 en parallèle, PV séparés (M3, M4) |
| 3 | Combat coopératif | **Sans objet** : exclu par T10-D02 (combats individuels) |
| 4 | Joueur arrivant pendant un combat | Lune : OK. Réel : **NOT TESTED** (Local Server arrêté avant l'ajout d'un joueur). Approché par M2 (joueur entré dans l'arène avant l'activation d'autrui) |
| 5 | Déconnexion pendant un combat (M8) | Lune : OK. Réel : **NOT TESTED** (session arrêtée pendant le combat c6 de Player1, Output non relu) |
| 6 | Mort d'un joueur | **OK (réel)** : chute de Player2 pendant son combat c2 → `ended reason=no_character`, aucune victoire |
| 7 | Récompenses individuelles | **OK (réel)** : victoires et réclamation propres à chaque joueur (M5, M12) |
| 8 | Tentative de duplication | **OK (réel)** : 2e réclamation `ALREADY_CLAIMED` ; 2e victoire de Player1 `first=false` ; une seule ligne `SacredReward` |
| 9 | Falsification des dégâts | **OK** : Studio solo (`damage`, argument en trop → `INVALID_TARGET`) ; réel : éclats de Player1 envoyés par Player2 → `INVALID_TARGET`, PV de Player2 intacts |
| 10 | Accès à un site non autorisé | **OK (réel)** : Player2 nouveau profil → `REQUIREMENT_NOT_MET` ; Studio solo : `WORLD_LOCKED` |

Plan M1–M14 (`docs/tests/T10_3_TEST_PLAN.md`) :

| # | Résultat |
|---|---|
| M1 Accès séparé | **OK** : Player2 `REQUIREMENT_NOT_MET` |
| M2 Observateur | **OK** : Player2 dans l'arène pendant le combat c1 de Player1 : aucun événement de combat, 0 touche, aucune barre de vie |
| M3 Deux combats au même site | **OK** : c1 (P1) et c2 (P2) ; éclats sh12/sh13 de P1 refusés à P2 |
| M4 Dégâts indépendants | **OK** : P1 19/24, P2 24/24 au même instant |
| M5 Victoires simultanées | **OK** : `user=-1 combat=c5 first=false` et `user=-2 combat=c4 first=true`, 12 s d'écart |
| M6 Victoire de l'un, combat de l'autre | **OK** : gardien masqué (`LocalTransparencyModifier = 1`) chez P1 seulement ; P2 en combat, 0 événement de victoire |
| M7 Réapparition personnelle | **OK** : P1 `GUARDIAN_RESPAWNING` |
| M8 Déconnexion en combat | **NOT TESTED** (réel) ; Lune OK |
| M9 Déconnexion juste après la victoire | **OK** : Player2 exclu dans la même frame que sa ligne `GuardianReward` ; une seule ligne, `sauvegarde (sortie) OK, verrou libéré`, aucune erreur |
| M10 Reconnexion | **NOT TESTED** (réel) : un joueur ajouté en Local Server reçoit un nouvel identifiant ; couvert en Lune et Studio (MemoryDataStore) |
| M11 Sortie d'arène | **OK** : `ended reason=left_arena` ≈ 20 s après la sortie, aucune victoire |
| M12 Ressource sacrée | **OK** (comportement D-035, remplace l'attendu « bientôt disponible » du plan) : P1 +3 `sacred_heartwood_seed`, puis `ALREADY_CLAIMED` ; P2 sans victoire `REQUIREMENT_NOT_MET` |
| M13 Collecte pendant le combat d'autrui | **OK** : P1 collecte `wild_fruit_001` (`SUCCESS`) pendant le combat de P2 |
| M14 Output | **OK** : aucune erreur `[Guardian]`, `[SacredSites]`, `[PlayerData]` ; sauvegardes `guardian_victory`, `sacred_reward`, `sortie` OK |

Observations :

- Téléportation client (`PivotTo` vers l'autel) : `movement_anomaly` puis
  `movement_correction`, personnage ramené ; autel refusé `TOO_FAR`.
  Anti-triche confirmé en réel.
- Lignes `[Security] unknown_id action=GuardianStrike` nombreuses : causées
  par le harnais (renvoi d'éclats déjà pris), refus attendus.
- Touches et étourdissements observés (`STUNNED`) : 4, 5 et 2 touches selon
  les combats ; durées de victoire 49 à 127 s (harnais non optimal).
- Non observé : HUD, lisibilité, recul visuel (aucune capture, contrôle
  logique seulement).

## 6. Sondes de sécurité (Studio, Play, client MCP, 2026-11-22)

Nouveau profil (mémoire), Green Valley, loin des sites :

| Envoi client | Réponse serveur |
|---|---|
| `Activate {RootSanctuary}` | `REQUIREMENT_NOT_MET` |
| `Activate {AstralSanctuary}` | `WORLD_LOCKED` |
| `Activate {NopeSite}` | `INVALID_TARGET` (`unknown_id`) |
| `Activate {…, victory = true}` | refusé (`rate_limited` puis `invalid_payload extra_field`) |
| `Strike {shardId, damage = 999}` | `INVALID_TARGET` |
| `Strike {shardId}, "extra"` | `INVALID_TARGET` (`extra_field`) |
| `SacredCollect {nodeId, amount = 99}` | `INVALID_TARGET` |
| `SacredCollect {nodeId}` sans victoire | `REQUIREMENT_NOT_MET` |

Chaque refus est journalisé par `SecurityLog`. Aucun Coin, inventaire ni
succès modifié.

## 7. Performance

| Mesure | Avant (T9) | Après (T10, Studio PC) | Galaxy A23 |
|---|---|---|---|
| FPS / temps de frame | non mesuré | non significatif : 67 ms moyen, Studio en arrière-plan (rendu bridé) | **NOT TESTED** |
| Draw calls | non mesuré | **NOT TESTED** (MicroProfiler non lancé) | **NOT TESTED** |
| Triangles | — | ressources 648–733 tris par asset source (manifeste) | **NOT TESTED** |
| Mémoire | non mesuré | client 456 Mo, serveur 527 Mo (Studio, valeurs d'éditeur, non comparables à un appareil) | **NOT TESTED** |
| Particules actives | — | 14 émetteurs, 0 actif hors interaction (pools) | **NOT TESTED** |
| Temps CPU scripts | non mesuré | Heartbeat serveur 0,23 ms | **NOT TESTED** |
| Modèles chargés | — | 160 nœuds ; 3 076 BaseParts client dont 221 MeshParts ; 61 969 instances | **NOT TESTED** |

Aucune base de référence chiffrée n'existe avant T10
(`performance/T10_1_BASELINE_A23.md` jamais rempli). La comparaison
avant/après est donc **impossible** en l'état. Seul test réel connu :
iPhone 12 Pro sur le prototype T10.1 (D-031). **Performance mobile non
validée.**

## 8. Tests automatisés

| Test | Résultat |
|---|---|
| `lune run tools/run_tests.luau` | **OK**, code 0 : 24 suites, ConfigTests + 496 cas |
| Tests au démarrage du Play Studio | **OK** (mêmes suites, `TOUS LES TESTS : OK`) |
| `luau-lsp analyze` strict (sourcemap temporaire) | **OK**, code 0 |
| `rojo build` (fichier temporaire) | **OK** |
| `tools/simulate_progression.luau` | OK, entrées inchangées depuis T9 |
| `tools/simulate_sacred_economy.luau` | OK (voir anomalie A-3) |
| Collecte, vente, économie, progression, persistance, sécurité, 4 mondes | OK (suites correspondantes) |
| Place de test = dépôt | OK : sources Studio identiques au dépôt (hors fins de ligne) |

## 9. Assets et licences

20 meshes Polyfork (une ligne par ressource dans `ASSET_MANIFEST.md`),
tous **CC BY 4.0**, fiche vérifiée le 2026-11-22, attribution « modifié »
renseignée. Gardiens et sites : primitives Roblox, aucun asset tiers.
**Crédits non affichés** en jeu ni dans la description : obligatoires
(CC BY) avant toute publication publique.

## 10. Anomalies restantes

| # | Gravité | Anomalie |
|---|---|---|
| A-1 | Bloquant pour clôture | T10-D03 : vente et consommation des ressources sacrées non conçues ni implémentées (valeurs non validées) |
| A-2 | Bloquant pour clôture | Mobile et latence (L1–L7), Galaxy A23 : non exécutés. Multijoueur réel : fait, sauf arrivée en combat, M8 et M10 |
| A-3 | Mineure (doc/outil) | `simulate_sacred_economy.luau` suppose 5 places par unité ; D-035 en fixe 1. Résultats de la section « place dans le sac » obsolètes. Non corrigé (aucune modification d'outil dans ce lot) |
| A-4 | Avant publication | Crédits CC BY 4.0 absents |
| A-5 | Moyenne | Sites et gabarits présents seulement dans le place de test non sauvegardé ; `build_sacred_sites.luau` les reconstruit |
| A-6 | Faible | Deux joueurs au même site voient chacun le gardien tourné vers eux (accepté, D-034) |
| A-7 | Faible | Poussée appliquée par le client : à vérifier avec latence mobile |
| A-8 | Info | Avertissement d'asset d'avatar 203785492, préexistant et étranger au projet |

## 11. Critères de clôture

| Critère | État |
|---|---|
| 20 ressources intégrées | OK |
| VFX fonctionnels et optimisés | Fonctionnels (Lune, Studio) ; optimisation mobile **NOT TESTED** |
| 4 gardiens opérationnels | OK (Lune ; combat complet en Studio pour Forest seulement) |
| 4 sites sacrés fonctionnels | OK (présence, accès, réclamation en Lune ; Studio : Root) |
| Combats sécurisés côté serveur | OK |
| Récompenses non duplicables | OK |
| Données existantes préservées | OK (v3 inchangé, P10) ; DataStore réel NOT TESTED |
| Tests automatisés | OK |
| Tests multijoueur requis | **Largement réalisés** (Local Server, 2 joueurs) ; arrivée en combat, M8, M10 NOT TESTED en réel (Lune OK) |
| Performances sur appareil de référence | **NOT TESTED** |
| Risques résiduels documentés | OK (§10) |

**Statut proposé : PARTIAL.**

## 12. État Git

Branche `t10-3-guardians`, HEAD `981e2d4` (T10.3) ; T10.0 à T10.3 commitées
sur cette branche, non fusionnées dans `main`. Modifications locales : les
seuls documents listés au §2, non commitées.

## 13. Prochaine étape

1. Exécuter L1–L7 sur Galaxy A23 (remplir
   `performance/T10_1_BASELINE_A23.md`) ; si souhaité, compléter en Local
   Server : joueur ajouté pendant un combat, M8.
2. Décider des valeurs et coûts sacrés (T10-D03), puis lot dédié vente et
   consommation atomiques.
3. Puis validation officielle de T10.
