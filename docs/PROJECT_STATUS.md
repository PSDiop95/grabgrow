# GRAB & GROW — État du projet

Dernière mise à jour : 2026-11-22 (T10.2 et import des 20 ressources validés, D-032, D-033)

## Résumé

**T10.2 (VFX et animations des ressources) : VALIDÉE** le 2026-11-22
avec réserves (mobile, A23, deux joueurs réels non testés) (`phases/T10_2_VFX_REPORT.md`, D-032). Système VFX commun
aux 20 ressources (visuel local par nœud, présence par rareté, particules
et auras prêtées par pools, collecte orientée vers le joueur,
disparition et reconstruction pilotées par le serveur). Lune 447 cas OK,
LSP OK, tests Studio OK (solo). Non testés : deux joueurs réels, qualité
basse réelle, mobile, captures. Aucun import, économie, schéma ni
`GrabAndGrow.rbxl` modifié ; commit autorisé. T10.3 non commencée
(autorisation distincte requise).

**Import des 16 autres ressources : fait** le 2026-11-22 sur demande du
propriétaire (D-033) : 20/20 ressources en modèle Polyfork (GLB corrigés,
import manuel, `ServerStorage.ResourceTemplates` du place de test).
Contrôle visuel Studio fait (captures `performance/T10_2_captures/`) ;
mobile et Galaxy A23 non testés.

**T10.1 (prototype ressources, imports, V-01) : prototype VALIDÉ** le
2026-11-22 sur la base du test iPhone 12 Pro (D-031 ; réserve : mesure
Galaxy A23 non faite) (`phases/T10_1_REPORT.md`). V-01 corrigé et vérifié dans Studio
(primitives et modèles) ; prototype 4 ressources en jeu (gabarits
`ServerStorage.ResourceTemplates` du place de test, import manuel :
l'upload Open Cloud reste refusé). GLB corrigés par
`tools/fix_glb_colors.luau` (couleurs de sommets linéaire → sRGB) et
réimportés : 4 ressources en 1–2 pièces (72 MeshParts client). Feuille
recolorée en palette contrastée (visible sur l'herbe). Cristaux
d'améthyste agrandis (×1,6). Place sauvegardé dans
`places/T10_1_prototype.rbxl` ; `GrabAndGrow.rbxl`, écrasé par une
sauvegarde Studio, restauré depuis la version cloud 105 (identique au
commit T9). Reste : mesure A23 avant/après
(`performance/T10_1_BASELINE_A23.md`). Lune 440 cas OK, LSP OK, Rojo OK. Mesure A23 : NOT TESTED.
Schéma v3, économie, `StreamingEnabled` inchangés ; aucun commit.

**T10.0 (audit et conception World Enrichment) : VALIDÉE** par le
propriétaire le 2026-11-22, avec les décisions D-025 à D-030 : refonte des
20 ressources sur bases Polyfork personnalisées, licence CC BY 4.0, quatre
gardiens et quatre sites sacrés en combats **strictement individuels**,
accès permanent après victoire, ressources sacrées à double usage (vente
ou améliorations), **schéma v3 conservé**, aucune valeur économique avant
simulation. Documents : `phases/T10_0_AUDIT.md` (matrice finale §5),
`assets/T10_*`, `gameplay/T10_*`, `performance/T10_PERFORMANCE_BUDGET.md`.
Aucun code, schéma, économie, asset ni `GrabAndGrow.rbxl` modifié ; aucun
commit. **T10.1 non commencée** (mesure de référence Galaxy A23, tests
d'import GLB/FBX, prototype sur 4 ressources, correction V-01) : attend
l'autorisation du propriétaire. T10.2 à T10.4 interdites d'ici là.


**T9 (analytics et préparation à la publication) : VALIDÉE avec réserves** par le propriétaire le 2026-11-16 (« Valider en l'état », D-024). Réserves : onboarding, progression `Worlds`, dépense `World:*`, succès, `WorldEntered` et `BackpackFull` non observés dans Roblox (validés en Lune et Studio) ; Local Server analytics non testé ; correctif T9-UI-01 non contrôlé sur téléphone. La validation de T9 n'autorise pas la publication publique.
Étape A (audit) validée le 2026-11-16 avec D1 à D5 ; T8 clôturée avec
réserves (D1). Étape B construite le 2026-11-16 : `AnalyticsService`
centralisé (règles) et `AnalyticsSinks` (API Roblox), appelés par
`Bootstrap` après chaque opération confirmée ; `balanceAfter` dans les
résultats économiques ; documents `analytics/` et `publication/`. Lune 429
cas OK, LSP strict OK, Rojo OK, Studio solo OK (événements vérifiés dans
l'Output). Publication privée autorisée (D5) et faite le 2026-11-16 :
événements économiques et personnalisés reçus par Roblox, conformes
(PARTIAL : onboarding, progression et autres non encore observés). NOT
TESTED : Local Server analytics. Correction T9-UI-01 (bouton Journal
masqué quand la Boutique est ouverte). Aucun commit
(`phases/T9_ANALYTICS_PUBLICATION_REPORT.md`).

**T8 (mondes et contenu) : EN COURS** (D-021). Étape A validée par le
propriétaire le 2026-11-14 (`phases/T8_WORLD_AUDIT.md`). T8.0
(décisions, documentation, Bible 1.1, manifeste d'assets) et T8.1
(architecture des mondes, contrôle serveur du monde, voyage serveur)
autorisés ; rapport intermédiaire : `phases/T8_IMPLEMENTATION_REPORT.md`.
T8.0 et T8.1 validées (2026-11-14) sous réserve du test multijoueur, réussi
le jour même (Local Server, 2 joueurs). T8.2 (carte de Green Valley,
portails, interface de voyage) validée le 2026-11-15 ; T8.3 (Golden
Desert) autorisée et construite le 2026-11-15, testée en Studio à un
joueur et en Local Server à 2 joueurs, **validée** par le propriétaire le 2026-11-15 (`phases/T8_3_GOLDEN_DESERT_REPORT.md`). T8.0 à
T8.2 commitées (dd806ef) ; T8.3 commitée (33830ca). T8.4 (Frozen Peaks)
construite et testée en Studio à un joueur et en Local Server à 2 joueurs
le 2026-11-15, **validée** par le propriétaire le 2026-11-15 (`phases/T8_4_FROZEN_PEAKS_REPORT.md`) ; commitée (628e9a2).
T8.5 (Mystic World) construite et testée en Studio à un joueur et en
Local Server à 2 joueurs le 2026-11-15 (`phases/T8_5_MYSTIC_WORLD_REPORT.md`) ;
**validée** par le propriétaire le 2026-11-15 ; commitée (17e38ea) et
poussée le 2026-11-15 (vérifié le 2026-11-16 : `main` = `origin/main`).
T8.6 (Collection Journal, D-022) : étape A validée le 2026-11-16 ; schéma v3
et migration v2 -> v3, découverte atomique à la collecte, interface Journal
FR/EN, sans récompense ; construite et testée le 2026-11-16 (Lune, Studio à
un joueur, DataStore de test, Local Server à 2 joueurs) ; **validée** par le
propriétaire le 2026-11-16 ; commit local autorisé, sans push (`phases/T8_6_COLLECTION_JOURNAL_REPORT.md`,
`phases/T8_6_MIGRATION_TEST_REPORT.md`).

**T8.7 (stabilisation et validation globale) : VALIDÉE** par le propriétaire le 2026-11-16. Étape A (audit) validée le 2026-11-16 : aucun P0 ni P1. Étape B autorisée « avec P2-02 » : sauvegarde différée de 5 s après achat d'amélioration et déblocage de monde (D-023). Lune 401 cas OK, LSP strict OK, Rojo OK, simulation inchangée, Studio solo OK (quatre mondes), Local Server à 2 joueurs OK (11 scénarios, dont collecte et ventes simultanées), DataStore de test OK (12 cas : v3, D-023, reconnexion, migration v2, verrou, interruption, pannes). Réserves acceptées : contrôle visuel mobile, performance non mesurée (`phases/T8_7_STABILIZATION_REPORT.md`). Commit 5f63900, poussé (`main` = `origin/main`, vérifié le 2026-11-16). **T8 clôturée** par le propriétaire le 2026-11-16 (D-024 D1).

**T7 (progression et équilibrage) : VALIDÉE et CLÔTURÉE** (propriétaire,
2026-11-14, après test réel, D-020 ; commit 0b821a2, poussé). Backpack 2 à
75 Coins ; temps de jeu serveur (A-21) ; schéma v2 et 12 succès
permanents ; simulateur `tools/simulate_progression.luau`. 17 suites Lune
OK, luau-lsp 0 erreur, rojo build OK, Play Studio OK. Détail :
`phases/T7_IMPLEMENTATION_REPORT.md`.

**T6 (sécurité multijoueur) : VALIDÉE et CLÔTURÉE** (propriétaire,
2026-11-14, D-019 ; commit c199d85, poussé le 2026-11-14). MovementValidator,
PayloadValidator, SecurityLog, ProfileAudit ; 15 suites Lune OK,
luau-lsp 0 erreur, rojo build OK ; scénarios Studio à un joueur OK.
Local Server multi-joueurs : OK selon le propriétaire. Réserves : latence
mobile réelle (A-27), seuils R4 à calibrer, A-42.

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

**T3 est TERMINÉ** : clôturé par le propriétaire le 2026-11-12. Vente serveur atomique,
station de vente provisoire, HUD Coins. Tests automatisés (Lune et Studio)
et parcours Studio à un joueur OK. Tests manuels du propriétaire contrôlés
dans les journaux : E1, E2, E5 vérifiés ; E9 (DataStore de test) vérifié
par Claude ; E3, E4, E6 (2 joueurs, ventes simultanées), E8 et rendu 3D
exécutés par Claude et validés par le propriétaire (2026-11-12) ; E7
(émulateur mobile) : toucher réel validé en portrait et paysage ; E8
partiel accepté (manette physique reportée) ; A-34 et A-35 corrigés. Place de test sauvegardé avec la station corrigée et A-35 (version 25,
non publiée, 2026-11-12). Commit local T3 autorisé et créé (aucun push).
Copie locale `GrabAndGrow.rbxl` rafraîchie et vérifiée.
D-014 **validée** par le propriétaire (2026-11-11) ; paramètres de sécurité
de la vente validés provisoirement, à réévaluer en T6. Réserve acceptée :
E8 sur manette physique reporté.
Détail : `SELLING.md` et « Vérifications T3 » ci-dessous.

**T4 est TERMINÉ** (clôturé par le propriétaire le 2026-11-12) : cinq améliorations
achetables (Backpack, Grabber, Magnet, Boots, Multiplier), effets réels
côté serveur, déblocage des quatre mondes (sans contenu), `EconomyService`,
boutique client. Décisions du propriétaire au préflight : D-015 (périmètre
étendu, Magnet décalé d'un niveau, Multiplier arrondi à l'inférieur, ordre
strict des mondes). Tests automatisés (Lune et Studio) et parcours Studio à
un joueur OK. Tests manuels U1 à U9b validés (Studio, émulateur, téléphone
réel) ; U10 manette reporté. A-39, A-40, A-41 corrigés et validés. Commits
locaux 69fb421 et e63039d, aucun push. Détail : `UPGRADES.md`, `PROGRESSION.md`, « Vérifications T4 ».

**T5 est TERMINÉ** (clôturé par le propriétaire le 2026-11-13, D-018) :
HUD (T5.1), feedback audio et visuel (T5.2), première session (T5.3),
textes EN/FR (T5.4), validation multiplateforme (T5.5, téléphone réel et
PC déclarés validés). Réserves : manette, tablette réelle, performance non
chiffrée. Place de test version 56. Commit T5.5 non créé, aucun push.

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
    Config/UpgradeConfig.lua         Cinq améliorations (Bible 5.2–5.6, T4)
    Config/WorldConfig.lua           Quatre mondes ; seul GreenValley jouable (T4)
    Config/DataConfig.lua            Persistance : schéma v1, DataStore, reprises, verrou
    Util/TableUtil.lua               deepFreeze, deepCopy
    Util/Localization.lua            Textes en / fr par clé (provisoire, T2 ; vente T3)
    Util/SaleValue.lua               Formule de vente partagée (T3), Multiplier (T4)
    Util/UpgradeMath.lua             Lecture des tables d'amélioration (T4)
    Util/BagDisplay.lua              États d'affichage du sac (T5.1)
    Util/FeedbackRules.lua           Règles des retours audio/visuels (T5.2)
    Config/FeedbackConfig.lua        Sons, volumes, budgets d'effets (T5.2)
    Util/OnboardingRules.lua         Étapes du guidage de première session (T5.3)
    Config/OnboardingConfig.lua      Seuil et durées du guidage (T5.3)
    Remotes/Remotes.lua              RemoteEvents et codes de résultat (T2)
  ServerStorage/ServerOnlyConfig/
    CollectionSecurityConfig.lua     Marges de sécurité de la collecte, non répliquées (T2)
    SellSecurityConfig.lua           Marges de sécurité de la vente, non répliquées (T3)
    EconomySecurityConfig.lua        Limites des achats et déblocages (T4)
  StarterPlayer/StarterPlayerScripts/
    ClientBootstrap.client.lua       Point d'entrée client (T2)
    Controllers/InventoryController.lua   Affichage du sac
    Controllers/CollectionController.lua  Ciblage, entrées, retour visuel
    Controllers/SellController.lua   Prompt de vente, étiquette, retours (T3)
    Controllers/UpgradeController.lua Boutique et mondes (T4)
    Controllers/FeedbackController.lua Sons, effets, préférences (T5.2)
    Controllers/OnboardingController.lua Guidage de première session (T5.3)
  ServerScriptService/
    Bootstrap.server.lua             Point d'entrée serveur, magasin, branchement de la collecte
    Services/PlayerDataService.lua   Chargement, Update, sauvegarde, verrou de session
    Services/InventoryService.lua    Sac : état, capacité, ajout (T2)
    Services/CollectionService.lua   Validation serveur d'une collecte (T2)
    Services/RateLimitService.lua    Limite de fréquence par joueur et action (T2)
    Services/SellService.lua         Vente : validation et transaction unique (T3)
    Services/EconomyService.lua      Crédit, débit, journal (T4)
    Services/UpgradeService.lua      Achat des améliorations (T4)
    Services/WorldUnlockService.lua  Déblocage des mondes (T4)
    Systems/ResourceSpawner.lua      Nœuds, états, réapparition (T2)
    Systems/ResourceNodes.lua        Points de spawn -> Parts du Workspace (T2)
    Systems/SellZones.lua            Zones de vente du Workspace (T3)
    Systems/StudioTestPresets.lua    Préréglages des tests manuels U1–U10, Studio uniquement (T4)
    Systems/DataSchema.lua           Profil par défaut, intégrité, migrations
    Systems/MemoryDataStore.lua      Magasin en mémoire (tests, Studio)
    Systems/PlayerSession.lua        PlayerAdded, PlayerRemoving, sauvegarde auto, BindToClose
    Tests/ConfigTests.lua            Cohérence structurelle des configs
    Tests/DataSchemaTests.lua        Schéma, intégrité, migrations (18 cas)
    Tests/PlayerDataServiceTests.lua Chargement, sauvegarde, sessions (27 cas)
    Tests/InventoryServiceTests.lua  Sac (14 cas)
    Tests/ResourceSpawnerTests.lua   Nœuds et limite de fréquence (9 cas)
    Tests/CollectionServiceTests.lua Collecte, anti-exploit, multijoueur simulé (22 cas)
    Tests/SellServiceTests.lua       Vente, invariants, concurrence, persistance (25 cas)
    Tests/EconomyServiceTests.lua    Crédit, débit, arrondi du Multiplier (10 cas, T4)
    Tests/UpgradeServiceTests.lua    Achats, effets, concurrence, mondes, persistance, préréglages (23 cas, T4)
    Tests/HudTests.lua               États du sac, textes EN/FR (10 cas, T5.1)
    Tests/FeedbackTests.lua          Retours audio/visuels (14 cas, T5.2)
    Tests/OnboardingTests.lua        Guidage, parcours, reconnexion (21 cas, T5.3)
    Tests/LocalizationTests.lua      Couverture et typographie EN/FR (15 cas, T5.4)
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
| E7 | Émulateur mobile | Aucune trace exploitable dans les journaux (session 21:23:49, `+14 Coins`, non attribuable à un appareil) ; repris le 2026-11-12 (voir « Bilan final E7 / E8 ») | Voir bilan final |
| E8 | Manette | Aucune trace exploitable ; repris par Claude (voir « Bilan final E7 / E8 ») | Voir bilan final |
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

### Bilan final E7 / E8 (Claude, 2026-11-12)

Statut accepté par le propriétaire avant ces vérifications : E1–E6, E9,
rendu 3D et A-34 validés ; E7 et E8 partiels. Studio Play, profils en
mémoire, profil DataStore de test non touché. Aucun système économique ou
serveur modifié.

| # | Vérification | Résultat | Preuve |
|---|---|---|---|
| E8 | ButtonX près d'une ressource (simulé) | PASS : `Collect/SUCCESS`, sac 1 | Résultat client relu |
| E8 | ButtonX sur la dalle de vente | PASS : aucune vente déclenchée (X reste la collecte) | Aucun `ActionResult` Sell |
| E8 | ButtonY sur la dalle, sac 1 (simulé) | PASS : `Sell/SUCCESS +1` | Journal `[Sell] joueur 11975439775 : +1 Coins` |
| E8 | Manette physique | **NON TESTÉ** : aucune manette (`GamepadEnabled = false`, 0 connectée). Limite matérielle : E8 reste **PARTIEL** | — |
| E7 | Orientation | Jeu configuré en paysage (`StarterGui.ScreenOrientation = LandscapeSensor`) ; demande du propriétaire : paysage. L'émulateur Studio permet malgré tout le portrait | Propriété lue dans le client |
| E7 | Portrait (capture du propriétaire) | **FAIL → A-35** : bouton « Prendre » dans la zone du stick gauche (359 × 718, bouton en 79–169 / 510–600) | Capture du propriétaire |
| E7 | Paysage après correction A-35 (705 × 338, `LandscapeLeft`, `TouchEnabled`) | PASS : Grab 600–690 / 88–178 centré au-dessus du saut 610–680 / 190–260 ; stick dynamique x ≤ 282 ; sac 192–512 / 8–90 ; prompt tactile (`TextButton` 148 × 72) centré vers (447, 217), soit 373–521 / 181–253 : aucun chevauchement | Positions relues ; capture `E7_paysage_apres_vente.jpg` (dossier temporaire de session) |
| E7 | Prompt tactile affiché | PASS à 9,2 studs, station à l'écran (prompt masqué si la station est hors champ, comportement Roblox) | `PromptShown`, étiquette masquée |
| E7 | Vente | PASS : `Sell/SUCCESS +1`, sac 0, Coins 1, toast `+1 Coins` | Résultat client ; capture |
| E7 | Toucher réel du prompt et du bouton Grab | **NON TESTÉ** : l'outil MCP injecte des `Touch` non routés vers les boutons GUI (`GetGuiObjectsAtPosition` vide). Vente déclenchée par `InputHoldBegin` / `InputHoldEnd` (même événement `Triggered` que le toucher), collecte par la touche E | — |
| E7 | Captures | La capture de l'émulateur ne montre ni `TouchGui` ni prompt (CoreGui) ; une capture en portrait était sans 3D | `E7_capture_emulateur_sans_3D.jpg` |

Décisions du propriétaire (2026-11-12) : E8 **PARTIEL ACCEPTÉ** (X et Y
validés en simulation, manette physique reportée) ; A-35 acceptée
techniquement sous réserve du contrôle tactile ; E7 à compléter par le
toucher réel en portrait et paysage.

### E7 — toucher réel et A-35 (propriétaire et Claude, 2026-11-12)

Émulateur Studio, Play, profils en mémoire. Touchers réels du
propriétaire ; Claude relit un enregistreur client (entrées, prompts,
résultats) et le journal serveur.

| Orientation | Disposition (A-35) | Toucher « Prendre » | Toucher « Vendre » |
|---|---|---|---|
| Portrait 359 × 718 | Prendre 254–344 / 468–558, juste au-dessus du saut 264–334 / 570–640 (écart 12 px), côté droit ; sac 71–286 / 8–90 | PASS : 5 × `GRAB Touch` → 5 × `Collect/SUCCESS` | PASS : `TRIGGERED SellPrompt` (toucher) → `Sell/SUCCESS +9` (green_leaf 4, stone 1, wood 1, exact) ; second toucher → `NOTHING_TO_SELL` ; une seule ligne `[Sell]` |
| Paysage 705 × 338 | Prendre 600–690 / 88–178 au-dessus du saut 610–680 / 190–260 ; stick x ≤ 282 ; prompt 373–521 / 181–253 : aucun chevauchement | PASS : 4 touchers, 3 × `Collect/SUCCESS` (le 4e sans réponse : hors cadence ou sans cible, aucun crédit) | PASS : `TRIGGERED SellPrompt` (toucher) → `Sell/SUCCESS +4` (green_leaf 2, wood 1, exact) |

En portrait, la zone du stick dynamique de Roblox
(`DynamicThumbstickFrame`) couvre tout le bas de l'écran, bouton de saut
compris ; les boutons captent leurs touchers (`Touch (gui)` journalisé),
le stick reste utilisable à gauche.

**E7 : PASS** (portrait et paysage, toucher réel). **A-35 : PASS**
(portrait et paysage). **E8 : PARTIEL ACCEPTÉ** (manette physique
reportée).

### Clôture de T3

**Clôturé par le propriétaire le 2026-11-12.** Réserve acceptée : E8 sur
manette physique reporté (X et Y validés en simulation).

### Sauvegarde du place et commit (2026-11-12, autorisés par le propriétaire)

| Contrôle | Résultat |
|---|---|
| Synchronisation Rojo, avant sauvegarde | Mode Edit ; 35 / 35 scripts du place identiques au dépôt (empreinte, fins de ligne normalisées), aucun script en trop ou manquant ; `DataConfig` `useMemoryStore = true` |
| Station dans le place | `Workspace.SellZones.GreenValley` : `SellZonePad` (`GreenValley_Main`), comptoir, poteaux, toit, pièce ; 36 points de spawn ; pas de `ResourceNodes` (nœuds d'exécution absents) |
| `save_place` | **Version 24** sur Roblox (Team Create), non publiée (station, A-34) |
| `save_place` après A-35 (commit `e2090c4`) | 35 / 35 scripts du place identiques au dépôt (empreinte), `useMemoryStore = true`, station présente, pas de `ResourceNodes` ; **version 25** sur Roblox (Team Create), non publiée |
| Copie locale `GrabAndGrow.rbxl` après A-35 | Rafraîchie par le propriétaire (2026-11-12 11:17:53 UTC, 142 428 octets). Contrôle Lune : station complète (`GreenValley_Main`), 36 points de spawn (16 / 12 / 8), pas de `ResourceNodes`, 35 / 35 scripts identiques au dépôt (empreinte), `CollectionController` avec A-35, `useMemoryStore = true`. Non versionnée (D-013) |
| Profil DataStore de test | Non touché (11 Coins, 2 feuilles) |
| Copie locale `GrabAndGrow.rbxl` | Rafraîchie par le propriétaire (2026-11-12 10:37 UTC, 141 092 octets). Contrôle Lune : `SellZones.GreenValley` complet (`SellZonePad` `GreenValley_Main`), 36 points de spawn (16 / 12 / 8), pas de `ResourceNodes`, 35 / 35 scripts identiques au dépôt (empreinte), `DataConfig` compris (`useMemoryStore = true`) |

## Vérifications T4 (2026-11-12)

### Automatisées

| Vérification | Résultat |
|---|---|
| Lune (`lune run tools/run_tests.luau`) | Exécuté — `TOUS LES TESTS : OK` : 155 cas et ConfigTests (32 cas T4 nouveaux, 1 cas DataSchema nouveau) |
| Mêmes suites dans Studio (Play, magasin en mémoire) | Exécuté — `TOUS LES TESTS : OK` |
| `luau-lsp analyze` (strict, définitions Roblox) | Exécuté — 0 erreur, 0 avertissement |
| `rojo build` (vers un fichier temporaire, copie locale intacte) | Exécuté — OK |
| Synchronisation Rojo | Exécuté — nouveaux modules présents dans Studio ; `UpgradeController` identique au dépôt (19 042 octets) |
| Contrôle négatif : débit supprimé ; portée et vitesse figées | Exécuté — 18 et 2 échecs détectés, code restauré |
| Régressions T1, T2, T3 (suites existantes) | Exécuté — OK |

### Dans Studio, un joueur (Play piloté par MCP, magasin en mémoire)

| Vérification | Résultat |
|---|---|
| Achat Backpack sans fonds | `INSUFFICIENT_FUNDS`, rien dépensé |
| Payload falsifié `{ upgradeId, price = 0, level = 16 }` | `INVALID_TARGET` |
| Golden Desert et Frozen Peaks sans prérequis | `REQUIREMENT_NOT_MET` |
| Collecte, 4 ventes (132 Coins), achat Backpack | `SUCCESS`, −100, solde 32, capacité 75, niveau 2 ; journal `motif Upgrade:Backpack, opération Upgrade-1` |
| Suite de ventes, achat Boots | `SUCCESS`, −250 ; `Humanoid.WalkSpeed` 16 → 16,5 vu du client |
| `ShopUI` créé côté client | Oui |

Les avertissements « déplacement implausible » de ce parcours viennent du
script de test (téléportation entre nœuds) : contrôle anti-exploit actif.

### Préparation des tests manuels (2026-11-12, accord du propriétaire)

- Préréglages de profil `StudioTestPresets` (reset, U1 à U9), branchés
  seulement dans Studio (`ServerStorage.StudioTestHooks.ApplyPreset`) ;
  testés en Lune (1 cas) et dans Studio : `U9`, `U8` appliqués, préréglage
  inconnu refusé ; boutique client : « Manque 1500 », prix payables, Golden
  Desert masqué (débloqué), Frozen Peaks « Débloquer » ; WalkSpeed 16,5.
- Fiche U1 à U10 avec environnement (Studio, émulateur, appareil réel,
  manette physique) et procédure U8 sur DataStore de test :
  `tests/TEST_STRATEGY.md`.
- Aucun paramètre économique modifié ; `GrabAndGrow.rbxl` non touché ;
  `useMemoryStore = true`.

### Scénarios U1 à U10 exécutés par Claude dans Studio (2026-11-12)

Play sur PC (fenêtre 1630 × 734), préréglages `StudioTestPresets`. Achats
et ventes envoyés par les RemoteEvents réels (même chemin serveur que
l'interface) ; U7 et U9 par vrais clics souris (outil Studio) ; U10 par
touches injectées. Simulation : ni téléphone, ni émulateur, ni manette.

| # | Résultat | Constat |
|---|---|---|
| U1 | OK | −100, Coins 0, capacité 75 ; toast « Amélioré ! » ; 75 collectes réelles (MoveTo) : sac 75/75, « Sac plein ! », puis 2 refus `INVENTORY_FULL`, rien perdu |
| U2 | OK | Sonde 2 ressources à 0,63 s d'écart : avant achat `SUCCESS,COOLDOWN`, après `SUCCESS,SUCCESS` ; cadence d'état 0,70 s ; −150. Mesure 20 s : 21 puis 21 (limitée par les déplacements, pas par la cadence) |
| U3 | OK | Ressource à 12,60 studs : aucune cible avant, cible (`stone_002`) après ; portée 14 ; −200 |
| U4 | OK | WalkSpeed 16 → 16,5 ; 16,5 après mort et réapparition ; vitesse mesurée 16,50 studs/s ; −250 |
| U5 | OK | Vente +60 (`base 60 x1`) ; après achat (−300, solde 0) +63 (`base 60 x1.05`) |
| U6 | OK | Boutons « Manque 50 à 250 » ; 5 × `INSUFFICIENT_FUNDS`, toast « Pas assez de Coins » ; Golden Desert `REQUIREMENT_NOT_MET` ; Coins 50 |
| U7 | OK | Verrouillé : statut rouge, clics → `REQUIREMENT_NOT_MET`, toast « Verrouillé ». Prêt : 1er clic « Confirmer ? » sans envoi, 2e clic `SUCCESS`, « Monde débloqué ! », Coins 0, « Débloqué · Contenu à venir », Mondes 2/4 ; Frozen Peaks « Sac à dos niv. 8 · 35000 Coins » |
| U8 | OK | DataStore de test `GrabAndGrow_PlayerData_v1_Studio` (`useMemoryStore = false` le temps du test, puis remis à `true`, vérifié dans Studio) : après Stop puis Play, même état (1 000 Coins, niveaux 5/2/1/2/2, Golden Desert, sac 5/180, 16,5) ; `lastSaveAt` 1794432687 → 1794490886 ; verrou précédent libéré. Aucune écriture en production |
| U9a | OK | PC (Claude) : ouverture par clic, Grabber « MAX » doré, Backpack « Manque 100 », Magnet / Boots / Multiplier payables (verts), défilement molette jusqu'à Mystic World, achat Magnet `SUCCESS`, fermeture X. Émulateur paysage et portrait : testé par le propriétaire (2026-11-12), aucun défaut signalé (A-39) |
| U9b | OK | Téléphone réel, propriétaire (2026-11-12), place de test publié (version T4, profil neuf, DataStore de l'expérience de test, option B acceptée) : rendu, icônes, placement des boutons, états « Manque N » OK. États MAX et payable non couverts sur appareil (couverts en Studio) |
| U10a | PARTIEL | DPadUp ouvre, ButtonB ferme. Sélection du 1er bouton non testable : aucune manette connectée (`GamepadEnabled = false`, entrée vue comme clavier) |
| U10b | REPORTÉ | Décision du propriétaire (2026-11-12) : manette non testée en T4 |

### Non exécutées

- U10 manette (sélection du 1er bouton, achat par A) : reporté par le
  propriétaire (2026-11-12).

### Contrôle du diff avant commit (2026-11-12)

- Tables Backpack, Grabber, Magnet (décalage D-015), Boots, Multiplier et
  coûts des 4 mondes identiques à la Bible (5.2 à 5.6, 6) ; Bible : notes
  seulement, aucune valeur modifiée.
- `useMemoryStore = true` ; noms des DataStores inchangés ; préréglages et
  `StudioTestHooks` branchés seulement si `RunService:IsStudio()`.
- Lune : TOUS LES TESTS OK ; luau-lsp strict : 0 erreur ; `git diff
  --check` : propre. `GrabAndGrow.rbxl` non modifié.
- Place de test publié par le propriétaire avec ce code (U9b, A-41).
- Deux joueurs réels (Local Server) : simulé seulement.
- Magnet : effet vérifié (U3), non perçu en jeu par le propriétaire (A-40).

## Vérifications T5.1 — HUD (2026-11-12, TERMINÉ)

**T5.1 est TERMINÉ** : clôturé par le propriétaire le 2026-11-12 après
un test sur téléphone réel jugé OK (constat du propriétaire, détail des
appareils non communiqué).

Lot client seulement : aucun service serveur, aucune valeur économique,
aucun schéma modifié. Détail : `phases/T5_PREFLIGHT.md`, section 9.

| Vérification | Type | Résultat |
|---|---|---|
| Lune : toutes les suites, dont `HudTests` (10 cas, nouveau) | Automatisé, terminal | Exécuté — `TOUS LES TESTS : OK`, code de sortie 0 |
| Contrôle négatif : 7 défauts introduits dans `BagDisplay` (seuil, règle « plein », invitation, pastille, couleur, capacité codée en dur, clé absente) | Lune | Exécuté — 7 détectés sur 7 |
| `luau-lsp analyze` sur `src/` (`--!strict`) | Terminal | Exécuté — 0 erreur, code de sortie 0 |
| `rojo build` (fichier temporaire) | Terminal | Exécuté — réussi |
| Suites dans Studio (Play) | Studio | Exécuté — `TOUS LES TESTS : OK` |
| Synchronisation Rojo | Studio | Exécuté — 47 / 47 scripts identiques au dépôt |
| Collecte, presque plein, plein, refus `INVENTORY_FULL`, vente, Boutique, doublons après réapparition | Studio, piloté par MCP | Exécuté — OK (détail : `phases/T5_PREFLIGHT.md`, section 9) |
| Formats : PC 990 × 512, téléphone tactile 801 × 413, tablette 1179 × 819, PC 16:9 à l'échelle | Studio, émulateur | Exécuté — aucun chevauchement ; Boutique sous le sac |
| Téléphone petit et grand à leurs proportions réelles | Émulateur | Non exécuté — réglage non appliqué par Studio (3 essais) |
| Téléphone réel | Manuel, propriétaire | **OK** (constat du propriétaire, 2026-11-12) |
| Défauts trouvés et corrigés : remplissage sous l'icône, contraste « Sac plein ! » | Studio | Corrigés et revérifiés |
| Sauvegarde du place de test (accord du propriétaire) | Studio | **Version 41** (Team Create), non publiée ; avant sauvegarde : 47 / 47 scripts identiques au dépôt, `useMemoryStore = true`, station présente, pas de `ResourceNodes` |
| Commit local (accord du propriétaire) | Git | `feat(hud)` T5.1 ; aucun push |

## Vérifications T5.2 — Feedback audio et visuel (2026-11-12, TERMINÉ)

Clôturé par le propriétaire le 2026-11-12 : test sur téléphone réel
réalisé et validé. Décisions D-8 et D-9 :
recommandations en place (préférences en session, section dans la
boutique), sans décision explicite consignée.

Détail : `phases/T5_PREFLIGHT.md` section 10 ; sons :
`assets/SOUND_MANIFEST.md`. Aucun service serveur, schéma, prix ou effet
d'amélioration modifié (`git status` : seuls Localization, RunTests,
ClientBootstrap, InventoryController, UpgradeController modifiés ;
4 fichiers de code nouveaux).

### Automatisées

| Vérification | Résultat |
|---|---|
| Lune, 11 suites (`FeedbackTests` : 14 cas nouveaux) | Exécuté — `TOUS LES TESTS : OK` |
| Contrôle négatif : 7 défauts introduits dans `FeedbackRules` (refus traité comme succès, anti-doublon supprimé, son coupé ignoré, montant = quantité, budget négatif, volume réduit ignoré, son à la baisse) | Exécuté — 7 / 7 détectés (1 à 13 échecs), code restauré |
| `luau-lsp analyze` (strict) | Exécuté — 0 erreur, code de sortie 0 |
| `rojo build` (fichier temporaire) | Exécuté — OK |
| Suites dans Studio (Play) | Exécuté — `TOUS LES TESTS : OK` |
| Synchronisation Rojo | Exécuté — 51 / 51 scripts identiques au dépôt (taille sans fins de ligne) |

Les tests automatisés prouvent quel retour est demandé, pas le rendu réel
d'un son.

### Dans Studio, un joueur (Play, magasin en mémoire, demandes par les RemoteEvents réels)

Compteurs relus sur les attributs de `PlayerGui.FeedbackFX`.

| # | Vérification | Résultat |
|---|---|---|
| 1 | Collecte green_leaf, wood, stone | 3 `SUCCESS` → 3 sons `collect`, 3 éclats ; 3 instances par éclat ; 0 instance après 1 s |
| 2 | Collecte refusée | Sac plein : `INVENTORY_FULL` → son `bag_full` seul ; aucun éclat |
| 3-4 | Vente (U5) | `SUCCESS`, `coinsEarned = 60` ; `LastSaleAmount = 60`, toast « +60 Coins », journal serveur `+60` ; 6 pièces de (482, 271) vers l'icône Coins (378, 55), détruites en 0,7 s ; ligne Coins impulsion + blanc → or ; `sell` puis `coins` |
| 5 | Vente sac vide | `NOTHING_TO_SELL` → `refuse` seul, aucun visuel |
| 6 | Achats Backpack, Grabber, Magnet, Boots, Multiplier | 5 `SUCCESS` → 5 sons `upgrade`, 5 anneaux (détruits), toasts « avant → après » ; Magnet : 1 seul anneau 3D (A-40) |
| 7 | Achats refusés | `INSUFFICIENT_FUNDS` ×3, `MAX_LEVEL` (U9) → `refuse`, aucun anneau |
| 8 | Monde | `REQUIREMENT_NOT_MET` (U7_locked) → `refuse` ; `SUCCESS` (U7_ready) → son `world`, 12 confettis, contour ; toast « Golden Desert débloqué ! » ; rien ne reste après 1,4 s |
| — | Sac presque plein / plein (U5 + 20 collectes) | 40/50 : 1 `bag_warning` ; 41–49 : aucun ; 50/50 : 1 `bag_full` ; 3 refus en 2,4 s : 1 son de plus, 2 doublons écartés |
| 9 | Son désactivé | Groupe Master à 0 ; vente et collecte : 0 son joué (`IsPlaying` max 0), compteurs inchangés ; visuels conservés |
| 10 | Effets réduits | Vente : 3 pièces au plus ; éclat de collecte sans déplacement ; montant inchangé (80 = journal serveur) |
| — | Boutons Paramètres (clic souris réel) | Son : Activé → Désactivé (Master 0) → Activé |
| 11 | Nettoyage | `ClientFeedbackEffects` et `FeedbackFX` à 0 descendant après chaque scénario ; `SoundService.SFX` : 9 sons, constant |
| 12 | Doublons | Une réponse = un son et un visuel (compteurs) ; doublons simulés en Lune |
| — | Erreurs | Aucune erreur du jeu ; seule : asset d'avatar 203785492 (étrangère) |

Capture : section Paramètres de la boutique (dossier de session, non
versionnée). Effets en mouvement **non capturés** (durée < 1 s, capture
non synchronisable par l'outil).

### Non exécutées

| Vérification | Raison |
|---|---|
| Écoute des sons (volume, confort, superposition) | Couvert par le test sur téléphone réel validé par le propriétaire (2026-11-12) |
| Téléphone en paysage, tablette (émulateur) | Émulateur non pilotable par MCP ; à faire par le propriétaire |
| Téléphone réel | **Fait** : validé par le propriétaire (2026-11-12) |
| Manette | Aucune manette (comme E8, U10) |
| FPS sur appareil modeste | Non mesuré ; budget : ≤ 6 éclats (3 instances chacun), 1 volée de pièces à la fois, aucune boucle par frame ajoutée |
| Deux joueurs | Effets locaux (chaque client ne réagit qu'à ses propres `ActionResult`) ; non testé en Local Server |

## Vérifications T5.3 — Première session et guidage (2026-11-13, TERMINÉ)

Implémenté ; validé et clôturé par le propriétaire sur l'émulateur (2026-11-13).
Réserve reprise en T5.5 : parcours nouveau joueur sur téléphone réel.
D-10 acceptée (D-017). Commit local autorisé. Parcours nouveau joueur sur
téléphone réel non refait (compte de production déjà avancé).
Détail : `ONBOARDING.md`. Aucune valeur économique, règle de collecte, de
vente ou d'achat, ni schéma de profil modifiés ; aucun RemoteEvent ajouté.
Un changement serveur (D-10, acceptée : D-017) : `progress` dans l'état client.

### Automatisées

| Vérification | Résultat |
|---|---|
| Lune, 12 suites (`OnboardingTests` : 21 cas nouveaux ; `UpgradeServiceTests` adapté aux préréglages `O_*`) | Exécuté — `TOUS LES TESTS : OK` |
| Contrôle négatif : réponse sans `SUCCESS` acceptée + événement signalé sans changement d'étape | Exécuté — 6 échecs détectés, code restauré |
| `luau-lsp analyze` (strict) | Exécuté — 0 erreur, code de sortie 0 (après chaque correction) |
| `rojo build` (fichier temporaire) | Exécuté — OK |
| Suites dans Studio (Play) | Exécuté — `TOUS LES TESTS : OK` |
| Synchronisation Rojo | Exécuté — 3 fichiers nouveaux et contrôleur corrigé identiques au dépôt (taille sans fins de ligne) |

Cas couverts par `OnboardingTests` (services réels, magasin en mémoire) :
nouveau joueur, première collecte, demande sans confirmation, première
vente (avant le seuil), premier achat, plusieurs achats possibles, étape
déjà faite, déjà vendu, déjà acheté (dépense ou niveau), déblocage de
monde, déconnexion pendant collecte / vente / amélioration (ReleasePlayer
puis rechargement), reconnexion après la fin et non-régression, double
confirmation, refus réels (`NOTHING_TO_SELL`, `INSUFFICIENT_FUNDS`,
`TOO_FAR`) et réponses falsifiées, progression illisible, masquage,
textes EN/FR (présence, longueur, motifs), appareils.

### Dans Studio, un joueur (Play, magasin en mémoire, RemoteEvents réels, locale fr)

| Parcours | Résultat |
|---|---|
| A — Nouveau joueur | OK — accueil 👋 (≈ 5 s, visible pendant le chargement), « Étape 1/3 » + « Maintiens E ou clique sur une ressource », ▼ sur la ressource ; 1re collecte `SUCCESS` → 2/3 « Continue de remplir » ; à 10 → « Vends tes ressources ! », ▼ sur `SellZonePad`, flèche de bord ; près du stand : repères effacés ; vente `SUCCESS` +15 → « Belle vente ! +15 Coins » puis 3/3 « encore 85 Coins » ; (préréglage `O_sold_rich`) « Utilise tes Coins… » + ▶ sur Boutique ; boutique ouverte : carte masquée, ▶ sur Backpack seul (seul payable) ; achat `SUCCESS` niveau 2 → « Sac à dos niveau 2 ! … », flèches retirées, plus rien après 6 s |
| B — Joueurs avancés | OK — `O_sold` → directement 3/3 ; `O_upgraded` → aucun guidage ; `O_collected` ensuite → aucun retour en arrière |
| C — Déconnexion | **Automatisé seulement** (Lune, services réels). Studio : profils en mémoire perdus à l'arrêt, une seule session par place ; non rejoué sur DataStore de test |
| D — Liberté | OK — × (clic souris réel) : carte et repères masqués, « ? Guide » affiché ; collecte par la touche E réelle (4 ressources) ; carte revenue à l'étape suivante ; « ? Guide » la réaffiche |
| Réapparition du personnage | OK — une seule instance de `OnboardingUI` et `OnboardingMarker` |
| Erreurs | Aucune ; seule : asset d'avatar 203785492 (étrangère) |

### Corrections pendant les tests Studio

- L'accueil se terminait pendant le chargement (`task.delay` de 5 s écoulé
  avant l'affichage du monde) : décompte lancé après `game.Loaded` et
  l'apparition du personnage.
- Position de la carte : `GetGuiInset` vaut 0 au démarrage ;
  `TopbarInset` suivi en plus (carte sous la barre Roblox).
- Glyphes ✕, ➤, ✔ affichés en carré ou gris : remplacés par ×, →, 💰, 🎉
  (test de rendu de 15 glyphes).

### Captures (dossier de session, non versionnées)

Accueil (pendant le chargement), étape 1/3, étape 2/3 avec flèche de bord
(avant correction des glyphes), boutique ouverte avec ▶ sur Backpack.
Dossier : `~/.claude/projects/D--Projet-grabgrow/<session>/tool-results/`.
Les dernières captures Studio montraient un monde noir (fenêtre sans
focus) : caméra et personnage vérifiés normaux.

### Test mobile du propriétaire (2026-11-13)

- Retour : « je ne vois pas le tuto sur mobile ». Causes possibles : place
  publié sans T5.3, ou profil de production déjà avancé (étape
  `COMPLETED`, guidage masqué par conception). Lecture du profil de
  production refusée par le garde-fou de Claude : non vérifié.
- Ajout d'une ligne de diagnostic client, une fois par session :
  `[Onboarding] étape de départ : … (collectes, ventes, Coins dépensés)`
  (console développeur, `/console`).
- Publication autorisée par le propriétaire : synchronisation Rojo
  contrôlée (55 / 55 scripts identiques), place sauvegardé en version 53.
  La publication elle-même est à faire par le propriétaire (l'outil ne
  publie pas).
- Publié par le propriétaire. Console du téléphone : étape de départ
  `COMPLETED` → profil de production déjà avancé ; guidage masqué comme
  prévu (cause confirmée). Parcours « nouveau joueur » sur téléphone réel
  encore à faire (autre compte ou réinitialisation autorisée).
- **Parcours nouveau joueur validé sur l'émulateur d'appareils de Studio**
  (propriétaire, 2026-11-13).

### Non exécutées

| Vérification | Raison |
|---|---|
| Téléphone réel, paysage | À faire par le propriétaire (`tests/TEST_STRATEGY.md`, « Tests manuels T5.3 ») |
| Tablette, téléphone (émulateur) | Émulateur non pilotable par MCP (constaté en T5.1) |
| Manette | Aucune manette (comme E8, U10) |
| Reconnexion réelle (DataStore de test) | Non demandée ; couverte par simulation |
| Deux joueurs | Guidage local à chaque client ; non testé en Local Server |
| Chevauchement avec la fenêtre du chat Roblox ouverte | Non vérifié ; le chat s'ouvre en haut à gauche, comme la carte |

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
| A-17 | Table Magnet de la Bible (niveau 1 gratuit à 12 studs) à réaligner sur `magnetLevel = 0` | **Décidée** (D-015, propriétaire, 2026-11-12) : niveau k = ligne k + 1, maximum 9 ; note ajoutée à la Bible 5.4 |
| A-36 | Projection : niveaux au-delà de 5 rentabilisés en dizaines d'heures tant que Green Valley est le seul monde jouable ; Golden Desert à ≈ 85 min (actif) | **Réduite en T7, validée** (D-020) : cause structurelle (mondes 2 à 4 vides) ; succès permanents et Backpack 2 à 75 ; Golden Desert 1,8 -> 1,5 h, Backpack 8 10,6 -> 8,4 h (régulier, projection). Plateau après 2 à 4 h maintenu jusqu'au contenu de Golden Desert (`phases/T7_PROGRESSION_AUDIT.md`) |
| A-37 | `WalkSpeed` fixé par le serveur mais modifiable localement par un client tricheur ; la collecte reste bornée par la vitesse des Boots du profil | **Réduite en T6, validée** (2026-11-14) (D-019) : vitesse observée comparée aux Boots du profil ; speed hack ≤ ~2 × la vitesse de référence non détecté |
| A-40 | Magnet : achat sans effet perçu (retour du propriétaire, U3). Effet réel vérifié dans Studio (`U3` : ressource à 12,6 studs hors portée avant achat, collectée après) mais faible (+2 studs, valeur de la Bible) et sans retour visuel de la portée | **Corrigé en T4, validé** (décision options 1 + 2 puis validation du propriétaire, 2026-11-12) : message d'achat « valeur avant → après » pour les 5 améliorations, EN/FR (`Sac 50 → 75`, `Délai de collecte 0,75 → 0,7 s`, `Portée 12 → 14 studs`, `Vitesse 16 → 16,5 studs/s`, `Valeur de vente x1 → x1,05`, vérifiés par achats réels dans Studio) ; anneau de portée temporaire (Magnet seulement, rayon 14,00 = portée, au sol, détruit à 2,5 s, sans boucle). Messages déplacés dans `NotificationsUI` (DisplayOrder 10) : ils étaient cachés par le panneau Boutique. Aucun changement serveur, économique ni de collecte. Émulateur Studio (téléphone paysage) : captures OK ; téléphone réel non testé |
| A-38 | Icônes de la boutique en glyphes Unicode (rendu OK sur un téléphone réel, U9b, 2026-11-12 ; autres appareils non vérifiés) ; noms de mondes identiques en anglais et en français | Phase UX (T5) |
| A-18 | GDD 15.5 et 20 non alignés sur D-004 et D-006 ; l'exemple de l'architecture 8.1 indique encore Stone « Uncommon » | Prochaine révision des documents |
| A-20 | Le prompt T1 cite `docs/GRAB_AND_GROW_ECONOMY_v1.0.1.md` ; le fichier réel est `..._v1.0.md` (contenu 1.0.1, en-tête encore « Version : 1.0 ») | Sans effet technique |
| A-21 | `stats.playTimeSeconds` existe dans le schéma mais aucun système ne l'alimente | **Corrigée en T7, validée** (D-020) : `PlayTimeTracker`, ajout avant chaque écriture, sans écriture supplémentaire ; 15 tests automatisés ; non vérifié sur DataStore réel |
| A-22 | Messages d'expulsion (`PlayerSession`) en anglais brut, non localisés | **Corrigé en T5.4, validé** (propriétaire, 2026-11-13) : clés `system.kick.*` EN/FR, traduites avec `Player.LocaleId` ; règles d'expulsion inchangées. Vérifié dans Studio (fr-fr) : `Server Kick Message: Votre session a été ouverte sur un autre serveur.` |
| A-19 | Première amélioration (100 Coins) atteinte à la 2e vente avec 3 ressources (sac ≈ 89 Coins) ; revenu théorique maximal ≈ 142 Coins/min pour une cible de 120–250 | **Corrigée en T7, validée** (D-020) : Backpack 2 à 75, payable après la 1re vente (projection 1,3 à 2,1 min) ; à mesurer en test privé |
| A-23 | `rojo serve` lancé avant T2 ne prenait pas en compte les nouvelles entrées de `default.project.json` (`ServerStorage`, `StarterPlayer`) | **Levée** le 2026-11-11 : `rojo serve` relancé, plugin reconnecté par le propriétaire ; dans Studio, 29 scripts identiques au dépôt (empreinte comparée), aucun doublon |
| A-24 | La carte de test n'existait que dans le place ouvert, non enregistré | **Levée** le 2026-11-11 : carte reconstruite par script, place de test sauvegardé en version 15 (non publié), copie locale `GrabAndGrow.rbxl` contenant la carte vérifiée (18:59 UTC). Non versionnée dans Git (D-013) : sauvegarde de travail locale |
| A-25 | Ressources inconnues de `ResourceConfig` conservées par D-008 | **Décidée** (propriétaire, 2026-11-11, D-012) : conservées, et comptées dans l'occupation du sac pour empêcher tout dépassement de capacité. Comportement actuel, documenté dans `COLLECTION.md`. Vente (T3, D-014) : jamais vendues ni supprimées ; `NOTHING_TO_SELL` si elles sont seules |
| A-31 | `EconomyService` de l'architecture (5.4, 9.3) non créé : le crédit de la vente vit dans la transaction de `SellService` | **Résolue en T4** (D-015) : `EconomyService.credit` / `debit`, utilisés par la vente, les achats et les déblocages |
| A-32 | Distance de vente (10 studs), marge (4) et limite (rafale 3, 1/s) absentes de la Bible | **Validées provisoirement** (propriétaire, 2026-11-11, D-014) : configurables, à réévaluer en T6 |
| A-33 | Pas de son ni d'effet de pièces à la vente (GDD 13.4) | Phase UX, avec A-29 |
| A-34 | Près de la station, l'étiquette « Vente » (BillboardGui, décalage 9) apparaît derrière le panneau du sac en haut de l'écran : lisibilité réduite | **Corrigé en T3** (décision du propriétaire, 2026-11-12) : `SellController` masque l'étiquette tant que le prompt de vente est affiché (`PromptShown` / `PromptHidden`, sans boucle). Vérifié dans Studio : masquée à 6,2 studs, visible à 12,3 et 15,4 studs sans chevauchement du HUD ; vente F toujours OK (`NOTHING_TO_SELL`, sac vide). **Validé** par le propriétaire (2026-11-12) |
| A-41 | Téléphone : le panneau du sac (en haut au centre) masque le texte du chat Roblox, en haut à gauche (constat du propriétaire, appareil réel, 2026-11-12) | **Corrigé en T4, validé** (téléphone réel, propriétaire, 2026-11-12) : essai en haut à droite refusé par le propriétaire (« le sac doit être centré et en haut au milieu », capture du 2026-11-12) ; 2e capture : sac monté dans la bande de la barre Roblox, zone annotée par le propriétaire (`IgnoreGuiInset = true`, 8 px du bord, toast juste dessous) ; sac en haut au centre, largeur réduite de 60 % à 45 % de l'écran (170 à 300 px, auparavant 200 à 320), ligne Coins réduite plutôt que tronquée ; `UpgradeController` place Boutique à gauche de Prendre si le sac gêne au-dessus. Vérifié dans Studio (705 × 280, bande 58 px) : sac centré (centre 352 / 352), à 8 px du bord réel, Boutique au-dessus de Prendre sans chevauchement pour les positions réalistes. **Reste** : chat ouvert sur téléphone, recouvrement réduit mais pas supprimé (fenêtre du chat ≈ 50 % de la largeur, valeur Roblox supposée) ; écran très bas, Boutique à gauche de Prendre peut toucher le coin du sac |
| A-39 | Mobile paysage : bouton « Boutique » (bord droit, 38 % de la hauteur) posé sur le bouton « Prendre » (constat du propriétaire, émulateur, 2026-11-12) | **Corrigé en T4, validé** (U9a émulateur, propriétaire, 2026-11-12) : `UpgradeController` place Boutique juste au-dessus de Prendre (écart 12 px), ou à sa gauche si la place manque ; position fixe d'origine quand Prendre est masqué (PC). Vérifié dans Studio (positions de Prendre simulées, écran 705 × 280) : aucun chevauchement avec Prendre, bouton toujours à l'écran. Aucun chevauchement signalé |
| A-35 | Mobile portrait : bouton « Prendre » placé à 190 px du bord droit, donc dans la zone du stick gauche sur un écran étroit (constat du propriétaire, émulateur) | **Corrigé en T3** (décision du propriétaire, 2026-11-12) : `CollectionController` place le bouton juste au-dessus du `JumpButton` de Roblox (positions suivies par événements, repli en bas à droite). Vérifié en portrait et en paysage, touchers réels du propriétaire : aucun chevauchement, collecte et vente OK. Acceptée par le propriétaire ; commit local autorisé |
| A-26 | Position du personnage simulée par le client : le contrôle de trajet ne bloque que la téléportation entre deux collectes | **PARTIEL — réduite en T6, validée** (2026-11-14) (D-019) : MovementValidator (fenêtre glissante, téléportation, vertical), contrôle avant collecte et vente, référence de réapparition serveur, correction graduelle. La position reste simulée par le client |
| A-27 | Marges de sécurité de la collecte (4 studs, 0,1 s, 5 demandes/s) jamais mesurées avec une latence mobile réelle | **Ouverte** : latence Studio 0,4 s partiellement testée en T6 ; mobile réel non mesuré ; seuils R4 provisoires |
| A-42 | Projection physique forte (≥ 40 studs) en continuant de courir : l'épisode peut durer 3 s et provoquer la correction d'un joueur honnête | **Ouverte (T6)** : calibrer `persistentEpisodeSeconds` avec des mesures réelles |
| A-43 | Profils créés par les préréglages Studio : constats `data_inconsistency` attendus au chargement | **Documentée (T6)** : sans effet en production, audit en lecture seule |
| A-28 | Collecte par toucher et collecte en maintien implémentées toutes les deux (GDD 5.1) | **Levée** le 2026-11-11 (propriétaire, D-012) : les deux modes sont conservés. Maintien mesuré sur émulateur (39 collectes en 60 s) ; toucher non mesuré |
| A-29 | Aucun son ni animation de personnage à la collecte ; modèles de ressources provisoires | **Décidée** (D-012) : reportée à une phase dédiée à l'expérience utilisateur |
| A-30 | Barre du sac affichée en pastille ronde à faible remplissage (largeur du remplissage inférieure à l'arrondi des coins) | **Corrigée en T5.1, validée** (Studio, 2 / 50 : barre, plus de point rond ; téléphone réel OK, propriétaire) : remplissage à coins de 6 px, largeur minimale 6 px, inséré dans une piste de 26 px ; la pastille compacte est désormais un état voulu de la piste entière (sac < 25 %) |

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

## Vérifications T5.4 — Textes et localisation EN/FR (2026-11-13, TERMINÉ)

Validé par le propriétaire (2026-11-13). Commit local autorisé.

Détail : `docs/LOCALIZATION.md`.

| Vérification | Type | Résultat |
|---|---|---|
| Lune (`lune run tools/run_tests.luau`) | Automatisé | 13 suites OK, dont `LocalizationTests` (15 cas) ; code de sortie 0 |
| Sensibilité des nouveaux tests | Automatisé (mutations temporaires, annulées) | Tutoiement, accent manquant, motif `%d` en trop, apostrophe typographique, texte non traduit, espace simple avant « ! » : tous détectés |
| luau-lsp strict | Automatisé | 0 erreur |
| `rojo build` | Automatisé | OK |
| Play Studio (fr-fr, émulation tactile) | MCP | `TOUS LES TESTS : OK` ; carte du guidage « Collectez vos premières ressources ! » (« ! » reste sur la ligne de son mot) ; Boutique « 0,75 s → 0,7 s », « 12 studs → 14 studs » ; expulsion `kickSessionLost` : message en français dans le journal serveur |

### Non exécutées

| Vérification | Raison |
|---|---|
| Interface en anglais dans Studio | Studio en fr-fr ; textes EN couverts par les tests automatisés seulement |
| Fenêtre d'expulsion affichée | En Play Studio la fenêtre ne s'affiche pas ; message vérifié dans le journal |
| Expulsions `load_failed` et `session_locked` en jeu | Exigent une panne DataStore ou un verrou réel ; textes couverts par les tests |
| Téléphone réel, autres appareils | À faire par le propriétaire (`tests/TEST_STRATEGY.md`, « Tests manuels T5.4 ») |

## Vérifications T5.5 — Validation multiplateforme (2026-11-13, TERMINÉ avec réserves)

Détail : `tests/T5_MULTIPLATFORM_REPORT.md`, `tests/T5_DEVICE_MATRIX.md`,
`tests/T5_ISSUES.md`. Aucun commit.

| Vérification | Type | Résultat |
|---|---|---|
| Lune, 13 suites | Automatisé | Exécuté — `TOUS LES TESTS : OK`, code 0 |
| `luau-lsp analyze` strict | Automatisé | Exécuté — 0 erreur |
| `rojo build` | Automatisé | Exécuté — OK |
| Synchronisation Rojo | Studio | Exécuté — 56 / 56 scripts identiques |
| Suites dans Studio | Studio | Exécuté — `TOUS LES TESTS : OK` |
| Parcours nouveau joueur complet, sans préréglage (collecte, plein, vente ×2, boutique, achat, effet, reprise) | Studio, émulateur téléphone paysage, RemoteEvents réels, touches F et B réelles | Exécuté — OK |
| Retours audio/visuels (compteurs) | Studio | Exécuté — 1 retour par confirmation, aucune accumulation |
| Réapparition | Studio | Exécuté — aucune GUI dupliquée |
| Téléphone réel (R1–R10) et PC hors Studio (P1) | Manuel, propriétaire | **Validé** — validé par le propriétaire (déclaration « test validé », 2026-11-13 ; appareil, version Android, détail ligne par ligne et version du place testée non communiqués) |
| Tablette réelle | — | Non testée (non mentionnée) |
| Manette | — | **Reporté** (aucun matériel) |
| Session 15 min sur téléphone (R9) | Propriétaire | Comprise dans la déclaration ; aucune mesure chiffrée transmise |

Anomalies : aucune P0/P1 ; T55-01 (P3, ponctuation) corrigée avec accord
(`Localization`, texte seul ; tests relancés OK, vérifiée dans Studio) ;
T55-02 (statut T5.3) corrigée dans ce document. Seul fichier de code
modifié en T5.5 : `Localization.lua` (2 chaînes).

Sauvegarde du place de test (accord du propriétaire, 2026-11-13) :
**version 56** (Team Create), non publiée. Avant sauvegarde : 56 / 56
scripts identiques au dépôt (correction T55-01 incluse),
`useMemoryStore = true`, station présente, aucun résidu de Play. La
publication reste à faire par le propriétaire.

## Vérifications T6 — Sécurité multijoueur (2026-11-13, VALIDÉ le 2026-11-14)

Détail : `phases/T6_SECURITY_REPORT.md` et
`phases/T6_MULTIPLAYER_TEST_REPORT.md`.

Fichiers ajoutés : `Systems/MovementValidator.lua`,
`Systems/PayloadValidator.lua`, `Systems/ProfileAudit.lua`,
`Services/SecurityLog.lua`, `ServerOnlyConfig/MovementSecurityConfig.lua`,
`ServerOnlyConfig/SecurityLogConfig.lua`, `Tests/MovementValidatorTests.lua`,
`Tests/SecurityTests.lua`. Modifiés : `Bootstrap`, `CollectionService`,
`SellService`, `UpgradeService`, `WorldUnlockService`, `RunTests`.
Aucun changement d'économie, de schéma ni de client.

| Vérification | Résultat |
|---|---|
| Lune, 15 suites (dont 25 + 42 cas nouveaux) | PASS |
| Régression : 13 suites existantes | PASS |
| luau-lsp strict / rojo build | PASS / PASS |
| Contrôle négatif (16 défauts) | PASS (14 seuls, 2 couverts par garde redondante) |
| Studio : marche, sauts, téléportation isolée et répétée, `WalkSpeed` local, réapparition, remotes falsifiés, spam | PASS |
| Studio : latence 0,4 s | PARTIAL |
| Local Server multi-joueurs (propriétaire) | PASS (déclaré, détail non transmis) |
| Mobile réel, R-02 | NOT TESTED |

À remettre en état : `IncomingReplicationLag` laissé à **0,4** dans Studio
(session fermée avant remise à 0) ; Studio Settings > Network → **0**.

## Vérifications T7 — Progression et équilibrage (2026-11-14, VALIDÉE ET CLÔTURÉE)

Détail : `phases/T7_IMPLEMENTATION_REPORT.md`, `phases/T7_ECONOMY_SIMULATION.md`,
`phases/T7_PROGRESSION_AUDIT.md`.

| Vérification | Type | Résultat |
|---|---|---|
| 17 suites Lune (dont `PlayTimeTests` 15 cas, `AchievementTests` 16 cas) | Automatisé | OK |
| Mutations volontaires des nouveaux modules | Automatisé | Détectées, code restauré |
| `luau-lsp analyze` | Automatisé | 0 erreur |
| `rojo build` (fichier temporaire) | Automatisé | Réussi |
| Play Studio : suites, 40 collectes réelles, succès `collect_100` | Studio, magasin en mémoire | OK (+50 Coins, journal, bandeau FR) |
| Test réel par le propriétaire | Manuel (propriétaire) | Effectué, T7 validée le 2026-11-14 |
| Migration v2 sur DataStore réel | Manuel | Non exécutée (optionnelle) |

## Vérifications T8.1 — Architecture des mondes (2026-11-14, À VALIDER)

Détail : `phases/T8_IMPLEMENTATION_REPORT.md`.

| Vérification | Type | Résultat |
|---|---|---|
| 18 suites Lune (dont `WorldTravelServiceTests` 25 cas avec les vérifications A/B, `CollectionServiceTests` 27, `MovementValidatorTests` 30) | Automatisé | OK |
| Local Server, 2 joueurs (lancé par le propriétaire, piloté par MCP), magasin en mémoire, fixture temporaire retirée ensuite | Studio, multijoueur | **OK** : voir « Test multijoueur T8.1 » dans `phases/T8_IMPLEMENTATION_REPORT.md` |
| Mutations volontaires (contrôle du monde en collecte, grâce, déblocage et monde connu en voyage) | Automatisé | Détectées, code restauré |
| `luau-lsp analyze` | Automatisé | 0 erreur |
| `rojo build` (fichier temporaire) | Automatisé | Réussi |
| Simulateur, option `t7` | Automatisé | Sortie identique à celle de T7 |
| Play Studio (magasin en mémoire) : 18 suites, voyage refusé (verrouillé), voyage réussi après U8, payload falsifié refusé, limite de fréquence, retour Green Valley, collecte réelle | Studio, un joueur | OK ; aucune anomalie de déplacement journalisée |
| Reconnexion du même joueur en Local Server | Studio | Non exécutable (un nouveau joueur reçoit un autre UserId) ; couverte par Lune |
| Téléphone réel, DataStore de test | Manuel | NON EXÉCUTÉ |

## Vérifications T8.2 — Green Valley (2026-11-15, VALIDÉE par le propriétaire)

Détail : `phases/T8_IMPLEMENTATION_REPORT.md`, section T8.2.

| Vérification | Type | Résultat |
|---|---|---|
| 19 suites Lune (dont `TravelRulesTests` 8 cas) | Automatisé | OK |
| `luau-lsp analyze`, `rojo build` | Automatisé | 0 erreur ; réussi |
| Construction (`build_green_valley.luau`, mode Edit) | Studio | 40 points (16/12/8/3/1), 312 parts sur l'île (budget 1 200) |
| Play Studio, magasin en mémoire : collecte des 3 Fruits sauvages et du Cristal vert, vente, réapparition (20,06 s), voyages, portails, boutique, réapparition du personnage au hub | Studio, un joueur | OK ; aucune anomalie de déplacement |
| Appui réel sur F / clic sur « Voyager » | Manuel | NON VÉRIFIÉ (entrées simulées non transmises par MCP) |
| Rendu visuel de l'île | Manuel | NON VÉRIFIÉ (capture Studio vide) |
| Téléphone réel | Manuel | NON EXÉCUTÉ |

## Vérifications T8.3 — Golden Desert (2026-11-15, VALIDÉE par le propriétaire)

Détail : `phases/T8_3_GOLDEN_DESERT_REPORT.md`.

| Vérification | Type | Résultat |
|---|---|---|
| 19 suites Lune ; mutation « particules hors Épique » détectée | Automatisé | PASS |
| `luau-lsp analyze`, `rojo build` | Automatisé | PASS (0 erreur ; réussi) |
| Construction (`build_world_golden_desert.luau`, mode Edit) | Studio | 40 points (16/12/7/4/1), 442 parts de décor (budget 1 200), 1 émetteur, 0 lumière ; Green Valley intact |
| Play Studio, magasin en mémoire : refus avant déblocage, déblocage, voyage, collecte des 5 ressources à pied, double collecte refusée, réapparitions (8,02 s ; 60,00 s), vente +80, portail de retour, mort → hub, payloads falsifiés | Studio, un joueur | PASS ; aucune anomalie de déplacement |
| Appui réel au portail, captures, rendu visuel | Manuel | NOT TESTED |
| Local Server à 2 joueurs (lancé par le propriétaire) : refus verrouillé, voyages, collecte du même nœud, ventes simultanées, déconnexion | Studio, multijoueur | PASS ; aucune anomalie de déplacement, aucune erreur |
| Téléphone réel | Manuel | NOT TESTED |

## Vérifications T8.4 — Frozen Peaks (2026-11-15, VALIDÉE par le propriétaire)

Détail : `phases/T8_4_FROZEN_PEAKS_REPORT.md`.

| Vérification | Type | Résultat |
|---|---|---|
| 19 suites Lune, `luau-lsp analyze`, `rojo build` | Automatisé | PASS |
| Construction (`build_world_frozen_peaks.luau`, mode Edit) et relances | Studio | 40 points (16/12/7/4/1), 592 parts de décor (budget 1 200), 1 émetteur, 0 lumière ; sans doublon ; autres îles intactes |
| Modèles à plusieurs pièces (`ResourceVisualConfig.details`, `ResourceNodes`), mutation Neon détectée | Automatisé et Studio | PASS |
| Play Studio : refus avant déblocage, déblocage, voyage, collecte des 5 ressources à pied, double collecte, réapparitions (3,01 / 4,02 / 8,02 / 60,02 s), vente +278, noms EN/FR, portails, mort → hub, payloads falsifiés | Studio, un joueur | PASS ; aucune anomalie de déplacement |
| Écart de raretés (complément : `silver_ore` Peu commune, `frozen_stone` Commune) | Décision | **Tranché** par le propriétaire le 2026-11-15 : `ResourceConfig` / Bible 1.1 conservés |
| Local Server à 2 joueurs (lancé par le propriétaire) : refus verrouillé, voyages simultanés, collecte du même nœud (un seul succès), nœuds distincts, ventes simultanées (+36 / +18), déconnexion | Studio, multijoueur | PASS ; aucune anomalie de déplacement, aucune erreur |
| Appui réel au portail, rendu visuel, téléphone réel | Manuel | NOT TESTED |

## Vérifications T8.5 — Mystic World (2026-11-15, VALIDÉE par le propriétaire)

Détail : `phases/T8_5_MYSTIC_WORLD_REPORT.md`.

| Vérification | Type | Résultat |
|---|---|---|
| 19 suites Lune, mutation « Neon sur Peu commune » détectée, `luau-lsp analyze`, `rojo build` | Automatisé | PASS |
| Construction (`build_world_mystic_world.luau`, mode Edit) et relance | Studio | 40 points (16/12/7/4/1), 719 parts de décor (budget 1 200), 1 émetteur, 0 lumière ; sans doublon ; autres îles intactes ; raycasts : 40 points posés, 7 ponts continus |
| Play Studio : refus avant déblocage, déblocage (-250 000), voyage, collecte des 5 ressources à pied, double collecte, réapparitions (3,02 / 4,00 / 8,01 / 20,02 / 60,02 s), vente +1 077, portails, chute → hub, payloads falsifiés, limite de fréquence | Studio, un joueur | PASS ; aucune anomalie de déplacement, aucune erreur |
| Noms FR du prompt (« Poussière mystique », « Fragment d'étoile ») au-delà de la limite de 16 caractères | Décision | **Tranché** par le propriétaire le 2026-11-15 : « Poudre mystique » et « Éclat d'étoile » conservés |
| Local Server à 2 joueurs (lancé par le propriétaire) : refus verrouillé, voyages simultanés, collecte du même nœud (un seul succès), nœuds distincts, ventes simultanées (+136 / +68), déconnexion | Studio, multijoueur | PASS ; aucune anomalie de déplacement, aucune erreur |
| Appui réel au portail, rendu en jeu, téléphone réel | Manuel | NOT TESTED |

## Vérifications T8.6 — Collection Journal (2026-11-16, validée)

Détail : `phases/T8_6_COLLECTION_JOURNAL_REPORT.md`,
`phases/T8_6_MIGRATION_TEST_REPORT.md`.

| Vérification | Type | Résultat |
|---|---|---|
| 20 suites Lune (dont `CollectionJournalTests`, 35 cas), 3 mutations détectées, `luau-lsp analyze`, `rojo build` | Automatisé | PASS |
| Play Studio : 20 suites au démarrage ; collecte à pied (`firstDiscovery` true puis false), payload falsifié, monde verrouillé, bandeau, vente (découvertes conservées), vues du Journal, préréglages `J_partial` / `J_full`, exclusion Boutique / Journal, J, croix bas, B | Studio, un joueur | PASS (manette : touches émulées seulement) |
| Migration v2 -> v3 sur `GrabAndGrow_PlayerData_v1_Studio` (expérience de test) : v2, v3, neuf, sauvegarde, reconnexion, conflit `Recovery_`, verrou actif, corrompu | DataStore de test | PASS |
| Local Server à 2 joueurs (lancé par le propriétaire, 2026-11-16) : découvertes indépendantes, même nœud à 1 ms (un seul succès, une seule découverte), journaux séparés 1/20 et 2/20, bandeau, sauvegardes auto | Studio, multijoueur | PASS |
| Tactile, manette réelle, téléphone réel, capture en anglais | Manuel | NOT TESTED |

## Décisions en attente

1. Push GitHub des commits T1 à T7 : autorisé et effectué le 2026-11-14.
2. D-8 (persistance des préférences) et D-9 (emplacement) : recommandations
   appliquées, sans décision consignée.

## Prochaine étape

1. Vérifier dans Studio que `IncomingReplicationLag` = 0.
2. T8.2 validée (2026-11-15). Vérifier que le place est enregistré avec la
   carte de Green Valley.
3. T8.3 (Golden Desert) validée le 2026-11-15. Vérifier que le place est
   enregistré avec les deux îles.
4. T8.4 (Frozen Peaks) validée le 2026-11-15. Vérifier que le place est
   enregistré avec les trois îles.
5. T8.5 (Mystic World) construite et testée (un joueur, Local Server à
   2 joueurs) le 2026-11-15 ; noms FR existants conservés (propriétaire,
   2026-11-15) ; **validée** par le propriétaire le 2026-11-15. Place
   enregistré avec les quatre îles (version 90, non publié). T8.6 : en
   attente d'autorisation. Enregistrer le place avec les quatre îles.
   T8.6 autorisée le 2026-11-16 (D-022), construite et testée (Local
   Server à 2 joueurs compris) ; **validée** le 2026-11-16 ; commit local
   autorisé, push non autorisé.
   T8.7 non commencée.
6. Commits : T8.0 à T8.2 (dd806ef), T8.3 (33830ca), T8.4 (628e9a2),
   T8.5 (`feat(worlds): T8.5 Mystic World archipelago`) ; push de T8.0 à
   T8.5 autorisé et effectué le 2026-11-15.
