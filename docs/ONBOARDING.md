# Guidage de première session (T5.3)

Date : 2026-11-13. Statut : implémenté ; tests automatisés, Studio et
émulateur (propriétaire) OK ; D-10 acceptée (D-017).

Principe : montrer → faire essayer → confirmer → laisser jouer. Le guidage
est un système d'interface : il ne crédite rien, n'achète rien, ne déplace
pas le joueur et ne bloque aucune action.

## Étapes

| État | Affichage | Repère | Passe à l'étape suivante quand |
|---|---|---|---|
| `INTRO` | 👋 « Bienvenue dans Grab & Grow ! » + « Collecte des ressources, vends-les et améliore ton équipement. » | — | 5 s après le chargement du jeu et l'apparition du personnage, ou appui sur × |
| `COLLECT` (1/3) | « Collecte tes premières ressources ! » + contrôle de l'appareil | ▼ au-dessus de la ressource disponible la plus proche | `ActionResult` Collect `ok`, `SUCCESS`, `amount > 0` |
| `SELL` (2/3) | Sous 10 unités : « Bien joué ! Continue de remplir ton sac. » ; à partir de 10 (ou sac plein si capacité < 10) : « Ton sac se remplit. Vends tes ressources ! » | Ressource, puis ▼ au-dessus du stand | `ActionResult` Sell `ok`, `SUCCESS`, `coinsEarned > 0` (vente avant le seuil reconnue) |
| `UPGRADE` (3/3) | Après la vente : 💰 « Belle vente ! +N Coins » (3 s, N = `coinsEarned` du serveur). Puis, sans amélioration payable : « Collecte et vends : encore N Coins… » ; payable : « Utilise tes Coins pour améliorer ton équipement ! » | ▶ à côté du bouton Boutique ; boutique ouverte : ▶ sur **chaque** carte payable (aucune imposée), carte de guidage masquée | `ActionResult` Upgrade `ok`, `SUCCESS` (ou UnlockWorld) |
| `COMPLETED` | 🎉 « Sac à dos niveau 2 ! À toi de jouer : prends, vends, améliore. » (6 s). Le gain (« Sac 50 → 75 ») est affiché par le toast existant de la Boutique | — | Fin : plus rien n'est affiché |

Hors champ, une flèche → au bord de l'écran pointe vers la cible. Le repère
s'efface à portée (collecte : portée du Magnet ; vente : 10 studs) : la
surbrillance de collecte et le prompt de vente prennent le relais.

## Validation et intégrité

- Étape déduite de l'état serveur (`StateUpdated`) : `progress` =
  copie en lecture seule de `profile.stats` :
  `totalResourcesCollected`, `totalSales`, `totalCoinsSpent`.
  | Condition | Étape |
  |---|---|
  | `coinsSpent > 0` ou une amélioration au-dessus de son niveau de départ | `COMPLETED` |
  | `sales > 0` | `UPGRADE` |
  | `resourcesCollected > 0` | `SELL` |
  | sinon | `COLLECT` (précédé de `INTRO` dans la session) |
- Une étape n'avance que sur une réponse serveur positive ; une demande
  cliente, un refus (`INVENTORY_FULL`, `NOTHING_TO_SELL`,
  `INSUFFICIENT_FUNDS`, `TOO_FAR`…) ou une réponse incohérente ne change
  rien.
- L'étape ne recule jamais (maximum) ; un événement n'est signalé que s'il
  fait avancer l'étape : un doublon ne valide rien deux fois.
- Aucun RemoteEvent ajouté, aucune requête envoyée par le guidage.

## Persistance

Aucun champ de profil ajouté, aucune migration (D-2 = b). Les statistiques
existantes sont déjà sauvegardées : après une déconnexion, l'étape est
recalculée au chargement. Un joueur avancé ne revoit pas les étapes
passées ; un joueur qui a acheté ne voit plus rien.

Limite assumée : un joueur qui n'a **rien collecté** revoit l'accueil à sa
prochaine connexion (c'est encore un nouveau joueur). L'état « masqué »
n'est pas mémorisé (session).

Diagnostic : à la première réception de l'état, le client écrit
`[Onboarding] étape de départ : <étape> (collectes n, ventes n, Coins
dépensés n)` dans la console développeur (`/console`). `COMPLETED` = joueur
déjà avancé, guidage volontairement masqué.

**Changement serveur (D-10, acceptée : D-017)** : `CollectionService.
GetClientState` ajoute `progress` à l'état client. Lecture seule, rien ne
le relit côté serveur ; nécessaire car les statistiques n'étaient pas
envoyées au client. Écart avec D-016 (« T5 client seulement »).

## Interface

- Carte compacte en haut à gauche, sous la barre Roblox (`TopbarInset`),
  200–300 px de large, rétrécie ou placée sous le sac si elle le toucherait.
  Hors des zones du stick, du saut, de « Prendre », de la Boutique et du
  prompt de vente.
- × (40 × 40) : masque la carte jusqu'à l'étape suivante ; bouton « ? Guide »
  pour la réafficher. Sur l'accueil, × passe à l'étape 1.
- Aucune fenêtre modale ; la boutique ouverte recouvre la carte (ordre 4 < 6).
- Glyphes vérifiés dans Studio : × ▶ ▼ → et emoji ; ✕ ➤ ✔ s'affichent mal.

## Contrôles affichés

| Étape | Tactile | Clavier / souris | Manette |
|---|---|---|---|
| Collecte | Touche une ressource ou maintiens Prendre | Maintiens E ou clique sur une ressource | Maintiens X près d'une ressource |
| Vente | Va au stand et touche Vendre | Va au stand et appuie sur F | Va au stand et appuie sur Y |
| Boutique | Touche Boutique | Appuie sur B ou clique sur Boutique | Appuie sur la croix haut |

Appareil déduit du dernier type d'entrée (`LastInputTypeChanged`). Les
noms X / Y suivent la disposition Xbox (sur PlayStation : carré /
triangle). Manette **non testée sur matériel**.

## Fichiers

| Fichier | Rôle |
|---|---|
| `Shared/Config/OnboardingConfig.lua` | Seuil de vente (10), durées, rafraîchissement (hypothèses) |
| `Shared/Util/OnboardingRules.lua` | Logique pure : états, déduction, réponses serveur, indications, masquage, appareil |
| `Controllers/OnboardingController.lua` | Carte, repères, flèches ; aucune autorité |
| `Services/CollectionService.lua` | `progress` dans l'état client (D-10) |
| `Shared/Util/Localization.lua` | Clés `onboarding.*` EN/FR |
| `Systems/StudioTestPresets.lua` | Préréglages `O_collected`, `O_sold`, `O_sold_rich`, `O_upgraded` (Studio) |
| `Tests/OnboardingTests.lua` | 21 cas |

## Textes

Tutoiement, comme demandé pour T5.3 ; le reste de l'interface FR vouvoie
(« Vendez au stand ! ») : à harmoniser en T5.4.
