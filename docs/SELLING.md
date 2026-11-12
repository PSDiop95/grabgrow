# GRAB & GROW — Vente et Coins (T3)

Dernière mise à jour : 2026-11-12 — T3 implémenté, PARTIEL (D-014 validée ; E1–E9 et A-34 validés ; clôture en attente).

Décision : `decisions/TECHNICAL_DECISIONS.md`, D-014. État et résultats de
tests : `PROJECT_STATUS.md`. Collecte et inventaire : `COLLECTION.md`.

## Modules

| Module | Rôle |
|---|---|
| `Services/SellService` | Valide une demande de vente et exécute la transaction |
| `Systems/SellZones` | Zones de `Workspace.SellZones` → position serveur |
| `Shared/Util/SaleValue` | Formule de vente unique (serveur : calcul ; client : estimation) |
| `ServerStorage/ServerOnlyConfig/SellSecurityConfig` | Marges de sécurité, jamais répliquées |
| `Shared/Remotes/Remotes` | `RequestSell`, `Action.Sell`, `NOTHING_TO_SELL` |
| `Controllers/SellController` (client) | Prompt de vente, étiquette, retours |
| `Controllers/InventoryController` (client) | Coins, valeur estimée, confirmation `+N Coins` |

Branchement : `Bootstrap.server.lua`.

## Flux d'une vente

```text
Client : RequestSell { sellZoneId = "GreenValley_Main" }
Serveur (SellService.HandleRequest), dans cet ordre :
  1. limite de fréquence              -> RATE_LIMITED
  2. profil chargé                    -> PROFILE_NOT_LOADED
  3. payload                          -> INVALID_TARGET
  4. zone connue                      -> INVALID_TARGET
  5. personnage présent et vivant     -> NO_CHARACTER
  6. distance                         -> TOO_FAR
  7. transaction (un seul Update)     -> NOTHING_TO_SELL / INTERNAL_ERROR / SUCCESS
Serveur : ActionResult { action = "Sell", ok, code, sellZoneId, coinsEarned, quantitySold }
          StateUpdated { inventory, coins, ... } (succès)
```

Le payload n'accepte que `sellZoneId` (texte de 1 à 64 caractères). Tout
autre champ (`amount`, `coins`, `items`...) fait refuser la demande.

## Transaction

Une seule mutation `PlayerDataService.Update`, sans suspension du fil :

1. devis de `inventory.resources` (`SaleValue.quote`) ;
2. refus si rien de vendable (`NOTHING_TO_SELL`) ou si un calcul
   dépasserait 2^53 − 1 (`INTERNAL_ERROR`, journalisé) ;
3. retrait des ressources vendues (clé supprimée) ;
4. `currencies.coins += total` ;
5. `stats.totalCoinsEarned += total`, `stats.totalSales += 1` ;
6. contrôle du profil par le schéma ; sinon rien ne change.

`totalCoinsSpent` et `totalResourcesCollected` ne sont jamais touchés.
Une erreur à n'importe quelle étape annule tout : aucun crédit sans
retrait, aucun retrait sans crédit. Deux demandes simultanées sont
traitées l'une après l'autre ; la seconde voit le sac vidé
(`NOTHING_TO_SELL`). Une même ressource ne peut pas être vendue deux fois.

Chaque vente réussie est journalisée avec son motif :
`[Sell] joueur <id> : +N Coins (motif Sell, zone ..., k unité(s) : ...)`.

Aucune écriture DataStore par vente : sauvegarde périodique (60 s), de
sortie et de fermeture, inchangées (T1). Le retrait et le crédit sont dans
le même profil : une sauvegarde contient les deux ou aucun.

## Règles économiques

`SaleValue = somme(quantité × sellValue)`, valeurs de `ResourceConfig`
(Bible 3.2) : `green_leaf` 1, `wood` 2, `stone` 3. Aucun multiplicateur,
bonus, taxe, arrondi ni nouvelle monnaie. Aucune valeur économique modifiée
en T3.

Impact : nul sur les hypothèses de la Bible (temps jusqu'à la première
vente, première amélioration, revenu par minute) ; le montant crédité est
exactement celui de la Bible. A-19 (première amélioration à la 2e vente,
≈ 142 Coins/min au maximum) reste à mesurer en T7.

## Ressources inconnues (D-014)

Identifiant présent dans `inventory.resources` mais absent de
`ResourceConfig` (conservé par D-008) :

- jamais vendu, jamais valorisé, jamais supprimé ;
- toujours compté dans l'occupation du sac (D-012) ;
- sac ne contenant que des inconnues : `NOTHING_TO_SELL`, aucune mutation ;
- sac mixte : seules les connues sont vendues.

Conséquence pour les migrations : une ressource retirée de
`ResourceConfig` reste dans les sacs et occupe de la place sans pouvoir
être vendue. Avant de retirer ou renommer une ressource, prévoir une
migration explicite (conversion ou rachat) ; à l'inverse, la rétablir dans
`ResourceConfig` la rend de nouveau vendable sans perte.

## Paramètres

| Paramètre | Source | Valeur | Statut |
|---|---|---|---|
| Distance d'interaction | `GameConfig.Selling.interactRangeStuds` | 10 studs | Validée provisoirement, réévaluation T6 |
| Marge serveur | `SellSecurityConfig.Distance.toleranceStuds` | 4 studs (max accepté 14, 3D, HumanoidRootPart → centre de la zone) | Validée provisoirement, réévaluation T6 |
| Limite de fréquence | `SellSecurityConfig.RateLimits.Sell` | rafale 3, 1/s | Validée provisoirement, réévaluation T6 |
| Retour de limite | `SellSecurityConfig.RateLimitFeedback` | 1 réponse/s ; 1 ligne de journal / 50 rejets | Hypothèse T3 |
| Longueur d'identifiant | `SellSecurityConfig.Payload.maxSellZoneIdLength` | 64 | — |

Ces valeurs sont des hypothèses de sécurité, pas des paramètres
économiques (D-014, validation provisoire du 2026-11-11). Elles restent
configurables et seront réévaluées en T6 avec des mesures de latence et de
cadence réelles.

## Zone de vente

- `Workspace.SellZones.<...>` : BasePart avec l'attribut texte
  `SellZoneId`, unique. Position lue sur le Part (serveur) à chaque
  demande.
- Carte de test : station provisoire en `(-12, 0, -16)`, à 20 studs du
  point d'apparition, dalle jaune 10 × 10 `SellZonePad`
  (`GreenValley_Main`), comptoir, toit rouge et pièce dorée en primitives.
  Aucun texte ni logo dans les modèles.

## Client

- Un `ProximityPrompt` local par zone, visible à moins de 10 studs
  (indication de proximité) : « Sell / Vendre » et la valeur estimée
  (`~N Coins`) ou « Bag empty / Sac vide ».
- PC : F ; mobile : toucher le prompt ; manette : Y. (E et X restent la
  collecte.)
- Étiquette « Sell / Vente » au-dessus de la station, visible à 120 studs,
  masquée tant que le prompt est affiché (A-34 : de près, elle passait
  derrière le panneau du sac).
- HUD : ligne `Coins N | Valeur ~M` sous le sac ; défilement du solde et
  toast `+N Coins` avec le seul montant confirmé par le serveur.
- Messages : « Rien à vendre », « Approchez-vous du stand », « Vente
  impossible. Rien n'est perdu. », et « Sac plein ! Vendez au stand » à
  la collecte refusée pour sac plein.
- Une demande à la fois ; sans réponse après 2 s, une nouvelle est permise.

## Limites connues

- La position du personnage est simulée par le client (A-26) : un
  tricheur peut vendre à distance en falsifiant sa position, sans gain de
  Coins (la vente reste plafonnée au contenu réel du sac). Risque connu :
  validation des déplacements renforcée côté serveur en T6.
- Marges et limite de fréquence non mesurées avec une latence mobile réelle.
- Pas de son ni d'effet de pièces (GDD 13.4) : phase UX, avec A-29.
- Textes par `Localization` provisoire (T5).
- `EconomyService` (`CreditCurrency` / `DebitCurrency`) non créé : le crédit
  vit dans la transaction de vente pour rester atomique (D-014, validée).
  Extraction autorisée en T4 avec le premier débit.
