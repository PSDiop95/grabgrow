# Manifeste des assets 3D — GRAB & GROW

Dernière mise à jour : 2026-11-15 (T8.5, D-021 D7). Sons : voir
`SOUND_MANIFEST.md` (manifeste distinct, inchangé).

## Statut du manifeste

**À valider par le propriétaire.** Tant qu'il n'est pas validé, aucun
asset Polyfork (ni aucun autre asset tiers) n'est importé dans le jeu.

## État actuel

Aucun asset 3D tiers n'est intégré. Tout ce qui est visible est construit
par le code ou par des scripts de construction, avec des primitives Roblox
(Part, WedgePart, CornerWedgePart, Cylinder, Ball) :

| Élément | Source | Emplacement |
|---|---|---|
| Ressources collectables (formes, couleurs, matériaux) | Primitives, `Shared/Config/ResourceVisualConfig.lua` | Créées par `Systems/ResourceNodes` dans `Workspace.ResourceNodes` |
| Île de Green Valley (hub, portails, zones, décor), station de vente, point d'arrivée (T8.2) | Primitives, `tools/studio/build_green_valley.luau` (remplace `build_test_map.luau`) | `Workspace.Map`, `Workspace.SellZones`, `Workspace.WorldArrivals` |
| Île de Golden Desert (oasis, dunes, ruines et arche, crête, recoin secret), station de vente, point d'arrivée, portail de retour (T8.3) | Primitives (Part, WedgePart, Cylinder), `tools/studio/build_world_golden_desert.luau` | `Workspace.Map.GoldenDesert`, `Workspace.SellZones.GoldenDesert`, `Workspace.WorldArrivals.GoldenDesert` |
| Île de Frozen Peaks (camp, plateau, lac gelé et cascade, grotte de cristaux, sommet), station de vente, point d'arrivée, portail de retour (T8.4) | Primitives (Part, WedgePart, Cylinder, Ball), `tools/studio/build_world_frozen_peaks.luau` | `Workspace.Map.FrozenPeaks`, `Workspace.SellZones.FrozenPeaks`, `Workspace.WorldArrivals.FrozenPeaks` |
| Modèles des ressources de Frozen Peaks à plusieurs pièces (T8.4) | Primitives, `ResourceVisualConfig.details` | Enfants des nœuds dans `Workspace.ResourceNodes` |
| Particules du Diamant de glace (T8.4) | `ParticleEmitter` Roblox, texture par défaut, `ResourceVisualConfig.particles` | Enfant du nœud `ice_diamond_001` |
| Archipel de Mystic World (île d'arrivée, forêt mystique, îles flottantes, grotte spectrale, sanctuaire, 7 ponts suspendus, rochers flottants, cascades), station de vente, point d'arrivée, portail de retour (T8.5) | Primitives (Part, WedgePart, Cylinder, Ball), `tools/studio/build_world_mystic_world.luau` | `Workspace.Map.MysticWorld`, `Workspace.SellZones.MysticWorld`, `Workspace.WorldArrivals.MysticWorld` |
| Modèles des ressources de Mystic World à plusieurs pièces (T8.5) | Primitives, `ResourceVisualConfig.details` | Enfants des nœuds dans `Workspace.ResourceNodes` |
| Particules du Cœur mystique (T8.5) | `ParticleEmitter` Roblox, texture par défaut, `ResourceVisualConfig.particles` | Enfant du nœud `mystic_core_001` |
| Particules du Cristal solaire (T8.3) | `ParticleEmitter` Roblox, texture par défaut, `ResourceVisualConfig.particles` | Enfant du nœud `sun_crystal_001` |
| Interface (HUD, boutique) | Instances d'interface créées par les contrôleurs | `PlayerGui` |

Les primitives Roblox ne demandent ni licence ni attribution : elles ne
sont pas listées une par une.

## Règles d'intégration (CLAUDE.md §11, GDD 14)

1. Un asset = une ligne, **avant** son import dans Studio.
2. Licence vérifiée **fichier par fichier** (jamais « toute la
   bibliothèque ») ; noter si l'usage commercial est permis et si une
   attribution est exigée.
3. Conserver le fichier source si la licence le permet (hors Git si
   volumineux : emplacement noté dans la ligne).
4. Tester échelle, pivots, matériaux et collisions dans Studio, puis sur
   téléphone réel ; budgets indicatifs du GDD 14.6 (petite ressource
   100–800 triangles, prop simple 300–1 500, décor majeur 2 000–6 000).
5. Ne jamais retirer les informations de provenance. Toute modification
   (réduction, recoloration, découpe) est notée.
6. Statut : à rechercher / sélectionné / téléchargé / importé / validé /
   rejeté.

## Politique de licence T10 (D-025, D-026, 2026-11-22)

- Meshes Polyfork utilisés sous **CC BY 4.0** : ligne de crédit de la fiche
  (« <Titre> by Polyfork (<URL>), CC BY 4.0 ») recopiée dans la colonne
  Attribution, avec la mention des modifications (recoloration, échelle,
  matériaux).
- Licence revérifiée **fichier par fichier** au téléchargement (date).
- Une ligne par asset, statut « sélectionné » puis « téléchargé », remplie
  **avant** l'import dans Studio. Sélection : `T10_RESOURCE_ASSET_SELECTION.md`.
- Crédits à publier (description de l'expérience, écran Crédits) avant
  toute publication publique.
- **Contrôle T10.4 (2026-11-22)** : 20 lignes `res_*`, toutes CC BY 4.0
  vérifiées le 2026-11-22, attribution « modifié » renseignée ; 20 gabarits
  présents dans `ServerStorage.ResourceTemplates` du place de test.
  Gardiens et sites sacrés : primitives Roblox, aucun asset tiers.
  **Crédits pas encore affichés** (ni jeu, ni description) : bloquant avant
  publication publique.
- **GLB corrigés (T10.1, 2026-11-22)** : `assets_src/polyfork/fixed/<id>.glb`,
  produits par `tools/fix_glb_colors.luau` à partir des fichiers source
  (inchangés). Modification : couleurs de sommets converties linéaire →
  sRGB (l'import Roblox les lit comme du sRGB) ; feuille recolorée du roux
  au vert (4 teintes ; palette contrastée avec l'herbe depuis le
  2026-11-22 : limbe 214,232,76, bord 40,98,30). Géométrie, UV et matériaux glTF inchangés. Concerne
  `res_green_leaf`, `res_copper_ore`, `res_silver_ore`, `res_purple_crystal` ;
  attribution « modifié » déjà portée par ces lignes.

## Assets tiers

| Nom interne | Nom source | Identifiant ou URL | Catégorie | Monde | Fichier source | Format | Triangles | Licence et date de vérification | Usage commercial | Attribution | Modifications | Emplacement Roblox | Statut |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `res_green_leaf` (prototype T10.1) | Fallen Oak Leaf | `fallen-oak-leaf-5b15fe` — https://polyfork.dev/asset/fallen-oak-leaf-5b15fe | Ressource | Green Valley | `assets_src/polyfork/fallen-oak-leaf-5b15fe.glb` et `.fbx` (hors Git) | GLB, FBX | 648 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Fallen Oak Leaf by Polyfork (https://polyfork.dev/asset/fallen-oak-leaf-5b15fe), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`, 1 MeshPart) : sommets sRGB, recoloré vert ; pièce blanche, échelle ≈ 0,18 | `ServerStorage.ResourceTemplates.green_leaf` (place de test 93404872714886) | Prototype T10.1 (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) |
| `res_copper_ore` (prototype T10.1) | Copper Ore Deposit | `copper-ore-deposit-d5e58b` — https://polyfork.dev/asset/copper-ore-deposit-d5e58b | Ressource | Golden Desert | `assets_src/polyfork/copper-ore-deposit-d5e58b.glb` et `.fbx` (hors Git) | GLB, FBX | 685 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Copper Ore Deposit by Polyfork (https://polyfork.dev/asset/copper-ore-deposit-d5e58b), CC BY 4.0 » — modifié | GLB corrigé (2 MeshParts) : sommets sRGB ; pièces blanches | `ServerStorage.ResourceTemplates.copper_ore` (place de test) | Prototype T10.1 (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) |
| `res_silver_ore` (prototype T10.1) | Silver Ore Deposit | `silver-ore-deposit-57f7c3` — https://polyfork.dev/asset/silver-ore-deposit-57f7c3 | Ressource | Frozen Peaks | `assets_src/polyfork/silver-ore-deposit-57f7c3.glb` (hors Git) | GLB | 729 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Silver Ore Deposit by Polyfork (https://polyfork.dev/asset/silver-ore-deposit-57f7c3), CC BY 4.0 » — modifié | GLB corrigé (2 MeshParts) : sommets sRGB ; Metal sur `deposit-metal` | `ServerStorage.ResourceTemplates.silver_ore` (place de test) | Prototype T10.1 (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) |
| `res_purple_crystal` (prototype T10.1) | Amethyst Ore Deposit | `amethyst-ore-deposit-02d55d` — https://polyfork.dev/asset/amethyst-ore-deposit-02d55d | Ressource | Mystic World | `assets_src/polyfork/amethyst-ore-deposit-02d55d.glb` (hors Git) | GLB | 733 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Amethyst Ore Deposit by Polyfork (https://polyfork.dev/asset/amethyst-ore-deposit-02d55d), CC BY 4.0 » — modifié | GLB corrigé (2 MeshParts) : sommets sRGB ; cristaux Neon violets agrandis ×1,6 (config) | `ServerStorage.ResourceTemplates.purple_crystal` (place de test) | Prototype T10.1 (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) |
| `res_wood` | Fallen Log | `fallen-log-1685fb` — https://polyfork.dev/asset/fallen-log-1685fb | Ressource | Green Valley | `assets_src/polyfork/fallen-log-1685fb.glb` (hors Git) | GLB | 484 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Fallen Log by Polyfork (https://polyfork.dev/asset/fallen-log-1685fb), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB | `ServerStorage.ResourceTemplates.wood` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_stone` | Medium Rock | `medium-rock-e08405` — https://polyfork.dev/asset/medium-rock-e08405 | Ressource | Green Valley | `assets_src/polyfork/medium-rock-e08405.glb` (hors Git) | GLB | 374 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Medium Rock by Polyfork (https://polyfork.dev/asset/medium-rock-e08405), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB | `ServerStorage.ResourceTemplates.stone` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_wild_fruit` | Apple | `apple-b15012` — https://polyfork.dev/asset/apple-b15012 | Ressource | Green Valley | `assets_src/polyfork/apple-b15012.glb` (hors Git) | GLB | 276 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Apple by Polyfork (https://polyfork.dev/asset/apple-b15012), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB | `ServerStorage.ResourceTemplates.wild_fruit` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_green_crystal` | Emerald Ore Deposit | `emerald-ore-deposit-4f0566` — https://polyfork.dev/asset/emerald-ore-deposit-4f0566 | Ressource | Green Valley | `assets_src/polyfork/emerald-ore-deposit-4f0566.glb` (hors Git) | GLB | 702 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Emerald Ore Deposit by Polyfork (https://polyfork.dev/asset/emerald-ore-deposit-4f0566), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; cristaux Neon (config) | `ServerStorage.ResourceTemplates.green_crystal` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_sandstone` | Sandstone Outcrop | `sandstone-outcrop-75800b` — https://polyfork.dev/asset/sandstone-outcrop-75800b | Ressource | Golden Desert | `assets_src/polyfork/sandstone-outcrop-75800b.glb` (hors Git) | GLB | 786 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Sandstone Outcrop by Polyfork (https://polyfork.dev/asset/sandstone-outcrop-75800b), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; recoloré ocre clair | `ServerStorage.ResourceTemplates.sandstone` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_fossil` | Fossil Ribcage | `fossil-ribcage-b243c5` — https://polyfork.dev/asset/fossil-ribcage-b243c5 | Ressource | Golden Desert | `assets_src/polyfork/fossil-ribcage-b243c5.glb` (hors Git) | GLB | 800 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Fossil Ribcage by Polyfork (https://polyfork.dev/asset/fossil-ribcage-b243c5), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB | `ServerStorage.ResourceTemplates.fossil` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_gold_nugget` | Gold Nugget | `gold-nugget-ccd143` — https://polyfork.dev/asset/gold-nugget-ccd143 | Ressource | Golden Desert | `assets_src/polyfork/gold-nugget-ccd143.glb` (hors Git) | GLB | 587 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Gold Nugget by Polyfork (https://polyfork.dev/asset/gold-nugget-ccd143), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; sans Neon (le Neon aplatissait la pépite) | `ServerStorage.ResourceTemplates.gold_nugget` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_sun_crystal` | Glowing Crystal Cluster | `lair-crystal-column-877d1a` — https://polyfork.dev/asset/lair-crystal-column-877d1a | Ressource | Golden Desert | `assets_src/polyfork/lair-crystal-column-877d1a.glb` (hors Git) | GLB | 512 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Glowing Crystal Cluster by Polyfork (https://polyfork.dev/asset/lair-crystal-column-877d1a), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; cristaux rouges recolorés orange ; Neon (config) | `ServerStorage.ResourceTemplates.sun_crystal` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_ice_shard` | Crystal Shard | `crystal-shard-9e0a83` — https://polyfork.dev/asset/crystal-shard-9e0a83 | Ressource | Frozen Peaks | `assets_src/polyfork/crystal-shard-9e0a83.glb` (hors Git) | GLB | 208 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Crystal Shard by Polyfork (https://polyfork.dev/asset/crystal-shard-9e0a83), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; recoloré glace pâle | `ServerStorage.ResourceTemplates.ice_shard` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_frozen_stone` | Boulder Field Cluster | `boulder-field-cluster-08e364` — https://polyfork.dev/asset/boulder-field-cluster-08e364 | Ressource | Frozen Peaks | `assets_src/polyfork/boulder-field-cluster-08e364.glb` (hors Git) | GLB | 734 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Boulder Field Cluster by Polyfork (https://polyfork.dev/asset/boulder-field-cluster-08e364), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; touffes d'herbe et RootPart de l'importeur exclus ; variante par défaut (pas de variante `count`) | `ServerStorage.ResourceTemplates.frozen_stone` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_blue_crystal` | Sapphire Ore Deposit | `sapphire-ore-deposit-f8a71a` — https://polyfork.dev/asset/sapphire-ore-deposit-f8a71a | Ressource | Frozen Peaks | `assets_src/polyfork/sapphire-ore-deposit-f8a71a.glb` (hors Git) | GLB | 473 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Sapphire Ore Deposit by Polyfork (https://polyfork.dev/asset/sapphire-ore-deposit-f8a71a), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; cristaux Neon (config) | `ServerStorage.ResourceTemplates.blue_crystal` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_ice_diamond` | Rough Diamond | `rough-diamond-fecf28` — https://polyfork.dev/asset/rough-diamond-fecf28 | Ressource | Frozen Peaks | `assets_src/polyfork/rough-diamond-fecf28.glb` (hors Git) | GLB | 362 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Rough Diamond by Polyfork (https://polyfork.dev/asset/rough-diamond-fecf28), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; Neon (config) | `ServerStorage.ResourceTemplates.ice_diamond` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_mystic_dust` | Gem Chip Heap | `gem-chip-heap-573355` — https://polyfork.dev/asset/gem-chip-heap-573355 | Ressource | Mystic World | `assets_src/polyfork/gem-chip-heap-573355.glb` (hors Git) | GLB | 662 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Gem Chip Heap by Polyfork (https://polyfork.dev/asset/gem-chip-heap-573355), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; recoloré lavande | `ServerStorage.ResourceTemplates.mystic_dust` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_star_fragment` | Meteorite | `meteorite-c400d9` — https://polyfork.dev/asset/meteorite-c400d9 | Ressource | Mystic World | `assets_src/polyfork/meteorite-c400d9.glb` (hors Git) | GLB | 630 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Meteorite by Polyfork (https://polyfork.dev/asset/meteorite-c400d9), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; recoloré bleu nuit et cyan | `ServerStorage.ResourceTemplates.star_fragment` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_spectral_ore` | Geode Boulder | `geode-boulder-e8091d` — https://polyfork.dev/asset/geode-boulder-e8091d | Ressource | Mystic World | `assets_src/polyfork/geode-boulder-e8091d.glb` (hors Git) | GLB | 589 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Geode Boulder by Polyfork (https://polyfork.dev/asset/geode-boulder-e8091d), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; cristaux blancs recolorés violet | `ServerStorage.ResourceTemplates.spectral_ore` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |
| `res_mystic_core` | Divination Orb | `divination-orb-115d77` — https://polyfork.dev/asset/divination-orb-115d77 | Ressource | Mystic World | `assets_src/polyfork/divination-orb-115d77.glb` (hors Git) | GLB | 688 | CC BY 4.0, fiche vérifiée le 2026-11-22 (`free: true`) | Oui | « Divination Orb by Polyfork (https://polyfork.dev/asset/divination-orb-115d77), CC BY 4.0 » — modifié | GLB corrigé (`fixed/`) : sommets sRGB ; orbe et éclats recolorés magenta ; fittings, gems et RootPart de l'importeur exclus ; Neon (config) | `ServerStorage.ResourceTemplates.mystic_core` (place de test 93404872714886) | Importé (GLB corrigé, import manuel Studio 2026-11-22, sans assetId de modèle) ; validation visuelle et mobile en attente |

## Candidats à rechercher (après validation du manifeste)

Catégories prioritaires (GDD 14.2 et 14.8), une recherche par monde :
arbres et rochers (Green Valley), dunes, cactus et ruines (Golden Desert),
sapins enneigés et blocs de glace (Frozen Peaks), plantes et cristaux
fantastiques (Mystic World). Les ressources emblématiques, stations de
vente et portails restent prévus sur mesure (GDD 14.8).
