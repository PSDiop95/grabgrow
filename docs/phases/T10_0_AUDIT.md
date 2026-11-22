# T10.0 — Audit et conception « World Enrichment »

Date : 2026-11-21 — Statut : **VALIDÉ** par le propriétaire le 2026-11-22
(décisions D-025 à D-030). T10.1 en attente d'autorisation. Aucun fichier de jeu, de schéma ou d'économie modifié ; aucun
asset téléchargé ni importé ; `GrabAndGrow.rbxl` non touché ; aucun commit.

Livrables liés :
`assets/T10_RESOURCE_ASSET_SELECTION.md`, `assets/T10_VFX_DESIGN.md`,
`gameplay/T10_GUARDIANS_DESIGN.md`, `gameplay/T10_SACRED_SITES_DESIGN.md`,
`performance/T10_PERFORMANCE_BUDGET.md`.

## 1. Prérequis

| Contrôle | Résultat |
|---|---|
| T9 validée | **Oui, avec réserves** (propriétaire, 2026-11-16, D-024) : onboarding, progression `Worlds`, dépense `World:*`, succès, `WorldEntered`, `BackpackFull` non observés dans Roblox ; Local Server analytics non testé ; T9-UI-01 non contrôlé sur téléphone. Validation ≠ autorisation de publier |
| Dépôt | Branche `main`, arbre propre, dernier commit `e1d4d94` (T9) |
| Schéma | v3 (`DataConfig.SchemaVersion = 3`) |
| Dernière décision | D-024 à l'audit ; D-025 à D-030 acceptées le 2026-11-22 |

Écarts documentation / code relevés :

- **E-01** : le prompt cite `docs/GRAB_AND_GROW_ECONOMY_v1.1.md` ; le
  fichier présent est `GRAB_AND_GROW_ECONOMY_v1.0.md`, dont le contenu est
  la **version 1.1** (2026-11-14, D-021). Pas de doublon à créer.
- **E-02** : `PROJECT_STATUS.md` a pour en-tête « T9 étape B construite »
  alors que son résumé indique T9 validée : en-tête non mis à jour.
- **E-03** : budget T8 estimé à ≈ 5 000 Parts (audit T8) ; mesuré
  ≈ 2 265 en T8.7. Pas de conflit, l'estimation était haute.
- **E-04** (résolu, D-025) : `ASSET_MANIFEST.md` est « à valider par le propriétaire » et
  le GDD 14.8 prévoit des ressources emblématiques **sur mesure** si
  nécessaire. T10 propose des bases Polyfork adaptées (recoloration,
  échelle) : à confirmer (D-025, D-026).
- **E-05** (résolu, D-028) : les gardiens introduisent du **combat PvE**, absent du GDD
  (seuls les événements coopératifs y figurent ; PvP exclu). CLAUDE.md 5.2
  reporte les événements coopératifs « avant validation du MVP » : le MVP
  est validé (T2 à T9), mais l'ouverture de ce périmètre exige une décision
  explicite (D-028).

## 2. Audit des 20 ressources (code au 2026-11-21)

Sources : `ResourceConfig.lua`, `ResourceVisualConfig.lua`,
`Systems/ResourceNodes.lua`, `tools/studio/build_*.luau`. Points : nombre de
points de spawn dans le monde (répartition 16/12/8/3/1 en GV, 16/12/7/4/1
ailleurs, par `spawnWeight`, plus forts restes). Parts/nœud = Part
principal + détails. Valeurs et raretés **non modifiées**.

| Ressource | Monde | Valeur | Rareté | Respawn | Modèle actuel | Points / emplacement | Config visuelle | Parts/nœud | Total parts |
|---|---|---|---|---|---|---|---|---|---|
| `green_leaf` | GV | 1 | Commune | 2 s | Ball 1,8 | 16 — zone de base (aléatoire, graine fixe) | SmoothPlastic vert | 1 | 16 |
| `wood` | GV | 2 | Commune | 3 s | Cylinder 2,6 × 1,4 | 12 — zone de base | SmoothPlastic brun | 1 | 12 |
| `stone` | GV | 3 | Commune | 4 s | Block 2 × 1,6 × 2 | 8 — zone de base | SmoothPlastic gris | 1 | 8 |
| `wild_fruit` | GV | 5 | Peu commune | 8 s | Ball 1,6 | 3 — zone avancée (positions fixes) | SmoothPlastic rouge | 1 | 3 |
| `green_crystal` | GV | 12 | Rare | 20 s | Block 1,2 × 2,6 | 1 — zone avancée | **Neon** vert | 1 | 1 |
| `sandstone` | GD | 5 | Commune | 3 s | Block 2,2 × 1,4 | 16 — anneau de l'oasis (aléatoire) | SmoothPlastic sable | 1 | 16 |
| `copper_ore` | GD | 6 | Commune | 4 s | Block 1,8 × 1,6 | 12 — entre les dunes | SmoothPlastic cuivre | 1 | 12 |
| `fossil` | GD | 9 | Peu commune | 8 s | Cylinder 2,4 × 1,2 | 7 — ruines (positions fixes) | SmoothPlastic os | 1 | 7 |
| `gold_nugget` | GD | 17 | Rare | 20 s | Ball 1,6 | 4 — plateau de la crête (fixes) | **Neon** or | 1 | 4 |
| `sun_crystal` | GD | 38 | Épique | 60 s | Block 1,4 × 3 | 1 — recoin secret, piédestal | **Neon** orange + émetteur | 1 | 1 |
| `ice_shard` | FP | 18 | Commune | 3 s | Wedge + 1 détail | 16 — bord du plateau, près du camp | SmoothPlastic cyan | 2 | 32 |
| `silver_ore` | FP | 24 | Commune | 4 s | Block + 3 détails Metal | 12 — lac gelé (8 sur la glace) et rive | SmoothPlastic + Metal | 4 | 48 |
| `frozen_stone` | FP | 34 | Peu commune | 8 s | Block + 3 détails | 7 — bords des chemins du sommet (5) et de la grotte (2) | SmoothPlastic gris-bleu | 4 | 28 |
| `blue_crystal` | FP | 62 | Rare | 20 s | Block + 2 détails | 4 — grotte de cristaux (fixes) | **Neon** bleu | 3 | 12 |
| `ice_diamond` | FP | 140 | Épique | 60 s | Block + 1 détail | 1 — sommet, piédestal | **Neon** cyan + émetteur | 2 | 2 |
| `mystic_dust` | MW | 68 | Commune | 3 s | Ball + 3 détails | 16 — île d'arrivée, < 38 studs de la vente | SmoothPlastic violet | 4 | 64 |
| `star_fragment` | MW | 87 | Commune | 4 s | Wedge + 2 détails | 12 — ouest de l'île d'arrivée et est de la forêt | SmoothPlastic cyan | 3 | 36 |
| `spectral_ore` | MW | 125 | Peu commune | 8 s | Block Slate + 4 détails | 7 — îles flottantes (3/2/2) | Slate + SmoothPlastic | 5 | 35 |
| `purple_crystal` | MW | 230 | Rare | 20 s | Block + 2 détails | 4 — grotte spectrale (fixes) | **Neon** violet | 3 | 12 |
| `mystic_core` | MW | 480 | Épique | 60 s | Block + 4 détails | 1 — sanctuaire, piédestal | **Neon** magenta + émetteur | 5 | 5 |

Totaux : **160 nœuds, 354 Parts**, ≈ 37 Parts Neon, 3 émetteurs
permanents, 0 lumière, 0 mesh, 0 texture.

### Réutilisation de modèles (silhouettes)

- Même géométrie, couleur différente : `blue_crystal` et `purple_crystal`
  (prisme + 2 pointes) ; `ice_diamond` et `mystic_core` (cube double
  tourné) ; `silver_ore` et `spectral_ore` (bloc + inclusions cubiques).
- Sphères simples : `green_leaf`, `wild_fruit`, `gold_nugget`.
- Prismes Neon verticaux : `green_crystal`, `sun_crystal`.
- Conforme à la règle « distinct au sein d'un monde », mais les mondes se
  ressemblent entre eux : principal argument visuel de T10.

### Coût graphique

Faible : primitives instanciées, aucun mesh ni texture. Postes visibles :
Neon (rendu sans éclairage, coût faible), 3 émetteurs, pièces de détail
(194 Parts en FP et MW). Aucune mesure sur appareil (réserve T5/T8).

### Défauts et contraintes pour T10

- **V-01** : rebond de réapparition et éclat de collecte limités au Part
  principal (les détails ne suivent pas) — `CollectionController`,
  `FeedbackController`.
- **V-02** : aucune animation d'attente.
- **C-01** : le Part du nœud est la seule cible du client (`CanQuery`) et
  la seule porteuse des attributs ; la position de collecte (serveur) est
  celle de ce Part. Tout nouveau visuel doit conserver ce Part (hitbox).
- **C-02** : `StreamingEnabled` désactivé : les 4 mondes et leurs 160
  nœuds sont chargés en permanence ; le budget de triangles est global.

## 3. Recherche Polyfork (résumé)

MCP Polyfork **non configuré** ; API publique utilisée en lecture
(anonyme). 20 ressources couvertes par 20 meshes distincts (principal) et
une alternative documentée ; aperçus vérifiés visuellement ; ≈ 95 000
triangles au total. Licence retenue : **CC BY 4.0** (D-026).
Détail : `assets/T10_RESOURCE_ASSET_SELECTION.md`.

## 4. VFX, gardiens, sites sacrés, performance

- VFX : séparation hitbox serveur / visuel client piloté par
  `ResourceVisualConfig` + `RarityVisualConfig`
  (`assets/T10_VFX_DESIGN.md`).
- Gardiens : 4 fiches, combat « Grab » individuel (D-028), sans PvP,
  sans mort ni perte (`gameplay/T10_GUARDIANS_DESIGN.md`).
- Sites sacrés : zones T8 réutilisées, accès par le Journal puis
  permanent après victoire, schéma v3 conservé (D-029) (`gameplay/T10_SACRED_SITES_DESIGN.md`).
- Performance : budgets et protocole Galaxy A23
  (`performance/T10_PERFORMANCE_BUDGET.md`).

## 5. Décisions (validées le 2026-11-22)

Les propositions de T10.0 ont été arbitrées par le propriétaire le
2026-11-22 et inscrites dans `decisions/TECHNICAL_DECISIONS.md` (D-025 à
D-030, ACCEPTÉES). Le texte de référence est celui du registre ; les
écarts avec la proposition initiale sont listés ci-dessous.

### Matrice finale

| Id | Domaine | Décision finale | Changement par rapport à T10.0 | Ce qui reste à autoriser |
|---|---|---|---|---|
| D-025 | Artistique | 20 ressources refaites avec les modèles Polyfork sélectionnés, personnalisés ; identité GRAB & GROW ; primitives en repli | E-04 tranché : bases Polyfork personnalisées acceptées | 20 imports après validation de T10.1 |
| D-026 | Polyfork | **CC BY 4.0**, crédit par asset, licence vérifiée fichier par fichier, manifeste avant chaque import, tests GLB et FBX d'abord | Option « licence Polyfork » écartée | Écran Crédits et crédits de description avant publication publique |
| D-027 | VFX | Hitbox serveur inchangée, visuel client, `RarityVisualConfig`, plafonds ; **V-01 corrigé dans T10.1** ; streaming inchangé | V-01 avancé de T10.2 à T10.1 ; streaming explicitement gelé | Tout changement de `StreamingEnabled` (mesures + validation) |
| D-028 | Gameplay PvE | 4 gardiens, 4 sites ; combats **strictement individuels** (dégâts, victoires, déblocages, récompenses) ; pas de PvP ; accès permanent après victoire | PV partagés, adaptation au nombre de joueurs et réapparition par serveur retirés | Démarrage de T10.4 |
| D-029 | Sauvegarde | **Schéma v3 conservé** ; v4 = proposition et autorisation distinctes | Schéma v4 (`guardians`, `sacredItems`) retiré | Support v3 de la victoire (`achievements` recommandé) au moment de T10.4 |
| D-030 | Économie | Ressources sacrées à **double usage** (vente ou améliorations) ; **aucune valeur fixée** avant simulation | « Non vendables, hors sac » remplacé ; montants 500 / 1 500 / 6 000 / 20 000 et délai 20 min retirés | Valeurs, coût en ressources dans les améliorations, ajout à `ResourceConfig` |

### Contradictions corrigées

| Id | Contradiction | Correction |
|---|---|---|
| K-01 | T10.0 : combat coopératif à PV partagés ; décision 3 : combats individuels | Guardians et Sites réécrits : état serveur par joueur, rendu local, aucun partage |
| K-02 | T10.0 : ressources sacrées non vendables et hors sac ; décision 4 : vente ou améliorations | Sites §6 : double usage, conséquences (sac, Journal, `UpgradeService`) signalées |
| K-03 | T10.0 : schéma v4 ; décision 5 : v3 conservé | v4 retiré ; persistance via clés v3 existantes (D-008), limites listées (aucun horodatage ni compteur) |
| K-04 | Accès permanent (décision 4) suppose de persister la victoire ; v3 conservé (décision 5) | Résolu sans migration : clé `achievements` (booléen) ; à autoriser avec T10.4 |
| K-05 | Montants de récompenses dans T10.0 ; décision 6 : rien avant simulation | Montants requalifiés en entrées de simulation |
| K-06 | Délai personnel de 20 min (horodatage) incompatible avec le v3 | Retiré ; mémoire de session ou proposition v4 si la simulation l'exige |
| K-07 | V-01 prévu en T10.2 ; décision : T10.1 | Découpage et VFX mis à jour |
| K-08 | Ressource sacrée vendable ⇒ ajoutée au Journal : la complétion d'un monde passe de 5 à 6 ressources | Condition d'accès maintenue sur les 5 ressources ordinaires ; impact Journal à décider avec D-030 |

Écarts E-04 et E-05 (§1) : **résolus** par D-025 et D-028.

## 6. Découpage de T10 (révisé le 2026-11-22)

| Lot | Contenu | État |
|---|---|---|
| T10.1 | Mesure de référence Galaxy A23 ; tests d'import GLB et FBX (couleurs, matériaux, pivots, dimensions, collisions) ; manifeste avant chaque import ; prototype visuel client sur 4 ressources (1 par monde) ; **correction et tests de V-01** | En attente d'autorisation |
| T10.2 | 16 autres ressources, `RarityVisualConfig` complet | Non commencé, interdit avant validation de T10.1 |
| T10.3 | Simulation économique des ressources sacrées et des récompenses (D-030) ; proposition v4 **seulement si** le v3 ne suffit pas | Non commencé |
| T10.4 | Forest Guardian + Bosquet ancien (combat individuel complet, 1 puis 2 joueurs simultanés) | Non commencé |
| T10.5–T10.7 | Sand, Ice, Mystic Guardians, un lot par gardien | Non commencé |
| T10.8 | Stabilisation et rapport | Non commencé |

## 7. Risques principaux

| Id | Risque | Mesure |
|---|---|---|
| R1 | Couleurs par sommet perdues à l'import Roblox (Polyfork : matériaux nommés à l'export FBX/OBJ) | Test d'import en ouverture de T10.1 ; repli : recoloration par MeshPart |
| R2 | Coût mémoire des meshes avec `StreamingEnabled` désactivé | Budget ≤ 120 000 triangles, mesure A23 |
| R3 | Animations d'attaque inexistantes (clips fournis : Idle/Walk/Run) | Création dans l'Animation Editor ; prototype Forest seul |
| R4 | Inflation par les gardiens et les ressources sacrées | Aucune valeur avant simulation (D-030) ; délai non persistable en v3 |
| R5 | Silhouettes « gisement » répétées (8 meshes Loot & Lode) | Couleurs de monde, contrôle visuel mobile |
| R6 | Gardiens jugés effrayants (public jeune) | Revue visuelle ; alternatives documentées |
