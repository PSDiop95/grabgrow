# T10 — Conception des sites sacrés

Date : 2026-11-21, révisé le 2026-11-22 — Statut : **VALIDÉ (T10.0,
D-028)**, non implémenté. Aucune ressource n'est créée dans le code.

Révision 2026-11-22 : combats et déblocages **individuels** (D-028) ;
**accès permanent** au sanctuaire après la victoire (D-028) ; ressources
sacrées à **double usage**, vente ou améliorations (D-030) ; **schéma v3
conservé**, le schéma v4 proposé en T10.0 est retiré (D-029) ; aucune valeur
économique fixée (D-030).

## 1. Rôle

Un site sacré par monde : l'arène du gardien (`T10_GUARDIANS_DESIGN.md`)
et l'objectif de fin de monde. Il réutilise une zone **déjà construite**
en T8 pour limiter le coût de production.

| Monde | Site | Zone existante réutilisée | Gardien |
|---|---|---|---|
| Green Valley | Bosquet ancien | Au-delà de la zone avancée (Fruits sauvages, Cristal vert) | Colosse des racines |
| Golden Desert | Temple du soleil | Ruines et arche (T8.3) | Sentinelle des sables |
| Frozen Peaks | Sanctuaire du givre | Sommet (T8.4) | Troll du givre |
| Mystic World | Observatoire astral | Sanctuaire de l'archipel (T8.5) | Gardien des étoiles |

Le sommet de Frozen Peaks et le sanctuaire de Mystic World portent déjà
le piédestal de la ressource Épique (`diamondSpot`, `coreSpot`) : l'arène
se place **à côté**, sans déplacer ce point de spawn.

## 2. Accès

- **Avant la première victoire** : monde débloqué **et** les 5 ressources
  du monde découvertes dans le Journal (données v3 existantes, aucun champ
  nouveau). Contrôle serveur ; la barrière d'arène (champ semblable aux
  portails) ne laisse entrer que les joueurs qui remplissent la condition ;
  les autres voient un message localisé.
- **Après la victoire** : accès **permanent** pour ce joueur, quelles que
  soient les évolutions futures du Journal. Persistance de la victoire :
  support à choisir dans le v3 (D-029, §8).
- L'accès d'un joueur ne dépend jamais d'un autre joueur.

## 3. Activation

- Un autel au centre ; le joueur éligible maintient « Prendre » 2 s
  (même bouton, même portée que la collecte) → son combat passe en
  `Awakening`.
- Chaque joueur active **son propre** combat ; plusieurs joueurs peuvent
  combattre en même temps dans le même sanctuaire, chacun contre son
  gardien (rendu local, état serveur par joueur).

## 4. Combat

Voir `T10_GUARDIANS_DESIGN.md` §2 et §3. Arène d'environ 40 studs, sans
pièce mobile ni physique simulée ; décor ≤ 300 Parts ou MeshParts par
site.

## 5. Déblocage et progression

- Victoire : déblocage **individuel** de l'accès permanent, entrée de
  Journal « Sacré », annonce locale, succès éventuel.
- Aucune condition de déblocage de monde modifiée (WorldConfig inchangé).
- Proposition ultérieure (non décidée) : les 4 gardiens vaincus comme
  objectif de fin de contenu affiché dans le Journal.

## 6. Ressources sacrées (non créées)

| Identifiant proposé | Nom FR / EN | Monde |
|---|---|---|
| `sacred_heartwood_seed` | Graine de Cœur-de-Bois / Heartwood Seed | Green Valley |
| `sacred_sun_relic` | Relique solaire / Sun Relic | Golden Desert |
| `sacred_frost_heart` | Cœur de givre / Frost Heart | Frozen Peaks |
| `sacred_astral_essence` | Essence astrale / Astral Essence | Mystic World |

Règles (D-030) :

- **Double usage** : vente **ou** dépense dans les améliorations.
- **Aucune valeur fixée** : prix de vente, coût d'amélioration, quantité
  obtenue, mode d'obtention (victoire seule, ou aussi collecte dans le
  sanctuaire après la victoire) : après simulation et validation.
- Conséquences techniques à autoriser :
  - Vendable ⇒ clé de `ResourceConfig`, stockée dans
    `inventory.resources` (compatible v3 sans migration, D-008), **comptée
    dans le sac** et ajoutée au catalogue du Journal (le pourcentage de
    complétion de chaque monde change : 6 ressources au lieu de 5) ;
    condition d'accès du §2 à garder sur les 5 ressources ordinaires.
  - Améliorations ⇒ nouvelle règle de coût en ressources dans
    `UpgradeService`/`UpgradeConfig` (aujourd'hui Coins seulement).
- Modèle 3D : à rechercher plus tard (`geode-dragon-egg` exclu : confusion
  avec les œufs de Pets).

## 7. Réapparition du gardien

Pas de réapparition par serveur : chaque joueur a son propre gardien,
toujours disponible pour lui (`Dormant`) hors combat en cours. La
possibilité et la récompense d'un nouveau combat après la victoire sont
décidées avec la simulation (D-030).

## 8. Récompenses individuelles et persistance (v3)

- Récompenses calculées par le serveur **pour le joueur qui a gagné son
  combat**, sans partage ni « dernier coup ». Montants : D-030.
- Attribution unique par identifiant de combat serveur, journalisée
  (`GuardianReward:<guardianId>`), sauvegarde demandée après attribution
  (comme D-023).
- Persistance dans le **schéma v3** (D-029), sans migration :

| Donnée | Support v3 possible | Limite |
|---|---|---|
| Victoire / accès permanent | `achievements["guardian_<monde>"] = true` (recommandé) ou `collection.discoveredResources[...]` | Booléen seulement |
| Ressource sacrée possédée | `inventory.resources[sacredId]` | Comptée dans le sac |
| Délai entre récompenses, nombre de victoires | **Impossible en v3** | Mémoire de session, ou proposition v4 distincte |

- Toute évolution v4 : proposition et autorisation distinctes (D-029).
- Tests prévus au moment du lot : clé de victoire relue après
  reconnexion, profil v3 existant sans clé, attribution unique,
  déconnexion pendant l'attribution, serveur ancien conservant la clé
  inconnue (D-008).
