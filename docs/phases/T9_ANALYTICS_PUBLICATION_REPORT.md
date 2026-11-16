# T9 — Analytics et préparation à la publication : rapport

Date : 2026-11-16. Décision : D-024. Statut : **VALIDÉE avec réserves** par
le propriétaire le 2026-11-16 (« Valider en l'état »). Réserves : onboarding, progression `Worlds`, dépense `World:*`, succès, `WorldEntered` et `BackpackFull` non observés dans Roblox (validés en Lune et Studio) ; Local Server analytics non testé ; correctif T9-UI-01 non contrôlé sur téléphone.
Cette validation n'autorise ni publication publique ni monétisation.

## A. Résumé exécutif

- **État initial :** aucune instrumentation ; T8.0 à T8.7 validées ; T8
  clôturée formellement par le propriétaire avec réserves (D1, 2026-11-16).
- **Travail réalisé :** audit (T9-A, validé avec D1 à D5) ; service
  analytics centralisé et instrumentation serveur ; 28 tests ; catalogue,
  KPI, rapport de tests ; checklist et plan de publication.
- **État final :** instrumentation opérationnelle et vérifiée en Studio
  solo ; aucune valeur économique, aucun schéma, aucun réglage d'expérience
  modifié ; aucune publication.

## B. Architecture analytics

| Fichier | Rôle |
|---|---|
| `ServerStorage/ServerOnlyConfig/AnalyticsConfig.lua` | Noms stables, budget, intervalles, mode Studio, interrupteur |
| `ServerScriptService/Services/AnalyticsService.lua` | Règles : sessions, validation, anti-doublon, onboarding, agrégation, budget, isolation des erreurs. Aucune API Roblox |
| `ServerScriptService/Systems/AnalyticsSinks.lua` | Seuls appels Roblox (`LogCustomEvent`, `LogEconomyEvent`, `LogOnboardingFunnelStepEvent`, `LogProgressionCompleteEvent`) ; sink `log` et `off` |
| `Bootstrap.server.lua` | Appels après `result.ok` ; double `pcall` (`track`) ; tâche des lots de collecte |
| `SellService`, `UpgradeService`, `WorldUnlockService`, `AchievementService` | Ajout additif de `balanceAfter` aux résultats (D3) |

Services intégrés (via Bootstrap) : collecte, vente, améliorations,
déblocage, voyage, succès, journal (`firstDiscovery`), cycle de session.
Catalogue : `docs/analytics/ANALYTICS_EVENT_CATALOG.md`.

Règles anti-doublon : session unique par joueur ; étapes d'onboarding par
préfixe d'état persistant, sans rétroactivité ; un événement économique
par transaction confirmée ; sac plein par épisode ; collectes par lots.
Erreurs : `pcall` par envoi, aucune nouvelle tentative, journal limité ;
plafond de débit avec priorité ; désactivation par configuration.

## C. Résultats analytics

| Événement | Code | Studio (sink log) | Roblox (Dashboard) |
|---|---|---|---|
| Onboarding 1 à 4 | Oui | Observés | NOT TESTED |
| Onboarding 5 | Oui | Non déclenché (préréglage, attendu) ; Lune PASS | NOT TESTED |
| Économie Source (vente, succès) | Oui | Observés, soldes exacts | NOT TESTED |
| Économie Sink (amélioration, monde) | Oui | Observés, soldes exacts | NOT TESTED |
| Progression `Worlds` | Oui | Observé | NOT TESTED |
| Custom (6 noms) | Oui | Tous observés | NOT TESTED |

Vrais appels Roblox en Studio : acceptés sans erreur (« event fired »),
mais Roblox n'envoie rien depuis Studio. **Aucun événement n'est déclaré
validé dans Roblox.**

Limites techniques : Studio n'envoie pas d'événements ; délai d'environ
24 h pour les graphiques ; fin de session perdue si le serveur plante ;
collecte mesurée par monde, pas par ressource ; temps jusqu'au déblocage
non agrégé par Roblox.

## D. Tests

| Test | Résultat | Preuve |
|---|---|---|
| Lune | PASS | 21 suites, 429 cas OK |
| LSP strict | PASS | `luau-lsp analyze` : sortie 0 |
| Rojo build | PASS | Place construit |
| Studio solo | PASS | Parcours complet par les remotes, Output vérifié |
| Studio multijoueur | NOT TESTED | Procédure pour le propriétaire (`ANALYTICS_TEST_REPORT.md`) |
| Analytics Roblox | PARTIAL | Reçus dans « Voir les événements » (expérience privée) : économie (ventes, amélioration) et 4 événements personnalisés, conformes, sans doublon ; onboarding, progression et autres non encore observés |
| Non-régression économique | PASS | Suites existantes OK ; cas « panne sans effet » |

Détail : `docs/analytics/ANALYTICS_TEST_REPORT.md`.

## E. Publication readiness

Synthèse (`docs/publication/PUBLICATION_READINESS_CHECKLIST.md`) :
identité et visuels BLOCKED (non produits) ; classification BLOCKED
(propriétaire) ; configuration de l'expérience NOT TESTED ; compatibilité
PARTIAL (tablette réelle, manette, performance) ; sécurité, données,
licences, dépendances PASS. Plan : `docs/publication/RELEASE_PLAN.md`.

## E bis. Anomalie corrigée pendant T9 (retour du propriétaire, mobile)

- **T9-UI-01** : sur téléphone, le bouton « Journal » (placé à gauche de
  « Boutique » quand il n'y a pas de place dessous) s'affichait par-dessus
  le panneau des améliorations ouvert. Correction :
  `CollectionJournalController` masque le bouton tant que `ShopPanel` est
  visible et le réaffiche à la fermeture. Vérifié en Studio (Play, client) :
  visible → masqué boutique ouverte → visible après fermeture ; Lune et LSP
  OK. Contrôle sur téléphone réel : à faire après republication.

## F. Risques résiduels

- Le budget de débit est une hypothèse de prudence (50 % de la limite
  documentée) ; la limite s'applique peut-être à l'univers entier et non au
  serveur (documentation imprécise).
- Les noms d'événements sont figés par le Dashboard : un renommage casse
  l'historique.
- Documentation Roblox contradictoire sur le nombre de monnaies (5 ou 10) :
  sans effet (une seule monnaie).
- `GetData` copie le profil : lu seulement tant que le funnel n'est pas
  terminé (coût nul ensuite).
- Réserves antérieures inchangées : performance mobile, contrôle visuel
  mobile, tablette réelle, manette, R-01.

## G. Git

Branche `main`, à jour avec `origin/main` avant T9. Aucun commit, aucun
push. Fichiers : voir le compte rendu de lot.
