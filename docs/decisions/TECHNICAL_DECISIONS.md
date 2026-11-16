# GRAB & GROW — Décisions techniques

Journal des décisions. Statuts : PROPOSÉE (attend la validation du
propriétaire), ACCEPTÉE, REMPLACÉE.

---

## D-001 — Code source sur disque, synchronisé vers Studio par Rojo

- **Date :** 2026-11-10
- **Statut :** ACCEPTÉE (Prompt 1.1)
- **Contexte :** le dépôt ne contient aucun fichier Roblox. Claude Code
  travaille sur des fichiers ; Roblox Studio travaille sur un fichier place.
  Sans passerelle, chaque script doit être recopié à la main dans Studio.
- **Décision :** les scripts vivent dans `src/`, en miroir de l'Explorer
  (`src/ReplicatedStorage/...`, `src/ServerScriptService/...`).
  `default.project.json` décrit le mappage. Rojo synchronise vers Studio.
  La carte, les modèles et les interfaces restent édités dans Studio.
- **Justification :** historique Git lisible, revue et tests possibles hors
  Studio, pas de recopie manuelle. Rojo est un outil de développement : il
  n'ajoute rien au jeu publié.
- **Mise en œuvre :** Rokit 1.2.0 gère les outils ; versions épinglées dans
  `rokit.toml` (Rojo 7.7.1, luau-lsp 1.70.1). Plugin Studio `Rojo.rbxm`
  7.7.1 dans `%LOCALAPPDATA%\Roblox\Plugins`. Fichier place initial
  `GrabAndGrow.rbxl` produit par `rojo build`.
- **Conséquences :** le mappage ne
  cible que `Shared` et `Tests` : les instances créées dans Studio ne sont
  pas écrasées. Chaque nouveau dossier de scripts devra être ajouté au
  fichier projet.
- **Alternative :** copie manuelle dans Studio. L'arborescence `src/` reste
  valable ; `default.project.json` devient inutile.
- **Affecte :** tout le flux de développement, `docs/tests/TEST_STRATEGY.md`.

## D-002 — Noms de modules et de scripts de l'architecture technique

- **Date :** 2026-11-10
- **Statut :** ACCEPTÉE (demande explicite du propriétaire dans le Prompt 1)
- **Contexte :** le GDD et la Bible nomment `EconomyConfig`,
  `ResourcesConfig`, `UpgradesConfig`, `WorldsConfig`, `Main.server.lua`,
  `SellingService`. L'architecture et CLAUDE.md nomment `GameConfig`,
  `ResourceConfig`, `UpgradeConfig`, `WorldConfig`, `Bootstrap.server.lua`.
- **Décision :** noms de l'architecture technique. Extension `.lua`.
- **Justification :** le Prompt 1 liste ces quatre modules ; c'est la
  décision la plus récente du propriétaire.
- **Conséquences :** les arborescences du GDD (15.4) et de la Bible (16)
  sont indicatives et non suivies à la lettre.
- **Affecte :** `src/ReplicatedStorage/Shared/Config/`.

## D-003 — Contenu des configurations du MVP

- **Date :** 2026-11-10
- **Statut :** ACCEPTÉE (Prompt 1.1)
- **Contexte :** le MVP impose trois ressources et deux améliorations ; la
  Bible en définit cinq et cinq.
- **Décision :**
  - Ressources : `green_leaf`, `wood`, `stone` (les trois communes de la
    Bible 3.2, valeurs et poids inchangés). `wood` désigne « Wood Chunk ».
  - Améliorations : `Backpack` et `Grabber`, tables complètes de la Bible
    (16 et 10 niveaux).
  - Mondes : `GreenValley` (jouable) et `GoldenDesert` (verrouillé, 1 500
    Coins et Backpack niveau 5, Bible 6). `GoldenDesert` n'existe que pour
    tester le verrouillage et le déblocage : aucun contenu.
  - Achats d'amélioration : x1 uniquement dans le MVP. x10, x100 et MAX
    (Bible 5.7) sont reportés.
  - `GameConfig` ne contient que les paramètres globaux qui ne figurent
    dans aucune autre table (monde de départ, monnaie Coins, portée de base
    12 studs, vitesse de base 16). La capacité initiale et l'intervalle de
    base se lisent dans `UpgradeConfig` (niveau 1).
  - `respawnSeconds` (2 / 3 / 4 s) et `collectAmount` (1) viennent de
    l'exemple de l'architecture : hypothèses provisoires, consignées dans
    la Bible 3.6, à ajuster en T7.
  - Les configurations sont gelées (`TableUtil.deepFreeze`).
- **Justification :** une seule source par valeur ; aucune valeur inventée ;
  les trois ressources retenues sont celles de l'exemple de l'architecture.
- **Conséquences :** valeur moyenne par unité de 1,78 au lieu de 2,24 (voir
  `PROJECT_STATUS.md`, A-02). Les identifiants de ressources seront
  persistés à partir de T1 : les renommer ensuite exigera une migration.
- **Affecte :** les quatre modules `Config`, l'équilibrage T7.

## D-004 — Phasage T0 à T8 pour le MVP

- **Date :** 2026-11-10
- **Statut :** ACCEPTÉE (CLAUDE.md, sections 5 et 21)
- **Contexte :** le calendrier du GDD place Pets, événements et monétisation
  avant ou avec la sauvegarde. CLAUDE.md et l'architecture reportent ces
  systèmes après la validation du MVP.
- **Décision :** suivre T0 à T8 de l'architecture. La sauvegarde (T1)
  précède la collecte.
- **Justification :** CLAUDE.md exprime la décision du propriétaire et
  prime ; construire la boucle sur un profil déjà persistant évite de
  réécrire les services.
- **Conséquences :** `docs/ROADMAP.md` suit T0 à T8. La section 20 du GDD
  devrait être alignée lors d'une prochaine révision.
- **Affecte :** `docs/ROADMAP.md`, GDD section 20.

## D-005 — Tests sans framework externe pour l'instant

- **Date :** 2026-11-10
- **Statut :** ACCEPTÉE (stratégie utilisée pour clôturer T0)
- **Contexte :** aucun outil de test Luau n'est installé. CLAUDE.md interdit
  les dépendances non justifiées.
- **Décision :** modules de test en Luau pur, retournant une liste d'échecs,
  lancés dans Studio par `RunTests.server.lua` (inactif hors Studio). Les
  services seront écrits pour que leur logique soit testable sans API
  Roblox (dépendances passées en paramètre).
- **Justification :** zéro dépendance, suffisant pour un développeur solo.
- **Conséquences :** pas de rapport formaté ni d'intégration continue. À
  réévaluer si le nombre de tests le justifie.
- **Affecte :** `src/ServerScriptService/Tests/`, `docs/tests/TEST_STRATEGY.md`.

## D-006 — Schéma des données joueur : monnaies groupées, Magnet à 0

- **Date :** 2026-11-10
- **Statut :** ACCEPTÉE (Prompt 1.1) — à implémenter en T1
- **Contexte :** le GDD (15.5) stocke `coins`, `gems`, `stars` à plat et
  démarre `magnetLevel` à 1 ; l'architecture (7.1) utilise
  `currencies = { coins, gems, stars }` et `magnetLevel = 0`.
- **Décision :** structure de l'architecture.
  `currencies = { coins = 0, gems = 0, stars = 0 }`. `magnetLevel = 0`
  tant que l'amélioration n'est pas acquise.
- **Justification :** une seule table à valider et à migrer pour les
  soldes ; le niveau 0 distingue « non acquis » de « niveau 1 ».
- **Conséquences :**
  - Gems et Stars existent dans le profil mais restent à 0 et invisibles
    dans le MVP.
  - `GameConfig.Collection.baseRangeStuds` (12) est la portée à
    `magnetLevel = 0`.
  - La table Magnet de la Bible (5.4) démarre au niveau 1 gratuit à
    12 studs : à réaligner sur le niveau 0 quand le Magnet sera
    implémenté (hors MVP).
  - La section 15.5 du GDD est remplacée par ce schéma.
- **Affecte :** `PlayerDataService` (T1), GDD 15.5, Bible 5.4.

## D-007 — Correction des moyennes de la Bible économique

- **Date :** 2026-11-10
- **Statut :** ACCEPTÉE (Prompt 1.1)
- **Contexte :** les valeurs moyennes par monde annoncées ne correspondaient
  pas aux poids et valeurs unitaires du même document.
- **Décision :** moyennes recalculées (moyenne pondérée par les poids) :
  Green Valley 2,24 ; Golden Desert 20,42 ; Frozen Peaks 105,1 ;
  Mystic World 562. Ajout de la moyenne MVP à trois ressources (1,78).
  Bible passée en 1.0.1.
- **Justification :** les simulations doivent partir de chiffres cohérents.
- **Conséquences :** aucune valeur unitaire, aucun poids, aucun coût
  modifié. Les fourchettes de revenu cible par minute (4.2) sont
  inchangées et restent à confronter aux mesures en T7.
- **Affecte :** Bible économique 3.2, 3.6, 4.2, 20.

## D-008 — Règles d'intégrité des profils chargés

- **Date :** 2026-11-11
- **Statut :** ACCEPTÉE (validation du propriétaire, 2026-11-11) ;
  décision définitive validée sur la base de l'implémentation et des tests
  automatisés. Vérification de la copie `Recovery_` sur DataStore réel :
  à faire (`PROJECT_STATUS.md`, R-01).
- **Termes validés :** profil corrompu = joueur bloqué ; données originales
  jamais écrasées ni réparées automatiquement ; données conservées pour une
  récupération manuelle ; erreurs journalisées.
- **Décision définitive (propriétaire, 2026-11-11, après le commit
  e90f709) :**
  - Profil corrompu ou incohérent : blocage, aucune réparation
    automatique, original intact.
  - Profil lisible nécessitant une normalisation : corrections en mémoire
    autorisées, aucune réécriture immédiate de l'original.
  - Avant toute sauvegarde d'un profil normalisé, une copie récupérable de
    l'original est préservée. Si elle ne peut pas l'être, la sauvegarde de
    ce profil est bloquée et le problème journalisé.
  - Les migrations de schéma explicitement définies et testées suivront
    une procédure dédiée (à définir avec la première migration réelle).
- **Mise en œuvre :**
  - Au chargement, seul le verrou est écrit ; `profile` reste l'original.
  - Profil normalisé = au moins une correction, ou `schemaVersion`
    différent de celui du serveur. En attendant la procédure dédiée, une
    migration déclenche aussi la copie.
  - Copie dans le même DataStore, clé `Recovery_<UserId>_<heure Unix du
    chargement>` : `{ kind, userId, sourceKey, capturedAt,
    serverSchemaVersion, repairs, originalProfile }`. Écrite par
    `UpdateAsync` seulement si la clé est vide ; une copie existante
    différente n'est jamais écrasée (et bloque la sauvegarde).
  - Copie impossible : sauvegarde refusée (`BackupFailed`), données gardées
    en mémoire, nouvel essai à la sauvegarde suivante. À la sortie : le
    verrou est libéré sans toucher au profil ; les modifications de la
    session sont perdues, l'original reste.
  - La copie n'est écrite qu'une fois par session.
- **Décision connexe (validée le 2026-11-11) :** les `UserId` négatifs sont
  acceptés. Ils n'existent que dans les serveurs de test de Studio
  (Test > Local Server : -1, -2...), qui sinon expulseraient chaque joueur.
  `0`, les décimaux et les valeurs infinies restent refusés.
- **Contexte :** l'architecture (7.4) demande à la fois de remplacer les
  valeurs invalides par des valeurs sûres et de ne jamais écraser
  silencieusement une sauvegarde illisible. Le schéma contient en outre
  Magnet, Boots et Multiplier, absents de `UpgradeConfig` (hors MVP).
- **Décision initiale (règles de contrôle, inchangées) :**
  - Champ ou section manquant : valeur par défaut ajoutée (en mémoire).
  - Nombre hors bornes (niveau, solde négatif, décimale) : borné (en
    mémoire).
  - Type incorrect, NaN, structure illisible : profil refusé
    (`CorruptData`), rien n'est écrit, le joueur est expulsé.
  - Version future : refus (`UnsupportedVersion`).
  - Clés inconnues, dont les ressources absentes de `ResourceConfig` :
    conservées.
  - Toute réparation est journalisée.
  - Bornes des niveaux hors MVP : 10, d'après la Bible 5.4 à 5.6, dans
    `DataConfig.NonMvpUpgradeMaxLevels`. Backpack et Grabber restent bornés
    par `UpgradeConfig`.
  - Niveaux initiaux comparés aux configurations et à la Bible : identiques
    au schéma D-006, aucune valeur modifiée.
- **Justification :** une valeur bornée reste plausible ; une valeur de
  mauvais type signale un défaut de code ou une édition manuelle, qu'une
  réparation automatique masquerait en détruisant l'original.
- **Conséquences :** un joueur au profil corrompu est bloqué jusqu'à
  correction manuelle. Une panne limitée aux écritures de copie empêche la
  sauvegarde des profils normalisés concernés (perte possible de leur
  session, jamais de l'original). Les copies `Recovery_` ne sont jamais
  supprimées automatiquement : purge manuelle à prévoir. Le nombre de niveaux hors MVP est écrit à deux
  endroits (Bible et `DataConfig`) : à ramener dans `UpgradeConfig` quand
  ces améliorations seront implémentées.
- **Affecte :** `DataSchema`, `DataConfig`, `docs/DATA_PERSISTENCE.md`.

## D-009 — Persistance : verrou de session, magasin injectable, Lune

- **Date :** 2026-11-11
- **Statut :** ACCEPTÉE (validation du propriétaire, 2026-11-11 ; Lune
  validé pendant T1)
- **Termes validés :** expiration du verrou après 180 s en cas de crash ;
  renouvellement pendant une session active ; vérification de propriété
  avant chaque sauvegarde et libération ; aucune reprise tant que le verrou
  est valide.
- **Contexte :** T1 doit protéger un profil contre deux serveurs
  simultanés et se tester sans DataStore réel. Aucun moteur Luau n'était
  disponible en terminal : les tests ne tournaient que dans Studio, lancés
  à la main.
- **Décision :**
  - Aucune bibliothèque externe (ProfileStore, etc.) : service maison,
    limité au besoin du MVP.
  - Valeur stockée `{ profile, session }` ; lecture et écriture uniquement
    par `UpdateAsync` ; verrou de 180 s renouvelé à chaque sauvegarde
    (60 s) ; un verrou valide n'est jamais remplacé.
  - `PlayerDataService.new(dépendances)` : magasin, horloge, attente et
    identifiant de serveur injectés. API par `UserId`, pas par `Player`.
  - `GetData` retourne une copie ; `Update` est la seule voie de
    modification et valide le résultat contre le schéma.
  - Studio : magasin en mémoire par défaut, sinon DataStore
    `GrabAndGrow_PlayerData_v1_Studio`. Jamais le DataStore de production.
  - Lune 0.11.1 (via Rokit) exécute les tests en terminal avec
    `tools/run_tests.luau`, qui simule `game`, `script` et `require`.
- **Justification :** la sécurité des données prime ; un service court et
  testé est plus simple à maîtriser pour un développeur seul qu'une
  dépendance. Lune rend les tests exécutables sans action manuelle.
- **Conséquences :** un joueur attend jusqu'à 180 s après un crash serveur.
  Lune est un outil de développement, absent du jeu. D-005 reste valable
  (pas de framework de test) ; sa limite « tests uniquement dans Studio »
  est levée pour la logique pure.
- **Affecte :** `PlayerDataService`, `Bootstrap`, `rokit.toml`,
  `tools/run_tests.luau`, `docs/tests/TEST_STRATEGY.md`.

## D-010 — Sécurité de la collecte : distance, cadence, limite de fréquence

- **Date :** 2026-11-11
- **Statut :** ACCEPTÉE comme hypothèses de départ (propriétaire,
  2026-11-11, voir D-012, A-27) ; valeurs définitives après mesure sur
  mobile avec latence réelle
- **Contexte :** A-16. La Bible fixe la portée (12 studs) et l'intervalle
  de collecte (Grabber, 0,75 s au niveau 1), mais ni la marge de distance
  serveur, ni la tolérance de cadence, ni la limite des RemoteEvents.
- **Décision :**
  - Marges dans `ServerStorage/ServerOnlyConfig/CollectionSecurityConfig`,
    jamais répliquées. Les valeurs nominales restent dans `GameConfig` et
    `UpgradeConfig` (une seule source).
  - Distance acceptée : portée nominale + 4 studs, en 3D, depuis la
    position du personnage vue par le serveur. Le Magnet n'intervient pas.
  - Cadence : intervalle du Grabber du profil serveur ; avance tolérée de
    0,1 s ; échéance suivante = `max(maintenant, échéance) + intervalle`.
  - Trajet entre deux collectes réussies : au plus vitesse de référence
    × 2 × temps + 20 studs. Remis à zéro à la réapparition du personnage.
  - Limite de fréquence : seau à jetons par joueur, rafale 10, 5/s.
    `RateLimitService` est créé maintenant car la collecte en a besoin.
  - Payload : table avec le seul champ `resourceId` ; tout autre champ
    fait refuser la demande.
  - Aucun bannissement : refus, journal limité.
  - Code de résultat ajouté à la liste de l'architecture 6.3 :
    `NO_CHARACTER`, `RESOURCE_UNAVAILABLE`, `PROFILE_NOT_LOADED`.
- **Justification :** 4 studs couvrent 150 ms de latence à 16 studs/s
  (2,4 studs) et la taille de la ressource. Une échéance calée sur
  l'intervalle nominal tolère la gigue sans accélérer la cadence moyenne.
  5 demandes/s dépassent la cadence légitime maximale (2,8/s, Grabber 10).
- **Conséquences :** impact économique nul sur la cadence nominale
  (revenu par minute, temps jusqu'à la première vente inchangés). Un
  tricheur gagne au plus 4 studs de portée. Valeurs à mesurer sur mobile
  (A-27). Toute téléportation légitime future doit appeler
  `ResetTravelReference`.
- **Affecte :** `CollectionService`, `RateLimitService`,
  `CollectionSecurityConfig`, `docs/COLLECTION.md`.

## D-011 — Ressources partagées, points de spawn et interface construite par code

- **Date :** 2026-11-11
- **Statut :** PROPOSÉE
- **Contexte :** T2 doit fournir des ressources collectables en
  multijoueur, testables sans Roblox, sans carte ni assets définitifs.
- **Décision :**
  - Les ressources sont partagées entre les joueurs : un nœud collecté
    disparaît pour tous jusqu'à sa réapparition.
  - `ResourceSpawner` (logique pure, minuterie injectée) tient le registre
    et les états `ACTIVE → COLLECTED → RESPAWNING → ACTIVE` ;
    `ResourceNodes` crée les Parts et reflète l'état.
  - Points de spawn édités dans Studio (`Workspace.ResourceSpawnPoints`,
    attribut `ResourceType`). Identifiants de nœud attribués par le
    serveur. État répliqué par attributs (`NodeId`, `ResourceType`,
    `Available`), sans RemoteEvent supplémentaire.
  - Carte de test produite par `tools/studio/build_test_map.luau`
    (versionné, rejouable), en attendant la vraie carte.
  - Modèles provisoires en formes simples : aucun asset importé.
  - Interface T2 construite par code dans les contrôleurs (versionnée,
    sans édition manuelle dans Studio) ; textes par clé dans
    `Shared/Util/Localization` (en, fr). À revoir en T5.
  - `PlayerSession.start` accepte deux points d'accroche facultatifs
    (`onProfileLoaded`, `onPlayerRemoving`) ; `PlayerDataService` est
    inchangé.
  - Aucun retrait d'inventaire ni service vide : `InventoryService` se
    limite à la lecture et à l'ajout.
- **Justification :** ressources partagées = comportement demandé pour le
  MVP et le plus simple à rendre sûr (une seule vérité serveur). Les
  attributs répliquent l'état sans code réseau. Une interface par code
  reste dans Git tant que le place n'est pas versionné.
- **Conséquences :** avec peu de points de spawn, plusieurs joueurs se
  disputent les ressources (densité à régler en T7). Les nœuds sont
  répliqués à tous les clients (36 Parts dans la carte de test). Le place
  doit contenir `Workspace.ResourceSpawnPoints`, sinon aucune ressource
  n'apparaît (avertissement au démarrage).
- **Affecte :** `ResourceSpawner`, `ResourceNodes`, `PlayerSession`,
  contrôleurs client, `default.project.json`, `docs/COLLECTION.md`.

## D-012 — Arbitrage des réserves de T2 (A-25 à A-29)

- **Date :** 2026-11-11
- **Statut :** ACCEPTÉE (décision du propriétaire, retour sur T2)
- **Contexte :** le rapport T2 laissait cinq réserves ouvertes.
- **Décision :**
  - A-25 : les ressources inconnues de `ResourceConfig` restent conservées
    (D-008) et comptent dans l'occupation du sac, pour empêcher tout
    dépassement de capacité. Comportement déjà en place, documenté.
  - A-26 : le contrôle de trajet actuel reste une protection provisoire ;
    validation renforcée des déplacements côté serveur en T6.
  - A-27 : les marges de `CollectionSecurityConfig` restent des hypothèses
    jusqu'aux tests sur mobile avec latence réelle.
  - A-28 : toucher et maintien sont comparés sur mobile avant le choix du
    comportement définitif. Les deux restent actifs d'ici là.
    **Mise à jour 2026-11-11 (propriétaire) :** les deux modes sont
    conservés définitivement pour le MVP, après mesure du maintien sur
    émulateur (39 collectes en 60 s) ; le toucher n'est pas mesuré.
  - A-29 : sons et animations dans une phase dédiée à l'expérience
    utilisateur.
- **Justification :** aucune de ces réserves ne met en cause la sécurité
  serveur ou l'intégrité des données du MVP.
- **Conséquences :** aucun changement de code. T2 reste PARTIEL jusqu'aux
  vérifications manuelles et à la validation finale.
  **Mise à jour 2026-11-11 :** vérifications faites, T2 validé et clôturé
  par le propriétaire. A-26 et A-27 restent des risques ouverts pour T6 ;
  A-29 et A-30 (barre du sac) reportés à la phase UX.
- **Affecte :** `docs/COLLECTION.md`, `docs/PROJECT_STATUS.md`, T6, phase UX.

## D-013 — Fichiers place `.rbxl` hors de Git

- **Date :** 2026-11-11
- **Statut :** ACCEPTÉE (décision du propriétaire, clôture de T2)
- **Contexte :** la carte de test n'existe que dans le place ; une copie
  locale `GrabAndGrow.rbxl` a été vérifiée. Studio crée aussi `server.rbxl`
  lors d'un Test > Local Server.
- **Décision :** `GrabAndGrow.rbxl` et `server.rbxl` ne sont pas versionnés
  (`.gitignore`, chemins exacts à la racine). `GrabAndGrow.rbxl` reste une
  sauvegarde de travail locale ; `server.rbxl` est temporaire.
- **Justification :** fichiers binaires, illisibles en diff. La carte de test
  se reconstruit avec `tools/studio/build_test_map.luau` (déterministe) et
  le place de test est sauvegardé sur Roblox.
- **Conséquences :** une carte éditée à la main dans Studio n'est protégée
  que par le place Roblox et la copie locale. À réexaminer quand une carte
  non scriptée existera.
- **Affecte :** `.gitignore`, `docs/PROJECT_STATUS.md`.

## D-014 — Vente : transaction unique dans SellService, ressources inconnues conservées

- **Date :** 2026-11-11
- **Statut :** ACCEPTÉE (propriétaire, 2026-11-11, retour sur T3). Les
  paramètres de sécurité restent des hypothèses provisoires (voir
  « Validation »).
- **Validation du propriétaire (2026-11-11) :**
  - Pas d'`EconomyService` en T3 : le crédit des Coins reste intégré à la
    transaction atomique de vente.
  - Extraction vers `EconomyService` autorisée en T4, lors de
    l'introduction du premier débit.
  - `totalSales` = nombre de ventes réussies.
  - Une vente ne déclenche pas de sauvegarde DataStore : la persistance
    reste gérée par le cycle normal de `PlayerDataService`.
  - Une ressource retirée de `ResourceConfig` reste conservée dans les
    inventaires, sans vente possible ; toute suppression ou conversion
    exigera une migration explicite.
  - Paramètres validés **provisoirement** : distance d'interaction 10 studs
    + marge serveur 4 studs ; limite 3 requêtes initiales puis 1 par
    seconde. Hypothèses, pas des paramètres définitifs : ils restent
    configurables (`GameConfig.Selling`, `SellSecurityConfig`) et seront
    réévalués en T6 (mesures de latence et de cadence réelles).
  - A-26 reste un risque connu : validation des déplacements renforcée
    côté serveur en T6 (collecte et vente).
- **Contexte :** l'architecture (5.4, 9.3) répartit la vente entre
  `InventoryService` (retrait) et un `EconomyService` (crédit). Deux
  mutations séparées ne seraient pas atomiques. Le prompt T3 demande un
  `SellService` et une transaction unique via `PlayerDataService.Update`.
  A-25 laissait le sort des ressources inconnues à la vente pour T3.
- **Décision :**
  - `SellService` exécute retrait, crédit et statistiques dans un seul
    `Update`. Pas d'`EconomyService` en T3 (il n'aurait qu'une fonction) :
    `CreditCurrency` / `DebitCurrency` seront extraits en T4, avec le
    premier débit, sous forme de fonctions appliquées au brouillon du même
    `Update`.
  - Formule unique `Shared/Util/SaleValue` (somme quantité × sellValue,
    entiers, bornée à 2^53 − 1), lue par le serveur pour créditer et par
    le client pour l'estimation affichée.
  - Ressources inconnues : jamais vendues, jamais supprimées, comptées
    dans le sac (D-012). Sac sans ressource vendable : `NOTHING_TO_SELL`,
    aucune mutation.
  - `RequestSell { sellZoneId }` (architecture 6.1) ; nouveau code
    `NOTHING_TO_SELL`. Zones : BaseParts de `Workspace.SellZones` avec
    l'attribut `SellZoneId`.
  - `stats.totalSales` = nombre de ventes réussies (une par transaction).
  - Aucune sauvegarde DataStore déclenchée par une vente.
  - Hypothèses de départ, hors Bible : distance d'interaction 10 studs
    (`GameConfig.Selling`), marge serveur 4 studs, limite rafale 3 / 1 par
    seconde (`SellSecurityConfig`).
  - Interaction par `ProximityPrompt` créé côté client (F, toucher, Y) :
    indication de proximité native sur les trois plateformes ; le serveur
    refait tous les contrôles.
- **Justification :** atomicité garantie par l'existant (`Update` tout ou
  rien, sans suspension) ; une seule formule évite toute divergence entre
  estimation et crédit ; aucun service vide.
- **Conséquences :** l'économie ne passe pas encore par une fonction
  centrale de crédit (écart temporaire à l'architecture 9.3). Une ressource
  retirée de `ResourceConfig` occupe le sac sans être vendable : toute
  suppression ou tout renommage de ressource exigera une migration. Perte
  possible d'une vente (Coins et retrait ensemble) en cas de crash avant
  la sauvegarde suivante (≤ 60 s), sans incohérence.
- **Affecte :** `SellService`, `SellZones`, `SaleValue`, `Remotes`,
  `GameConfig`, `SellSecurityConfig`, contrôleurs client,
  `docs/SELLING.md`.

## D-015 — T4 : cinq améliorations, quatre mondes, EconomyService

- **Date :** 2026-11-12
- **Statut :** ACCEPTÉE (choix du propriétaire, 2026-11-12, en réponse au
  préflight T4)
- **Contexte :** le prompt T4 demande cinq améliorations et la préparation
  des quatre mondes. CLAUDE.md 5.1, GDD 19.2 et D-003 limitaient le MVP à
  Backpack et Grabber, et GoldenDesert seul. Le préflight a relevé quatre
  points non tranchés par la Bible : alignement du Magnet (D-006),
  arrondi du Multiplier, ordre de déblocage, extraction d'EconomyService
  (prévue par D-014).
- **Décision :**
  - **Périmètre** (amende D-003) : Backpack, Grabber, Magnet, Boots et
    Multiplier, tables de la Bible 5.2 à 5.6 sans changement de coût ni
    d'effet. Achat x1 seulement (x10, x100, MAX restent reportés).
    FrozenPeaks et MysticWorld ajoutés à `WorldConfig` (Bible 6),
    verrouillés, **sans contenu** : débloquer un monde ne téléporte pas.
  - **Magnet** : niveau k du profil = ligne k + 1 de la Bible. Niveau 0
    (départ) = 12 studs, niveau 1 = 14 studs pour 200 Coins, niveau
    maximum 9 = 30 studs. `magnetLevel = 0` conservé (D-006).
  - **Multiplier** : montant crédité = `floor(base × multiplicateur)`,
    une fois par vente, calculé en centièmes entiers ; multiplicateur
    total plafonné à x5,00 (`GameConfig.Selling.maxSellMultiplier`, Bible
    2 et 10.2). Aucune vente passée n'est recalculée.
  - **Ordre strict des mondes** : un monde d'ordre n exige le monde
    n − 1 débloqué, `backpackLevel >= requiredBackpackLevel` et un solde
    `>= unlockCost`, débité une seule fois.
  - **EconomyService** : module de fonctions `credit` / `debit` appliquées
    au brouillon d'un `PlayerDataService.Update` (pas un service à état).
    Utilisé par `SellService`, `UpgradeService` et `WorldUnlockService`.
    Journal (Bible 13.3) : motif, montant, identifiant d'opération, solde.
  - **Effets** lus dans le profil serveur à chaque usage : capacité
    (`InventoryService`), intervalle et portée (`CollectionService`),
    vitesse (`Humanoid.WalkSpeed` fixé par le serveur au chargement, à
    l'apparition et après achat ; contrôle de trajet de la collecte calé
    sur la vitesse des Boots), Multiplier (`SellService`).
  - **Source unique** : `UpgradeConfig` gagne `order`, `profileKey`,
    `startLevel`. `DataSchema` en tire les bornes des cinq niveaux
    (`DataConfig.NonMvpUpgradeMaxLevels` supprimé). Portée et vitesse de
    base retirées de `GameConfig` (elles dupliquaient Magnet et Boots
    niveau de départ). Lecture partagée : `Shared/Util/UpgradeMath`.
  - **Remotes** : `RequestUpgrade { upgradeId }`,
    `RequestUnlockWorld { worldId }` ; codes `INSUFFICIENT_FUNDS`,
    `MAX_LEVEL`, `ALREADY_UNLOCKED`, `REQUIREMENT_NOT_MET`. Tout champ
    supplémentaire fait refuser la demande.
  - Limites de fréquence (`EconomySecurityConfig`, hypothèses hors Bible) :
    achats 5 puis 3/s ; déblocages 2 puis 0,5/s. À réévaluer en T6.
- **Justification :** décision explicite du propriétaire ; aucune valeur
  économique inventée ; atomicité garantie par l'existant (`Update` tout
  ou rien, sans suspension) ; une seule source par valeur.
- **Conséquences :**
  - Schéma de profil inchangé (v1) : aucune migration. Seule la borne de
    `magnetLevel` passe de 10 à 9 ; un profil à 10 (impossible jusqu'ici,
    aucun achat n'existait) serait ramené à 9 par la normalisation D-008,
    avec copie de récupération.
  - Les niveaux élevés sont hors de portée tant que Green Valley est le
    seul monde jouable (voir `PROGRESSION.md`).
  - La vitesse n'est pas protégée contre un client qui modifie localement
    son `WalkSpeed` (contrôle complet du déplacement : T6, A-26) ; la
    collecte reste bornée par la vitesse des Boots du profil.
- **Affecte :** `UpgradeConfig`, `WorldConfig`, `GameConfig`, `DataConfig`,
  `DataSchema`, `SaleValue`, `UpgradeMath`, `Remotes`, `Localization`,
  `EconomyService`, `UpgradeService`, `WorldUnlockService`, `SellService`,
  `CollectionService`, `Bootstrap`, contrôleurs client, Bible 5.4 et 5.6
  (notes), `docs/UPGRADES.md`, `docs/PROGRESSION.md`.

## D-016 — T5 : cadre du HUD et du feedback mobile

- **Date :** 2026-11-12
- **Statut :** ACCEPTÉE (recommandations du préflight T5 validées par le
  propriétaire, 2026-11-12)
- **Contexte :** préflight T5 (`phases/T5_PREFLIGHT.md`) : sept points non
  tranchés par le GDD ou l'architecture (sons, mémorisation du guidage,
  icônes, localisation, temps de jeu, option de réduction, découpage des
  contrôleurs).
- **Décision :**
  - **D-1 Sons** : sons du Creator Store Roblox, 4 à 5 sons courts ;
    licence et provenance de chacun consignées dans
    `docs/assets/ASSET_MANIFEST.md` (créé au premier asset).
  - **D-2 Guidage** : fin de chaque étape déduite des données existantes
    (inventaire, `totalCoinsEarned`, niveaux), **sans changement de
    schéma**.
  - **D-3 Icônes** : glyphes conservés en T5 (A-38 reste ouverte).
  - **D-4 Localisation** : module `Shared/Util/Localization` conservé ;
    pas de migration vers `LocalizationService` (amende la note de D-011).
  - **D-5 Temps de jeu** : `stats.playTimeSeconds` laissé non alimenté
    jusqu'à T7 (A-21).
  - **D-6 Réduction** : bouton « son coupé / effets réduits » côté client.
  - **D-7 Contrôleurs** : organisation actuelle conservée, ajout d'un
    `FeedbackController` ; pas de refonte en `HUDController` /
    `InputController` (écart assumé avec l'architecture 13.1).
- **Justification :** aucun changement serveur, économique ni de schéma ;
  assets limités et traçables ; coût de refonte sans bénéfice joueur.
- **Conséquences :** T5 reste client seulement ; A-21 et A-38 restent
  ouvertes ; manifeste d'assets à créer avant le premier son.
- **Affecte :** contrôleurs client, `Localization`, `docs/assets/`,
  `phases/T5_PREFLIGHT.md`, architecture 13.1 (écart).

## D-017 — T5.3 : statistiques de progression dans l'état client (D-10)

- **Date :** 2026-11-13
- **Statut :** ACCEPTÉE (propriétaire, 2026-11-13)
- **Contexte :** le guidage de première session (T5.3) doit savoir si le
  joueur a déjà collecté, vendu ou acheté, y compris après une
  reconnexion. Ces statistiques sont sauvegardées (`profile.stats`) mais
  n'étaient pas envoyées au client. D-016 prévoyait un T5 sans changement
  serveur ; D-2 = b interdit un nouveau champ de profil.
- **Décision :** `CollectionService.GetClientState` ajoute `progress` =
  `{ resourcesCollected, sales, coinsSpent }`, copie en lecture seule de
  `totalResourcesCollected`, `totalSales`, `totalCoinsSpent`, envoyée par
  le `StateUpdated` existant. Le serveur ne la relit jamais ; aucun
  RemoteEvent ajouté, aucun schéma modifié.
- **Justification :** déduction fiable et persistante des étapes ; une
  déduction par l'inventaire, le solde et les niveaux confondrait un joueur
  ayant tout dépensé avec un nouveau joueur.
- **Conséquences :** écart limité à D-016 (« T5 client seulement ») ;
  le client connaît trois compteurs de son propre profil (aucune donnée
  sensible). Un joueur avancé ne voit jamais le guidage.
- **Affecte :** `CollectionService`, `InventoryController` (type d'état),
  `OnboardingRules`, `OnboardingController`, `docs/ONBOARDING.md`.

## D-018 — Clôture de T5 (HUD et feedback mobile)

- **Date :** 2026-11-13
- **Statut :** ACCEPTÉE (propriétaire, 2026-11-13 : « Oui, clôturer T5 »)
- **Contexte :** T5.1 à T5.4 clôturés ; T5.5 : tests techniques et
  parcours complet sur émulateur exécutés par Claude, checklist téléphone
  réel (R1–R10) et PC (P1) déclarée validée par le propriétaire, sans
  détail transmis. Aucune anomalie P0/P1 ; T55-01 (P3) corrigée.
- **Décision :** T5 est clôturée avec réserves.
- **Réserves acceptées :** manette physique jamais testée (E8, U10, T5.5) ;
  tablette réelle non testée ; aucune mesure chiffrée de performance sur
  téléphone ; préférences audio en session seulement (D-8, D-9 sans
  décision consignée) ; A-38 et reste d'A-41 (P3) ouverts.
- **Conséquences :** T6 (multijoueur et anti-exploit) peut être préparé
  sur demande du propriétaire ; A-26, A-27, A-37 y sont attendus.
- **Affecte :** `ROADMAP.md`, `PROJECT_STATUS.md`,
  `phases/T5_PREFLIGHT.md`, `tests/T5_*.md`.

## D-019 — T6 : validation des déplacements, payloads communs, journal de sécurité

- **Date :** 2026-11-13
- **Statut :** ACCEPTÉE pour l'implémentation (propriétaire, 2026-11-13 :
  R1, R2, R3 validés ; R4 validé sous réserve). T6 validée et clôturée
  par le propriétaire le 2026-11-14 ; R4 reste à calibrer.
- **Contexte :** audit T6 (A-26, A-27, A-37) : position simulée par le
  client, vente sans contrôle de déplacement, « Reset » qui efface la
  référence de trajet, `WalkSpeed` local invisible, NaN, arguments
  supplémentaires ignorés, journalisation incomplète.
- **Décision :**
  - `Systems/MovementValidator` (logique pure) échantillonné à 4 Hz par une
    boucle unique de `Bootstrap` ; paramètres dans
    `ServerOnlyConfig/MovementSecurityConfig` (hypothèses R4, à calibrer).
    Horizontal et vertical séparés, descente jamais limitée ; seuil de
    téléportation (un échantillon) distinct du seuil de vitesse (fenêtre
    glissante 1 s) ; gel réseau absorbé avec un crédit borné.
  - **R1** : anomalie isolée = journal + refus temporaire de collecte et
    de vente ; anomalie persistante (3 s) ou répétée (3 en 10 s) = retour
    à la dernière position validée + suspension 5 s. Grâce de 1 s et 5 s
    minimum entre deux corrections (pas de boucle). Aucune expulsion ni
    bannissement.
  - **R2** : refus renvoyés au client avec `TOO_FAR` ; aucun changement
    client.
  - **R3** : D-8 (préférences persistantes) hors T6.
  - Référence de trajet à la réapparition = point d'apparition lu par le
    serveur (`ResetTravelReference(userId, position)`) ; sans position,
    comportement T2 conservé.
  - Gardes NaN / infini dans la collecte et la vente.
  - `Systems/PayloadValidator` commun aux quatre remotes : contrats
    inchangés, arguments supplémentaires et caractères hors `[%w_-]`
    refusés (`INVALID_TARGET`).
  - `Services/SecurityLog` : lignes structurées, limitées par joueur et
    par type et globalement, valeurs assainies, appel protégé.
  - `Systems/ProfileAudit` au chargement : journal seulement, aucune
    correction.
  - Dépendances `movement` et `security` facultatives dans les services
    (tests existants inchangés) ; branchées dans `Bootstrap`.
- **Justification :** la position ne peut pas être rendue autoritaire sans
  propriété réseau serveur, inacceptable sur mobile (latence d'entrée) ;
  observer, refuser l'action économique et corriger graduellement est le
  meilleur compromis entre sécurité et faux positifs.
- **Conséquences :** aucun changement de schéma, de prix, de revenus, de
  capacités ni d'effets. Un tricheur reste toléré jusqu'à environ 2 × la
  vitesse de référence ; une projection physique forte en courant peut
  provoquer une correction (A-42). Préréglages Studio : constats d'audit
  attendus (A-43). Coût mesuré (Lune) : 0,77 ms/s pour 50 joueurs.
- **Affecte :** `Bootstrap`, `CollectionService`, `SellService`,
  `UpgradeService`, `WorldUnlockService`, nouveaux `MovementValidator`,
  `PayloadValidator`, `ProfileAudit`, `SecurityLog`,
  `MovementSecurityConfig`, `SecurityLogConfig`, tests,
  `phases/T6_SECURITY_REPORT.md`, `phases/T6_MULTIPLAYER_TEST_REPORT.md`.

## D-020 — T7 : première amélioration, temps de jeu, succès permanents

- **Date :** 2026-11-14
- **Statut :** ACCEPTÉE pour l'implémentation (propriétaire, 2026-11-14 :
  « Oui, comme recommandé » sur les décisions D1 à D7 de l'étape A).
  Implémentée le 2026-11-14 ; T7 validée et clôturée par le propriétaire le 2026-11-14 après test réel.
- **Contexte :** audit T7 (`phases/T7_PROGRESSION_AUDIT.md`), risques A-19,
  A-21, A-36. Simulation reproductible
  (`tools/simulate_progression.luau`, `phases/T7_ECONOMY_SIMULATION.md`) :
  première amélioration seulement à la 2e vente ; attente entre deux achats
  de plus de 20 min après 1 h de jeu, de plus d'1 h après 6 h ; chaque
  achat n'ajoute que 2 à 5 % de revenu. Cause structurelle : la courbe de
  la Bible est financée par des mondes encore vides dans le MVP.
- **Décision :**
  - **D1 / P0** : Backpack niveau 2 à 75 Coins (100 dans la Bible 1.0).
  - **D2 / P3** : 12 succès permanents récompensés une seule fois en Coins
    (`Shared/Config/AchievementConfig`), attribués par
    `Services/AchievementService` après chaque action validée par le
    serveur et au chargement du profil ; crédit par `EconomyService` dans
    le même `Update` que le marquage (atomique, jamais deux fois). Aucune
    quête quotidienne, série ni pénalité d'absence. Message serveur ->
    client `ActionResult { action = "Achievement" }` ; aucune demande
    client.
  - **D3 / A-21** : temps de jeu compté par le serveur
    (`Systems/PlayTimeTracker`, horloge `os.clock`) et ajouté à
    `stats.playTimeSeconds` dans `PlayerDataService` juste avant chaque
    écriture ; aucune écriture supplémentaire ; intervalle borné à 300 s.
  - **D4** : schéma v2, migration v1 -> v2 (`achievements = {}`).
  - **D5** : `AnalyticsService` Roblox reporté à T8 ; indicateurs de
    rétention natifs du Creator Hub en attendant.
  - **D6** : P1 (coûts ≥ 2 000 × 0,6) et P2 (Golden Desert dès Backpack
    4) écartés tant que les mondes 2 à 4 sont vides.
  - **D7** : Bible économique révisée sur place (1.0.2) dans
    `GRAB_AND_GROW_ECONOMY_v1.0.md` ; ce fichier porte déjà la révision
    1.0.1 dans son historique : aucun doublon créé.
  - Un profil qui a déjà atteint un seuil reçoit le succès au chargement
    (récompense rétroactive ; seuls des profils de test existent) :
    confirmé par le propriétaire le 2026-11-14.
- **Justification :** P0 place la première amélioration juste après la
  première vente (GDD 4.2 et 4.3). P3 ajoute des récompenses perceptibles
  entre 30 min et 8 h sans toucher la courbe des mondes futurs ; les
  récompenses uniques ne créent pas d'inflation durable. A-21 sans
  migration ni écriture supplémentaire.
- **Conséquences :** projections (joueur régulier) : première amélioration
  3,2 -> 1,6 min ; Golden Desert 1,8 -> 1,5 h ; Backpack 8 10,6 -> 8,4 h ;
  coût total inchangé à 25 Coins près. A-36 réduit, non résolu (structurel
  jusqu'au contenu de Golden Desert). Un serveur v1 refuse les profils v2 :
  redémarrer tous les serveurs à la publication.
- **Affecte :** `UpgradeConfig`, `DataConfig`, `DataSchema`,
  `PlayerDataService`, `Bootstrap`, `Remotes`, `FeedbackRules`,
  `Localization`, `ProfileAudit` (commentaire), `StudioTestPresets` (U1),
  nouveaux `AchievementConfig`, `AchievementRules`, `AchievementService`,
  `PlayTimeTracker`, `AchievementController`,
  `tools/simulate_progression.luau`, tests, Bible 1.0.2,
  `DATA_PERSISTENCE.md`, `PROGRESSION.md`, rapports T7.

## D-021 — T8 : mondes et contenu (périmètre, voyage serveur, valeurs des ressources)

- **Date :** 2026-11-14
- **Statut :** ACCEPTÉE (propriétaire, 2026-11-14 : décisions D1 à D10 de
  l'étape A de T8, `phases/T8_WORLD_AUDIT.md`). T8.0 et T8.1 autorisés ;
  T8.2 et suivants soumis à validation.
- **Contexte :** audit T8 : les mondes 2 à 4 n'existent que dans
  `WorldConfig` (déblocage payé, aucun contenu) ; Green Valley est une carte
  de test plate. La roadmap plaçait en T8 la préparation de publication et
  `CLAUDE.md` §5.2 reportait les mondes après le MVP. Simulation : avec les
  valeurs de la Bible 1.0 (× 9 par monde), l'arbre complet des améliorations
  est acheté en ≈ 5 h par un joueur régulier.
- **Décision :**
  - **D1** : T8 = mondes et contenu. Préparation de publication et
    `AnalyticsService` (D-020, D5) reportés en **T9**. `CLAUDE.md`,
    `ROADMAP.md` et `PROJECT_STATUS.md` harmonisés.
  - **D2** : un seul place, quatre îles ; voyage effectué exclusivement par
    le serveur (`WorldTravelService`, RemoteEvent `TravelToWorld`) ; pas de
    `TeleportService` (le verrou de session du profil resterait à
    transférer entre places).
  - **D3** : valeurs des ressources « option B » (Bible 1.1) : Golden
    Desert 5 / 6 / 9 / 17 / 38 ; Frozen Peaks 18 / 24 / 34 / 62 / 140 ;
    Mystic World 68 / 87 / 125 / 230 / 480. Coûts d'amélioration et de
    déblocage inchangés.
  - **D4** : Fruit sauvage (5) et Cristal vert (12), valeurs de la Bible,
    dans la zone avancée de Green Valley.
  - **D5** : apparition systématique dans le hub de Green Valley à chaque
    connexion et à chaque réapparition ; position non sauvegardée.
  - **D6** : journal de collection, schéma v3 et récompenses associées
    NON retenus pour T8 ; aucune migration de données. À réévaluer après
    les quatre mondes. *Journal et schéma v3 rouverts par D-022
    (2026-11-16) ; récompenses toujours écartées.*
  - **D7** : décors en primitives low-poly scriptées ; aucun asset Polyfork
    avant validation de `assets/ASSET_MANIFEST.md`, puis asset par asset.
  - **D8** (sous réserve) : environ 40 nœuds par monde, réapparition
    2 à 4 s (Commune), 8 s (Peu commune), 20 s (Rare), 60 s (Épique) :
    hypothèses, ajustées seulement sur mesures.
  - **D9** : événements environnementaux reportés (ni Golden Rush ni
    système d'événements en T8).
  - **D10** : conditions de déblocage inchangées ; P2 non rouverte.
- **Mise en œuvre T8.1 (architecture) :**
  - collecte refusée (`WORLD_LOCKED`) si le monde de la ressource n'est pas
    débloqué dans le profil serveur, quelle que soit la demande reçue ;
  - voyage : le client n'envoie que `{ worldId }` ; le serveur vérifie le
    monde, son déblocage et la présence d'un point d'arrivée
    (`Workspace.WorldArrivals`, attribut `ArrivalWorldId`), puis déplace
    lui-même le personnage ;
  - après un voyage, nouvelle référence de déplacement au point d'arrivée
    (`MovementValidator.Reset`, `CollectionService.ResetTravelReference`) et
    courte période de grâce d'observation
    (`MovementSecurityConfig.ServerTeleport.graceSeconds`), comme après une
    correction T6 : les positions encore en transit ne créent pas de faux
    positif. La suspension et l'historique des anomalies sont conservés ;
    `CanAct` reste appliqué pendant la grâce.
  - aucun champ `playable` dans `WorldConfig` (proposé à l'étape A) : un
    monde est accessible dès qu'il est débloqué ET qu'un point d'arrivée
    existe sur la carte ; aucune condition propre à un monde dans les
    services.
- **Justification :** contenu des mondes nécessaire pour résorber A-36
  (plateau structurel) ; option B : arbre complet en ≈ 13,5 h (régulier,
  projection) au lieu de ≈ 5 h ; un seul place garde le verrou de session
  et les protections T6 sans transfert.
- **Conséquences :** inventaire : nouvelles clés de ressources, aucune
  migration (schéma v2 inchangé ; un serveur ancien conserve les clés
  inconnues, D-008). Cibles de revenus de la Bible 4.2 révisées en
  proportion. Le simulateur projette désormais les quatre mondes (variante
  `t7` pour reproduire les chiffres de T7).
- **Affecte :** `CLAUDE.md`, `ROADMAP.md`, `PROJECT_STATUS.md`, Bible 1.1,
  `assets/ASSET_MANIFEST.md`, `ResourceConfig`, nouveau
  `ResourceVisualConfig`, `WorldConfig` (commentaire), `ResourceNodes`,
  `CollectionService`, nouveaux `WorldTravelService` et `WorldArrivals`,
  `TravelSecurityConfig`, `MovementSecurityConfig`, `MovementValidator`,
  `Remotes`, `Bootstrap`, `Localization`, `InventoryController`,
  `CollectionController`, `tools/simulate_progression.luau`,
  `tools/studio/build_test_map.luau`, tests.

## D-022 — T8.6 : journal de collection et schéma v3 (réouverture de D-021 D6)

- **Date :** 2026-11-16
- **Statut :** ACCEPTÉE (propriétaire, 2026-11-16 : recommandations D1 à D7
  de l'étape A de T8.6 validées, étape B autorisée). Rouvre D-021 D6 pour
  le journal et le schéma v3 seulement ; les récompenses associées restent
  écartées.
- **Contexte :** les quatre mondes existent (T8.2 à T8.5 validées). D-021 D6
  avait reporté le journal et le schéma v3 « après les quatre mondes ».
  Audit de l'étape A : une seule attribution de ressource
  (`InventoryService.AddResource`, dans `PlayerDataService.Update`), un
  seul canal d'état serveur -> client (`StateUpdated`), mécanisme de
  migration et copie de récupération D-008 déjà en place.
- **Décision :**
  - **D1** : COLLECTION JOURNAL réouvert, sans aucune récompense (ni
    Coins, Gems, Stars, multiplicateur, bonus ni coffre). Une récompense de
    collection complète exigera une décision distincte.
  - **D2** : schéma v3, section `collection = { discoveredResources =
    { [identifiant de ResourceConfig] = true } }`. Totaux et pourcentages
    jamais stockés.
  - **D3** : migration v2 -> v3 avec un journal VIDE ; aucun historique
    reconstitué, même depuis l'inventaire.
  - **D4** : pas de `CollectionJournalService` ; module pur partagé
    `Shared/Util/CollectionJournalRules` (catalogue dérivé de
    `ResourceConfig` et `WorldConfig`, résumé, marquage). Le marquage a lieu
    dans le mutateur de `InventoryService.AddResource`, dans la même
    transaction que l'ajout.
  - **D5** : aucun nouveau RemoteEvent ; `StateUpdated` porte `discovered`
    (lecture seule, identifiants inconnus filtrés) ; `ActionResult`
    (Collect) porte `firstDiscovery`, calculé par le serveur.
  - **D6** : bandeau « Nouvelle découverte : X ! » à la première collecte,
    dans la file des succès (`AchievementController`), sans nouveau son.
  - **D7** : bouton « Journal » sous la Boutique, touches J et DPadDown ;
    préréglages Studio `J_partial`, `J_full`, `J_world4` (et `reset` vide
    le journal).
- **Justification :** le marquage dans la mutation de l'ajout rend
  impossible une ressource sans découverte (ou l'inverse) et réutilise tous
  les refus existants (monde verrouillé, distance, cadence, sac plein) sans
  les dupliquer. Sans requête client, rien à falsifier ni à limiter.
- **Conséquences :** un serveur v2 refuse les profils v3
  (`UnsupportedVersion`, rien d'écrasé) : redémarrer tous les serveurs à la
  publication. Un profil migré écrit sa copie `Recovery_` avant sa première
  sauvegarde (D-008). Les joueurs v2 (profils de test seulement à ce jour)
  repartent d'un journal vide. `StateUpdated` grossit d'au plus 20
  identifiants. Aucune valeur économique, condition de déblocage ni
  protection T6 modifiée.
- **Affecte :** `DataConfig`, `DataSchema`, nouveau `CollectionJournalRules`,
  `InventoryService`, `CollectionService`, `Bootstrap`, `Remotes`
  (commentaires), `StudioTestPresets`, `Localization`, nouveau
  `CollectionJournalController`, `UpgradeController` (`close`),
  `AchievementController`, `InventoryController` (type), `ClientBootstrap`,
  tests (`CollectionJournalTests`, `DataSchemaTests`, `AchievementTests`,
  `LocalizationTests`), `DATA_PERSISTENCE.md`, `ROADMAP.md`,
  `PROJECT_STATUS.md`, `TEST_STRATEGY.md`, rapports T8.6.

## D-023 — T8.7 : sauvegarde après achat d'amélioration et déblocage de monde

- **Date :** 2026-11-16
- **Statut :** ACCEPTÉE (propriétaire, 2026-11-16 : étape B de T8.7
  autorisée « avec P2-02 »).
- **Contexte :** audit T8.7-A, anomalie P2-02. `CLAUDE.md` §8 demande de
  sauvegarder « après les opérations importantes » ; l'implémentation et
  `DATA_PERSISTENCE.md` ne sauvegardaient qu'à la sortie, à l'arrêt et
  toutes les 60 s. Un plantage serveur pouvait perdre jusqu'à 60 s de
  progression, dont un déblocage de monde (jusqu'à 250 000 Coins). Perte
  seulement, jamais duplication (verrou de session).
- **Décision :** `PlayerDataService.RequestSave(userId, reason)`, appelé
  par `Bootstrap` après un achat d'amélioration ou un déblocage de monde
  réussi. Sauvegarde différée de `DataConfig.Save.importantSaveDelaySeconds`
  (5 s, réglage technique de départ) ; toutes les demandes reçues pendant le
  délai sont regroupées en une écriture. Collecte et vente restent couvertes
  par l'autosauvegarde de 60 s.
- **Justification :** les achats sont rares (54 sur toute la progression,
  simulateur T8) mais coûteux ; le regroupement borne les écritures d'un
  joueur qui enchaîne les achats (au plus une toutes les 5 s environ) et
  ménage le budget d'écritures DataStore du serveur.
- **Conséquences :** perte maximale après un achat ou un déblocage ramenée
  d'environ 60 s à environ 5 s (plus la durée de l'écriture). Aucune valeur
  économique, règle d'achat, schéma ni protection T6 modifiés. Sauvegarde
  après opération importante non vérifiée sur DataStore réel tant que le
  test DataStore de T8.7 n'est pas fait.
- **Affecte :** `PlayerDataService`, `DataConfig`, `Bootstrap`,
  `PlayerDataServiceTests`, `DATA_PERSISTENCE.md`.
