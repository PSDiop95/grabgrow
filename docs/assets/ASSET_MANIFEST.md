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

## Candidats à rechercher (après validation du manifeste)

Catégories prioritaires (GDD 14.2 et 14.8), une recherche par monde :
arbres et rochers (Green Valley), dunes, cactus et ruines (Golden Desert),
sapins enneigés et blocs de glace (Frozen Peaks), plantes et cristaux
fantastiques (Mystic World). Les ressources emblématiques, stations de
vente et portails restent prévus sur mesure (GDD 14.8).
