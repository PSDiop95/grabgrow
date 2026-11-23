# T10.4 — Validation complémentaire (T10-D01 à T10-D03)

Date : 2026-11-22 / 23. Branche `t10-3-guardians` (HEAD `2a20191`).
Complète `T10_4_FINAL_VALIDATION_REPORT.md` maintenant que la vente et la
consommation sacrées existent (T10.5a/b, D-037, D-038).
Statut proposé : **PARTIEL**. Aucune publication, aucune phase suivante.

## Environnement

- Lune (`tools/run_tests.luau`), MemoryDataStore, horloge simulée.
- Studio, **expérience de test dédiée** (universe 10775875517, place
  93404872714886), DataStore réel `GrabAndGrow_PlayerData_v1_Studio`, clé
  `Player_11975439775`, Play solo piloté par MCP (déplacements
  `Humanoid:MoveTo` et pathfinding, envois de remotes, lecture des
  réponses). « Déconnexion / reconnexion » = Stop puis Play (sauvegarde
  `BindToClose`, nouveau serveur, même `UserId`), relecture `GetAsync` entre
  deux sessions.
- `DataConfig.Studio.useMemoryStore` passé à `false` **dans le place
  seulement** pendant les tests, puis remis à `true` (dépôt jamais modifié).
- Aucune donnée de production touchée.

## Résultats par décision

### T10-D01 — Déblocage individuel et permanent (section A)

| Étape | Résultat | Preuve |
|---|---|---|
| Victoire du gardien | **OK (réel)** | Combat Forest complet, 50 s, 24 éclats, 5 touches ; `GuardianReward … first=true persistent=true` |
| Déblocage du sanctuaire | **OK (réel)** | `GetAsync` : `sanctuary_RootSanctuary=true`, schéma 3 |
| Déconnexion | **OK (réel)** | Stop ; `GetAsync` : `lastSaveAt` mis à jour, verrou de session vide |
| Reconnexion | **OK (réel)** | `profil chargé, lastSaveAt=1795386322, verrou précédent : aucun` |
| Accès conservé | **OK (réel)** | `Activate` → `SUCCESS` (combat lancé) |
| Nouvelle défaite | **OK (réel)** | Sortie d'arène → `ended left_arena`, deux fois |
| Accès toujours conservé | **OK (réel)** | `Activate` → `SUCCESS` après la défaite ; sessions 3 et 4 : `TOO_FAR` (accès accepté, seule la distance refuse) ; clé toujours présente |
| Lune | OK | `GuardianPersistenceTests` P1–P4 (23 cas) |

### T10-D02 — Combat individuel multijoueur (section B)

Local Server à 2 joueurs lancé par le propriétaire le 2026-11-23 (Player1
= -1, Player2 = -2, MemoryDataStore, `J_full`), piloté par MCP. S'y
ajoutent les résultats du Local Server T10.4 (§5) et les tests Lune :

| Point | Résultat |
|---|---|
| Combats simultanés | **OK (réel)** : c3 (P1, PV 16/24) et c4 (P2) actifs en même temps ; déjà M3 en T10.4 |
| Dégâts et PV indépendants | **OK (réel)** : P2 démarre à 24/24 pendant que P1 est à 16/24 ; déjà M4 |
| Arrivée pendant un combat | **OK (réel)** : P2 entre dans l'arène (12 studs du centre) pendant c3 ; 0 événement de combat reçu en 6 s ; combat de P1 poursuivi |
| Victoires, déblocages, récompenses indépendants | **OK (réel)** : `GuardianReward user=-2 combat=c4 first=true`, aucune ligne pour -1 ; déjà M5, M12 ; Lune P11 |
| Déconnexion pendant son combat (M8) | **OK (réel)** : `Kick` de P1 en combat (PV 16/24) → `sauvegarde (sortie) OK, verrou libéré`, aucune victoire ni récompense pour -1 ; combat de P2 non affecté, mené à la victoire 69 s plus tard ; Lune OK |
| Reconnexion | Solo sur DataStore réel : OK (section A). Multijoueur après M8 : **NOT TESTED** (en Local Server, un joueur ajouté reçoit un nouvel identifiant) ; Lune OK |
| Falsification des dégâts | OK (réel : `damage = 999`, argument en trop → `INVALID_TARGET`) |
| Récompense d'un autre joueur | OK (réel : éclats de P1 envoyés par P2 → `INVALID_TARGET` ; P2 sans victoire → `REQUIREMENT_NOT_MET`) ; Lune P13b |
| Modifier les PV du gardien | OK : aucun champ client accepté ; PV calculés serveur |

Tentative M8 en solo sur DataStore réel (Temple du soleil, site non
débloqué) : **non aboutie**. Mon harnais est resté bloqué contre les pierres
`ZoneE_Secret`, puis le personnage est mort. Ensuite, une attente infinie de
mon script (`CharacterAdded:Wait()`) a coupé la connexion MCP et Studio a
été relancé. Aucun résultat à consigner.

### T10-D03 — Ressources sacrées (section C)

| Étape | Résultat | Preuve |
|---|---|---|
| Collecte après victoire | **OK (réel)** | Terrasse : `SacredCollect SUCCESS`, +3 `sacred_heartwood_seed` ; autre nœud → `ALREADY_CLAIMED` |
| Reconnexion après collecte | **OK (réel)** | `GetAsync` : 3 unités, `sanctuary_reward_RootSanctuary=true` ; session 4 : `ALREADY_CLAIMED` à la terrasse |
| Capacité du sac | Lune OK (P14–P14d, « sac plein ») ; réel : sac vide, non saturé |
| Vente | **OK (réel)** | `SacredSell SUCCESS sold=3 coins=594` |
| Double vente | **OK (réel)** | 2e vente → `NOTHING_TO_SELL`, 0 Coin |
| Consommer une ressource vendue | **OK (réel)** | `SacredUpgrade sacred_magnet` → `INSUFFICIENT_RESOURCES` |
| Reconnexion après vente | **OK (réel)** | `GetAsync` : coins 594, `totalCoinsEarned` 594, `totalSales` 0 (D-038), plus d'unités |
| Consommation pour amélioration | **OK (réel)** | `S_sacred` puis `sacred_backpack` → `SUCCESS units=3`, capacité 700 → 770 |
| Double achat | **OK (réel)** | `MAX_LEVEL`, 0 unité consommée |
| Vendre une ressource consommée | **OK (réel)** | `SacredSell sacred_frost_heart` → `NOTHING_TO_SELL` |
| Payload falsifié | **OK (réel)** | `cost = 0`, `quantity = 99` → `INVALID_TARGET` |
| Ressources insuffisantes | OK (réel, ci-dessus) ; Lune |
| Reconnexion après amélioration | **OK (réel)** | `GetAsync` : `sacred_upgrade_sacred_backpack`, pas de `sacred_frost_heart` ; session 4 : rachat → `MAX_LEVEL`, revente → `NOTHING_TO_SELL` |
| Lune (nouveaux cas) | OK | « vendre après améliorer », « reconnexion après chaque étape » |

## Critères (section D)

| Interdit | État |
|---|---|
| Débloquer sans victoire valide | Tenu (réel : `REQUIREMENT_NOT_MET`, `WORLD_LOCKED` ; Lune) |
| Profiter de la victoire d'autrui | Tenu (réel M5, M6, M12 ; Lune P11, P13b) |
| Modifier les PV du gardien | Tenu (réel : `INVALID_TARGET`) |
| Récompense sans validation serveur | Tenu (réel : `SacredCollect` sans victoire, `amount = 99`) |
| Dépenser une ressource deux fois | Tenu (réel : `MAX_LEVEL`, `INSUFFICIENT_RESOURCES`) |
| Vendre une ressource consommée | Tenu (réel + Lune) |
| Consommer une ressource vendue | Tenu (réel + Lune) |

## Tests automatisés

| Test | Résultat |
|---|---|
| `lune run tools/run_tests.luau` | **OK** : 25 suites, `SacredTransactionTests` 20 cas (18 + 2) |
| Mêmes suites au démarrage du Play Studio | OK (`TOUS LES TESTS : OK`, 4 démarrages) |
| Contrôle négatif des 2 nouveaux cas | **NOT TESTED** |
| LSP, `rojo build` | Non relancés (seul un fichier de test a changé) |

## Observations

- **D-008 sur DataStore réel (R-01)** : au premier chargement, le profil de
  test ancien a été normalisé. La copie `Recovery_11975439775_1795386059`
  a été écrite avant la première sauvegarde. Le comportement n'avait
  jusque-là été vérifié qu'en simulation.
- `achievement world_2` (+1 000 Coins) et `coins_unexplained excess=1000` au
  chargement : effet du profil de test hérité, puis effacé par `J_full`.
  À surveiller, sans lien avec T10.
- Nombreux `unknown_id action=GuardianStrike` : renvois du harnais en plus
  de la saisie automatique du client (refus attendus).
- `sauvegarde (guardian_victory) OK` observée en Local Server (-2). En solo,
  l'extrait d'Output lu était filtré ; la clé était bien présente après Stop.
- **Bord de l'arène du Sanctuaire des racines** : sol jusqu'à environ 30
  studs du centre, vide au-delà de 34 studs (22 rayons sur 24 sans sol). Le
  rayon de l'arène est de 28 et le recul d'une touche de 18 studs. Un joueur
  touché près du bord pourrait donc tomber. Non observé en jeu : la mort de
  P1 pendant ce lot vient de mon harnais (positions d'éclats mal lues, marche
  vers (0, 0, 0)). La « chute de Player2 » de T10.4 (§5, scénario 6) a une
  cause probable identique, non confirmée.
- **Mesure du recul (2026-11-23, Studio solo, Root, A-7)** :
  - Profil des 4 arènes identique : sol plein jusqu'à 30 studs, vide au-delà
    de 34 studs (sauf la passerelle). Éclats à 20 studs au plus.
  - 6 touches mesurées : déplacement radial de **0 à 0,2 stud**.
  - Cause : le client pose bien la vitesse (23,6 studs/s à la 1re frame,
    `GuardianController.onHit`), mais l'Humanoid reste en état `Running`
    et l'annule en 3 frames. Seul un petit saut (≈ 1 stud) subsiste.
  - Conséquences : aucun risque de chute par recul **en l'état**, mais le
    recul de 18 studs prévu (`GuardianConfig.Combat.hit`) ne fonctionne pas.
    Le corriger tel quel recréerait le risque de chute près du bord : un
    correctif doit borner le recul pour rester dans le sol (≤ 30 studs).
  - Non mesuré : mobile, latence.
- **Correctif A-7 (D-040, 2026-11-23)** : recul appliqué par un
  `LinearVelocity` planaire pendant 0,45 s, borné par le serveur puis par le
  client à 24 studs du centre (`GuardianConfig.Combat.hit.maxRadiusStuds`).
  Mesure Studio, 5 touches dans 2 directions : recul de 12,8 à 18,1 studs,
  distance finale au centre de 25,8 studs au plus (sol jusqu'à 30), aucune
  alerte de déplacement. Avant resserrement (borne 28) : 29,8 studs, jugé
  trop près du bord.
- Le place de test a été relancé pendant le lot. `useMemoryStore` y était
  encore à `false` : remis à `true`. À vérifier : la version cloud du place
  a-t-elle été enregistrée avec `false` ?

## Restant avant clôture de T10.4

1. Reconnexion multijoueur réelle : demande deux clients sur un serveur
   publié de l'expérience de test (autorisation requise).
2. Mobile, Galaxy A23 (inchangé, A-2).
3. Recul (A-7) : corrigé (D-040) ; à vérifier sur mobile avec latence.
