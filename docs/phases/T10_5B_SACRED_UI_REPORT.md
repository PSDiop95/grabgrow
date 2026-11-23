# T10.5b — Interface des reliques sacrées (client)

Date : 2026-11-22 — Branche `t10-3-guardians`. Suite de T10.5a (D-037,
D-038). Statut : **fait en Studio solo** ; mobile et Local Server non
testés. Aucun commit ; place de test synchronisé par Rojo, non enregistré.

## Réalisé

- `Controllers/SacredShopSection` (nouveau) : section « Reliques sacrées »
  de la Boutique, entre les améliorations et les mondes. Une carte par
  monde, visible si le joueur a des unités ou l'amélioration ; boutons de
  48 px « Vendre {Coins} » et « Utiliser 3 » ; confirmation en deux appuis
  (3 s) ; « Actif » une fois acquise ; aide « Battez un gardien… » si
  aucune carte. Montants affichés = indication ; le toast de vente montre
  le montant renvoyé par le serveur.
- `Controllers/SacredCompassController` (nouveau) : jusqu'à 3 marqueurs
  (BillboardGui, pool fixe) sur les ressources Rare/Epic disponibles dans
  un rayon de 150 studs, recherche toutes les 0,5 s ; inactif sans
  l'amélioration. Paramètres : `SacredResourceConfig.Compass` (hypothèses).
- `UpgradeController` : construit et démarre la section ;
  `InventoryController` : `showWarningText`, champ `sacredUpgrades` ;
  `ClientBootstrap` : démarre la Boussole.
- `Localization` : 22 clés EN/FR (`shop.sacred`, `sacred.*`,
  `sacred_upgrade.*`) ; présence vérifiée par `GuardianTests`.
- `StudioTestPresets` : préréglage `S_sacred` (Studio seulement).

## Tests

| Test | Résultat |
|---|---|
| `lune run tools/run_tests.luau` | OK, 25 suites |
| LSP strict, `rojo build` | OK |
| Studio Play (solo, MemoryDataStore, `S_sacred`) : 4 cartes, textes FR, montants 594 / 2 604 / 17 520 / 83 976 | OK |
| Vente, revente (`NOTHING_TO_SELL`), achat après vente (`INSUFFICIENT_RESOURCES`), double achat (`MAX_LEVEL`), payload avec `quantity` (`INVALID_TARGET`), 3 achats | OK (remotes envoyés depuis le client, réponses et Output conformes, sauvegardes `sacred_sale` / `sacred_upgrade`) |
| Capacité après Sac sacré : 700 → 770 | OK (HUD) |
| Boussole : 1 marqueur « Cristal vert » à 140 studs | OK |
| Cartes « Actif », carte vendue masquée | OK (capture) |
| Clic réel et confirmation en deux appuis | **NOT TESTED** (remotes envoyés directement) |
| Mobile (taille des boutons, lisibilité), Galaxy A23, Local Server | **NOT TESTED** |

## Points à surveiller

- Portée et intervalle sacrés appliqués par le serveur (tests Lune) ; non
  mesurés en jeu.
- Coût de la Boussole (parcours des nœuds toutes les 0,5 s) non mesuré
  sur mobile.
- Analytics des actions sacrées non instrumentées (noms à valider).
