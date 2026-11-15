# T8.3 — Golden Desert : rapport

Date : 2026-11-15. Étape A présentée puis étape B autorisée par le
propriétaire le 2026-11-15 (résolutions proposées acceptées, particules
comprises). **T8.3 validée par le propriétaire le 2026-11-15** ; commit
autorisé le même jour.

## Écarts du prompt résolus à l'étape A

| Écart | Résolution appliquée |
|---|---|
| Répartition « 16 communes / 12 peu communes / 7 rares / 4 / 1 » | Raretés de `ResourceConfig` conservées : Grès 16, Cuivre brut 12 (Communes), Fossile 7 (Peu commune), Pépite d'or 4 (Rare), Cristal solaire 1 (Épique) |
| « Minerai de cuivre » (17 caractères) | « Cuivre brut » conservé (16 caractères au plus, `LocalizationTests`) |
| Particules du Cristal solaire | Champ facultatif `particles` dans `ResourceVisualConfig`, réservé à l'Épique (test), émetteur coupé pendant la réapparition |

## Réalisé

| Élément | Changement |
|---|---|
| `tools/studio/build_world_golden_desert.luau` (nouveau) | Île en primitives, graine fixe, rejouable (remplace seulement ce qu'il a créé pour Golden Desert) |
| `Shared/Config/ResourceVisualConfig` | Champ facultatif `particles` ; Cristal solaire : 4 particules/s, doré |
| `Systems/ResourceNodes` | Crée l'émetteur si `particles` est défini ; `Enabled` suit l'état du nœud |
| `Tests/ConfigTests` | Particules réservées à l'Épique, débit dans ]0, 8] |

Serveur de jeu, prix, réapparitions, conditions de déblocage, schéma v2 :
inchangés. Aucun asset tiers. Aucun nouveau RemoteEvent ni code de voyage.

## Organisation de la carte

Centre de l'île : (3000 ; 0 ; 0), à plus de 2 000 studs de Green Valley.
Trois dalles croisées (environ 270 × 270 studs), falaise ocre, mer sans
collision (une chute renvoie au hub de Green Valley, D5). Coordonnées
ci-dessous relatives au centre ; +Z = nord.

| Zone | Contenu | Ressources |
|---|---|---|
| A — Arrivée et oasis | Place (rayon 18), arrivée (0 ; 0,3 ; 6), portail vers Green Valley (0 ; 26), bassin turquoise et 8 palmiers (28 ; -8), vente `GoldenDesert_Oasis` (-16 ; -12) : comptoir de grès, auvent turquoise, pièce dorée | 16 Grès, à 22–46 studs de la place |
| B — Dunes (sud) | 10 dunes (deux WedgeParts chacune, crêtes orientées), petit point d'eau avec 2 palmiers | 12 Cuivre brut, entre les dunes |
| C — Ruines (ouest, -82 ; 6) | Arche rocheuse monumentale au-dessus du chemin (sommet à 21 studs), dallage, 8 colonnes (2 brisées), linteau, colonne couchée, murets | 7 Fossiles |
| D — Crête (nord-est, 66 ; 74) | Plateau à 10 studs, blocs de falaise, rampe de 44 studs (pente 13°) bordée de rochers, point de vue vers l'oasis (pierres dressées, muret) | 4 Pépites d'or sur le plateau |
| E — Recoin secret (nord-ouest, -96 ; 98) | Cercle de pierres dressées ouvert au sud, disque doré, piédestal ; sentier sinueux depuis les ruines, bordé de rochers | 1 Cristal solaire (piédestal, Neon, particules) |
| Décor | 10 palmiers, 26 cactus, 44 rochers, 30 touffes d'herbe sèche, chemins de sable vers chaque zone | — |

Distances horizontales à la vente (mesurées par le script) : Grès 12,6 ;
Cuivre 37 ; Fossile 51 ; Pépite d'or 115 ; Cristal solaire 136 studs.
La zone avancée (ruines) est à 51–75 studs de la vente ; la crête est au-delà
de la cible de 60–90 studs (115 à vol d'oiseau, plus la rampe) : à juger en
test de jeu.

## Ressources et valeurs (Bible 1.1, inchangées)

| id | FR / EN | Rareté | Valeur | Réapparition | Nœuds |
|---|---|---|---|---|---|
| `sandstone` | Grès / Sandstone | Commune | 5 | 3 s | 16 |
| `copper_ore` | Cuivre brut / Copper Ore | Commune | 6 | 4 s | 12 |
| `fossil` | Fossile / Fossil | Peu commune | 9 | 8 s | 7 |
| `gold_nugget` | Pépite d'or / Gold Nugget | Rare | 17 | 20 s | 4 |
| `sun_crystal` | Cristal solaire / Sun Crystal | Épique | 38 | 60 s | 1 |

## Mesures (Studio, mode Edit puis Play)

| Mesure | Budget (audit T8) | Mesuré |
|---|---|---|
| BaseParts de décor de l'île (`Map.GoldenDesert`) | ~1 200 | 442 |
| Total créé par le script (décor, vente, arrivée) | — | 450 parts (+ 40 points de spawn invisibles) |
| Instances sous `Map.GoldenDesert` | — | 509 |
| Nœuds de ressources | ~40 | 40 |
| Lumières dynamiques | 0 | 0 |
| Émetteurs de particules | 2 au plus | 1 (Cristal solaire) |
| Ombres | désactivées | `CastShadow = false` sur tout le décor (assertion du script) et sur les nœuds |
| Décor ancré | oui | oui (assertion du script) |
| BaseParts du Workspace en jeu (deux îles, avatar compris) | — | 948 (418 en T8.2) |
| Instances du Workspace en jeu | — | 1 375 |
| Mémoire Studio en Play | — | 470 Mo (Studio, non représentatif d'un téléphone) |

Contrôles géométriques (raycasts, mode Edit) : les 40 points sont posés sur
une surface à 0,25 stud près, aucun ne chevauche une part solide ; la rampe
monte régulièrement de 0 à 10 studs.

## Tests

| Test | Type | Résultat |
|---|---|---|
| 19 suites Lune (`lune run tools/run_tests.luau`) | Automatisé | PASS |
| Mutation : particules sur `gold_nugget` | Automatisé | PASS (détectée par ConfigTests, code restauré) |
| `luau-lsp analyze` (définitions `.tools/globalTypes.d.luau`, sourcemap temporaire) | Automatisé | PASS (0 erreur) |
| `rojo build` (fichier temporaire hors dépôt) | Automatisé | PASS |
| Construction en mode Edit | Studio | PASS (40 points, 442 parts, Green Valley intact : 312 parts) |
| Relance du script sans doublon | Studio | NOT TESTED (même mécanisme `replace` que Green Valley, non relancé) |
| Play : 19 suites au démarrage, 80 nœuds, 2 zones de vente, magasin en mémoire | Studio | PASS |
| Voyage et collecte avant déblocage | Studio | PASS (`WORLD_LOCKED` pour les deux) |
| Déblocage (U7_ready, `RequestUnlockWorld`) puis voyage | Studio | PASS (arrivée exacte en 3000 ; 3,2 ; 6 ; « Bienvenue dans Golden Desert ! ») |
| Collecte des 5 ressources en marchant (`Humanoid:MoveTo`), y compris rampe et sentier secret | Studio | PASS (5 × `SUCCESS`) |
| Double collecte du même nœud | Studio | PASS (`RESOURCE_UNAVAILABLE`, deux fois) |
| Réapparition (mesure serveur) | Studio | PASS : Fossile 8,02 s, Cristal solaire 60,00 s ; Grès ≈ 3 s (mesure client, latence comprise) |
| Particules du Cristal solaire | Studio | PASS (actives, coupées pendant la réapparition) |
| Vente à l'oasis | Studio | PASS : +80 Coins = 2 × 5 + 6 + 9 + 17 + 38 ; seconde vente `NOTHING_TO_SELL` |
| Noms EN/FR des 5 ressources et du monde | Studio | PASS |
| Portail de retour : prompt « Voyager / Green Valley », boutique « Vous êtes ici » / « Voyager » | Studio | PASS (état vérifié) |
| Aller-retour Golden Desert → Green Valley → Golden Desert, collecte à Green Valley entre les deux | Studio | PASS (arrivées exactes) |
| Mort au désert | Studio | PASS (réapparition au hub de Green Valley, D5) |
| Sécurité : position et CFrame dans la demande, payload non table, monde inconnu, `amount` et `value` ajoutés, nœud inconnu, nœud trop loin, 15 demandes rapprochées | Studio | PASS (`INVALID_TARGET`, `TOO_FAR`, `RATE_LIMITED` ; aucun déplacement) |
| MovementValidator après 4 voyages et une mort | Studio | PASS (aucune ligne `[Movement]`, aucune erreur de script) |
| Appui réel sur F / toucher au portail, clic sur « Voyager » | Manuel | NOT TESTED (entrées simulées non transmises par MCP) |
| Captures (vue générale, oasis, ruines, crête, Cristal) | Manuel | NOT TESTED (capture Studio vide, comme en T8.2) |
| Local Server à 2 joueurs (section suivante) | Studio, multijoueur | PASS |
| Reconnexion, profils indépendants | Automatisé (Lune, T8.1) | PASS en Lune ; NOT TESTED sur la carte T8.3 |
| Téléphone réel, DataStore de test | Manuel | NOT TESTED |

Régression : les 19 suites couvrent collecte, inventaire, vente,
améliorations, déblocage, sauvegarde et sécurité T6 ; en Play, collecte,
vente et voyage à Green Valley fonctionnent. DataStore de production non
utilisé. `GrabAndGrow.rbxl` non touché.

## Test multijoueur (Local Server, 2 joueurs, 2026-11-15)

Conditions : Local Server à 2 joueurs lancé par le propriétaire, piloté par
MCP (RemoteEvents du jeu, déplacements par `Humanoid:MoveTo`, envois
synchronisés sur `GetServerTimeNow`). Magasin en mémoire confirmé ;
19 suites OK au démarrage ; 40 nœuds Golden Desert, 2 zones de vente.
A = Player1 (UserId -1), B = Player2 (-2), tous deux en `U7_ready`.

| # | Étape | Résultat observé |
|---|---|---|
| 1 | A débloque Golden Desert ; B (non débloqué) voyage, voyage avec `unlocked = true`, collecte `sandstone_001` | A `SUCCESS` (-1 500, succès +1 000) ; B `WORLD_LOCKED`, `INVALID_TARGET` (`extra_field`), `WORLD_LOCKED` ; B immobile |
| 2 | B débloque ; voyages simultanés vers Golden Desert | 2 × `SUCCESS`, journalisés à 8 ms d'écart ; A et B au point d'arrivée |
| 3 | A et B collectent `sandstone_008` au même instant | Un seul `SUCCESS` (B), A `RESOURCE_UNAVAILABLE` ; réapparition 3,01 s (serveur) |
| 4 | Collectes simultanées de deux nœuds distincts | 2 × `SUCCESS` |
| 5 | Ventes simultanées à l'oasis | Journalisées à 2 ms d'écart : B +10 (2 Grès), solde 1 010 ; A +5 (1 Grès), solde 1 005 ; montants exacts, opérations distinctes |
| 6 | A collecte un Grès puis est déconnecté (`Kick` serveur) | `sauvegarde (sortie) OK, verrou libéré` |
| 7 | B après le départ de A : collecte, vente, voyage vers Green Valley | `SUCCESS` ×3 ; +5, solde 1 015 ; B à (0 ; 3,2 ; 12) |

Journal serveur sur toute la session : aucune ligne `[Movement]`, aucune
erreur de script. Non couvert : reconnexion du **même** joueur (impossible
en Local Server : un nouveau joueur reçoit un autre UserId ; couverte par
Lune en T8.1).

## Problèmes rencontrés

- Orientation des WedgeParts vérifiée par raycast avant écriture (bas au -Z
  local) : la rampe et les dunes ont été construites en conséquence.
- Premier placement : point de vue sur le haut de la rampe et une pépite
  contre un bloc de falaise ; corrigés avant la construction (rampe à l'est,
  pépite déplacée).
- Le client lit `Available` avec un léger retard : une seconde demande sur
  un nœud tout juste collecté est refusée par le serveur (comportement
  voulu).

## Risques résiduels

1. **Rendu visuel non vérifié** : captures MCP vides ; à contrôler par le
   propriétaire (lisibilité, couleurs, échelle).
2. **Multijoueur** : Local Server à 2 joueurs réussi ; reconnexion du même
   joueur et latence réelle non couvertes en Studio.
3. **Crête éloignée** (115 studs de la vente, plus la rampe) : temps de
   trajet à juger en jeu ; la rampe peut être rapprochée.
4. **Latence mobile (A-27)** après voyage : inchangée depuis T8.1.
5. **Place non enregistré** : la carte disparaît si Studio est fermé sans
   enregistrer (relancer le script).
6. **Valeurs et réapparitions** : hypothèses (Bible 1.1, D8), à mesurer.
7. **Performance mobile** : 948 BaseParts en jeu ; mesure sur téléphone et
   décision `StreamingEnabled` en T8.7.

## État de préparation

T8.3 : validée par le propriétaire le 2026-11-15 après les tests Studio à
un et deux joueurs. Rendu visuel et appui réel au portail : non vérifiés par MCP.
T8.4 non commencée.
