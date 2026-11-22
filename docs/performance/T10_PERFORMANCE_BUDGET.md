# T10 — Budget graphique et protocole de mesure

Date : 2026-11-21, révisé le 2026-11-22 — Statut : **VALIDÉ (T10.0)** ;
mesure de référence à exécuter en ouverture de T10.1. `StreamingEnabled`
reste désactivé : toute modification exige des mesures avant/après et
une validation (décision du 2026-11-22). Aucune mesure sur
appareil n'a encore été faite (réserve ouverte depuis T5 et T8, D-024 D1).
Tous les seuils sont des **cibles internes à mesurer**, pas des limites
Roblox.

## 1. Appareil de référence

**Samsung Galaxy A23** (Snapdragon 680, GPU Adreno 610, 4 Go de RAM selon
la variante, écran 6,6 pouces 1080 × 2408). Version Android et réglage
graphique Roblox à noter à chaque mesure. Le modèle exact du téléphone
testé en T5 n'a pas été communiqué (`tests/T5_DEVICE_MATRIX.md`).

## 2. Situation actuelle (code et rapports)

| Élément | Valeur | Source |
|---|---|---|
| Parts du place (édition) | ≈ 2 265 | T8.7 |
| Nœuds de ressources | 160 (40 par monde) | scripts `tools/studio/build_*` |
| Parts des nœuds (principaux + détails) | 354 (160 + 82 FP + 112 MW) | `ResourceVisualConfig` |
| Pièces Neon des nœuds | ≈ 37 | `ResourceVisualConfig` |
| `ParticleEmitter` permanents | 3 (Épiques, 4/s) | `ResourceVisualConfig` |
| Lumières dynamiques | 0 ; `GlobalShadows` désactivé | T8.7 |
| `StreamingEnabled` | **désactivé** : les 4 îles sont chargées en permanence | T8.7 |
| Boucles | Heartbeat client limité ; boucle serveur 4 Hz | T8.7 |

## 3. Budgets cibles

### Ressources (T10.1–T10.2)

| Poste | Cible |
|---|---|
| Triangles par modèle | 100–800 (GDD 14.6) |
| Triangles des nœuds par monde | ≤ 30 000 (sélection actuelle : 19 500 à 29 300) |
| Triangles des nœuds, 4 mondes | ≤ 120 000 (sélection : ≈ 95 000) |
| Meshes distincts | ≤ 20 (un par ressource, réutilisés par toutes les instances) |
| Matériaux par modèle | ≤ 2 |
| Instances par nœud | Hitbox + ≤ 3 MeshParts (visuel client) |
| Transparence partielle | Aucune |

### VFX

| Poste | Cible |
|---|---|
| Émetteurs d'attente | Pool client ≤ 8 (Peu commun et plus, rayon 45 studs) ; ≤ 3 en qualité basse (Épique) ; 0 en Effets réduits (révisé T10.2, D-032) |
| Auras (disques opaques, Épique) | ≤ 3, rayon 90 studs |
| Nœuds animés simultanément | ≤ 24, rayon 60 studs, mise à jour 30 Hz |
| Éclats (collecte, réapparition) | Pool de 6 ; copies Neon de collecte ≤ 6 (existant) |
| Particules visibles au total | ≤ 150 |
| Lumières dynamiques, `Beam`, ombres | 0 |

### Gardiens et sites

| Poste | Cible |
|---|---|
| Triangles par gardien | ≤ 5 000 (candidats : 2 726 à 4 992) |
| Gardiens animés à la fois | 1 par client (son propre combat, D-028) ; animation seulement en combat ou à < 80 studs |
| Os | ≤ 31 (squelette Polyfork : 22 + 9 visage) |
| Décor par site | ≤ 300 Parts/MeshParts, ≤ 8 000 triangles |
| Zones d'attaque simultanées | ≤ 8, décor plat sans transparence animée coûteuse |
| Réseau gardien | Signaux d'attaque ≤ 2/s, envoyés au seul joueur concerné ; aucun envoi par image |
| Serveur | État par joueur, 10 Hz pendant un combat, 0 hors combat ; mesurer avec 4 combats simultanés |

### Appareil (Galaxy A23, cibles)

| Mesure | Cible |
|---|---|
| FPS moyen | ≥ 45 |
| FPS minimal (pics exclus) | ≥ 30 |
| Mémoire client totale | ≤ 1 000 Mo, écart après/avant ≤ +15 % |
| Mémoire graphique meshes | à relever (pas de seuil avant la mesure de référence) |
| Réception réseau | ≤ 30 ko/s en jeu normal, ≤ 50 ko/s en combat |
| Session 15 min | Aucune dérive mémoire > 10 %, pas de chauffe bloquante |

## 4. Protocole de mesure (avant / après)

Mesure de référence **avant toute modification** (T10.1), puis après
chaque lot (ressources, VFX, gardien, site).

1. Même build (version du place notée), même appareil, batterie > 50 %,
   mode économie d'énergie désactivé, réglage graphique Roblox automatique
   puis niveau fixe noté.
2. Expérience privée (publication déjà autorisée en T9 D5) ; serveurs de
   **1** joueur puis **4** joueurs.
3. Parcours fixe de 3 min par monde : arrivée → zone de ressources →
   collecte de 20 unités → vente → portail. Gardien : un combat complet.
4. Relevés (console développeur `/console`) : onglet **Memory** (total,
   `GraphicsMeshParts`, `GraphicsTexture`, `Instances`, `PlaceMemory`),
   onglet **Network** (réception), **Server Stats** (cœur serveur,
   Heartbeat). FPS : compteur intégré de Roblox si disponible, sinon
   superposition de débogage limitée à Studio/test (à proposer en T10.1,
   jamais active en production).
5. Session longue : 15 min dans Mystic World (monde le plus chargé), mémoire
   au début et à la fin.
6. Studio, en complément (non représentatif) : MicroProfiler, nombre
   d'instances, triangles affichés (`Stats`).
7. Résultats consignés dans `docs/performance/` (une table par lot :
   avant, après, écart), avec la mention PASS / FAIL / NOT TESTED.

Règle : une régression supérieure aux cibles bloque le lot suivant ; on
mesure, on identifie le poste dominant, on corrige, on remesure (CLAUDE.md
14).
