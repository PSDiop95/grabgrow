# Manifeste des assets 3D — GRAB & GROW

Dernière mise à jour : 2026-11-15 (T8.3, D-021 D7). Sons : voir
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

## Assets tiers

| Nom interne | Nom source | Identifiant ou URL | Catégorie | Monde | Fichier source | Format | Triangles | Licence et date de vérification | Usage commercial | Attribution | Modifications | Emplacement Roblox | Statut |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | — | — | — | — | — | Aucun asset tiers à ce jour |

## Candidats à rechercher (après validation du manifeste)

Catégories prioritaires (GDD 14.2 et 14.8), une recherche par monde :
arbres et rochers (Green Valley), dunes, cactus et ruines (Golden Desert),
sapins enneigés et blocs de glace (Frozen Peaks), plantes et cristaux
fantastiques (Mystic World). Les ressources emblématiques, stations de
vente et portails restent prévus sur mesure (GDD 14.8).
