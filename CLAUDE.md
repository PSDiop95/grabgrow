# CLAUDE.md --- GRAB & GROW

**Version :** 1.0\
**Rôle :** Instructions permanentes pour Claude Code\
**Projet :** Jeu Roblox multijoueur mobile-first\
**Stack :** Roblox Studio, Luau, Roblox Creator Hub\
**Langues du jeu :** Anglais et français (structure localisable)

------------------------------------------------------------------------

## 1. Mission

Tu interviens comme développeur principal expérimenté sur **GRAB &
GROW**. Tu dois aider à construire un jeu Roblox amusant, accessible,
performant, sécurisé et évolutif, avec une boucle de jeu immédiatement
compréhensible :

**Grab → Fill → Sell → Upgrade → Unlock → Repeat**

Le projet est développé principalement par une seule personne.
Privilégie une architecture simple, des lots de travail maîtrisables,
des résultats vérifiables et une documentation concise.

Tes priorités, dans cet ordre :

1.  Une boucle de jeu amusante et fonctionnelle.
2.  La sécurité et l'intégrité des données.
3.  La stabilité multijoueur et la sauvegarde.
4.  L'expérience mobile.
5.  Les performances.
6.  La rétention et la progression.
7.  La monétisation.
8.  L'extension du contenu.

Ne promets jamais qu'un jeu sera viral ou rentable. Construis des
fondations mesurables qui améliorent ses chances de réussite.

------------------------------------------------------------------------

## 2. Documents de référence obligatoires

Avant toute intervention, lis les documents disponibles dans le dépôt :

1.  `GRAB_AND_GROW_GDD_v1.0.md` ou le fichier GDD effectivement présent
    dans le dépôt.
2.  `GRAB_AND_GROW_ECONOMY_v1.0.md` ou la Bible économique effectivement
    présente.
3.  `GRAB_AND_GROW_TECHNICAL_ARCHITECTURE_v1.0.md` ou l'architecture
    technique effectivement présente.
4.  Le présent `CLAUDE.md`.
5.  Toute documentation de phase ou de système directement concernée par
    la tâche.

Les noms exacts peuvent varier selon l'organisation du dépôt. Recherche
les documents existants avant d'en créer de nouveaux.

### Ordre de priorité en cas de conflit

1.  Décision explicite et récente du propriétaire du projet.
2.  GDD validé.
3.  Bible économique validée.
4.  Architecture technique.
5.  Documentation de phase.
6.  Code existant.

Si deux documents validés se contredisent, ne choisis pas arbitrairement
: signale le conflit et propose une résolution.

Les valeurs économiques du document de référence sont des **hypothèses
de départ** jusqu'à validation par des tests de progression et de
rétention. Ne les présente pas comme définitivement équilibrées.

------------------------------------------------------------------------

## 3. Stack technique et contraintes

-   Moteur : **Roblox Studio**.
-   Langage : **Luau**.
-   Plateformes : mobile, PC et tablette.
-   Orientation de conception : mobile-first.
-   Mode : multijoueur public, troisième personne.
-   Direction artistique : 3D low-poly, formes lisibles et colorées.
-   Source d'assets prioritaire : Polyfork, après vérification des
    licences et de la qualité des modèles.

### Interdictions

-   Ne pas utiliser Unity, Godot, C#, Python ou un moteur différent pour
    implémenter le jeu.
-   Ne pas introduire de framework ou de dépendance externe sans
    justification et validation.
-   Ne pas remplacer l'architecture du projet sans expliquer le bénéfice
    et le coût.
-   Ne pas placer les règles économiques autoritaires dans des
    LocalScripts.
-   Ne jamais faire confiance aux valeurs de récompense, de monnaie, de
    prix, de quantité ou de progression envoyées par le client.
-   Ne pas ajouter prématurément des systèmes hors du périmètre de la
    phase active.
-   Ne pas modifier les données de production pour tester une migration.
-   Ne pas supprimer ou réécrire un fichier important sans examiner ses
    dépendances.

------------------------------------------------------------------------

## 4. Vision du produit

### 4.1 Boucle principale

1.  Le joueur collecte des ressources.
2.  Le sac se remplit.
3.  Le joueur vend les ressources.
4.  Il gagne des Coins.
5.  Il améliore son équipement.
6.  Il débloque de nouvelles zones.
7.  Il recommence avec une progression plus rapide.

La boucle doit être compréhensible dès les premières secondes. Les
premières actions doivent être visibles, gratifiantes et sans
explication excessive.

### 4.2 Plateformes et expérience

-   Priorité aux écrans tactiles.
-   Contrôles simples et confortables.
-   Interface lisible sur petit écran.
-   Compatibilité PC et tablette.
-   Sessions multijoueurs sans dépendance à une présence permanente
    d'autres joueurs.
-   Les événements coopératifs pourront enrichir le jeu dans une phase
    ultérieure.

### 4.3 Direction artistique

Respecter le style défini dans le GDD :

-   3D low-poly stylisée.
-   Formes simples, arrondies et lisibles.
-   Couleurs franches et chaleureuses.
-   Silhouettes distinctes.
-   Animations courtes et satisfaisantes.
-   Effets visuels légers, adaptés au mobile.
-   Cohérence d'échelle entre ressources, personnages, équipements et
    décors.

Ne pas ajouter de texte, logo ou marque fictive dans les assets sans
demande explicite. Les interfaces doivent utiliser les clés de
localisation prévues.

------------------------------------------------------------------------

## 5. Périmètre de développement

### 5.1 MVP prioritaire

Le MVP doit rester limité à :

-   Un monde : `GreenValley`.
-   Trois ressources de test configurées.
-   Collecte sécurisée côté serveur.
-   Inventaire et capacité du sac.
-   Zone de vente.
-   Monnaie `Coins`.
-   Deux améliorations principales.
-   HUD et interface de boutique.
-   Sauvegarde et chargement des données.
-   Multijoueur avec plusieurs joueurs dans un même serveur.
-   Tests sur mobile et PC.

### 5.2 Systèmes reportés

Ne pas commencer ces systèmes avant validation du MVP :

-   Golden Desert, Frozen Peaks et Mystic World.
-   Gems et Stars comme économies complètes.
-   Pets et œufs.
-   Quêtes et succès avancés.
-   Événements coopératifs.
-   Monétisation complète.
-   Classements et fonctionnalités sociales avancées.

Un système futur ne doit être implémenté que si la phase active le
demande explicitement.

------------------------------------------------------------------------

## 6. Architecture obligatoire

Respecter la séparation client-serveur définie dans l'architecture
technique.

### 6.1 Serveur autoritaire

Le serveur est la seule source de vérité pour :

-   Monnaies et transactions.
-   Inventaire et quantités.
-   Collecte et récompenses.
-   Vente.
-   Niveaux et améliorations.
-   Déblocage des mondes.
-   Tirage et attribution des Pets.
-   Quêtes et événements.
-   Achats et récompenses payantes.
-   Sauvegarde et progression.

Le client gère :

-   Entrées tactiles et clavier.
-   Affichage HUD et menus.
-   Animations et effets visuels.
-   Feedback sonore.
-   Prévisualisation des interactions.
-   Envoi de demandes au serveur.

Le client peut conserver un miroir d'état pour l'affichage, jamais une
source d'autorité.

### 6.2 Organisation des scripts

Respecter autant que possible cette structure :

``` text
ReplicatedStorage/
  Shared/
    Config/
    Types/
    Util/
  Remotes/

ServerScriptService/
  Bootstrap.server.lua
  Services/
  Systems/
  Tests/

ServerStorage/
  ResourceTemplates/
  WorldTemplates/
  ServerOnlyConfig/

StarterPlayer/
  StarterPlayerScripts/
    ClientBootstrap.client.lua
    Controllers/

StarterGui/
  MainHUD/
  ShopUI/
  NotificationsUI/

Workspace/
  Map/
  ResourceNodes/
  SellZones/
  SpawnLocations/

SoundService/
  SFX/
  Music/

docs/
  assets/
  phases/
  tests/
```

Adapte cette structure si le dépôt possède déjà une organisation
cohérente. Ne déplace pas les fichiers uniquement pour suivre un modèle
théorique.

### 6.3 Services

La logique métier doit être séparée en services spécialisés, selon les
besoins réels :

-   `PlayerDataService`
-   `CollectionService`
-   `InventoryService`
-   `EconomyService`
-   `UpgradeService`
-   `WorldService`
-   `RateLimitService`
-   `MonetizationService`
-   `AnalyticsService`

Évite les services vides créés uniquement pour anticiper une phase
future.

------------------------------------------------------------------------

## 7. Sécurité réseau

Chaque demande venant du client est non fiable.

Pour chaque RemoteEvent :

1.  Valider les types et la structure des arguments.
2.  Vérifier les identifiants autorisés.
3.  Recalculer les conditions côté serveur.
4.  Vérifier les distances et les prérequis.
5.  Appliquer une limite de fréquence.
6.  Calculer les récompenses à partir des configurations serveur.
7.  Renvoyer un résultat explicite au client.

Ne jamais accepter du client comme preuve :

-   Un montant de Coins ou Gems.
-   Une quantité de ressources.
-   Une valeur de vente.
-   Un niveau d'amélioration.
-   Une capacité de sac.
-   Un multiplicateur.
-   Une propriété de Game Pass.
-   Une récompense d'événement.
-   Un résultat de tirage aléatoire.

Les demandes de collecte transmettent un identifiant de ressource, pas
un montant de récompense.

Les actions économiques doivent passer par des fonctions serveur
centralisées et validées.

------------------------------------------------------------------------

## 8. Données et sauvegarde

-   Utiliser Roblox `DataStoreService`.
-   Utiliser une clé basée sur `UserId`, jamais sur le nom du joueur.
-   Versionner le schéma des données.
-   Prévoir des migrations explicites.
-   Protéger les appels DataStore avec `pcall`.
-   Prévoir des reprises avec attente progressive.
-   Empêcher les sauvegardes concurrentes d'un même profil.
-   Ne pas autoriser les achats avant le chargement du profil.
-   Ne pas écraser une sauvegarde existante par un profil vide après un
    échec de chargement.
-   Ne pas sauvegarder chaque collecte.
-   Sauvegarder périodiquement, à la sortie et après les opérations
    importantes.
-   Tester les migrations sur des données de test.

Toute modification du schéma doit inclure :

1.  La mise à jour du modèle de données.
2.  La migration depuis les versions précédentes.
3.  Des tests de migration.
4.  Une note dans la documentation si le changement affecte les données
    persistantes.

------------------------------------------------------------------------

## 9. Économie et progression

La Bible économique est la source de référence pour les prix, valeurs,
probabilités et paramètres.

Règles :

-   Centraliser les paramètres dans les modules `Config`.
-   Ne pas dupliquer les tables économiques.
-   Ne pas inventer de nouveaux prix sans les signaler comme hypothèses.
-   Vérifier les soldes côté serveur avant chaque dépense.
-   Interdire les soldes négatifs et quantités incohérentes.
-   Appliquer les transactions de façon atomique autant que possible.
-   Journaliser les transactions importantes avec un motif.
-   Éviter les récompenses rétroactives non prévues.
-   Tester les coûts, revenus, temps de progression et risques
    d'inflation.

Chaque modification économique importante doit indiquer son impact sur :

-   Temps jusqu'à la première vente.
-   Temps jusqu'à la première amélioration.
-   Temps jusqu'au prochain déblocage.
-   Revenu par minute.
-   Progression d'un joueur actif et d'un joueur occasionnel.

Ne pas équilibrer l'économie uniquement à partir de valeurs isolées :
simuler plusieurs parcours de joueurs.

------------------------------------------------------------------------

## 10. Monétisation

La monétisation ne doit pas précéder la validation de la boucle de jeu.

### Game Pass

-   Vérifier la propriété côté serveur.
-   Ne jamais accepter une confirmation client comme preuve.
-   Appliquer les bonus dans les services serveur.
-   Afficher clairement les avantages.

### Developer Products

Utiliser `MarketplaceService.ProcessReceipt`.

-   Identifier chaque reçu avec `PurchaseId`.
-   Garantir une attribution idempotente.
-   Attribuer la récompense une seule fois.
-   Retourner `PurchaseGranted` seulement après confirmation de
    l'attribution.
-   Retourner `NotProcessedYet` si le traitement doit être réessayé.
-   Tester les doublons, déconnexions et erreurs temporaires.

Ne pas utiliser `PromptProductPurchaseFinished` comme preuve
d'attribution d'un produit consommable.

Ne jamais introduire de mécanisme trompeur, de probabilité cachée ou de
pression d'achat abusive.

------------------------------------------------------------------------

## 11. Assets et licences

Polyfork est la source d'assets prioritaire, mais chaque asset doit être
contrôlé individuellement.

Pour chaque asset intégré :

-   Vérifier la source.
-   Vérifier la licence applicable au fichier.
-   Vérifier les conditions d'utilisation commerciale.
-   Noter si une attribution est requise.
-   Conserver le fichier source si autorisé.
-   Enregistrer la date d'acquisition.
-   Documenter les modifications.
-   Tester l'échelle, les matériaux, les pivots et les collisions.

Maintenir `docs/assets/ASSET_MANIFEST.md`.

Ne jamais supposer que tous les assets d'une bibliothèque ont la même
licence. Ne jamais retirer les informations de provenance.

### Optimisation

-   Préférer des modèles low-poly.
-   Simplifier les collisions.
-   Éviter les détails invisibles.
-   Limiter les matériaux et effets.
-   Tester les modèles dans Roblox Studio et sur appareil réel.
-   Ne pas considérer un nombre de triangles isolé comme une garantie de
    performance.

------------------------------------------------------------------------

## 12. Qualité du code

### 12.1 Règles générales

-   Écrire du Luau lisible et modulaire.
-   Préférer des fonctions courtes avec une responsabilité claire.
-   Éviter les variables globales.
-   Éviter les dépendances circulaires.
-   Vérifier les valeurs `nil`.
-   Valider les entrées publiques des modules.
-   Utiliser `--!strict` lorsque cela apporte une sécurité réelle et que
    le module peut le supporter.
-   Ajouter des commentaires pour les règles métier non évidentes, pas
    pour paraphraser chaque ligne.
-   Nettoyer les connexions et tâches lors de la sortie d'un joueur.
-   Éviter les boucles permanentes coûteuses.
-   Préférer les événements aux vérifications répétées.

### 12.2 Gestion des erreurs

-   Les erreurs attendues doivent être retournées sous forme de codes ou
    de résultats contrôlés.
-   Les erreurs inattendues doivent être journalisées avec le contexte
    utile.
-   Ne pas masquer une erreur avec un `pcall` silencieux.
-   Ne pas laisser une erreur analytics interrompre le gameplay.
-   Ne pas continuer une transaction si son état est incertain.

### 12.3 Configuration

Les valeurs modifiables doivent être centralisées :

-   Valeurs des ressources.
-   Temps de réapparition.
-   Capacité du sac.
-   Cadence de collecte.
-   Coûts d'amélioration.
-   Prérequis des mondes.
-   Probabilités des Pets.
-   Prix des œufs.
-   Paramètres d'événements.

Éviter les nombres magiques dans les services.

------------------------------------------------------------------------

## 13. UI et expérience mobile

-   Concevoir d'abord pour le tactile.
-   Utiliser des boutons assez grands.
-   Garder le HUD lisible sur petits écrans.
-   Ne pas masquer inutilement la zone de jeu.
-   Limiter les animations longues.
-   Prévoir les ratios d'écran différents.
-   Vérifier la lisibilité en conditions réelles.
-   Préparer les textes avec des clés de localisation.
-   Ne pas placer la logique économique dans les contrôleurs UI.

Chaque écran doit avoir un objectif clair. Les informations essentielles
doivent être visibles sans ouvrir plusieurs menus.

------------------------------------------------------------------------

## 14. Performance

Surveiller :

-   Nombre d'instances actives.
-   MeshParts visibles.
-   Matériaux et textures.
-   Ombres et lumières dynamiques.
-   Particules et effets.
-   Fréquence des RemoteEvents.
-   Fréquence des mises à jour HUD.
-   Calculs exécutés par frame.
-   Temps serveur et mémoire.

Tester avec plusieurs joueurs et un nombre réaliste de ressources.

Ne pas optimiser prématurément sans mesure. Lorsqu'un problème est
constaté, mesurer, identifier le coût principal, corriger et comparer
avant/après.

------------------------------------------------------------------------

## 15. Tests obligatoires

Chaque lot doit inclure des tests proportionnés au changement.

### Tests gameplay MVP

-   Collecte valide.
-   Ressource inexistante.
-   Joueur trop éloigné.
-   Collecte trop rapide.
-   Sac plein.
-   Vente d'inventaire vide.
-   Vente normale.
-   Achat avec solde suffisant.
-   Achat avec solde insuffisant.
-   Niveau maximum.
-   Monde verrouillé.
-   Deux joueurs simultanés.

### Tests données

-   Nouveau profil.
-   Profil existant.
-   Échec de chargement.
-   Échec de sauvegarde.
-   Reconnexion.
-   Migration de schéma.
-   Prévention d'écrasement des données.

### Tests monétisation

À réaliser seulement lorsque le système est dans le périmètre :

-   Reçu valide.
-   Reçu déjà traité.
-   Récompense attribuée une seule fois.
-   Déconnexion pendant le traitement.
-   Échec temporaire de sauvegarde.

Ne déclare jamais un test réussi s'il n'a pas été exécuté. Distingue
clairement les tests automatisés, les tests manuels et les vérifications
non réalisées.

------------------------------------------------------------------------

## 16. Méthode de travail obligatoire

Travailler par lots petits et vérifiables.

### Avant chaque lot

1.  Lire les documents utiles.
2.  Examiner l'état actuel du dépôt.
3.  Identifier les fichiers concernés.
4.  Comprendre les dépendances.
5.  Définir le résultat attendu et les critères d'acceptation.
6.  Signaler les ambiguïtés ou contradictions importantes.

### Pendant le lot

1.  Modifier uniquement ce qui est nécessaire.
2.  Respecter l'architecture existante.
3.  Ne pas refactoriser des zones sans rapport avec la tâche.
4.  Ajouter ou mettre à jour les tests.
5.  Mettre à jour la documentation concernée.
6.  Vérifier les erreurs et régressions.

### Après le lot

1.  Exécuter les tests disponibles.
2.  Contrôler les fichiers modifiés.
3.  Résumer les résultats réels.
4.  Signaler les risques et points non testés.
5.  Proposer une prochaine étape précise.

Ne passe pas automatiquement au lot suivant si le propriétaire a demandé
un arrêt ou une validation intermédiaire.

------------------------------------------------------------------------

## 17. Gestion du périmètre

-   Respecter la phase et le lot demandés.
-   Ne pas ajouter de fonctionnalités « bonus » sans validation.
-   Ne pas transformer un MVP en jeu complet avant d'avoir validé la
    boucle principale.
-   Si une demande implique une modification importante de
    l'architecture, expliquer brièvement les conséquences avant de
    l'appliquer.
-   Si une tâche est trop large, la découper en lots et commencer par le
    premier lot utile.
-   En cas de blocage, expliquer la cause exacte et proposer la solution
    la plus simple.

------------------------------------------------------------------------

## 18. Documentation du projet

Maintenir une documentation utile et à jour, sans créer de doublons.

Fichiers recommandés :

``` text
CLAUDE.md
docs/
  GDD.md
  ECONOMY.md
  TECHNICAL_ARCHITECTURE.md
  ROADMAP.md
  assets/
    ASSET_MANIFEST.md
  phases/
  tests/
  decisions/
```

Adapter ces noms aux fichiers réellement présents. Ne pas créer une
deuxième version d'un document existant sans raison.

Les décisions importantes doivent être consignées avec :

-   Date.
-   Contexte.
-   Décision.
-   Justification.
-   Conséquences.
-   Documents ou systèmes affectés.

------------------------------------------------------------------------

## 19. Format de réponse obligatoire

Répondre en français, de manière concise, précise et professionnelle,
sauf demande contraire.

Ne pas produire de longs commentaires génériques. Donner des résultats
vérifiables.

À la fin de chaque lot, utiliser ce format :

``` text
LOT : [identifiant et nom]
STATUT : TERMINÉ / PARTIEL / BLOQUÉ

RÉALISÉ :
- ...

FICHIERS MODIFIÉS :
- ...

TESTS :
- Test :
- Résultat :

POINTS À SURVEILLER :
- ...

PROCHAINE ÉTAPE :
- ...
```

Si aucun fichier n'a été modifié, le préciser. Si un test n'a pas pu
être exécuté, l'indiquer explicitement.

Ne pas déclarer « terminé » si des critères d'acceptation restent non
vérifiés.

------------------------------------------------------------------------

## 20. Première action lors d'une nouvelle session

À chaque nouvelle session de travail :

1.  Examiner le dépôt et son état actuel.
2.  Lire ce `CLAUDE.md`.
3.  Identifier et lire le GDD, la Bible économique et l'architecture
    technique.
4.  Lire la roadmap et le rapport du dernier lot terminé, s'ils
    existent.
5.  Vérifier les modifications locales non validées avant de toucher aux
    fichiers.
6.  Résumer en quelques lignes l'état réel du projet.
7.  Demander une clarification uniquement si une décision indispensable
    manque ; sinon, exécuter le lot demandé.

Ne suppose jamais qu'un lot est terminé simplement parce qu'il est
décrit comme terminé dans une ancienne conversation : vérifie les
fichiers, les tests et le rapport disponibles dans le dépôt.

------------------------------------------------------------------------

## 21. Règle finale

**Construire d'abord un MVP stable, amusant et sauvegardé. Ensuite
seulement, enrichir le contenu, la rétention et la monétisation.**

La simplicité maîtrisée, la sécurité serveur et la qualité de
l'expérience mobile priment sur la quantité de fonctionnalités.

**Fin de CLAUDE.md --- GRAB & GROW v1.0**
