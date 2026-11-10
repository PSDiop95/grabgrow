# GRAB & GROW — État du projet

Dernière mise à jour : 2026-11-10 (Prompt 1 — audit initial)

## Résumé

Projet au stade pré-production. Les trois documents de référence existent.
Les configurations du MVP et un test de cohérence sont écrits mais n'ont
jamais été exécutés dans Roblox Studio. Aucun système de gameplay n'existe.

## État du dépôt

- Avant le lot : 4 fichiers Markdown (`CLAUDE.md` + 3 documents dans `docs/`).
  Aucun script, aucun asset, aucun fichier place (`.rbxl`/`.rbxlx`), aucune
  configuration de projet, aucune dépendance.
- Pas de dépôt Git initialisé : aucun historique, aucune modification locale
  à préserver.
- Rien à supprimer, aucun script redondant.

## Environnement (vérifié le 2026-11-10)

| Outil | État |
|---|---|
| Roblox Studio | Installé (`%LOCALAPPDATA%\Roblox\Versions\version-63eb6055af4e4688`). Non lancé pendant ce lot. |
| Git | 2.56.0 disponible, dépôt non initialisé |
| GitHub CLI | 2.103.2 disponible |
| Rojo | Absent |
| Luau CLI / luau-lsp / Selene / StyLua / Lune | Absents |
| Rokit / Aftman | Absents |
| Node.js, Python | Présents (outillage uniquement, jamais pour le jeu) |

Conséquence : aucun code Luau ne peut être exécuté ni analysé depuis le
terminal aujourd'hui, et rien ne relie encore `src/` à Studio.

## Fichiers en place

```text
default.project.json                 Mappage Rojo (proposition, D-001)
src/
  ReplicatedStorage/Shared/
    Config/GameConfig.lua            Paramètres globaux MVP
    Config/ResourceConfig.lua        3 ressources Green Valley
    Config/UpgradeConfig.lua         Backpack (16 niveaux), Grabber (10 niveaux)
    Config/WorldConfig.lua           Green Valley
    Util/TableUtil.lua               deepFreeze (gel des configs)
  ServerScriptService/Tests/
    ConfigTests.lua                  Cohérence structurelle des configs
    RunTests.server.lua              Lanceur, Studio uniquement
docs/
  ROADMAP.md, PROJECT_STATUS.md
  decisions/TECHNICAL_DECISIONS.md
  tests/TEST_STRATEGY.md
```

Les autres dossiers de la structure cible (Services, Systems, Remotes,
Controllers, GUI, Workspace) seront créés avec leur premier fichier utile.

## Vérifications

| Vérification | Type | Résultat |
|---|---|---|
| Valeurs Backpack, Grabber, ressources, portée, vitesse identiques à la Bible | Script de comparaison ponctuel (hors dépôt) | Exécuté — identique |
| `default.project.json` | Analyse JSON | Exécuté — valide |
| Équilibre des délimiteurs et blocs Luau | Contrôle textuel grossier | Exécuté — rien d'anormal (ne remplace pas un analyseur) |
| Syntaxe et types Luau (`--!strict`) | Analyseur Luau | **Non exécuté** — outil absent |
| `ConfigTests` | Test automatisé dans Studio | **Non exécuté** |
| Lancement sans erreur dans Studio | Manuel | **Non exécuté** |

## Anomalies relevées dans les documents

| # | Constat | Traitement |
|---|---|---|
| A-01 | Bible 3.2 et 4.2 : valeurs moyennes annoncées 2,4 / 19,4 / 112 / 540. Recalcul avec les poids donnés : 2,24 / 20,42 / 105,1 / 562. | À corriger dans la Bible (décision propriétaire) |
| A-02 | Le MVP impose 3 ressources, la Bible en définit 5 pour Green Valley. Avec Green Leaf, Wood Chunk, Stone : moyenne 1,78 Coin/unité au lieu de 2,24. | Voir impact ci-dessous, D-003 |
| A-03 | Rareté de Stone : « Commune » (Bible) contre « Uncommon » (exemple architecture 8.1). | Bible appliquée |
| A-04 | Identifiant du bois : `wood` (architecture) ; nom « Wood Chunk » (Bible). | `wood_chunk` retenu, D-003 |
| A-05 | `magnetLevel = 0` dans le schéma de l'architecture 7.1 ; la Bible et le GDD démarrent le Magnet au niveau 1. | À trancher en T1 |
| A-06 | Schéma de données : GDD 15.5 (monnaies à plat, `unlockedWorlds` en liste) contre architecture 7.1 (`currencies{}`, `worlds{}` en dictionnaire). | À trancher en T1 |
| A-07 | Noms des modules : `EconomyConfig`, `ResourcesConfig`… (GDD, Bible) contre `GameConfig`, `ResourceConfig`… (architecture, CLAUDE.md). | Noms de l'architecture, D-002 |
| A-08 | `Main.server.lua` et `SellingService` (GDD) contre `Bootstrap.server.lua` et vente dans `EconomyService` (architecture). | Architecture appliquée, D-002 |
| A-09 | Ordre des phases : le GDD place Pets et événements avant la sauvegarde ; CLAUDE.md et l'architecture les reportent après le MVP. | CLAUDE.md appliqué, D-004 |
| A-10 | Bible section 2 : « Capacité d'équipement initial : 1 Pet » et « Pets équipables gratuits au départ : 2 ». | Hors MVP, à corriger avant le lot Pets |
| A-11 | Achat multiple x1/x10/x100/MAX (Bible 5.7) ; `RequestUpgrade` ne transporte que `upgradeId` (architecture 6.1). | x1 seul pour le MVP, à confirmer |
| A-12 | Golden Desert exige niveau de sac ET Coins (Bible 6) ; le GDD 7.3 déconseille les conditions simultanées. | Hors MVP, à trancher plus tard |
| A-13 | La Bible ne définit ni temps de réapparition, ni intervalle minimal de sécurité, ni tolérance de distance serveur. | Réapparition : exemple de l'architecture (hypothèse). Le reste en T2 |
| A-14 | Les documents se citent sous `docs/GDD.md`, `docs/ECONOMY.md`, `docs/TECHNICAL_ARCHITECTURE.md` ; les fichiers réels sont `docs/GRAB_AND_GROW_*_v1.0.md`. | Sans effet technique |
| A-15 | Le test MVP « Monde verrouillé » et le remote `RequestUnlockWorld` supposent un second monde, absent du MVP. | Décision en attente |

### Impact économique de A-02 (calcul théorique, sans déplacement)

| Indicateur | 3 ressources (MVP) | 5 ressources (Bible) |
|---|---|---|
| Valeur moyenne par unité | 1,78 | 2,24 |
| Valeur d'un sac de 50 | ~89 Coins | ~112 Coins |
| Revenu maximal théorique à 0,75 s | ~142 Coins/min | ~179 Coins/min |
| Première amélioration (Backpack 2, 100 Coins) | 2e vente | 1re vente |

La cible du GDD « première vente ou première amélioration en 30–60 s »
reste atteignable pour la vente (37,5 s de remplissage théorique), mais la
première amélioration glisse à la deuxième vente. La cible de revenu de
Green Valley (120–250 Coins/min) n'est atteinte qu'en haut de fourchette
théorique. À mesurer en T7 ; aucune valeur n'a été modifiée.

## Décisions en attente

1. Flux de travail fichiers → Studio : installer Rojo (recommandé) ou copie manuelle (D-001).
2. Initialiser Git (`git init`, `.gitignore`).
3. Installer un analyseur Luau (luau-lsp ou Luau CLI) pour valider hors Studio.
4. Confirmer les 3 ressources du MVP et l'identifiant `wood_chunk` (D-003).
5. Test « Monde verrouillé » : ajouter Golden Desert comme entrée verrouillée dans `WorldConfig`, ou reporter ce test après le MVP (A-15).
6. Corriger les moyennes de la Bible (A-01).

## Prochaine étape

Clôturer T0 (voir `ROADMAP.md`), puis T1 — profil joueur et sauvegarde.
