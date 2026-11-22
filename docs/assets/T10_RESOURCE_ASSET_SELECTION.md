# T10 — Sélection des assets Polyfork pour les 20 ressources

Date : 2026-11-21, révisé le 2026-11-22 — Statut : **VALIDÉ (T10.0,
D-025, D-026)**. Aucun fichier téléchargé, aucun asset importé. Chaque
import reste soumis aux contrôles de T10.1 et à une ligne du manifeste
(`ASSET_MANIFEST.md`) remplie avant l'import.

## 1. Méthode et accès

- **MCP Polyfork : non configuré** dans cet environnement Claude Code (aucun
  outil `polyfork` disponible). Recherche faite par l'**API publique**
  `https://polyfork.dev/api` (anonyme, sans clé, en lecture seule),
  documentée dans `https://polyfork.dev/llms.txt`.
- Requêtes : `GET /api/assets?q=…` (≈ 60 termes), `GET /api/kits/{id}`,
  `GET /api/assets/{id}` pour chaque candidat (triangles, matériaux,
  dimensions, formats, licence, description).
- **Aperçus contrôlés visuellement** (vignettes officielles, planche de 57
  candidats) : plusieurs choix « par le nom » ont été écartés ou réaffectés
  (ex. la feuille est rousse ; « Glowing Crystal Cluster » a des cristaux
  orange, donc Cristal solaire et non Cristal vert ; « Ice Chunk » et
  « Rough Diamond » ont la même silhouette, donc une seule des deux en
  Frozen Peaks).
- Les vignettes et rendus sont sous licence Polyfork uniquement : **liens
  seulement**, aucune image copiée dans le dépôt.
- Données relevées le 2026-11-21 ; à revérifier au téléchargement (T10.1).

## 2. Licence (relevée sur `/licensing` et dans chaque fiche)

Chaque fiche retournée porte : *« Mesh files (GLB, FBX, USD, OBJ): CC BY
4.0 with the line in `credit`, or the Polyfork licence with no credit and
no redistribution, your choice. »* Tous les candidats ci-dessous sont
`free: true`, `plan: free`.

| Option | Ce qu'elle permet | Point Roblox |
|---|---|---|
| CC BY 4.0 | Usage commercial, modification, redistribution, avec la ligne de crédit (`credit`) et mention des modifications | Couvre le fait qu'un mesh téléversé sur Roblox soit techniquement extractible. Exige un crédit (description de l'expérience ou écran Crédits) |
| Licence Polyfork | Usage commercial, modification, sans crédit ; « your game can ship the models inside it » ; pas de redistribution des fichiers | Ne jamais publier ces meshes sur le Creator Store ni rendre le place copiable |

**Décision D-026 (2026-11-22) : CC BY 4.0** pour tous les meshes
Polyfork : ligne de crédit de chaque fiche + mention des modifications ;
licence revérifiée fichier par fichier au téléchargement ; crédits publiés
avant toute publication publique. Les modules `.mjs` et éditions HD ne sont pas
concernés (non utilisés).

## 3. Caractéristiques communes des candidats

- Format : **GLB** (`/cdn/{id}.glb`, sans compte) ; exports **FBX, OBJ(+MTL),
  USDZ, USDA** disponibles pour tous les candidats.
- Style : low-poly, *flat shading*, **couleurs par sommet** (pas de
  texture). Polyfork précise que les couleurs par sommet deviennent des
  **matériaux nommés** à l'export FBX/OBJ. Rendu des couleurs après import
  Roblox **non vérifié** : premier test de T10.1 (risque R1).
- Origine au sol (`origin_y = 0`), Y vers le haut, mètres.
- Échelle : 1 stud ≈ 0,28 m. Cible des ressources (GDD 13, config actuelle)
  : 1,2 à 3 studs. Les facteurs ci-dessous sont indicatifs.
- 2 matériaux = matériau partagé opaque + une surface distincte (verre,
  eau, chrome) : à remplacer par un matériau Roblox opaque (règle T8.4 :
  pas de transparence) ; Neon réservé à Rare et Épique (inchangé).

## 4. Fiches par ressource

Valeur, rareté et monde : `ResourceConfig` (inchangés). Page :
`https://polyfork.dev/asset/<id>` ; aperçu :
`https://polyfork.dev/files/<id>/renders/hero.png` ; GLB :
`https://polyfork.dev/cdn/<id>.glb`. Crédit CC BY : « <Titre> by Polyfork
(https://polyfork.dev/asset/<id>), CC BY 4.0 ».

Colonnes : Tri = triangles ; Mat = matériaux ; Dim = dimensions source (m).

### Green Valley

| Ressource | Choix | Nom Polyfork / identifiant | Kit | Tri | Mat | Dim (m) | Aperçu vérifié | Adaptation |
|---|---|---|---|---|---|---|---|---|
| `green_leaf` (Commune, 1) | Principal | Fallen Oak Leaf — `fallen-oak-leaf-5b15fe` | insect-world | 648 | 1 | 10 × 0,89 × 6 | Feuille lobée, rousse | Recolorer vert (palette GV) ; échelle ≈ 0,08 ; incliner ≈ 25° pour la lisibilité ; flottement |
| | Alternative | Round Bush — `round-bush-cd2ac0` | nature-forest | 573 | 1 | 1,27 × 0,63 × 0,87 | Buisson rond vert | Risque de confusion avec le décor végétal de GV |
| `wood` (Commune, 2) | Principal | Fallen Log — `fallen-log-1685fb` | nature-forest | 484 | 1 | 3,09 × 0,9 × 0,7 | Bûche simple | Échelle ≈ 0,3 (≈ 3 studs) |
| | Alternative | Firewood Stack — `firewood-stack-8a2899` | nature-forest | 752 | 1 | 1,18 × 0,76 × 0,66 | Pile de bûches | Échelle ≈ 0,7 |
| `stone` (Commune, 3) | Principal | Medium Rock — `medium-rock-e08405` | nature-forest | 374 | 1 | 1 × 0,5 × 0,95 | Rocher gris facetté | Échelle ≈ 0,6 |
| | Alternative | Field rock — `field-rock-5e37c6` | salvage-commons | 144 | 1 | 1,05 × 0,77 × 1,03 | Rocher, dessus moussu | Retirer la mousse (couleur) |
| `wild_fruit` (Peu commune, 5) | Principal | Apple — `apple-b15012` | (Nano) | 276 | 1 | 0,1 × 0,11 × 0,09 | Pomme rouge et feuille | Échelle ≈ 5,5 (≈ 2 studs) ; couleur actuelle conservée |
| | Alternative | Berry Bush — `berry-bush-ee4812` | cozy-farm | 720 | 1 | 0,73 × 0,97 × 0,65 | Arbuste à baies rouges | Proche du décor |
| `green_crystal` (Rare, 12) | Principal | Emerald Ore Deposit — `emerald-ore-deposit-4f0566` | loot-lode | 702 | 2 | 1,64 × 1,12 × 1,17 | Rochers et cristaux verts | Échelle ≈ 0,45 ; cristaux en Neon |
| | Alternative | Glowing Crystal Cluster — `lair-crystal-column-877d1a` | dragons-lair | 512 | 3 | 1,51 × 1,64 × 1,13 | Cristaux orange sur socle | Recoloration verte (déjà retenu pour `sun_crystal`) |

### Golden Desert

| Ressource | Choix | Nom Polyfork / identifiant | Kit | Tri | Mat | Dim (m) | Aperçu vérifié | Adaptation |
|---|---|---|---|---|---|---|---|---|
| `sandstone` (Commune, 5) | Principal | Sandstone Outcrop — `sandstone-outcrop-75800b` | roadside-americana | 786 | 1 | 4,1 × 2,5 × 2,15 | Strates rouille et sable | Échelle ≈ 0,17 ; tirer vers l'ocre clair |
| | Alternative | Garden Rock — `garden-rock-7f5d60` | cozy-farm | 140 | 1 | 0,72 × 0,42 × 0,64 | Rocher simple | Recolorer sable ; silhouette générique |
| `copper_ore` (Commune, 6) | Principal | Copper Ore Deposit — `copper-ore-deposit-d5e58b` | loot-lode | 685 | 2 | 1,65 × 0,9 × 0,97 | Rochers à veines cuivre | Échelle ≈ 0,45 |
| `fossil` (Peu commune, 9) | Principal | Fossil Ribcage — `fossil-ribcage-b243c5` | prehistoric-valley | 800 | 1 | 2 × 1,4 × 3,5 | Cage thoracique semi-enterrée | Échelle ≈ 0,2 ; vérifier la cible de toucher (formes ajourées) |
| | Alternative | Dinosaur Bone Pile — `dinosaur-bone-pile-3c285a` | prehistoric-valley | 552 | 1 | 2 × 0,51 × 1,5 | Tas d'os plat | Faible hauteur : lisibilité médiocre |
| `gold_nugget` (Rare, 17) | Principal | Gold Nugget — `gold-nugget-ccd143` | loot-lode | 587 | 1 | 0,1 × 0,08 × 0,07 | Pépite jaune bosselée | Échelle ≈ 6 ; Neon conservé |
| | Alternative | Gold Ore Deposit — `gold-ore-deposit-9965a4` | loot-lode | 775 | 2 | 1,63 × 0,98 × 1,15 | Rochers et pépites | Plus lourd, même famille que `copper_ore` |
| `sun_crystal` (Épique, 38) | Principal | Glowing Crystal Cluster — `lair-crystal-column-877d1a` | dragons-lair | 512 | 3 | 1,51 × 1,64 × 1,13 | Cristaux orange, socle taupe | Échelle ≈ 0,5 ; cristaux Neon orange, opaques ; particules (existantes) |
| | Alternative | Amber Lump — `amber-lump-f3a85d` | prehistoric-valley | 634 | 3 | 0,31 × 0,32 × 0,3 | Ambre avec insecte | Insecte peu lisible ; 3 matériaux |

### Frozen Peaks

| Ressource | Choix | Nom Polyfork / identifiant | Kit | Tri | Mat | Dim (m) | Aperçu vérifié | Adaptation |
|---|---|---|---|---|---|---|---|---|
| `ice_shard` (Commune, 18) | Principal | Crystal Shard — `crystal-shard-9e0a83` | dragons-lair | 208 | 1 | 0,39 × 0,13 × 0,14 | Prisme hexagonal cyan couché | Recolorer glace pâle ; échelle ≈ 5 ; redresser à 40° |
| | Alternative | Ice Chunk — `ice-chunk-b23ad7` | space-base | 253 | 1 | 0,83 × 0,88 × 0,86 | Bloc polyédrique cyan | Silhouette trop proche du diamant : à ne pas combiner avec `rough-diamond` |
| `silver_ore` (Commune, 24) | Principal | Silver Ore Deposit — `silver-ore-deposit-57f7c3` | loot-lode | 729 | 2 | 1,54 × 0,87 × 0,88 | Rochers sombres veinés de blanc | Échelle ≈ 0,45 |
| `frozen_stone` (Peu commune, 34) | Principal | Boulder Field Cluster — `boulder-field-cluster-08e364` | alpine-and-snow | 734 (défaut) | 1 | 2,5 × 1,45 × 2 | Blocs de granit enneigés | Réglage `count` à 1 ou 2 (variante à générer, budget *remix*) ; échelle ≈ 0,4 |
| | Alternative | Iron Ore Deposit — `iron-ore-deposit-577b67` | loot-lode | 802 | 2 | 1,64 × 0,99 × 1,14 | Rochers ardoise | Recolorer givré |
| `blue_crystal` (Rare, 62) | Principal | Sapphire Ore Deposit — `sapphire-ore-deposit-f8a71a` | loot-lode | 473 | 2 | 1,46 × 0,92 × 1,15 | Rochers et pointes bleues | Échelle ≈ 0,45 ; Neon. Même famille que `silver_ore` : contrôler la distinction (pointes vs veines) |
| `ice_diamond` (Épique, 140) | Principal | Rough Diamond — `rough-diamond-fecf28` | loot-lode | 362 | 1 | 0,09 × 0,08 × 0,07 | Octaèdre cyan pâle | Échelle ≈ 7 ; Neon ; particules (existantes) |
| | Alternative | Diamond Ore Deposit — `diamond-ore-deposit-4dafd4` | loot-lode | 506 | 2 | 1,64 × 1,06 × 1,04 | Rochers et diamants | Silhouette « gisement » déjà utilisée deux fois dans le monde |

### Mystic World

| Ressource | Choix | Nom Polyfork / identifiant | Kit | Tri | Mat | Dim (m) | Aperçu vérifié | Adaptation |
|---|---|---|---|---|---|---|---|---|
| `mystic_dust` (Commune, 68) | Principal | Gem Chip Heap — `gem-chip-heap-573355` | loot-lode | 662 | 1 | 0,39 × 0,13 × 0,4 | Monticule d'éclats multicolores | Recolorer violet/lavande ; échelle ≈ 1,8 ; peu haut : vérifier la lisibilité |
| | Alternative | Mushroom Cluster — `mushroom-cluster-18dc1d` | dungeon-crypt | 587 | 1 | 0,39 × 0,38 × 0,29 | Champignons pâles | Recolorer violet ; s'éloigne de « poudre » |
| `star_fragment` (Commune, 87) | Principal | Meteorite — `meteorite-c400d9` | space-base | 630 | 1 | 0,82 × 0,78 × 0,76 | Roche sombre à cratères | Recolorer bleu nuit et cyan ; échelle ≈ 0,7 |
| | Alternative | Crystal Shard — `crystal-shard-9e0a83` | dragons-lair | 208 | 1 | 0,39 × 0,13 × 0,14 | Prisme cyan | Même mesh que `ice_shard` (recoloré) : économique, moins distinctif |
| `spectral_ore` (Peu commune, 125) | Principal | Geode Boulder — `geode-boulder-e8091d` | dragons-lair | 589 | 2 | 1,61 × 1,6 × 0,87 | Coque sombre ouverte, cristaux cyan | Échelle ≈ 0,45 ; cristaux cyan et violets |
| | Alternative | Coal Seam Deposit — `coal-seam-deposit-1577c4` | loot-lode | 555 | 2 | 1,48 × 0,82 × 1,16 | Rochers brun-gris | Recolorer ; peu mystique |
| `purple_crystal` (Rare, 230) | Principal | Amethyst Ore Deposit — `amethyst-ore-deposit-02d55d` | loot-lode | 733 | 2 | 1,59 × 1,1 × 0,96 | Rochers et cristaux violets | Échelle ≈ 0,45 ; Neon |
| `mystic_core` (Épique, 480) | Principal | Divination Orb — `divination-orb-115d77` | primal-future-armory | 688 | 4 | 0,3 × 0,27 × 0,26 | Orbe violet sur berceau | Échelle ≈ 7 ; orbe Neon magenta ; 4 matériaux à réduire à 2 ; particules (existantes) |
| | Alternative | Geode Dragon Egg — `geode-dragon-egg-89141e` | dragons-lair | 657 | 1 | 0,63 × 0,7 × 0,61 | Œuf bleu à pointes cyan | **Déconseillé** : forme d'œuf confondue avec le futur système d'œufs (Pets) |

## 5. Synthèse

- 20 ressources couvertes, 20 meshes distincts en choix principal (aucun
  mesh partagé entre deux ressources).
- Famille cohérente : 8 choix dans le kit **Loot & Lode** (67 pièces,
  publié) : `copper_ore`, `gold_nugget`, `silver_ore`, `blue_crystal`,
  `ice_diamond`, `purple_crystal`, `green_crystal`, `mystic_dust`.
- Triangles par monde (nœuds 16/12/8/3/1 en GV, 16/12/7/4/1 ailleurs) :
  GV ≈ 20 700 ; GD ≈ 29 300 ; FP ≈ 19 500 ; MW ≈ 25 900 ; **total ≈ 95 000**
  (tous chargés : `StreamingEnabled` désactivé). Budget :
  `performance/T10_PERFORMANCE_BUDGET.md`.
- Tous les choix principaux sont dans la cible GDD 14.6 (100–800
  triangles) ; le plus lourd est le Fossile (800).

## 6. Points à vérifier en T10.1 (avant toute intégration)

1. Import d'**un** GLB et d'**un** FBX dans Studio : couleurs par sommet ou
   matériaux nommés, nombre de MeshParts créés, pivots, échelle (R1).
2. Variante `count = 1` de `boulder-field-cluster` (génération côté
   Polyfork, budget anonyme 40/heure).
3. Lisibilité des formes plates (`green_leaf`, `mystic_dust`, `fossil`) en
   vue mobile à 30 studs.
4. Distinction `silver_ore` / `blue_crystal` dans un même monde.
5. Remplir `ASSET_MANIFEST.md` ligne par ligne **avant** chaque import
   (statut « sélectionné » puis « téléchargé »), date et ligne de crédit.
