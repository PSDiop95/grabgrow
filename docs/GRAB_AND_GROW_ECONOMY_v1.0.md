# GRAB & GROW --- Bible économique

> **Document de référence économique et de monétisation**\
> Version : 1.0 --- 10 novembre 2026\
> Statut : proposition chiffrée initiale à tester\
> Projet : GRAB & GROW\
> Plateforme : Roblox\
> Référence de conception : `docs/GDD.md`\
> Document associé : `docs/TECHNICAL_ARCHITECTURE.md`\
> Bibliothèque d'assets : [Polyfork](https://polyfork.dev/)

------------------------------------------------------------------------

## 0. Objet du document

Cette bible définit les règles économiques de GRAB & GROW :

-   monnaies et sources de revenus ;
-   valeur des ressources ;
-   capacité du sac et rythme de collecte ;
-   prix et effets des améliorations ;
-   déblocage des mondes ;
-   Pets et bonus ;
-   quêtes et événements ;
-   récompenses de progression ;
-   produits Robux ;
-   garde-fous contre l'inflation et les abus ;
-   métriques et protocole d'équilibrage.

Les chiffres ci-dessous constituent une **version économique de
départ**, destinée à être implémentée dans des fichiers de configuration
et testée en jeu. Ils ne sont pas des valeurs définitives issues de
données de joueurs.

### 0.1 Principes non négociables

1.  Le joueur doit pouvoir progresser gratuitement dans tous les mondes
    principaux.
2.  Les achats Robux ne doivent pas être obligatoires pour terminer le
    contenu.
3.  Une amélioration doit produire un bénéfice perceptible.
4.  Le prochain objectif doit être visible et compréhensible.
5.  Les récompenses sont calculées et attribuées par le serveur.
6.  Les prix, valeurs et multiplicateurs sont centralisés dans la
    configuration.
7.  Aucune monnaie ne doit être créée sans source et usage définis.
8.  Les systèmes aléatoires affichent leurs probabilités avant l'action.
9.  Les bonus sont plafonnés pour limiter les écarts entre joueurs.
10. L'équilibrage est validé par simulation et tests réels, pas
    uniquement par intuition.

------------------------------------------------------------------------

## 1. Synthèse de l'économie

### 1.1 Les trois monnaies

  -----------------------------------------------------------------------
  Monnaie           Symbole interne   Fonction          Dépenses
                                      principale        
  ----------------- ----------------- ----------------- -----------------
  Coins             `COINS`           Progression       Équipements,
                                      courante          mondes, œufs
                                                        standards

  Gems              `GEMS`            Progression       Certains œufs,
                                      spéciale          cosmétiques,
                                                        boosts

  Stars             `STARS`           Prestige et       Boutique de
                                      objectifs avancés prestige, objets
                                                        spéciaux
  -----------------------------------------------------------------------

**Coins** est la monnaie principale. Elle est obtenue fréquemment par la
vente des ressources.

**Gems** est une monnaie rare, obtenue par les quêtes, succès et
événements. Elle peut aussi être vendue en packs Robux, mais aucune
progression fondamentale ne doit dépendre exclusivement de son achat.

**Stars** est une monnaie de long terme. Elle n'est pas nécessaire au
MVP. Son usage doit être activé uniquement lorsque le système de
prestige et sa boutique sont prêts.

### 1.2 Sources et puits

  -----------------------------------------------------------------------
  Monnaie                 Sources                 Puits (dépenses)
  ----------------------- ----------------------- -----------------------
  Coins                   Vente, quêtes,          Sac, Grabber, Magnet,
                          événements, succès      Boots, Multiplier,
                                                  mondes, œufs Coins

  Gems                    Quêtes, succès,         Œufs Gems, cosmétiques,
                          événements, récompenses boosts spéciaux
                          spéciales, packs Robux  

  Stars                   Prestige, objectifs     Boutique Stars,
                          avancés, événements     cosmétiques de prestige
                          rares                   
  -----------------------------------------------------------------------

Chaque source et chaque dépense doivent être enregistrées dans les
statistiques économiques du serveur.

### 1.3 Règle de conversion

Aucune conversion directe Coins ↔ Gems ↔ Stars dans la version initiale.

Cette séparation évite : - l'arbitrage entre monnaies ; - les
conversions exploitables ; - la dévaluation rapide des monnaies rares
; - la complexité de l'équilibrage.

------------------------------------------------------------------------

## 2. Paramètres globaux

Valeurs de départ :

  Paramètre                                      Valeur initiale
  ------------------------------------- ------------------------
  Capacité du sac initiale                             50 unités
  Capacité maximale cible                           2 000 unités
  Capacité d'équipement initial                            1 Pet
  Pets équipables gratuits au départ                           2
  Vitesse de déplacement de référence                 16 studs/s
  Portée de collecte de base                            12 studs
  Intervalle de collecte de base                          0,75 s
  Durée de Combo sans collecte                               3 s
  Multiplicateur maximal de Combo                          x1,50
  Bonus maximal total de vente                             x5,00
  Bonus Friend Boost maximal                               +10 %
  Durée cible d'un boost                                  15 min
  Intervalle cible des événements                     10--15 min
  Capacité de serveur de conception       À mesurer et confirmer

Les limites doivent être configurées côté serveur. Les valeurs affichées
par le client ne sont jamais des valeurs d'autorité.

------------------------------------------------------------------------

## 3. Ressources et valeur de vente

### 3.1 Règle de valeur

Chaque ressource possède une valeur de base exprimée en Coins par unité.

`Valeur vendue = quantité × valeur unitaire × multiplicateurs autorisés`

Les multiplicateurs s'appliquent à la vente, pas à la création des
ressources. Les calculs utilisent des nombres entiers afin d'éviter les
soldes fractionnaires.

### 3.2 Green Valley

  Ressource       Rareté          Valeur / unité   Poids de spawn indicatif
  --------------- ------------- ---------------- --------------------------
  Green Leaf      Commune                      1                         40
  Wood Chunk      Commune                      2                         30
  Stone           Commune                      3                         20
  Wild Fruit      Peu commune                  5                          8
  Green Crystal   Rare                        12                          2

**Valeur moyenne théorique par ressource apparue :** 2,24 Coins avec les
poids ci-dessus (moyenne pondérée des cinq ressources).

**MVP :** seules Green Leaf, Wood Chunk et Stone sont actives. Avec leurs
poids (40 / 30 / 20), la moyenne est de 1,78 Coin par ressource. Les
valeurs unitaires ne changent pas.

### 3.3 Golden Desert

  Ressource     Rareté          Valeur / unité   Poids de spawn indicatif
  ------------- ------------- ---------------- --------------------------
  Sandstone     Commune                     12                         40
  Copper Ore    Commune                     16                         30
  Fossil        Peu commune                 24                         18
  Gold Nugget   Rare                        45                         10
  Sun Crystal   Épique                     100                          2

### 3.4 Frozen Peaks

  Ressource      Rareté          Valeur / unité   Poids de spawn indicatif
  -------------- ------------- ---------------- --------------------------
  Ice Shard      Commune                     65                         40
  Silver Ore     Commune                     85                         30
  Frozen Stone   Peu commune                120                         18
  Blue Crystal   Rare                       220                         10
  Ice Diamond    Épique                     500                          2

### 3.5 Mystic World

  Ressource        Rareté          Valeur / unité   Poids de spawn indicatif
  ---------------- ------------- ---------------- --------------------------
  Mystic Dust      Commune                    350                         40
  Star Fragment    Commune                    450                         30
  Spectral Ore     Peu commune                650                         18
  Purple Crystal   Rare                     1 200                         10
  Mystic Core      Épique                   2 500                          2

Les poids sont des valeurs relatives. Le système de spawn doit appliquer
les poids, vérifier les plafonds de ressources simultanées et respecter
les zones autorisées.

### 3.6 Règles de spawn

-   Les ressources apparaissent dans des emplacements ou volumes
    prédéfinis.
-   Une ressource collectée passe à l'état indisponible.
-   Le serveur contrôle son temps de réapparition.
-   Le client ne peut pas choisir la ressource ou son emplacement.
-   Les ressources rares ne doivent pas être générées en quantité
    illimitée.
-   Les ressources d'événement sont séparées des ressources ordinaires.
-   Le nombre d'objets visibles est plafonné pour préserver les
    performances.

**Hypothèse provisoire (MVP) :** temps de réapparition de 2 s (Green
Leaf), 3 s (Wood Chunk) et 4 s (Stone). Ces durées ne résultent d'aucune
simulation ; elles sont à mesurer et ajuster pendant l'équilibrage.

------------------------------------------------------------------------

## 4. Rythme de collecte et revenus cibles

### 4.1 Hypothèses de référence

Pour les simulations initiales : - intervalle de collecte de base : 0,75
seconde ; - collecte théorique maximale de base : 80 unités/minute ; -
capacité initiale : 50 unités ; - le temps de déplacement et de vente
réduit le débit réel ; - les multiplicateurs et Pets sont exclus des
revenus de référence.

Le débit réel dépend de la densité des ressources, de la distance, du
nombre de joueurs et des déplacements. Les tableaux de progression ne
doivent pas supposer une collecte parfaite en continu.

### 4.2 Objectifs de revenus par monde

  -----------------------------------------------------------------------
  Monde               Valeur moyenne indicative   Revenu brut cible / min
                                                   en progression normale
  ------------------- ------------------------- -------------------------
  Green Valley                       2,24 Coins            120--250 Coins

  Golden Desert                     20,42 Coins          900--1 800 Coins

  Frozen Peaks                      105,1 Coins        5 000--9 000 Coins

  Mystic World                        562 Coins      25 000--45 000 Coins
  -----------------------------------------------------------------------

Ces plages sont des objectifs de simulation. Si les joueurs obtiennent
durablement beaucoup plus ou beaucoup moins, ajuster les valeurs des
ressources, la densité, le temps de collecte ou les coûts
d'amélioration.

### 4.3 Capacité et temps de remplissage

  Niveau de sac     Capacité   Temps théorique à 0,75 s/unité
  --------------- ---------- --------------------------------
  1                       50                           37,5 s
  2                       75                           56,3 s
  3                      100                             75 s
  4                      140                            105 s
  5                      180                            135 s

Le temps théorique n'inclut pas les déplacements et les ressources
rares. Le sac ne doit pas imposer des allers-retours excessifs. Une
amélioration de capacité doit être utile sans rendre la station de vente
obsolète.

------------------------------------------------------------------------

## 5. Améliorations

### 5.1 Principes

Cinq améliorations sont prévues :

1.  Backpack --- capacité.
2.  Grabber --- vitesse de collecte.
3.  Magnet --- portée.
4.  Boots --- déplacement.
5.  Multiplier --- revenu de vente.

Chaque amélioration possède un niveau, un coût, une statistique et un
plafond. Les effets sont appliqués par le serveur.

### 5.2 Backpack

    Niveau   Capacité   Coût Coins
  -------- ---------- ------------
         1         50      Gratuit
         2         75          100
         3        100          250
         4        140          600
         5        180        1 200
         6        240        2 500
         7        320        5 000
         8        420       10 000
         9        550       20 000
        10        700       40 000
        11        850       75 000
        12      1 000      130 000
        13      1 200      220 000
        14      1 400      360 000
        15      1 650      600 000
        16      2 000    1 000 000

Les niveaux 17+ seront définis après les tests de la version initiale.

### 5.3 Grabber

Le Grabber réduit l'intervalle minimal entre deux collectes valides.

    Niveau   Intervalle cible   Coût Coins
  -------- ------------------ ------------
         1             0,75 s      Gratuit
         2             0,70 s          150
         3             0,65 s          400
         4             0,60 s          900
         5             0,55 s        2 000
         6             0,50 s        5 000
         7             0,46 s       12 000
         8             0,42 s       30 000
         9             0,39 s       70 000
        10             0,36 s      150 000

Le serveur doit appliquer un intervalle minimal de sécurité. Les bonus
de Pets et d'événement ne peuvent pas contourner cette limite.

### 5.4 Magnet

    Niveau   Portée cible   Coût Coins
  -------- -------------- ------------
         1       12 studs      Gratuit
         2       14 studs          200
         3       16 studs          500
         4       18 studs        1 200
         5       20 studs        3 000
         6       22 studs        7 500
         7       24 studs       18 000
         8       26 studs       45 000
         9       28 studs      100 000
        10       30 studs      220 000

La portée ne dispense jamais des vérifications de distance serveur. Elle
définit une portée de confort, pas une autorisation de collecte à
distance.

### 5.5 Boots

    Niveau   Vitesse cible   Coût Coins
  -------- --------------- ------------
         1              16      Gratuit
         2            16,5          250
         3              17          650
         4            17,5        1 500
         5              18        3 500
         6            18,5        8 000
         7              19       20 000
         8            19,5       50 000
         9              20      110 000
        10            20,5      250 000

La vitesse maximale doit être testée pour éviter les problèmes de
déplacement, de collision et de désynchronisation.

### 5.6 Multiplier

Le Multiplier augmente le montant de vente. Il ne multiplie pas les
récompenses de quêtes, les Gems ou les Stars.

    Niveau   Bonus de vente   Coût Coins
  -------- ---------------- ------------
         1            x1,00      Gratuit
         2            x1,05          300
         3            x1,10          800
         4            x1,15        1 800
         5            x1,20        4 000
         6            x1,25        9 000
         7            x1,30       22 000
         8            x1,35       55 000
         9            x1,40      130 000
        10            x1,50      300 000

Le multiplicateur est plafonné. Les multiplicateurs d'autres systèmes
doivent respecter le plafond global de vente.

### 5.7 Achat multiple

Le système d'achat doit prendre en charge : - `x1` ; - `x10` ; - `x100`
; - `MAX`.

Le serveur calcule le coût total et vérifie le solde. Le client ne
transmet que le type d'amélioration et la quantité demandée.

Pour `MAX`, le serveur détermine le nombre de niveaux achetables et
renvoie le résultat.

------------------------------------------------------------------------

## 6. Déblocage des mondes

  Monde           Condition de déblocage                           Coût
  --------------- ------------------------------------- ---------------
  Green Valley    Disponible au départ                          Gratuit
  Golden Desert   Backpack niveau 5 et 1 500 Coins          1 500 Coins
  Frozen Peaks    Backpack niveau 8 et 35 000 Coins        35 000 Coins
  Mystic World    Backpack niveau 10 et 250 000 Coins     250 000 Coins

Le coût est payé une seule fois. Une fois un monde débloqué, le joueur
le conserve.

Les conditions doivent être affichées explicitement : niveau requis,
Coins requis et état de progression.

Les valeurs seront réévaluées avec les revenus réellement observés. Un
joueur ne doit pas être forcé à acheter un produit Robux pour accéder au
monde suivant.

------------------------------------------------------------------------

## 7. Pets --- économie et bonus

### 7.1 Principes de bonus

Les Pets offrent des bonus limités. Ils ne doivent pas rendre les
joueurs sans Pets incapables de progresser.

Types de bonus : - `sellBonus` : bonus de Coins à la vente ; -
`capacityBonus` : capacité supplémentaire ; - `magnetBonus` : portée
supplémentaire ; - `eventBonus` : bonus de contribution, plafonné.

Un Pet ne doit pas cumuler plusieurs bonus majeurs sans contrepartie.

### 7.2 Raretés et probabilités de l'œuf standard

  Rareté        Probabilité
  ----------- -------------
  Common               55 %
  Uncommon             25 %
  Rare                 13 %
  Epic                  5 %
  Legendary             2 %
  **Total**       **100 %**

Ces probabilités sont affichées avant l'ouverture. Elles sont des
valeurs de départ et devront être ajustées selon la valeur des bonus et
les règles Roblox applicables.

### 7.3 Bonus indicatifs par rareté

  Rareté        Bonus de vente indicatif
  ----------- --------------------------
  Common                            +2 %
  Uncommon                          +4 %
  Rare                              +6 %
  Epic                              +9 %
  Legendary                        +12 %
  Mythic                           +15 %

Les bonus équipés sont additionnés puis plafonnés à +50 % pour la
version initiale. Le plafond global de vente reste prioritaire.

### 7.4 Capacité d'équipement

  Progression                    Pets équipables
  ---------------------------- -----------------
  Départ                                       2
  Déblocage par quête/succès                   3
  Game Pass éventuel                           4

Le Game Pass ne doit pas être le seul moyen d'obtenir un troisième
emplacement. Le quatrième emplacement peut être une option premium après
test d'équilibrage.

### 7.5 Œufs et prix de départ

  Œuf          Monde             Prix Coins
  ------------ --------------- ------------
  Green Egg    Green Valley             500
  Desert Egg   Golden Desert          8 000
  Frozen Egg   Frozen Peaks          75 000
  Mystic Egg   Mystic World         600 000

Chaque œuf possède une table de Pets cohérente avec le monde. Les
probabilités spécifiques sont affichées dans l'interface.

### 7.6 Doublons

Les doublons sont convertis en fragments de Pet ou en progression de
fusion uniquement si le système de fusion est implémenté et équilibré.

Pour le MVP, privilégier une conversion simple et transparente : -
doublon Common : 1 Pet Token ; - Uncommon : 2 ; - Rare : 5 ; - Epic : 12
; - Legendary : 30.

Les Pet Tokens sont une ressource d'inventaire non échangeable. Ils
peuvent être utilisés pour une récompense définie, mais ne deviennent
pas une quatrième monnaie générale.

------------------------------------------------------------------------

## 8. Quêtes, succès et récompenses

### 8.1 Quêtes quotidiennes

Chaque joueur reçoit trois quêtes quotidiennes parmi une liste
contrôlée.

  Type de quête   Exemple                           Récompense indicative
  --------------- --------------------------------- -----------------------
  Collecte        Collecter 100 ressources          250 Coins
  Vente           Vendre 500 Coins de ressources    300 Coins
  Amélioration    Acheter 1 amélioration            400 Coins
  Découverte      Découvrir 3 ressources            2 Gems
  Événement       Participer à 1 événement          3 Gems
  Compagnon       Faire éclore 1 œuf gagné en jeu   250 Coins

Les objectifs s'adaptent au monde du joueur. Ne pas demander une action
inaccessible à son niveau.

### 8.2 Quêtes hebdomadaires

  Type              Exemple                         Récompense indicative
  ----------------- ------------------------------- -----------------------
  Collecte longue   Collecter 2 000 ressources      10 Gems
  Vente longue      Vendre 25 000 Coins             12 Gems
  Social            Participer à 5 événements       15 Gems
  Exploration       Découvrir 10 ressources rares   15 Gems

### 8.3 Succès permanents

Exemples : - première collecte ; - première vente ; - premier sac
amélioré ; - premier monde débloqué ; - 1 000 ressources collectées ; -
10 000 ressources collectées ; - premier événement terminé ; - premier
Pet Rare obtenu.

Les récompenses de succès sont uniques et doivent être enregistrées pour
éviter toute répétition frauduleuse.

### 8.4 Séries quotidiennes

Les récompenses de connexion doivent rester modestes. Éviter une
mécanique qui pénalise lourdement une absence ou encourage une connexion
compulsive.

La progression peut utiliser un calendrier hebdomadaire flexible : les
jours manqués ne réinitialisent pas brutalement l'ensemble des gains.

------------------------------------------------------------------------

## 9. Événements et récompenses

### 9.1 Giant Meteor

Objectif collectif : collecter des fragments de météore.

Récompenses indicatives : - participation minimale : 300 Coins ; -
contribution intermédiaire : 500 Coins + 2 Gems ; - contribution élevée
: 800 Coins + 4 Gems ; - récompense de serveur : coffre cosmétique ou
Pet Token.

La contribution est calculée par le serveur. Le joueur doit accomplir
une action réelle pour être éligible.

### 9.2 Golden Rush

Pendant une durée limitée, des ressources bonus apparaissent dans une
zone.

-   durée cible : 3 minutes ;
-   valeur totale limitée par serveur ;
-   récompense de participation : Coins ;
-   bonus de classement : cosmétique ou petite quantité de Gems.

### 9.3 Crystal Explosion

Les joueurs contribuent à briser un cristal géant.

-   jauge commune ;
-   récompense individuelle selon des paliers ;
-   récompense commune si l'objectif est atteint ;
-   récompense de consolation si l'objectif échoue, afin que la
    participation ne soit pas inutile.

### 9.4 Contrôle économique des événements

Les récompenses d'événement ne doivent pas dépasser une part excessive
du revenu normal d'une session.

Cible initiale : un événement réussi apporte environ 1 à 3 minutes de
revenu normal du joueur, selon le monde et son niveau.

------------------------------------------------------------------------

## 10. Grab Combo et multiplicateurs

### 10.1 Combo

-   Une collecte valide augmente le compteur.
-   Le Combo expire après 3 secondes sans collecte.
-   Les paliers sont 5, 10, 20 et 30 collectes.
-   Le bonus maximal est x1,50.
-   Le bonus ne s'applique qu'à la vente des ressources éligibles.

### 10.2 Multiplicateurs

Les catégories de multiplicateurs sont : - équipement ; - Pets ; -
événement ; - Friend Boost ; - produit temporaire.

Tous les multiplicateurs sont calculés côté serveur. Le cumul est
plafonné à x5,00 en vente.

Formule conceptuelle :

`SellMultiplier = min(Equipment × Pet × Event × Friend × Temporary, 5.00)`

Pour éviter les explosions de revenus, préférer des bonus additifs à
l'intérieur de chaque catégorie et une multiplication contrôlée entre
catégories.

### 10.3 Friend Boost

-   +5 % par ami éligible présent dans le serveur ;
-   maximum +10 % ;
-   le joueur ne peut pas se compter lui-même ;
-   les comptes et conditions sont validés côté serveur ;
-   le bonus ne s'applique pas aux Gems, Stars ou achats.

La règle exacte de détection des amis doit respecter les API et
paramètres de confidentialité Roblox disponibles.

------------------------------------------------------------------------

## 11. Prestige et Stars

Le prestige n'est pas requis pour le MVP. Il sera activé après
validation des quatre mondes.

### 11.1 Principe proposé

Le joueur peut réinitialiser une partie de sa progression Coins et
équipements contre des Stars et un bonus permanent plafonné.

Éléments conservés : - Pets ; - cosmétiques ; - succès ; - mondes
découverts ou une partie de leur accès, selon la décision finale ; -
achats Robux ; - paramètres.

Éléments réinitialisés : - Coins ; - niveaux d'amélioration ; -
progression de monde associée aux équipements.

### 11.2 Conditions indicatives

-   Mystic World débloqué ;
-   seuil de Coins gagnés au total ;
-   confirmation explicite avant reset.

### 11.3 Récompense

Les Stars doivent être attribuées selon une formule basée sur la
progression totale, avec des paliers contrôlés. La formule exacte sera
définie dans une version ultérieure après observation du temps
nécessaire pour terminer les quatre mondes.

**Décision :** Stars visibles dans l'interface uniquement lorsque le
système Prestige est prêt. Ne pas afficher une monnaie sans usage.

------------------------------------------------------------------------

## 12. Monétisation Robux

### 12.1 Principes

-   Les Game Pass sont des achats permanents.
-   Les Developer Products sont des achats répétables.
-   Les achats sont traités côté serveur.
-   Le contenu et le prix sont affichés clairement.
-   Les fenêtres d'achat ne doivent pas interrompre la boucle.
-   Les offres ne doivent pas être trompeuses ou artificiellement
    urgentes.
-   Les produits aléatoires payants doivent respecter les exigences
    Roblox applicables.

### 12.2 Game Pass proposés

  -----------------------------------------------------------------------------
  Identifiant interne   Nom affiché      Effet                        Prix test
  --------------------- ---------------- ---------------- ---------------------
  `PASS_VIP`            VIP              Badge,                         299 R\$
                                         cosmétique,      
                                         petit bonus      
                                         social           

  `PASS_DOUBLE_COINS`   x2 Coins         x2 sur ventes                  399 R\$
                                         éligibles        

  `PASS_AUTO_SELL`      Auto Sell        Vente                          249 R\$
                                         automatique à    
                                         cadence          
                                         contrôlée        

  `PASS_EXTRA_PET`      Extra Pet Slot   +1 emplacement                 199 R\$
                                         de Pet           

  `PASS_NAME_STYLE`     Name Style       Style de nom                    99 R\$
                                         cosmétique       
  -----------------------------------------------------------------------------

Ces prix sont des hypothèses de test. Ils ne doivent pas être publiés
avant test d'élasticité et vérification des règles de tarification
Roblox.

### 12.3 Règles d'effets

**VIP** - badge et nom distinctif ; - cosmétique exclusif ; - bonus
social léger, non indispensable.

**x2 Coins** - s'applique uniquement aux ventes de ressources éligibles
; - ne double pas les récompenses Gems ou Stars ; - respecte les
plafonds de multiplicateur ; - est vérifié par le serveur.

**Auto Sell** - vend le sac lorsque les conditions sont réunies ; -
n'augmente pas directement la valeur des ressources ; - utilise une
cadence serveur raisonnable ; - ne doit pas créer une boucle de gains
hors ligne illimitée.

**Extra Pet Slot** - augmente la capacité d'équipement d'un emplacement
; - respecte le plafond de bonus des Pets.

### 12.4 Developer Products proposés

  -------------------------------------------------------------------------------
  Identifiant interne     Produit          Effet                        Prix test
  ----------------------- ---------------- ---------------- ---------------------
  `PROD_BOOST_COINS_15`   Coins Boost 15   Bonus temporaire                29 R\$
                          min              de Coins         

  `PROD_BOOST_LUCK_15`    Luck Boost 15    Bonus de chance                 39 R\$
                          min              affiché          

  `PROD_GEMS_S`           Gems Small       Petit pack de                   49 R\$
                                           Gems             

  `PROD_GEMS_M`           Gems Medium      Pack moyen de                  149 R\$
                                           Gems             

  `PROD_GEMS_L`           Gems Large       Grand pack de                  499 R\$
                                           Gems             

  `PROD_EVENT_BOOST`      Event Boost      Bonus de                        29 R\$
                                           contribution     
                                           plafonné         
  -------------------------------------------------------------------------------

Les quantités de Gems de chaque pack doivent être fixées après
simulation de leur valeur par rapport au temps de jeu gratuit.

### 12.5 Starter Pack

Offre unique et facultative : - un cosmétique exclusif ; - un Pet non
indispensable ; - une petite quantité de Gems ; - un boost court.

Le contenu et le prix doivent être affichés avant achat. Ne pas utiliser
de compte à rebours trompeur.

### 12.6 Publicités

Les publicités récompensées ne sont pas dans le MVP. Elles pourront être
étudiées plus tard selon les fonctionnalités disponibles et les règles
Roblox en vigueur.

### 12.7 Reçus et attribution

-   Chaque Developer Product est traité via
    `MarketplaceService.ProcessReceipt`.
-   L'identifiant du reçu est conservé pour empêcher un double crédit.
-   Une attribution n'est confirmée qu'après sauvegarde fiable.
-   Si le service de données est indisponible, le traitement doit
    permettre une nouvelle tentative sans perte ni duplication.
-   Les achats ne sont jamais validés sur la seule base d'un message
    client.
-   Les Game Pass sont vérifiés côté serveur.

------------------------------------------------------------------------

## 13. Inflation, plafonds et anti-abus

### 13.1 Sources d'inflation

-   valeur de ressources trop élevée ;
-   multiplicateurs cumulés ;
-   récompenses de quêtes répétables ;
-   événements trop généreux ;
-   vente automatique mal contrôlée ;
-   achats multiples non validés ;
-   exploits de RemoteEvents.

### 13.2 Garde-fous

-   plafond de multiplicateur de vente ;
-   plafond de collecte par seconde ;
-   plafonds de récompense par événement ;
-   validation serveur des quêtes ;
-   cooldown serveur des récompenses ;
-   inventaire et soldes modifiés par services centraux ;
-   journalisation des transactions importantes ;
-   détection des variations anormales de soldes.

### 13.3 Journal des transactions

Chaque opération économique importante doit pouvoir être tracée avec : -
identifiant joueur interne ; - type de transaction ; - montant ; -
monnaie ; - source ou puits ; - horodatage ; - identifiant d'opération
; - résultat.

Ne pas enregistrer de données personnelles non nécessaires.

------------------------------------------------------------------------

## 14. Modèle de simulation

Avant le lancement, créer un simulateur de progression ou des tests
automatisés capables de calculer :

-   temps estimé pour remplir le sac ;
-   revenus par minute ;
-   temps nécessaire pour acheter chaque amélioration ;
-   temps de déblocage de chaque monde ;
-   valeur des bonus Pets ;
-   revenus avec et sans Game Pass ;
-   effets des événements ;
-   effet des variations de densité de ressources.

### 14.1 Scénarios à simuler

  Profil             Hypothèse
  ------------------ ------------------------------------------------
  Joueur débutant    Comprend lentement, collecte avec déplacements
  Joueur moyen       Utilise les améliorations et suit les quêtes
  Joueur efficace    Optimise sa route et participe aux événements
  Joueur avec Pets   Utilise deux Pets de progression
  Joueur premium     Possède un Game Pass de confort ou de revenus

Le joueur premium ne doit pas rendre le joueur gratuit insignifiant.
Comparer le temps de progression, pas seulement les soldes.

### 14.2 Tests de sensibilité

Faire varier : - temps de collecte de ±20 % ; - valeur moyenne des
ressources de ±20 % ; - densité des ressources ; - temps de déplacement
; - durée entre deux ventes ; - taux de participation aux événements ; -
bonus moyen des Pets.

Si une petite variation rend la progression impossible ou trop rapide,
le modèle est trop fragile.

------------------------------------------------------------------------

## 15. Analytics économiques

### 15.1 Événements à enregistrer

-   `currency_earned`
-   `currency_spent`
-   `resource_collected`
-   `resource_sold`
-   `upgrade_purchased`
-   `world_unlocked`
-   `pet_egg_opened`
-   `pet_equipped`
-   `quest_reward_claimed`
-   `event_reward_claimed`
-   `gamepass_purchase_completed`
-   `developer_product_granted`

Chaque événement inclut une catégorie de source/puits et les valeurs
nécessaires à l'analyse.

### 15.2 KPI économiques

  -----------------------------------------------------------------------
  KPI                                 Utilité
  ----------------------------------- -----------------------------------
  Coins earned per minute             Vérifier le rythme de progression

  Coins spent per session             Mesurer les dépenses de progression

  Time to first upgrade               Vérifier le premier objectif

  Time to unlock world                Vérifier les paliers

  Upgrade purchase distribution       Identifier les améliorations
                                      ignorées

  Pet ownership/equip rate            Mesurer l'usage des Pets

  Event reward share                  Contrôler l'inflation
                                      événementielle

  Conversion to payer                 Mesurer les achats

  Revenue per payer                   Mesurer la dépense moyenne

  Refund / failed receipt rate        Surveiller les problèmes d'achat
  -----------------------------------------------------------------------

### 15.3 Règles d'ajustement

-   Modifier une variable principale à la fois.
-   Comparer les cohortes avant et après changement.
-   Ne pas réduire les récompenses uniquement pour pousser un achat.
-   Documenter chaque modification dans l'historique.
-   Tester les valeurs sur serveur privé avant déploiement public.

------------------------------------------------------------------------

## 16. Configuration technique suggérée

Les valeurs économiques doivent être stockées dans des modules de
configuration et non dispersées dans les scripts.

Exemple de structure :

``` lua
local EconomyConfig = {
    StartingCurrency = {
        Coins = 0,
        Gems = 0,
        Stars = 0,
    },

    Backpack = {
        [1] = { capacity = 50, cost = 0 },
        [2] = { capacity = 75, cost = 100 },
        [3] = { capacity = 100, cost = 250 },
    },

    GlobalCaps = {
        sellMultiplier = 5.0,
        petSellBonus = 0.50,
        friendBoost = 0.10,
    },

    Combo = {
        timeoutSeconds = 3,
        maxMultiplier = 1.50,
    },
}

return EconomyConfig
```

Les tables complètes doivent être définies dans : -
`EconomyConfig.lua` - `ResourcesConfig.lua` - `UpgradesConfig.lua` -
`WorldsConfig.lua` - `PetsConfig.lua` - `QuestsConfig.lua` -
`EventsConfig.lua` - `ProductsConfig.lua`

Ne pas dupliquer les prix dans les interfaces. Le client lit les valeurs
partagées pour l'affichage ; le serveur reste la source d'autorité pour
les transactions.

------------------------------------------------------------------------

## 17. Ordre d'implémentation économique

### Lot ECO-01 --- Économie centrale

-   soldes Coins ;
-   inventaire de ressources ;
-   vente ;
-   journal de transactions ;
-   tests de cohérence.

### Lot ECO-02 --- Progression

-   Backpack ;
-   Grabber ;
-   Magnet ;
-   Boots ;
-   Multiplier ;
-   achats x1/x10/x100/MAX.

### Lot ECO-03 --- Mondes

-   coûts de déblocage ;
-   conditions ;
-   persistance des accès ;
-   tests de progression.

### Lot ECO-04 --- Quêtes et événements

-   récompenses ;
-   limites ;
-   validation serveur ;
-   prévention des doublons.

### Lot ECO-05 --- Pets

-   tables de probabilités ;
-   attribution ;
-   équipement ;
-   plafonds de bonus ;
-   affichage des chances.

### Lot ECO-06 --- Monétisation

-   Game Pass ;
-   Developer Products ;
-   reçus idempotents ;
-   tests d'achat ;
-   vérification des droits.

### Lot ECO-07 --- Équilibrage

-   simulateur ;
-   tests de profils ;
-   mesures de revenus ;
-   ajustements documentés.

------------------------------------------------------------------------

## 18. Critères d'acceptation

La bible économique est considérée comme implémentée lorsque :

-   chaque monnaie possède des sources et puits définis ;
-   les ressources ont des valeurs centralisées ;
-   le sac respecte sa capacité ;
-   les ventes sont validées par le serveur ;
-   les achats d'amélioration débitent le bon montant ;
-   les achats multiples sont exacts ;
-   les mondes se débloquent une seule fois ;
-   les bonus sont plafonnés ;
-   les récompenses de quêtes et événements ne peuvent pas être
    réclamées deux fois ;
-   les probabilités des œufs sont visibles ;
-   les reçus Developer Products sont idempotents ;
-   les données économiques persistent ;
-   les tests couvrent les cas normaux, limites et abus ;
-   les revenus et dépenses peuvent être analysés par source.

------------------------------------------------------------------------

## 19. Décisions à ne pas figer avant les tests

1.  Les valeurs finales de vente des ressources.
2.  La cadence de spawn et le nombre d'objets actifs.
3.  Les revenus par minute par monde.
4.  Le coût définitif des améliorations.
5.  Le temps cible pour débloquer les mondes.
6.  Les bonus exacts des Pets.
7.  La distribution des probabilités des œufs.
8.  Le montant des récompenses d'événement.
9.  Les quantités de Gems des packs Robux.
10. Les prix définitifs des Game Pass et Developer Products.
11. La date d'activation de Stars et du Prestige.

Les valeurs de cette version permettent de construire et de tester les
systèmes, mais ne doivent pas être considérées comme un équilibrage
final.

------------------------------------------------------------------------

## 20. Historique des versions

  -----------------------------------------------------------------------
  Version                 Date                    Modifications
  ----------------------- ----------------------- -----------------------
  1.0                     2026-11-10              Première bible
                                                  économique : monnaies,
                                                  ressources,
                                                  améliorations, mondes,
                                                  Pets, événements,
                                                  monétisation,
                                                  garde-fous et analytics

  1.0.1                   2026-11-10              Correction des valeurs
                                                  moyennes par monde (3.2
                                                  et 4.2) recalculées
                                                  depuis les poids ;
                                                  moyenne MVP à trois
                                                  ressources ; hypothèse
                                                  de réapparition (3.6).
                                                  Aucune valeur unitaire
                                                  modifiée

  -----------------------------------------------------------------------

------------------------------------------------------------------------

**Fin du document --- GRAB & GROW ECONOMY v1.0**

Cette bible complète le GDD v1.0. Toute modification des valeurs
économiques doit être centralisée dans les fichiers de configuration,
testée et documentée ici avant publication.
