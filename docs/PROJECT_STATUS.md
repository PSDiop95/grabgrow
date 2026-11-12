# GRAB & GROW — État du projet

Dernière mise à jour : 2026-11-12 (T3 — vente et Coins, commit local, PARTIEL)

## Résumé

T0 est clos. **T1 est validé avec réserves** (propriétaire, 2026-11-11) :
socle commité en e90f709, protection D-008 dans le commit suivant
(`fix(data): protect normalized profiles with recovery backups`). Sur
DataStore réel (expérience de test) : V-01, V-02, V-03, V-05 validés ;
V-04 partiel. Réserves ci-dessous.

**T2 est VALIDÉ et CLÔTURÉ** (propriétaire, 2026-11-11), commit local
`feat(collection): implement server-authoritative collection and inventory`
(aucun push). Restent ouverts pour T6 : A-26 et A-27. Reportée en phase UX :
A-29, A-30. Parcours : synchronisation Rojo
vérifiée, carte de test reconstruite, place de test sauvegardé (version 15),
reconnexion validée sur le DataStore de test, Local Server à 2 joueurs
validé (points 1 à 5 OK), copie locale `GrabAndGrow.rbxl` vérifiée,
émulateur mobile validé (protocole B OK), A-28 tranchée : toucher et
maintien conservés tous les deux (maintien : 39 collectes en 60 s). Toutes
les vérifications manuelles demandées sont faites.

**T3 est IMPLÉMENTÉ, PARTIEL** (2026-11-11) : vente serveur atomique,
station de vente provisoire, HUD Coins. Tests automatisés (Lune et Studio)
et parcours Studio à un joueur OK. Tests manuels du propriétaire contrôlés
dans les journaux : E1, E2, E5 vérifiés ; E9 (DataStore de test) vérifié
par Claude ; E3, E4, E6 (2 joueurs, ventes simultanées), E8 et rendu 3D
exécutés par Claude et validés par le propriétaire (2026-11-12) ; E7
(émulateur mobile) testé et validé par le propriétaire ; A-34 corrigé et
validé. Place de test sauvegardé avec la station corrigée (version 24,
non publiée, 2026-11-12). Commit local T3 autorisé et créé (aucun push).
Copie locale `GrabAndGrow.rbxl` rafraîchie et vérifiée.
D-014 **validée** par le propriétaire (2026-11-11) ; paramètres de sécurité
de la vente validés provisoirement, à réévaluer en T6. T3 reste PARTIEL
jusqu'à la clôture explicite par le propriétaire.
Détail : `SELLING.md` et « Vérifications T3 » ci-dessous.

### Réserves de T1

| # | Réserve | Statut |
|---|---|---|
| R-01 | Copie `Recovery_` (D-008) non vérifiée sur DataStore réel : D-008 validée sur l'implémentation et les tests automatisés | À faire ; demande le droit MCP `universe-datastores.objects:update`, à n'activer qu'avec l'accord du propriétaire |
| R-02 | V-04 : deux serveurs actifs simultanément non testés (Studio : une session par place, `RCC-276`) | Facultatif avant T2 |
| R-03 | V-02 : sortie d'un joueur sur un serveur qui continue (`PlayerRemoving` seul) non isolée sur DataStore réel | Couvert par simulation |
| R-04 | Place Roblox de test : version enregistrée avec `useMemoryStore = false` | **Levée** le 2026-11-11 (accord du propriétaire) : place de test (93404872714886) sauvegardé en version 7 avec `useMemoryStore = true` ; `DataConfig` du place et de `GrabAndGrow.rbxl` local identiques au dépôt (empreinte comparée) ; aucune donnée persistante modifiée |

## Environnement

| Outil | Version | Emplacement |
|---|---|---|
| Roblox Studio | 0.747.0.7471481 | `%LOCALAPPDATA%\Roblox\Versions` |
| Rokit | 1.2.0 | `~/.rokit` (PATH utilisateur) |
| Rojo | 7.7.1 | via Rokit, épinglé dans `rokit.toml` |
| luau-lsp | 1.70.1 | via Rokit, épinglé dans `rokit.toml` |
| Lune | 0.11.1 | via Rokit, épinglé dans `rokit.toml` (tests en terminal, D-009) |
| Plugin Studio Rojo | 7.7.1 | `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm` |
| Types API Roblox | tag luau-lsp 1.70.1 | `.tools/globalTypes.d.luau` (non versionné) |
| Git / GitHub CLI | 2.56.0 / 2.103.2 | dépôt `PSDiop95/grabgrow` |

Selene et StyLua ne sont pas installés : pas nécessaires à ce stade.

## Fichiers en place

```text
default.project.json                 Mappage Rojo (Shared, Bootstrap, Services, Systems, Tests, ServerOnlyConfig, client)
rokit.toml                           Versions des outils
GrabAndGrow.rbxl                     Copie locale du place de test, avec la carte (non versionnée, D-013)
src/
  ReplicatedStorage/Shared/
    Config/GameConfig.lua            Paramètres globaux MVP
    Config/ResourceConfig.lua        green_leaf, wood, stone
    Config/UpgradeConfig.lua         Backpack (16 niveaux), Grabber (10 niveaux)
    Config/WorldConfig.lua           GreenValley, GoldenDesert (verrouillé, test)
    Config/DataConfig.lua            Persistance : schéma v1, DataStore, reprises, verrou
    Util/TableUtil.lua               deepFreeze, deepCopy
    Util/Localization.lua            Textes en / fr par clé (provisoire, T2 ; vente T3)
    Util/SaleValue.lua               Formule de vente partagée (T3)
    Remotes/Remotes.lua              RemoteEvents et codes de résultat (T2)
  ServerStorage/ServerOnlyConfig/
    CollectionSecurityConfig.lua     Marges de sécurité de la collecte, non répliquées (T2)
    SellSecurityConfig.lua           Marges de sécurité de la vente, non répliquées (T3)
  StarterPlayer/StarterPlayerScripts/
    ClientBootstrap.client.lua       Point d'entrée client (T2)
    Controllers/InventoryController.lua   Affichage du sac
    Controllers/CollectionController.lua  Ciblage, entrées, retour visuel
    Controllers/SellController.lua   Prompt de vente, étiquette, retours (T3)
  ServerScriptService/
    Bootstrap.server.lua             Point d'entrée serveur, magasin, branchement de la collecte
    Services/PlayerDataService.lua   Chargement, Update, sauvegarde, verrou de session
    Services/InventoryService.lua    Sac : état, capacité, ajout (T2)
    Services/CollectionService.lua   Validation serveur d'une collecte (T2)
    Services/RateLimitService.lua    Limite de fréquence par joueur et action (T2)
    Services/SellService.lua         Vente : validation et transaction unique (T3)
    Systems/ResourceSpawner.lua      Nœuds, états, réapparition (T2)
    Systems/ResourceNodes.lua        Points de spawn -> Parts du Workspace (T2)
    Systems/SellZones.lua            Zones de vente du Workspace (T3)
    Systems/DataSchema.lua           Profil par défaut, intégrité, migrations
    Systems/MemoryDataStore.lua      Magasin en mémoire (tests, Studio)
    Systems/PlayerSession.lua        PlayerAdded, PlayerRemoving, sauvegarde auto, BindToClose
    Tests/ConfigTests.lua            Cohérence structurelle des configs
    Tests/DataSchemaTests.lua        Schéma, intégrité, migrations (17 cas)
    Tests/PlayerDataServiceTests.lua Chargement, sauvegarde, sessions (27 cas)
    Tests/InventoryServiceTests.lua  Sac (14 cas)
    Tests/ResourceSpawnerTests.lua   Nœuds et limite de fréquence (9 cas)
    Tests/CollectionServiceTests.lua Collecte, anti-exploit, multijoueur simulé (22 cas)
    Tests/SellServiceTests.lua       Vente, invariants, concurrence, persistance (25 cas)
    Tests/RunTests.server.lua        Lanceur, Studio uniquement
tools/run_tests.luau                 Lanceur des tests en terminal (Lune)
tools/studio/build_test_map.luau     Carte de test Green Valley (sol, spawn, 36 points, station de vente)
docs/                                Références, roadmap, décisions, tests
```

Flux de travail : voir `tests/TEST_STRATEGY.md`. Les scripts se modifient
dans `src/` ; la carte, les modèles et les interfaces dans Studio.

## Vérifications T0 (2026-11-10)

| Vérification | Type | Résultat |
|---|---|---|
| `luau-lsp analyze` sur `src/` (7 fichiers, `--!strict`) | Automatisé, terminal | Exécuté — 0 erreur, code de sortie 0 |
| Contrôle négatif de l'analyseur (fichier volontairement faux) | Automatisé, terminal | Exécuté — erreurs détectées |
| `rojo build` vers `GrabAndGrow.rbxl` | Automatisé, terminal | Exécuté — réussi |
| Ouverture du place et chargement du plugin Rojo | Journal Studio | Constaté |
| `ConfigTests` dans Studio (Run) | Automatisé, lancé à la main | Exécuté — `[Tests] ConfigTests : OK` (journal Studio, 23:07:58 UTC) |
| Valeurs Backpack, Grabber, ressources, portée, vitesse identiques à la Bible | Script de comparaison ponctuel | Exécuté — identique |
| Connexion `rojo serve` ↔ plugin Studio (synchronisation en direct) | Manuel | **Non exécuté** |
| Play avec personnage (F5) | Manuel | **Non exécuté** — le place n'a ni sol ni point d'apparition |

## Vérifications T1 (2026-11-11)

| Vérification | Type | Résultat |
|---|---|---|
| `luau-lsp analyze` sur `src/` (`--!strict`) | Automatisé, terminal | Exécuté — 0 erreur, code de sortie 0 |
| `rojo build` (fichier temporaire) | Automatisé, terminal | Exécuté — réussi |
| `ConfigTests` (non-régression T0) | Automatisé, Lune | Exécuté — OK |
| `DataSchemaTests` | Automatisé, Lune | Exécuté — OK, 17 cas |
| `PlayerDataServiceTests` (magasin simulé) | Automatisé, Lune | Exécuté — OK, 27 cas |
| Contrôle négatif : 6 défauts introduits tour à tour dans le service et le schéma | Automatisé, Lune | Exécuté — chaque défaut détecté (2 à 16 échecs) |
| Configurations T0 (`GameConfig`, `ResourceConfig`, `UpgradeConfig`, `WorldConfig`) inchangées | `git status` | Constaté — aucun de ces fichiers modifié |
| Tests et `Bootstrap` dans Studio (Play F5, synchro Rojo) | Lancé par le propriétaire, journal lu | Exécuté — `[Tests] TOUS LES TESTS : OK` (17 + 27 cas, ConfigTests OK), `[Bootstrap] PlayerDataService démarré`, magasin en mémoire (journal Studio, 08:55:24 UTC) |
| `PlayerSession` : arrivée | Studio, Play | Exécuté — `Player_<UserId> : nouveau profil créé` |
| `PlayerSession` : départ, `BindToClose` | Studio, Play puis Stop | Exécuté sans erreur ; aucune trace de succès (la libération réussie ne journalise rien) |
| `PlayerSession` : sauvegarde périodique (60 s) | Studio | **Non exécuté** — session de 20 s |
| Chargement et sauvegarde sur DataStore réel (place de test) | Manuel | **Non exécuté** — étapes dans `DATA_PERSISTENCE.md` |
| Deux serveurs réels sur le même profil | Manuel | **Non exécuté** — couvert seulement par simulation |

## Vérifications T2 (2026-11-11)

Détail du système : `COLLECTION.md`. Décisions : D-010, D-011.

### Automatisées

| Vérification | Type | Résultat |
|---|---|---|
| Lune : ConfigTests, DataSchemaTests (17), PlayerDataServiceTests (35), InventoryServiceTests (14), ResourceSpawnerTests (9), CollectionServiceTests (22) | Terminal | Exécuté — `TOUS LES TESTS : OK`, code de sortie 0 |
| Mêmes suites dans Studio (Play, magasin en mémoire) | Piloté par MCP | Exécuté — `TOUS LES TESTS : OK` |
| `luau-lsp analyze` sur `src/` (`--!strict`, client compris) | Terminal | Exécuté — 0 erreur, code de sortie 0 |
| `rojo build` (fichier temporaire) | Terminal | Exécuté — réussi |
| Contrôle négatif : 13 défauts introduits tour à tour (distance, cadence, échéance, champs falsifiés, nœud inactif, limite de fréquence, trajet, plafond du sac, sac plein, quantité négative, double collecte, minuterie périmée, seau à jetons) | Lune | Exécuté — 13 détectés sur 13 (un test renforcé après un premier passage à 12) |
| Non-régression T0 et T1 | Lune et Studio | Exécuté — suites T0/T1 inchangées et OK ; `ConfigTests` étendu (sécurité, textes) |

### Dans Studio, un joueur (Play piloté par MCP, magasin en mémoire)

| Vérification | Résultat |
|---|---|
| Démarrage | `[Bootstrap] PlayerDataService démarré ; collecte : 36 ressource(s)` |
| État initial reçu par le client | `Sac 0 / 50`, détail par ressource, langue `fr-fr` |
| Collecte touche E | `Sac 1 / 50`, message `+1 Feuille`, nœud réapparu après 2 s |
| Maintien de E 5 s | 3 collectes (une seule ressource à portée, réapparition 2 s) |
| Clic sur une ressource | +1 Pierre |
| Bouton tactile (rendu visible, maintenu à la souris 5,5 s) | 4 collectes |
| Les trois ressources collectées | Feuille, Bois, Pierre présents dans le sac |
| Sac plein | 50 / 50 (37 feuilles, 13 bois) ; `INVENTORY_FULL` ensuite ; ressource refusée toujours disponible ; 3 tentatives de plus : toujours 50 / 50 |
| Nœud à 80 studs | `TOO_FAR` |
| Identifiant inexistant, payload texte, payload `nil` | `INVALID_TARGET` |
| Payload avec `amount = 9999, coins = 1e6` | `INVALID_TARGET`, rien crédité |
| Arguments supplémentaires après le payload | Ignorés (demande jugée sur le seul payload) |
| 300 demandes d'un coup | 1 `SUCCESS`, 9 `RESOURCE_UNAVAILABLE`, 1 seule réponse `RATE_LIMITED` ; sac +1 |
| Téléportation de 82 studs juste après une collecte | `TOO_FAR`, journal `déplacement implausible` ; acceptée 5 s plus tard |
| Capture d'écran | Panneau du sac, bouton « Prendre », contour de la cible : conformes |

### Synchronisation Rojo et place de test (2026-11-11, après retour du propriétaire)

| Vérification | Résultat |
|---|---|
| `rojo serve` relancé avec le `default.project.json` de T2 | Arbre servi : `ServerStorage/ServerOnlyConfig`, `ClientBootstrap`, `Controllers` présents |
| Plugin reconnecté (propriétaire), place rouvert dans Studio | Verrou de session Rojo présent |
| Scripts du place comparés au dépôt (empreinte, fins de ligne normalisées) | 29 / 29 identiques, aucun doublon, aucun script absent de part ou d'autre |
| Synchronisation en direct | Ligne de commentaire ajoutée puis retirée dans `Localization.lua` : reçue puis retirée dans Studio (1981 octets, identique au dépôt) |
| Créations manuelles de T2 | Remplacées par la synchronisation (contenu identique) : plus de dépendance |
| Carte reconstruite par `tools/studio/build_test_map.luau` | `green_leaf x16, stone x8, wood x12` ; mêmes positions qu'à la première construction (contrôle : `Spawn_green_leaf_06` en 11,62 / 4,90) |
| Place de test sauvegardé (`save_place`) | **Version 15** sur Roblox (Team Create), non publiée. Avant sauvegarde : `DataConfig` du place identique au dépôt (`useMemoryStore = true`, empreinte comparée) |
| Copie locale `GrabAndGrow.rbxl` avec la carte | **Faite** le 2026-11-11 à 18:59 UTC (propriétaire, Fichier > Télécharger une copie, depuis la fenêtre d'édition ; 129 121 octets). Contrôle Lune : pas de `Workspace.ResourceNodes`, 36 points de spawn (16 feuilles, 12 bois, 8 pierres ; `Spawn_green_leaf_06` en 11,62 / 4,90), 29 scripts identiques au dépôt (empreinte), `useMemoryStore = true`. Deux essais précédents rejetés : instantanés de session de jeu (`server.rbxl`, 36 nœuds d'exécution déjà présents). `server.rbxl` reste dans le dossier, non suivi, à exclure du commit |

### Reconnexion sur DataStore de test (2026-11-11, autorisée par le propriétaire)

Environnement : place de test 93404872714886, DataStore
`GrabAndGrow_PlayerData_v1_Studio`, clé `Player_11975439775`.
`useMemoryStore = false` le temps du test puis remis à `true` (dépôt et
place, vérifié par empreinte). Aucune règle de sauvegarde modifiée.
DataStore de production non touché.

| Étape | Résultat | Preuves |
|---|---|---|
| Play 1 : chargement | Profil T1 existant, sac vide | `profil chargé, lastSaveAt=1794396150` ; HUD `Sac 0 / 50` |
| Collecte de 4 ressources | 4 `SUCCESS` | HUD `Sac 4 / 50 \| Feuille 2 Bois 1 Pierre 1` |
| Stop | Sauvegarde de fermeture | Journal Studio : `sauvegarde (fermeture serveur) OK, lastSaveAt=1794417526, verrou libéré` |
| Play 2 : reconnexion | **Inventaire restauré** | `profil chargé, lastSaveAt=1794417526, verrou précédent : aucun` ; HUD `Sac 4 / 50 \| Feuille 2 Bois 1 Pierre 1` |
| Lecture de la clé (`GetAsync`, lecture seule) | Valeur stockée conforme | `green_leaf=2, stone=1, wood=1`, `totalResourcesCollected=4`, `coins=0` |
| Stop | Sauvegarde de fermeture | `sauvegarde (fermeture serveur) OK, lastSaveAt=1794417559, verrou libéré` |

Aucune écriture DataStore pendant les collectes (une seule écriture de
profil par session, à la fermeture). Le profil de test garde ces
4 ressources.

### Multijoueur — Local Server, 2 joueurs (propriétaire, 2026-11-11, 17:33–17:36 UTC)

Magasin en mémoire. Preuves : constats du propriétaire et journaux Studio
(serveur `…173305Z_Studio_F415D`, clients `…0D308` et `…F5B70`).

| # | Vérification (protocole A) | Résultat | Source |
|---|---|---|---|
| — | Démarrage serveur, deux joueurs chargés | OK : `TOUS LES TESTS : OK`, `collecte : 36 ressource(s)`, `Player_-1` et `Player_-2 : nouveau profil créé` (verrous `…:1` et `…:2`) ; environ 80 s à deux joueurs | Journal serveur |
| — | Sauvegardes pendant et après le test | OK : sauvegardes auto à 60 s pour les deux profils, puis `sauvegarde (sortie) OK, verrou libéré` pour chacun | Journal serveur |
| 1 | Inventaires indépendants | **OK** | Propriétaire |
| 2 | Même ressource : un seul sac crédité | **OK** (second essai, testeur seul alternant deux fenêtres, pierre) | Propriétaire |
| 3 | Disparition et réapparition visibles dans les deux fenêtres | **OK** (second essai) | Propriétaire |
| 4 | Sac plein d'un joueur sans effet sur l'autre | **OK** | Propriétaire |
| 5 | Aucune erreur du jeu dans Output | OK : aucune ligne `[Collection]` ni erreur de script du jeu. Seules erreurs : texture d'accessoire d'avatar introuvable (`Hat1`) et `ChatScript` de Roblox (`CoreGuiChatConnections`), étrangères au projet | Journaux serveur et clients |

Les collectes réussies ne sont pas journalisées : les points 1 à 4 ne
reposent que sur les constats visuels. Second essai (points 2 et 3),
journaux retrouvés : serveur `…174628Z_Studio_05E0B`, clients `…FB08B` et
`…FE4DA`. `TOUS LES TESTS : OK`, `collecte : 36 ressource(s)`, `Player_-1`
(17:47:12) et `Player_-2` (17:48:25) créés, sauvegardes auto OK, aucune
erreur du jeu. Le point 2 reste couvert par la
simulation Lune (même ressource, deux joueurs) et par l'atomicité serveur
(aucune suspension entre contrôle et consommation du nœud).

### Mobile — émulateur d'appareils (propriétaire, 2026-11-11)

Preuves : constat du propriétaire et capture d'écran (téléphone, paysage).
Les journaux Studio ne montrent que le chargement du plugin
DeviceSimulator : ils ne prouvent pas le test.

| # | Vérification (protocole B) | Résultat | Source |
|---|---|---|---|
| 6 | Bouton « Prendre » visible, atteignable, sans recouvrir saut ni stick | **OK** : bouton à gauche du saut, stick à gauche, aucun recouvrement | Propriétaire, capture |
| 7 | Panneau du sac lisible, sans masquer l'action | **OK** : `Sac 34 / 50`, `Feuille 14 Bois 8 Pierre 12`, en haut au centre | Propriétaire, capture |
| 8 | Contour blanc et nom au-dessus de la cible | **OK** : contour et étiquette `Bois` visibles | Propriétaire, capture |
| 9 | Retours `+1`, barre, `Sac plein !`, barre rouge | **OK** | Propriétaire |
| 10 | Stick, saut, caméra pendant et après la collecte | **OK** | Propriétaire |

Défaut cosmétique relevé (capture PC, `Sac 2 / 50`) : à faible
remplissage, la barre du sac s'affiche comme une pastille ronde (largeur du
remplissage inférieure à l'arrondi des coins). Non corrigé : décision du
propriétaire (2026-11-11), reporté à la phase dédiée à
l'expérience utilisateur (A-30).

### Comparaison toucher / maintien (protocole C, A-28)

| Mode | Collectes en 60 s | Remarques |
|---|---|---|
| Maintien | 39 | Mesure du propriétaire |
| Toucher | Non mesuré | — |

Référence : cadence maximale théorique 80 en 60 s (intervalle 0,75 s),
réellement bornée par les déplacements et la réapparition. Décision du
propriétaire (2026-11-11) : conserver les deux modes, sans mesure du
toucher (D-012).

### Relance finale (2026-11-11, vers 20:00 UTC)

| Test | Type | Résultat |
|---|---|---|
| `lune run tools/run_tests.luau` | Automatisé, terminal | OK : 6 suites (Config, 17, 35, 14, 9, 22 cas), code de sortie 0 |
| `luau-lsp analyze` sur `src/` | Automatisé, terminal | 0 erreur, code de sortie 0 |
| `rojo build` (vers un fichier temporaire, la copie locale n'est pas écrasée) | Automatisé, terminal | Réussi |
| Synchronisation Studio | Empreintes | 29 scripts identiques au dépôt |
| Play dans Studio | Automatisé, lancé par MCP | `TOUS LES TESTS : OK`, `collecte : 36 ressource(s)`, profil créé en mémoire ; seule erreur : asset Roblox 203785492 (avatar), étrangère au projet |
| Périmètre | Diff | Aucun changement de `Config`, `PlayerDataService`, `DataSchema` ; aucune référence à la vente ou aux Coins dans le code T2 |

### Non exécutées

| Vérification | Raison | Couverture actuelle |
|---|---|---|
| Appareil mobile réel | Pas d'appareil branché | Émulateur validé (protocole B) |
| Mesure du mode toucher (A-28) | Non demandée : les deux modes sont conservés (D-012) | Maintien : 39 collectes en 60 s |
| Étiquette de nom au-dessus de la cible | L'outil de capture n'affiche aucun BillboardGui (vérifié avec un panneau neutre) | Propriétés lues : activée, ancrée sur la cible, texte `Pierre  [E]` |
| Manette (bouton X) | Pas de manette | Même chemin de code que la touche E |
| Performances avec plusieurs joueurs | Hors périmètre T2 | T6 |

## Vérifications T3 (2026-11-11)

Détail du système : `SELLING.md`. Décision : D-014 (acceptée le 2026-11-11).

### Automatisées

| Vérification | Type | Résultat |
|---|---|---|
| Lune : 7 suites (Config, 17, 35, 14, 9, 22, **SellServiceTests 25**) | Terminal | Exécuté — `TOUS LES TESTS : OK`, code de sortie 0 |
| Mêmes suites dans Studio (Play, magasin en mémoire) | Piloté par MCP | Exécuté — `TOUS LES TESTS : OK` |
| `luau-lsp analyze` sur `src/` (`--!strict`) | Terminal | Exécuté — 0 erreur, après correction de 3 erreurs de typage (comparaisons à `nil`, options de test) |
| `rojo build` (fichier temporaire) | Terminal | Réussi |
| Synchronisation Rojo | Empreintes Studio / dépôt | 35 / 35 scripts identiques |
| Contrôle négatif : 11 défauts introduits tour à tour (pas de retrait, pas de distance, champs falsifiés acceptés, `totalSales` oublié, inconnues vendues, pas de limite de fréquence, contrôle de dépassement du solde, `totalCoinsSpent` modifié, vente sans personnage, garde de dépassement par quantité, sac vide accepté) | Lune | 10 détectés sur 11 après renforcement : le contrôle de dépassement du solde n'était d'abord vu que par son effet (le schéma bloquait aussi), les tests vérifient désormais la détection explicite. Non détecté : la garde de quantité, redondante avec la garde de somme qui bloque le même cas (même code, aucune mutation) |
| Non-régression T0 à T2 | Lune et Studio | Suites T0–T2 inchangées et OK ; `ConfigTests` étendu (vente, textes) |
| Configurations économiques | Diff | `ResourceConfig`, `UpgradeConfig`, `WorldConfig` inchangés ; `GameConfig` : ajout de `Selling.interactRangeStuds` seulement |

Cas couverts par `SellServiceTests` : les 18 points du prompt T3, plus
quantités à zéro, zone inconnue, vente pendant une sauvegarde, erreur dans
la mutation, deux joueurs. Le point 16 (HUD) est couvert côté serveur
(`GetClientState` après vente, estimation égale au crédit) ; l'affichage
est vérifié dans Studio ci-dessous.

### Dans Studio, un joueur (Play piloté par MCP, magasin en mémoire)

| Vérification | Résultat |
|---|---|
| Carte reconstruite (mode Edit) | Points de spawn identiques (`Spawn_green_leaf_06` en 11,62 / 4,90) ; station `GreenValley_Main`, point de spawn le plus proche à 14,7 studs |
| Démarrage | `collecte : 36 ressource(s) ; vente : 1 zone(s)` |
| Vente depuis le point d'apparition (20,4 studs) | `TOO_FAR` |
| Vente sur la zone, sac vide | `NOTHING_TO_SELL` ; prompt `Vendre` / `Sac vide`, touche F, manette Y |
| 10 collectes (6 feuilles, 2 bois, 2 pierres) | HUD `Sac 10 / 50`, `Coins 0 / Valeur ~16` ; prompt `~16 Coins` |
| Vente par le prompt (`InputHoldBegin`) + seconde demande immédiate | `SUCCESS`, `coinsEarned = 16`, `quantitySold = 10`, puis `NOTHING_TO_SELL` ; HUD `Sac 0 / 50`, `Coins 16 / Valeur ~0` ; prompt `Sac vide` |
| Journal serveur | Une seule ligne `[Sell] ... +16 Coins (motif Sell, zone GreenValley_Main, 10 unité(s) : green_leaf=6, stone=2, wood=2)` |
| Payloads `nil`, texte, nombre, `amount`/`coins` ajoutés, zone inconnue, `items` | `INVALID_TARGET` puis `RATE_LIMITED` (rafale 3) ; Coins inchangés |
| 300 demandes d'un coup | 3 `NOTHING_TO_SELL`, 1 `RATE_LIMITED`, le reste silencieux ; Coins inchangés (16) |
| Capture d'écran | Ligne Coins / Valeur sous le sac, lisible. La 3D n'est pas rendue par l'outil de capture : station et prompt non vus à l'image |

Constat : une seconde réponse (`Rien à vendre`) arrivée juste après une
vente remplace le toast `+N Coins`. Ne se produit pas par le prompt (une
demande à la fois côté client) ; seulement en envoyant le RemoteEvent à la
main.

### Tests manuels du propriétaire (2026-11-11, 21:14–21:25 UTC) — contrôle des preuves

Annoncés « effectués » par le propriétaire. Contrôle par Claude : journaux
Studio (`%LOCALAPPDATA%\Roblox\logs` : session d'édition `…160046Z_Studio_9D48E`,
Local Server `…211925Z_Studio_3B179` et clients `…D95FA`, `…90D7D`) et
lecture seule (`GetAsync`) de la clé de test. Chaque montant journalisé a
été recalculé (somme quantité × prix) : tous exacts.

| # | Vérification | Preuve | Statut |
|---|---|---|---|
| E1 | Vente partielle | `+21 Coins` (4 feuilles, 3 pierres, 4 bois) puis `+12 Coins` (5 unités), 21:14–21:15. Constat du propriétaire : un seul appui sur « Vendre » vend tout le sac (comportement prévu : architecture 9.2, GDD 6.1) | **Vérifié** |
| E2 | Sac plein puis nouvelle collecte | `+90 Coins (50 unité(s) : green_leaf=24, stone=14, wood=12)` à 21:18:15, puis `+6` et `+8` (collectes après la vente) | **Vérifié** |
| E3 | Sac vide | `NOTHING_TO_SELL` n'est pas journalisé ; exécuté ensuite par Claude (voir ci-dessous) | **Validé** (2026-11-12) |
| E4 | Distance | `TOO_FAR` n'est pas journalisé ; exécuté ensuite par Claude (voir ci-dessous) | **Validé** (2026-11-12) |
| E5 | Double vente | Une seule ligne `[Sell]` à 21:18:15, suivie d'un rejet `[RateLimit]` 0,5 s après : demandes répétées, un seul crédit | **Vérifié** |
| E6 | Deux joueurs (Local Server) | Serveur : `TOUS LES TESTS : OK`, `Player_-1` et `Player_-2` créés, sauvegardes auto et de sortie OK, aucune erreur du jeu. **Une seule vente** journalisée (`joueur -1 : +37 Coins`) : aucune vente du joueur 2, donc pas de vente simultanée prouvée. Refait ensuite par Claude avec ventes simultanées (voir ci-dessous) | **Validé** (2026-11-12) |
| E7 | Émulateur mobile | Aucune trace exploitable dans les journaux (session 21:23:49, `+14 Coins`, non attribuable à un appareil) ; retesté le 2026-11-12 (voir « E7 » ci-dessous) | **Validé** (propriétaire, 2026-11-12) |
| E8 | Manette | Aucune trace exploitable ; ButtonY simulé ensuite par Claude (voir ci-dessous) | **Validé** (2026-11-12) |
| E9 | Reconnexion sur DataStore de test | Exécuté ensuite par Claude, avec l'accord du propriétaire : voir « E9 » ci-dessous | **Vérifié** |
| — | Rendu 3D de la station | Non vérifiable par journal ; station présente dans le place (`GreenValley_Main` en -12 / 0,2 / -16) ; rendu vu ensuite dans les captures Local Server | **Validé** (2026-11-12) |
| — | Erreurs | Seule erreur : `ChatScript` de Roblox (`CoreGuiChatConnections`), étrangère au projet | OK |

### E9 — Reconnexion sur DataStore de test (Claude, 2026-11-11, vers 21:30 UTC)

Autorisé par le propriétaire (DataStore de test uniquement). Place de test
93404872714886, DataStore `GrabAndGrow_PlayerData_v1_Studio`, clé
`Player_11975439775`. `useMemoryStore = false` le temps du test (dépôt,
synchronisé par Rojo), puis remis à `true`. Production non touchée.

| Étape | Résultat | Preuves |
|---|---|---|
| Avant | Clé inchangée depuis T2 | `GetAsync` : `lastSaveAt=1794417559`, `coins=0`, sac 2 / 1 / 1 |
| Play 1 : chargement | Profil T2 lu dans le DataStore de test | `[Bootstrap] DataStore : GrabAndGrow_PlayerData_v1_Studio` ; `profil chargé, lastSaveAt=1794417559` ; HUD `Sac 4 / 50`, `Coins 0 \| Valeur ~7` |
| 4 collectes | Sac 8 | HUD `Feuille 6 Bois 1 Pierre 1`, `Valeur ~11` |
| Vente par le prompt | `SUCCESS`, 11 Coins, 8 unités | `[Sell] ... +11 Coins (... green_leaf=6, stone=1, wood=1)` ; HUD `Sac 0 / 50`, `Coins 11` |
| 2 collectes après vente | Sac 2 | HUD `Feuille 2`, `Coins 11`, `Valeur ~2` |
| Stop | Sauvegarde de fermeture | `GetAsync` : `coins=11`, `totalSales=1`, `totalCoinsEarned=11`, `totalCoinsSpent=0`, `totalResourcesCollected=10`, sac `green_leaf=2`, `lastSaveAt=1794432655`, verrou libéré |
| Play 2 : reconnexion | **Coins et sac restaurés** | `profil chargé, lastSaveAt=1794432655, verrou précédent : aucun` ; HUD `Sac 2 / 50 \| Feuille 2 \| Coins 11 \| Valeur ~2` |
| Stop | Sauvegarde de fermeture | `GetAsync` : `coins=11`, `lastSaveAt=1794432687`, verrou libéré |
| Remise en état | `useMemoryStore = true` | Dépôt identique à HEAD (`git diff` vide) ; place : empreinte `2442:2008118041`, identique au dépôt |

Une seule écriture de profil par session (fermeture) : la vente n'a
déclenché aucune écriture (D-014). Le profil de test garde 11 Coins et
2 feuilles.

État après les tests : `useMemoryStore = true` (dépôt et place). Seules
écritures : profil de test ci-dessus ; aucune en production.

### E3, E4, E6, E7, E8, rendu 3D — exécutés par Claude (2026-11-12)

Magasin en mémoire (`useMemoryStore = true`) ; aucune écriture DataStore.
Profil de test `Player_11975439775` (11 Coins, 2 feuilles) non touché.
Entrées réelles : déplacement par `character_navigation`, touches par
`user_keyboard_input` (E, F, ButtonY).

**Validés par le propriétaire (2026-11-12) : E3, E4, E6, E8, rendu 3D.**
E7 : testé ensuite par le propriétaire sur l'émulateur, validé (voir
« E7 » ci-dessous).

### E7 — Émulateur mobile (propriétaire, 2026-11-12)

Test manuel du propriétaire, déclaré effectué. Trace Studio (magasin en
mémoire, profil de test non touché) : `[Sell] joueur 11975439775 : +8 Coins
(motif Sell, zone GreenValley_Main, 6 unité(s) : green_leaf=5, stone=1)`,
montant recalculé exact (5 × 1 + 1 × 3) ; `sauvegarde (sortie) OK`. Seule
erreur : asset d'avatar 203785492, étrangère au projet. Le journal ne
permet pas d'attribuer la session à un appareil : la validation repose sur
le constat du propriétaire. **Validé** (propriétaire).

| # | Protocole | Résultat observé |
|---|---|---|
| E3 | Play, sac vide, sur la dalle, touche F | Prompt `Vendre` / `Sac vide`, touches F et ButtonY ; `NOTHING_TO_SELL` ; toast « Rien à vendre » ; Coins 0 |
| E4 | Sac 2 (1 feuille, 1 bois, ~3), à 18,3 studs | Prompt caché ; F : aucune demande envoyée ; `RequestSell` direct : `TOO_FAR`, toast « Approchez-vous du stand », sac et Coins inchangés |
| E4 | Approche | Prompt caché à 11,7 studs, affiché à 9,7 (`~3 Coins`) ; F : `SUCCESS +3`, HUD `Sac 0 / 50`, `Coins 3 \| Valeur ~0` ; une seule ligne `[Sell]` |
| E8 | ButtonY simulé (aucune manette réelle, `GamepadEnabled = false`) | Déclenche la vente (`NOTHING_TO_SELL` sac vide) ; prompt `GamepadKeyCode = ButtonY` |
| E7 | Émulateur mobile non pilotable par MCP | **Non exécuté.** Contrôles indirects : prompt `ClickablePrompt = true` (toucher), `HoldDuration 0`, `RequiresLineOfSight = false` ; panneau HUD 320 × 82 px (largeur 0,6, plafonnée) à 990 × 512. Portrait / paysage non vus |
| E6 | Local Server, 2 joueurs (lancé par le propriétaire), magasin en mémoire | P1 collecte 2 feuilles, P2 1 feuille + 1 bois (touche E). P2 vend seul (F) : `+3`, P1 inchangé (sac 2, Coins 0). P2 recollecte 1 feuille. Ventes simultanées : chaque client envoie 3 `RequestSell` à la même heure serveur (écart 2 ms) : P1 `SUCCESS +2` (2 unités) puis 2 × `NOTHING_TO_SELL` ; P2 `SUCCESS +1` (1 unité) puis 2 × `NOTHING_TO_SELL`. Final : P1 Coins 2, P2 Coins 4, sacs vides. Journal serveur : exactement 3 lignes `[Sell]` (`-2 +3`, `-2 +1`, `-1 +2`), montants exacts ; sauvegardes auto OK. Aucun double crédit, aucune perte |
| 3D | Captures des clients Local Server | Station rendue : dalle jaune, comptoir, toit rouge, pièce dorée, étiquette « Vente ». Constat A-34 ci-dessous |
| — | Erreurs | Seules : assets d'avatar Roblox 203785492 et 81504106 (absents du dépôt), étrangères au projet |

### Restant avant clôture de T3

| Vérification | Raison |
|---|---|
| Clôture de T3 | Décision du propriétaire |

### Sauvegarde du place et commit (2026-11-12, autorisés par le propriétaire)

| Contrôle | Résultat |
|---|---|
| Synchronisation Rojo, avant sauvegarde | Mode Edit ; 35 / 35 scripts du place identiques au dépôt (empreinte, fins de ligne normalisées), aucun script en trop ou manquant ; `DataConfig` `useMemoryStore = true` |
| Station dans le place | `Workspace.SellZones.GreenValley` : `SellZonePad` (`GreenValley_Main`), comptoir, poteaux, toit, pièce ; 36 points de spawn ; pas de `ResourceNodes` (nœuds d'exécution absents) |
| `save_place` | **Version 24** sur Roblox (Team Create), non publiée |
| Profil DataStore de test | Non touché (11 Coins, 2 feuilles) |
| Copie locale `GrabAndGrow.rbxl` | Rafraîchie par le propriétaire (2026-11-12 10:37 UTC, 141 092 octets). Contrôle Lune : `SellZones.GreenValley` complet (`SellZonePad` `GreenValley_Main`), 36 points de spawn (16 / 12 / 8), pas de `ResourceNodes`, 35 / 35 scripts identiques au dépôt (empreinte), `DataConfig` compris (`useMemoryStore = true`) |

## Anomalies

### Résolues

| # | Constat | Résolution |
|---|---|---|
| A-01 | Moyennes de la Bible incohérentes avec ses poids | Bible 1.0.1, D-007 |
| A-02 | 3 ressources MVP contre 5 dans la Bible | 3 confirmées ; moyenne 1,78 documentée dans la Bible |
| A-03 | Rareté de Stone | « Common » (Bible) |
| A-04 | Identifiant du bois | `wood`, D-003 |
| A-05 | `magnetLevel` de départ | 0, D-006 |
| A-06 | Structure des monnaies | `currencies = { coins, gems, stars }`, D-006 |
| A-07, A-08 | Noms de modules et de scripts | Architecture technique, D-002 |
| A-09 | Ordre des phases | T0 à T8, D-004 |
| A-11 | Achat multiple | x1 seul dans le MVP, D-003 |
| A-13 | Temps de réapparition non définis | 2 / 3 / 4 s, hypothèse provisoire consignée dans la Bible 3.6 |
| A-15 | Test « Monde verrouillé » sans second monde | `GoldenDesert` verrouillé dans `WorldConfig`, D-003 |
| A-16 | Intervalle minimal de sécurité et tolérance de distance serveur non définis | Valeurs de départ dans `CollectionSecurityConfig`, D-010 ; hypothèses à mesurer en T6/T7 |

### Restantes

| # | Constat | Échéance |
|---|---|---|
| A-10 | Bible section 2 : « Capacité d'équipement initial : 1 Pet » contre « Pets équipables gratuits au départ : 2 » | Avant le lot Pets |
| A-12 | Golden Desert exige niveau de sac ET Coins ; le GDD 7.3 déconseille les conditions simultanées | Avant l'ouverture réelle de Golden Desert |
| A-14 | Les documents se citent sous `docs/GDD.md`, etc. ; noms réels `docs/GRAB_AND_GROW_*_v1.0.md` | Sans effet technique |
| A-17 | Table Magnet de la Bible (niveau 1 gratuit à 12 studs) à réaligner sur `magnetLevel = 0` | Avec l'amélioration Magnet (hors MVP) |
| A-18 | GDD 15.5 et 20 non alignés sur D-004 et D-006 ; l'exemple de l'architecture 8.1 indique encore Stone « Uncommon » | Prochaine révision des documents |
| A-20 | Le prompt T1 cite `docs/GRAB_AND_GROW_ECONOMY_v1.0.1.md` ; le fichier réel est `..._v1.0.md` (contenu 1.0.1, en-tête encore « Version : 1.0 ») | Sans effet technique |
| A-21 | `stats.playTimeSeconds` existe dans le schéma mais aucun système ne l'alimente | À décider avant T5 |
| A-22 | Messages d'expulsion (`PlayerSession`) en anglais brut, non localisés | T5 |
| A-19 | Première amélioration (100 Coins) atteinte à la 2e vente avec 3 ressources (sac ≈ 89 Coins) ; revenu théorique maximal ≈ 142 Coins/min pour une cible de 120–250 | À mesurer en T7 |
| A-23 | `rojo serve` lancé avant T2 ne prenait pas en compte les nouvelles entrées de `default.project.json` (`ServerStorage`, `StarterPlayer`) | **Levée** le 2026-11-11 : `rojo serve` relancé, plugin reconnecté par le propriétaire ; dans Studio, 29 scripts identiques au dépôt (empreinte comparée), aucun doublon |
| A-24 | La carte de test n'existait que dans le place ouvert, non enregistré | **Levée** le 2026-11-11 : carte reconstruite par script, place de test sauvegardé en version 15 (non publié), copie locale `GrabAndGrow.rbxl` contenant la carte vérifiée (18:59 UTC). Non versionnée dans Git (D-013) : sauvegarde de travail locale |
| A-25 | Ressources inconnues de `ResourceConfig` conservées par D-008 | **Décidée** (propriétaire, 2026-11-11, D-012) : conservées, et comptées dans l'occupation du sac pour empêcher tout dépassement de capacité. Comportement actuel, documenté dans `COLLECTION.md`. Vente (T3, D-014) : jamais vendues ni supprimées ; `NOTHING_TO_SELL` si elles sont seules |
| A-31 | `EconomyService` de l'architecture (5.4, 9.3) non créé : le crédit de la vente vit dans la transaction de `SellService` | **Décidée** (D-014, propriétaire, 2026-11-11) : extraction autorisée en T4, avec le premier débit |
| A-32 | Distance de vente (10 studs), marge (4) et limite (rafale 3, 1/s) absentes de la Bible | **Validées provisoirement** (propriétaire, 2026-11-11, D-014) : configurables, à réévaluer en T6 |
| A-33 | Pas de son ni d'effet de pièces à la vente (GDD 13.4) | Phase UX, avec A-29 |
| A-34 | Près de la station, l'étiquette « Vente » (BillboardGui, décalage 9) apparaît derrière le panneau du sac en haut de l'écran : lisibilité réduite | **Corrigé en T3** (décision du propriétaire, 2026-11-12) : `SellController` masque l'étiquette tant que le prompt de vente est affiché (`PromptShown` / `PromptHidden`, sans boucle). Vérifié dans Studio : masquée à 6,2 studs, visible à 12,3 et 15,4 studs sans chevauchement du HUD ; vente F toujours OK (`NOTHING_TO_SELL`, sac vide). **Validé** par le propriétaire (2026-11-12) |
| A-26 | Position du personnage simulée par le client : le contrôle de trajet ne bloque que la téléportation entre deux collectes | **Ouverte, à traiter en T6** (D-012) : contrôle actuel conservé comme protection provisoire ; validation renforcée des déplacements côté serveur en T6. Concerne aussi la vente depuis T3 (D-014) : position falsifiée = vente à distance, sans gain de Coins |
| A-27 | Marges de sécurité de la collecte (4 studs, 0,1 s, 5 demandes/s) jamais mesurées avec une latence mobile réelle | **Ouverte, à traiter en T6** (D-012) : marges conservées comme hypothèses jusqu'aux tests sur mobile avec latence réelle |
| A-28 | Collecte par toucher et collecte en maintien implémentées toutes les deux (GDD 5.1) | **Levée** le 2026-11-11 (propriétaire, D-012) : les deux modes sont conservés. Maintien mesuré sur émulateur (39 collectes en 60 s) ; toucher non mesuré |
| A-29 | Aucun son ni animation de personnage à la collecte ; modèles de ressources provisoires | **Décidée** (D-012) : reportée à une phase dédiée à l'expérience utilisateur |
| A-30 | Barre du sac affichée en pastille ronde à faible remplissage (largeur du remplissage inférieure à l'arrondi des coins) | **Reportée** (propriétaire, 2026-11-11) : phase dédiée à l'expérience utilisateur, avec A-29 |

## Vérifications avant le commit D-008 (2026-11-11)

| Vérification | Type | Résultat |
|---|---|---|
| Lune : ConfigTests, DataSchemaTests (17), PlayerDataServiceTests (35) | Automatisé, terminal | Exécuté — OK, code de sortie 0 |
| Mêmes suites dans Studio (Play, magasin en mémoire) | Automatisé, piloté par MCP | Exécuté — `TOUS LES TESTS : OK`, profil créé |
| Scripts du place Studio identiques au dépôt | Empreinte comparée, 11 modules | Identiques (ConfigTests : fins de ligne CRLF seulement) |
| `luau-lsp analyze` | Automatisé, terminal | 0 erreur |
| Défauts D-008 introduits volontairement (4) | Contrôle négatif, Lune | Tous détectés |
| Configs économiques inchangées | `git diff` | Constaté |

## Validations T1 sur DataStore réel (2026-11-11)

Environnement : expérience de test dédiée (universe 10775875517, place
93404872714886, confirmée par le propriétaire), DataStore
`GrabAndGrow_PlayerData_v1_Studio`, clé `Player_11975439775`. Pilotage de
Studio par le serveur MCP Roblox Studio (Play, Stop, Luau) ; preuves :
journal Studio (`[PlayerData]`) et lectures `GetAsync` de la clé réelle.
Après les tests : `useMemoryStore` remis à `true` (dépôt et place ouvert).

| # | Vérification | Résultat | Preuves |
|---|---|---|---|
| V-03 | DataStore réel | **Validé** | `[Bootstrap] DataStore : GrabAndGrow_PlayerData_v1_Studio` ; `nouveau profil créé` (11:06:34 UTC) ; `GetAsync` : profil v1 par défaut + verrou `studio-733f…:1`, `expiresAt=1794395373` |
| V-01 | Sauvegarde auto 60 s | **Validé** | `sauvegarde (auto) OK, lastSaveAt=1794395251` (11:07:32, 58 s après le chargement) ; `GetAsync` : `lastSaveAt=1794395251`, `expiresAt` repoussé à 1794395432. Persistance sans sauvegarde de sortie : après le crash (E3), E5 relit `lastSaveAt=1794395680`, valeur de la dernière sauvegarde auto |
| V-02 | Sauvegarde écrite à la sortie | **Validé** (propriétaire) ; voie `PlayerRemoving` seule non isolée (R-03) | Stop : `sauvegarde (fermeture serveur) OK, lastSaveAt=1794395300, verrou libéré` ; `GetAsync` : `lastSaveAt=1794395300`, `session=nil` ; Play suivant : `profil chargé, lastSaveAt=1794395300, verrou précédent : aucun`. Dans Studio, le Stop déclenche `BindToClose` : le cas « joueur qui quitte un serveur qui continue » n'a pas été observé seul |
| V-05 | Crash : expiration du verrou | **Validé** | Dernière sauvegarde auto `lastSaveAt=1794395680`, verrou jusqu'à 1794395860 ; Studio tué (`taskkill /F`, 11:14:52) ; Play à 11:15:40 : 5 tentatives `profil détenu par la session studio-48a3…:1 (expire dans 122 s…98 s)`, puis `chargement refusé (SessionLocked)` et expulsion ; `GetAsync` : valeur inchangée. Play à 11:17:56 : `profil chargé, lastSaveAt=1794395680, verrou précédent : studio-48a3…:1 (expiré depuis 13 s)` |
| V-04 | Deux serveurs sur le même profil | **Partiel** (validé partiellement par le propriétaire, R-02) | Un serveur ne peut pas prendre un verrou détenu par un autre (E4, verrou d'un serveur arrêté). Deux serveurs **actifs simultanément** : non testé, Studio refuse deux sessions sur le même place (`RCC-276 Sessions multiples détectées`) et ferme l'ancienne ; celle-ci s'est arrêtée proprement (`sauvegarde (fermeture serveur) OK, lastSaveAt=1794395974, verrou libéré`). Reste couvert par la simulation |

Non vérifié sur DataStore réel :

- V-04 avec deux serveurs actifs : demande deux serveurs publiés (le même
  compte qui change de serveur sur l'expérience de test), journaux lus par
  la console développeur.
- Copie de récupération D-008 (`Recovery_`) : aucun profil à normaliser
  dans le magasin de test ; en provoquer un exige le droit d'écriture MCP
  (`universe-datastores.objects:update`), non demandé. Couvert par la
  simulation uniquement.
- `ListKeysAsync` depuis MCP retourne une liste vide alors que la clé
  existe : non utilisé comme preuve.

## Décisions en attente

1. Push GitHub des commits T1 et T2 (non autorisé à ce jour).
2. Push du commit local T3 (non autorisé à ce jour).
3. Clôture formelle de T3.

## Prochaine étape

1. Propriétaire : clôture de T3. Aucun push, T4 non commencé.
