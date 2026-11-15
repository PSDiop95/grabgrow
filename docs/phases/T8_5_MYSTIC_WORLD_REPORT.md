# T8.5 — Mystic World : rapport

Date : 2026-11-15. Lot demandé par le propriétaire le 2026-11-15 (prompt
T8.5). Prérequis vérifiés : T8.4 validée par le propriétaire le 2026-11-15
et commitée (628e9a2) ; D-021 ; Bible 1.1 (§ 3.5) ; rapports T8.2, T8.3,
T8.4 ; `WorldConfig`, `ResourceConfig`, `ResourceVisualConfig`,
`ResourceSpawner`, `ResourceNodes`, `CollectionService`, `SellService`,
`WorldTravelService`, `MovementValidator`, `PayloadValidator`,
`SecurityLog`. Le portail Green Valley → Mystic World existait depuis T8.2.

**T8.5 validée par le propriétaire le 2026-11-15** après les tests Studio à
un joueur et en Local Server à 2 joueurs. Non commitée.

## Écarts du prompt et résolutions

| Écart | Résolution appliquée |
|---|---|
| Noms FR du prompt « Poussière mystique » (18 caractères) et « Fragment d'étoile » (17) : la limite `LocalizationTests` des noms de ressource est 16 (HUD mobile) | **Noms existants conservés** : « Poudre mystique », « Éclat d'étoile » (audit T8, `Localization`). **Confirmé par le propriétaire le 2026-11-15** |
| Raretés : prompt 16/12/7/4/1 | Identique à `ResourceConfig` / Bible 1.1 (Commune, Commune, Peu commune, Rare, Épique) : aucun écart, aucune modification |
| Prompt : zone C « peu communes », zone D « rares » | Appliqué : Minerai spectral sur les îles flottantes, Cristaux violets dans la grotte spectrale |
| Ressources communes de la forêt (zone B) éloignées de la vente (97–141 studs au premier jet) | 4 Éclats d'étoile sur l'île d'arrivée (côté ouest, au-delà de la Poudre) et 8 dans la moitié est de la forêt : 47–111 studs |
| Archipel sans sol | Aucune surface sous les îles : une chute fait réapparaître au hub de Green Valley (D5), comme la mer des autres îles. Garde-corps pleins sur les 7 ponts, muret de bord sur l'île d'arrivée |

## Réalisé

| Élément | Changement |
|---|---|
| `tools/studio/build_world_mystic_world.luau` (nouveau) | Archipel en primitives, graine fixe, rejouable (remplace seulement ce qu'il a créé pour Mystic World) ; même architecture que Frozen Peaks ; nombre de points dérivé des poids de `ResourceConfig` ; assertions de budget, d'ancrage, d'ombres, d'absence de lumière, d'émetteur et de script dans le décor |
| `Shared/Config/ResourceVisualConfig` | Modèles à plusieurs pièces des cinq ressources de Mystic World ; particules du Cœur mystique (4/s) |
| `Systems/StudioTestPresets` | Préréglages Studio `U7_mystic_locked` (Backpack 9) et `U7_mystic_ready` (Backpack 10, 250 000 Coins) ; outil de test, Studio uniquement |

Serveur de jeu (collecte, vente, voyage, inventaire), prix, réapparitions,
raretés, conditions de déblocage, schéma v2, protections T6 : **inchangés**.
Aucun nouveau RemoteEvent, aucun asset tiers, `Lighting` et
`StreamingEnabled` non modifiés, `GrabAndGrow.rbxl` non touché.

## Organisation de la carte

Centre : (0 ; 0 ; 3000), au nord de Green Valley, sans chevauchement avec
les autres îles (x = ±3000). Sept îles flottantes (dessus en disque, rebord
de pierre, dessous en couches octogonales de roche) dans environ
255 × 216 studs. Coordonnées relatives au centre ; +Z = nord.

Boucle de ponts : arrivée → forêt → grotte → sanctuaire → îles flottantes →
arrivée. Le sanctuaire n'est pas relié directement à l'arrivée : il est
visible de loin et se découvre par l'un des deux côtés de la boucle.

| Zone | Île (centre, rayon) | Contenu | Ressources |
|---|---|---|---|
| A — Île d'arrivée | (0 ; -60), r 44 | Place (r 16), arrivée (0 ; 0,3 ; -56), portail vers Green Valley (0 ; -90), vente `MysticWorld_Arrival` (22 ; -64), obélisque de cristal (repère du monde), poteau à 3 flèches sans texte (violet : forêt et grotte, cyan : îles, magenta : sanctuaire), muret de bord ouvert aux ponts | 16 Poudres mystiques (12–30 studs de la vente), 4 Éclats d'étoile (47–60) |
| B — Forêt mystique | (-90 ; -36), r 34 | 12 arbres fantastiques, 6 champignons géants, plantes lumineuses, 2 ruines, cascade dans le vide | 8 Éclats d'étoile (jusqu'à 111 studs) |
| C — Îles flottantes | C1 (82 ; -42) r 22, C2 (110 ; 6) r 18, C3 (80 ; 52) r 18 | Arbres, plantes lumineuses, ruines, cristaux, cascade (C2), rochers flottants autour | 7 Minerais spectraux (3 / 2 / 2), 54–141 studs |
| D — Grotte spectrale | (-74 ; 52), r 30 ; grotte (-78 ; 60), intérieur 18 × 20, plafond 11 | Entrée au sud encadrée de colonnes et de cristaux, stalactites Neon, cristaux aux parois, 4 plateformes de collecte | 4 Cristaux violets, 156–164 studs |
| E — Sanctuaire mystique | (10 ; 82), r 30, dessus à 4 studs | Estrade circulaire (r 13, +3 studs, rampe sud 12°), grande arche, couronne de colonnes (2 brisées) coiffées de cristaux, piédestal et couronne de cristaux, pierres suspendues, terrasse panoramique au nord, cascade | 1 Cœur mystique (150 studs) |
| Liaisons | 7 ponts de 8 studs (18–32 studs) | Tablier de pierre, garde-corps pleins de 1,4 stud, poteaux à lanternes Neon, cordes décoratives ; deux ponts inclinés à 7° vers le sanctuaire | — |
| Décor libre | — | 18 rochers flottants sans collision, 39 rochers de bord | — |

Distances (règle audit) : zone de base < 40 studs respectée (Poudre). Zone
avancée : 54–141 studs pour le Minerai spectral (au-delà de 90 sur C2 et
C3). Grotte et sanctuaire : lieux de découverte au-delà de 150 studs.
Boucle complète à pied (Backpack 10, sans Boots) : environ 43 s.

## Ressources et valeurs (`ResourceConfig`, inchangé)

| id | EN / FR | Rareté | Valeur | Réapparition | Nœuds | Modèle |
|---|---|---|---|---|---|---|
| `mystic_dust` | Mystic Dust / Poudre mystique | Commune | 68 | 3 s | 16 | Amas de 4 boules violettes et lavande |
| `star_fragment` | Star Fragment / Éclat d'étoile | Commune | 87 | 4 s | 12 | Deux coins cyan et bleu clair, éclat |
| `spectral_ore` | Spectral Ore / Minerai spectral | Peu commune | 125 | 8 s | 7 | Bloc sombre (Slate), 4 inclusions cyan et violettes |
| `purple_crystal` | Purple Crystal / Cristal violet | Rare | 230 | 20 s | 4 | Prisme Neon vertical et deux pointes |
| `mystic_core` | Mystic Core / Cœur mystique | Épique | 480 | 60 s | 1 | Noyau Neon magenta, facettes violettes, pointes magenta et cyan ; particules |

Neon réservé aux raretés Rare et Épique, particules à l'Épique (ConfigTests).

## Mesures (Studio)

| Mesure | Budget (audit T8) | Mesuré |
|---|---|---|
| BaseParts de décor (`Map.MysticWorld`) | ~1 200 | 719 |
| Total créé par le script | — | 733 parts (+ 40 points invisibles) |
| Instances sous `Map.MysticWorld` | — | 853 |
| Nœuds de ressources | ~40 | 40 (+ 112 pièces de détail en jeu) |
| Lumières dynamiques | 0 | 0 (assertion du script) |
| Émetteurs de particules | 2 au plus par monde | 1 (Cœur mystique) ; 3 sur les quatre mondes |
| Scripts dans le décor | 0 | 0 (assertion du script) |
| Ombres / ancrage | désactivées / ancré | assertion du script sur tout le décor |
| Temps de construction (mode Edit) | — | 0,6 s |
| BaseParts du Workspace en Play (quatre îles, avatar) | — | 2 636 (1 711 en T8.4) |
| Instances du Workspace en Play | — | 3 322 |
| FPS client Studio (50 s, sanctuaire) | — | 59,5 (PC, non représentatif d'un téléphone) |
| Mémoire Studio en Play | — | 332 Mo client, 491 Mo total (non représentatif) |

Contrôles géométriques (raycasts, mode Edit) : les 40 points sont posés sur
une surface à 0,00 stud près (Cœur sur le piédestal, cristaux sur les
plateformes de la grotte) ; aucune part solide dans le volume d'un nœud
(seul signalement : la boîte englobante du disque de la place, sans
contact réel). Les 7 tabliers sont continus (aucun trou sur l'axe) ; pentes
0° et 7,1–7,3°.

## Tests

| Test | Type | Résultat |
|---|---|---|
| 19 suites Lune (`lune run tools/run_tests.luau`) | Automatisé | PASS |
| Mutation : Neon sur `spectral_ore` (Peu commune) | Automatisé | PASS (détectée par ConfigTests, code restauré, 19 suites OK ensuite) |
| `luau-lsp analyze` (sourcemap temporaire) | Automatisé | PASS (code 0, aucune erreur) |
| `rojo build` (fichier temporaire hors dépôt) | Automatisé | PASS |
| Construction en mode Edit, puis relance | Studio | PASS ; sans doublon (`Map`, `WorldArrivals`, `ResourceSpawnPoints`, `SellZones` : 4 îles) ; Green Valley 312, Golden Desert 442, Frozen Peaks 592 parts inchangés |
| Play : 19 suites au démarrage, 160 nœuds, 4 zones de vente, magasin en mémoire, préréglages listés | Studio | PASS |
| Voyage, collecte et déblocage avant les conditions (`U7_mystic_locked`) | Studio | PASS (`WORLD_LOCKED` ×2, `REQUIREMENT_NOT_MET`) |
| Déblocage puis voyage (`U7_mystic_ready`) | Studio | PASS (-250 000 Coins journalisé ; arrivée exacte en 0 ; 3,2 ; 2944) |
| Collecte des 5 ressources à pied sur toute la boucle (arrivée, îles C1–C3, sanctuaire par la rampe, grotte, forêt) | Studio | PASS (6 × `SUCCESS`) |
| Vente à l'île d'arrivée | Studio | PASS : +1 077 = 68 + 2 × 87 + 125 + 230 + 480 ; seconde vente `NOTHING_TO_SELL` |
| Double collecte du même nœud | Studio | PASS (`SUCCESS` puis `RESOURCE_UNAVAILABLE`) |
| Réapparition (mesure serveur) | Studio | PASS : Poudre 3,02 s ; Éclat 4,00 s ; Minerai 8,01 s ; Cristal violet 20,02 s ; Cœur 60,02 s (détails et particules restaurés) |
| Sécurité : cristal demandé depuis l'arrivée, id inconnu, champ `amount`, `position` dans le voyage, monde inconnu, payload non table, vente dans la zone d'un autre monde, 15 demandes rapprochées | Studio | PASS (`TOO_FAR`, `INVALID_TARGET` ×5, `TOO_FAR`, `RATE_LIMITED` ; aucun déplacement) |
| Portails : prompts « Voyager / Green Valley » et « Voyager / Mystic World » ; aller-retour | Studio | PASS (arrivées exactes) |
| Chute depuis le bord de la forêt | Studio | PASS (réapparition au hub de Green Valley après 13,5 s, D5) |
| Noms EN/FR | Automatisé | PASS (`LocalizationTests`) ; affichage en jeu des noms FR non relu |
| Journal serveur | Studio | Aucune ligne `[Movement]`, aucune erreur de script |
| Captures | Studio | 6 captures en mode Edit : `phases/T8_5_captures/` |
| Local Server à 2 joueurs (section suivante) | Studio, multijoueur | PASS |
| Appui réel sur F / toucher au portail, manette | Manuel | NOT TESTED |
| Rendu des modèles de ressources en jeu (captures disponibles en mode Edit seulement) | Manuel | NOT TESTED |
| Performance mobile, téléphone réel | Manuel | NOT TESTED |

## Test multijoueur (Local Server, 2 joueurs, 2026-11-15)

Conditions : Local Server à 2 joueurs lancé par le propriétaire, piloté par
MCP (RemoteEvents du jeu, déplacements par `Humanoid:MoveTo`, envois
synchronisés sur `GetServerTimeNow`). Magasin en mémoire ; 19 suites OK au
démarrage ; 160 nœuds (40 dans Mystic World), 4 zones de vente.
A = Player1 (UserId -1) en `U7_mystic_ready`, B = Player2 (-2) en
`U7_mystic_locked`.

| # | Étape | Résultat observé |
|---|---|---|
| 1 | A débloque Mystic World ; B (Backpack 9) voyage, voyage avec `unlocked = true`, collecte `mystic_dust_001`, tente le déblocage | A `SUCCESS` (-250 000, succès `world_2` +1 000) ; B `WORLD_LOCKED`, `INVALID_TARGET` (`extra_field`), `WORLD_LOCKED`, `REQUIREMENT_NOT_MET` ; B immobile (0,00 stud) |
| 2 | B passe en `U7_mystic_ready` et débloque ; voyages simultanés vers Mystic World | B `SUCCESS` (-250 000) ; 2 × `SUCCESS` ; A et B au point d'arrivée (écartés d'environ 1 stud par la collision des avatars) |
| 3 | A et B collectent `mystic_dust_008` au même instant | Un seul `SUCCESS` (A) ; B `RESOURCE_UNAVAILABLE` |
| 4 | Collectes simultanées de deux nœuds distincts (`mystic_dust_006`, `mystic_dust_016`) | 2 × `SUCCESS` |
| 5 | Ventes simultanées à `MysticWorld_Arrival` | A +136 (2 Poudres), solde 1 136 ; B +68 (1 Poudre), solde 1 068 ; montants exacts, opérations distinctes (`Sell-1`, `Sell-2`), inventaires indépendants |
| 6 | A collecte une Poudre puis est déconnecté (`Kick` serveur) | `sauvegarde (sortie) OK, verrou libéré` |
| 7 | B après le départ de A : collecte, vente, voyage vers Green Valley | `SUCCESS` ×3 ; +68, solde 1 136 ; B à (0 ; 3,2 ; 12) |

Journal serveur sur toute la session : aucune ligne `[Movement]`, aucune
erreur de script. Non couvert : reconnexion du **même** joueur (impossible
en Local Server ; couverte par Lune en T8.1), latence réelle.

Avertissements observés au démarrage du Play, sans lien avec T8.5 : assets
d'avatar connus `rbxassetid://203785492` et `81504106`, déjà signalés en
T8.1 (`T8_IMPLEMENTATION_REPORT.md`).

DataStore de production non utilisé (magasin en mémoire). Place Studio
enregistré sur Roblox avec les quatre îles le 2026-11-15, à la demande du
propriétaire (version 90, « T8.5 Mystic World ») ; non publié.

## Problèmes rencontrés

- Captures parallèles : délai dépassé ; captures refaites une par une.
- Néon violet (160, 70, 255) rendu rose dans le décor : teinte décalée vers
  le bleu (128, 72, 255).
- Premier jet : Éclats d'étoile à 97–141 studs de la vente ; répartis entre
  l'arrivée et la forêt.
- Exécution du script : copie temporaire synchronisée par Rojo dans
  `ServerOnlyConfig`, `require` d'un clone en mode Edit, copie supprimée.

## Risques résiduels

1. **Multijoueur** : Local Server à 2 joueurs réussi ; reconnexion du même
   joueur et latence mobile réelle non couvertes en Studio.
2. **Chutes** : archipel sans sol ; une chute renvoie au hub (13,5 s avec
   la réapparition) et impose un nouveau voyage. Garde-corps sur les
   ponts ; bords des autres îles signalés par des rochers seulement. À
   juger en jeu, surtout sur mobile.
3. **Noms FR** : écart avec le prompt tranché le 2026-11-15 (noms existants
   conservés, aucune modification).
4. **Éloignement** : Minerai spectral jusqu'à 141 studs, Cristaux violets et
   Cœur à plus de 150 studs ; temps de trajet à juger en jeu.
5. **Performance mobile** : 2 636 BaseParts en jeu avec quatre îles ;
   mesure sur téléphone et décision `StreamingEnabled` en T8.7.
6. **Rendu visuel** non vérifié en jeu sur petit écran (lisibilité des
   modèles, saturation des Neon).
7. **Place enregistré** (version 90) : en cas de perte, le script
   reconstruit Mystic World à l'identique.
