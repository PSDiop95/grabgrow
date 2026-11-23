# Prompts d'images — ChatGPT (icône, miniatures, icônes de reliques)

Date : 2026-11-23. Prompts prêts à coller dans ChatGPT, **un prompt par
message**. Ils sont en anglais, ce qui rend les images plus précises ;
chaque prompt fonctionne seul.

Les images générées sont des **propositions** : elles demandent la
validation du propriétaire et une ligne dans `docs/assets/ASSET_MANIFEST.md`
(outil, date, prompt, retouches) avant tout envoi sur Roblox.

## Mode d'emploi

1. Ouvrir une **nouvelle conversation** pour chaque série, pour garder un
   style cohérent sans mélanger les consignes.
2. Coller un prompt. Si le résultat convient, demander des variantes :
   `Same image, 3 variations, keep the style and composition.`
3. Formats : ChatGPT produit du 1024 × 1024 (carré) ou du 1536 × 1024
   (paysage).
   - Icône : réduire à **512 × 512**.
   - Miniature : recadrer en 16:9 (1536 × 864), puis agrandir à
     **1920 × 1080** dans un éditeur.
4. Ne pas demander de texte dans l'image ; ajouter le titre ensuite si
   besoin.
5. Contrôler chaque image : rien qui n'existe pas dans le jeu (Pets, œufs,
   armes, sang), aucun logo, aucun texte parasite.

Corrections utiles à envoyer après une image :

- `Remove all text, letters and logos from the image.`
- `Make the shapes simpler and more low-poly, fewer small details.`
- `Increase contrast and readability at small size.`
- `The character must look like a simple blocky toy figure, not a realistic human.`

---

## Icônes (512 × 512)

### I1 — Personnage au sac débordant (recommandé)

```text
Square game icon, 1:1. Stylized low-poly 3D render, bright saturated but controlled colors, soft studio lighting, clean shapes readable at very small size.
Subject: a cheerful blocky toy-like character (simple cube head, simple body, friendly face) seen from the front, three-quarter view, carrying a huge oversized backpack that is overflowing with colorful resources: green leaves, a wooden log, grey stones, a red apple, glowing green and purple crystals, and a few shiny gold coins popping out.
The character is jumping slightly with joy. Background: a simple soft gradient from turquoise to light green with a hint of a rounded green hill, no detailed scenery.
Composition: subject centered and large, filling about 80% of the frame, nothing important near the edges (the icon may be cropped with rounded corners).
No text, no letters, no logo, no watermark, no UI.
```

### I2 — Gros plan sur le sac

```text
Square game icon, 1:1. Stylized low-poly 3D render with flat-shaded facets, vibrant colors, strong readable silhouette.
Subject: a chunky cartoon backpack, front view, bursting open with treasures: emerald green crystal, purple amethyst crystal, blue sapphire crystal, golden sun crystal, a gold nugget and several gold coins flying out with small sparkles. The backpack is warm orange-brown with rounded shapes.
Background: simple radial gradient, warm yellow center to soft green edges, subtle light rays.
Composition: centered, large, clear contrast between the backpack and the background, nothing important near the edges.
No text, no letters, no logo, no watermark.
```

### I3 — Emblème des quatre mondes

```text
Square game icon, 1:1. Stylized low-poly 3D render, saturated colors, soft lighting.
Subject: a small floating round island split into four quarters, each quarter a different biome: green grassy valley with a rounded tree (top left), golden desert with dunes and a small cactus (top right), snowy blue ice peaks (bottom left), mystic purple land with glowing crystals and tiny stars (bottom right). In the center of the island, a glowing crystal sprout grows upward.
Background: deep blue sky gradient with a few soft clouds.
Composition: island centered and large, readable at small size, nothing important near the edges.
No text, no letters, no logo, no watermark.
```

---

## Miniatures (1536 × 1024, puis recadrage 16:9)

Rappel : à côté de ces illustrations, prévoir au moins deux **vraies
captures** du jeu.

### T1 — La boucle de jeu à Green Valley

```text
Wide landscape game key art, 3:2, composition safe for a 16:9 crop (keep important elements in the central band, leave top and bottom margins).
Stylized low-poly 3D style, flat-shaded facets, bright saturated colors (greens, turquoise, soft yellow), warm sunny lighting.
Scene: a lush floating island called a valley, with soft rounded hills, stylized round trees, small wooden bridges, a winding path and a turquoise pond. Three blocky toy-like characters collect resources: one picks up a glowing green crystal, one grabs a wooden log, one reaches for a red apple on a small bush. Each wears a backpack with a small glowing fill bar. Small leaves and sparkles float toward the backpacks.
In the background, a wooden market stall with a large golden coin sign (no letters) where resources are sold.
No text, no letters, no logo, no watermark, no user interface.
```

### T2 — La vente et les Coins

```text
Wide landscape game key art, 3:2, composition safe for a 16:9 crop.
Stylized low-poly 3D style, vibrant colors, cheerful mood.
Scene: a blocky toy-like character stands on a glowing circular sell pad in a green valley and empties a big backpack; colorful resources (leaves, stones, apples, crystals) dissolve into a fountain of shiny gold coins that burst upward around the character. The character looks excited. Behind, a small wooden market stall and rounded green hills.
Lighting: warm golden light coming from the coins, soft shadows.
No text, no letters, no numbers, no logo, no watermark, no user interface.
```

### T3 — Les quatre mondes

```text
Wide landscape panoramic game key art, 3:2, composition safe for a 16:9 crop.
Stylized low-poly 3D style, clean geometric shapes, saturated but controlled colors.
Scene: four floating islands in the sky, connected by glowing light trails, from left to right:
1) Green Valley: green hills, round trees, a pond (greens and turquoise);
2) Golden Desert: golden dunes, ochre rocks, stylized cacti, small non-realistic ruins, a colorful oasis (ochre, orange, gold);
3) Frozen Peaks: snowy stylized mountains, ice caves, blue crystals (glacier blue, white, cyan);
4) Mystic World: purple floating rocks, glowing magenta and purple crystals, small stars (violet, magenta, deep blue).
A tiny blocky toy-like character with a backpack stands on the first island, looking toward the others.
No text, no letters, no logo, no watermark, no user interface.
```

### T4 — Combat contre le gardien de la forêt

```text
Wide landscape game key art, 3:2, composition safe for a 16:9 crop.
Stylized low-poly 3D style, dynamic but friendly, no violence, no blood, no weapons.
Scene: a circular stone arena on a green floating island, surrounded by rounded trees. In the center, a large friendly-looking forest guardian made of mossy wood, roots and leaves, with glowing green eyes, raising its root arms. On the ground, a glowing orange ring telegraphs its next attack. A blocky toy-like character with a backpack dodges to the side while reaching for a glowing green energy shard floating above the ground; several other shards float around the arena.
Lighting: late afternoon sun with green magical glow.
No text, no letters, no health bars, no logo, no watermark, no user interface.
```

### T5 — Sanctuaire et reliques sacrées

```text
Wide landscape game key art, 3:2, composition safe for a 16:9 crop.
Stylized low-poly 3D style, soft magical atmosphere.
Scene: a small sacred terrace at the edge of a forest sanctuary, with three stone pedestals. On each pedestal floats a glowing sacred relic: a golden-green heartwood seed. A blocky toy-like character with a backpack approaches in awe. In the background, four distant floating islands each show a faint glowing sanctuary: green forest, golden sun temple, blue ice shrine, purple astral altar. Gentle light beams rise from the pedestals.
No text, no letters, no logo, no watermark, no user interface.
```

### T6 — Jouer ensemble

```text
Wide landscape game key art, 3:2, composition safe for a 16:9 crop.
Stylized low-poly 3D style, bright and welcoming.
Scene: a snowy Frozen Peaks island with stylized mountains and blue ice crystals. Four blocky toy-like characters in different colorful outfits explore side by side, each collecting a different resource: an ice shard, a silver ore rock, a blue crystal and a sparkling ice diamond. Each has their own backpack with a small glowing fill bar. Friendly, cooperative mood, no fighting.
Lighting: crisp bright daylight, cyan reflections.
No text, no letters, no logo, no watermark, no user interface.
```

---

## Icônes de reliques sacrées (optionnel, interface)

À utiliser seulement si le propriétaire décide de remplacer les visuels
actuels de la section « Reliques sacrées » (autre lot, non autorisé ici).
Générer en 1024 × 1024, fond transparent, puis réduire.

Préambule à coller une fois au début de la conversation :

```text
I will ask for 4 game item icons that must share the exact same style: stylized low-poly 3D render, flat-shaded facets, a single object centered, three-quarter view, soft top-left lighting, a subtle colored glow around the object, transparent background (PNG), no text, no letters, no border, no shadow box. Readable at 64x64 pixels. Reply "ready" and wait for each request.
```

Puis un message par relique :

```text
Icon 1 — Heartwood Seed: a large glowing seed made of polished golden-brown wood with green leaf sprouts on top and faint green light veins; green glow.
```

```text
Icon 2 — Sun Relic: a small golden sun-shaped artifact with ochre stone inlay and radiant pointed rays; warm orange glow.
```

```text
Icon 3 — Frost Heart: a heart-shaped faceted ice crystal, pale cyan and white, with a soft inner blue light; cyan glow.
```

```text
Icon 4 — Astral Essence: a small floating orb of swirling violet and deep-blue mist with tiny star sparkles inside; magenta glow.
```

---

## Suivi

| Image | Prompt | Retenue | Fichier | Retouches | Manifeste |
|---|---|---|---|---|---|
| Icône | I1 / I2 / I3 | — | — | — | — |
| Miniatures | T1 à T6 | — | — | — | — |
| Reliques | 1 à 4 | — | — | — | — |
