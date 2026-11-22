# T10.3 — Gardiens et sites sacrés : rapport

Date : 2026-11-22 — Statut : **VALIDÉ par le propriétaire** (2026-11-22).
Persistance option A et récompense sacrée implémentées (D-035). Tests
manuels M1-M14, L1-L7 et captures : résultats non transmis, non consignés
comme exécutés. Vente et consommation des unités sacrées : non conçues.

Décisions appliquées : D-028, addendum propriétaire T10-D01 à T10-D03
(2026-11-22), consignées en **D-034**. Aucune modification de `DataSchema`,
de l'économie, des 20 ressources ni de `GrabAndGrow.rbxl`. Aucun commit.

## 1. Conflit relevé et résolution

Le prompt T10.3 demandait un combat coopératif (gardien partagé). D-028
imposait des combats individuels. Question posée ; réponse du propriétaire :
addendum T10-D01 à T10-D03 — **combats individuels**, gardien
**visuellement commun**, états isolés, accès permanent après victoire,
ressources sacrées à double usage sans valeur avant validation.

## 2. Architecture

| Module | Rôle |
|---|---|
| `Shared/Config/GuardianConfig` | Gardiens, attaques, phases, durées, sites, identifiants sacrés (`enabled = false`). Hypothèses de gameplay, aucune valeur économique |
| `Shared/Util/GuardianRules` | Règles pures partagées : phases, formes d'attaque (`ring`, `circle`, `line`, `cone`), éclats, arène, accès aux sites, place dans le sac |
| `ServerOnlyConfig/GuardianSecurityConfig` | Marges, limites de fréquence, taille des payloads |
| `Services/GuardianCombatService` | Un état de combat **par joueur** : réveil, phases, annonces, impacts jugés sur la position serveur, étourdissement, victoire, réapparition par joueur, abandon |
| `Services/SacredSiteService` | Accès, activation à l'autel, attribution unique de la victoire (par identifiant de combat), vue d'affichage. Victoires dans un magasin **de session** injecté |
| `Services/SacredResourceService` | Collecte sacrée : contrôles complets, puis `NOT_AVAILABLE` tant que T10-D03 n'est pas validée |
| `Systems/SacredSites` | Lecture des positions de la carte (centre, autel, nœuds) |
| `Controllers/GuardianController` | Affichage seulement : animation locale du gardien, télégraphies, éclats, barre de vie, messages, poussée du personnage, cibles du bouton Grab |
| `CollectionController` | Nouvelle API `addTargetSource` : le bouton Grab vise aussi éclats, autel et nœuds sacrés |
| `Remotes` | `RequestGuardianActivate {siteId}`, `RequestGuardianStrike {shardId}`, `RequestSacredCollect {nodeId}`, `GuardianEvent` (serveur → joueur concerné) ; 5 codes |
| `tools/studio/build_sacred_sites.luau` | Construction rejouable des 4 sites |

`GuardianService` n'a pas été créé : son rôle (orchestration) est tenu par
`Bootstrap` et `SacredSiteService`, sans service vide.

### Gardien commun, états isolés (T10-D02)

- Serveur : **un** modèle statique et ancré par site (`Workspace.SacredSites.<site>.Guardian`), jamais déplacé par le serveur. Aucun état global de gardien.
- Client : le joueur en combat anime **localement** ce modèle (orientation, préparation, frappe, défaite, disparition, réapparition). Une modification client d'une pièce répliquée ne se réplique pas : chaque joueur voit son propre état.
- Vérifié dans Studio : pendant que le client masquait le gardien vaincu (`LocalTransparencyModifier = 1`), le serveur conservait le pivot et la transparence d'origine.
- Coût : 0 modèle supplémentaire par joueur ; éclats et télégraphies sont des pièces locales temporaires.
- Limite : deux joueurs qui combattent au même site voient chacun le gardien tourné vers eux ; l'autre joueur semble esquiver des zones invisibles. Acceptable pour un PvE individuel ; option future : silhouette des combats d'autrui.

## 3. Boucle de combat

1. Accès : monde débloqué **et** 5 ressources du monde découvertes, ou victoire déjà obtenue (accès permanent, prioritaire).
2. Activation à l'autel (≤ 12 studs + 4 de marge, position serveur).
3. Réveil 3 s, puis 4 éclats de faiblesse.
4. Annonce de l'attaque (zone au sol qui se densifie, projectiles qui tombent, gardien qui se penche) : 1,5 à 1,7 s d'esquive.
5. Impact jugé sur la position **serveur** ; touché : étourdi 1,5 s (aucune saisie) et repoussé. Aucun PV d'avatar, sac ou Coin touché.
6. Saisie d'un éclat (bouton Grab) : 1 dégât fixé par le serveur ; cadence 0,35 s.
7. Phases à 66 % et 33 % : attaques plus fréquentes et nouvelles attaques.
8. PV à 0 : victoire unique, accès débloqué (session), gardien masqué localement.
9. Réapparition après 45 s **pour ce joueur**.
10. Abandon sans attribution : sortie de l'arène > 20 s, personnage absent ou réapparu, voyage, départ.

| Gardien | PV | Attaques (phase 1 → 3) |
|---|---|---|
| Forest (Sanctuaire des racines) | 24 | Frappe des racines (anneau 12) ; Jaillissement de racines (ligne) |
| Sand (Temple du soleil) | 30 | Balayage (cône 100°) ; Jet de rochers (3 disques sur le joueur) |
| Ice (Autel des glaces) | 36 | Charge (ligne 34) ; Vague de glace (anneau 10–22) ; Sol gelé (zones restant 3 s) |
| Mystic (Sanctuaire astral) | 42 | Traits d'étoiles (4 disques) ; Nova astrale (anneau 8–28, refuge près du gardien) |

Solo : faisable par construction (PV fixes, pas de mise à l'échelle). Durée
mesurée avec un script de test qui n'esquive pas : 55–57 s (Forest).
Cible 60–90 s : à régler en test réel.

## 4. Sites sacrés

| Site | Monde | Position | Environnement |
|---|---|---|---|
| Sanctuaire des racines | Green Valley | (-175 ; 175), pont depuis l'angle nord-ouest | Herbe, pierres moussues, racines géantes, champignons lumineux |
| Temple du soleil | Golden Desert | (2850 ; 150) | Grès, colonnes et chapiteaux dorés, disque solaire |
| Autel des glaces | Frozen Peaks | (-2850 ; 150), près du sommet | Glacier, pics de glace, congères, bassin gelé |
| Sanctuaire astral | Mystic World | (10 ; 3168), plateforme flottante reliée au sanctuaire | Ardoise violette, pylônes et orbes d'étoiles, anneaux astraux |

Chaque site : plateforme d'arène (rayon 32, arène 28, anneau Neon de
limite), autel côté pont, gardien en primitives (≈ 18–20 studs),
terrasse de récompense hors de l'arène avec 3 nœuds sacrés. 48 à 60
BaseParts par site (budget 300), tout ancré, aucune lumière, aucun
émetteur, aucun chevauchement avec la carte existante (contrôlé par le
script). Les îles étant encombrées, les sites sont sur des plateformes
dédiées plutôt que dans les zones T8 prévues par T10.0.

Gardiens en primitives : repli. Les modèles Polyfork de la sélection T10.0
demandent un import manuel et des animations à créer (lot à part).

## 5. Sécurité

Le client n'envoie que des identifiants. Le serveur contrôle : limite de
fréquence, payload (champ unique, arguments en trop), profil, site connu,
monde, accès, position finie, distance, `MovementValidator`, propriété de
l'éclat (un éclat d'un autre joueur est inconnu), état du combat,
étourdissement, cadence. Dégâts, PV, touches, victoire et récompense ne
viennent jamais du client. Victoire attribuée une fois par identifiant de
combat, au seul joueur qui l'a menée. Journal : `[Guardian]
GuardianReward:<gardien> user=… combat=… first=… persistent=false`.

## 6. Tests

| Test | Type | Résultat |
|---|---|---|
| Lune (`lune run tools/run_tests.luau`) | Automatisé | **OK** : 24 suites, dont `GuardianTests` 27 cas |
| Tests Studio au démarrage du Play | Automatisé | **OK** (mêmes suites) |
| `luau-lsp analyze` strict (sourcemap temporaire) | Automatisé | **OK**, code 0, aucune erreur |
| `rojo build` (fichier temporaire) | Automatisé | **OK** |
| Construction des sites (Edit) | Studio | OK : 4 sites, 0 chevauchement |
| Combat solo complet (Forest) | Studio, Play, client MCP | OK : réveil, 4 éclats, 24 saisies, 6 touches + étourdissement, phases 1→3, victoire 57 s, `sites:Root=unlocked` |
| Nouveau joueur à l'autel | Studio | OK : `REQUIREMENT_NOT_MET` ; autels : « Débloquez d'abord ce monde », « Ressources du monde trouvées : 0/5 » |
| Saisie hors distance | Studio + Lune | OK : `TOO_FAR`, PV intacts |
| Saisie trop rapide | Lune | OK : `COOLDOWN` puis `RATE_LIMITED` |
| Falsification des dégâts (`damage`, argument en trop) | Studio + Lune | OK : `INVALID_TARGET` |
| Falsification des récompenses (`victory = true`, victoire rejouée) | Studio + Lune | OK : refusées |
| Éclat d'un autre joueur | Lune | OK : refusé, combat de l'autre intact |
| Gardien déjà vaincu | Studio + Lune | OK : `NOT_IN_COMBAT`, puis `GUARDIAN_RESPAWNING`, nouveau combat après 45 s |
| Double attribution | Lune | OK : une victoire par combat ; seconde victoire non « première » |
| Joueur non participant près de l'arène | Lune | OK : ni victoire ni message |
| Deux joueurs simultanés (dégâts, victoires, déblocages indépendants) | Lune | OK |
| Quatre joueurs | Lune | OK : 4 combats, 4 victoires distinctes |
| Déconnexion pendant le combat | Lune | OK : rien attribué, état effacé |
| Sortie de l'arène, personnage absent | Lune | OK : abandon, aucune victoire |
| Nouvelle défaite après déblocage | Lune | OK : accès conservé |
| Monde verrouillé | Lune | OK : `WORLD_LOCKED` |
| Ressource sacrée (production) | Studio + Lune | OK : `NOT_AVAILABLE`, message « bientôt disponible » ; champ `amount` refusé |
| Ressource sacrée et sac plein | Lune (définitions de test) | OK : `INVENTORY_FULL`, rien ajouté |
| Isolation visuelle | Studio | OK : modèle serveur inchangé pendant l'animation locale |
| Reconnexion après déblocage | Lune | Résultat attendu en v3 : **perdu** (session) ; conservé avec un magasin persistant injecté |
| Deux joueurs réels (Local Server) | — | **NON TESTÉ** |
| Mobile, Galaxy A23, émulateur | — | **NON TESTÉ** |
| Captures | — | **NON FAITES** : viewport noir via MCP (Studio en arrière-plan), comme en T10.2 |
| Vente, consommation, double vente, double achat, déconnexion pendant transaction | — | **NON IMPLÉMENTÉS** : attendent T10-D03 et la persistance |

## 7. Persistance (option A, implémentée le 2026-11-22)

Choix du propriétaire (2026-11-22) : **option A en schéma v3**, aucune
migration v4 (D-029). Proposition technique, audit de compatibilité et
tests de préservation : `T10_3_PERSISTENCE_OPTION_A.md`. Clé
`achievements["sanctuary_<siteId>"] = true`, posée une fois à la première
victoire ; aucun autre consommateur de `achievements` n'est affecté
(audit du code). L'option B (v4) est abandonnée.

## 8. Ressources sacrées (D-035, récompense implémentée ; vente et valeurs non)

Simulation : `T10_3_SACRED_ECONOMY_SIMULATION.md`. Décisions validées le
2026-11-22 (`T10_3_DECISION_SYNTHESIS.md`, D-035) : 3 unités par site à la
première victoire (R1), 1 place de sac par unité, catégorie « Sacrée »,
configuration dédiée hors `ResourceConfig` (Journal à 20/20), réclamation
atomique à la terrasse avec droit conservé si le sac est plein, S2 (k = 2)
comme hypothèse de test. Valeurs provisoires ; `ResourceConfig` inchangé.

Identifiants réservés (inchangés) : `sacred_heartwood_seed`,
`sacred_sun_relic`, `sacred_frost_heart`, `sacred_astral_essence`.

Améliorations spéciales (conception, non autorisées) :

| Amélioration | Effet proposé | Coût proposé |
|---|---|---|
| Sac sacré | +10 / +20 / +30 % de capacité au-delà du Backpack max | 3 / 5 / 8 ressources sacrées du monde 2, 3, 4 |
| Grabber sacré | −5 / −10 % d'intervalle | 3 / 6 ressources (mondes 3, 4) |
| Magnet sacré | +2 / +4 studs | 3 / 6 (mondes 1, 2) |
| Boussole des sanctuaires (exploration) | Indique les ressources rares du monde | 2 ressources du monde 1 |

Transactions (vente et achat) : une seule mutation `PlayerDataService.Update`
(retrait + crédit ou retrait + niveau), refus sans modification partielle,
protection par limite de fréquence et identifiant de demande.

## 9. Points à surveiller

- Persistance (option A) implémentée : victoire et récompense sauvegardées dans `achievements` ; reconnexion vérifiée en Lune et Studio (MemoryDataStore), pas encore sur DataStore réel.
- Récompense : 3 unités sacrées une fois par site, réclamées à la terrasse ; aucun Coin ; vente et consommation des unités non conçues.
- Poussée appliquée par le client : compatible avec `MovementValidator` en Studio (aucune correction observée), à vérifier avec latence mobile.
- Équilibrage (PV, cadences, zones) non mesuré sur joueurs réels.
- Contrôle visuel des sites et des gardiens à faire (Studio au premier plan, mobile).
- Place enregistré : non. Les sites existent dans le place de test ouvert (non sauvegardé) ; `tools/studio/build_sacred_sites.luau` les reconstruit à l'identique.

## 10. Prochaine étape

1. Examiner les tests P1 à P15 (`T10_3_PERSISTENCE_OPTION_A.md` §4), puis autoriser ou non l'implémentation (option A, D-035).
3. Exécuter `docs/tests/T10_3_TEST_PLAN.md` : Local Server à 2 joueurs, recul avec latence, Galaxy A23, captures.
4. T10.4 seulement après autorisation.
