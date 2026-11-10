# GRAB & GROW — Stratégie de tests

Dernière mise à jour : 2026-11-10

Règle : un test n'est « réussi » que s'il a été exécuté. Chaque rapport de
lot distingue tests automatisés, tests manuels et vérifications non faites.

## Niveaux de test

| Niveau | Objet | Moyen | Disponible aujourd'hui |
|---|---|---|---|
| 1. Analyse statique | Syntaxe, types `--!strict` | Script Analysis de Studio ; luau-lsp ou Luau CLI en terminal | Studio : oui (manuel). Terminal : non, outil absent |
| 2. Configurations | Cohérence structurelle et références croisées | `Tests/ConfigTests.lua` | Écrit, pas encore exécuté |
| 3. Logique serveur | Règles des services (collecte, vente, achat, migration) | Modules de test en Luau pur, dépendances simulées | À écrire avec chaque service |
| 4. Intégration | Remotes, validation, rate limit | Play dans Studio, Output | À partir de T2 |
| 5. Multijoueur | Isolation des données, double collecte | Studio : Test > Local Server, 2 joueurs ou plus | À partir de T2 |
| 6. Sauvegarde | Nouveau profil, reconnexion, échecs, migration | DataStore simulé injecté dans `PlayerDataService` ; puis place de test avec accès API | À partir de T1 |
| 7. Appareils | Lisibilité, tactile, performances | Émulateur d'appareils de Studio, puis téléphone réel | À partir de T5 |

## Lancer les tests automatisés

1. Synchroniser `src/` dans Studio.
2. Lancer Play (ou Run).
3. Lire Output : `[Tests] ConfigTests : OK` ou la liste des échecs.

`RunTests.server.lua` ne fait rien hors Studio.

## Principes d'écriture

- La logique métier ne dépend pas directement des API Roblox : le temps,
  le DataStore et les positions sont passés en paramètre, pour être
  remplacés dans les tests.
- Les tests de configuration vérifient la structure, pas les valeurs : ils
  ne recopient pas les tables de la Bible.
- La conformité des valeurs à la Bible se contrôle par comparaison avec le
  document à chaque modification d'une config.
- Tout test de sauvegarde utilise un DataStore de test, jamais la production.

## Couverture attendue par phase

| Phase | Cas obligatoires |
|---|---|
| T1 | Nouveau profil ; profil existant ; échec de chargement sans écrasement ; échec de sauvegarde ; reconnexion ; migration ; sauvegardes concurrentes |
| T2 | Collecte valide ; ressource inexistante ; trop loin ; trop rapide ; sac plein ; deux joueurs sur la même ressource |
| T3 | Vente normale ; inventaire vide ; hors zone ; inventaire intact si le crédit échoue |
| T4 | Solde suffisant ; solde insuffisant ; niveau maximum ; identifiant inconnu |
| T6 | Remote à cadence excessive ; arguments de type invalide ; valeurs falsifiées ; isolation entre joueurs |

## Limites de l'environnement

- Roblox Studio ne peut pas être piloté depuis le terminal : les tests des
  niveaux 4 à 7 sont exécutés par le propriétaire, qui en rapporte le
  résultat.
- Sans analyseur Luau en terminal, une erreur de syntaxe n'est détectée
  qu'à l'ouverture dans Studio.
- Les limites de requêtes et la latence réelles du DataStore ne sont pas
  reproduites par un DataStore simulé.
- L'émulateur d'appareils ne mesure pas les performances d'un vrai
  téléphone.
