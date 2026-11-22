# T10.1 — Mesure Galaxy A23 avant / après prototype (fiche)

Date : 2026-11-22 — Statut : **NOT TESTED sur appareil** (relevés à faire
par le propriétaire sur le téléphone ; aucune valeur ci-dessous n'est
inventée). Protocole : `T10_PERFORMANCE_BUDGET.md` §4. Publication privée
des deux variantes autorisée par le propriétaire le 2026-11-22.

## 0. Variantes mesurées

Même code (dépôt T10.1, synchronisé par Rojo), même place de test
93404872714886, `StreamingEnabled` désactivé, imports écartés du monde
(`ServerStorage._T10_1_Imports`, non envoyés aux clients).

| Variante | Réglage du place | Rendu des 44 nœuds concernés |
|---|---|---|
| **AVANT** | `ServerStorage.ResourceTemplates` renommé `_ResourceTemplates_OFF` | Formes primitives (repli du chargeur) |
| **APRÈS** | `ServerStorage.ResourceTemplates` (4 modèles GLB corrigés) | Modèles : 16 feuilles, 12 cuivre, 12 argent, 4 améthystes (72 MeshParts) |

Procédure : je règle la variante dans Studio ; le propriétaire publie
(Fichier → Publier sur Roblox, expérience privée), relève sur l'A23,
puis on passe à l'autre variante. Noter la version publiée de chacune.

## 1. Conditions (à remplir)

| Champ | AVANT | APRÈS |
|---|---|---|
| Version du place publiée | non publiée | version cloud courante, identique octet pour octet à `places/T10_1_prototype.rbxl` (modèles actifs) |
| Version Android / Roblox | | |
| Réglage graphique (auto, puis niveau fixe noté) | | |
| Batterie > 50 % / économie d'énergie désactivée | | |
| Date et heure | | |

## 2. Relevés appareil (console `/console`)

| Mesure | Cible | AVANT 1 j. | APRÈS 1 j. | AVANT 4 j. | APRÈS 4 j. | Écart | Statut |
|---|---|---|---|---|---|---|---|
| FPS moyen | ≥ 45 | | | | | | NOT TESTED |
| FPS minimal (pics exclus) | ≥ 30 | | | | | | NOT TESTED |
| Mémoire totale (Mo) | ≤ 1 000 ; écart ≤ +15 % | | | | | | NOT TESTED |
| `GraphicsMeshParts` (Mo) | à relever | | | | | | NOT TESTED |
| `GraphicsParts` (Mo) | à relever | | | | | | NOT TESTED |
| `GraphicsTexture` (Mo) | à relever | | | | | | NOT TESTED |
| `Instances` (Mo) | à relever | | | | | | NOT TESTED |
| Réception réseau (ko/s) | ≤ 30 | | | | | | NOT TESTED |
| Cœur serveur / Heartbeat | à relever | | | | | | NOT TESTED |
| Mystic World 15 min : mémoire début → fin | dérive ≤ 10 % | | | — | — | | NOT TESTED |

Parcours par monde (3 min) : arrivée → ressources → 20 collectes → vente →
portail. Noter tout à-coup visible au rebond de réapparition, à l'éclat de
collecte et à l'arrivée sur une île (chargement des modèles).

Régression : écart hors cible = bloquant pour la suite de T10.1
(CLAUDE.md 14 : mesurer, identifier le poste dominant, corriger,
remesurer).

## 2 bis. Test propriétaire sur iPhone 12 Pro (2026-11-22)

Rapporté par le propriétaire : « feuille visible et collectée », test
déclaré validé. Variante réellement publiée : **APRÈS** (version cloud
courante vérifiée identique à `places/T10_1_prototype.rbxl` : 4 gabarits
actifs, imports écartés, `StreamingEnabled` désactivé).

| Point | Résultat |
|---|---|
| Feuille modélisée visible sur mobile | **OK** (propriétaire, iPhone 12 Pro) |
| Collecte d'une feuille modélisée sur mobile | **OK** (propriétaire) |
| Autres ressources (cuivre, argent, améthyste) sur mobile | non rapporté |
| Relevés chiffrés (FPS, mémoire, réseau) | non fournis : **NOT TESTED** |
| Galaxy A23 (appareil de référence) | **NOT TESTED** |
| Variante AVANT sur appareil | non publiée : **NOT TESTED** |

L'iPhone 12 Pro (A14, 6 Go) est nettement plus puissant que l'A23 : ce
test valide le rendu et la collecte sur un écran mobile tactile, pas le
budget de performance de l'appareil de référence.

## 3. Complément Studio (PC, **non représentatif** du mobile)

Relevé le 2026-11-22 en Play Studio (client local, 1 joueur), même place,
même code, les deux variantes à la suite :

| Mesure (client Studio) | AVANT | APRÈS | Écart |
|---|---|---|---|
| Visuels client (`ClientResourceVisuals`) | 0 | 44 | +44 |
| MeshParts dans Workspace (avatar compris) | 17 | 89 | **+72** |
| Instances dans Workspace | 3 353 | 3 469 | +116 |
| `GraphicsMeshParts` (Mo) | 4,5 | 5,3 | +0,8 |
| `GraphicsParts` (Mo) | 0,6 | 2,4 | +1,8 |
| `GraphicsTexture` (Mo) | 27,0 | 27,0 | 0 |
| `GraphicsParticles` (Mo) | 12,0 | 12,1 | ≈ 0 |
| `Instances` (Mo) | 110,1 | 109,7 | ≈ 0 |
| Mémoire totale (Mo) | 1 415 | 1 752 | non interprétable* |
| FPS (RenderStepped, 5 s) | 16,6 | 60,0 | non interprétable* |

\* La mémoire totale inclut tout le processus Studio (éditeur, plugins,
historique) et varie d'une session de jeu à l'autre ; le FPS dépend du
premier plan de la fenêtre Studio pendant la mesure. Seuls les postes
graphiques ciblés sont comparables, et seulement en ordre de grandeur.

Lecture : le surcoût graphique des 4 modèles est de l'ordre de +2,6 Mo
(meshes + parts) en Studio, pour 72 MeshParts ; aucune texture ajoutée
(couleurs de sommets). À confirmer sur l'A23.

Captures comparatives (même position de caméra, Play Studio) :
`T10_1_captures/avant_*.jpg` et `T10_1_captures/apres_*.jpg`, une par
monde.

Relevé d'origine (mode Édition, version 105, avant T10.1) : 2 658
instances sous Workspace, 2 265 BaseParts, 0 MeshPart, 259 parts Neon,
0 lumière dynamique, `GlobalShadows` et `StreamingEnabled` désactivés.
