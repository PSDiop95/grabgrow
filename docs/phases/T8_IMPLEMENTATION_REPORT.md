# T8 — Rapport d'implémentation

Rapport intermédiaire après T8.0 et T8.1 (2026-11-14, validées sous
réserve du test multijoueur, réussi), puis T8.2 (2026-11-15, validée par le propriétaire).
**T8 n'est pas terminée** : T8.3 et suivants attendent la validation du
propriétaire (D-021). Aucun commit.

## T8.0 — Décisions et documentation

- D-021 consignée (`decisions/TECHNICAL_DECISIONS.md`) : décisions D1 à D10
  et choix d'architecture de T8.1.
- `PROJECT_STATUS.md` : résumé corrigé (T7 clôturée, T6 et T7 poussés),
  section T8.
- `CLAUDE.md` §5.2 : exception T8 ; `ROADMAP.md` : T8 = mondes et contenu,
  T9 = préparation de publication et `AnalyticsService`.
- Bible économique 1.1 : valeurs des mondes 2 à 4 (option B), Wild Fruit et
  Green Crystal actifs, réapparition (3.6), cibles 4.2 révisées.
- `assets/ASSET_MANIFEST.md` créé (à valider : aucun asset tiers).
- `phases/T8_WORLD_AUDIT.md` : trace de l'étape A.

## T8.1 — Architecture et sécurité

| Élément | Changement |
|---|---|
| `Shared/Config/ResourceConfig` | 20 ressources (5 par monde), valeurs Bible 1.1, réapparition D8 |
| `Shared/Config/ResourceVisualConfig` (nouveau) | Apparence par ressource en données simples (testable en Lune) ; Neon réservé à Rare et Épique ; aucune lumière ni particule |
| `Systems/ResourceNodes` | Tous les mondes de `WorldConfig` ; apparence lue dans la config ; attribut `WorldId` |
| `Services/CollectionService` | Refus `WORLD_LOCKED` si le monde de la ressource n'est pas débloqué dans le profil serveur (après « nœud connu », avant toute autre lecture) ; journalisé |
| `Services/WorldTravelService` (nouveau) | RemoteEvent `TravelToWorld { worldId }` : limite de fréquence, `PayloadValidator`, monde connu, débloqué, point d'arrivée présent, personnage vivant ; aucune écriture de profil |
| `Systems/WorldArrivals` (nouveau) | Points d'arrivée : `Workspace.WorldArrivals`, attribut `ArrivalWorldId` |
| `Systems/MovementValidator` | `Reset(…, graceSeconds?)` : grâce d'observation facultative ; sans argument, comportement T6 inchangé |
| `ServerOnlyConfig/TravelSecurityConfig` (nouveau), `MovementSecurityConfig.ServerTeleport` | Limite 2 voyages puis 1 / 5 s ; grâce 1 s (hypothèses) |
| `Bootstrap` | Déplacement serveur : `root.CFrame`, vitesse annulée, `MovementValidator.Reset` avec grâce, `CollectionService.ResetTravelReference` |
| `Remotes` | `TravelToWorld`, action `Travel`, codes `WORLD_LOCKED`, `WORLD_UNAVAILABLE` |
| Client | Message « Débloquez d'abord ce monde » ; détail du sac limité aux ressources présentes (20 ressources configurées) |
| `Localization` | 17 noms EN/FR, `collect.world_locked` |
| `tools/simulate_progression.luau` | Quatre mondes (40 nœuds par monde, répartis selon les poids) ; option `t7` |
| `tools/studio/build_test_map.luau` | Ne place que les ressources de la carte MVP : carte inchangée jusqu'à T8.2 |

Compatibilité des données : schéma v2 inchangé, aucune migration. Les
nouvelles clés d'inventaire sont conservées par un serveur ancien (D-008).
Conditions et coûts de déblocage, coûts d'amélioration : inchangés.

Écart avec l'étape A : pas de champ `playable` dans `WorldConfig`. Un
monde est accessible s'il est débloqué et qu'un point d'arrivée existe sur
la carte (moins de configuration, aucune condition propre à un monde).

## Projection économique (simulateur, configuration réelle)

`lune run tools/simulate_progression.luau`. Ce sont des projections
théoriques : la rareté liée aux réapparitions et la concurrence entre
joueurs sont ignorées.

| Profil | 1re vente | Golden Desert | Frozen Peaks | Mystic World | Fin de l'arbre |
|---|---|---|---|---|---|
| Occasionnel | 2,1 min | 1,4 h | 6,8 h | 15,2 h | 19,0 h |
| Régulier | 1,6 min | 1,2 h | 5,3 h | 9,8 h | 13,3 h |
| Très actif | 1,3 min | 58 min | 2,9 h | 6,9 h | 10,1 h |

Valeur par nœud de la carte prévue : GV 2,27 ; GD 8,03 ; FP 30,05 ;
MW 110,17. Plus longue attente entre deux achats (régulier) : 62 min, avant
Mystic World. La carte actuelle (36 nœuds, sans fruit ni cristal) reste
celle de T7 jusqu'à T8.2.

## Tests

| Test | Type | Résultat |
|---|---|---|
| 18 suites Lune (`lune run tools/run_tests.luau`) | Automatisé | OK : 344 cas + ConfigTests |
| Nouveaux cas : collecte en monde verrouillé, demandes répétées, deux joueurs, monde débloqué (5) ; voyage valide, refus, payloads, limite, intégration voyage + collecte (16) ; grâce de MovementValidator (5) ; cohérence des configs T8 | Automatisé | OK |
| Mutations : contrôle du monde en collecte, grâce ignorée, déblocage en voyage, monde connu | Automatisé | 4 sur 4 détectées, code restauré |
| `luau-lsp analyze` (sourcemap temporaire) | Automatisé | 0 erreur |
| `rojo build` (fichier temporaire hors dépôt) | Automatisé | Réussi |
| Simulateur `current t7` comparé à la version T7 | Automatisé | Sortie identique |
| Play Studio, magasin en mémoire, un joueur, points d'arrivée temporaires (session Play seulement) | Studio | 18 suites OK ; `WORLD_LOCKED` avant déblocage ; voyage vers Golden Desert après U8 (personnage à l'arrivée) ; payload avec position refusé (`extra_field`) ; limite de fréquence ; retour à Green Valley ; collecte réelle acceptée ; **aucune anomalie ni correction de déplacement journalisée** |
| Vérifications A/B (9 cas ajoutés à `WorldTravelServiceTests`, 25 au total) | Automatisé | OK |
| Local Server à 2 joueurs | Studio, multijoueur | OK (section suivante) |
| Téléphone réel (latence) | Manuel | NON EXÉCUTÉ |
| DataStore de test | Manuel | NON EXÉCUTÉ (aucun changement de schéma) |

Le place Studio n'a pas été modifié en mode Edit. `GrabAndGrow.rbxl` n'a
pas été touché. Le DataStore de production n'a pas été utilisé.

## Vérifications A/B (avant T8.2)

Cas Lune ajoutés à `WorldTravelServiceTests` (vrais services, magasin en
mémoire) :

| Point | Cas | Résultat |
|---|---|---|
| A | 18 demandes falsifiées (3 mondes verrouillés, casse, champs `unlocked` / `force`) : aucun déplacement, aucun déblocage | OK |
| A | Joueur mort : `NO_CHARACTER`, références de déplacement inchangées | OK |
| A | Profil libéré (déconnexion) : `PROFILE_NOT_LOADED` | OK |
| A | Voyage pendant une suspension T6 : suspension conservée, collecte au point d'arrivée refusée (`TOO_FAR`) | OK |
| A | 3 demandes dans la même image : 2 déplacements, la 3e limitée ; position et ancre = dernier voyage accepté ; aucune anomalie | OK |
| B | 6 voyages : profil identique (comparaison canonique), aucune écriture DataStore | OK |
| B | Voyage, collecte au désert, retour, sortie, reconnexion sur un autre serveur : déblocage, inventaire et Coins conservés ; aucune position persistée | OK |
| B | Profil v2 sans ressource T8 : chargé sans modification | OK |
| B | Ressources des quatre mondes : conservées après sauvegarde et rechargement | OK |

## Test multijoueur T8.1 (Local Server, 2 joueurs, 2026-11-14)

Conditions : Local Server à 2 joueurs lancé par le propriétaire, piloté
par MCP (clients : RemoteEvents du jeu, déplacements par `Humanoid:MoveTo`).
Magasin en mémoire confirmé (`[Bootstrap] Studio : profils en mémoire`).
Fixture temporaire `tools/studio/build_t8_mp_fixture.luau` (points
d'arrivée Green Valley et Golden Desert, sol et 5 points de spawn du
désert, préfixe `T8Fixture_`) installée en mode Edit avant le test, puis
**retirée** (mode Edit vérifié : seuls `Map.GreenValley` et
`ResourceSpawnPoints.GreenValley` restent, pas de `WorldArrivals`). Place
non enregistré. Serveur : 18 suites OK, 41 nœuds (36 + 5).

A = Player1 (UserId -1), B = Player2 (-2). Les deux reçoivent `U7_ready`
(Backpack 5, 1 500 Coins) : B pourrait débloquer, mais ne le fait pas.

| # | Étape | Résultat observé |
|---|---|---|
| 1 | A voyage avant déblocage | `WORLD_LOCKED`, journalisé |
| 2 | A débloque Golden Desert (`RequestUnlockWorld`) | `SUCCESS` ; `-1500 Coins (UnlockWorld:GoldenDesert)` ; succès `world_2` `+1000` |
| 3 | B voyage, puis payload falsifié `{ worldId, unlocked = true }` | `WORLD_LOCKED`, puis `INVALID_TARGET` (`extra_field`) ; position de B inchangée |
| 4 | A voyage vers Golden Desert | `SUCCESS` ; A en (3000 ; 3 ; 0) ; 5 nœuds du désert entre 6 et 20 studs |
| 5 | Collectes simultanées (même heure serveur) : A `sandstone_001`, B `green_leaf_006` ; B tente `copper_ore_001` (désert) | A `SUCCESS` ; B `SUCCESS` ; B `WORLD_LOCKED` (journalisé) |
| 6 | A collecte `copper_ore_001`, revient à Green Valley | `SUCCESS`, `SUCCESS` ; A en (0 ; 3 ; 20) |
| 7 | Ventes | A `+11` (grès 5 + cuivre 6), solde **1011** (= 1500 − 1500 + 1000 + 11) ; B `+1`, solde **1501** ; sacs vides ; mondes de B : Green Valley seul |
| 8 | A : 6 demandes dans la même image | 2 `SUCCESS`, 1 `RATE_LIMITED`, 3 sans réponse (silencieuses) |
| 9 | A : 4 voyages espacés de 5,2 s, puis marche de 10 studs | 4 `SUCCESS`, positions exactes à chaque arrivée, marche normale |
| 10 | A au désert collecte `fossil_001`, puis déconnexion (`Kick` serveur) | `SUCCESS` ; `sauvegarde (sortie) OK, verrou libéré` ; aucune erreur |
| 11 | B après le départ de A : voyage, collecte au désert, collecte à Green Valley | `WORLD_LOCKED`, `WORLD_LOCKED`, `SUCCESS` |

Journal serveur sur toute la session : **aucune anomalie ni correction de
déplacement** (`[Movement]` absent), aucune erreur de script, montants
`[Sell]`, `[World]`, `[Achievement]` exacts, sauvegardes automatiques OK.
Seuls avertissements : assets d'avatar connus (203785492, 81504106).

Non couvert ici : reconnexion du **même** joueur (impossible en Local
Server, un nouveau joueur reçoit un autre UserId ; couverte par Lune) ;
latence d'un téléphone réel (A-27).

## T8.2 — Green Valley (2026-11-15, validée)

### Réalisé

| Élément | Changement |
|---|---|
| `tools/studio/build_green_valley.luau` (nouveau) | Carte en primitives, graine fixe, rejouable, en mode Edit. Remplace `build_test_map.luau` (marqué obsolète) |
| Île | Trois dalles croisées (angles coupés), falaise, eau sans collision (chute = réapparition au hub) |
| Hub (centre) | Place de 48 studs ; apparition (0 ; 0,5 ; 0) ; point d'arrivée Green Valley (0 ; 0,3 ; 12) ; station de vente inchangée (`GreenValley_Main`, -12 ; 0 ; -16) |
| Portails | Trois arches au nord du hub (Golden Desert, Frozen Peaks, Mystic World), champ traversable avec attribut `PortalWorldId` |
| Zone de base | 36 points en anneaux : feuille 30–62, bois 45–85, pierre 65–105 studs (hors portails et vente) |
| Zone avancée | Clairière clôturée à l'ouest (centre -140 ; 0 ; 0), chemin depuis le hub ; 3 Fruits sauvages près de 3 arbres fruitiers, 1 Cristal vert au centre entre 4 rochers |
| Décor | 46 arbres, 28 rochers, 32 buissons, 48 fleurs, à 2–7 studs au moins de chaque ressource |
| `Controllers/TravelController` (nouveau) | Prompt local par portail (F, Y manette, toucher) ; île courante = point d'arrivée le plus proche ; aucune demande si le monde est verrouillé ou sans île (message local) ; messages de réponse |
| `Shared/Util/TravelRules` (nouveau) | Règles pures : île courante, état d'un monde, messages |
| `UpgradeController` | Ligne d'un monde débloqué : « Vous êtes ici », « Voyager » ou « Contenu à venir » ; panneau fermé après un voyage réussi |
| `Localization` | 6 clés `travel.*` EN/FR |

Serveur inchangé en T8.2. Prix, conditions de déblocage, schéma v2 :
inchangés. Aucun asset tiers.

### Budgets (audit T8)

| Mesure | Budget | Mesuré |
|---|---|---|
| Parts de l'île (décor compris) | ~1 200 | 312 |
| Nœuds de ressources | ~40 | 40 (16 feuilles, 12 bois, 8 pierres, 3 fruits, 1 cristal) |
| Lumières dynamiques | 0 | 0 |
| Ombres | Désactivées | `CastShadow = false` sur toute la carte ; `GlobalShadows` déjà désactivé |
| BaseParts du Workspace en jeu (avatar compris) | — | 418 |

Distances (marche à 16 studs/s) : hub → zone avancée 16,5 s pour les quatre
ressources ; retour à la vente 9,5 s.

### Tests

| Test | Type | Résultat |
|---|---|---|
| 19 suites Lune, dont `TravelRulesTests` (8 cas) ; longueur de `travel.go` | Automatisé | OK |
| `luau-lsp analyze` ; `rojo build` | Automatisé | 0 erreur ; réussi |
| Construction de la carte (mode Edit) | Studio | 40 points, 312 parts, ressource la plus proche de la vente à 25,8 studs |
| Play : 18 + 1 suites au démarrage, 40 nœuds chargés | Studio | OK |
| Collecte des 3 Fruits sauvages et du Cristal vert | Studio | 4 × `SUCCESS` |
| Réapparition du Cristal vert (config 20 s) ; recollecte pendant l'attente | Studio | 20,06 s ; `RESOURCE_UNAVAILABLE` |
| Vente (3 fruits + 2 cristaux) | Studio | +39 Coins (3 × 5 + 2 × 12) |
| Portails verrouillés | Studio | Prompt « Verrouillé / Golden Desert » ; aucune demande envoyée |
| Golden Desert débloqué (U8) avec une île provisoire **limitée à la session Play** | Studio | Prompt et ligne « Voyager » ; voyage `SUCCESS`, « Bienvenue dans Golden Desert ! », ligne « Vous êtes ici » ; retour à Green Valley au point d'arrivée (0 ; 3,2 ; 12) |
| Frozen Peaks (verrouillé) par RemoteEvent | Studio | `WORLD_LOCKED` |
| Golden Desert débloqué sans île | Studio | Ligne « Débloqué · Contenu à venir », prompt « Contenu à venir », RemoteEvent brut `WORLD_UNAVAILABLE` |
| Mort dans la zone avancée | Studio | Réapparition au hub (0 ; 4 ; 0), ligne « Vous êtes ici » |
| Journal serveur | Studio | Aucune erreur, aucune anomalie de déplacement |
| Appui réel sur F au portail, clic sur « Voyager » | Manuel | **NON VÉRIFIÉ** : les entrées clavier et souris simulées par MCP n'atteignent pas le jeu |
| Rendu visuel de l'île | Manuel | **NON VÉRIFIÉ** : capture Studio vide |
| Local Server avec la carte T8.2, téléphone réel | Manuel | NON EXÉCUTÉ |

La carte existe dans le place ouvert en mode Edit, **non enregistré** :
elle se perd si le place est fermé sans être enregistré (relancer le script
de construction). `GrabAndGrow.rbxl` n'a pas été touché.

## Risques résiduels

1. **Latence mobile (A-27).** Si les anciennes positions arrivent plus d'1 s
   après le voyage, un épisode d'anomalie isolé peut être journalisé (sans
   correction, il en faut 3 en 10 s). À mesurer sur téléphone réel.
2. **Interaction réelle non vérifiée.** Prompt des portails et bouton
   « Voyager » validés par leur état et par le chemin serveur, pas par un
   appui réel (voir T8.2).
3. **Îles absentes.** Golden Desert, Frozen Peaks et Mystic World n'ont pas
   d'île : débloquer Golden Desert affiche « Contenu à venir » (T8.3).
4. **Réapparition.** Elle se fait toujours dans le hub de Green Valley (D5),
   y compris après une mort dans un autre monde : voulu, à confirmer en test
   de jeu.
5. **Zone avancée.** Sans condition d'accès (D4) : seule la distance la
   distingue. Accès plus contrôlé à décider si les tests le demandent.
6. **Sous réserve de mesures.** Valeurs économiques (option B), temps de
   réapparition, limite de voyage et grâce restent des hypothèses.
7. **Avertissement connu.** La sortie Studio affiche « ContentId
   rbxassetid://203785492 … Asset type does not match » : asset d'avatar
   déjà relevé comme étranger au projet (`PROJECT_STATUS.md`).

## Prochaine étape proposée

1. Propriétaire : essayer la carte en jeu (rendu, portails avec F ou au
   toucher, bouton « Voyager »), puis enregistrer le place avec la carte.
2. Après validation de T8.2 : T8.3, île Golden Desert (5 ressources,
   40 nœuds, point d'arrivée, portail de retour), puis Local Server à
   2 joueurs.
