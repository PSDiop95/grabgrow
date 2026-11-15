# T8 — Audit des mondes et conception (étape A)

Date : 2026-11-14. Étape A validée par le propriétaire le 2026-11-14
(D-021, décisions D1 à D10). Aucun fichier modifié pendant l'étape A.

## 1. État des quatre mondes (audit)

Place de test inspecté en lecture seule (Studio, mode Edit) :

| Monde | État |
|---|---|
| Green Valley | Sol plat 240 × 240 studs, 1 SpawnLocation, 36 points de spawn (16 feuilles, 12 bois, 8 pierres), 1 station de vente (6 Parts). Aucun décor ni zone ; tout est provisoire (`tools/studio/build_test_map.luau`). |
| Golden Desert, Frozen Peaks, Mystic World | Présents uniquement dans `WorldConfig` (conditions et paiement unique). Ni carte, ni ressources, ni vente, ni moyen d'y aller. |
| Global | `StreamingEnabled = false`, `GlobalShadows = false`, aucun MeshPart, aucune lumière ni particule. Pas de manifeste d'assets 3D. |

Systèmes : `ResourceSpawner`, `InventoryService`, `SellService`,
`SellZones` et `WorldUnlockService` sont génériques et conservés.
Lacunes relevées : visuels codés en dur et filtre « monde de départ » dans
`ResourceNodes` ; `CollectionService` ne vérifiait pas le déblocage du
monde de la ressource ; aucun voyage (une téléportation aurait déclenché
`MovementValidator`) ; simulateur limité à Green Valley ; détail du sac
(HUD) listant toutes les ressources configurées.

## 2. Catalogue des ressources (validé, D3 et D4)

| id | EN | FR | Monde | Rareté | Valeur | Réapparition (D8) |
|---|---|---|---|---|---|---|
| `green_leaf` | Green Leaf | Feuille | GV | Commune | 1 | 2 s |
| `wood` | Wood Chunk | Bois | GV | Commune | 2 | 3 s |
| `stone` | Stone | Pierre | GV | Commune | 3 | 4 s |
| `wild_fruit` | Wild Fruit | Fruit sauvage | GV | Peu commune | 5 | 8 s |
| `green_crystal` | Green Crystal | Cristal vert | GV | Rare | 12 | 20 s |
| `sandstone` | Sandstone | Grès | GD | Commune | 5 | 3 s |
| `copper_ore` | Copper Ore | Cuivre brut | GD | Commune | 6 | 4 s |
| `fossil` | Fossil | Fossile | GD | Peu commune | 9 | 8 s |
| `gold_nugget` | Gold Nugget | Pépite d'or | GD | Rare | 17 | 20 s |
| `sun_crystal` | Sun Crystal | Cristal solaire | GD | Épique | 38 | 60 s |
| `ice_shard` | Ice Shard | Éclat de glace | FP | Commune | 18 | 3 s |
| `silver_ore` | Silver Ore | Argent brut | FP | Commune | 24 | 4 s |
| `frozen_stone` | Frozen Stone | Pierre gelée | FP | Peu commune | 34 | 8 s |
| `blue_crystal` | Blue Crystal | Cristal bleu | FP | Rare | 62 | 20 s |
| `ice_diamond` | Ice Diamond | Diamant de glace | FP | Épique | 140 | 60 s |
| `mystic_dust` | Mystic Dust | Poudre mystique | MW | Commune | 68 | 3 s |
| `star_fragment` | Star Fragment | Éclat d'étoile | MW | Commune | 87 | 4 s |
| `spectral_ore` | Spectral Ore | Minerai spectral | MW | Peu commune | 125 | 8 s |
| `purple_crystal` | Purple Crystal | Cristal violet | MW | Rare | 230 | 20 s |
| `mystic_core` | Mystic Core | Cœur mystique | MW | Épique | 480 | 60 s |

Noms FR raccourcis à 16 caractères au plus (règle d'affichage mobile de
`LocalizationTests`) : « Cuivre brut », « Argent brut », « Poudre
mystique », « Éclat d'étoile ». Poids de spawn : Bible 3.2 à 3.5. Environ
40 nœuds par monde (16 / 12 / 7 / 4 / 1 ; Green Valley 16 / 12 / 8 / 3 / 1).

## 3. Fiches des mondes (structure GDD 8.5)

Un seul place, quatre îles éloignées (D2). Chaque île : environ
260 × 260 studs ; zone d'arrivée avec retour ; zone de base (communes) à
moins de 40 studs de la vente ; zone avancée (peu communes, rares) à
60–90 studs ; recoin ou point de vue avec l'Épique ; repères visuels.

- **Green Valley** : collines, arbres, pont, rivière ; verger (Fruit
  sauvage) et affleurement de cristal en zone avancée ; hub des portails
  avec la condition de chaque monde.
- **Golden Desert** : dunes, oasis (vente), arche rocheuse, ruines ; crête
  du Cristal solaire.
- **Frozen Peaks** : plateau enneigé, lac gelé, grotte de cristaux bleus,
  sommet.
- **Mystic World** : îles flottantes et ponts, plantes lumineuses (Neon,
  sans lumière dynamique), sanctuaire du Cœur mystique.

Construction en primitives scriptées (`tools/studio/build_world_<id>.luau`),
aucun asset Polyfork avant validation du manifeste (D7).

## 4. Activités

Retenues : zones rares par monde, points de vue et secrets non
économiques. Reportés : journal de collection et schéma v3 (D6),
événements environnementaux (D9). Exclus : combat, PvP, crafting, échange,
loot box, monnaie supplémentaire, paiement.

## 5. Progression (simulateur, projections théoriques)

Joueur passant au monde suivant dès son déblocage ; rareté liée aux temps
de réapparition et concurrence entre joueurs ignorées (le jeu réel sera
plus lent).

| Option (valeur moyenne GD / FP / MW) | Régulier : GD → FP → MW → fin de l'arbre | Occasionnel : fin |
|---|---|---|
| A. Bible 1.0 (20,8 / 107 / 571) | 1,5 h → 3,1 h → 4,5 h → 5,2 h | 6,5 h |
| **B. Retenue (8 / 30 / 110)** | 1,5 h → 5,6 h → 10 h → 13,5 h | 21 h |
| C. (6 / 20 / 60) | 1,5 h → 5,7 h → 12,9 h → 19,2 h | 30 h |

Les chiffres reproductibles avec la configuration réelle sont dans
`T8_IMPLEMENTATION_REPORT.md` (simulateur étendu en T8.1).

## 6. Performance (budget, à mesurer en T8.7)

Par monde : environ 1 200 BaseParts de décor, environ 40 nœuds, aucune
lumière dynamique, au plus 2 émetteurs de particules (Épiques),
`CastShadow = false` sur les nœuds, décor ancré. Total ≈ 5 000 Parts :
tester `StreamingEnabled` (le client suit déjà les nœuds par
ChildAdded/ChildRemoved) et mesurer sur téléphone réel.

## 7. Plan

T8.0 documentation ; T8.1 architecture et sécurité ; T8.2 Green Valley ;
T8.3 à T8.5 mondes 2 à 4 ; T8.7 validation. Rapport intermédiaire et
validation du propriétaire après T8.1.
