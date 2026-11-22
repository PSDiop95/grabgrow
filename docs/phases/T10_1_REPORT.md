# T10.1 — Rapport (prototype ressources, imports, V-01)

Date : 2026-11-22 — Statut : **PROTOTYPE VALIDÉ** par le propriétaire le
2026-11-22 sur la base du test iPhone 12 Pro (D-031) ; réserve : mesure
Galaxy A23 non faite. Périmètre autorisé le 2026-11-22 : mesure de
référence A23, tests d'import GLB/FBX, manifeste avant import, prototype
sur 4 ressources (une par monde), correction et test de V-01. Schéma v3,
économie et `StreamingEnabled` inchangés ; `GrabAndGrow.rbxl` écrasé par
une sauvegarde Studio puis restauré à l'identique de la version 105
(§2 ter) ; aucun commit.

## 1. Réalisé

| Élément | État |
|---|---|
| V-01 (rebond et éclat ignoraient les détails) | **Corrigé et testé** (primitives et modèles) |
| Visuel client des nœuds (`Controllers/NodeVisuals`) | Fait et vérifié : modèle cloné ou primitive + détails, `BulkMoveTo`, attente ≤ 24 nœuds / 60 studs / 30 Hz, coupée en Effets réduits |
| Chargeur serveur (`Systems/ResourceModelLoader`) | Fait : source `template` (place) ou `assetId` (`InsertService`, 3 essais), normalisation, échelle `targetSize`, pivot bas-centre, repli primitif |
| Configuration | `RarityVisualConfig` ; champ `model` de `ResourceVisualConfig` renseigné pour les 4 ressources du prototype |
| Imports | Faits **à la main par le propriétaire** dans Studio (l'upload Open Cloud refuse toujours le dossier) : 4 GLB + 2 FBX |
| Prototype 4 ressources | En place : `ServerStorage.ResourceTemplates` (copies ; imports d'origine laissés dans Workspace) |
| Manifeste | Rempli avant import ; lignes mises à jour après import |
| Mesure Galaxy A23 | **NOT TESTED** ; fiche `performance/T10_1_BASELINE_A23.md` |

## 2. Résultats d'import

| Fichier | MeshParts | Échelle | Couleurs | Pivot | Collisions / ancrage |
|---|---|---|---|---|---|
| GLB (4 modèles) | 1–2 (une par nœud ou primitive glTF) | correcte (≈ 1–10 studs) | couleurs de sommets conservées **mais trop sombres** | bas-centre | CanCollide vrai, non ancré |
| FBX (feuille, cuivre) | 4 (une par matériau) | **×100** (cm) | **perdues** (gris par défaut) | bas-centre | idem |

- Cause des GLB sombres (vérifiée sur les fichiers) : glTF stocke les
  couleurs de sommets en **linéaire**, Roblox les affiche comme du sRGB.
  Exemple : rocher du cuivre 0,29 linéaire → attendu ≈ 146/255, affiché
  ≈ 74/255. Mettre `Color` en blanc éclaircit peu (la couleur de la pièce
  multiplie les sommets, ne peut pas éclaircir). La feuille GLB est rousse
  (automne) et ne peut pas être recolorée en vert.
- Les collisions et l'ancrage sont corrigés par le chargeur (ancré, sans
  collision, requête, contact ni ombre) : vérifié sur les 4 gabarits.

Choix du prototype : feuille et cuivre en **FBX** recolorés par pièce ;
argent et améthyste en **GLB** (pièces blanches, cristaux Neon violets,
rareté Rare).

## 2 bis. Correction des GLB (décision du propriétaire, 2026-11-22)

- `tools/fix_glb_colors.luau` (Lune) écrit `assets_src/polyfork/fixed/` :
  couleurs de sommets linéaire → sRGB, feuille recolorée en vert ; seuls
  les octets de couleur changent (taille, géométrie, JSON identiques).
  Vérifié par relecture : rocher du cuivre 0,57 (≈ 146/255) au lieu de
  0,29 ; verts de la feuille exacts.
- Upload Open Cloud refusé aussi pour `fixed/` ; réimport manuel.
- Gabarits remplacés par les GLB corrigés : feuille 1 pièce, cuivre,
  argent, améthyste 2 pièces. Visuels client : **72 MeshParts** (contre
  144 avec les FBX) ; budget ≤ 3 pièces par nœud respecté.
- Rendu : cuivre bon ; argent gris clair à pépites argentées (contraste
  faible mais lisible) ; améthyste : roche grise lisible, cristaux violets
  **petits** ; feuille : d'abord verte sur herbe verte (peu visible),
  puis palette contrastée (limbe 214,232,76, bord 40,98,30 ; herbe
  116,178,92), régénérée et réimportée : **nettement visible**, y compris
  à distance (capture Studio). Hypothèse visuelle à confirmer sur A23.
- Collecte d'une feuille GLB : `SUCCESS`, éclat à 1 pièce ; aucune erreur
  de script.

- Améthyste : surcharge `scale` par pièce ajoutée (config, chargeur,
  `ConfigTests` : ]0, 2]) ; cristaux ×1,6 autour de leur centre avant
  l'ajustement global. Gabarit 2,40 × 2,03 × 1,54 studs (cristaux
  2,15 × 2,03 × 1,19, roche 2,40 × 1,67 × 1,44) : les cristaux violets
  dominent désormais (capture Studio). Aucun réimport nécessaire.

## 2 ter. Sauvegarde du place et incident `GrabAndGrow.rbxl` (2026-11-22)

- Imports écartés du monde : 11 objets déplacés de `Workspace` vers
  `ServerStorage._T10_1_Imports` (accord du propriétaire) ; 0 MeshPart
  restante dans Workspace.
- Sauvegarde dédiée : `places/T10_1_prototype.rbxl` (433 Ko, 12:56 UTC ;
  `places/` ignoré par Git). Relue avec Lune : 4 gabarits avec les meshes
  finaux, 11 imports écartés, 0 MeshPart dans Workspace,
  `StreamingEnabled` désactivé. Réouverture dans Studio même : non faite
  (la session reste sur le place cloud).
- **Incident** : `GrabAndGrow.rbxl` écrasé à 12:53 UTC par une sauvegarde
  Studio (contenu = place de test avec les imports), hors de toute action
  de l'assistant. Restauré à 12:59 depuis la **version cloud 105** (version
  ouverte au début de T10.1), avec l'accord du propriétaire ; vérifié :
  86 scripts identiques au commit T9 `e1d4d94`, aucun élément T10.1,
  2 265 BaseParts. Copie de l'état écrasé conservée :
  `places/GrabAndGrow_ecrase_2026-11-22.rbxl`. La version cloud 106 date
  de T10.1.

## 3. Tests

| Test | Type | Résultat |
|---|---|---|
| Lune `tools/run_tests.luau` (22 suites, 440 cas + ConfigTests) | Automatisé | OK |
| `luau-lsp analyze` (fichiers touchés) | Automatisé | OK, 0 diagnostic |
| `rojo build` (fichier temporaire) | Automatisé | OK |
| Studio Play : tests serveur, aucune erreur de script | Automatisé | OK |
| 4 gabarits chargés, normalisés, tailles 1,80–2,40 studs | Manuel (MCP) | OK |
| 44 visuels client (16 feuilles, 12 cuivre, 12 argent, 4 cristaux), hitbox serveur masquée localement | Manuel (MCP) | OK |
| Collecte réelle d'une feuille modélisée | Manuel (MCP) | OK : `SUCCESS`, éclat à 4 MeshParts, modèle masqué |
| Rebond de réapparition d'un modèle (cuivre, 4 pièces) | Manuel (MCP) | OK : même rapport sur les 4 pièces (0,895 → 1,066 → 1,000), invisible avant le rebond |
| V-01 sur primitives (rebond `silver_ore_007`, éclat `ice_shard_015`) | Manuel (MCP) | OK (session précédente) |
| Animation d'attente : 12/12 modèles à < 60 studs bougent ; Effets réduits : 0/12 | Manuel (MCP) | OK |
| Rendu visuel (captures) | Manuel | Feuille et cuivre : bons ; argent et améthyste : trop sombres |
| Mobile iPhone 12 Pro (propriétaire) : feuille modélisée visible et collectée, variante APRÈS publiée | Manuel | OK (qualitatif, sans relevé chiffré) |
| Galaxy A23, avant/après, 1 et 4 joueurs | Appareil | NOT TESTED |

## 4. Performance

- Studio (non représentatif) : +144 MeshParts côté client (16×4 + 12×4 +
  12×2 + 4×2), meshes partagés par ressource ; hitboxes serveur inchangées.
- Budget « ≤ 3 MeshParts par nœud » **dépassé** par les FBX (4) ; respecté
  par les GLB (2).
- A23 : NOT TESTED (avant et après).

## 5. Problèmes rencontrés

1. Upload Open Cloud refusé malgré l'approbation déclarée du dossier
   (3 essais, Studio redémarré) : import manuel à la place. Conséquence :
   pas d'`assetId` de modèle ; les gabarits vivent dans le place de test
   (`ServerStorage.ResourceTemplates`, non géré par Rojo).
2. Couleurs GLB trop sombres (gamma) ; FBX sans couleur et à ×100.
3. Les imports d'origine restent dans `Workspace` (dont les FBX à ×100,
   ≈ 1 000 studs) : ils apparaissent en jeu ; à retirer avec accord.
4. Le place de test n'est pas sauvegardé : `ResourceTemplates` est perdu
   si Studio ferme sans sauvegarde.
5. Avertissements préexistants `rbxassetid://203785492` et `81504106`
   (avatar / place), sans lien avec les imports.

## 6. Recommandations

1. **Format retenu : GLB corrigé** (`tools/fix_glb_colors.luau`), en place
   pour les 4 ressources : 1–2 pièces, budget respecté.
2. Feuille : palette contrastée appliquée ; confirmer sur A23.
3. Améthyste : cristaux agrandis (×1,6) ; confirmer sur A23.
4. Faire la mesure A23 avant l'extension aux 16 autres ressources.
5. Ne pas étendre le prototype avant validation (règle T10.1).
