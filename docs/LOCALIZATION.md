# Textes et localisation (T5.4)

Date : 2026-11-13. Module unique : `Shared/Util/Localization.lua` (D-4 :
pas de migration vers LocalizationService). Langues : `en` (défaut,
repli) et `fr`, choisies d'après `Player.LocaleId` (`fr-fr`, `fr-ca`… →
`fr` ; autre langue → `en`).

## Règles d'écriture

| Règle | Détail |
|---|---|
| Clés | Toute clé existe en EN **et** en FR ; aucun texte affiché en dur (hors symboles × ▶ ▼ →, touches `[E]`, `[B]`, chiffres) |
| Motifs | `%d` (`Localization.format`) et `{nom}` (`Localization.fill`), identiques dans les deux langues |
| Français | Vouvoiement partout (« Vendez au stand ! ») ; accents obligatoires, y compris sur les majuscules (« Étape ») |
| Ponctuation FR | Espace avant `! ? : ;` écrite comme une espace normale dans la table ; remplacée au chargement par une espace insécable (`Localization.NBSP`) pour que la ponctuation ne passe jamais seule à la ligne |
| Ponctuation EN | Aucune espace avant `! ? : ;` |
| Apostrophes | Droites (`'`) dans les deux langues, pour l'homogénéité |
| Noms propres | Mondes (« Green Valley »…), « Coins », « Guide », « MAX » : identiques en EN et FR |
| Unités | `unit.seconds`, `unit.studs`, `unit.speed`, `unit.multiplier` ; nombre décimal à virgule en FR (`UpgradeController.formatNumber`) |
| Messages système | Expulsions (`system.kick.*`) traduites côté serveur avec la langue du joueur (A-22) |

## Longueurs maximales (caractères)

Hypothèses calibrées pour un téléphone en paysage, vérifiées par
`LocalizationTests` :

| Usage | Clés | Max |
|---|---|---|
| Boutons, pastilles | `collect.action`, `sell.action`, `sell.station`, `shop.open`, `shop.close`, `shop.max`, `settings.on/off`, `onboarding.show` | 10 |
| Bouton de déblocage | `world.unlock` | 12 |
| Noms | `resource.*`, noms de mondes | 16 |
| HUD | `hud.*` | 20 |
| Unités | `unit.*` | 16 |
| Contrôles du guidage | `onboarding.ctrl.*` | 44 |
| Carte du guidage | `onboarding.*` | 80 |
| Expulsion | `system.*` | 160 |
| Autres (toasts, boutique) | — | 48 |

## Ajouter un texte

1. Ajouter la clé dans `en` puis dans `fr` (même motif).
2. Si la clé est construite par le code (`<nom>.gain`, `onboarding.ctrl.*`,
   unités, expulsions), l'ajouter à « clés construites par le code » dans
   `Tests/LocalizationTests.lua`.
3. Si le texte est volontairement identique dans les deux langues,
   l'ajouter à `SAME_IN_BOTH`.
4. `lune run tools/run_tests.luau`.
