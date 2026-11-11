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
- **Statut :** ACCEPTÉE (validation du propriétaire, 2026-11-11)
- **Termes validés :** profil corrompu = joueur bloqué ; données originales
  jamais écrasées ni réparées automatiquement ; données conservées pour une
  récupération manuelle ; erreurs journalisées.
- **Portée de « jamais réparées » (lecture de Claude, à confirmer) :** elle
  vise les profils refusés (type incorrect, structure illisible, version
  future), qui restent intacts dans le DataStore. Les ajustements exigés
  par le prompt T1 (« ajouter les champs manquants », « borner les
  niveaux ») restent appliqués à un profil lisible et sont réécrits dans le
  DataStore dès le chargement, journalisés ligne par ligne. Si le
  propriétaire veut aussi conserver l'original dans ce cas, il faut une
  décision complémentaire (par exemple refuser au lieu de borner).
- **Contexte :** l'architecture (7.4) demande à la fois de remplacer les
  valeurs invalides par des valeurs sûres et de ne jamais écraser
  silencieusement une sauvegarde illisible. Le schéma contient en outre
  Magnet, Boots et Multiplier, absents de `UpgradeConfig` (hors MVP).
- **Décision :**
  - Champ ou section manquant : valeur par défaut ajoutée.
  - Nombre hors bornes (niveau, solde négatif, décimale) : borné.
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
  correction manuelle. Le nombre de niveaux hors MVP est écrit à deux
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
