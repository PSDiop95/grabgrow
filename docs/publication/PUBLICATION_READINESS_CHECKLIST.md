# Checklist de préparation à la publication — GRAB & GROW

Date de l'audit : 2026-11-16 (T9-G). **Aucune publication ni aucun réglage
de l'expérience n'a été modifié.** Les règles Roblox citées sont celles de
la documentation Creator Hub consultée à cette date (pages « Publish
experiences and places », « Content maturity ») ; à revérifier le jour de
la publication.

Statuts : **PASS** (vérifié), **PARTIAL** (en partie vérifié ou avec
réserve), **BLOCKED** (manque une action ou une décision), **NOT TESTED**
(non vérifié). « Propriétaire » = action réservée au titulaire du compte.

## A. Identité et présentation

| Élément | Statut | Constat / action |
|---|---|---|
| Nom « GRAB & GROW » | PARTIAL | Le place de test s'affiche « Test de prise et de croissance » dans Studio. Nom public à définir dans l'expérience de production (propriétaire) |
| Description courte | BLOCKED | Non rédigée. Règle Roblox : résumer le jeu dès la première phrase, sans répétition de mots-clés. Proposition à rédiger et valider |
| Description complète | BLOCKED | Non rédigée (EN et FR) |
| Icône | BLOCKED | Aucune ; génération soumise à validation explicite |
| Miniatures | BLOCKED | Aucune ; captures existantes de travail (`docs/phases/T8_5_captures`, `T8_6_captures`) non destinées à la vitrine |
| Captures d'écran | BLOCKED | À produire après validation de la direction visuelle |
| Cohérence visuelle | PARTIAL | Quatre îles en primitives low-poly cohérentes (T8) ; aucun asset tiers ; logo absent |
| Présentation des quatre mondes | PARTIAL | Mondes jouables et validés (T8.2 à T8.5) ; aucun support de présentation |
| Langues disponibles | PASS | EN et FR, clés de localisation (`LOCALIZATION.md`, T5.4) ; tables de localisation Roblox non utilisées (choix T5.4) |

## B. Configuration Roblox (à auditer dans le Creator Dashboard)

| Élément | Statut | Constat / action |
|---|---|---|
| Nom et description | NOT TESTED | Non consultés (aucun accès lecture au Dashboard par l'outil) |
| Place principale | PARTIAL | Place de test 93404872714886 (univers 10775875517) ; expérience de **production distincte** à créer ou à identifier (propriétaire) |
| Accès et permissions | NOT TESTED | Nouveaux jeux privés par défaut ; vérifier la visibilité actuelle de l'expérience de test |
| Confidentialité | NOT TESTED | Propriétaire |
| Serveurs (taille, nombre de joueurs) | NOT TESTED | Taille de serveur non décidée ; le jeu ne dépend pas de la présence d'autres joueurs |
| Paramètres de sauvegarde | PASS | DataStore séparés : `GrabAndGrow_PlayerData_v1_Studio` (Studio) et nom de production (`DataConfig.Store.name`) ; « Enable Studio Access to API Services » à vérifier dans le place de production (propriétaire) |
| Compatibilité des plateformes | PARTIAL | Voir C ; cases d'appareils de l'expérience non consultées |
| Communication (chat) | NOT TESTED | Aucun chat ajouté par le jeu ; réglages par défaut de Roblox |
| Classification (questionnaire) | BLOCKED | Obligatoire : sans classification, Roblox restreint la jouabilité pour tous. Contenu présumé sans élément restreint (aucune violence, aucun chat ajouté, aucun achat) : réponse « non » à la question de contenu restreint → audience 16+ ; Kids & Select demande un parcours supplémentaire (ci-dessous). Réponse réservée au propriétaire |
| Permissions des assets | PASS | Aucun asset 3D tiers (`ASSET_MANIFEST.md`) ; 8 sons Roblox vérifiés (`SOUND_MANIFEST.md`) |
| Dépendances | PASS | Aucune dépendance externe, aucun HttpService sortant, aucun package |

### Exigences Roblox de sortie publique (au 2026-11-16)

| Audience | Exigences du compte |
|---|---|
| 16+ | Compte en règle, ancien d'au moins 2 jours, contrôle d'âge (estimation faciale ou pièce d'identité), question de contenu restreint répondue |
| Tous âges (Kids & Select) | Compte vérifié, 2FA, Roblox Plus/Premium 2 mois consécutifs **ou** frais remboursables (1 000 Robux), évaluation Kids & Select, questionnaire complet avec note Minimal / Mild / Moderate |

Choix d'audience : **décision du propriétaire** (le GDD vise un public
large ; Kids & Select implique des démarches et un coût).

## C. Compatibilité et qualité

| Élément | Statut | Constat |
|---|---|---|
| Mobile | PARTIAL | Téléphone Android réel validé en T5.5 (modèle non communiqué) ; contrôle visuel mobile des quatre mondes non fait (réserve T8) |
| PC | PASS | Studio PC (T5.1, T8.7) |
| Tablette | PARTIAL | Émulateur seulement (T5.1) ; aucune tablette réelle |
| Manette | NOT TESTED | Reportée depuis T3 |
| Résolutions et ratios | PARTIAL | Émulateur téléphone portrait/paysage, tablette, PC (T5) |
| Appareils modestes | NOT TESTED | Performance non mesurée (réserve T5 et T8) |
| Chargement des mondes | PASS | Quatre mondes, Studio et Local Server (T8.7) |
| Multijoueur | PASS | Local Server à 2 joueurs, 11 scénarios (T8.7) ; analytics multijoueur NOT TESTED (T9) |
| Reconnexion | PASS | DataStore de test (T8.7, 12 cas) |
| Sauvegarde | PASS | Schéma v3, D-023 ; réserve R-01 (copie `Recovery_` non vérifiée sur DataStore réel) |
| Gestion des erreurs | PASS | Tests Lune (429 cas), panne analytics isolée (T9) |

Appareils réellement testés : PC (Studio), téléphone Android réel (T5.5),
émulateurs Studio. Rien d'autre n'est déclaré compatible.

## D. Sécurité et conformité

| Élément | Statut | Constat |
|---|---|---|
| Conditions de publication | PARTIAL | Exigences relevées ci-dessus ; leur respect dépend du compte (propriétaire) |
| Classification | BLOCKED | Questionnaire à remplir par le propriétaire |
| Communications | PASS | Aucun système de communication ajouté |
| Données et analytics | PASS | Roblox AnalyticsService uniquement, aucune donnée personnelle dans les champs, aucun service tiers (T9) |
| Assets et licences | PASS | Voir B |
| Contenus restreints | PASS (présumé) | Aucun contenu violent, sexuel, de jeu d'argent ou d'achat ; à confirmer par le propriétaire dans le questionnaire |
| Confidentialité | NOT TESTED | Paramètres de l'expérience |
| Sécurité serveur | PASS | T6 (D-019), T8.7 : aucune autorité client |

Aucune conformité juridique n'est affirmée ici ; les points ci-dessus
relèvent du titulaire du compte.

## E. Monétisation future (état des lieux, rien d'implémenté)

| Option | État | Prérequis avant toute phase dédiée |
|---|---|---|
| Game Passes | Absent | Décision, validation de la boucle par les données, `ProcessReceipt` non requis ; vérification de propriété côté serveur |
| Developer Products | Absent | `ProcessReceipt` idempotent (`PurchaseId`), tests doublons et déconnexion (CLAUDE.md §10) |
| Publicités | Absent | Règles d'éligibilité Roblox à vérifier ; non prévu par le GDD MVP |
| Achats Robux (boutique) | Absent | Aucune boutique Robux ; l'économie Coins ne doit pas être modifiée sans décision |

## F. Actions nécessaires avant publication

1. Clôture et validation de T9 (propriétaire).
2. Publication **privée** de l'expérience de test et vérification des
   événements (D5, `ANALYTICS_TEST_REPORT.md`).
3. Test Local Server analytics à 2 joueurs (propriétaire).
4. Rédaction et validation : nom public, descriptions EN/FR, icône,
   miniatures, captures.
5. Choix de l'audience (16+ ou Kids & Select) et questionnaire de
   classification (propriétaire).
6. Création ou identification de l'expérience de production, avec son
   DataStore de production vierge.
7. Test fermé (voir `RELEASE_PLAN.md`), dont mesure de performance sur
   appareil modeste, tablette réelle et contrôle visuel mobile.
8. Levée ou acceptation des réserves R-01, manette, performance.
