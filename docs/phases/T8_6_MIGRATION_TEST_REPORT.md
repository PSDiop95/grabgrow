# T8.6 — Rapport de test de la migration v2 -> v3

Date : 2026-11-16. Décision : D-022. Statuts : PASS, PARTIAL, FAIL, NOT TESTED.

## Périmètre

Migration du profil joueur du schéma v2 (T7 à T8.5) vers le schéma v3
(section `collection.discoveredResources`). Détails du schéma et des règles :
`../DATA_PERSISTENCE.md`, section « v2 -> v3 ».

Aucun test n'a utilisé le DataStore de production
(`GrabAndGrow_PlayerData_v1`).

## 1. Tests automatisés (magasin en mémoire)

Suites `CollectionJournalTests` (35 cas) et `DataSchemaTests` (22 cas),
exécutées par Lune (`lune run tools/run_tests.luau`) et au démarrage du
Play Studio. Résultat : 20 suites, `TOUS LES TESTS : OK` (Lune et Studio).

| Cas | Résultat |
|---|---|
| Profil v2 valide : journal vide, toutes les sections identiques (monnaies, inventaire avec ressource inconnue, améliorations, mondes, statistiques, succès, réglages, `lastSaveAt`, clé inconnue de premier niveau), aucune réparation, entrée non modifiée | PASS |
| Profil v3 valide : inchangé, aucune réparation | PASS |
| Profil neuf : v3 directement, journal vide, tables non partagées | PASS |
| Migration répétée (étape rejouée sur un profil migré ; `normalize` appliqué deux fois) : idempotente | PASS |
| v2 contenant déjà une section `collection` : conservée ; sous-section ajoutée si absente | PASS |
| D-022 D3 : inventaire v2 non converti en découvertes, quantités inchangées | PASS |
| v1 -> v3 enchaînées (`DataSchemaTests`) | PASS |
| Profil corrompu (9 formes : `collection` texte, booléen ; `discoveredResources` nombre ; valeur `false`, nombre ; clé numérique, vide, trop longue ; monnaie texte) : refus `CorruptData`, jamais réparé | PASS |
| Profil v3 incomplet (`collection` ou sous-section absente) : ajoutée et signalée ; `validate` strict refuse | PASS |
| Version future (v4) : `UnsupportedVersion` | PASS |
| Chargement v2 : migré en mémoire, original intact dans le magasin, aucune copie immédiate | PASS |
| Sauvegarde après migration : copie `Recovery_<UserId>_<heure>` = profil v2 d'origine, puis profil v3 conforme écrit | PASS |
| Conflit `Recovery_` (clé occupée par une autre copie) : `BackupFailed` à la sauvegarde et à la sortie, copie existante intacte, original v2 intact, verrou libéré | PASS |
| Écriture de la copie impossible : sauvegarde bloquée, original intact ; reprise après rétablissement | PASS |
| Profil v2 corrompu au chargement : refus, rien écrit, aucun verrou, aucune copie | PASS |
| Verrou de session actif sur un profil v2 : `SessionLocked`, profil et verrou d'autrui intacts | PASS |
| Reconnexion après migration : découverte, inventaire et Coins conservés ; pas de seconde copie ; pas de redécouverte | PASS |

Contrôle négatif : une migration modifiée pour reconstituer l'historique
depuis l'inventaire fait échouer 4 cas (code restauré ensuite).

## 2. DataStore de test réel

Environnement : Studio, place « Test de prise et de croissance »
(PlaceId 93404872714886, expérience de test dédiée), Play à un joueur,
script serveur via MCP. Magasin : `GrabAndGrow_PlayerData_v1_Studio`
(`DataConfig.Store.studioName`). Le script vérifiait `RunService:IsStudio()`,
le `PlaceId` de test et le suffixe `_Studio` avant tout appel. Clés de test :
`Player_<UserId négatif>`, jamais un joueur réel. Services réels
(`PlayerDataService`, `InventoryService`) branchés sur ce magasin ; deux
« serveurs » successifs (identifiants distincts) pour la reconnexion.

| Cas | Clé | Résultat |
|---|---|---|
| Profil v2 riche (123 456 Coins, Backpack 10, quatre mondes, ressources des quatre mondes, succès, réglage) : chargement | `Player_-86001` | PASS : `profil normalisé en mémoire uniquement ; original conservé` ; magasin toujours en v2 après le chargement |
| Découverte après migration (`ice_shard`) puis seconde collecte | `Player_-86001` | PASS : `firstDiscovery` true puis false |
| Sauvegarde : copie de récupération puis v3 | `Player_-86001` | PASS : `copie de récupération écrite : Recovery_-86001_1794820488` ; copie `PreNormalizationBackup`, `sourceKey = Player_-86001`, profil v2 sans `collection`, 123 456 Coins |
| Sortie puis reconnexion sur un second service | `Player_-86001` | PASS : v3, 123 456 Coins, `ice_shard` 4, `mystic_core` 1, Backpack 10, Mystic World débloqué, 120 ventes, succès et réglage conservés, 1 découverte ; verrou libéré à la fin |
| Profil v3 existant (2 découvertes) | `Player_-86002` | PASS : inchangé après chargement, sortie et reconnexion |
| Nouveau profil | `Player_-86003` | PASS : créé en v3, journal vide, rechargé en v3 |
| Conflit `Recovery_` : clé exacte occupée par une autre copie entre chargement et sauvegarde | `Player_-86007` | PASS : `sauvegarde bloquée, copie de récupération impossible (D-008)` à la sauvegarde et à la sortie (`BackupFailed`) ; original v2 intact (888 Coins) ; copie existante intacte ; verrou libéré |
| Verrou actif d'une autre session sur un profil v2 | `Player_-86005` | PASS : 6 tentatives (≈ 28 s) puis `SessionLocked` ; profil v2 et verrou d'autrui intacts |
| Profil v2 corrompu (`collection = 42`) | `Player_-86006` | PASS : `CorruptData` ; profil inchangé, aucun verrou posé |

Premier essai du conflit (`Player_-86004`) : préparation erronée (clés
occupées pour les mauvaises secondes) ; la migration s'est déroulée
normalement. Non compté ; refait avec la clé exacte (`Player_-86007`).

Données laissées dans le magasin de test : clés `Player_-86001` à
`Player_-86007` et leurs copies `Recovery_`. `Player_-86005` porte un verrou
fictif (`autre-serveur:1`) posé pour 600 s : expiré 10 minutes après le
test.
Aucune n'appartient à un joueur réel.

## 3. Non testé

| Élément | Statut | Raison |
|---|---|---|
| Profil v2 d'un joueur réel issu de la production | NOT TESTED | Interdit (aucun accès production) ; le jeu n'est pas publié |
| Deux serveurs v2 et v3 actifs en même temps | NOT TESTED | Studio : une session par place (`RCC-276`) ; couvert par la règle de redémarrage de tous les serveurs |
| Quotas et latence DataStore sous charge | NOT TESTED | Hors de portée de Studio |

## Conclusion

Migration v2 -> v3 : PASS en mémoire et sur le DataStore de test réel. Aucune
perte, aucune duplication, aucune écriture sur un profil refusé ou verrouillé,
aucune copie de récupération écrasée.
