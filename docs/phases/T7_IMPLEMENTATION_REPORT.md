# T7 — Rapport d'implémentation (étapes B et C)

Date : 2026-11-14. Décision : D-020. Statut : **validée et clôturée**
(propriétaire, 2026-11-14, après test réel). Commit et push autorisés le 2026-11-14.

## 1. Réalisé

| Élément | Fichiers |
|---|---|
| P0 : Backpack 2 à 75 Coins | `Shared/Config/UpgradeConfig.lua` ; préréglage U1 (`Systems/StudioTestPresets.lua`) |
| A-21 : temps de jeu serveur | `Systems/PlayTimeTracker.lua` (nouveau) ; `Services/PlayerDataService.lua` (dépendance `playClock`, ajout avant chaque écriture) ; `Shared/Config/DataConfig.lua` (`PlayTime`) ; `Bootstrap.server.lua` (`playClock = os.clock`) |
| Schéma v2 | `DataConfig.SchemaVersion = 2` ; `Systems/DataSchema.lua` (migration v1 -> v2, contrôle `achievements`) |
| P3 : succès permanents | `Shared/Config/AchievementConfig.lua`, `Shared/Util/AchievementRules.lua`, `Services/AchievementService.lua` (nouveaux) ; `Bootstrap.server.lua` (après chaque action validée et au chargement) ; `Shared/Remotes/Remotes.lua` (`Action.Achievement`) |
| Client | `Controllers/AchievementController.lua` (nouveau, bandeau dans `NotificationsUI`) ; `ClientBootstrap.client.lua` ; `Shared/Util/FeedbackRules.lua` (son) ; `Shared/Util/Localization.lua` (14 clés EN/FR) |
| Simulateur | `tools/simulate_progression.luau` (non mappé dans le jeu) |
| Audit | `Systems/ProfileAudit.lua` : commentaire seulement (récompenses incluses dans `totalCoinsEarned`) |

Sécurité T6 inchangée : aucun nouveau RemoteEvent client -> serveur ;
`MovementValidator`, `PayloadValidator`, limites de fréquence intacts.
Aucune monnaie nouvelle, aucun paiement.

## 2. Tests

| Test | Type | Résultat |
|---|---|---|
| Suite Lune (`lune run tools/run_tests.luau`) : 17 suites, dont `PlayTimeTests` (15 cas) et `AchievementTests` (16 cas), nouvelles | Automatisé | **OK** |
| Mutations volontaires (succès non marqué ; horloge du temps de jeu non avancée) | Automatisé, contrôle des tests | Détectées : 15 et 9 échecs ; code restauré, suite OK |
| `luau-lsp analyze` (sourcemap régénérée dans un dossier temporaire) | Automatisé | 0 erreur, code de sortie 0 |
| `rojo build` (fichier temporaire hors dépôt) | Automatisé | Réussi ; `GrabAndGrow.rbxl` non touché |
| Play Studio (place de test, magasin en mémoire) : 17 suites | Automatisé dans Studio | `TOUS LES TESTS : OK` |
| Play Studio : préréglage `O_sold_rich` (60 collectes), puis 40 collectes réelles (déplacement + `RequestCollect`) | Scénario Studio, script client | `collect_100` attribué une fois à la 100e collecte ; Coins 120 -> 170 ; journal serveur `motif Achievement:collect_100` ; bandeau « 🏆 Succès : 100 ressources collectées +50 Coins » affiché |

Couverture des cas demandés :
- **Temps de jeu :** sortie normale, sortie brutale (serveur perdu, verrou
  expiré), reconnexion, sessions multiples, sauvegarde et chargement,
  échec de sauvegarde, second serveur refusé, fermeture, serveur figé,
  pas de double comptage.
- **Économie :** Backpack 2 payable après un premier sac défavorable
  (`ConfigTests`) ; succès attribués une seule fois ; atomicité en cas de
  dépassement ; deux joueurs isolés ; audit T6 sans incohérence.
- **Migration :** v1 -> v2 sans perte (toutes les sections comparées),
  valeurs invalides refusées, profil v1 chargé puis évalué.
- **Régression :** collecte, inventaire, vente, améliorations, mondes,
  persistance, sécurité T6 (suites existantes, toutes OK).

## 3. Non vérifié

- Temps de jeu dans Studio : seulement par tests automatisés (le profil
  en mémoire n'est pas lisible hors du service).
- Bandeau des succès sur téléphone réel, tablette et manette ; capture
  Studio non faite (bandeau de 3 s).
- DataStore réel (Studio) : migration v1 -> v2 et copie `Recovery_` non
  exécutées sur un vrai DataStore.
- Local Server à 2 joueurs avec les succès.
- Progression réelle : aucune mesure de joueur (test privé T8).

## 4. Risques résiduels

| # | Risque | Suite |
|---|---|---|
| A-36 | Plateau structurel après 2 à 4 h en Green Valley ; réduit, pas résolu | Contenu de Golden Desert (après le MVP) |
| R-T7-1 | Serveurs v1 encore actifs à la publication : profils v2 refusés | Redémarrer tous les serveurs à la publication |
| R-T7-2 | Succès attribués au chargement d'un profil déjà avancé (rétroactifs) | **Confirmé** par le propriétaire le 2026-11-14 ; profils de test seulement |
| R-T7-3 | Une copie `Recovery_` par profil migré (D-008) | Volume à surveiller ; profils de test seulement |
| R-T7-4 | Évaluation des succès à chaque collecte : une copie du profil en plus | Mesurer en test multi-joueurs |
| R-T7-5 | Inactivité comptée jusqu'à l'expulsion Roblox (≈ 20 min) | Acceptable pour le MVP |
| R-T7-6 | Récompenses et coût de Backpack 2 : hypothèses | Mesurer en T8 |
