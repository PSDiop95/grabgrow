# T6 — Rapport de tests (sécurité, multijoueur, régression)

Date : 2026-11-13. Environnement : dépôt local (aucun commit), Lune 0.11.1,
luau-lsp 1.70.1, Rojo 7.7.1, Roblox Studio 0.747 (place de test
93404872714886, synchronisé par Rojo, **magasin en mémoire**). Aucun
DataStore réel utilisé, production non touchée, `GrabAndGrow.rbxl` non
modifié.

Statuts : PASS, PARTIAL, FAIL, NOT TESTED. « Simulé » = Lune (logique
pure, horloge et positions simulées) ; « Studio » = exécuté réellement dans
Roblox Studio avec un personnage.

## 1. Automatisés

| Test | Résultat |
|---|---|
| Lune : 15 suites, dont **MovementValidatorTests (25 cas)** et **SecurityTests (42 cas)** nouvelles | **PASS** — `TOUS LES TESTS : OK`, code 0 |
| Mêmes 15 suites dans Studio (Play) | **PASS** — `TOUS LES TESTS : OK` |
| 13 suites existantes (régression T0–T5) | **PASS** — inchangées, toutes OK |
| `luau-lsp analyze` strict | **PASS** — 0 erreur |
| `rojo build` (fichier temporaire) | **PASS** |
| Synchronisation Studio | **PASS** — 64 / 64 scripts, tailles identiques au dépôt |
| Contrôle négatif : 16 défauts introduits tour à tour | **PASS** — 14 / 16 détectés seuls ; les 2 restants (une des deux gardes NaN retirée, collecte ou vente) sont couverts par l'autre garde ; les deux gardes retirées ensemble : détecté (3 et 4 échecs) |

## 2. Déplacements

| Scénario | Simulé | Studio |
|---|---|---|
| Déplacement normal (16 studs/s, 20 s) | PASS | PASS — navigation sur la carte, aucune ligne `[Security]` |
| Vitesse Boots (20,5 avec Boots 20,5 ; 20,5 avec référence 16) | PASS | NOT TESTED (Boots non acheté en Studio) |
| Sauts et collisions | PASS (sauts, projection isolée de 40 studs : journal sans correction) | PASS — 4 s de sauts en marchant, collectes OK, aucune anomalie |
| Chute (300 studs), pente 45°, échelle | PASS | NOT TESTED (carte plate) |
| Latence simulée | PASS (gel 0,75 s, gel 1,5 s puis rattrapage) | PARTIAL — `IncomingReplicationLag = 0,4 s` (retard mesuré ≈ 0,45 s) : 2 trajets légitimes sans anomalie ; le parcours collecte + sauts + vente sous latence n'a pas abouti (script bloqué, session Studio fermée) |
| Vitesse anormale | PASS (40 studs/s : détectée, corrigée après 3 s, corrections ≥ 5 s d'écart) | PASS — `WalkSpeed = 60` local (≈ 43 studs/s observés) : `movement_anomaly kind=speed`, collecte refusée (`reason=anomaly`). Pas de correction (2 épisodes seulement, conforme R1) |
| Téléportation | PASS (200 studs : refus puis correction ; verticale +40) | PASS — 52 studs : `TOO_FAR` (`recent_anomaly`), journal, aucune correction, collecte possible 4 s plus tard |
| Tentatives répétées | PASS (3 × 45 studs en 10 s → correction + suspension 5 s) | PASS — 3 téléportations de 60 studs : `movement_correction`, personnage remis à la dernière position validée (accepté par le client), collecte `suspended`, vente `TOO_FAR` |
| Pas de boucle après correction | PASS | PASS — marche légitime après la suspension, collecte `SUCCESS`, aucune nouvelle correction |
| Réapparition (« Reset ») | PASS (ancre = apparition, suspension conservée) | PASS — mort locale, réapparition en 0,4,0, `WalkSpeed` serveur 16, téléportation immédiate sur une ressource : `TOO_FAR` |
| NaN et infini | PASS | NOT TESTED (non reproductible par un client normal) |

## 3. RemoteEvents

| Scénario | Simulé (4 remotes) | Studio |
|---|---|---|
| Payload valide | PASS | PASS |
| Payload malformé (nil, texte, nombre, booléen, table vide, type, vide, 200 caractères, caractères interdits) | PASS | PASS — texte, `\0`, 5 000 caractères : `INVALID_TARGET` |
| Identifiant inexistant | PASS | PASS (T2–T4, inchangé) |
| Champs supplémentaires (`amount`, `price`, `coins`…) | PASS | PASS — `coins = 1e9`, `force = true` : `INVALID_TARGET` |
| Arguments supplémentaires | PASS | PASS — `invalid_payload reason=extra_arguments` |
| Spam (300 demandes) | PASS (≤ rafale traitée, une seule réponse `RATE_LIMITED`) | PASS — 300 achats : 5 traités (`INSUFFICIENT_FUNDS`), 1 `RATE_LIMITED`, le reste silencieux |
| Joueur sans profil actif | PASS | NOT TESTED (exige un chargement retardé) |

## 4. Économie

| Scénario | Résultat |
|---|---|
| Double vente au même instant | PASS (simulé) — un crédit, `NOTHING_TO_SELL` ensuite |
| Double achat avec le solde d'un seul | PASS (simulé) — un débit, niveau +1 |
| Achat sans solde | PASS (simulé et Studio) |
| Déblocage sans prérequis | PASS (simulé) |
| Appels simultanés mélangés (40 tours vente / achat / vente) | PASS (simulé) — solde = gagné − dépensé à chaque tour |
| Aucune création de monnaie | PASS (simulé) — totaux égaux aux montants des résultats |

## 5. Multijoueur

| Scénario | Résultat |
|---|---|
| Deux joueurs, même ressource | PASS (simulé) ; Studio : NOT TESTED en T6 (validé en T2) |
| Deux joueurs vendent simultanément | PASS (simulé) ; Studio : NOT TESTED en T6 (validé en T3, E6) |
| Transactions simultanées sur un profil | PASS (simulé) |
| Déconnexion pendant une opération | PASS (simulé) — demandes après la sortie : `PROFILE_NOT_LOADED`, rien écrit |
| Reconnexion et cohérence | PASS (simulé, même magasin, autre serveur) |
| **Local Server à 2 joueurs ou plus (Studio)** | **PASS (déclaré par le propriétaire, 2026-11-13)** — protocole section 8 exécuté manuellement ; détail point par point et lignes `[Security]` non transmis |
| Deux serveurs actifs sur un profil (R-02) | NOT TESTED — impossible dans Studio |

## 6. Journal et audit

| Scénario | Résultat |
|---|---|
| Limite par joueur et par type, compteur `suppressed` | PASS (simulé et Studio) |
| Plafond global, `log_overflow` | PASS (simulé) |
| Injection dans le journal (retour à la ligne, faux `[Security]`) | PASS (simulé) |
| Journal en panne : décisions inchangées | PASS (simulé) |
| Audit : profil propre, Coins sans origine, non payé, monde, sac | PASS (simulé) |
| Audit en lecture seule | PASS (simulé) |
| Audit au chargement dans Studio | PASS — nouveau profil : aucun constat |

## 7. Non effectués et raisons

| Test | Raison |
|---|---|
| Latence mobile réelle (A-27) | Aucun appareil branché ; latence Studio seulement |
| Parcours complet sous latence (collecte, sauts, vente) | Script bloqué puis session Studio fermée (23:50 UTC) ; à refaire |
| Boots acheté, pente, chute réelles | Carte plate, pas de préréglage Boots lancé |
| Manette, tablette | Hors matériel (réserves T5) |
| Coût réel sur serveur Roblox | Mesure Lune seulement (0,77 ms/s pour 50 joueurs) |

## 8. Protocole Local Server proposé (propriétaire)

Studio, `useMemoryStore = true`, Test > Local Server, 2 joueurs :

1. Les deux joueurs marchent, sautent, collectent et vendent : aucune ligne
   `[Security] type=movement_*` dans la sortie serveur.
2. Les deux visent la même ressource : un seul sac crédité.
3. Les deux vendent au même moment : chacun reçoit son propre montant.
4. Bousculade volontaire entre les deux personnages pendant 30 s : noter
   toute ligne `movement_anomaly` ou `movement_correction` (faux positif à
   signaler).
5. Avec `Studio Settings > Network > Incoming Replication Lag = 0.3`, refaire
   1 à 3, puis **remettre la valeur à 0**.

## 9. À remettre en état

`settings().Network.IncomingReplicationLag` a été réglé à **0,4** dans
Studio pendant le test de latence ; la session s'est fermée avant sa
remise à 0. Vérifier dans Studio Settings > Network et remettre **0**.
