# GRAB & GROW — Décisions techniques

Journal des décisions. Statuts : PROPOSÉE (attend la validation du
propriétaire), ACCEPTÉE, REMPLACÉE.

---

## D-001 — Code source sur disque, synchronisé vers Studio par Rojo

- **Date :** 2026-11-10
- **Statut :** PROPOSÉE
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
- **Conséquences :** installer Rojo (binaire + plugin Studio). Le mappage ne
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
- **Statut :** PROPOSÉE
- **Contexte :** le MVP impose trois ressources et deux améliorations ; la
  Bible en définit cinq et cinq.
- **Décision :**
  - Ressources : `green_leaf`, `wood_chunk`, `stone` (les trois communes de
    la Bible 3.2, valeurs et poids inchangés).
  - Améliorations : `Backpack` et `Grabber`, tables complètes de la Bible
    (16 et 10 niveaux).
  - Monde : `GreenValley` seul.
  - `GameConfig` ne contient que les paramètres globaux qui ne figurent
    dans aucune autre table (monde de départ, monnaie Coins, portée de base
    12 studs, vitesse de base 16). La capacité initiale et l'intervalle de
    base se lisent dans `UpgradeConfig` (niveau 1).
  - `respawnSeconds` (2 / 3 / 4 s) et `collectAmount` (1) viennent de
    l'exemple de l'architecture : hypothèses, absentes de la Bible.
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
- **Statut :** PROPOSÉE
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
