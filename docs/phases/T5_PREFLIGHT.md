# T5 — HUD et feedback mobile : préflight

Date : 2026-11-12. Statut : **préflight validé** (décisions D-1 à D-7 :
recommandations acceptées, D-016) ; T5.1 terminé (section 9) ; T5.2 terminé (section 10) ; T5.3 terminé (section 11) ; T5.4 terminé (section 12) ; T5.5 non commencé.

Critère de la phase (architecture 20, ROADMAP) : **boucle complète
utilisable sur téléphone.**

## 1. État de départ

- T0 à T4 terminés ; commits locaux 69fb421 (T4) et e63039d (A-40), non
  poussés. Place de test publié avec le code T4.
- Boucle jouable de bout en bout : Prendre → sac → vente → Coins →
  boutique (5 améliorations) → déblocage des mondes (sans contenu).
- Interface construite par code dans quatre contrôleurs :
  `CollectionController` (ciblage, bouton Prendre), `InventoryController`
  (sac, Coins, messages), `SellController` (station, prompt),
  `UpgradeController` (boutique, mondes) ; `RangeRing` (anneau du Magnet).
  Pas de `HUDController`, `FeedbackController` ni `InputController`
  séparés (architecture 13.1).
- Validé sur téléphone réel : boutique, placement Prendre / Boutique / sac
  (A-35, A-39, A-41). Manette jamais testée sur matériel (E8, U10).
- Aucun son, aucune particule, aucun asset importé. `docs/assets/` absent.

## 2. Références

| Source | Exigence pour T5 |
|---|---|
| GDD 4.2 | Première session : feedback clair dès la 1re collecte, 1re vente très tôt ; tutoriel contextuel (instruction courte + flèche ou marqueur), jamais bloquant |
| GDD 12.1, 12.4 | Lisible sur petit écran, peu de panneaux, boutons larges ; pas d'information par la couleur seule ; feedback visuel **et audio** |
| GDD 13.4 | Collecte : éclat + mouvement vers le joueur ; vente : compteur + pièces ; amélioration : impulsion lumineuse |
| Architecture 13.3 | Une main si possible ; option de réduction des effets et du son ; plusieurs ratios d'écran |
| Architecture 13.4 | Textes par clés ; pas de texte en dur |

## 3. Éléments reportés vers T5

| # | Constat | Proposition |
|---|---|---|
| A-29 | Aucun son ni animation à la collecte | Son court + éclat léger (lot T5.2) |
| A-33 | Pas de son ni d'effet de pièces à la vente | Son + effet de pièces (lot T5.2) |
| A-30 | Barre du sac en pastille ronde à faible remplissage | Corriger (lot T5.1) |
| A-38 | Icônes en glyphes Unicode ; noms de mondes non traduits | À décider (D-3) |
| A-22 | Messages d'expulsion en anglais brut | Passer par `Localization` (lot T5.4) |
| A-21 | `playTimeSeconds` jamais alimenté | À décider **avant** T5 (D-5) |
| E8, U10 | Manette jamais testée sur matériel | Test si manette disponible (T5.5) |
| D-011 | `Localization` provisoire, « à revoir en T5 » | À décider (D-4) |

## 4. Périmètre proposé (lots)

| Lot | Contenu | Fichiers principaux |
|---|---|---|
| T5.1 HUD | Barre du sac corrigée (A-30) ; hiérarchie Coins / sac ; indication « Sac plein → Vendre » plus visible ; vérification sur 4 ratios | `InventoryController` |
| T5.2 Feedback | `FeedbackController` client : sons (collecte, vente, achat, refus), éclat de collecte, pièces à la vente, impulsion à l'achat ; budget d'effets mobile ; aucun effet permanent | nouveau `FeedbackController`, `SoundService/SFX` |
| T5.3 Première session | Guidage contextuel non bloquant : « Prends une ressource » → « Vends au stand » (marqueur vers la station) → « Améliore ton sac » ; disparaît après chaque étape ; jamais rejoué une fois terminé | nouveau contrôleur client ; état « vu » à décider (D-2) |
| T5.4 Textes | A-22 ; relecture EN/FR de tous les textes ; décision D-4 | `Localization`, `PlayerSession` |
| T5.5 Validation | Parcours complet sur téléphone réel (portrait, paysage), tablette (émulateur), PC ; manette si disponible | docs/tests |

Hors périmètre T5 : Gems, Stars, Pets, quêtes, Grab Combo, événements,
monétisation, contenu des mondes, modification des valeurs économiques,
refonte serveur. Aucun changement de règle de jeu.

## 5. Décisions (validées : recommandations acceptées, D-016)

| # | Question | Options | Recommandation |
|---|---|---|---|
| D-1 | Source des sons | a) sons du Creator Store Roblox (licence Roblox, à consigner) ; b) fichiers externes à importer ; c) pas de son en T5 | a), 4 à 5 sons courts, consignés dans `docs/assets/ASSET_MANIFEST.md` (à créer) |
| D-2 | Mémoriser la fin du guidage | a) champ `tutorialDone` dans le profil (**changement de schéma** : migration v→v+1 et tests) ; b) déduit des statistiques existantes (`totalCoinsEarned > 0`, niveau Backpack > 1), sans schéma ; c) rejoué à chaque session | b) : aucun changement de schéma |
| D-3 | Icônes de la boutique (A-38) | a) garder les glyphes (OK sur un téléphone) ; b) images importées (assets à créer et licencier) | a) en T5, b) plus tard |
| D-4 | Localisation | a) garder `Localization` (module) ; b) migrer vers `LocalizationService` (tables Roblox) | a) : fonctionne, testé ; migration sans gain pour le MVP |
| D-5 | `playTimeSeconds` (A-21) | a) l'alimenter (serveur, sauvegardé, utile pour T7) ; b) le laisser vide jusqu'à T7 | b) : hors du thème de T5 |
| D-6 | Option « réduire effets et son » (archi 13.3) | a) bouton muet + effets réduits dans le HUD ; b) reporter | a) si D-1 = a, sinon b) |
| D-7 | Architecture client | a) garder les contrôleurs actuels + `FeedbackController` ; b) refondre en `HUDController` / `InputController` (archi 13.1) | a) : refonte coûteuse, sans bénéfice joueur |

## 6. Critères d'acceptation proposés

1. Nouveau joueur sur téléphone réel : 1re collecte, 1re vente et 1er achat
   sans aide extérieure, guidés par le jeu, sans écran bloquant.
2. Chaque action (collecte, vente, achat, refus) a un retour visuel ; un
   retour sonore si D-1 ≠ c ; le refus ne repose pas sur la couleur seule.
3. Aucun chevauchement entre HUD, boutons Roblox, chat, stick et saut, en
   portrait et en paysage, sur 4 ratios (téléphone petit / grand, tablette,
   PC).
4. Aucun texte en dur hors `Localization` ; EN et FR complets (test).
5. Performance : aucune boucle par frame ajoutée ; effets détruits après
   usage ; nombre d'instances stable après 5 minutes de jeu (mesuré).
6. Aucun changement serveur autoritaire, économique ou de schéma (sauf
   D-2 = a, avec migration et tests).

## 7. Risques

- Sons et images : licence de chaque asset à vérifier et consigner.
- Effets sur appareils modestes : à mesurer (instances, FPS) sur téléphone.
- Guidage : ne doit jamais bloquer ni réapparaître pour un joueur avancé.
- Manette : toujours aucun matériel ; risque de non-validation.
- Place de test publié : contient du code non poussé (sans risque
  production, mais à garder en tête).

## 8. Tests prévus

- Automatisés : clés de localisation (toutes langues), logique du guidage
  (étapes déduites de l'état, sans Roblox), absence de texte en dur
  (contrôle ciblé).
- Studio : rendu sur ratios émulés ; budget d'instances avant / après 5 min.
- Téléphone réel : parcours « nouveau joueur » complet, portrait et paysage.
- Manette : si disponible.

## 9. Lot T5.1 — HUD (2026-11-12, TERMINÉ)

Clôturé par le propriétaire le 2026-11-12 : test sur téléphone réel OK.

### Audit de départ

| Élément | Constat |
|---|---|
| Panneau du sac (`InventoryController`) | Haut centre, bande de la barre Roblox (`IgnoreGuiInset`, A-41), 45 % de largeur (170–300 px), 82 px de haut ; titre « Sac n / max », barre de 10 px à coins ronds (A-30), détail des ressources, ligne Coins + valeur |
| Boutique (`UpgradeController`) | Bouton au-dessus de « Prendre » (ou à sa gauche) ; panneau centré, 90 % × 82 %, max 560 × 640 ; fermeture X (64 × 44), B, croix haut |
| Prendre (`CollectionController`) | Suit le `JumpButton` (A-35) ; inchangé |
| Vente (`SellController`) | Prompt natif, étiquette masquée pendant le prompt (A-34) ; inchangé |
| Messages | `NotificationsUI`, toast à 96 px du haut ; inchangé |
| Constat | Panneau Boutique centré : son haut passait sous le bas du sac (bande de la barre Roblox) sur un téléphone en paysage (calcul : 705 × 338, bande 58 px → haut du panneau à 83 px, bas du sac à 90 px) |

### Réalisé

- `Shared/Util/BagDisplay` (nouveau, logique pure) : état du sac déduit de
  `used` / `capacity` du serveur ; aucune capacité calculée côté client.
  Seuils (paramètres d'interface, hypothèses à valider sur appareil) :
  | État | Condition | Affichage |
  |---|---|---|
  | Vide | `used = 0` | Pastille compacte, sans remplissage |
  | Presque vide | < 25 % | Pastille compacte, remplissage vert |
  | En remplissage | 25 % à < 80 % | Barre pleine largeur, vert → jaune |
  | Presque plein | 80 % à < 100 % | Barre orange, « Presque plein », contour, une impulsion à l'entrée |
  | Plein | `used >= capacity` | Barre rouge, « Sac plein ! », contour, « Vendez au stand ! » à la place du détail |
- Pastille → barre : la piste s'élargit depuis son centre (0,25 s), seulement
  au changement de forme ; aucun déplacement du panneau, hauteur fixe.
- A-30 : remplissage à coins de 6 px, largeur minimale 6 px, inséré dans une
  piste de 26 px : plus de point rond à faible remplissage.
- Hiérarchie : ligne 1 sac (🎒, glyphe existant de la boutique), ligne 2
  Coins (pièce dessinée, 18 px, gras) et valeur estimée (13 px, atténuée),
  ligne 3 détail. Textes réduits plutôt que tronqués (`UITextSizeConstraint`).
- Boutique : panneau centré dans la zone sûre située **sous** le sac
  (recalcul par événements : taille de l'écran, position du sac) ; taille
  maximale, fermeture, contenu inchangés.
- Textes : `hud.bag_almost_full` (« Almost full » / « Presque plein »),
  `hud.sell_hint` (« Sell at the stand! » / « Vendez au stand ! »).
- Aucun changement serveur, économique, de schéma, de contrôle de collecte
  ou de vente. API publique d'`InventoryController` inchangée.

### Corrections pendant les tests Studio

- Le début du remplissage passait sous l'icône 🎒 : zone de remplissage
  décalée à droite de l'icône (28 px).
- « Sac plein ! » en jaune sur fond rouge, peu lisible : texte du sac
  toujours blanc avec contour noir.

### Tests

| Test demandé | Type | Résultat |
|---|---|---|
| 1–5 Sac vide, presque vide, 50 %, presque plein, plein | Lune (`HudTests`) et Studio | OK — Studio : 0, 1, 2, 30, 39 (jaune), 40 (« Presque plein », orange, contour), 50 / 50 (« Sac plein ! », rouge, « Vendez au stand ! ») |
| 6 Capacité après Backpack | Lune (état serveur via `InventoryService.describe`) | OK |
| 7 Ressources inconnues comptées | Lune | OK |
| 8 HUD après collecte | Studio, collectes réelles par `RequestCollect` | OK — sac, détail et valeur mis à jour ; collecte de trop : `INVENTORY_FULL`, message « Sac plein ! Vendez au stand », sac inchangé |
| 9 HUD après vente | Studio, `RequestSell` au stand | OK — `SUCCESS`, +86, Coins 300 → 386 ; barre → pastille en 0,25 s, centre stable (494–495 px), panneau immobile |
| 10 Boutique | Studio | OK — ouverture (bouton, B), fermeture (X, B) sur PC ; tactile : X confirmé par clic réel du propriétaire (clics simulés MCP décalés de la barre Roblox, 58 px) |
| 11 Doublons d'événements | Studio | OK — une collecte = 1 message, 1 mise à jour, 1 impulsion ; après réapparition : une seule instance de chaque ScreenGui, 117 descendants avant et après |
| 12 Localisation EN/FR | Lune (`HudTests`, `ConfigTests`) ; Studio en `fr-fr` | OK |
| Suites dans Studio | Play | `TOUS LES TESTS : OK` (HudTests 10 cas) |
| Synchronisation Rojo | Studio, Edit | 47 / 47 scripts identiques au dépôt (taille sans fins de ligne) |

### Formats d'écran (Studio, émulateur d'appareils)

Positions en pixels écran, barre Roblox de 58 px.

| Format | Écran | Sac | Boutique | Prendre | Saut | Prompt de vente | Panneau Boutique | Chevauchements |
|---|---|---|---|---|---|---|---|---|
| PC, fenêtre Studio | 990 × 512 | 345–645 / 8–90 | bord droit | — (non tactile) | — | — | 98–504 (8 px sous le sac) | 0 |
| Téléphone, paysage (tactile) | 801 × 413 | 250–550 / 8–90 | 693–789 / 157–209 | 696–786 / 221–311 | 706–776 / 323–393 | 315–470 / 258–339 | 98–405, x 120–680 | 0 |
| Tablette, paysage (tactile) | 1179 × 819 | 439–739 / 8–90 | 1021–1117 / 443–495 | 1024–1114 / 507–597 | 1009–1129 / 609–729 | 495–643 / 551–623 | 134–774, x 309–869 | 0 |
| PC 1920 × 1080 (rendu à l'échelle) | 1069 × 512 | 384–684 / 8–90 | 961–1057 / 204–256 | — | — | — | 98–504 | 0 |

Stick dynamique : zone x < 320 (téléphone), x < 471 (tablette) ; au repos
29–103 / 320–394 (téléphone). Le prompt de vente entre de 5 px dans la
zone du stick sur le téléphone : comportement natif, inchangé (comme E7).

**Non couvert** : téléphone petit et téléphone grand à leurs proportions
réelles. Trois réglages successifs de l'émulateur ont donné le même écran
(801 × 413, captures identiques) ; Studio n'a pas appliqué l'appareil.
PC 1920 × 1080 seulement rendu à l'échelle de la fenêtre.

### Captures (dossier de session, non versionnées)

Avant (code T4) : PC 30 / 50, PC 2 / 50 (point rond A-30). Après : PC
2 / 50, 40 / 50, plein, Boutique ; téléphone (repos, stand, Boutique) ;
tablette (Boutique) ; PC 16:9 (30 / 50). Dossier :
`~/.claude/projects/D--Projet-grabgrow/<session>/tool-results/`.

### Clôture

1. Fait : téléphone réel OK (propriétaire, 2026-11-12).
2. Fait (accord du propriétaire) : place de test sauvegardé en version 41
   (non publié), commit local ; aucun push.

## 10. Lot T5.2 — Feedback audio et visuel (2026-11-12, TERMINÉ)

Clôturé par le propriétaire le 2026-11-12 : téléphone réel validé.

### Audit de départ

| Événement | Source existante | Champs utilisés |
|---|---|---|
| Collecte réussie / refusée | `ActionResult` (`Collect`) | `ok`, `code`, `resourceId` (nœud), `resourceType`, `amount` |
| Inventaire mis à jour | `StateUpdated` via `InventoryController.onStateChanged` | `inventory.used`, `inventory.capacity` → tier `BagDisplay` |
| Vente / Coins crédités | `ActionResult` (`Sell`) puis `StateUpdated` | `ok`, `code`, `coinsEarned` |
| Achat d'amélioration | `ActionResult` (`Upgrade`) | `ok`, `code`, `upgradeId`, `level` |
| Déblocage de monde | `ActionResult` (`UnlockWorld`) | `ok`, `code`, `worldId` |

Aucun RemoteEvent ajouté, aucun service serveur modifié.

### Réalisé

- `Shared/Config/FeedbackConfig` : 8 sons (compte Roblox, voir
  `docs/assets/SOUND_MANIFEST.md`), volumes, durées, budgets d'effets.
- `Shared/Util/FeedbackRules` (logique pure) : retour par réponse serveur
  (positif seulement si `ok == true` et champs cohérents ; montant de vente
  = `coinsEarned`), retours d'état du sac (à la hausse seulement),
  anti-doublon par clé (0,3 s ; sac plein 1,5 s), budget d'effets,
  volumes selon les préférences.
- `Controllers/FeedbackController` : `SoundService/GrabGrowMaster` >
  `SFX` (groupes), sons pré-créés et réutilisés (9 instances, aucune
  création par événement) ; effets :
  | Action | Effet | Son |
  |---|---|---|
  | Collecte | Copie néon du nœud qui rétrécit vers le joueur (0,3 s) + 8 particules (texture moteur par défaut) | `collect` |
  | Presque plein / plein | (visuel T5.1 existant) | `bag_warning` / `bag_full` (+0,25 s) |
  | Vente | 6 pièces du personnage vers l'icône Coins (0,45 s), impulsion et éclair blanc de la ligne Coins ; toast `+N Coins` existant | `sell`, puis `coins` |
  | Amélioration | Anneau doré qui s'agrandit autour de l'icône, impulsion de l'icône, niveau en vert ; toast « avant → après » existant ; Magnet : anneau 3D A-40 seul | `upgrade` |
  | Monde | Contour doré de la ligne, 12 confettis, toast nommé « Golden Desert débloqué ! » | `world` |
  | Refus | Aucun visuel positif ; messages existants | `refuse` / `bag_full` |
- Préférences D-6 : section « Paramètres » en bas de la boutique (Son :
  Activé / Désactivé ; Effets réduits). Effets réduits : volume × 0,6,
  3 particules, 3 pièces, 5 confettis, animations plus courtes, éclat sans
  déplacement, pas d'anneau d'icône ; retours essentiels conservés.
  Activé par défaut si `GuiService.ReducedMotionEnabled` ou qualité
  graphique manuelle 1 à 3 (appareil modeste).
- **Persistance des préférences : session seulement.** Le profil v1
  contient déjà `settings.sfxEnabled`, mais aucun RemoteEvent ne permet de
  le lire ou de l'écrire, et « Effets réduits » n'a pas de champ. Persister
  demanderait un RemoteEvent et un traitement serveur (hors périmètre
  T5.2), plus une migration pour « Effets réduits ». Décision D-8 ci-dessous.
- Retouches d'interface : `InventoryController.getCoinIcon` /
  `highlightCoins` ; `UpgradeController` : noms `Icon` / `Level`, toast de
  déblocage nommé. Textes : `world.unlocked_named`, `settings.*` (EN/FR).

### Décision à valider

| # | Question | Options | Recommandation |
|---|---|---|---|
| D-8 | Persistance des préférences audio | a) session seulement (actuel) ; b) `sfxEnabled` persistant via un RemoteEvent `RequestSetting` (sans migration), « Effets réduits » en session ; c) b + champ `reducedEffects` (migration v1→v2) | a) pour T5, b) en T6 avec la revue serveur |
| D-9 | Emplacement des préférences | a) section en bas de la boutique (actuel, aucun nouveau bouton sur l'écran) ; b) bouton ⚙ dédié | a) |

### Tests

Voir `docs/PROJECT_STATUS.md`, « Vérifications T5.2 ».

## 11. Lot T5.3 — Première session (2026-11-13, TERMINÉ)

Détail : `docs/ONBOARDING.md` ; tests : `PROJECT_STATUS.md`,
« Vérifications T5.3 ».

### Audit de départ

| Élément | Constat |
|---|---|
| Statistiques du profil (`DataSchema`) | `totalResourcesCollected` (InventoryService), `totalSales` (SellService), `totalCoinsSpent` (EconomyService), `totalCoinsEarned` ; sauvegardées |
| État client (`GetClientState`) | Inventaire, Coins, niveaux, mondes ; **aucune statistique** |
| Confirmations serveur | `ActionResult` : Collect (`amount`), Sell (`coinsEarned`), Upgrade (`upgradeId`, `level`), UnlockWorld (`worldId`) |
| Contrôles | Collecte E / clic / X / « Prendre » ; vente F / Y / prompt ; boutique B / croix haut / bouton |

### Réalisé

- États `INTRO`, `COLLECT`, `SELL`, `UPGRADE`, `COMPLETED`, déduits des
  statistiques existantes (D-2 = b) : aucun champ ni migration.
- Changement serveur minimal (D-10, à valider) : `progress` dans l'état
  client. Aucun RemoteEvent ajouté.
- Carte non bloquante, repère ▼, flèche de bord, flèches ▶ sur la Boutique
  et les cartes payables ; masquage × et « ? Guide ».
- Seuil de vente : 10 unités (`OnboardingConfig`, hypothèse d'interface).

### Décision (acceptée, D-017)

| # | Question | Options | Recommandation |
|---|---|---|---|
| D-10 | Source des statistiques côté client | a) `progress` dans `StateUpdated` (actuel) ; b) déduction depuis inventaire, Coins et niveaux, sans changement serveur | a) : fiable, lecture seule, aucun RemoteEvent |

## 12. Lot T5.4 — Textes et localisation EN/FR (2026-11-13, TERMINÉ)

Détail : `docs/LOCALIZATION.md` ; tests : `PROJECT_STATUS.md`,
« Vérifications T5.4 ».

### Audit

| Source | Constat |
|---|---|
| `Localization` (EN/FR) | 17 textes FR du guidage au tutoiement ; reste de l'interface au vouvoiement ; espaces simples avant « ! ? : » |
| `PlayerSession` | 3 messages d'expulsion en anglais brut (A-22) |
| `UpgradeController` | Unités « s », « studs », « studs/s », « x » en dur |
| Contrôleurs | Autres textes en dur : symboles (× ▶ ▼ →, « X » de fermeture), touches `[E]` / `[B]` : conservés (non linguistiques) |
| Carte Studio (Workspace, StarterGui) | Aucun texte posé |
| Clés utilisées par le code | Toutes présentes en EN et FR |

### Réalisé

- Français au vouvoiement partout (guidage T5.3 compris).
- A-22 : `system.kick.*` EN/FR, traduits avec `Player.LocaleId` ;
  conditions d'expulsion inchangées.
- Unités des améliorations localisées (`unit.*`).
- Espace insécable avant `! ? : ;` en français, appliquée au chargement.
- `Localization.keys`, `Localization.NBSP` ; suite `LocalizationTests`.
- Aucune mécanique, valeur économique ni règle serveur modifiée.
