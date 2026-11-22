# T10.2 — Rapport VFX et animations des ressources

Date : 2026-11-22 — Statut : **VALIDÉE** par le propriétaire le
2026-11-22 (D-032, D-033), avec réserves : mobile, Galaxy A23 et deux
joueurs réels non testés. Code intégré et testé dans Studio (place de test
cloud 93404872714886) ; captures, deux joueurs réels, qualité graphique
basse réelle et mobile **non testés**. Économie, sauvegarde (schéma v3),
règles de collecte, `StreamingEnabled` et `GrabAndGrow.rbxl` inchangés ;
commit sur autorisation du propriétaire (2026-11-22).

## 0. Périmètre et écarts signalés

- **Redéfinition de T10.2** : le découpage T10.0 prévoyait « 16 autres
  ressources + `RarityVisualConfig` complet ». La demande du propriétaire
  (2026-11-22) en fait le lot VFX. Interprétation retenue : effets sur les
  **20 ressources telles qu'elles sont** (4 modèles du prototype, 16
  primitives) ; **aucun import** de nouveau modèle. L'import des 16 autres
  ressources reste à planifier (D-032).
- **Prérequis** : T10.1 validée comme prototype (D-031) ; réserve A23
  toujours ouverte.
- **Budget VFX révisé** : « émetteurs d'attente ≤ 1 par monde (Épique) »
  est incompatible avec « Peu commun : petites particules ». Remplacé par
  un pool global plafonné (§3).

## 1. Architecture (audit puis adaptation)

| Élément | Rôle | État |
|---|---|---|
| `Shared/Config/ResourceVFXConfig` | Présentation par rareté, budgets, durées (renomme et étend `RarityVisualConfig`, T10.1) | Nouveau |
| `Shared/Util/ResourceFxRules` | Règles pures : pose (pirouette Épique), `effectLevel`, `allocateEmitters`, `burstCount`, `disappearance` | Étendu |
| `Controllers/NodeVisuals` | Visuel local de **chaque** nœud (modèle ou copie de la primitive), attente, écrasement immédiat, disparition, reconstruction | Adapté |
| `Controllers/ResourceVFXController` | Pools : émetteurs d'attente, auras, éclats (collecte, réapparition) ; boucle unique de réattribution | Nouveau |
| `Controllers/FeedbackController` | Éclat de collecte (copie Neon) ; particules déléguées au pool | Adapté |
| `Controllers/CollectionController` | Après l'envoi de la demande : `NodeVisuals.notifyLocalRequest` | 2 lignes |
| `Systems/ResourceNodes` (serveur) | Plus d'émetteur « Sparkle » serveur (effet devenu client) | Simplifié |

Le serveur reste seul juge : le client envoie toujours l'identifiant du
nœud seulement ; aucun effet ne précède ni ne remplace `Available` ou
`ActionResult`.

## 2. Effets

| Rareté | Présence | Particules d'attente | Aura | Collecte (normal / réduit) | Réapparition |
|---|---|---|---|---|---|
| Common | Flottement 0,15 | — | — | 6 / 3 | Reconstruction seule |
| Uncommon | + rotation 10°/s | 1,5/s, petites | — | 8 / 3 | + 4 particules |
| Rare | + rotation 20°/s, **pulsation ±6 %** | 2/s | — | 10 / 4 | + 6 |
| Epic | + pulsation ±4 %, **pirouette** (saut 0,5 + tour, toutes les 6 s) | Anneau montant 4/s | **Disque Neon opaque au sol** | 14 / 5 | + 8 |

- **Collecte** : écrasement immédiat (0,9 → 1, 0,12 s) à l'envoi, sans
  masquer le nœud ; à la confirmation serveur, copie Neon qui rétrécit et
  glisse vers le joueur (existant) et cône de particules **orienté vers le
  joueur** (25°).
- **Disparition** : nœud demandé par le joueur local dans la dernière
  seconde → masquage immédiat (l'éclat prend le relais) ; sinon (autre
  joueur) → rétrécissement 0,15 s puis masquage. Pas de double effet.
- **Réapparition** : déclenchée uniquement par `Available = true`
  (serveur) : reconstruction 0,2 → 1 en 0,3 s (toutes les pièces, V-01)
  et bouffée vers le haut.

## 3. Performance (règles appliquées)

- Pools : 8 émetteurs d'attente, 3 auras, 6 éclats, créés une fois ;
  aucune instance par nœud ni par cycle (hors copie Neon de collecte, ≤ 6
  simultanées, existant).
- Une boucle d'animation (30 Hz, 24 nœuds, 60 studs, existante) et une
  boucle de réattribution (2 Hz) ; aucune boucle par ressource.
- Émetteurs : rareté puis distance, rayon 45 studs ; auras : 90 studs.
- Niveaux : `full` 8 émetteurs ; `low` (qualité Roblox 1–3) 3, Épique
  seulement ; `reduced` (« Effets réduits ») 0 émetteur, pas d'animation,
  aura statique, éclats réduits.
- Aucune lumière, ombre ni `Beam` ; pièces opaques (seules les particules
  sont transparentes).
- Pire cas théorique de particules : 8 × 5,6 + 6 × 14 ≈ 129 (≤ 150,
  vérifié par test).

## 4. Tests

### Automatisés (Lune) — exécutés

447 cas, **tous OK** (dont `ResourceFxTests` 18 cas, 7 nouveaux :
pirouette, niveau d'effets, attribution des émetteurs, éclats,
disparition, effets par rareté, budgets). LSP (`luau-lsp analyze`) : 0
erreur. Les mêmes tests passent dans Studio (`RunTests`).

### Studio (Play solo, client + serveur) — exécutés

| Test | Résultat |
|---|---|
| 160 nœuds / 20 ressources : un visuel local chacun | OK (160 visuels, 338 pièces) |
| Collecte réelle (E) d'un Épique | OK : 1 éclat, 1 copie Neon, aura et émetteur libérés aussitôt, visuel masqué |
| Collecte rapide répétée (E maintenu 6 s) | OK : 3 collectes, 3 éclats, 0 doublon, 0 copie restante, 0 visuel incohérent avec `Available` |
| Respawn réel | OK : visible, taille de repos ; bouffées comptées |
| Disparition « autre joueur » (simulée : `Available` changé côté serveur) | OK : visible et rétrécissant à +0,05 s, masqué à +0,3 s ; reconstruction synchronisée au retour |
| Collecte locale : pas de rétrécissement en double | OK : masqué à +0,03 s (modèle `green_leaf`) |
| « Effets réduits » | OK : niveau `reduced`, 0 émetteur, nœuds immobiles ; retour à `full` : 7 émetteurs, animation reprise |
| Changement de monde (4 mondes) | OK : émetteurs réattribués, aucun émetteur actif à > 60 studs |
| Erreurs console | Aucune liée à T10.2 |

### Non testés

- **Deux joueurs réels** sur la même zone (Studio MCP : Play solo seul) ;
  comportement couvert par la simulation serveur ci-dessus.
- **Déconnexion** pendant une collecte : rien de persistant côté client ;
  non testé spécifiquement.
- **Qualité graphique basse réelle** : `SavedQualityLevel` non modifiable
  par script ; règle testée en Lune seulement.
- **Mobile** (Galaxy A23, iPhone) : NOT TESTED.
- **Captures et vidéos** : le viewport Studio ne rendait pas (images
  noires) pendant la session ; aucune capture produite.
- **Draw calls** : non accessibles par script.

## 5. Mesures avant / après (Studio, même machine, même parcours)

« Avant » = code T10.1 (commit 2725816, Rojo) ; « après » = T10.2.

| Poste | Avant | Après | Écart |
|---|---|---|---|
| Parts Workspace | 2 709 | 2 992 | +283 (copies locales des 16 ressources primitives ; pièces serveur masquées, non dessinées) |
| MeshParts | 89 | 89 | 0 |
| Instances (`Stats.InstanceCount`) | 61 366 | 61 781 | +415 |
| ParticleEmitters | 3 (serveur, toujours actifs) | 14 (pool : 8 + 6 éclats) | Actifs : 3 → 0 à 4 selon la position |
| Mémoire particules (`GraphicsParticles`) | 12,1 Mo | 12,1 Mo | 0 |
| Mémoire `GraphicsParts` | 2,4 Mo | 2,6 Mo | +0,2 Mo |
| FPS | 60 / 15 | 60 / 60 | **Non interprétable** (viewport non rendu, fenêtre en arrière-plan) |
| Mémoire totale | 751–1 299 Mo | 791–839 Mo | Non interprétable (Studio) |

Conclusion provisoire : surcoût mémoire faible ; le seul surcoût de
rendu attendu est le dessin des copies primitives (qui remplacent les
pièces serveur masquées, pas en plus). À confirmer sur Galaxy A23.

## 6. Points à surveiller

- Copie des primitives : +283 parts client ; à revoir quand les 16
  ressources auront leur modèle (le visuel deviendra un clone de modèle).
- Qualité « Automatic » (défaut mobile) = niveau `full` : Roblox n'expose
  pas la qualité effective ; « Effets réduits » reste le levier joueur.
- Disque d'aura Épique : lisibilité et goût à valider visuellement.
- Valeurs (débits, durées, amplitudes) = hypothèses de confort.

## 7. Prochaine étape proposée

1. Captures et courte vidéo par le propriétaire (Studio au premier plan)
   et test mobile (iPhone ; A23 si disponible).
2. Validation de T10.2 ; puis décision sur l'import des 16 autres
   ressources (lot distinct) avant T10.3.

## 8. Import des 16 autres ressources (2026-11-22, demande du propriétaire)

Demande : « importer toutes les ressources restantes » (lève la réserve
D-031 sur l'import). Même chaîne que le prototype T10.1 (D-033).

| Étape | Résultat |
|---|---|
| Fiches Polyfork (API publique) | 16/16 `free: true`, CC BY 4.0, ligne de crédit relevée |
| Téléchargement GLB | 16/16 dans `assets_src/polyfork/` (hors Git) |
| Correction (`tools/fix_glb_colors.luau`) | 16/16 : sommets linéaire → sRGB ; recolorés : grès, cristaux solaires (rouges → orange), éclat de glace, poussière mystique, fragment d'étoile, géode, orbe |
| Manifeste | 16 lignes remplies avant import, statut « Importé » après |
| Import Studio | Manuel (propriétaire) ; 16 gabarits rangés dans `ServerStorage.ResourceTemplates`, imports d'origine dans `ServerStorage._T10_2_Imports` |
| Config | `ResourceVisualConfig.<ressource>.model` pour les 16 ; nouvelle surcharge `exclude` (testée par `ConfigTests`) |
| Sauvegarde | Place enregistré par le propriétaire dans `places/T10_1_prototype.rbxl` (14:08, même fichier que T10.1, remplacé) ; relu avec Lune : 20 gabarits présents. `GrabAndGrow.rbxl` inchangé (12:59) |
| Chargeur | Ignore désormais les pièces invisibles de la source (`RootPart` ajouté par l'importeur à `frozen_stone` et `mystic_core`) |

Vérifications Studio (Play solo, exécutées) :

- 20/20 modèles chargés, aucun avertissement du chargeur ; 160/160 nœuds
  en modèle, 0 Part serveur visible.
- Pièces par modèle : 1 à 3 (budget ≤ 3 respecté après exclusions :
  `frozen_stone` 1, `mystic_core` 3, `sun_crystal` 3).
- Contrôle visuel des 20 modèles côte à côte
  (`performance/T10_2_captures/20_ressources.jpg`) : la pépite d'or en Neon
  se lisait comme une tache plate (`20_ressources_v1.jpg`) → passée en
  couleurs de sommets, sans Neon.
- Épique en jeu avec aura (`epique_sun_crystal_aura.jpg`) ; collecte d'un
  modèle à 3 pièces : copie Neon, éclat, aura libérée, rien de résiduel.
- Lune : tous les tests OK ; LSP : 0 erreur.

Mesures Studio (Green Valley, point d'arrivée ; FPS non interprétables) :

| Poste | T10.1 | T10.2 primitives | T10.2 + 20 modèles |
|---|---|---|---|
| Parts Workspace | 2 709 | 2 992 | 2 858 |
| MeshParts | 89 | 89 | 221 |
| Pièces des visuels client | — | 338 | 204 (toutes MeshParts) |
| `GraphicsMeshParts` | 5,2 Mo | 4,6 Mo | 7,8 Mo |
| `GraphicsParts` | 2,4 Mo | 2,6 Mo | 2,7 Mo |
| `GraphicsParticles` | 12,1 Mo | 12,1 Mo | 12,1 Mo |

Points à surveiller :

- Triangles : ≈ 95 000 pour les 160 nœuds (sélection T10.0), dans le
  budget de 120 000 ; **non mesurés sur appareil**. La réserve A23 devient
  prioritaire : c'est le cas « extension aux 20 ressources » visé par
  D-031.
- `spectral_ore` (géode) : cristaux visibles d'un seul côté ; la rotation
  d'attente (Peu commun) les montre, mais pas en « Effets réduits ».
- `ice_shard` couché (la sélection prévoyait de le redresser à 40°, non
  fait : pas de surcharge de rotation).
- `frozen_stone` : variante par défaut du tas de rochers (pas de variante
  `count`).
- Couleurs et tailles = hypothèses visuelles ; contrôle sur mobile à faire.
