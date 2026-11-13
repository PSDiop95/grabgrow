# T5.5 — Validation multiplateforme : rapport

Date : 2026-11-13. **Statut : TERMINÉ avec réserves** (mise à jour 2026-11-13) — tests sur
téléphone réel et PC validé par le propriétaire (déclaration « test validé », 2026-11-13 ; appareil, version Android, détail ligne par ligne et version du place testée non communiqués). Réserves : manette reportée, tablette réelle
non testée, aucune mesure de performance chiffrée sur téléphone.

État initial : PARTIEL — validation technique et parcours
complet sur émulateur Studio faits ; téléphone réel, tablette réelle, PC
hors Studio et manette non exécutés en T5.5.

Matrice : `T5_DEVICE_MATRIX.md`. Anomalies : `T5_ISSUES.md`.

## 1. Préflight

| Point | Constat |
|---|---|
| Git | `main` propre au départ ; dernier commit cf1b0b2 (T5.4) ; aucun push depuis T1 |
| T5.1 HUD | Clôturé par le propriétaire (2026-11-12), téléphone réel OK ; commit 5d4f339 |
| T5.2 Feedback | Clôturé (2026-11-12), téléphone réel OK ; commit 837f11f |
| T5.3 Première session | Clôturé (2026-11-13) sur émulateur, D-017 acceptée ; commit dd259ae. **Réserve** : parcours nouveau joueur jamais fait sur téléphone réel (profil principal déjà avancé). Titre « PARTIEL » dans `PROJECT_STATUS.md` incohérent (T55-02, corrigé) |
| T5.4 Textes | Clôturé (2026-11-13) ; commit cf1b0b2 ; tests L1–L5 sur téléphone réel non faits |
| Conclusion | Prérequis T5.1–T5.4 validés par le propriétaire : tests finaux engagés. Les réserves T5.3 et T5.4 sont reprises dans la checklist téléphone réel |

## 2. Validation technique (T5.5.8)

| Vérification | Type | Résultat |
|---|---|---|
| `lune run tools/run_tests.luau` | Automatisé, terminal | Exécuté — 13 suites, `TOUS LES TESTS : OK`, code 0 |
| `luau-lsp analyze` (strict, sourcemap régénéré) | Automatisé | Exécuté — 0 erreur, code 0 ; sourcemap inchangé |
| `rojo build` (fichier temporaire) | Automatisé | Exécuté — OK |
| Synchronisation Rojo | Studio (Edit), empreinte sans fins de ligne | Exécuté — **56 / 56** scripts identiques au dépôt |
| Suites dans Studio (Play) | Studio | Exécuté — `TOUS LES TESTS : OK` |
| `useMemoryStore` | Dépôt et place | `true` : aucun DataStore réel touché |

Régressions T1–T4 couvertes par les suites automatisées (persistance,
verrou, collecte, limite de fréquence, sac, réapparition, vente exacte,
double crédit, achats, effets, mondes). Reconnexion sur DataStore réel
et deux joueurs : non refaits en T5.5 (dernière preuve : T1–T3).

## 3. Parcours complet (T5.5.5) — Studio, émulateur téléphone paysage

Environnement : place de test 93404872714886, Play à un joueur, profil en
mémoire neuf, émulateur tactile 801 × 413, locale fr-fr. Déplacements par
`Humanoid:MoveTo` (pas de téléportation), demandes par les RemoteEvents
réels ; vente par la touche F réelle ; boutique par la touche B réelle ;
achat par clic réel. **Aucun préréglage.**

| # | Étape | Résultat |
|---|---|---|
| 1 | Connexion nouveau joueur | `nouveau profil créé` ; `[Onboarding] étape de départ : INTRO` |
| 2 | Introduction | « Étape 1/3 — Collectez vos premières ressources ! », consigne tactile |
| 3 | Première collecte | `SUCCESS` → « Étape 2/3 — Bien joué ! Continuez de remplir votre sac. » |
| 4 | Remplissage | À 10 : « Vendez vos ressources ! » ; 50 / 50 : « Sac plein ! », « Vendez au stand ! » ; 3 refus `INVENTORY_FULL` |
| 5–6 | Vente (F) | `SUCCESS +67` ; Coins 0 → 67 ; journal serveur `+67 … solde 67` ; « Belle vente ! +67 Coins » puis « 3/3 … encore 33 Coins » |
| — | 2e cycle (26 collectes, F) | `+35`, Coins 102 ; « Utilisez vos Coins… », ▶ sur Boutique |
| 7 | Boutique (B) | Panneau sous le sac, ▶ sur Sac à dos seul payable, « Manque 48 / 98 / 148 / 198 » ; capture prise |
| 8 | Achat Sac à dos (clic) | `SUCCESS Backpack niv 2` ; Coins 2 ; journal `-100 … solde 2` |
| 9 | Effet réel | Sac `0 / 75` (capacité lue de l'état serveur) ; toast « Sac 50 → 75 » |
| 10 | Reprise | Guidage terminé (aucune carte, 0 flèche après 7 s) ; boutique fermée par B ; 3 collectes `SUCCESS`, sac 3 / 75 ; aucun guidage réapparu |

Joueur avancé : couvert par `OnboardingTests` (Lune) et T5.3 (Studio) ;
sur téléphone réel, console `COMPLETED` (2026-11-13). Non refait ici.

## 4. Audio et visuel (T5.5.6) — compteurs `FeedbackFX`

| Action | Compté | Conforme |
|---|---|---|
| 76 collectes réussies | 76 sons `collect`, 76 éclats | Oui : 1 retour par confirmation |
| Presque plein (40/50) | 1 `bag_warning` | Oui |
| Plein + 3 refus | 3 `bag_full`, 1 doublon écarté | Oui (anti-doublon 1,5 s) |
| 2 ventes | 2 `sell`, 2 `coins`, 2 volées de pièces ; `LastSaleAmount` = montant serveur | Oui |
| 1 achat | 1 `upgrade`, 1 anneau | Oui |
| Fin de session | `ClientFeedbackEffects` 0, `FeedbackFX` 0 descendant, 9 sons, 0 en cours | Oui, aucune accumulation |

Muet, effets réduits, déblocage de monde : non refaits (T5.2, Studio et
téléphone réel). Écoute réelle : non faisable par Claude.

## 5. EN/FR (T5.5.7)

Textes FR relus en jeu : guidage, sac, boutique, ventes, toasts —
vouvoiement, espaces insécables, accents OK. Une incohérence de
ponctuation (T55-01, P3), corrigée. EN : tests automatisés seulement. Messages
d'expulsion : vérifiés en T5.4 (journal), non refaits.

## 6. Stabilité et performance (T5.5.9)

| Mesure | Valeur | Portée |
|---|---|---|
| Durée de la session Studio | ≈ 6 min | Pas 15 min ; pas un téléphone |
| `PlayerGui` | 233 descendants ; 231 après réapparition ; aucun ScreenGui dupliqué | Studio |
| Mémoire client | 405 Mo | PC de développement, **non représentatif** |
| FPS physique | 60 | Studio, non représentatif |
| Erreurs du jeu | Aucune (seules : asset d'avatar étranger 203785492, et deux erreurs de mes propres commandes d'inspection) | Studio |

Aucune métrique téléphone : non mesurée.

## 7. Plateformes non testées en T5.5

| Plateforme | Raison | Statut |
|---|---|---|
| Téléphone Android réel | — | **Fait** : R1–R10 validé par le propriétaire (déclaration « test validé », 2026-11-13 ; appareil, version Android, détail ligne par ligne et version du place testée non communiqués) |
| Tablette réelle | Non mentionnée | Non testée |
| PC Roblox Player, deux résolutions | — | **Fait** : P1, même déclaration |
| Tablette, PC dans l'émulateur | L'émulateur ne se pilote pas par MCP (T5.1) ; déjà OK en T5.1 | Non refait |
| Manette | Aucune manette ; liaisons relues dans le code : X collecte, Y vente, croix haut boutique, B fermeture, sélection du 1er bouton | **Reporté**, PARTIEL |

## 8. Données

Aucune opération DataStore réelle. Profil en mémoire uniquement
(`useMemoryStore = true`). Aucune valeur économique, règle serveur ni
schéma modifiés. Seule modification de code : 2 chaînes de
`Localization` (T55-01). Aucun commit.

## 9. Recommandation

Mise à jour 2026-11-13 : checklist déclarée validée. Critères d'acceptation
atteints sur la base de cette déclaration ; clôture de T5 soumise à la
décision du propriétaire. **T5 clôturée par le propriétaire le
2026-11-13 (D-018).**

Recommandation initiale :

Pas de P0/P1 détectée sur ce qui a été testé. **Clôture de T5
recommandée après** l'exécution de R1–R8 sur téléphone réel (au minimum),
avec la manette documentée comme reportée. T55-01 (P3) : corrigée.
