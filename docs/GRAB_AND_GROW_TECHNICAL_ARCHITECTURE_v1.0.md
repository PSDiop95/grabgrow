# GRAB & GROW --- Architecture technique

**Version :** 1.0\
**Statut :** Proposition de référence pour le développement\
**Moteur :** Roblox Studio\
**Langage :** Luau\
**Cible :** Mobile-first, PC et tablette\
**Mode :** Multijoueur public, troisième personne

------------------------------------------------------------------------

## 1. Objectif du document

Ce document définit l'architecture technique de **GRAB & GROW**. Il sert
de référence pour organiser le projet Roblox Studio, répartir les
responsabilités entre client et serveur, structurer les données,
sécuriser les interactions réseau et préparer une évolution progressive
du MVP vers le jeu complet.

L'architecture doit rester adaptée à un développeur solo : modulaire,
lisible, testable et sans sur-ingénierie.

### 1.1 Principes directeurs

1.  **Serveur autoritaire :** le serveur décide des gains, achats,
    capacités, déblocages et récompenses.
2.  **Client réactif :** le client gère l'affichage, les animations, les
    effets et les contrôles.
3.  **Validation systématique :** toute demande client est considérée
    comme non fiable.
4.  **Configuration centralisée :** prix, valeurs, probabilités et
    paramètres de gameplay ne doivent pas être dispersés dans les
    scripts.
5.  **Sauvegarde robuste :** les données persistantes sont versionnées
    et protégées contre les pertes et doublons.
6.  **Mobile-first :** les interactions principales doivent être
    simples, lisibles et accessibles au toucher.
7.  **MVP avant extension :** construire et tester une boucle de jeu
    complète dans un seul monde avant d'ajouter les systèmes avancés.

------------------------------------------------------------------------

## 2. Périmètre fonctionnel

### 2.1 Architecture cible

Le jeu complet pourra comprendre :

-   Collecte de ressources (« Grab »).
-   Sac à dos et capacité maximale.
-   Vente des ressources contre des Coins.
-   Améliorations de l'équipement.
-   Déblocage de mondes.
-   Animaux de compagnie (Pets) et œufs.
-   Quêtes, succès et récompenses.
-   Événements coopératifs.
-   Game Pass et Developer Products.
-   Sauvegarde et progression persistantes.
-   Analytics et suivi des performances.

### 2.2 Périmètre du MVP

Le MVP doit contenir uniquement :

-   Un monde : **Green Valley**.
-   Trois ressources de test, définies dans la configuration.
-   Un système de collecte validé par le serveur.
-   Un sac à dos avec capacité limitée.
-   Un point de vente.
-   Une monnaie : Coins.
-   Deux améliorations simples (capacité du sac et vitesse de collecte,
    par exemple).
-   Une interface mobile fonctionnelle.
-   Une sauvegarde et un chargement fiables.
-   Un serveur multijoueur permettant à plusieurs joueurs de jouer
    simultanément.

Les Pets, Gems, Stars, œufs, événements, autres mondes et achats Robux
sont exclus du premier MVP. Ils seront ajoutés après validation de la
boucle principale.

------------------------------------------------------------------------

## 3. Architecture générale

### 3.1 Répartition des responsabilités

  -----------------------------------------------------------------------
  Domaine                 Client                  Serveur
  ----------------------- ----------------------- -----------------------
  Contrôles et input      Oui                     Non

  HUD et menus            Oui                     Non

  Animations et effets    Oui                     Validation des états
  visuels                                         importants

  Détection visuelle      Oui, indicative         Oui, définitive
  d'une ressource                                 

  Collecte réelle         Demande uniquement      Autorise et crédite

  Inventaire              Affichage du miroir     Source de vérité

  Vente                   Demande uniquement      Calcule et crédite

  Améliorations           Affichage et demande    Vérifie et applique

  Déblocage des mondes    Affichage et demande    Vérifie et applique

  Pets et probabilités    Affichage               Tirage et attribution

  Événements              Affichage et            Gestion et récompenses
                          participation           

  Monétisation            Affichage des offres    Vérification et
                                                  attribution

  Sauvegarde              Aucun accès direct      Source de vérité
  -----------------------------------------------------------------------

**Règle absolue :** aucun LocalScript ne doit attribuer directement des
Coins, Gems, Stars, ressources, niveaux, Pets ou achats.

### 3.2 Flux simplifié

``` text
Joueur
  |
  v
Client Roblox
  |  Inputs / demandes via RemoteEvents
  v
Serveur Roblox
  |
  +--> Validation des demandes
  |
  +--> Services de gameplay
  |      +--> CollectionService
  |      +--> InventoryService
  |      +--> EconomyService
  |      +--> UpgradeService
  |      +--> WorldService
  |      +--> QuestService (phase ultérieure)
  |      +--> PetService (phase ultérieure)
  |      +--> EventService (phase ultérieure)
  |
  +--> DataService
  |      +--> DataStoreService
  |
  +--> MonetizationService
  |      +--> MarketplaceService
  |
  v
Réponses contrôlées vers le client
```

------------------------------------------------------------------------

## 4. Organisation du projet Roblox Studio

Utiliser une structure claire dans `Explorer`. Les noms de dossiers et
modules doivent rester stables.

``` text
ReplicatedStorage/
  Shared/
    Config/
      GameConfig.lua
      ResourceConfig.lua
      UpgradeConfig.lua
      WorldConfig.lua
      MonetizationConfig.lua
    Types/
      DataTypes.lua
    Util/
      FormatUtil.lua
      TableUtil.lua
  Remotes/
    RequestCollect
    RequestSell
    RequestUpgrade
    RequestUnlockWorld
    StateUpdated
    ActionResult

ServerScriptService/
  Bootstrap.server.lua
  Services/
    PlayerDataService.lua
    CollectionService.lua
    InventoryService.lua
    EconomyService.lua
    UpgradeService.lua
    WorldService.lua
    RateLimitService.lua
    MonetizationService.lua
    AnalyticsService.lua
  Systems/
    ResourceSpawner.lua
    PlayerSession.lua
  Tests/

ServerStorage/
  ResourceTemplates/
  WorldTemplates/
  ServerOnlyConfig/

StarterPlayer/
  StarterPlayerScripts/
    ClientBootstrap.client.lua
    Controllers/
      InputController.lua
      HUDController.lua
      CollectionController.lua
      InventoryController.lua
      ShopController.lua
      FeedbackController.lua

StarterGui/
  MainHUD/
  ShopUI/
  NotificationsUI/

Workspace/
  Map/
    GreenValley/
  ResourceNodes/
  SellZones/
  SpawnLocations/

SoundService/
  SFX/
  Music/
```

### 4.1 Règles de placement

-   `ReplicatedStorage` contient uniquement les modules et objets
    nécessaires au client et au serveur.
-   `ServerScriptService` contient la logique serveur non répliquée.
-   `ServerStorage` contient les modèles et paramètres qui ne doivent
    pas être accessibles au client.
-   `StarterPlayerScripts` contient les contrôleurs client.
-   `StarterGui` contient les interfaces.
-   `Workspace` contient uniquement les éléments actifs de la scène.
-   Les secrets, clés privées ou règles anti-triche ne doivent jamais
    être placés dans un module répliqué.

### 4.2 Convention de nommage

-   Modules : `PascalCase.lua`.
-   Scripts serveur : suffixe `.server.lua`.
-   Scripts client : suffixe `.client.lua`.
-   RemoteEvents : noms d'action explicites, préfixés par `Request` pour
    les demandes client.
-   Fonctions : `PascalCase` ou `camelCase`, mais une seule convention
    doit être appliquée partout.
-   Variables locales : `camelCase`.
-   Constantes : `UPPER_SNAKE_CASE` si elles sont réellement constantes.

------------------------------------------------------------------------

## 5. Modules et responsabilités

### 5.1 `PlayerDataService`

Responsabilités :

-   Charger les données lors de `PlayerAdded`.
-   Créer un profil par défaut pour un nouveau joueur.
-   Valider et normaliser les données chargées.
-   Maintenir les données de session en mémoire.
-   Sauvegarder périodiquement et lors de la sortie.
-   Gérer les erreurs, tentatives de reprise et versions de schéma.
-   Empêcher les sauvegardes concurrentes pour un même joueur.
-   Libérer le verrou de session lorsque le joueur quitte.

Ne doit pas gérer les règles de collecte, les prix ou les interfaces.

### 5.2 `CollectionService`

Responsabilités :

-   Recevoir les demandes de collecte.
-   Vérifier que la ressource existe et est collectable.
-   Vérifier la distance entre le personnage et la ressource.
-   Vérifier la cadence autorisée selon l'équipement.
-   Vérifier la capacité restante du sac.
-   Calculer la quantité réellement collectée.
-   Mettre à jour l'inventaire côté serveur.
-   Déclencher le retour visuel et la mise à jour d'état.

Le client ne transmet jamais une valeur de récompense. Il transmet
uniquement l'identifiant de la ressource ciblée.

### 5.3 `InventoryService`

Responsabilités :

-   Maintenir les quantités par type de ressource.
-   Calculer le poids ou l'occupation du sac.
-   Vérifier la capacité maximale.
-   Ajouter et retirer des ressources.
-   Fournir un état simplifié au client.
-   Empêcher les quantités négatives ou incohérentes.

### 5.4 `EconomyService`

Responsabilités :

-   Maintenir les soldes de monnaies.
-   Créditer les Coins après une vente validée.
-   Débiter les Coins lors d'un achat.
-   Vérifier qu'un solde est suffisant avant toute dépense.
-   Centraliser les transactions et leurs motifs.
-   Refuser toute transaction qui produirait un solde négatif.

Les valeurs économiques proviennent des modules de configuration. Le
client ne choisit jamais le montant d'une transaction.

### 5.5 `UpgradeService`

Responsabilités :

-   Lire le niveau actuel d'une amélioration.
-   Calculer le coût à partir de la configuration.
-   Vérifier le solde et le niveau maximum.
-   Débiter la monnaie et appliquer l'amélioration de manière atomique
    côté serveur.
-   Retourner le nouvel état au client.

### 5.6 `WorldService`

Responsabilités :

-   Vérifier les prérequis d'un monde.
-   Débiter le coût de déblocage.
-   Enregistrer le monde débloqué.
-   Autoriser les déplacements vers les zones accessibles.
-   Refuser les demandes d'accès à un monde verrouillé.

### 5.7 `RateLimitService`

Responsabilités :

-   Appliquer une limite de fréquence par joueur et par action.
-   Rejeter les appels répétés ou anormaux.
-   Fournir des limites distinctes pour la collecte, la vente et les
    achats.
-   Journaliser les comportements suspects sans bannir automatiquement
    sur un seul signal.

### 5.8 `MonetizationService`

Responsabilités :

-   Vérifier la propriété des Game Pass.
-   Traiter les Developer Products via
    `MarketplaceService.ProcessReceipt`.
-   Attribuer chaque achat consommable une seule fois.
-   Gérer les erreurs temporaires et les reçus en attente.
-   Journaliser les transactions.
-   Ne jamais faire confiance à une confirmation d'achat envoyée par le
    client.

### 5.9 `AnalyticsService`

Responsabilités :

-   Enregistrer les événements de gameplay utiles.
-   Mesurer la progression et les points de friction.
-   Éviter de transmettre des données personnelles inutiles.
-   Ne jamais être une dépendance critique pour la boucle de jeu : une
    panne analytics ne doit pas bloquer une collecte ou une vente.

------------------------------------------------------------------------

## 6. Communication client-serveur

### 6.1 Remotes du MVP

  ----------------------------------------------------------------------------
  Remote                 Sens              Payload           Contrôle serveur
                                           recommandé        
  ---------------------- ----------------- ----------------- -----------------
  `RequestCollect`       Client → Serveur  `resourceId`      Existence,
                                                             distance,
                                                             cadence, capacité

  `RequestSell`          Client → Serveur  `sellZoneId`      Zone, distance,
                                                             inventaire, prix

  `RequestUpgrade`       Client → Serveur  `upgradeId`       ID autorisé,
                                                             coût, solde,
                                                             niveau

  `RequestUnlockWorld`   Client → Serveur  `worldId`         Prérequis, coût,
                                                             solde

  `StateUpdated`         Serveur → Client  État public du    Données produites
                                           joueur            par le serveur

  `ActionResult`         Serveur → Client  Action, succès,   Réponse contrôlée
                                           code résultat     
  ----------------------------------------------------------------------------

Les objets `RemoteEvent` sont créés et référencés de manière
centralisée. Ne pas créer un RemoteEvent différent pour chaque
ressource.

### 6.2 Exemple de demande de collecte

Payload client :

``` lua
{
    resourceId = "green_leaf_001"
}
```

Le serveur doit ensuite :

1.  Vérifier le type et la taille du payload.
2.  Vérifier que `resourceId` correspond à une ressource active.
3.  Vérifier que le personnage existe et est vivant.
4.  Vérifier la distance réelle au serveur.
5.  Vérifier le délai minimal depuis la dernière collecte.
6.  Vérifier la capacité du sac.
7.  Lire la valeur de la ressource dans `ResourceConfig`.
8.  Ajouter la quantité autorisée à l'inventaire.
9.  Envoyer le nouvel état au client.

Le client ne doit jamais envoyer `reward`, `amount`, `price`, `coins` ou
`capacity` comme valeurs faisant autorité.

### 6.3 Validation réseau

Pour chaque RemoteEvent :

-   Vérifier que les arguments sont du type attendu.
-   Refuser les identifiants inconnus.
-   Vérifier les limites numériques.
-   Appliquer un rate limit.
-   Recalculer les conditions côté serveur.
-   Ne jamais utiliser directement une position ou un montant fourni par
    le client comme preuve.
-   Retourner un code d'erreur stable et exploitable par l'interface.

Codes de résultat possibles :

-   `SUCCESS`
-   `INVALID_TARGET`
-   `TOO_FAR`
-   `COOLDOWN`
-   `INVENTORY_FULL`
-   `NOT_ENOUGH_COINS`
-   `MAX_LEVEL`
-   `WORLD_LOCKED`
-   `RATE_LIMITED`
-   `INTERNAL_ERROR`

------------------------------------------------------------------------

## 7. Modèle de données joueur

### 7.1 Schéma initial

Exemple de structure logique conservée par le serveur :

``` lua
local DEFAULT_DATA = {
    schemaVersion = 1,

    currencies = {
        coins = 0,
        gems = 0,
        stars = 0,
    },

    inventory = {
        resources = {},
    },

    upgrades = {
        backpackLevel = 1,
        grabberLevel = 1,
        magnetLevel = 0,
        bootsLevel = 1,
        multiplierLevel = 1,
    },

    worlds = {
        GreenValley = true,
        GoldenDesert = false,
        FrozenPeaks = false,
        MysticWorld = false,
    },

    stats = {
        totalResourcesCollected = 0,
        totalCoinsEarned = 0,
        totalCoinsSpent = 0,
        totalSales = 0,
        playTimeSeconds = 0,
    },

    settings = {
        musicEnabled = true,
        sfxEnabled = true,
    },

    lastSaveAt = 0,
}
```

Ce schéma est une base évolutive. Les champs Pets, Quests, Events et
achats seront ajoutés dans des migrations ultérieures, pas anticipés
sous forme de systèmes vides dans le MVP.

### 7.2 Clé DataStore

Utiliser un nom de DataStore versionné, par exemple :

`GrabAndGrow_PlayerData_v1`

Clé joueur :

`Player_<UserId>`

Ne jamais utiliser le nom d'utilisateur comme identifiant de sauvegarde
: il peut changer.

### 7.3 Chargement et sauvegarde

-   Charger les données à l'arrivée du joueur.
-   Ne pas autoriser les transactions tant que le profil n'est pas
    chargé.
-   Si le chargement échoue, appliquer une stratégie de reprise
    contrôlée ; ne pas écraser les données existantes avec un profil
    vide.
-   Utiliser `UpdateAsync` lorsque l'opération doit protéger une mise à
    jour concurrente.
-   Sauvegarder périodiquement, à la sortie et lors d'une fermeture
    serveur si possible.
-   Ajouter un mécanisme de verrouillage de session pour éviter que deux
    serveurs modifient simultanément le même profil.
-   Utiliser `pcall` autour des appels DataStore.
-   Prévoir des tentatives de reprise avec attente progressive et une
    limite.
-   Ne pas sauvegarder à chaque ressource collectée.
-   Garder les données en mémoire et sauvegarder à intervalles
    raisonnables ainsi qu'après les opérations importantes.

### 7.4 Intégrité des données

À chaque chargement :

-   Vérifier `schemaVersion`.
-   Ajouter les champs manquants depuis le profil par défaut.
-   Vérifier les types.
-   Borner les niveaux aux valeurs autorisées.
-   Remplacer les valeurs non valides par des valeurs sûres.
-   Refuser ou mettre en quarantaine les structures manifestement
    corrompues.
-   Ne pas écraser silencieusement une sauvegarde illisible.

### 7.5 Migrations

Chaque évolution de schéma doit avoir une migration explicite :

``` text
v1 -> v2 : ajout du champ pets
v2 -> v3 : nouvelle structure des quêtes
```

Les migrations doivent être testées sur des données représentatives
avant publication.

------------------------------------------------------------------------

## 8. Système de collecte et ressources

### 8.1 Configuration des ressources

Les propriétés de chaque ressource doivent être centralisées dans
`ResourceConfig.lua`.

Exemple :

``` lua
return {
    green_leaf = {
        displayNameKey = "resource.green_leaf",
        worldId = "GreenValley",
        sellValue = 1,
        rarity = "Common",
        collectAmount = 1,
        respawnSeconds = 2,
    },

    wood = {
        displayNameKey = "resource.wood",
        worldId = "GreenValley",
        sellValue = 2,
        rarity = "Common",
        collectAmount = 1,
        respawnSeconds = 3,
    },

    stone = {
        displayNameKey = "resource.stone",
        worldId = "GreenValley",
        sellValue = 3,
        rarity = "Uncommon",
        collectAmount = 1,
        respawnSeconds = 4,
    },
}
```

Les valeurs ci-dessus sont des exemples de configuration initiale ;
elles doivent rester cohérentes avec la Bible économique et être
ajustées par les tests de progression.

### 8.2 Identifiants des ressources

Chaque instance collectable possède un identifiant stable et unique
pendant sa durée de vie. Le serveur maintient la correspondance entre
l'identifiant, le modèle et la configuration.

Ne pas utiliser uniquement le nom visuel du modèle comme identifiant.

### 8.3 Cycle de collecte

``` text
Joueur cible une ressource
        |
        v
Client envoie RequestCollect(resourceId)
        |
        v
Serveur valide cible, distance, cadence et capacité
        |
   +----+----+
   |         |
 Refus     Acceptation
   |         |
Feedback   Mise à jour inventaire
             |
             v
       Mise à jour du client
             |
             v
       Effet visuel local
```

### 8.4 Combo

Le combo doit être calculé côté serveur pour éviter la manipulation des
multiplicateurs.

-   Le serveur mémorise l'heure de la dernière collecte valide.
-   Une collecte valide dans le délai configuré augmente le combo.
-   Une interruption supérieure au délai remet le combo à zéro ou au
    niveau de départ.
-   Le multiplicateur est calculé à partir de la configuration.
-   Le client ne fait qu'afficher le combo reçu.

### 8.5 Apparition des ressources

Pour le MVP, utiliser un système simple de points de spawn prédéfinis.

-   Les points sont organisés par zone.
-   Le serveur contrôle le nombre de ressources actives.
-   Les ressources réapparaissent après leur délai.
-   Éviter de créer des centaines de Parts dynamiques.
-   Utiliser des modèles simples et des collisions minimales.
-   Étudier le pooling si les créations/destructions deviennent
    coûteuses.

------------------------------------------------------------------------

## 9. Inventaire, vente et économie

### 9.1 Inventaire

L'inventaire serveur conserve les quantités par identifiant de
ressource.

Exemple :

``` lua
resources = {
    green_leaf = 12,
    wood = 5,
    stone = 3,
}
```

Le total utilisé et la capacité maximale sont calculés côté serveur. Le
client reçoit uniquement les données nécessaires à l'affichage.

### 9.2 Vente

Lors d'une demande de vente :

1.  Vérifier que le joueur se trouve dans la zone de vente.
2.  Lire l'inventaire réel côté serveur.
3.  Calculer la valeur de chaque ressource via la configuration.
4.  Appliquer les bonus autorisés.
5.  Créditer les Coins.
6.  Vider uniquement les quantités vendues.
7.  Mettre à jour les statistiques.
8.  Retourner le résultat au client.

La vente et le crédit doivent former une seule transaction logique. Il
ne faut pas vider l'inventaire si le crédit n'a pas été appliqué.

### 9.3 Transactions

Toutes les opérations économiques doivent passer par des fonctions
centralisées, par exemple :

-   `CreditCurrency(player, currency, amount, reason)`
-   `DebitCurrency(player, currency, amount, reason)`
-   `SellInventory(player)`
-   `PurchaseUpgrade(player, upgradeId)`

Chaque fonction doit vérifier les montants, le type de monnaie et le
motif de transaction.

### 9.4 Bible économique

Les valeurs économiques initiales sont des hypothèses de conception. Les
paramètres définitifs doivent être lus depuis les configurations
partagées et validés par simulation et tests en jeu. Ne pas dupliquer
les tables de prix dans plusieurs scripts.

------------------------------------------------------------------------

## 10. Améliorations et déblocages

### 10.1 Configuration

`UpgradeConfig.lua` définit pour chaque amélioration :

-   Identifiant.
-   Niveau minimum et maximum.
-   Coût par niveau.
-   Monnaie utilisée.
-   Effet par niveau.
-   Formule de progression si nécessaire.

### 10.2 Achat d'amélioration

Le serveur exécute l'achat dans cet ordre :

1.  Vérifier l'identifiant.
2.  Lire le niveau actuel.
3.  Vérifier le niveau maximum.
4.  Calculer le coût.
5.  Vérifier le solde.
6.  Débiter le solde.
7.  Appliquer le nouveau niveau.
8.  Envoyer l'état mis à jour.

Si une étape échoue, l'achat ne doit pas laisser un état partiellement
modifié.

### 10.3 Déblocage des mondes

`WorldConfig.lua` centralise les prérequis et les coûts. Le serveur
vérifie les conditions avant d'ajouter le monde aux mondes accessibles
du joueur.

Le déplacement physique vers une zone ne constitue jamais une preuve de
déblocage.

------------------------------------------------------------------------

## 11. Monétisation Roblox

La monétisation sera intégrée après validation du gameplay principal.

### 11.1 Game Pass

Exemples prévus dans la conception :

-   VIP.
-   x2 Coins.
-   Auto Sell.
-   Extra Pet Slot.
-   Style de nom.

Règles :

-   Vérifier la propriété avec les services Roblox côté serveur.
-   Ne pas accepter un booléen envoyé par le client comme preuve de
    propriété.
-   Mettre en cache les résultats en session avec une stratégie de
    rafraîchissement appropriée.
-   Appliquer les bonus dans les calculs serveur.
-   Afficher clairement les avantages avant l'achat.

### 11.2 Developer Products

Exemples prévus :

-   Packs de Gems.
-   Boosts temporaires.
-   Récompenses consommables.

Le traitement doit utiliser `MarketplaceService.ProcessReceipt`.

Règles obligatoires :

1.  Traiter les reçus sur le serveur.
2.  Utiliser `PurchaseId` comme identifiant de transaction.
3.  Enregistrer les achats déjà attribués.
4.  Attribuer la récompense une seule fois.
5.  Retourner `PurchaseGranted` uniquement lorsque l'attribution est
    confirmée.
6.  Retourner `NotProcessedYet` si le traitement ne peut pas être
    confirmé et doit être réessayé.
7.  Tester les scénarios de répétition, de déconnexion et d'échec
    temporaire.

Ne jamais attribuer un produit consommable uniquement via
`PromptProductPurchaseFinished`.

### 11.3 Sécurité commerciale

-   Les prix affichés doivent correspondre aux produits configurés sur
    Roblox.
-   Aucun achat ne doit être confirmé par une simple réponse client.
-   Les bonus payants doivent être appliqués dans les services serveur.
-   Les achats ne doivent pas créer de monnaie négative ou de
    duplication.
-   Prévoir une journalisation des attributions et des erreurs de reçus.

------------------------------------------------------------------------

## 12. Pets, quêtes et événements --- phases ultérieures

Ces systèmes ne doivent pas retarder le MVP. Ils respecteront les mêmes
principes.

### 12.1 Pets

`PetService` sera responsable de :

-   Vérifier le coût d'un œuf.
-   Effectuer le tirage aléatoire côté serveur.
-   Utiliser les probabilités définies dans la configuration.
-   Attribuer le Pet dans les données du joueur.
-   Gérer les emplacements équipés.
-   Calculer les bonus côté serveur.

Les probabilités affichées doivent être exactes et cohérentes avec les
probabilités réellement utilisées.

### 12.2 Quêtes

`QuestService` sera responsable de :

-   Définir les objectifs.
-   Suivre la progression côté serveur.
-   Valider l'achèvement.
-   Attribuer les récompenses une seule fois.
-   Réinitialiser les quêtes quotidiennes selon une référence temporelle
    cohérente.

### 12.3 Événements

`EventService` sera responsable de :

-   Démarrer et terminer les événements.
-   Maintenir l'état global de l'événement.
-   Valider les contributions individuelles.
-   Calculer les récompenses.
-   Empêcher la répétition frauduleuse des récompenses.

------------------------------------------------------------------------

## 13. Interface et expérience utilisateur

### 13.1 Contrôleurs client

-   `InputController` : collecte des entrées tactiles, clavier et
    manette si prise en charge.
-   `HUDController` : Coins, capacité du sac, combo et informations
    essentielles.
-   `CollectionController` : ciblage visuel et feedback de collecte.
-   `InventoryController` : affichage des ressources.
-   `ShopController` : affichage des améliorations et demandes d'achat.
-   `FeedbackController` : notifications, sons et effets.

Les contrôleurs ne contiennent pas les règles économiques. Ils affichent
l'état serveur et transmettent des demandes.

### 13.2 État client

Le client peut conserver un miroir temporaire de l'état du joueur pour
l'affichage. Ce miroir n'est jamais utilisé comme source d'autorité pour
une transaction.

À la reconnexion ou après une réponse serveur, l'interface doit pouvoir
se reconstruire à partir d'un état complet.

### 13.3 Mobile-first

-   Boutons tactiles suffisamment grands.
-   Actions principales accessibles avec une seule main lorsque
    possible.
-   HUD lisible sur les petits écrans.
-   Éviter les menus qui masquent la zone de jeu.
-   Limiter les effets visuels simultanés.
-   Prévoir des options de réduction des effets et du son.
-   Tester les interfaces sur plusieurs ratios d'écran.

### 13.4 Localisation

Préparer les textes avec des clés de traduction, par exemple :

-   `ui.sell`
-   `ui.backpack`
-   `ui.upgrade`
-   `resource.green_leaf`

Ne pas disperser les textes français ou anglais directement dans la
logique du jeu. Le MVP peut démarrer en anglais avec une structure prête
pour le français, ou proposer les deux langues si le volume de textes
reste maîtrisé.

------------------------------------------------------------------------

## 14. Performance et optimisation

### 14.1 Objectifs

Le jeu doit rester fluide sur les appareils mobiles courants, sans
sacrifier la lisibilité de la collecte.

### 14.2 Règles de performance

-   Privilégier des modèles low-poly simples.
-   Réduire le nombre de Parts et de MeshParts visibles.
-   Limiter les collisions aux éléments nécessaires.
-   Désactiver les collisions et requêtes physiques inutiles.
-   Réduire les effets de particules et les lumières dynamiques.
-   Éviter les boucles `while true` sans attente contrôlée.
-   Éviter les calculs coûteux à chaque frame côté serveur.
-   Utiliser des événements plutôt que du polling fréquent.
-   Limiter la fréquence des mises à jour HUD.
-   Nettoyer les connexions, instances et tâches à la sortie des
    joueurs.
-   Tester avec plusieurs joueurs et un volume réaliste de ressources.

### 14.3 Streaming et monde

Évaluer `StreamingEnabled` selon la taille des mondes et la densité des
objets. Les éléments indispensables au gameplay doivent être gérés de
manière compatible avec le streaming.

### 14.4 Budget de contenu

Les limites exactes seront mesurées dans Roblox Studio et sur appareils
réels. Ne pas adopter un nombre fixe de triangles comme garantie de
performance : le nombre d'instances, les matériaux, les appels de rendu,
les ombres et les effets ont également un impact.

------------------------------------------------------------------------

## 15. Sécurité et anti-exploit

### 15.1 Menaces à prévoir

-   Collecte à distance.
-   Collecte trop rapide.
-   Modification du montant de récompense.
-   Vente d'objets non possédés.
-   Achat sans solde suffisant.
-   Déblocage forcé de mondes.
-   Modification locale de la vitesse ou de la capacité.
-   Rejeu de RemoteEvents.
-   Duplication de récompenses.
-   Falsification d'un achat.

### 15.2 Mesures

-   Serveur autoritaire pour toutes les données de valeur.
-   Vérification de distance et de cadence.
-   Rate limiting par action.
-   Validation stricte des types et identifiants.
-   Calcul des récompenses depuis la configuration serveur.
-   Contrôle des prérequis et des soldes.
-   Idempotence pour les achats et récompenses uniques.
-   Journalisation des anomalies.
-   Sanctions graduelles et fondées sur plusieurs signaux.

Ne pas considérer une seule anomalie réseau comme une preuve suffisante
pour bannir définitivement un joueur.

------------------------------------------------------------------------

## 16. Analytics et indicateurs

Événements recommandés :

  Événement                Données utiles
  ------------------------ -------------------------------------------
  `player_session_start`   monde, plateforme
  `first_collect`          délai depuis l'arrivée
  `resource_collected`     type, quantité, monde
  `backpack_full`          capacité, durée de session
  `inventory_sold`         valeur, quantités, monde
  `upgrade_purchased`      amélioration, niveau, coût
  `world_unlocked`         monde, temps de progression
  `session_end`            durée, progression
  `purchase_prompted`      produit, emplacement UI
  `purchase_completed`     type de produit, identifiant non sensible

Indicateurs prioritaires :

-   Taux de joueurs qui réalisent une première collecte.
-   Taux de joueurs qui effectuent une première vente.
-   Temps jusqu'à la première amélioration.
-   Durée moyenne de session.
-   Rétention J1 et J7.
-   Progression moyenne par monde.
-   Conversion des offres, sans dégrader l'expérience gratuite.
-   Taux d'erreur de sauvegarde et de traitement des reçus.

Les analytics ne doivent pas bloquer les actions du jeu.

------------------------------------------------------------------------

## 17. Gestion des assets Polyfork

Polyfork est la bibliothèque d'assets 3D prioritaire, sous réserve de
vérifier chaque modèle avant intégration.

### 17.1 Pipeline

``` text
Catalogue Polyfork
      |
      v
Sélection du modèle
      |
      v
Vérification de licence et de provenance
      |
      v
Téléchargement GLB
      |
      v
Contrôle visuel et technique
      |
      v
Optimisation si nécessaire
      |
      v
Import Roblox Studio
      |
      v
Contrôle matériaux, échelle, collisions
      |
      v
Validation en jeu
```

### 17.2 Manifest des assets

Créer et maintenir :

`docs/assets/ASSET_MANIFEST.md`

Pour chaque asset, conserver :

-   Nom interne.
-   Nom original.
-   Source et URL.
-   Date de téléchargement.
-   Licence applicable au fichier.
-   Attribution requise ou non.
-   Fichier source conservé.
-   Modifications réalisées.
-   Emplacement dans le jeu.
-   Statut de validation.

Ne pas supposer que tous les modèles d'une bibliothèque partagent
automatiquement les mêmes conditions. Vérifier les conditions
applicables à chaque fichier et conserver une copie des informations de
licence au moment de l'acquisition.

### 17.3 Qualité des assets

-   Échelle cohérente.
-   Pivot adapté.
-   Matériaux simples.
-   Collisions simplifiées.
-   Pas de géométrie cachée inutile.
-   Pas de dépendance à des textures externes non maîtrisées.
-   Tester le rendu après import dans Roblox Studio.

------------------------------------------------------------------------

## 18. Tests et qualité

### 18.1 Tests unitaires et de logique

Tester en priorité :

-   Collecte valide et invalide.
-   Collecte hors distance.
-   Collecte trop rapide.
-   Sac plein.
-   Vente d'un inventaire vide.
-   Vente d'un inventaire rempli.
-   Achat avec solde suffisant et insuffisant.
-   Niveau maximum atteint.
-   Monde verrouillé et déverrouillé.
-   Chargement d'un nouveau joueur.
-   Chargement d'un profil existant.
-   Migration de schéma.
-   Échec temporaire de DataStore.
-   Rejeu d'un reçu Developer Product.

### 18.2 Tests multijoueurs

Utiliser le mode serveur local de Roblox Studio avec plusieurs clients.

Vérifier :

-   Deux joueurs peuvent collecter simultanément.
-   Une ressource ne donne pas deux récompenses si elle ne doit être
    collectée qu'une fois.
-   Les données d'un joueur ne modifient pas celles d'un autre.
-   Les ventes et achats sont isolés par joueur.
-   Les événements de serveur ne provoquent pas de désynchronisation
    visible.

### 18.3 Tests appareils

Tester au minimum :

-   Smartphone à écran compact.
-   Smartphone récent.
-   Tablette.
-   PC avec clavier et souris.

### 18.4 Critères de sortie du MVP

Le MVP est validé lorsque :

-   Un nouveau joueur peut rejoindre et jouer sans erreur bloquante.
-   La collecte, la vente et les améliorations fonctionnent.
-   Le serveur contrôle toutes les valeurs économiques.
-   Les données survivent à une déconnexion et reconnexion.
-   Les erreurs DataStore ne provoquent pas d'écrasement silencieux.
-   Deux joueurs peuvent jouer simultanément sans fuite de données.
-   L'interface est utilisable sur mobile.
-   Les performances restent acceptables dans un test de session
    prolongé.
-   Les logs ne montrent pas d'erreur critique récurrente.

------------------------------------------------------------------------

## 19. Déploiement et environnements

### 19.1 Environnements

Prévoir trois niveaux :

1.  **Développement local :** tests rapides dans Roblox Studio.
2.  **Test privé :** validation multijoueur, sauvegarde, économie et
    achats de test.
3.  **Production :** expérience publiée et accessible au public.

Ne pas tester des migrations risquées sur les données de production.
Utiliser un DataStore distinct pour les environnements de test lorsque
la configuration le permet.

### 19.2 Publication

Avant chaque publication :

-   Exécuter les tests de logique.
-   Vérifier les RemoteEvents.
-   Vérifier les données et migrations.
-   Tester la sauvegarde.
-   Vérifier les achats et leurs reçus en environnement de test.
-   Vérifier les écrans mobiles.
-   Contrôler les assets et licences.
-   Consulter les logs serveur.
-   Préparer un plan de retour arrière pour les changements de données
    importants.

------------------------------------------------------------------------

## 20. Phasage technique recommandé

  -----------------------------------------------------------------------
  Phase                   Livrable                Critère de validation
  ----------------------- ----------------------- -----------------------
  T0                      Structure du projet et  Projet organisé,
                          configurations          lancement sans erreur

  T1                      Profil joueur et        Chargement, sauvegarde
                          sauvegarde              et reconnexion

  T2                      Collecte et inventaire  Collecte serveur
                                                  sécurisée, sac limité

  T3                      Vente et Coins          Transaction fiable et
                                                  inventaire vidé
                                                  correctement

  T4                      Améliorations           Achats validés côté
                                                  serveur

  T5                      HUD et feedback mobile  Boucle complète
                                                  utilisable sur
                                                  téléphone

  T6                      Tests multijoueurs et   Aucun exploit simple,
                          anti-exploit            aucune fuite de données

  T7                      Équilibrage MVP         Première session
                                                  compréhensible et
                                                  satisfaisante

  T8                      Préparation publication Tests privés concluants
  -----------------------------------------------------------------------

Les mondes supplémentaires, Pets, quêtes, événements et monétisation
avancée ne commencent qu'après validation des phases T0 à T8.

------------------------------------------------------------------------

## 21. Directives pour Claude Code

Claude Code doit respecter les règles suivantes lorsqu'il intervient sur
le projet :

1.  Lire ce document et le GDD avant toute modification.
2.  Travailler exclusivement avec Roblox Studio et Luau.
3.  Ne jamais introduire Unity, Godot ou un framework non validé.
4.  Respecter la séparation client/serveur.
5.  Ne jamais placer de logique économique autoritaire dans un
    LocalScript.
6.  Centraliser les paramètres dans les modules `Config`.
7.  Ne pas dupliquer les valeurs de la Bible économique.
8.  Ajouter ou mettre à jour les tests pour chaque règle de gameplay
    modifiée.
9.  Préserver les données existantes et versionner les migrations.
10. Ne pas créer de systèmes futurs prématurément.
11. Garder les scripts courts, modulaires et documentés lorsque
    nécessaire.
12. Après chaque lot, fournir un résumé des fichiers modifiés, tests
    exécutés, résultats, risques et prochaine étape.
13. Ne pas déclarer un lot terminé si les tests correspondants n'ont pas
    été exécutés.
14. Ne pas modifier ou remplacer un asset source sans conserver sa
    provenance et ses informations de licence.

### 21.1 Format de compte rendu attendu

``` text
LOT :
STATUT : terminé / partiel / bloqué

MODIFICATIONS :
- ...

FICHIERS :
- ...

TESTS :
- Commande ou procédure :
- Résultat :

RISQUES / POINTS À SURVEILLER :
- ...

PROCHAINE ÉTAPE :
- ...
```

------------------------------------------------------------------------

## 22. Références techniques officielles

À consulter et vérifier pendant le développement :

-   Roblox Creator Hub : https://create.roblox.com/docs
-   Data stores :
    https://create.roblox.com/docs/cloud-services/data-stores
-   Remote events and callbacks :
    https://create.roblox.com/docs/scripting/events/remote
-   MarketplaceService :
    https://create.roblox.com/docs/reference/engine/classes/MarketplaceService
-   ProcessReceipt :
    https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt
-   Performance :
    https://create.roblox.com/docs/performance-optimization
-   Security and cheat mitigation :
    https://create.roblox.com/docs/scripting/security/security-tactics
-   Polyfork : https://polyfork.dev/assets

Les API et recommandations Roblox évoluent. Vérifier la documentation
officielle au moment de l'implémentation, en particulier pour DataStore,
les achats et les paramètres de publication.

------------------------------------------------------------------------

## 23. Décisions à ne pas remettre en cause sans validation

-   Roblox Studio et Luau sont la stack technique du projet.
-   Le serveur est l'unique autorité pour les données économiques et la
    progression.
-   Le MVP démarre dans Green Valley.
-   La collecte, la vente, les améliorations et la sauvegarde sont
    prioritaires.
-   Les valeurs de la Bible économique sont des hypothèses à tester.
-   Le jeu est mobile-first, mais doit rester compatible PC et tablette.
-   Polyfork est la source d'assets prioritaire, avec vérification
    individuelle des licences.
-   La monétisation ne doit pas précéder la validation de la boucle de
    jeu.

**Fin du document --- GRAB & GROW Architecture technique v1.0**
