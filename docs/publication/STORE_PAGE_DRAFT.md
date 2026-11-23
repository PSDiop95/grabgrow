# Page de l'expérience — brouillon (préparation de publication)

Date : 2026-11-23. **Brouillon à valider par le propriétaire.** Aucune
publication, aucun changement de visibilité ni aucun réglage du Creator
Dashboard n'est fait par ce document. Les règles Roblox citées viennent de
la documentation connue au T9 : à revérifier le jour de la publication.

## 1. Nom

`GRAB & GROW` (identique en EN et en FR).

## 2. Descriptions (limite Roblox : 1 000 caractères)

Règle Roblox : la première phrase doit résumer le jeu, sans répéter de
mots-clés. Ne rien promettre qui n'existe pas (pas de Pets, quêtes,
classements ni achats).

### EN (≈ 610 caractères)

```text
Grab resources, fill your backpack, sell for Coins and grow stronger across four colorful islands.

Explore Green Valley, Golden Desert, Frozen Peaks and Mystic World. Collect 20 resources, from leaves and stones to rare crystals, then upgrade your backpack, grabber, magnet and boots to collect faster.

Defeat each world's guardian in your own personal battle to unlock its sacred sanctuary for good, and earn sacred relics: sell them or use them for powerful one-time upgrades.

Complete your Collection Journal. Play solo or alongside other players: your progress is always your own.

3D models by Polyfork (polyfork.dev), CC BY 4.0, modified. Full credits in game: Shop > Settings > Credits.
```

### FR (≈ 680 caractères)

```text
Ramassez des ressources, remplissez votre sac, vendez-les contre des Coins et devenez plus fort sur quatre îles colorées.

Explorez Green Valley, Golden Desert, Frozen Peaks et Mystic World. Collectez 20 ressources, des feuilles et pierres jusqu'aux cristaux rares, puis améliorez votre sac, votre pince, votre aimant et vos bottes pour récolter plus vite.

Battez le gardien de chaque monde lors d'un combat personnel pour débloquer son sanctuaire sacré pour toujours, et gagnez des reliques sacrées : vendez-les ou utilisez-les pour des améliorations uniques.

Complétez votre Journal de collection. Jouez seul ou avec d'autres joueurs : votre progression reste la vôtre.

Modèles 3D par Polyfork (polyfork.dev), CC BY 4.0, modifiés. Crédits complets en jeu : Boutique > Paramètres > Crédits.
```

Remarque : le jeu vouvoie dans ses textes FR (`LOCALIZATION.md`, T5.4) ;
la description suit la même règle.

## 3. Crédits CC BY 4.0 (anomalie A-4, bloquant avant publication)

20 meshes Polyfork sous CC BY 4.0, tous **modifiés**
(`docs/assets/ASSET_MANIFEST.md`). Les 20 lignes complètes font environ
2 000 caractères : elles **ne tiennent pas** dans la description
(1 000 caractères).

Options (décision du propriétaire) :

| Option | Effet | Coût |
|---|---|---|
| A. Panneau « Crédits » en jeu (menu) avec les 20 lignes | Crédit complet visible par chaque joueur | Petit lot client + clés EN/FR ; hors périmètre actuel, autorisation requise |
| B. Ligne courte dans la description + liste complète sur une page publique (dépôt ou site) | Pas de code | Nécessite une page publique stable ; lien hors plateforme dans la description à vérifier contre les règles Roblox |
| C. A + ligne courte dans la description | Le plus complet | Option A + texte |

**Option C retenue (D-039, 2026-11-23)** : panneau « Crédits » en jeu
(Boutique > Paramètres > Crédits, `CreditsController`, `CreditsConfig`)
implémenté ; ligne courte ci-dessus dans les deux descriptions. Aucune
conformité juridique n'est affirmée ici.

Liste à afficher (extraite du manifeste) :

```text
Amethyst Ore Deposit by Polyfork (https://polyfork.dev/asset/amethyst-ore-deposit-02d55d), CC BY 4.0
Apple by Polyfork (https://polyfork.dev/asset/apple-b15012), CC BY 4.0
Boulder Field Cluster by Polyfork (https://polyfork.dev/asset/boulder-field-cluster-08e364), CC BY 4.0
Copper Ore Deposit by Polyfork (https://polyfork.dev/asset/copper-ore-deposit-d5e58b), CC BY 4.0
Crystal Shard by Polyfork (https://polyfork.dev/asset/crystal-shard-9e0a83), CC BY 4.0
Divination Orb by Polyfork (https://polyfork.dev/asset/divination-orb-115d77), CC BY 4.0
Emerald Ore Deposit by Polyfork (https://polyfork.dev/asset/emerald-ore-deposit-4f0566), CC BY 4.0
Fallen Log by Polyfork (https://polyfork.dev/asset/fallen-log-1685fb), CC BY 4.0
Fallen Oak Leaf by Polyfork (https://polyfork.dev/asset/fallen-oak-leaf-5b15fe), CC BY 4.0
Fossil Ribcage by Polyfork (https://polyfork.dev/asset/fossil-ribcage-b243c5), CC BY 4.0
Gem Chip Heap by Polyfork (https://polyfork.dev/asset/gem-chip-heap-573355), CC BY 4.0
Geode Boulder by Polyfork (https://polyfork.dev/asset/geode-boulder-e8091d), CC BY 4.0
Glowing Crystal Cluster by Polyfork (https://polyfork.dev/asset/lair-crystal-column-877d1a), CC BY 4.0
Gold Nugget by Polyfork (https://polyfork.dev/asset/gold-nugget-ccd143), CC BY 4.0
Medium Rock by Polyfork (https://polyfork.dev/asset/medium-rock-e08405), CC BY 4.0
Meteorite by Polyfork (https://polyfork.dev/asset/meteorite-c400d9), CC BY 4.0
Rough Diamond by Polyfork (https://polyfork.dev/asset/rough-diamond-fecf28), CC BY 4.0
Sandstone Outcrop by Polyfork (https://polyfork.dev/asset/sandstone-outcrop-75800b), CC BY 4.0
Sapphire Ore Deposit by Polyfork (https://polyfork.dev/asset/sapphire-ore-deposit-f8a71a), CC BY 4.0
Silver Ore Deposit by Polyfork (https://polyfork.dev/asset/silver-ore-deposit-57f7c3), CC BY 4.0
All models modified (recolored, rescaled, simplified) for GRAB & GROW.
```

## 4. Images de la vitrine

| Élément | Format attendu par Roblox (à revérifier) | Source |
|---|---|---|
| Icône | 512 × 512 px, PNG ou JPG, sujet centré, lisible en petit | Prompts `IMAGE_PROMPTS_CHATGPT.md` (I1 à I3) |
| Miniatures | 1920 × 1080 px (16:9), jusqu'à 10 images | Prompts T1 à T6 ou captures Studio |
| Captures | Idem miniatures | Captures réelles du place de test (recommandé pour au moins 2 miniatures) |

Règles à respecter (modération Roblox et CLAUDE.md §4.3) :

- L'image doit représenter le jeu tel qu'il est : low-poly, 4 îles, sac,
  ressources, gardiens. Pas de Pets, d'œufs ni d'éléments absents.
- Aucun texte généré par l'IA (souvent illisible) ; le titre se rajoute si
  besoin dans un éditeur.
- Aucun logo Roblox, aucune marque, aucune mention de Robux, aucun lien.
- Au moins une miniature tirée d'une **vraie capture** pour éviter une
  vitrine trompeuse.
- Chaque image générée est notée dans `ASSET_MANIFEST.md` (outil, date,
  prompt, retouches) avant publication.

## 5. Avant de publier (rappel, rien n'est autorisé ici)

1. Fusionner la PR https://github.com/PSDiop95/grabgrow/pull/2 (T10
   validée le 2026-11-23, D-039).
2. Crédits : option C faite (D-039) ; saisir la ligne courte dans la description.
3. Valider nom, descriptions, icône, miniatures.
4. Questionnaire de classification et choix d'audience (propriétaire).
5. Expérience de production distincte, DataStore vierge.
6. Test fermé (`RELEASE_PLAN.md`), dont mobile réel et Galaxy A23.
7. Vérifier le bord de l'arène Root (vide au-delà de 34 studs).
