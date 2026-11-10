# GRAB & GROW — État du projet

Dernière mise à jour : 2026-11-10 (Prompt 1.1 — clôture T0)

## Résumé

T0 est clos : structure, configurations MVP, outillage et premier test
exécuté dans Roblox Studio. Aucun système de gameplay n'existe. Prochaine
phase : T1 (profil joueur et sauvegarde), en attente de validation.

## Environnement

| Outil | Version | Emplacement |
|---|---|---|
| Roblox Studio | 0.747.0.7471481 | `%LOCALAPPDATA%\Roblox\Versions` |
| Rokit | 1.2.0 | `~/.rokit` (PATH utilisateur) |
| Rojo | 7.7.1 | via Rokit, épinglé dans `rokit.toml` |
| luau-lsp | 1.70.1 | via Rokit, épinglé dans `rokit.toml` |
| Plugin Studio Rojo | 7.7.1 | `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm` |
| Types API Roblox | tag luau-lsp 1.70.1 | `.tools/globalTypes.d.luau` (non versionné) |
| Git / GitHub CLI | 2.56.0 / 2.103.2 | dépôt `PSDiop95/grabgrow` |

Selene, StyLua et Lune ne sont pas installés : pas nécessaires à ce stade.

## Fichiers en place

```text
default.project.json                 Mappage Rojo (Shared, Tests)
rokit.toml                           Versions des outils
GrabAndGrow.rbxl                     Fichier place (produit par rojo build)
src/
  ReplicatedStorage/Shared/
    Config/GameConfig.lua            Paramètres globaux MVP
    Config/ResourceConfig.lua        green_leaf, wood, stone
    Config/UpgradeConfig.lua         Backpack (16 niveaux), Grabber (10 niveaux)
    Config/WorldConfig.lua           GreenValley, GoldenDesert (verrouillé, test)
    Util/TableUtil.lua               deepFreeze
  ServerScriptService/Tests/
    ConfigTests.lua                  Cohérence structurelle des configs
    RunTests.server.lua              Lanceur, Studio uniquement
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
| A-19 | Première amélioration (100 Coins) atteinte à la 2e vente avec 3 ressources (sac ≈ 89 Coins) ; revenu théorique maximal ≈ 142 Coins/min pour une cible de 120–250 | À mesurer en T7 |

## Décisions en attente

1. Versionner ou non `GrabAndGrow.rbxl` dans Git (fichier binaire, mais seule
   copie de la carte dès qu'elle sera éditée dans Studio).
2. Commit et push de ce lot.

## Prochaine étape

T1 — profil joueur et sauvegarde (`PlayerDataService`, schéma D-006,
migrations, tests avec DataStore simulé). Ne pas commencer sans validation.
