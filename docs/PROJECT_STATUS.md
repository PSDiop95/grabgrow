# GRAB & GROW — État du projet

Dernière mise à jour : 2026-11-11 (T1 — profil joueur et sauvegarde)

## Résumé

T0 est clos. T1 (profil joueur et sauvegarde) est écrit, testé avec un
magasin simulé (Lune et Studio) et commité localement ; D-008 et D-009 sont
acceptées. **La persistance réelle n'est pas validée** : sauvegarde
automatique, sauvegarde de sortie et DataStore réel restent à vérifier
(section « Validations T1 non réalisées »). Aucun système de gameplay
n'existe. T2 attend la validation du propriétaire.

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

## Validations T1 non réalisées

Aucune de ces vérifications n'a été faite. Tant qu'elles ne le sont pas,
la persistance n'est validée que contre le magasin en mémoire.

| # | Vérification | Ce qui manque | Comment la faire |
|---|---|---|---|
| V-01 | Sauvegarde automatique (60 s) | Aucune session Studio n'a duré 60 s ; le magasin en mémoire n'en garde de toute façon aucune trace visible | Place de test publié, DataStore réel : jouer plus de 60 s, modifier une valeur par la barre de commande serveur, couper Studio brutalement, relancer et vérifier la valeur |
| V-02 | Sauvegarde réelle à la sortie | Le Stop dans Studio n'a produit aucune erreur, mais la libération réussie ne journalise rien et le magasin était en mémoire | DataStore réel : Play, Stop, Play ; vérifier `profil chargé` (et non `nouveau profil créé`) et l'absence d'attente de verrou |
| V-03 | DataStore réel sur un place de test publié | Jamais exécuté ; quotas et latence réels inconnus | Étapes dans `DATA_PERSISTENCE.md`, section « Vérification avec le DataStore réel » |
| V-04 | Deux serveurs réels sur le même profil | Couvert uniquement par simulation | Deux sessions de test sur le place publié avec le même compte |
| V-05 | Crash serveur : expiration du verrou (180 s) | Couvert uniquement par simulation | DataStore réel : fermer Studio de force pendant le Play, relancer ; refus attendu avant 180 s, chargement après |

## Décisions en attente

1. Versionner ou non `GrabAndGrow.rbxl` dans Git (fichier binaire, mais seule
   copie de la carte dès qu'elle sera éditée dans Studio). Exclu du commit T1.
2. Push GitHub du commit T1 (non autorisé à ce jour).
3. Portée exacte de « ne jamais réparer automatiquement » dans D-008 :
   profils lisibles avec champs manquants ou niveaux hors bornes.

## Prochaine étape

1. Validations V-01 à V-05 sur un place de test publié.
2. Après validation du propriétaire : T2 — collecte et inventaire.
