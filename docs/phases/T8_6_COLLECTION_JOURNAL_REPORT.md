# T8.6 — Collection Journal : rapport d'implémentation

Date : 2026-11-16. Décision : D-022 (réouverture de D-021 D6).
Étape A validée par le propriétaire le 2026-11-16 (D1 à D7). Statut :
**construit, testé et validé par le propriétaire le 2026-11-16.**
Statuts des tests : PASS, PARTIAL, FAIL, NOT TESTED.

## 1. Architecture

```text
Client                               Serveur
------                               -------
RequestCollect { resourceId }  --->  CollectionService.HandleRequest
                                       (refus T6/T8 inchangés)
                                     InventoryService.AddResource
                                       PlayerDataService.Update (atomique)
                                         inventaire += quantité
                                         stats.totalResourcesCollected
                                         CollectionJournalRules.markDiscovered
ActionResult { ..., firstDiscovery } <---
StateUpdated { ..., discovered }     <---  CollectionService.GetClientState
                                             (CollectionJournalRules.publicView)
CollectionJournalController (affichage)
AchievementController (bandeau « Nouvelle découverte »)
```

- `Shared/Util/CollectionJournalRules` (nouveau, logique pure partagée) :
  catalogue dérivé de `ResourceConfig.worldId` et `WorldConfig.order`
  (mondes dans l'ordre, ressources par rareté puis valeur), résumé par
  monde et global, pourcentage entier arrondi vers le bas, marquage serveur,
  vue client filtrée. Aucune liste de ressources dupliquée.
- Pas de `CollectionJournalService` (D-022 D4) : le marquage doit vivre
  dans la mutation de l'ajout ; un service n'aurait fait qu'envelopper
  trois fonctions.
- Aucun RemoteEvent ajouté (D-022 D5). Le client n'a aucune requête liée au
  journal : il ne peut ni déclarer, ni modifier, ni réinitialiser une
  découverte, ni lire le journal d'un autre joueur (`FireClient` au seul
  joueur concerné).
- Aucune récompense, aucune valeur économique, condition de déblocage,
  protection T6 ou carte modifiée.

## 2. Schéma v3

```lua
collection = {
    discoveredResources = { green_leaf = true, wood = true },
}
```

Un booléen `true` par ressource découverte ; totaux, pourcentages et
catalogue jamais stockés. Taille : 41 octets (vide) à 404 octets (20/20) en
JSON. Contrôle, migration, récupération : `../DATA_PERSISTENCE.md`.

## 3. Migration v2 -> v3

`DataSchema.Migrations[2]` : ajoute `collection = { discoveredResources = {} }`
sans toucher au reste ; conserve une section déjà présente ; idempotente.
Journal vide après migration (D-022 D3). Copie `Recovery_` D-008 avant la
première sauvegarde. Rapport : `T8_6_MIGRATION_TEST_REPORT.md`.

## 4. Fichiers

Créés :

- `src/ReplicatedStorage/Shared/Util/CollectionJournalRules.lua`
- `src/StarterPlayer/StarterPlayerScripts/Controllers/CollectionJournalController.lua`
- `src/ServerScriptService/Tests/CollectionJournalTests.lua`
- `docs/phases/T8_6_COLLECTION_JOURNAL_REPORT.md`,
  `docs/phases/T8_6_MIGRATION_TEST_REPORT.md`, `docs/phases/T8_6_captures/`

Modifiés :

| Fichier | Changement |
|---|---|
| `Shared/Config/DataConfig.lua` | `SchemaVersion = 3` |
| `Systems/DataSchema.lua` | Migration v2 -> v3, profil par défaut, contrôle de `collection` |
| `Services/InventoryService.lua` | Marquage dans le mutateur d'`AddResource` ; `AddResult.firstDiscovery` |
| `Services/CollectionService.lua` | `Result.firstDiscovery` ; `ClientState.discovered` |
| `Bootstrap.server.lua` | `firstDiscovery` dans `ActionResult` (Collect) |
| `Shared/Remotes/Remotes.lua` | Commentaires des payloads |
| `Systems/StudioTestPresets.lua` | Champ `discovered` ; `J_partial`, `J_full`, `J_world4` ; `reset` vide le journal |
| `Shared/Util/Localization.lua` | Clés `journal.*` et `rarity.*` (EN, FR) |
| `Controllers/AchievementController.lua` | Bandeau de découverte dans la file existante, couleur propre |
| `Controllers/UpgradeController.lua` | `UpgradeController.close()` |
| `Controllers/InventoryController.lua` | Type `State.discovered` |
| `ClientBootstrap.client.lua` | Démarrage du Journal |
| `Tests/RunTests.server.lua` | Suite `CollectionJournalTests` |
| `Tests/DataSchemaTests.lua`, `Tests/AchievementTests.lua` | Attentes v2 -> v3 |
| `Tests/LocalizationTests.lua` | Longueurs `journal.open`, `rarity.*` ; mots identiques EN/FR |
| `docs/decisions/TECHNICAL_DECISIONS.md` | D-022 ; renvoi dans D-021 D6 |
| `docs/DATA_PERSISTENCE.md`, `docs/ROADMAP.md`, `docs/PROJECT_STATUS.md`, `docs/tests/TEST_STRATEGY.md` | Schéma v3, état T8.6, statut réel de T8.5 |

Non touchés : `GrabAndGrow.rbxl`, configurations économiques, cartes,
`MovementValidator` et configurations de sécurité.

## 5. Découverte

- Découverte = première attribution confirmée par le serveur, dans le même
  `Update` que l'ajout au sac. Une mutation annulée (sac plein, erreur,
  profil invalide) n'attribue ni ressource ni découverte.
- Refus avant l'ajout (limite de fréquence, payload, nœud inconnu, monde
  verrouillé, nœud indisponible, distance, déplacement, cadence) : aucune
  découverte.
- Ressource inconnue de `ResourceConfig` : refusée par `AddResource`, jamais
  ajoutée au journal.
- Vente, retrait, consommation : la découverte reste (historique).
- Aucune écriture DataStore supplémentaire.

## 6. Interface (FR / EN)

| Clé | EN | FR |
|---|---|---|
| `journal.open` | Journal | Journal |
| `journal.title` | Collection Journal | Journal de collection |
| `journal.total` | {discovered} / {total} discovered — {percent}% | {discovered} / {total} découvertes — {percent} % |
| `journal.world_progress` | {discovered} / {total} — {percent}% | {discovered} / {total} — {percent} % |
| `journal.unknown` | Unknown | Inconnue |
| `journal.locked` | World locked | Monde verrouillé |
| `journal.back` | Back | Retour |
| `journal.value` | {value} Coins | {value} Coins |
| `journal.new_discovery` | New discovery: {name}! | Nouvelle découverte : {name} ! |
| `rarity.*` | Common, Uncommon, Rare, Epic | Commune, Peu commune, Rare, Épique |

- Bouton « Journal » (96 × 52 px) sous la Boutique, ou à sa gauche si la
  place manque (bouton « Prendre » sur mobile) ; touche J ; croix bas à la
  manette ; B : retour puis fermeture.
- Vue principale : total global, 4 cartes (couleur du monde, nom, barre,
  « 3 / 5 — 60 % », « Monde verrouillé »). Vue d'un monde : 5 entrées ;
  découverte = vignette de la couleur de la ressource, bord de la couleur de
  rareté, nom, rareté, valeur ; inconnue = silhouette grise, « Inconnue »,
  rien d'autre.
- Panneau calé sur celui de la Boutique (même cadre, évite le sac) ; un seul
  des deux ouvert. Rendu seulement panneau ouvert ; vignettes 2D, aucun
  modèle 3D.

Captures (Studio, fr-fr, PC 1020 × 512) : `T8_6_captures/`

1. `01_journal_vide_fr.jpg` : nouveau joueur, 0 / 20, trois mondes verrouillés.
2. `02_bandeau_decouverte_fr.jpg` : « Nouvelle découverte : Pierre ! ».
3. `03_detail_green_valley_apres_vente_fr.jpg` : 3 / 5 après une vente (sac 0).
4. `04_J_partial_fr.jpg` : 4 / 20, barres par monde, Golden Desert débloqué.
5. `05_J_full_mystic_world_fr.jpg` : 20 / 20, raretés Commune à Épique.
6. `06_local_server_player1_fr.jpg` : Local Server, Player1 à 2 / 20 avec le
   bandeau « Nouvelle découverte : Bois ! ».

Anglais : textes vérifiés par Lune ; aucune capture (Studio n'expose pas le
changement de `LocaleId` au MCP).

## 7. Tests automatisés

| Test | Résultat |
|---|---|
| Lune : 20 suites, dont `CollectionJournalTests` (35 cas) | PASS |
| Studio (Play) : mêmes 20 suites au démarrage | PASS |
| `luau-lsp analyze` (strict, sourcemap temporaire hors dépôt) | PASS (code 0, 0 erreur) |
| `rojo build` (fichier temporaire hors dépôt) | PASS |
| Contrôle négatif : marquage retiré (22 échecs), historique reconstitué (4), découverte marquée avant les contrôles de collecte (détectée) ; code restauré | PASS |

## 8. Tests Studio (Play, un joueur, magasin en mémoire)

| Scénario | Résultat |
|---|---|
| Journal d'un nouveau joueur : 0 / 20, mondes 2 à 4 « Monde verrouillé » | PASS |
| Collecte à pied d'une feuille : `SUCCESS`, `firstDiscovery = true` | PASS |
| Seconde feuille : `SUCCESS`, `firstDiscovery = false` | PASS |
| Payload `{ resourceId, discovered = true }` : `INVALID_TARGET`, `[Security] invalid_payload extra_field` | PASS |
| `sandstone_009` (Golden Desert verrouillé) : `WORLD_LOCKED`, aucune découverte | PASS |
| Nœud hors de portée : `TOO_FAR`, `firstDiscovery = false` | PASS |
| Bandeau « Nouvelle découverte : Pierre ! » ; aucun son ajouté | PASS |
| Vente (+9) : sac 0, découvertes `green_leaf, stone, wood` conservées | PASS |
| Vue Green Valley 3 / 5 — 60 %, 2 entrées « Inconnue » | PASS |
| `J_partial` appliqué panneau ouvert : mise à jour immédiate (4 / 20) | PASS |
| `J_full` : 20 / 20, Mystic World 5 / 5, raretés et valeurs | PASS |
| B ouvre la Boutique et ferme le Journal ; J fait l'inverse ; panneaux au même cadre (230, 40) | PASS |
| Croix bas ouvre ; ButtonB ferme (touches émulées, sans manette réelle) | PARTIAL |
| Navigation manette dans les cartes (sélection), écran tactile, téléphone réel | NOT TESTED |

## 9. DataStore de test

Voir `T8_6_MIGRATION_TEST_REPORT.md` : v2, v3, profil neuf, sauvegarde,
sortie, reconnexion, conflit `Recovery_`, verrou actif, profil corrompu sur
`GrabAndGrow_PlayerData_v1_Studio` (expérience de test). PASS.

## 10. Sécurité

| Cas | Résultat |
|---|---|
| Client qui déclare une découverte (champ `discovered` ou `firstDiscovery` dans la collecte, argument supplémentaire) | PASS : `INVALID_TARGET`, rien n'est marqué (Lune et Studio) |
| Client qui modifie une entrée ou le pourcentage | PASS par construction : aucune requête n'existe ; l'état client est une copie (modifier la copie ne change pas le profil, Lune) |
| Consultation du profil d'un autre joueur | PASS par construction : `StateUpdated` envoyé au seul joueur ; journaux indépendants (Lune) |
| Spam (40 demandes) | PASS : `RATE_LIMITED`, aucune découverte |
| Profil absent, session inactive | PASS : `PROFILE_NOT_LOADED`, aucun état |
| `Update` avec journal invalide (valeur `false`, section supprimée) | PASS : refusé, profil inchangé |

## 11. Multijoueur

| Cas | Résultat |
|---|---|
| Deux joueurs, même ressource, nœuds distincts : deux premières découvertes indépendantes | PASS (Lune) |
| Deux joueurs, même nœud : un seul obtient ressource et découverte | PASS (Lune) |
| Journaux non partagés, états clients séparés | PASS (Lune) |
| Cohérence après reconnexion | PASS (Lune et DataStore de test) |
| Local Server à 2 joueurs (section suivante) | PASS |

### Test Local Server (2 joueurs, 2026-11-16)

Lancé par le propriétaire, piloté par MCP. Magasin en mémoire. Player1
(UserId -1), Player2 (UserId -2).

| Cas | Résultat |
|---|---|
| Démarrage serveur | PASS : 20 suites, `TOUS LES TESTS : OK` |
| Feuille collectée par chacun (nœuds distincts, moments différents) | PASS : `firstDiscovery` true pour chacun |
| Même nœud `wood_004`, demandes à 1 ms d'écart | PASS : Player2 `SUCCESS`, first=true ; Player1 `RESOURCE_UNAVAILABLE`, first=false, aucune découverte |
| Journaux séparés (touche J) | PASS : Player1 « 1 / 20 découvertes — 5 % », Green Valley 1/5 ; Player2 « 2 / 20 — 10 % », 2/5 |
| Player1 collecte `wood_004` après réapparition | PASS : `SUCCESS`, first=true, bandeau « Nouvelle découverte : Bois ! », 2 / 20 (capture 06) |
| Sauvegardes automatiques | PASS pour les deux joueurs, aucune erreur du jeu |

Erreurs d'assets préexistantes (203785492, 81504106) sans rapport.
Non testé : reconnexion du même joueur (un nouveau joueur reçoit un autre
UserId ; couverte par Lune et le DataStore de test), latence réelle.

## 12. Performance

| Domaine | Impact |
|---|---|
| DataStore | Aucune écriture ajoutée |
| Taille du profil | +41 à +404 octets (JSON) |
| Chargement | Une étape de migration, contrôle de 20 entrées au plus |
| Serveur, par collecte | Une lecture et une affectation dans la mutation existante ; copie et validation du profil : 20 clés de plus au plus |
| Réseau | `StateUpdated` : +380 octets au plus (20/20), un envoi par action réussie comme avant |
| Client | Résumé O(20), seulement panneau ouvert ; 4 cartes et 5 entrées créées une fois ; aucun modèle 3D |

Non mesuré : temps serveur réel, mémoire, appareil mobile.

## 13. Risques résiduels

1. Après publication de la v3, un serveur v2 encore actif expulse les joueurs
   migrés (`UnsupportedVersion`, rien d'écrasé) : redémarrer tous les
   serveurs.
2. Les profils v2 repartent d'un journal vide (D-022 D3).
3. Placement tactile du bouton (à gauche de la Boutique quand « Prendre »
   est dessous) non vérifié sur téléphone ni émulateur.
4. Croix bas : avec une sélection manette dans le panneau, elle navigue au
   lieu de fermer (B ferme) ; non vérifié avec une vraie manette.
5. La 5e entrée d'un monde demande un défilement en 1020 × 512.
6. « 1 Coins » (valeur de la Feuille) : pluriel invariable, comme le HUD.

## 14. Écarts par rapport au périmètre

- `UpgradeController` reçoit une fonction `close()` (exclusion des panneaux,
  annoncée à l'étape A).
- Le bandeau de découverte réutilise la file de `AchievementController` au
  lieu d'un nouvel élément.
- « ??? » remplacé par « Inconnue » / « Unknown » : « ??? » est contraire à la
  règle de ponctuation française du projet (espace insécable).
- `journal.total` abrégé (« 3 / 20 découvertes — 15 % ») pour respecter la
  limite de 48 caractères des textes mobiles.

## 15. État de préparation

Construit ; tests automatisés, Studio à un joueur, DataStore de test et
Local Server à 2 joueurs : PASS. Reste, si souhaité : vérification tactile
et manette réelle. Validée par le propriétaire le 2026-11-16 ; commit
autorisé (local, sans push).
T8.7 non commencée.
