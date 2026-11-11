# GRAB & GROW — État du projet

Dernière mise à jour : 2026-11-11 (T1 — profil joueur et sauvegarde)

## Résumé

T0 est clos. **T1 est validé avec réserves** (propriétaire, 2026-11-11) :
socle commité en e90f709, protection D-008 dans le commit suivant
(`fix(data): protect normalized profiles with recovery backups`). Sur
DataStore réel (expérience de test) : V-01, V-02, V-03, V-05 validés ;
V-04 partiel. Réserves ci-dessous. Aucun système de gameplay n'existe.
T2 ne commence qu'avec l'accord explicite du propriétaire.

### Réserves de T1

| # | Réserve | Statut |
|---|---|---|
| R-01 | Copie `Recovery_` (D-008) non vérifiée sur DataStore réel : D-008 validée sur l'implémentation et les tests automatisés | À faire ; demande le droit MCP `universe-datastores.objects:update`, à n'activer qu'avec l'accord du propriétaire |
| R-02 | V-04 : deux serveurs actifs simultanément non testés (Studio : une session par place, `RCC-276`) | Facultatif avant T2 |
| R-03 | V-02 : sortie d'un joueur sur un serveur qui continue (`PlayerRemoving` seul) non isolée sur DataStore réel | Couvert par simulation |
| R-04 | Place Roblox de test : version enregistrée avec `useMemoryStore = false` ; corrigé dans le place ouvert mais non sauvegardé | Sauvegarde du place soumise à validation |

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
default.project.json                 Mappage Rojo (Shared, Bootstrap, Services, Systems, Tests)
rokit.toml                           Versions des outils
GrabAndGrow.rbxl                     Fichier place (produit par rojo build)
src/
  ReplicatedStorage/Shared/
    Config/GameConfig.lua            Paramètres globaux MVP
    Config/ResourceConfig.lua        green_leaf, wood, stone
    Config/UpgradeConfig.lua         Backpack (16 niveaux), Grabber (10 niveaux)
    Config/WorldConfig.lua           GreenValley, GoldenDesert (verrouillé, test)
    Config/DataConfig.lua            Persistance : schéma v1, DataStore, reprises, verrou
    Util/TableUtil.lua               deepFreeze, deepCopy
  ServerScriptService/
    Bootstrap.server.lua             Point d'entrée serveur, choix du magasin
    Services/PlayerDataService.lua   Chargement, Update, sauvegarde, verrou de session
    Systems/DataSchema.lua           Profil par défaut, intégrité, migrations
    Systems/MemoryDataStore.lua      Magasin en mémoire (tests, Studio)
    Systems/PlayerSession.lua        PlayerAdded, PlayerRemoving, sauvegarde auto, BindToClose
    Tests/ConfigTests.lua            Cohérence structurelle des configs
    Tests/DataSchemaTests.lua        Schéma, intégrité, migrations (17 cas)
    Tests/PlayerDataServiceTests.lua Chargement, sauvegarde, sessions (27 cas)
    Tests/RunTests.server.lua        Lanceur, Studio uniquement
tools/run_tests.luau                 Lanceur des tests en terminal (Lune)
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

### Restantes

| # | Constat | Échéance |
|---|---|---|
| A-10 | Bible section 2 : « Capacité d'équipement initial : 1 Pet » contre « Pets équipables gratuits au départ : 2 » | Avant le lot Pets |
| A-12 | Golden Desert exige niveau de sac ET Coins ; le GDD 7.3 déconseille les conditions simultanées | Avant l'ouverture réelle de Golden Desert |
| A-14 | Les documents se citent sous `docs/GDD.md`, etc. ; noms réels `docs/GRAB_AND_GROW_*_v1.0.md` | Sans effet technique |
| A-16 | Intervalle minimal de sécurité et tolérance de distance serveur non définis dans la Bible | T2 |
| A-17 | Table Magnet de la Bible (niveau 1 gratuit à 12 studs) à réaligner sur `magnetLevel = 0` | Avec l'amélioration Magnet (hors MVP) |
| A-18 | GDD 15.5 et 20 non alignés sur D-004 et D-006 ; l'exemple de l'architecture 8.1 indique encore Stone « Uncommon » | Prochaine révision des documents |
| A-20 | Le prompt T1 cite `docs/GRAB_AND_GROW_ECONOMY_v1.0.1.md` ; le fichier réel est `..._v1.0.md` (contenu 1.0.1, en-tête encore « Version : 1.0 ») | Sans effet technique |
| A-21 | `stats.playTimeSeconds` existe dans le schéma mais aucun système ne l'alimente | À décider avant T5 |
| A-22 | Messages d'expulsion (`PlayerSession`) en anglais brut, non localisés | T5 |
| A-19 | Première amélioration (100 Coins) atteinte à la 2e vente avec 3 ressources (sac ≈ 89 Coins) ; revenu théorique maximal ≈ 142 Coins/min pour une cible de 120–250 | À mesurer en T7 |

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

1. Versionner ou non `GrabAndGrow.rbxl` dans Git (fichier binaire, mais seule
   copie de la carte dès qu'elle sera éditée dans Studio). Exclu du commit T1.
2. Push GitHub des commits T1 (non autorisé à ce jour).
3. Sauvegarde du place de test dans Roblox (R-04).

## Prochaine étape

1. Facultatif : lever R-01 et R-02.
2. Sur accord explicite du propriétaire : T2 — collecte et inventaire.
