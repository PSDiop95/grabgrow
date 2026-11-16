# Catalogue des événements analytics — GRAB & GROW

Version : T9 (2026-11-16, D-024). Source de vérité des noms :
`src/ServerStorage/ServerOnlyConfig/AnalyticsConfig.lua`. Code :
`src/ServerScriptService/Services/AnalyticsService.lua` (règles),
`Systems/AnalyticsSinks.lua` (appels Roblox), branchement dans
`Bootstrap.server.lua`.

## Principes

- **Propriétaire unique :** `AnalyticsService` (serveur). Aucun RemoteEvent
  ne mène à l'analytics ; le client n'émet rien.
- **Déclencheur :** toujours après le résultat `ok` d'un service serveur
  (opération confirmée et appliquée au profil). Un refus n'émet rien, sauf
  `BackpackFull` (un par épisode).
- **Session :** ouverte au chargement réussi du profil (`onProfileLoaded`),
  fermée au départ (`onPlayerRemoving`). Sans session, aucun événement : un
  profil refusé ou corrompu ne produit rien.
- **Données :** le `Player` est transmis à Roblox (exigé par l'API) ; les
  champs ne contiennent ni UserId, ni nom, ni position, ni texte du joueur.
  Valeurs des champs : identifiants de `WorldConfig`, `ResourceConfig`
  (rareté), `UpgradeConfig`, `AchievementConfig`, niveaux numériques.
- **Échec :** chaque envoi est isolé (`pcall`), jamais rejoué ; au plus une
  ligne d'avertissement par méthode et par minute.
- **Désactivation :** `AnalyticsConfig.enabled = false` ; le jeu est
  identique (tests « analytics désactivé »).
- **Studio :** Roblox n'envoie rien depuis Studio. Par défaut
  (`Studio.sink = "log"`), chaque événement est écrit dans l'Output
  (`[Analytics] ...`) ; `"roblox"` fait les vrais appels (sans envoi).

## Funnel d'onboarding — `LogOnboardingFunnelStepEvent`

| Étape | Nom | Condition (état serveur du profil) |
|---|---|---|
| 1 | `JoinedGame` | Profil chargé sans aucune progression |
| 2 | `FirstCollection` | `stats.totalResourcesCollected > 0` |
| 3 | `FirstSale` | `stats.totalSales > 0` |
| 4 | `FirstUpgrade` | Une amélioration au-dessus de son niveau de départ |
| 5 | `FirstWorldUnlocked` | Au moins deux mondes débloqués |

Anti-doublon : l'étape envoyée est le **préfixe continu** des conditions
remplies ; elle avance seulement, une fois par session. Au chargement, un
joueur déjà avancé reprend à son niveau **sans envoi rétroactif**. Roblox ne
compte que la première occurrence d'une étape par joueur. Une étape n'est
jamais sautée : une amélioration achetée avant la première vente (Coins d'un
succès) n'envoie l'étape 4 qu'après l'étape 3 (Roblox complèterait sinon les
étapes précédentes d'office).

Écart assumé (D-024) : l'onboarding du jeu a 3 étapes (collecter, vendre,
améliorer) ; l'étape 5 mesure l'entrée dans la progression des mondes.

## Économie — `LogEconomyEvent` (monnaie `Coins`)

| Mouvement | Flux | Type de transaction | SKU | Déclencheur |
|---|---|---|---|---|
| Vente | `Source` | `Gameplay` | `Sale:<WorldId>` | `SellService` ok |
| Récompense de succès | `Source` | `Gameplay` | `Achievement:<id>` | `AchievementService.Evaluate` (chaque succès) |
| Amélioration | `Sink` | `Shop` | `Upgrade:<UpgradeId>` | `UpgradeService` ok |
| Déblocage de monde | `Sink` | `ContextualPurchase` | `World:<WorldId>` | `WorldUnlockService` ok, coût > 0 |

- Montant : toujours positif, celui de l'écriture `EconomyService`.
- Solde final : `balanceAfter` de l'écriture (`EconomyService.Entry`),
  exposé dans les résultats des services (D-024). Après un déblocage suivi
  d'un succès, chaque événement porte son propre solde.
- Une transaction confirmée = un événement. Aucune autre source ni dépense
  de Coins n'existe dans le jeu (les préréglages Studio ne sont pas mesurés).
- Monde de vente : préfixe `<WorldId>_` de `SellZoneId`, sinon `Unknown`.
- Cardinalité : 4 + 12 + 5 + 3 = 24 SKU (limite 100), 3 types (limite 20).

## Progression — `LogProgressionCompleteEvent`

| Parcours | Niveau | Nom du niveau | Déclencheur |
|---|---|---|---|
| `Worlds` | `WorldConfig.order` (2 à 4) | `WorldId` | Déblocage confirmé |

Le voyage n'est pas une progression : il est mesuré par `WorldEntered`.

## Événements personnalisés — `LogCustomEvent`

| Nom | Valeur | Champs (01, 02) | Déclencheur | Anti-doublon / volume |
|---|---|---|---|---|
| `SessionEnded` | Durée en s (`os.clock` serveur) | — | Départ du joueur | Une fois par session |
| `ResourcesCollected` | Unités collectées | Monde | Lot : toutes les 300 s, à chaque vente, au départ | Agrégé par joueur et par monde ; jamais un par collecte |
| `BackpackFull` | 1 | — | Collecte refusée `INVENTORY_FULL` | Un par épisode, réarmé par la vente |
| `WorldEntered` | 1 | Monde | Voyage confirmé (`WorldTravelService`) | Limité par la cadence de voyage (T8) |
| `JournalDiscovery` | 1 | Monde, rareté | Collecte avec `firstDiscovery` (journal v3) | Au plus 20 par joueur, à vie |
| `UpgradePurchased` | 1 | Amélioration, niveau | Achat confirmé | Un par achat |

6 noms (limite 100). `SessionStarted` n'est pas envoyé : le Creator
Dashboard compte déjà les sessions.

## Budget de fréquence

Limite Roblox (2026-11-16) : 120 + 20 × CCU requêtes par minute. Le service
vise la moitié, par serveur, en fenêtre d'une minute :

| Priorité | Événements | Plafond par minute |
|---|---|---|
| Basse | Personnalisés | 30 + 6 × joueurs |
| Haute | Économie, onboarding, progression, `SessionEnded` | 60 + 10 × joueurs |

Au-delà : l'événement est écarté (compteur `dropped`, une ligne
d'avertissement par minute), jamais mis en file.

## Non mesuré (volontairement)

- Funnel de boutique (ouverture, consultation) : purement client, aucune
  confirmation serveur possible (D-024).
- Collectes refusées autres que sac plein, requêtes invalides, sécurité :
  restent dans `SecurityLog`.
- Positions, chat, paramètres du joueur.
