# GRAB & GROW — Stratégie de tests

Dernière mise à jour : 2026-11-12 (T4)

Règle : un test n'est « réussi » que s'il a été exécuté. Chaque rapport de
lot distingue tests automatisés, tests manuels et vérifications non faites.

## Niveaux de test

| Niveau | Objet | Moyen | Disponible aujourd'hui |
|---|---|---|---|
| 1. Analyse statique | Syntaxe, types `--!strict` | `luau-lsp analyze` en terminal ; Script Analysis de Studio | Oui |
| 2. Configurations | Cohérence structurelle et références croisées | `Tests/ConfigTests.lua` | Oui |
| 3. Logique serveur | Règles des services (collecte, vente, achat, migration) | Modules de test en Luau pur, dépendances simulées | Oui pour T1 (`DataSchemaTests`, `PlayerDataServiceTests`) T2 (`InventoryServiceTests`, `ResourceSpawnerTests`, `CollectionServiceTests`) et T3 (`SellServiceTests`) et T4 (`EconomyServiceTests`, `UpgradeServiceTests`) |
| 4. Intégration | Remotes, validation, rate limit | Play dans Studio piloté par MCP : demandes envoyées depuis le client, réponses lues sur `ActionResult` | Oui (T2, T3 et T4, un joueur) |
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
[Tests] DataSchemaTests : OK (18 cas)
[Tests] PlayerDataServiceTests : OK (35 cas)
[Tests] InventoryServiceTests : OK (14 cas)
[Tests] ResourceSpawnerTests : OK (9 cas)
[Tests] CollectionServiceTests : OK (22 cas)
[Tests] SellServiceTests : OK (25 cas)
[Tests] EconomyServiceTests : OK (10 cas)
[Tests] UpgradeServiceTests : OK (22 cas)
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

## Tests manuels T4 (à faire par le propriétaire)

### Préparation

1. Place de test ouvert (`Test de prise et de croissance`), `rojo serve`
   actif, plugin connecté. Attendre quelques secondes après une
   modification de `src/` avant Play : un Play lancé trop tôt tourne sur
   l'ancienne version.
2. `DataConfig.Studio.useMemoryStore = true` pour U1 à U7, U9, U10.
3. Play (F5). Output attendu : `[Tests] TOUS LES TESTS : OK` et
   `[StudioTest] préréglages disponibles : ...`.
4. Préréglage : barre de commande de Studio, **contexte Serveur** (bascule
   Client/Serveur de l'onglet Test), pendant Play :

```lua
game.ServerStorage.StudioTestHooks.ApplyPreset:Invoke("U1")
```

Le préréglage remet le profil à zéro (solde, niveaux, mondes, sac,
statistiques) puis fixe l'état du scénario ; Output :
`[StudioTest] <joueur> : préréglage U1 appliqué (...)`. Outil Studio
uniquement (`Systems/StudioTestPresets`) : absent d'un serveur publié,
inaccessible au client, aucun paramètre économique modifié.

| Préréglage | État |
|---|---|
| `reset` | Nouveau joueur |
| `U1` | 100 Coins |
| `U2` | 150 Coins |
| `U3` | 200 Coins |
| `U4` | 250 Coins |
| `U5` | 300 Coins, sac : 10 Feuille, 10 Bois, 10 Pierre (base 60 Coins) |
| `U6` | 50 Coins |
| `U7_locked` | 1 500 Coins, Backpack 4 |
| `U7_ready` | 1 500 Coins, Backpack 5 |
| `U8` | 1 000 Coins, Backpack 5, Grabber 2, Magnet 1, Boots 2, Multiplier 2, Golden Desert débloqué, sac 3 Feuille + 2 Bois |
| `U9` | 500 Coins, Backpack 3, Grabber 10 (MAX) |

Mesures facultatives, barre de commande en **contexte Client** :

```lua
-- Distance à la ressource disponible la plus proche (U3)
local root = game.Players.LocalPlayer.Character.HumanoidRootPart local best = math.huge for _, p in workspace.ResourceNodes:GetDescendants() do if p:IsA("BasePart") and p:GetAttribute("Available") then best = math.min(best, (p.Position - root.Position).Magnitude) end end print("distance", best)
```

```lua
-- Collectes réussies pendant 20 s (U2)
local n = 0 local c = game.ReplicatedStorage.Remotes.ActionResult.OnClientEvent:Connect(function(r) if r.action == "Collect" and r.ok then n += 1 end end) task.wait(20) c:Disconnect() print("collectes en 20 s", n)
```

```lua
-- Vitesse appliquée (U4)
print("WalkSpeed", game.Players.LocalPlayer.Character.Humanoid.WalkSpeed)
```

### Scénarios

Environnement : **Studio** = Play sur PC ; **Émulateur** = Test > Device
de Studio (simulation, pas un téléphone) ; **Appareil réel** = téléphone ;
**Manette physique** = manette branchée. Un résultat obtenu en simulation
ne vaut pas validation sur appareil réel.

| # | Environnement | Préréglage | Action | Attendu |
|---|---|---|---|---|
| U1 | Studio | `U1` | Boutique (bouton ou B) > Backpack ; collecter jusqu'au plein | Message « Sac 50 → 75 » ; Coins 0 ; sac `x / 75` ; plein à 75, rien perdu |
| U2 | Studio | `U2` | Mesure 20 s en maintien, acheter Grabber, nouvelle mesure 20 s | Achat −150 ; mesure 2 ≥ mesure 1 (cadence 0,75 → 0,70 s ; plafond ≈ 28 en 20 s, limité aussi par les ressources disponibles) |
| U3 | Studio | `U3` | Approcher une ressource : noter la distance d'apparition du ciblage ; acheter Magnet ; recommencer | Avant : ciblage à ≤ 12 studs ; après : ≤ 14 studs ; −200 Coins ; message « Portée 12 → 14 studs » ; anneau bleu de 14 studs au sol pendant 2,5 s (A-40) |
| U4 | Studio | `U4` | Acheter Boots ; mesure vitesse ; réinitialiser le personnage (Échap > Réinitialiser) ; mesure | 16 → 16,5 ; 16,5 après réapparition ; −250 Coins |
| U5 | Studio | `U5` | Vendre au stand ; noter le gain ; `U5` de nouveau ; acheter Multiplier ; vendre | 1re vente : +60 ; après achat (solde 0) : +63 ; Output `base 60 x1.05` |
| U6 | Studio | `U6` | Ouvrir la boutique, appuyer sur chaque bouton | Boutons gris « Manque N » ; toast « Pas assez de Coins » ; Coins 50 inchangés |
| U7 | Studio | `U7_locked` puis `U7_ready` | Mondes > Golden Desert : appuyer ; puis `U7_ready`, appuyer deux fois | Verrouillé : statut rouge, refus, 1 500 inchangés. Prêt : « Confirmer ? », 2e appui : « Monde débloqué ! », Coins 0, « Débloqué · Contenu à venir » ; Frozen Peaks : « Sac à dos niv. 8 · 35000 Coins » |
| U8 | Studio, DataStore de test | `U8` | Voir procédure ci-dessous | Après Stop puis Play : même état (Coins 1 000, niveaux, Golden Desert, vitesse 16,5, sac 5/180) |
| U9a | Émulateur (simulation), paysage puis portrait | `U9` | Ouvrir, faire défiler, acheter Magnet, fermer (X) | Bouton Boutique au-dessus de Prendre (ou à sa gauche), sans chevauchement, en paysage comme en portrait (A-39) ; hors du stick et du saut ; cartes lisibles ; Grabber « MAX » doré ; Backpack « Manque 100 » ; Magnet payable ; défilement jusqu'aux mondes |
| U9b | Appareil réel (si disponible) | `U9` (publication de test requise : hors Studio, préréglages absents) | Mêmes gestes | Même rendu ; icônes (glyphes) visibles (A-38) |
| U10a | Émulateur de manette de Studio (simulation, si disponible) | `U9` | Croix haut, naviguer, A, B | Ouverture, sélection du 1er bouton, achat, fermeture |
| U10b | Manette physique (si disponible) | `U9` | Idem | Idem |

### Procédure U8 (DataStore de test uniquement)

1. Stop. Dans `src/ReplicatedStorage/Shared/Config/DataConfig.lua` :
   `useMemoryStore = false` (ou demander à Claude de le faire). Attendre
   la synchronisation Rojo.
2. Play. Output : `[Bootstrap] DataStore : GrabAndGrow_PlayerData_v1_Studio`
   (DataStore de test ; Studio n'utilise jamais `GrabAndGrow_PlayerData_v1`).
3. Préréglage `U8`. Noter l'état affiché.
4. Stop. Output : `sauvegarde (fermeture serveur) OK`.
5. Play. Output : `profil chargé` ; ouvrir la boutique et vérifier l'état
   noté, vitesse 16,5.
6. Stop. Remettre `useMemoryStore = true`, attendre la synchronisation,
   vérifier dans Studio avant toute sauvegarde du place.

### Bilan à transmettre

Pour chaque scénario : OK / KO, environnement réel utilisé, et, en cas de
KO, l'action, le résultat observé et l'extrait d'Output ou une capture.

## Tests manuels T5.2 (à faire par le propriétaire)

Play dans Studio, puis émulateur (téléphone paysage, tablette), puis
téléphone réel. Préréglages, côté serveur :
`game.ServerStorage.StudioTestHooks.ApplyPreset:Invoke("U5")`.

| # | Action | Attendu |
|---|---|---|
| F1 | Collecter une feuille, un bois, une pierre | Petit son doux, éclat coloré qui file vers le personnage, toast `+1` |
| F2 | U5 puis collecter jusqu'à 40 / 50, puis 50 / 50 | Signal discret à 40 ; son court de refus à 50 ; maintenir « Prendre » : pas de répétition fatigante |
| F3 | Vendre au stand | Son de pièces, pièces qui montent vers le solde, ligne Coins qui pulse, toast `+N Coins` = montant crédité |
| F4 | Vendre sac vide | Son discret de refus, aucun effet positif |
| F5 | U1 à U5 : acheter chaque amélioration | Son positif, anneau doré autour de l'icône, niveau en vert ; Magnet : anneau au sol seul |
| F6 | U6 : acheter | « Pas assez de Coins » + son discret de refus |
| F7 | U7_ready : débloquer Golden Desert | Son de victoire distinct, confettis, « Golden Desert débloqué ! » |
| F8 | Boutique > Paramètres > Son : Désactivé ; refaire F1, F3 | Aucun son ; effets visuels présents |
| F9 | Effets réduits : Activé ; refaire F1, F3, F5 | Sons plus faibles, moins de particules et de pièces, animations plus courtes ; retours toujours visibles |
| F10 | Téléphone paysage et tablette | Pièces et confettis sans masquer « Prendre », saut, stick ; section Paramètres lisible et touchable |

Les préférences sont mémorisées pour la session seulement (D-8).

## Tests manuels T5.3 (à faire par le propriétaire)

Téléphone réel en paysage d'abord, puis PC. Nouveau joueur : en Studio,
Play (profils en mémoire) ; préréglages côté serveur :
`game.ServerStorage.StudioTestHooks.ApplyPreset:Invoke("O_sold")`.

| # | Action | Attendu |
|---|---|---|
| G1 | Lancer en nouveau joueur | Accueil court (≈ 5 s) en haut à gauche, puis « Étape 1/3 — Collecte tes premières ressources ! » ; flèche ▼ sur une ressource ; rien ne bloque les déplacements |
| G2 | Collecter 1 ressource | Étape 2/3 « Continue de remplir ton sac » ; à 10 : « Vends tes ressources ! », ▼ sur le stand, flèche → au bord si le stand est hors champ |
| G3 | Vendre | « Belle vente ! +N Coins » (N = toast de vente), puis étape 3/3 avec les Coins manquants |
| G4 | `O_sold_rich`, ouvrir la Boutique | ▶ à côté du bouton Boutique, puis ▶ sur Sac à dos seulement ; carte masquée boutique ouverte |
| G5 | Acheter | « Sac à dos niveau 2 ! … » puis plus aucun guidage |
| G6 | × puis jouer | Carte et repères disparaissent ; tout fonctionne ; « ? Guide » réaffiche ; la carte revient à l'étape suivante |
| G7 | Lisibilité téléphone paysage | Aucun chevauchement avec sac, Boutique, Prendre, saut, stick, prompt de vente ; texte lisible |
| G8 | `O_upgraded`, nouvelle session | Aucun guidage |

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
| T4 | Achat de chaque amélioration ; débit exact ; fonds insuffisants ; niveau maximum ; effets réels (capacité, cadence, portée, vitesse et contrôle de trajet, Multiplier) ; état client ; achats répétés et coût cumulé ; achats concurrents ; deux joueurs ; statistiques avec ventes ; persistance et reconnexion ; payloads falsifiés ; profil en chargement, libéré, en fermeture ; limite de fréquence ; déblocage autorisé, refusé (niveau, fonds, ordre, déjà débloqué, inconnu) ; crédit et débit invalides ou en dépassement ; arrondi du Multiplier |
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
