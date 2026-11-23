# T10 — Conception des quatre gardiens (PvE individuel)

Date : 2026-11-21, révisé le 2026-11-22 — Statut : **VALIDÉ (T10.0,
D-028)**, non implémenté. Aucun système de combat n'existe dans le code.
Le GDD exclut le PvP (19.3). Les gardiens sont une extension de périmètre
acceptée (D-028) ; leur développement attend l'autorisation de T10.4.

Révision 2026-11-22 : combats **strictement individuels** (D-028) ;
récompenses **non fixées** avant simulation (D-030) ; schéma v3 conservé
(D-029). Les règles de PV partagés, d'adaptation au nombre de joueurs et
de réapparition par serveur de la version T10.0 sont retirées.

Révision T10.3 (2026-11-22, D-034) : **implémenté** en T10.3 (et non
T10.4) selon l'addendum T10-D01 à T10-D03. Gardien visuellement commun,
états par joueur ; PV, attaques et durées dans `GuardianConfig`
(hypothèses) ; détails et écarts dans `phases/T10_3_GUARDIANS_REPORT.md`.

Validation T10.4 (2026-11-22, D-036) : conformité à l'addendum vérifiée
(`phases/T10_4_FINAL_VALIDATION_REPORT.md` §3) ; combat coopératif sans
objet (T10-D02) ; équilibrage (PV, cadences) non mesuré sur joueurs réels.

## 1. Principes communs

- **PvE individuel, sans PvP** : chaque joueur combat **son** gardien ;
  dégâts, phases, victoire, déblocages et récompenses lui sont propres.
  Aucun joueur ne peut aider, gêner, blesser ou voler un autre joueur.
- **Faisable seul** par construction (CLAUDE.md 4.2).
- **Verbe du jeu conservé : « Grab »**. Pas d'arme ni de nouvel outil : le
  gardien libère des **Éclats de faiblesse** autour de lui ; chaque éclat
  saisi (même bouton que la collecte) inflige des dégâts calculés par le
  serveur.
- **Pas de mort, pas de perte** : une attaque reçue repousse le joueur et
  l'étourdit 1,5 s (pas de saisie possible). Les PV de l'avatar ne sont pas
  touchés, l'inventaire et les Coins jamais.
- **Lisibilité mobile** : attaques annoncées par une zone au sol (anneau,
  ligne, cône) **1,5 s** avant l'impact ; couleur + forme + son.
- **Taille** : avatar R15 ≈ 5,5 studs ; gardiens **15 à 20 studs** (≈ 3×).
- **Autorité serveur** : un état de combat **par joueur** (PV, éclats,
  résolution des attaques sur la position de ce joueur connue du serveur,
  victoire). Le client envoie seulement « saisir l'éclat X ».

## 2. Mécanique de combat commune

États serveur, **par joueur et par gardien** : `Dormant → Awakening (3 s)
→ Combat (phases 1-3) → Defeated → Dormant`.

| Élément | Règle proposée (hypothèses, à régler en T10.4) |
|---|---|
| PV | `basePV` fixe par gardien, indépendant du nombre de joueurs présents |
| Dégâts | 1 éclat = 1 dégât ; `basePV` = 24 / 30 / 36 / 42 (gardiens 1 à 4) |
| Éclats | 3 à 5 par combat à la fois, propres au joueur (invisibles et non saisissables par les autres), réapparition 2 à 3 s, portée identique à la collecte |
| Phases | 100–66 %, 66–33 %, 33–0 % : une attaque ajoutée par phase |
| Défense | Une fois par combat (à 50 %) : phase de protection propre à chaque gardien (§3) |
| Arène | Rayon ≈ 40 studs ; le gardien ne la quitte pas ; joueur hors de l'arène pendant 20 s ou déconnecté → combat abandonné, rien n'est attribué |
| Durée cible | 60–90 s |
| Rejouer | Après une victoire, nouveau combat possible ; récompense d'un nouveau combat **non décidée** (D-030) |

Affichage multijoueur : le serveur tient l'état ; chaque client dessine
**son** gardien, ses éclats et ses zones d'attaque. Les autres joueurs
présents dans le sanctuaire ne voient pas ce combat (option à évaluer en
T10.4 : silhouette discrète des combats d'autrui, sans interaction).

Réseau : signaux d'attaque envoyés **au seul joueur concerné**
(identifiant, type, position, heure de début). Aucun résultat de touche
n'est accepté du client. Nouveaux Remotes à prévoir : demande de saisie
d'éclat (identifiant seul, validée comme la collecte : distance,
fréquence, propriétaire du combat, état) et signaux d'état (serveur →
client).

## 3. Fiches

### 3.1 Forest Guardian — « Colosse des racines » (Green Valley)

| Rubrique | Proposition |
|---|---|
| Silhouette et identité | Colosse de bois noueux, mousse, yeux ambrés ; esprit protecteur de la vallée, pas menaçant |
| Modèle Polyfork | **Root Colossus** `root-colossus-base` (4 917 tri, 1 mat, 3,84 m, squelette Mixamo 22 os, clips Idle/Walk/Run) — alternative : Star-Barked Tree Golem `iridescent-treegolem-base` (4 670 tri) |
| Taille | ≈ 18 studs (échelle ≈ 1,3) |
| Animations | Idle, réveil, frappe au sol, balayage, défaite (effondrement en racines) ; Idle fourni, les autres à créer |
| Attaques | Frappe des racines (anneau 12 studs autour de lui) ; Lignes d'épines (3 lignes rayonnantes) ; Rafale de feuilles (phase 3 : cône qui repousse) |
| Défense | Écorce : à 50 %, invulnérable jusqu'à ce que 3 nœuds lumineux sur ses racines soient saisis |
| Comportement | Fixe, pivote vers son joueur ; rythme lent |
| Difficulté | 1/4 — tutoriel du combat |
| Récompense | Non fixée avant simulation (D-030) ; ressource sacrée du monde à usage double (vente ou améliorations) |

### 3.2 Sand Guardian — « Sentinelle des sables » (Golden Desert)

| Rubrique | Proposition |
|---|---|
| Silhouette et identité | Statue de grès en robe, ornements dorés, gardienne des ruines |
| Modèle Polyfork | **Stone Cathedral Statue** `cathedral-statue-base` (4 939 tri, 1 mat, 2,61 m, squelette Mixamo) recolorée grès et or — alternative : Lava Golem `furnace-golem-base` (4 991 tri) recoloré |
| Taille | ≈ 17 studs (échelle ≈ 1,8) |
| Animations | Idle, réveil (la statue s'anime), onde, rayon, défaite (s'effrite) |
| Attaques | Onde de sable (anneau qui s'élargit, à franchir en sautant) ; Rayon solaire (ligne qui balaie lentement) ; Sables mouvants (phase 3 : zones de ralentissement) |
| Défense | Tempête : à 50 %, invulnérable ; les éclats sont cachés sous 4 monticules de sable à fouiller |
| Comportement | Fixe ; tourne lentement ; rythme moyen |
| Difficulté | 2/4 |
| Récompense | Non fixée avant simulation (D-030) ; ressource sacrée du monde à usage double (vente ou améliorations) |

### 3.3 Ice Guardian — « Troll du givre » (Frozen Peaks)

| Rubrique | Proposition |
|---|---|
| Silhouette et identité | Grand troll trapu à peau de glace fissurée, gardien du sommet |
| Modèle Polyfork | **Ember-Cracked Troll** `ashen-troll-base` (4 983 tri, 1 mat, 2,56 m, squelette Mixamo) recoloré glace — alternative spectaculaire : **Crystal Dragon** `crystal-dragon-base` (3 844 tri, quadrupède, parties rigides nommées sans squelette, clips Idle/Walk/Run/FireBreath) : animation Roblox plus coûteuse |
| Taille | ≈ 18 studs (échelle ≈ 2) |
| Animations | Idle, réveil, piétinement, souffle, défaite |
| Attaques | Pics de glace (4 cercles aléatoires) ; Souffle gelé (cône, ralentit) ; Avalanche (phase 3 : grand anneau avec 3 zones sûres) |
| Défense | Armure de glace : à 50 %, chaque éclat demande 2 saisies (dégel puis prise) |
| Comportement | Fait 1 pas vers son joueur à chaque phase (reste dans l'arène) |
| Difficulté | 3/4 |
| Récompense | Non fixée avant simulation (D-030) ; ressource sacrée du monde à usage double (vente ou améliorations) |

### 3.4 Mystic Guardian — « Gardien des étoiles » (Mystic World)

| Rubrique | Proposition |
|---|---|
| Silhouette et identité | Astronome-prêtre très grand, robe violette, constellations |
| Modèle Polyfork | **Starkeeper** `starkeeper-base` (4 992 tri, 1 mat, 2,06 m, squelette Mixamo) — alternative plus douce pour un jeune public : **Crystal-Antlered Spectral Stag** `spectral-stag-d19dc1` (2 726 tri, 2 mat, quadrupède à parties rigides) |
| Taille | ≈ 20 studs (échelle ≈ 2,7) ; vérifier que l'allure n'est pas effrayante (cible tout public) |
| Animations | Idle (lévitation), réveil, invocation, téléportation, défaite (dissolution) |
| Attaques | Pluie d'étoiles (6 petits cercles) ; Orbes en orbite (2 sphères qui tournent autour de lui) ; Attraction (phase 3 : tire les joueurs vers le centre, puis anneau) |
| Défense | Déphasage : à 50 %, les éclats apparaissent sur les plateformes flottantes de l'arène |
| Comportement | Se téléporte entre 3 points de l'arène à chaque phase |
| Difficulté | 4/4 |
| Récompense | Non fixée avant simulation (D-030) ; ressource sacrée du monde à usage double (vente ou améliorations) |

## 4. Récompenses (D-030)

- **Aucune valeur fixée** avant simulation et validation économique :
  Coins, quantité de ressource sacrée, conditions d'un nouveau combat.
- Entrées de simulation seulement (T10.0, retirées comme valeurs) :
  ≈ 3 min du revenu cible du monde, soit 500 / 1 500 / 6 000 / 20 000 Coins,
  avec ou sans délai entre deux récompenses. Un délai personnel ne serait
  pas persistable en v3 (D-029) : il resterait en mémoire de session ou
  demanderait une proposition v4.
- Première victoire : accès permanent au sanctuaire (D-028), entrée de
  Journal, succès éventuel (support de persistance : D-029).

## 5. Risques

| Risque | Mesure |
|---|---|
| Animations : seuls Idle/Walk/Run fournis (clips CC0) | Création dans l'Animation Editor ; import du squelette testé en T10.4 |
| Rig Roblox : maillage skinné 22 os, liaison rigide | Tester import FBX/GLB → `Bone` + `AnimationController` |
| Plusieurs combats simultanés dans un même sanctuaire | Un modèle par client (rendu local) ; serveur : état léger par joueur, 10 Hz pendant le combat seulement |
| Ferme de récompenses en rejouant | Récompense d'un nouveau combat décidée après simulation (D-030) |
| Frustration mobile | Zones annoncées 1,5 s, pas de mort, étourdissement court |
| Persistance de la victoire en v3 | Support à proposer (D-029) : `achievements` ou `collection.discoveredResources` |
