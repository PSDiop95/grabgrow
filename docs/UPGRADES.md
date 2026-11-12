# GRAB & GROW — Améliorations et déblocage des mondes (T4)

Dernière mise à jour : 2026-11-12 — T4 implémenté, en attente de validation.

Décision : `decisions/TECHNICAL_DECISIONS.md`, D-015 (et D-006, D-014).
Analyse économique : `PROGRESSION.md`. Vente : `SELLING.md`.

## Modules

| Module | Rôle |
|---|---|
| `Shared/Config/UpgradeConfig` | Cinq tables de la Bible (coût, effet, `startLevel`, `profileKey`, `order`) |
| `Shared/Config/WorldConfig` | Quatre mondes : ordre, coût, niveau de Backpack requis |
| `Shared/Util/UpgradeMath` | Lecture des tables : niveau, effet, coût suivant, coût cumulé (serveur et client) |
| `Shared/Util/SaleValue` | `applyMultiplier` : `floor(base × multiplicateur)` en centièmes entiers |
| `Services/EconomyService` | `credit` / `debit` sur le brouillon d'un `Update`, journal |
| `Services/UpgradeService` | Achat x1 d'une amélioration |
| `Services/WorldUnlockService` | Déblocage d'un monde |
| `ServerOnlyConfig/EconomySecurityConfig` | Limites de fréquence, longueur des identifiants |
| `Controllers/UpgradeController` (client) | Boutique, état des mondes, confirmation |

Branchement et `Humanoid.WalkSpeed` : `Bootstrap.server.lua`.
Tests manuels : `Systems/StudioTestPresets` (Studio uniquement) et
`tests/TEST_STRATEGY.md`, U1 à U10.

## Effets

| Amélioration | Champ du profil | Départ → max | Appliqué par | Moment |
|---|---|---|---|---|
| Backpack | `backpackLevel` | 1 (50) → 16 (2 000) | `InventoryService` (capacité) | Ajout suivant ; le sac n'est jamais vidé |
| Grabber | `grabberLevel` | 1 (0,75 s) → 10 (0,36 s) | `CollectionService` (cadence) | Collecte suivante |
| Magnet | `magnetLevel` | 0 (12 studs) → 9 (30 studs) | `CollectionService` (portée + marge 4) | Collecte suivante |
| Boots | `bootsLevel` | 1 (16) → 10 (20,5 studs/s) | `Bootstrap` (`WalkSpeed`) ; `CollectionService` (contrôle de trajet) | Immédiat, puis à chaque apparition |
| Multiplier | `multiplierLevel` | 1 (x1) → 10 (x1,5) | `SellService` | Vente suivante, jamais rétroactif |

Tous les effets sont lus dans le profil serveur. Le client ne transmet
jamais de niveau, de prix ni d'effet.

## Flux d'un achat

```text
Client : RequestUpgrade { upgradeId = "Backpack" }
Serveur (UpgradeService.HandleRequest) :
  1. limite de fréquence             -> RATE_LIMITED
  2. profil chargé                   -> PROFILE_NOT_LOADED
  3. payload (champ unique)          -> INVALID_TARGET
  4. amélioration connue             -> INVALID_TARGET
  5. transaction (un seul Update) :
       niveau max ?                  -> MAX_LEVEL
       débit du coût suivant         -> INSUFFICIENT_FUNDS
       niveau + 1                    -> SUCCESS
Serveur : ActionResult { action = "Upgrade", ok, code, upgradeId, level, coinsSpent }
          StateUpdated (succès)
```

## Flux d'un déblocage

```text
Client : RequestUnlockWorld { worldId = "GoldenDesert" } (après confirmation à l'écran)
Serveur (WorldUnlockService.HandleRequest) : limite -> profil -> payload ->
  monde connu -> dans un seul Update :
    déjà débloqué                    -> ALREADY_UNLOCKED
    monde précédent verrouillé       -> REQUIREMENT_NOT_MET
    Backpack insuffisant             -> REQUIREMENT_NOT_MET
    solde < coût                     -> INSUFFICIENT_FUNDS
    débit + worlds[id] = true        -> SUCCESS
```

| Monde | Ordre | Backpack requis | Coût |
|---|---|---|---|
| Green Valley | 1 | — | Gratuit, débloqué au départ |
| Golden Desert | 2 | 5 | 1 500 |
| Frozen Peaks | 3 | 8 | 35 000 |
| Mystic World | 4 | 10 | 250 000 |

Aucun contenu jouable hors Green Valley : le déblocage est enregistré et
affiché (« Contenu à venir »), sans téléportation.

## Transactions

- Contrôles, débit et changement de niveau ou de monde dans un seul
  `PlayerDataService.Update` : tout ou rien.
- `Update` ne suspend jamais le fil : deux demandes simultanées sont
  traitées l'une après l'autre ; la seconde voit le solde et le niveau
  laissés par la première.
- Montants entiers ≥ 1, solde jamais négatif, aucun résultat au-delà de
  2^53 − 1.
- Statistiques : débit → `totalCoinsSpent`, vente → `totalCoinsEarned`.
- Aucune sauvegarde DataStore déclenchée par un achat : cycle normal (60 s
  et sortie).
- Journal serveur, une ligne par opération réussie :
  `joueur <id> : -100 Coins (motif Upgrade:Backpack, opération Upgrade-1, solde 32)`.

## Interface (client)

- Bouton « Boutique » : sur écran tactile, juste au-dessus du bouton Grab
  (à sa gauche si la place manque ou si le panneau du sac gêne), suivi
  par événements ; sinon au bord
  droit, au-dessus du milieu. Pastille verte : une amélioration est
  achetable.
- Panneau : solde et progression des mondes, une carte par amélioration
  (icône, nom, niveau → niveau suivant, effet → effet suivant, prix),
  puis les quatre mondes.
- États du bouton : prix (achetable), « Manque N » (fonds insuffisants),
  MAX, « ... » (achat en cours, 2 s au plus). Succès : message et contour
  vert ; échec : message, rien n'est dépensé.
- Monde : premier appui « Confirmer ? », second appui dans les 3 s.
- Entrées : toucher ; PC touche B ; manette croix haut (ouvrir/fermer),
  B (fermer), navigation native des boutons.
- Textes : clés `upgrade.*`, `shop.*`, `world.*` (anglais et français).
