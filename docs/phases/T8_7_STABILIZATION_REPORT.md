# T8.7 — Stabilisation et validation globale

Date : 2026-11-16. Statut : **VALIDÉ** par le propriétaire le 2026-11-16 (proposé : PASS sous réserve) (étape B
réalisée : automatisés, Studio solo, Local Server à 2 joueurs, DataStore de
test). Réserves : contrôle visuel mobile et performance non mesurés ;
reconnexion d'un client réel couverte au niveau service seulement.

## A. Résumé

- **État initial :** T8.0 à T8.6 validées par le propriétaire (D-021,
  D-022, schéma v3). `main` propre, dernier commit c4e0209.
- **Travaux :** audit A à H sans modification (étape A, validée le
  2026-11-16) ; correction P2-02 autorisée (D-023) ; corrections
  documentaires ; campagne automatisée et Studio solo par MCP.
- **État final :** aucun défaut P0 ou P1 ouvert. Une correction de code
  (sauvegarde après achat et déblocage). Tests Studio multijoueur,
  reconnexion et DataStore de test : NOT TESTED.

## B. Audit (étape A)

| Domaine | Résultat |
|---|---|
| A. Architecture | Remotes centralisés (5 demandes client, 2 événements serveur) ; aucune logique économique autoritaire côté client ; tests et préréglages limités à Studio ; aucun script obsolète. Les 82 scripts de Studio ont la même empreinte que le dépôt (synchronisation Rojo). |
| B. Quatre mondes | 4 × 40 nœuds, répartition conforme à la Bible 1.1 (GV 16/12/8/3/1 ; mondes 2 à 4 16/12/7/4/1) ; 20 ressources, valeurs, poids et réapparitions conformes ; 0 point invalide ou en double ; 4 zones de vente ; 4 points d'arrivée ; 3 portails aller, 3 retour ; une seule SpawnLocation (hub GV). |
| C. Collecte | Contrôles serveur ordonnés (fréquence, profil, payload, nœud, monde débloqué, actif, position finie, distance, déplacements, trajet, cadence) ; ajout et découverte dans une mutation ; pas de double attribution. |
| D. Vente, économie | Vente en une transaction ; achats et déblocages vérifiés et débités dans une mutation ; coûts conformes. Achats x10, x100, MAX absents (achat d'un niveau). |
| E. Persistance v3 | Migration v2 -> v3 idempotente, sections conservées ; section illisible -> CorruptData sans réécriture ; copie `Recovery_` ; verrou par chargement ; sauvegardes sortie, arrêt, 60 s ; journal client filtré en lecture seule. |
| F. Sécurité | PayloadValidator (champ unique, caractères, longueur, arguments supplémentaires) ; NaN et infini refusés ; voyage décidé par le serveur avec grâce ; aucun kick ajouté. |
| G. Interface | `ResetOnSpawn = false` partout ; raccourcis cohérents ; vente et portail partagent F / ButtonY mais sont à 40 studs ou plus. |
| H. Performance | 2 265 Parts (Edit), aucune lumière, `GlobalShadows` désactivé, `StreamingEnabled` désactivé ; une boucle Heartbeat client limitée en fréquence ; boucle serveur 4 Hz. Aucune mesure sur appareil. |

## C. Anomalies et corrections

| ID | Priorité | Constat | Statut |
|---|---|---|---|
| P2-02 | P2 | `CLAUDE.md` §8 (« sauvegarder après les opérations importantes ») contredit par l'implémentation (sortie, arrêt, 60 s seulement) : jusqu'à 60 s de progression perdue en cas de plantage, déblocage compris. | **Corrigé** (D-023) |
| P3-01 | P3 | Analyse LSP en échec (7 « Unknown require ») avec le `sourcemap.json` local du 13/11. Cause : étape de régénération déjà prévue par `TEST_STRATEGY.md` mais non exécutée lors de l'audit. Pas de défaut du dépôt (fichier ignoré par Git). | Fichier local régénéré ; aucune modification de procédure |
| P3-02 | P3 | `ROADMAP.md` contradictoire (T8.7 « soumise à validation » / « En attente »). | **Corrigé** |
| P3-03 | P3 | La Bible 1.1 est dans `GRAB_AND_GROW_ECONOMY_v1.0.md` ; aucun fichier `…_v1.1.md`. | Documenté, fichier non renommé (références existantes) |
| P3-04 | P3 | Les zones de vente ne dépendent pas du monde débloqué. Non exploitable : prix indépendant de la zone, accès aux îles par voyage serveur. | Documenté, sans correction |
| P3-05 | P3 | Hypothèse : la boucle de déplacements pourrait recréer l'état d'un joueur pendant `PlayerRemoving` (table négligeable). | Non reproduit, NOT TESTED, sans correction |
| P3-06 | P3 | `TEST_STRATEGY.md` : résultat Lune attendu figé à T4. | **Corrigé** (sortie T8.7) |
| P3-07 | P3 | Voyage limité à 2 demandes puis 1 toutes les 5 s (`TravelSecurityConfig`) : un joueur qui enchaîne trois voyages en moins de 5 s reçoit RATE_LIMITED. Comportement conforme à la configuration. | Documenté ; réglage à revoir sur retours de test |

### Correction P2-02 (D-023)

- **Problème :** perte possible d'un achat ou d'un déblocage (jusqu'à
  250 000 Coins) si le serveur s'arrête brutalement avant l'autosauvegarde.
- **Cause :** aucune sauvegarde déclenchée par les opérations économiques
  importantes.
- **Fichiers :** `Services/PlayerDataService.lua` (`RequestSave`),
  `Shared/Config/DataConfig.lua` (`Save.importantSaveDelaySeconds = 5`),
  `Bootstrap.server.lua` (appel après achat et déblocage réussis).
- **Correction :** sauvegarde différée de 5 s ; demandes regroupées ;
  rien si le joueur est parti (sauvegarde de sortie) ; échec : données
  conservées en mémoire.
- **Non-régression :** 5 nouveaux cas `PlayerDataServiceTests` (35 -> 40) ;
  Studio : `sauvegarde (amélioration) OK` et `sauvegarde (déblocage de
  monde) OK` environ 5 s après l'opération (magasin en mémoire).

## D. Tests

| Test | Résultat | Preuve |
|---|---|---|
| Lune | PASS | 20 suites, 401 cas, `TOUS LES TESTS : OK`, code 0 (avant correction : 396) |
| LSP strict | PASS | `luau-lsp analyze` après `rojo sourcemap`, code 0, aucune erreur |
| Rojo build | PASS | `Built project`, code 0 (sortie hors dépôt) |
| Simulation | PASS | Sortie identique avant et après correction ; régulier : GD 74 min, FP 5,3 h, MW 9,8 h, Backpack 16 13,3 h (projection T8 : ≈ 1,5 h, 5,6 h, 10 h, 13,5 h) |
| Suites dans Studio (Play) | PASS | 20 suites OK au démarrage |
| Studio solo | PASS (partiel) | Voir matrice ; reconnexion NOT TESTED (magasin en mémoire) |
| Studio multijoueur | PASS (partiel) | Local Server à 2 joueurs : 11 scénarios PASS, reconnexion NOT TESTED |
| DataStore test | PASS | 12 cas sur `GrabAndGrow_PlayerData_v1_Studio` (création v3, D-023, reconnexion, migration v2, verrou, interruption, pannes) |
| Quatre mondes | PASS (solo) | Déblocage, voyage, collecte, vente locale et retour dans chaque monde |
| Interface (visuel, mobile) | NOT TESTED | Non vérifiée à l'écran dans cette phase |

### Matrice Studio solo (2026-11-16, MCP, requêtes client réelles)

| # | Scénario | Résultat |
|---|---|---|
| 1 | Connexion | PASS — profil v3 créé (magasin en mémoire) |
| 2 | Apparition GV | PASS — (0, 4, 0), hub |
| 3 | Collecte (12, marche) | PASS — 12 SUCCESS, `firstDiscovery` uniquement à la première |
| 4 | Vente | PASS — +12 Coins, sac 12 -> 0 ; seconde vente NOTHING_TO_SELL ; journal conservé |
| 5 | Achat | PASS — Backpack 1 -> 2 (-75), capacité 75 ; second achat INSUFFICIENT_FUNDS ; sauvegarde (amélioration) OK |
| 6 | Déblocages | PASS — GD -1 500 (+1 000 succès world_2), FP -35 000, MW -250 000 ; ALREADY_UNLOCKED ; sauvegarde (déblocage) OK |
| 7 | Voyages | PASS — arrivées (3000, 6), (-3000, 6), (0, 2944) ; retour (0, 12) |
| 8 | Collecte et vente par monde | PASS — sandstone, ice_shard, mystic_dust (découvertes) ; ventes 5, 18, 68 |
| 9 | Grâce après voyage | PASS — nœud à 19 studs de l'arrivée : TOO_FAR ; nœud GV depuis GD : TOO_FAR |
| 10 | Voyages répétés (12) | PASS — aucune anomalie ni correction de mouvement ; rafale : RATE_LIMITED puis silence |
| 11 | Journal | PASS (état) — green_leaf, sandstone, ice_shard, mystic_dust ; affichage non vérifié à l'écran |
| 12 | Refus | PASS — id inconnu, argument ou champ supplémentaire, journal falsifié, type : INVALID_TARGET ; trop loin : TOO_FAR ; monde verrouillé : WORLD_LOCKED (collecte et voyage) ; prérequis : REQUIREMENT_NOT_MET ; zone inconnue : INVALID_TARGET |
| 13 | Déconnexion, reconnexion | NOT TESTED (magasin en mémoire perdu à l'arrêt) |

### Matrice Local Server à 2 joueurs (2026-11-16, MCP)

Local Server lancé par le propriétaire (Player1 = A, UserId -1 ; Player2 =
B, UserId -2), magasin en mémoire, code identique au dépôt (`RequestSave`
présent). Requêtes envoyées par les vrais clients. Synchronisation par
`workspace:GetServerTimeNow()` pour les scénarios simultanés.

| # | Scénario | Résultat attendu | Résultat |
|---|---|---|---|
| 1 | A débloque Golden Desert | A uniquement | PASS — A SUCCESS (-1 500), `worlds.GoldenDesert` vrai pour A seul |
| 2 | B reste verrouillé | Accès refusé | PASS — B : voyage WORLD_LOCKED, collecte `sandstone_001` WORLD_LOCKED, déblocage REQUIREMENT_NOT_MET |
| 3 | A voyage | Autorisé | PASS — arrivée (3000, 6) ; retour GV SUCCESS |
| 4 | B tente de voyager | Refus serveur | PASS — WORLD_LOCKED, B reste au hub |
| 5 | Même nœud, deux joueurs | Une attribution | PASS — `green_leaf_007`, requêtes à 4 ms d'écart : B SUCCESS, A RESOURCE_UNAVAILABLE (essai préalable à 1,2 s : `wood_001`, A SUCCESS, B RESOURCE_UNAVAILABLE) |
| 6 | Ventes simultanées | Indépendantes | PASS — 6 ms d'écart : A et B +60 Coins chacun, 30 unités chacun, sacs vidés, deux opérations distinctes (Sell-1, Sell-2) |
| 7 | Même ressource découverte | Journaux indépendants | PASS — B `green_leaf` (nouvelle) ; A garde `[wood]` puis découvre `green_leaf` (nouvelle pour A) |
| 8 | Déconnexion | Profil sauvegardé | PASS — `Player_-2 : sauvegarde (sortie) OK, verrou libéré` |
| 9 | Reconnexion | Profil restauré | NOT TESTED — impossible de rejoindre avec le même UserId en Local Server ; à vérifier sur DataStore de test |
| 10 | Modification du journal par le client | Refusée | PASS — champs `discovered` ou `collection` dans Collect, Sell, Upgrade : INVALID_TARGET ; arguments supplémentaires (Travel, Collect, Sell, UnlockWorld) : INVALID_TARGET ; `StateUpdated` sans écouteur serveur ; miroir local altéré écrasé par l'état serveur suivant (`[green_leaf]`) |
| 11 | Collecte dans la même frame que le voyage | Refusée | PASS — Travel SUCCESS puis Collect du nœud GV quitté : TOO_FAR ; pendant la grâce, nœud à 19 studs : TOO_FAR ; nœud GV depuis GD : TOO_FAR |
| 12 | Sauvegarde D-023 à deux joueurs | Profil concerné seul | PASS — `Player_-1 : sauvegarde (déblocage de monde) OK` (deux fois), aucune écriture parasite pour -2 |

Remarque : un préréglage Studio (U5) remplace aussi les mondes ; un refus
WORLD_LOCKED observé ensuite pour A en découlait, non un défaut.

### DataStore de test (2026-11-16, MCP)

Méthode de T8.6 : Play à un joueur, script serveur MCP ; contrôles avant
tout appel : `RunService:IsStudio()`, PlaceId 93404872714886 (expérience de
test dédiée), magasin `GrabAndGrow_PlayerData_v1_Studio` (suffixe `_Studio`,
différent de la production). Services réels (`PlayerDataService`, code du
dépôt) branchés sur ce magasin ; plusieurs « serveurs » successifs
(identifiants distincts). Clés de test neuves `Player_-87001` à `-87006`,
vérifiées vides avant le test. `DataConfig` non modifié
(`useMemoryStore = true` conservé). Production jamais appelée.

| # | Cas | Clé | Résultat |
|---|---|---|---|
| D1 | Nouveau profil v3 | -87001 | PASS — créé en v3 dans le magasin, verrou `t87-A:1` |
| D1 | Sauvegarde après achat (D-023) | -87001 | PASS — deux `RequestSave` ; magasin inchangé immédiatement (Backpack 1), puis à 6,4 s : Backpack 2, 5 Coins, `green_leaf` découvert, verrou conservé |
| D1 | Sortie puis reconnexion (second service) | -87001 | PASS — verrou libéré ; v3, 5 Coins, Backpack 2, 7 `green_leaf`, journal et `totalCoinsSpent` conservés |
| D2 | Migration v2 -> v3 | -87002 | PASS — v3 en mémoire, journal vide, magasin resté v2 au chargement |
| D2 | Sauvegarde après migration | -87002 | PASS — `Recovery_-87002_1794830818` (`PreNormalizationBackup`, v2, 42 000 Coins) puis v3 ; inventaire (ressource inconnue `removed_res` comprise), mondes, succès, ventes conservés |
| D2 | Reconnexion après migration | -87002 | PASS — v3, découverte conservée, aucune seconde copie |
| D3 | Verrou actif d'une autre session | -87003 | PASS — `SessionLocked` ; verrou et profil d'autrui intacts (tentatives réduites à 2 par configuration de test) |
| D4 | Interruption (serveur abandonné sans sortie) | -87004 | PASS — `SessionLocked` tant que le verrou est valide (8 s en test) ; après expiration : dernière sauvegarde reprise (555 Coins, Backpack 3), modification non sauvegardée perdue comme prévu ; écriture tardive de l'ancien serveur : `LockLost`, rien écrasé |
| D5 | 2 pannes DataStore puis succès | -87005 | PASS — sauvegarde OK après reprises |
| D5 | Panne totale à la sauvegarde | -87005 | PASS — `StoreError` ; mémoire conservée (900) ; magasin intact (700) ; reprise OK ensuite |
| D5 | Panne totale au chargement | -87006 | PASS — `StoreError`, aucun profil, rien écrit (clé toujours vide) |
| D5 | `RequestSave` pendant une panne | -87005 | PASS — pas d'exception, profil toujours chargé, magasin intact ; sortie après rétablissement : 1 234 Coins écrits, verrou libéré |

Pannes simulées par un intermédiaire placé devant le vrai magasin (erreur
avant l'appel). Données laissées : `Player_-87001` à `-87005` (v3, sans
verrou) et `Recovery_-87002_1794830818`. Aucune n'appartient à un joueur
réel.

Non couvert : le branchement `Bootstrap` -> `RequestSave` sur magasin réel
(Bootstrap utilise le magasin en mémoire dans Studio). Vérifié séparément
en Studio solo et en Local Server (lignes `sauvegarde (amélioration)` et
`sauvegarde (déblocage de monde)`).

### Restant pour validation (propriétaire)

- Reconnexion d'un vrai client sur le même compte : couverte au niveau
  service (D1, D2) ; non rejouée avec un client réel. (`useMemoryStore = false`, store `_Studio`) : profil
  v3, migration v2, sauvegarde après achat (D-023), reconnexion, verrou.
- Contrôle visuel du HUD, de la boutique et du journal sur mobile.

## E. Risques résiduels

- D-023 vérifiée sur DataStore de test au niveau service ; non observée en
  production (jeu non publié).
- Performance mobile non mesurée ; `StreamingEnabled` désactivé avec
  quatre îles (≈ 2 265 Parts) : à mesurer avant T9.
- Erreur d'asset d'avatar 203785492, préexistante et étrangère au projet.

## F. État des phases

T8.7 : **validée** par le propriétaire le 2026-11-16 ; réserves acceptées. Prérequis de T9 : clôture formelle de T8 par le propriétaire, puis
mesure de performance mobile et contrôle visuel recommandés avant toute
publication. T9 ne commence pas avant validation.

## G. Git

Branche `main`. Aucun commit ni push. Fichiers modifiés : voir le rapport
de lot.
