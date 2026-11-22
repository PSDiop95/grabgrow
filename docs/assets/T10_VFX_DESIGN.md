# T10 — Conception des effets visuels des ressources

Date : 2026-11-21, révisé le 2026-11-22 — Statut : **VALIDÉ (T10.0,
D-027)**, non implémenté. V-01 est corrigé et testé dans T10.1 ;
`StreamingEnabled` inchangé sans mesures et validation.

## 1. Existant (code au 2026-11-21)

| Effet | Où | Comportement actuel |
|---|---|---|
| Apparence | `Systems/ResourceNodes` + `ResourceVisualConfig` (serveur) | Un `Part` primitif par nœud, ancré, `CanCollide/CanTouch` faux, `CanQuery` vrai ; jusqu'à 4 pièces `details` enfants |
| Rareté | `ResourceVisualConfig` | Neon pour Rare/Épique ; `ParticleEmitter` « Sparkle » (4 particules/s) sur les 3 Épiques |
| Disparition | `ResourceNodes.applyState` (serveur) | `Transparency = 1`, `CanQuery` faux, émetteur coupé (répliqué) |
| Collecte | `FeedbackController.collectEffect` (client) | Copie Neon du **Part principal seulement**, 8 particules (3 réduits), glisse vers le joueur 0,3 s ; 6 effets simultanés max |
| Réapparition | `CollectionController.onAvailableChanged` (client) | Rebond de taille 0,3 → 1 en 0,25 s, **Part principal seulement** |
| Ciblage | `CollectionController` | `Highlight` + `BillboardGui` sur le Part visé |

Défauts relevés (existants, non corrigés en T10.0) :

- **V-01** : le rebond de réapparition et l'éclat de collecte ignorent les
  pièces `details` (Frozen Peaks, Mystic World) : les détails réapparaissent
  à pleine taille pendant que le corps grandit.
- **V-02** : aucune animation d'attente (flottement, rotation) ; les
  ressources se lisent comme du décor.
- **V-03** : l'apparence est construite côté serveur ; tout changement
  visuel futur (meshes, animation) passerait par la réplication.

## 2. Principe proposé : séparer cible serveur et visuel client

1. **Serveur (inchangé dans son rôle)** : un `Part` par nœud = cible
   (hitbox) avec les mêmes attributs (`NodeId`, `ResourceType`, `WorldId`,
   `Available`) et la même position. Il devient invisible
   (`Transparency = 1`) quand un modèle visuel existe pour la ressource.
   Aucune règle de collecte ni identifiant modifié.
2. **Client** : un `ResourceVisualController` crée pour chaque nœud un
   modèle visuel local (clone d'un modèle de
   `ReplicatedStorage.ResourceModels.<resourceType>`), suit l'attribut
   `Available` et anime localement.
3. **Repli** : si le modèle manque, le Part reste visible tel qu'aujourd'hui
   (comportement T8 conservé).

Bénéfices : animation sans coût réseau ni serveur ; préférence « Effets
réduits » respectée par joueur ; meshes Polyfork interchangeables sans
toucher à la logique. Coûts : `Highlight`, éclat de collecte et rebond
doivent viser le modèle visuel (adaptation de `CollectionController` et
`FeedbackController`) ; préchargement des meshes (`ContentProvider`).

## 3. Configuration (extension proposée, non écrite)

`ResourceConfig` : **inchangé** (rareté lue, jamais écrite).
`ResourceVisualConfig` : champs facultatifs ajoutés, données simples
(testables sous Lune) :

```lua
green_crystal = {
    -- champs actuels conservés (repli primitif)
    shape = "Block", size = { 1.2, 2.6, 1.2 }, ...,
    model = "green_crystal",          -- nom dans ReplicatedStorage.ResourceModels
    modelScale = 0.45,                -- appliqué au clone
    hitboxSize = { 2.4, 2.2, 2.4 },   -- Part serveur invisible
    idle = { bob = 0.25, bobPeriod = 2.4, spin = 20, pulse = 0 },
}
```

Nouveau module de données `Shared/Config/RarityVisualConfig.lua`
(présentation par rareté, aucune valeur économique) :

| Rareté | Flottement | Rotation | Pulsation | Particules d'attente | Éclat de collecte | Réapparition |
|---|---|---|---|---|---|---|
| Common | 0,15 stud / 2,8 s | — | — | — | 6 (réduit 3) | Rebond 0,25 s |
| Uncommon | 0,2 / 2,6 s | 10°/s | — | — | 8 (3) | Rebond + bouffée 4 |
| Rare | 0,25 / 2,4 s | 20°/s | Neon ±10 % luminosité | — | 10 (4) | Rebond + bouffée 6 |
| Epic | 0,3 / 2,2 s | 25°/s | Échelle ±4 %, 1,6 s | Émetteur existant, 4/s | 14 (5) + anneau | Rebond + anneau 0,4 s |

Valeurs = hypothèses de confort, à valider sur Galaxy A23 et en effets
réduits (flottement et rotation coupés, pas d'émetteur d'attente).

## 4. Effets détaillés

- **Flottement / rotation / pulsation** : une seule connexion
  `RenderStepped` côté client ; CFrame calculée à partir de `os.clock()` et
  d'une phase par nœud (pas de synchronisation visible). Seuls les nœuds à
  moins de **60 studs** de la caméra sont animés, **24 au maximum**, mise à
  jour à **30 Hz** (un nœud sur deux par image à 60 FPS). Aucun `Tween` par
  nœud et par cycle.
- **Particules** : émetteurs d'attente seulement pour l'Épique (règle T8
  conservée). Éclats de collecte via `:Emit()` sur un émetteur réutilisé
  (pas d'instance créée par collecte) ; plafond global existant
  (`MaxCollectEffects = 6`).
- **Collecte** : éclat dimensionné par rareté (table ci-dessus) ; le modèle
  rétrécit et glisse vers le joueur (existant, appliqué au modèle entier).
- **Disparition** : rétrécissement 0,15 s puis masqué ; `Available = false`
  reste la vérité (serveur).
- **Réapparition** : rebond appliqué au **modèle complet** (corrige V-01) ;
  bouffée de 4 à 6 particules dès Peu commune.
- **Rareté** : indice redondant non coloré (accessibilité GDD 12) : vitesse
  de rotation et anneau au sol pour l'Épique ; pas de lumière dynamique, pas
  de `Beam` permanent.
- **Son** : inchangé (sons du `SOUND_MANIFEST`) ; un son Épique éventuel
  serait un ajout au manifeste.

## 5. Contraintes

- Aucun `PointLight`/`SurfaceLight`, `CastShadow = false` (règles T8).
- Pas de transparence partielle sur les meshes (règle T8.4).
- Aucun effet ne bloque ni ne retarde une demande de collecte ; le client
  n'envoie toujours que l'identifiant du nœud.
- Mesures avant/après : `performance/T10_PERFORMANCE_BUDGET.md`.

## 6. Découpage proposé

1. T10.1 : mesure de référence A23, tests d'import Polyfork (GLB et FBX),
   prototype du contrôleur visuel sur **une** ressource par monde (4),
   **correction et tests de V-01**, mesures après.
2. T10.2 : 16 autres ressources, `RarityVisualConfig` complet, tests.
3. Gardiens et sites sacrés : phases distinctes (voir `gameplay/`).
