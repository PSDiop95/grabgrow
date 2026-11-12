# GRAB & GROW — Collecte et inventaire (T2)

Dernière mise à jour : 2026-11-11 — T2 validé et clôturé.

Décisions : `decisions/TECHNICAL_DECISIONS.md`, D-010 à D-012.
Risques ouverts pour T6 : A-26 (position simulée par le client), A-27
(marges de sécurité à mesurer).
État et résultats de tests : `PROJECT_STATUS.md`.

## Modules

| Module | Rôle |
|---|---|
| `Services/CollectionService` | Valide une demande de collecte et l'applique |
| `Services/InventoryService` | Lecture du sac, capacité, ajout de ressources |
| `Services/RateLimitService` | Limite de fréquence par joueur et par action |
| `Systems/ResourceSpawner` | Registre des nœuds, états, réapparition (logique pure) |
| `Systems/ResourceNodes` | Points de spawn → Parts dans `Workspace.ResourceNodes` |
| `ServerStorage/ServerOnlyConfig/CollectionSecurityConfig` | Marges de sécurité, jamais répliquées |
| `Shared/Remotes/Remotes` | Création des RemoteEvents, codes de résultat |
| `Shared/Util/Localization` | Textes anglais et français par clé |
| `Controllers/InventoryController` (client) | Affichage du sac |
| `Controllers/CollectionController` (client) | Ciblage, entrées, retour visuel |

Branchement des événements Roblox : `Bootstrap.server.lua`.

## Flux d'une collecte

```text
Client : RequestCollect { resourceId = "green_leaf_001" }
Serveur (CollectionService.HandleRequest), dans cet ordre :
  1. limite de fréquence          -> RATE_LIMITED
  2. profil chargé                -> PROFILE_NOT_LOADED
  3. payload                      -> INVALID_TARGET
  4. nœud connu                   -> INVALID_TARGET
  5. nœud ACTIVE                  -> RESOURCE_UNAVAILABLE
  6. personnage présent et vivant -> NO_CHARACTER
  7. distance                     -> TOO_FAR
  8. trajet plausible             -> TOO_FAR
  9. cadence                      -> COOLDOWN
 10. capacité + ajout (un seul Update) -> INVENTORY_FULL
 11. consommation du nœud, réapparition programmée
Serveur : ActionResult { action, ok, code, resourceId, resourceType, amount }
          StateUpdated { inventory, collectIntervalSeconds, collectRangeStuds } (succès)
```

Le payload n'accepte que le champ `resourceId` (texte de 1 à 64
caractères). Tout autre champ fait refuser la demande entière. La quantité
vient de `ResourceConfig.collectAmount`. Aucun Coin n'est crédité (T3).

Les étapes 5 à 11 ne suspendent jamais le fil : deux joueurs ne peuvent pas
recevoir la même ressource. `INVENTORY_FULL` ne consomme pas la ressource.

## Paramètres (A-16)

Valeurs nominales, visibles du client :

| Paramètre | Source | Valeur |
|---|---|---|
| Portée de collecte | `GameConfig.Collection.baseRangeStuds` | 12 studs |
| Intervalle de collecte | `UpgradeConfig.Grabber.levels[n].value` | 0,75 s au niveau 1 |
| Capacité du sac | `UpgradeConfig.Backpack.levels[n].value` | 50 au niveau 1 |
| Quantité, réapparition | `ResourceConfig` | 1 unité ; 2 / 3 / 4 s |

Marges serveur, **hypothèses de départ** (`CollectionSecurityConfig`), à
mesurer sur appareils réels puis ajuster (T6, T7) :

| Paramètre | Valeur | Effet |
|---|---|---|
| `Distance.toleranceStuds` | 4 | Distance maximale acceptée : 12 + 4 = 16 studs (3D, HumanoidRootPart → centre de la ressource) |
| `Cooldown.jitterToleranceSeconds` | 0,1 s | Une demande peut arriver jusqu'à 0,1 s en avance |
| `Travel.speedFactor`, `slackStuds` | 2 ; 20 | Entre deux collectes réussies : distance ≤ 16 × 2 × temps + 20 studs |
| `RateLimits.Collect` | rafale 10, 5/s | Au-delà : `RATE_LIMITED` (cadence légitime maximale : 2,8/s) |
| `RateLimitFeedback` | 1 s ; 50 | Une réponse `RATE_LIMITED` par seconde au plus ; une ligne de journal tous les 50 rejets |
| `Payload.maxResourceIdLength` | 64 | Longueur maximale de l'identifiant |

Depuis T4, la portée de base est celle du Magnet du profil (12 studs au
niveau 0, `UpgradeConfig`), marge comprise ; voir `UPGRADES.md`.

Cadence : l'échéance suivante vaut `max(maintenant, échéance) + intervalle`.
Une demande en avance est acceptée mais ne décale pas l'échéance : la
cadence moyenne ne dépasse jamais l'intervalle nominal.

Aucun bannissement : les demandes anormales sont refusées et journalisées.

## Ressources partagées

- Un nœud = une ressource collectable une fois, pour tous les joueurs.
- États : `ACTIVE → COLLECTED → RESPAWNING → ACTIVE`. `COLLECTED` est
  l'instant de la collecte ; le nœud passe aussitôt en `RESPAWNING`.
- Identifiants attribués par le serveur, par type, dans l'ordre des noms
  des points de spawn : `green_leaf_001`, `wood_001`, `stone_001`...
- Un nœud collecté devient invisible (`Transparency = 1`,
  `CanQuery = false`, attribut `Available = false`) et réapparaît au même
  endroit après `respawnSeconds`.
- Points de spawn : Parts de `Workspace.ResourceSpawnPoints`, attribut
  `ResourceType`. Carte de test : `tools/studio/build_test_map.luau`
  (36 points : 16 feuilles, 12 bois, 8 pierres, selon `spawnWeight`).
- Modèles provisoires : sphère verte, cylindre brun, bloc gris.

## API d'inventaire

`InventoryService.new({ playerData })`, par `UserId` :

| Fonction | Rôle |
|---|---|
| `GetState(userId)` | `{ resources, used, capacity, free }` (copie) ou `nil` si profil non chargé |
| `GetCapacity(userId)`, `GetFreeSpace(userId)` | Raccourcis |
| `AddResource(userId, resourceId, amount)` | `{ ok, code, granted, state }`. Ajoute au plus l'espace libre. Codes : `NotLoaded`, `InvalidResource`, `InvalidAmount`, `InventoryFull`, `InternalError` |
| `InventoryService.describe(profile)` | État d'un profil (fonction pure) |
| `InventoryService.capacityForLevel(level)` | Capacité d'un niveau de Backpack |

- Stockage unique : `profile.inventory.resources`, modifié seulement par
  `PlayerDataService.Update` (lecture de l'espace libre et écriture dans
  la même mise à jour).
- Occupation = somme de toutes les quantités, y compris les ressources
  inconnues de `ResourceConfig` conservées par D-008 (décision A-25,
  D-012) : elles ne sont jamais supprimées, mais occupent de la place, si
  bien que le sac ne peut jamais dépasser sa capacité. `AddResource`
  refuse d'en ajouter (`InvalidResource`). À la vente, elles ne sont ni
  vendues ni supprimées (T3, D-014, `SELLING.md`).
- `AddResource` alimente `stats.totalResourcesCollected`.
- Aucune écriture DataStore par collecte : sauvegarde périodique et de
  sortie de T1, inchangées.
- Retrait : uniquement par la vente, dans la transaction de `SellService` (T3, `SELLING.md`).

## Client

- Cible : ressource disponible la plus proche à portée, recalculée 10 fois
  par seconde ; contour blanc et nom au-dessus.
- PC : touche E (maintenir pour enchaîner) ou clic sur la ressource.
- Mobile : bouton rond « Grab / Prendre » juste au-dessus du bouton de saut
  de Roblox, suivi par événements (A-35, T3 ; avant : à gauche du saut,
  dans la zone du stick sur un écran étroit)
  (maintenir pour enchaîner) ou toucher la ressource.
- Manette : bouton X.
- Sac : panneau en haut au centre, dans la bande de la barre Roblox
  (`IgnoreGuiInset`), 45 % de la largeur au plus (A-41) (occupation, barre, détail par
  ressource), message « +1 … » à chaque collecte, « Bag full! / Sac plein ! »
  et barre rouge quand il est plein.
- Une seule demande à la fois ; sans réponse après 1 s, une nouvelle
  demande est permise.
- Le client ne modifie jamais l'inventaire : il affiche `StateUpdated`.

## Limites connues

- Roblox laisse le client simuler son personnage : la position lue par le
  serveur peut être falsifiée. Le contrôle de trajet freine la
  téléportation entre deux collectes, pas un déplacement accéléré continu.
  Protection provisoire ; validation renforcée des déplacements en T6
  (A-26, D-012).
- Le contrôle de trajet ne connaît que la réapparition du personnage
  (`ResetTravelReference`). Toute téléportation légitime future (changement
  de monde) devra l'appeler.
- Chaque demande copie le profil (`GetData`), chaque collecte le copie et
  le valide (`Update`). Borné par la limite de fréquence ; à mesurer en T6.
- Quitter et revenir remet la cadence à zéro (sans gain : le retour prend
  plus longtemps que l'intervalle).
- Pas de son, pas d'animation du personnage ; interface minimale. Phase
  dédiée à l'expérience utilisateur (A-29, D-012).
- Barre du sac en pastille ronde à faible remplissage : reporté à la même
  phase (A-30).
- Variante « Tap » et variante « Hold » coexistent : choix du
  propriétaire de conserver les deux (A-28, D-012).
- Messages non traduits par les tables Roblox : `Localization` est une
  solution provisoire (T5).
