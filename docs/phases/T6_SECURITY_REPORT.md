# T6 — Rapport de sécurité multijoueur et robustesse serveur

Date : 2026-11-13. Décision : D-019. Statut : **implémentation faite,
validation du propriétaire en attente** (T6 non clôturée).
Résultats de tests : `T6_MULTIPLAYER_TEST_REPORT.md`.

## 1. Vulnérabilités identifiées (étape A)

| # | Constat | Statut après T6 |
|---|---|---|
| V1 (A-26) | Position simulée par le client ; seul contrôle : trajet entre deux collectes (vitesse × 2 × t + 20 studs, ≈ 3,7 × la marche) | **Réduit** : MovementValidator (fenêtre glissante, téléportation, vertical) + contrôle avant collecte et vente |
| V2 (A-26) | « Reset » volontaire : `lastPosition = nil`, première collecte libre | **Corrigé** : référence = point d'apparition lu par le serveur ; suspension et historique conservés |
| V3 (A-26) | Vente sans contrôle de déplacement | **Corrigé** : même contrôle que la collecte |
| V4 (A-37) | `WalkSpeed` modifié localement jamais observé | **Réduit** : vitesse observée comparée aux Boots du profil serveur (détection au-delà d'environ 2 × la vitesse de référence) |
| V5 | Journalisation incomplète, non structurée | **Corrigé** : SecurityLog structuré et limité |
| V6 | Position NaN ou infinie : `d > max` faux, contrôle contourné | **Corrigé** : `isFinitePosition` et comparaisons `not (d <= max)` (deux gardes indépendantes) |
| V7 | Arguments après le payload ignorés | **Corrigé** : refusés (`INVALID_TARGET`) |
| V8 | Seau de limite remis à zéro à la reconnexion | **Non traité** (impact faible : une reconnexion prend plusieurs secondes) |

## 2. Protections mises en place

### MovementValidator (`Systems/MovementValidator.lua`)

Logique pure ; échantillonnage par une seule boucle serveur à 4 Hz
(`Bootstrap`). Paramètres : `ServerStorage/ServerOnlyConfig/MovementSecurityConfig.lua`
(unités, durées et marges documentées dans le fichier).

| Contrôle | Seuil (hypothèse initiale R4) |
|---|---|
| Téléportation (un échantillon) | saut horizontal > Boots × 1,5 × Δt + 30 studs |
| Vitesse (fenêtre glissante 1 s) | distance horizontale > Boots × 1,5 × durée + 8 studs, depuis la plus ancienne position **validée** de la fenêtre |
| Montée (fenêtre) | > Boots × 1 × durée + 8 (saut) + 4 studs ; **descente jamais limitée** |
| Gel réseau | positions identiques : la suite garde l'heure de son début, crédit borné à 1 s de plus que la fenêtre |
| Avant action | écart à la dernière position validée calculé sur ≤ 0,5 s |

Principes appliqués :

- **Référence** : jamais une position client. L'ancre vient d'un
  échantillon jugé valide, du point d'apparition (`CharacterAdded`, lu
  côté serveur) ou d'une correction serveur.
- **Vitesse de référence** : Boots du profil (`SetSpeed` appelé par
  `applyWalkSpeed` : chargement, apparition, achat, préréglage).
- **Stratégie graduelle (R1)** :
  1. anomalie isolée → journal (`movement_anomaly`), collecte et vente
     refusées pendant l'épisode et 1 s après (`TOO_FAR`, R2) ; aucune
     correction ;
  2. revérification à chaque échantillon ;
  3. 3 épisodes en 10 s, ou un épisode persistant 3 s → retour à la
     dernière position validée (`HumanoidRootPart.CFrame`, vitesse
     annulée) + suspension 5 s de la collecte et de la vente
     (`movement_correction`) ;
  4. jamais d'expulsion ni de bannissement.
- **Anti-boucle** : après correction, 1 s de grâce (échantillons en vol
  ignorés), historique remis à zéro, corrections espacées d'au moins 5 s.
- Une réapparition ne lève ni la suspension ni l'historique.

### Remotes (`Systems/PayloadValidator.lua`)

Contrats inchangés (un champ texte par demande, mêmes réponses
`ActionResult`). Ajouts : refus des arguments supplémentaires
(`select("#", ...)` dans `Bootstrap`), jeu de caractères `[%w_-]`, motif
de refus journalisé (jamais renvoyé au client). Ordre des contrôles
inchangé ; limites de fréquence inchangées (A-32 : valeurs provisoires
conservées, aucune mesure nouvelle ne justifie un changement).

### SecurityLog (`Services/SecurityLog.lua`, `SecurityLogConfig.lua`)

Format : `[Security] type=<type> user=<UserId> <clé>=<valeur>… count=<n> suppressed=<n>`.
Une ligne par joueur et par type toutes les 10 s au plus, plafond global
60 lignes/min (ligne `log_overflow` sinon), valeurs client assainies
(`[%w_-.:]`, 48 caractères). Appel protégé : une panne du journal ne
change aucune décision. Seule donnée de joueur : UserId.

Types : `invalid_payload`, `unknown_id`, `rate_limited`,
`profile_not_loaded`, `action_refused`, `movement_refused`,
`movement_anomaly`, `movement_correction`, `economy_refused`,
`data_inconsistency`.

### Contrôle de cohérence au chargement (`Systems/ProfileAudit.lua`)

Journal seulement, aucune modification. Constats : `coins_unexplained`
(solde + dépensé > gagné), `coins_missing`, `unpaid_progress` (coût cumulé
des niveaux et mondes > dépensé), `inventory_over_capacity`,
`inventory_exceeds_collected`, `world_requirement`, `unreadable`.
Source légitime connue hors ventes : **préréglages Studio**
(`StudioTestPresets`) — constats attendus sur ces profils. Aucune autre
source de Coins en production à ce jour.

## 3. Traitement de A-26 et A-37

- **A-26** : PARTIEL (réduit, non supprimé). Téléportation, speed hack et
  « Reset » détectés en test ; collecte et vente refusées pendant une
  anomalie ; correction graduelle. La position reste simulée par le client
  (propriété réseau) : on ne peut pas empêcher un mouvement, seulement le
  juger et le corriger.
- **A-37** : PARTIEL (réduit). Le `WalkSpeed` local reste invisible ; la
  vitesse **observée** est comparée aux Boots du profil. Un speed hack
  ≤ 2 × la vitesse de référence (tolérance 1,5 + marges) n'est pas
  détecté. La collecte reste bornée par la cadence Grabber et la vente
  par le contenu du sac : aucun gain de Coins direct.

Solution écartée : propriété réseau serveur des personnages
(`SetNetworkOwner(nil)`) — latence d'entrée inacceptable sur mobile.

## 4. Limites techniques et cas à tester en réel

- Roblox **interpole** la position côté serveur : une téléportation
  apparaît parfois comme plusieurs déplacements rapides. Constaté en
  Studio (téléportation de 52 studs classée `speed`, pas `teleport`). La
  fenêtre glissante la détecte quand même.
- Tolérance de vitesse : un tricheur peut aller jusqu'à environ 2 × la
  vitesse de référence (≈ 32 studs/s à Boots 1) sans détection.
- Téléportation isolée de moins d'environ 55 studs après une immobilité :
  refusée pendant ~2 s puis acceptée (pas de correction) — anomalie
  isolée, choix R1.
- Projection physique forte (≥ 40 studs) **en continuant de courir** :
  l'épisode peut persister 3 s → correction d'un joueur honnête. Rare sur
  la carte actuelle ; à calibrer.
- Descente non limitée : une téléportation vers le bas n'est pas
  détectée ; la distance 3D aux ressources reste contrôlée.
- Vol lent (montée ≤ Boots × 1 + 12 studs/s) non détecté.
- Latence mobile réelle, pertes de paquets, appareils lents : **non
  mesurés** (A-27 reste ouverte) ; seuils R4 à calibrer.
- La correction de position repose sur l'acceptation par le client de la
  `CFrame` imposée : vérifié dans Studio, un client modifié peut la
  refuser (il reste alors suspendu et recorrigé toutes les 5 s au plus).

## 5. Performances

- Échantillonnage : une boucle, 4 Hz, pour tous les joueurs ; une lecture
  de position et au plus ~5 échantillons en fenêtre par joueur.
- Mesure Lune (PC, interpréteur hors Roblox, indicative) : 3,9 µs par
  échantillon, soit **0,77 ms de calcul par seconde pour 50 joueurs**.
- `CanAct` : O(1), appelé seulement à la collecte et à la vente.
- Journal : au plus 60 lignes/min au total ; aucune ligne par frame.
- Un `GetData` (copie du profil) par chargement pour l'audit ; aucune copie
  supplémentaire par échantillon (vitesse mise en cache par `SetSpeed`).
- Non mesuré : coût réel sur serveur Roblox avec plusieurs joueurs
  (MicroProfiler).

## 6. Risques résiduels

| # | Risque | Suite |
|---|---|---|
| A-26 | Déplacement client toléré jusqu'à ~2 × la vitesse | Calibrer avec mesures réelles |
| A-27 | Marges jamais mesurées sur mobile réel | Ouverte |
| A-37 | Speed hack modéré non détecté | Ouverte, réduite |
| A-42 (nouveau) | Faux positif possible : projection forte en courant → correction | Calibrer `persistentEpisodeSeconds` |
| A-43 (nouveau) | Préréglages Studio : constats `data_inconsistency` attendus | Documenté, sans effet en production |
| R-02 | Deux serveurs actifs sur un même profil | Non testable dans Studio |
| V8 | Seau de limite remis à zéro à la reconnexion | Faible, non traité |
