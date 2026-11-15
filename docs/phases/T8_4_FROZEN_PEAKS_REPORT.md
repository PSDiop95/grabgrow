# T8.4 — Frozen Peaks : rapport

Date : 2026-11-15. Lot demandé par le propriétaire le 2026-11-15 (prompt
T8.4 et son complément, sections 5 à 7), après validation de T8.3.
Prérequis vérifiés : T8.3 validée (`T8_3_GOLDEN_DESERT_REPORT.md`, commit
33830ca), D-021, Bible 1.1 (§ 3.4), rapports T8.2 et T8.3,
`WorldTravelService`, `ResourceSpawner`, `CollectionService`, `SellService`,
`ResourceVisualConfig`.
**T8.4 validée par le propriétaire le 2026-11-15** après les tests Studio à
un joueur et en Local Server à 2 joueurs. Non commitée.

## Écarts du prompt et résolutions

| Écart | Résolution appliquée |
|---|---|
| Le complément (§ 5 et § 6.1) donne `silver_ore` Peu commune et `frozen_stone` Commune ; `ResourceConfig` et la Bible 1.1 (validées) donnent l'inverse, et le même complément interdit de modifier les valeurs | **`ResourceConfig` conservé** (`silver_ore` Commune, 4 s, poids 30 ; `frozen_stone` Peu commune, 8 s, poids 18). Valeurs identiques (24 et 34). **Confirmé par le propriétaire le 2026-11-15** |
| Nom FR « Minerai d'argent » au lieu de « Argent brut » | Appliqué (16 caractères, limite `LocalizationTests` respectée). Écart de style avec « Cuivre brut » (T8.3) |
| Répartition : Éclats sur le plateau, Argent au lac et sur les pentes, Pierres gelées sur les chemins de montagne | Appliquée. Les Éclats restent à moins de 38 studs de la vente (bord du plateau côté camp) pour respecter la règle de la zone de base |
| Modèles 3D distinctifs | Champ facultatif `details` dans `ResourceVisualConfig` (4 pièces au plus par nœud) ; primitives, sans transparence |

## Réalisé

| Élément | Changement |
|---|---|
| `tools/studio/build_world_frozen_peaks.luau` (nouveau) | Île en primitives, graine fixe, rejouable (remplace seulement ce qu'il a créé pour Frozen Peaks) ; même architecture que Golden Desert ; nombres de points dérivés des poids de `ResourceConfig` |
| `Shared/Config/ResourceVisualConfig` | Champ `details` ; modèles des cinq ressources de Frozen Peaks ; particules du Diamant de glace (4/s) |
| `Systems/ResourceNodes` | Crée les pièces de détail (enfants du Part du nœud, sans collision ni requête, sans attributs) ; les masque et les réaffiche avec le nœud ; un détail invalide écarte le nœud avec un avertissement |
| `Tests/ConfigTests` | Détails : 4 au plus, formes, matériaux autorisés (pas de Glass ni ForceField), Neon réservé Rare/Épique, dimensions, décalages, couleurs ; matériau principal dans la même liste |
| `Shared/Util/Localization` | `resource.silver_ore` (FR) : « Minerai d'argent » |
| `Systems/StudioTestPresets` | Préréglages Studio `U7_peaks_locked` et `U7_peaks_ready` (outil de test, Studio uniquement) |

Serveur de jeu (collecte, vente, voyage, inventaire), prix, réapparitions,
raretés, conditions de déblocage, schéma v2 : inchangés. Aucun asset tiers.
Aucun nouveau RemoteEvent. `Lighting` non modifié. Le portail Green Valley
→ Frozen Peaks existait depuis T8.2.

## Modèles des ressources (primitives)

| Ressource | Modèle | Pièces |
|---|---|---|
| Éclat de glace | Deux facettes en coin, cyan pâle et blanc bleuté | 2 |
| Minerai d'argent | Roche grise, 3 inclusions argentées (matériau Metal) | 4 |
| Pierre gelée | Bloc gris foncé, plaque de glace dessus, plaque latérale, pointe de glace | 4 |
| Cristal bleu | Prisme Neon et deux pointes inclinées (grappe) | 3 |
| Diamant de glace | Deux cubes Neon cyan et bleu tournés (facettes), particules | 2 |

## Organisation de la carte

Centre de l'île : (-3000 ; 0 ; 0), à l'opposé de Golden Desert. Trois dalles
de neige croisées (environ 270 × 270 studs), falaise de roche, mer froide
sans collision (une chute renvoie au hub de Green Valley, D5). Coordonnées
relatives au centre ; +Z = nord.

| Zone | Contenu | Ressources |
|---|---|---|
| A — Camp de base | Place (rayon 18), arrivée (0 ; 0,3 ; 6), portail vers Green Valley (0 ; 26), vente `FrozenPeaks_Camp` (14 ; -12) : dalle jaune, comptoir de bois, toit bleu enneigé, pièce dorée ; 2 tentes, feu de camp (braises Neon, sans lumière), caisses, poteau à 3 flèches colorées sans texte (bleu : grotte, turquoise : lac, blanc : sommet) | — |
| B — Plateau enneigé (est) | Zone ouverte depuis le camp, 22 sapins en bosquets, 5 congères, petits chemins | 16 Éclats de glace sur le bord côté camp, à 14–37 studs de la vente |
| C — Lac gelé (sud-ouest, -48 ; -58) | Glace solide (rayon 22), 6 formations de glace, passage rocheux, falaise et cascade gelée, ruisseau gelé et pont de bois | 12 Minerai d'argent (8 sur la glace, 4 sur la rive), à 47–107 studs |
| Chemins de montagne | Chemin du sommet et chemin de la grotte, rochers | 7 Pierres gelées (5 et 2), à 39–101 studs |
| D — Grotte (nord-ouest, -82 ; 62) | Entrée au sud, rochers d'encadrement, stalactites, cristaux Neon aux parois et à l'entrée (aucune lumière dynamique) | 4 Cristaux bleus, à 116–127 studs |
| E — Sommet (nord-est) | Épaulement à 12 studs (rampe de 48 studs, 14°), sommet à 24 studs (rampe de 40 studs, 17°), parapet, cairn, fanion, piédestal de glace et couronne de cristaux | 1 Diamant de glace (110 studs, plus les rampes) |
| Décor | 48 sapins, 43 rochers coiffés de neige, 18 buissons d'hiver, 7 pics de fond infranchissables | — |

Distances : zone de base < 40 studs respectée. Les zones avancées (lac,
chemins) commencent à 39–47 studs ; la grotte et le sommet sont des lieux de
découverte, au-delà de 90 studs. À juger en jeu. Trajet à pied grotte →
sommet : 21 s.

## Ressources et valeurs (`ResourceConfig`, inchangé)

| id | EN / FR | Rareté | Valeur | Réapparition | Nœuds |
|---|---|---|---|---|---|
| `ice_shard` | Ice Shard / Éclat de glace | Commune | 18 | 3 s | 16 |
| `silver_ore` | Silver Ore / Minerai d'argent | Commune | 24 | 4 s | 12 |
| `frozen_stone` | Frozen Stone / Pierre gelée | Peu commune | 34 | 8 s | 7 |
| `blue_crystal` | Blue Crystal / Cristal bleu | Rare | 62 | 20 s | 4 |
| `ice_diamond` | Ice Diamond / Diamant de glace | Épique | 140 | 60 s | 1 |

## Mesures (Studio)

| Mesure | Budget (audit T8) | Mesuré |
|---|---|---|
| BaseParts de décor (`Map.FrozenPeaks`) | ~1 200 | 592 |
| Total créé par le script | — | 601 parts (+ 40 points invisibles) |
| Nœuds de ressources | ~40 | 40 (+ 98 pièces de détail en jeu) |
| Lumières dynamiques | 0 | 0 (assertion du script) |
| Émetteurs de particules | 2 au plus par monde | 1 (Diamant de glace) |
| Ombres / ancrage | désactivées / ancré | assertion du script sur tout le décor |
| BaseParts du Workspace en Play (trois îles, avatar) | — | 1 711 (948 en T8.3) |
| Instances du Workspace en Play | — | 2 259 |
| Mémoire Studio en Play | — | 335 Mo (non représentatif d'un téléphone) |

Contrôles géométriques (raycasts, mode Edit) : les 40 points sont posés sur
une surface à 0,25 stud près (cristaux bleus contrôlés sous le toit) ; aucun
ne chevauche une part solide. Profils : rampe 1 de 0 à 12,2 studs, rampe 2
de 12,2 à 24,2, pont 0,1 → 1,6 → 0,1.

## Tests

| Test | Type | Résultat |
|---|---|---|
| 19 suites Lune (`lune run tools/run_tests.luau`) | Automatisé | PASS |
| Mutation : détail Neon sur `silver_ore` | Automatisé | PASS (détectée par ConfigTests, code restauré) |
| `luau-lsp analyze` (sourcemap temporaire) | Automatisé | PASS (0 erreur) |
| `rojo build` (fichier temporaire hors dépôt) | Automatisé | PASS |
| Construction en mode Edit, puis relances | Studio | PASS ; sans doublon (`Map` : 3 îles) ; Green Valley et Golden Desert inchangés |
| Play : 19 suites au démarrage, 120 nœuds, 3 zones de vente, magasin en mémoire, détails sans collision ni requête | Studio | PASS |
| Voyage et collecte avant déblocage | Studio | PASS (`WORLD_LOCKED` ×2) |
| Déblocage puis voyage | Studio | PASS (-35 000 Coins journalisé ; arrivée exacte en -3000 ; 3,2 ; 6) |
| Collecte des 5 ressources à pied : plateau, chemin du sommet, lac, grotte par le pont, sommet par les deux rampes | Studio | PASS (5 × `SUCCESS` ; détails masqués après collecte) |
| Double collecte du même nœud | Studio | PASS (`RESOURCE_UNAVAILABLE`, premier passage) |
| Réapparition (mesure serveur) | Studio | PASS : Éclat 3,01 s ; Minerai 4,02 s ; Pierre gelée 8,02 s ; Diamant 60,02 s (détails et particules restaurés). Cristal bleu (20 s) non chronométré |
| Vente au camp | Studio | PASS : +278 = 18 + 24 + 34 + 62 + 140 (deux fois) ; seconde vente `NOTHING_TO_SELL` |
| Noms EN/FR des 5 ressources | Studio | PASS (dont « Minerai d'argent ») |
| Sécurité (premier passage) : cristal demandé depuis le camp, `amount` ajouté, `position` dans le voyage, monde inconnu, zone de vente d'un autre monde, 15 demandes rapprochées | Studio | PASS (`TOO_FAR`, `INVALID_TARGET` ×3, `TOO_FAR`, `RATE_LIMITED` ; aucun déplacement) |
| Portails : prompts « Voyager / Green Valley » et « Voyager / Frozen Peaks » ; allers-retours | Studio | PASS (arrivées exactes) |
| Mort à Frozen Peaks (premier passage) | Studio | PASS (réapparition au hub de Green Valley, D5) |
| Journal serveur | Studio | Aucune ligne `[Movement]`, aucune erreur de script |
| Local Server à 2 joueurs (section suivante) | Studio, multijoueur | PASS |
| Appui réel sur F / toucher au portail, manette | Manuel | NOT TESTED |
| Rendu visuel (lisibilité des modèles, couleurs, neige) | Manuel | NOT TESTED (capture Studio vide) |
| Performance mobile, téléphone réel | Manuel | NOT TESTED |

## Test multijoueur (Local Server, 2 joueurs, 2026-11-15)

Conditions : Local Server à 2 joueurs lancé par le propriétaire, piloté par
MCP (RemoteEvents du jeu, déplacements par `Humanoid:MoveTo`, envois
synchronisés sur `GetServerTimeNow`). Magasin en mémoire ; 19 suites OK au
démarrage ; 120 nœuds, 3 zones de vente. A = Player1 (UserId -1),
B = Player2 (-2), tous deux en `U7_peaks_ready`.

| # | Étape | Résultat observé |
|---|---|---|
| 1 | A débloque Frozen Peaks ; B (non débloqué) voyage, voyage avec `unlocked = true`, collecte `ice_shard_001` | A `SUCCESS` (-35 000, succès `world_2` +1 000) ; B `WORLD_LOCKED`, `INVALID_TARGET` (`extra_field`), `WORLD_LOCKED` ; B immobile |
| 2 | B débloque ; voyages simultanés vers Frozen Peaks | 2 × `SUCCESS` ; A et B au point d'arrivée (écartés de 2 studs par la collision des avatars) |
| 3 | A et B collectent `ice_shard_015` au même instant | Un seul `SUCCESS` (A) ; B `RESOURCE_UNAVAILABLE` |
| 4 | Collectes simultanées de deux nœuds distincts (`ice_shard_001`, `ice_shard_012`) | 2 × `SUCCESS` |
| 5 | Ventes simultanées au camp | B +18 (1 Éclat), solde 1 018 ; A +36 (2 Éclats), solde 1 036 ; montants exacts, opérations distinctes, inventaires indépendants |
| 6 | A collecte un Éclat puis est déconnecté (`Kick` serveur) | `sauvegarde (sortie) OK, verrou libéré` |
| 7 | B après le départ de A : collecte, vente, voyage vers Green Valley | `SUCCESS` ×3 ; +18, solde 1 036 ; B à (0 ; 3,2 ; 12) |

Journal serveur sur toute la session : aucune ligne `[Movement]`, aucune
erreur de script. Non couvert : reconnexion du **même** joueur (impossible
en Local Server ; couverte par Lune en T8.1), latence réelle.

DataStore de production non utilisé. `GrabAndGrow.rbxl` non touché. Place
Studio **non enregistré** par Claude.

## Problèmes rencontrés

- Premier placement du lac trop loin (76–106 studs) : lac rapproché, arrivées
  du chemin et du ruisseau calculées sur la rive.
- Exécution du script : copie temporaire synchronisée par Rojo dans
  `ServerOnlyConfig`, `require` d'un clone en mode Edit, copie supprimée.
- Rojo s'est arrêté pendant le lot : `rojo serve` relancé, plugin reconnecté
  par le propriétaire.

## Risques résiduels

1. **Multijoueur** : Local Server à 2 joueurs réussi ; reconnexion du même
   joueur et latence mobile réelle non couvertes en Studio.
2. **Raretés** : écart tranché le 2026-11-15 (`ResourceConfig` conservé,
   aucune modification).
3. **Rendu visuel non vérifié**, dont la lisibilité des modèles sur petit
   écran et l'éblouissement de la neige.
4. **Grotte et sommet éloignés** : temps de trajet à juger en jeu.
5. **Performance mobile** : 1 711 BaseParts en jeu avec trois îles ;
   mesure sur téléphone et décision `StreamingEnabled` en T8.7.
6. **Place non enregistré** : relancer le script si Studio est fermé sans
   enregistrer.
7. **Caméra dans la grotte** (plafond à 12 studs) : à vérifier sur
   téléphone.
