# T10.5a — Vente et améliorations sacrées (serveur)

Date : 2026-11-22 — Branche `t10-3-guardians`. Décisions : D-037 (R-1,
U-A), D-038 (valeurs S2, effets, `totalSales`). Statut : **serveur fait ;
interface client faite en T10.5b** (`T10_5B_SACRED_UI_REPORT.md`). Aucun commit, place non modifié.

## Réalisé

- `SacredResourceConfig` : `sellValue` (198 / 868 / 5 840 / 27 992) et
  table `Upgrades` (4 améliorations à un niveau, coût 3 unités du monde).
- `Shared/Util/SacredUpgradeRules` (nouveau, pur) : clé U-A, possession,
  effets sur capacité, portée et intervalle.
- `SacredTransactionService` (nouveau) : `HandleSell { resourceId }` vend
  toutes les unités de la ressource ; `HandleUpgrade { upgradeId }`. Une
  mutation `PlayerDataService.Update` par opération ; refus sans
  modification ; sauvegarde demandée après succès.
- Effets appliqués côté serveur : `InventoryService.describe` (capacité),
  `CollectionService` (portée de validation, intervalle, état client
  `sacredUpgrades`).
- `Remotes` : `RequestSacredSell`, `RequestSacredUpgrade`, actions
  `SacredSell` / `SacredUpgrade`, code `INSUFFICIENT_RESOURCES`.
  Fréquence : `GuardianSecurityConfig.RateLimits` (3 en rafale, 1 / 2 s).
- `Bootstrap` : branchement, `ActionResult`, état renvoyé, nettoyage.

## Écarts à la proposition

- Pas de condition de proximité pour la vente : action de menu, comme
  `UpgradeService` ; valeur décidée par le serveur, offre unique.
- Multiplier non appliqué à la vente sacrée (valeur fixe S2).
- Analytics non instrumentées (nouveaux noms d'événements à valider dans
  `AnalyticsConfig`, D-024).

## Tests

| Test | Résultat |
|---|---|
| `lune run tools/run_tests.luau` | **OK** : 25 suites, dont `SacredTransactionTests` (18 cas) |
| Contrôle des tests : garde de double achat désactivée volontairement | 3 échecs détectés, code restauré |
| `luau-lsp analyze` strict | OK, aucune erreur |
| `rojo build` (fichier temporaire) | OK |
| Studio, Local Server, mobile, DataStore réel | **NOT TESTED** |

Couverture G : vente, consommation, double vente, double achat, ressources
insuffisantes, sac plein, deux joueurs, reconnexion, sauvegarde en échec à
la déconnexion, payload falsifié, fréquence, profil non chargé.

## Points à surveiller

- Sans interface, les actions ne sont accessibles qu'en envoyant les
  remotes (Studio) : T10.5b requis (boutons vente / achat, textes EN/FR
  `sacred_upgrade.*`, `INSUFFICIENT_RESOURCES`, affichage de la boussole).
- Boussole : possession persistée, effet d'affichage non implémenté.
- Gains réels (Magnet, Grabber, Sac) non mesurés ; valeurs = hypothèses.
- Clés `sacred_upgrade_*` ignorées par `AchievementService`,
  `ProfileAudit` et analytics par construction (identifiants inconnus) ;
  pas de test dédié équivalent à P10.
