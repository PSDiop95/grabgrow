# GRAB & GROW — Stratégie de tests

Dernière mise à jour : 2026-11-11

Règle : un test n'est « réussi » que s'il a été exécuté. Chaque rapport de
lot distingue tests automatisés, tests manuels et vérifications non faites.

## Niveaux de test

| Niveau | Objet | Moyen | Disponible aujourd'hui |
|---|---|---|---|
| 1. Analyse statique | Syntaxe, types `--!strict` | `luau-lsp analyze` en terminal ; Script Analysis de Studio | Oui |
| 2. Configurations | Cohérence structurelle et références croisées | `Tests/ConfigTests.lua` | Oui |
| 3. Logique serveur | Règles des services (collecte, vente, achat, migration) | Modules de test en Luau pur, dépendances simulées | Oui pour T1 (`DataSchemaTests`, `PlayerDataServiceTests`) T2 (`InventoryServiceTests`, `ResourceSpawnerTests`, `CollectionServiceTests`) et T3 (`SellServiceTests`) |
| 4. Intégration | Remotes, validation, rate limit | Play dans Studio piloté par MCP : demandes envoyées depuis le client, réponses lues sur `ActionResult` | Oui (T2 et T3, un joueur) |
| 5. Multijoueur | Isolation des données, double collecte | Simulation : deux `UserId` sur le même service (Lune). Réel : Studio, Test > Local Server, 2 joueurs ou plus | Simulé : oui. Réel : oui pour T2 (2 joueurs, propriétaire) |
| 6. Sauvegarde | Nouveau profil, reconnexion, échecs, migration | `MemoryDataStore` injecté dans `PlayerDataService` ; puis expérience de test avec accès API, pilotée par le serveur MCP Roblox Studio | Simulé : oui. DataStore réel : V-01, V-02, V-03, V-05 faits ; V-04 partiel (`PROJECT_STATUS.md`) |
| 7. Appareils | Lisibilité, tactile, performances | Émulateur d'appareils de Studio, puis téléphone réel | À partir de T5 |

## Analyse statique (terminal)

```bash
rojo sourcemap default.project.json -o sourcemap.json
```

```bash
luau-lsp analyze --sourcemap sourcemap.json --definitions @roblox=.tools/globalTypes.d.luau --platform roblox src
```

Code de sortie 0 et aucune ligne d'erreur : analyse propre.
`.tools/globalTypes.d.luau` (types de l'API Roblox) n'est pas versionné ;
il provient du dépôt luau-lsp, au tag de la version épinglée dans
`rokit.toml`.

## Lancer les tests automatisés (terminal)

```bash
lune run tools/run_tests.luau
```

Exécute `Tests/RunTests.server.lua` hors de Studio (Lune, épinglé dans
`rokit.toml`, D-009). `tools/run_tests.luau` simule `game:GetService`,
`script` et `require` pour les modules de logique pure. Code de sortie 0 :
aucun échec. Résultat attendu :

```text
[Tests] ConfigTests : OK
[Tests] DataSchemaTests : OK (17 cas)
[Tests] PlayerDataServiceTests : OK (35 cas)
[Tests] InventoryServiceTests : OK (14 cas)
[Tests] ResourceSpawnerTests : OK (9 cas)
[Tests] CollectionServiceTests : OK (22 cas)
[Tests] SellServiceTests : OK (25 cas)
[Tests] TOUS LES TESTS : OK
```

Non couvert par ce lanceur : `Bootstrap.server.lua`,
`Systems/PlayerSession.lua`, `Systems/ResourceNodes.lua`, `Systems/SellZones.lua` (événements et
instances Roblox) et les contrôleurs client, à vérifier dans Studio.

## Carte de test (Studio)

`tools/studio/build_test_map.luau` crée le sol, le point d'apparition et
36 points de spawn (`Workspace.ResourceSpawnPoints`) et, depuis T3, la
station de vente provisoire (`Workspace.SellZones.GreenValley`, zone
`GreenValley_Main`). À exécuter en mode
Edit (barre de commande ou serveur MCP). Rejouable, résultat identique à
chaque exécution. Sans points de spawn, le serveur démarre sans ressource
et l'écrit dans Output.

## Tests manuels T2 (à faire par le propriétaire)

Préparation : place de test ouvert, `rojo serve` actif et plugin connecté,
`useMemoryStore = true` (aucun test de cette liste ne touche un DataStore).
Noter pour chaque point : OK / KO, et une capture ou la ligne d'Output en
cas d'écart.

### A. Multijoueur — Test > Clients and Servers > Local Server, 2 joueurs

État au 2026-11-11 : points 1 à 5 OK (propriétaire).

Fenêtres : Server, Player1, Player2. Les deux joueurs apparaissent au même
point ; les feuilles les plus proches sont à environ 12 studs.

1. Player1 collecte une feuille, Player2 un bois : chaque panneau « Sac »
   n'augmente que de sa propre collecte.
2. Placer les deux joueurs devant la même ressource (une pierre : 4 s de
   réapparition laissent le temps de changer de fenêtre ; un testeur seul
   suffit). Player1 appuie sur E, puis, dans la fenêtre de Player2, E tout
   de suite : un seul sac augmente
   de 1 ; Player2 ne reçoit rien. La simultanéité exacte n'est pas
   nécessaire : la course réelle est couverte par les tests Lune.
3. Pendant le point 2, regarder la fenêtre de Player2 : la pierre y
   disparaît au moment de la collecte de Player1, puis réapparaît dans les
   deux fenêtres environ 4 s plus tard.
4. Player1 remplit son sac (50, message « Sac plein ! ») : Player2 continue
   de collecter normalement.
5. Fenêtre Server, Output : aucune erreur `[Collection]` ou `[PlayerData]`
   autre que les avertissements attendus.

### B. Mobile — Test > Device (émulateur), un téléphone, paysage puis portrait

État au 2026-11-11 : points 6 à 10 OK (propriétaire, capture en paysage).

6. Le bouton rond « Grab / Prendre » est visible, atteignable au pouce
   droit, sans recouvrir le bouton de saut ni le stick.
7. Le panneau du sac reste lisible et ne masque pas l'action.
8. La ressource ciblée a un contour blanc et son nom au-dessus.
9. Retours visuels : « +1 … », barre de progression, « Sac plein ! » en
   orange et barre rouge à 50.
10. Non-régression : déplacement au stick, saut et caméra fonctionnent
    pendant et après la collecte.

### C. Comparaison toucher / maintien (A-28), sur émulateur mobile

État au 2026-11-11 : maintien, 39 collectes en 60 s ; toucher non mesuré. Les deux modes sont conservés (D-012).

Pour chaque mode, 60 secondes autour du point d'apparition, sac vidé au
départ (nouveau Play) :

| Mode | Geste | À noter |
|---|---|---|
| Toucher | Toucher chaque ressource à l'écran | Nombre de collectes en 60 s ; touches manquées ; gêne avec la caméra |
| Maintien | Maintenir le bouton « Prendre » en marchant | Nombre de collectes en 60 s ; confort du pouce ; collectes non voulues |

Donner ensuite une préférence et ses raisons. Le choix définitif est une
décision du propriétaire (D-012).

### D. Reconnexion sur DataStore de test

Exécutée le 2026-11-11 avec l'accord du propriétaire (`PROJECT_STATUS.md`,
« Reconnexion sur DataStore de test »). Pour la rejouer : passer
`DataConfig.Studio.useMemoryStore` à `false`, collecter, Stop, Play,
comparer le sac, puis remettre `true` et vérifier le place avant toute
sauvegarde.

## Tests manuels T3 (à faire par le propriétaire)

Préparation : place de test ouvert, `rojo serve` actif et plugin connecté,
carte reconstruite par `tools/studio/build_test_map.luau` (station de
vente présente), `useMemoryStore = true` sauf en E.

| # | Protocole | Action | Attendu |
|---|---|---|---|
| E1 | Vente partielle (Play) | Collecter 5 à 10 ressources, aller sur la dalle jaune, touche F | Prompt « Vendre / ~N Coins » à portée ; toast `+N Coins` ; Coins = N ; sac à 0 ; prompt « Sac vide » |
| E2 | Sac plein | Remplir à 50, vendre | Message « Sac plein ! Vendez au stand » à la 51e collecte ; vente du sac entier ; collecte de nouveau possible |
| E3 | Sac vide | Vendre sans ressource | « Rien à vendre », Coins inchangés |
| E4 | Distance | Activer le prompt puis s'éloigner vite, ou rester à 15 studs | Pas de prompt hors portée ; aucun crédit |
| E5 | Double vente | Appuyer F plusieurs fois très vite | Un seul crédit ; Output serveur : une seule ligne `[Sell] ... +N Coins` |
| E6 | Deux joueurs (Local Server, 2 joueurs) | A et B vendent en même temps, puis A vend un sac vide | Soldes indépendants ; aucun effet de A sur B |
| E7 | Mobile (émulateur, portrait puis paysage) | Vendre en touchant le prompt | Prompt touchable, ne recouvre ni stick ni saut ; ligne « Coins / Valeur » lisible |
| E8 | Manette (si disponible) | Bouton Y à portée | Vente ; X reste la collecte |
| E9 | Reconnexion sur DataStore de test (accord préalable requis) | `useMemoryStore = false`, collecter, vendre, collecter 2, Stop, Play | Coins, statistiques et sac restaurés ; remettre `true` et vérifier avant toute sauvegarde du place |

## Lancer les tests automatisés (Studio)

1. Ouvrir `GrabAndGrow.rbxl`.
2. Terminal : `rojo serve`. Studio : onglet Plugins > Rojo > Connect.
3. Lancer Run (F8) ou Play (F5).
4. Lire Output : `[Tests] TOUS LES TESTS : OK` ou la liste des échecs, et
   `[Bootstrap] PlayerDataService démarré`.

Studio écrit aussi Output dans `%LOCALAPPDATA%\Roblox\logs`, ce qui permet
de relire le résultat depuis le terminal après exécution.

`RunTests.server.lua` ne fait rien hors Studio.

## Principes d'écriture

- La logique métier ne dépend pas directement des API Roblox : le temps,
  le DataStore et les positions sont passés en paramètre, pour être
  remplacés dans les tests.
- Les tests de configuration vérifient la structure, pas les valeurs : ils
  ne recopient pas les tables de la Bible.
- La conformité des valeurs à la Bible se contrôle par comparaison avec le
  document à chaque modification d'une config.
- Tout test de sauvegarde utilise un DataStore de test, jamais la production.
- Le magasin simulé copie les valeurs, refuse les valeurs non
  sérialisables et appelle deux fois la fonction de transformation, pour
  ne pas masquer des défauts que le DataStore réel révélerait.
- Les cas de concurrence pilotent des coroutines à la main ; l'horloge et
  les attentes sont simulées (exécution instantanée).
- Après l'écriture d'une suite, vérifier qu'elle échoue quand on introduit
  un défaut dans le code testé.

## Couverture attendue par phase

| Phase | Cas obligatoires |
|---|---|
| T1 | Nouveau profil ; profil existant ; échec de chargement sans écrasement ; échec de sauvegarde ; reconnexion ; migration ; sauvegardes concurrentes ; verrou actif, expiré, renouvelé, libéré ; données corrompues ; version future ; fermeture serveur |
| T2 | Collecte valide ; ressource inexistante ; ressource inactive ; trop loin ; trop rapide ; sac plein ; sac presque plein ; profil non chargé ; personnage absent ; payload invalide ou falsifié ; rejeu ; trajet implausible ; deux joueurs sur la même ressource ; inventaires indépendants ; réapparition ; quantité invalide ou négative ; persistance après reconnexion |
| T3 | Vente d'une et de plusieurs ressources ; calcul exact ; sac vide ; quantités à zéro ; inconnues seules ; sac mixte ; statistiques (`totalCoinsEarned`, `totalSales`, `totalCoinsSpent` intact) ; payload invalide ou falsifié ; zone inconnue ; trop loin ; personnage absent ; profil non chargé, en chargement, libéré ; limite de fréquence ; ventes concurrentes ; vente pendant une sauvegarde ; échec et erreur de mutation sans perte ; dépassements numériques ; état client après vente ; vente puis collecte ; deux joueurs ; persistance après rechargement |
| T4 | Solde suffisant ; solde insuffisant ; niveau maximum ; identifiant inconnu |
| T6 | Remote à cadence excessive ; arguments de type invalide ; valeurs falsifiées ; isolation entre joueurs |

## Limites de l'environnement

- Studio est piloté par le serveur MCP Roblox Studio (Play, Stop, Luau,
  console), configuré localement dans la config Claude du projet et activé
  dans Studio (Assistant > Gérer les serveurs MCP). Les droits sur les
  données passent par Assistant > MCP Permissions : lecture seule accordée.
- Studio n'accepte qu'une session par place (`RCC-276`) : pas de test à
  deux serveurs actifs depuis Studio.
- Le serveur MCP lance un Play à un seul joueur : pas de test à plusieurs
  clients, ni d'émulateur d'appareils. Sa capture d'écran n'affiche pas
  les BillboardGui.
- `rojo serve` ne relit pas les nouvelles entrées de
  `default.project.json` : le relancer après une modification du mappage.
- `luau-lsp analyze` vérifie syntaxe et types, mais n'exécute pas le code.
- Lune n'est pas Roblox : il exécute le même Luau, mais sans API Roblox.
  Un résultat sous Lune ne remplace pas une exécution dans Studio.
- Les limites de requêtes et la latence réelles du DataStore ne sont pas
  reproduites par un DataStore simulé.
- L'émulateur d'appareils ne mesure pas les performances d'un vrai
  téléphone.
